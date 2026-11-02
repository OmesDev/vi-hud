local HUD_COLOUR_WAYPOINT = 142
local TXD_NAME = 'vihud_minimap'
local KVP_PREFIX = 'layout5_'

-- Overall minimap size. Everything below (components, radar area, bar strip) is scaled by it
-- around the safe-zone bottom-left corner, so map, mask, panel and arrow stay lined up.
local SCALE = math.max(0.5, math.min(2.0, tonumber(Config.MinimapScale) or 1.0))

-- Default radar components (16:9 units, aligned Left / Bottom), restored on stop.
local BASE_COMPONENTS = {
    minimap      = { -0.0045, 0.002, 0.150, 0.188888 },
    minimap_mask = {  0.020,  0.032, 0.111, 0.159 },
    minimap_blur = { -0.03,   0.022, 0.266, 0.237 },
}

-- How far the radar is lifted (screen fraction). Kept at 0 so the map stays where GTA puts it;
-- layouts saved while it was lifted are moved back down by the difference (see rescale).
local LIFT = 0.0

-- What we pin on start: the defaults scaled by SCALE
local COMPONENTS = {}
for name, v in pairs(BASE_COMPONENTS) do
    COMPONENTS[name] = { v[1] * SCALE, v[2] * SCALE - LIFT, v[3] * SCALE, v[4] * SCALE }
end

-- Where GTA draws the player inside the default radar area (fraction of its height).
-- Measured in-game: the radar shows more road ahead, so the player sits low.
local PLAYER_Y = 0.70

local RADIUS = 0.09            -- corner radius as a fraction of frame height (matches style.css)
local MASK_W, MASK_H = 768, 384 -- runtime mask texture size (~ aspect of the blur component)

local editing = false
local nuiReady = false
local lastScreen = ''
local maskTex, maskBox

-- ---------------------------------------------------------------------------
-- Screen geometry (all rects are 0..1 screen fractions)
-- ---------------------------------------------------------------------------

local function safeMargin()
    return 0.5 * math.abs(GetSafeZoneSize() - 1.0)
end

local function aspectScale()
    return (16.0 / 9.0) / GetAspectRatio(false)
end

local RADAR_W16 = 0.140625 * SCALE  -- default radar width in 16:9 units (1 / (4 * 16/9))
local RADAR_H = 1.0 / 5.674 * SCALE -- default radar height (screen fraction)

-- Strip at the bottom of the default radar reserved for the health/armour bars. GTA never
-- draws the GPS route into it, even with the bars hidden. Measured in-game (23px at 1440p).
local BAR_STRIP_H = 0.016 * SCALE

-- GTA clips the GPS route to the *default* radar map area (anchor minus the bar strip),
-- wherever the components are moved — an engine limitation. 'fit' makes the panel exactly
-- that area, so nothing is ever cut short. 'wide' extends past it (see config.lua).
local function isWide()
    return Config.Shape == 'wide'
end

-- How far (16:9 units) the whole radar is shifted right so the wide panel can extend
-- equally on both sides of it.
local function radarShift()
    if not isWide() then return 0.0 end
    local panelW16 = (RADAR_H - BAR_STRIP_H) * (Config.WideAspect or 1.8) * 9.0 / 16.0
    return math.max(0.0, (panelW16 - RADAR_W16) / 2)
end

-- Horizontal stretch of the 'minimap' component (map + blips layer). GTA pins blips at that
-- layer's edges, so stretching it to the panel width lets them reach the panel's sides.
-- Map and blips stretch together, so they stay lined up.
local function radarStretch()
    if not isWide() or not Config.StretchRadar then return 1.0 end
    return (RADAR_W16 + 2 * radarShift()) / RADAR_W16
end

-- Radar area (where GTA draws/clamps blips) with our component layout
local function getRadarAnchor()
    local m, s = safeMargin(), aspectScale()
    return { x = m + radarShift() * s, y = 1.0 - m - RADAR_H - LIFT, w = RADAR_W16 * s, h = RADAR_H }
end

-- The radar mask texture is stretched over the minimap_blur component; this is the
-- largest area the map can be shown in.
local function getMaskBounds()
    local m, s, b = safeMargin(), aspectScale(), COMPONENTS.minimap_blur
    return { x = m + (b[1] + radarShift()) * s, y = (1.0 - m) - b[4] + b[2], w = b[3] * s, h = b[4] }
end

-- A layout made at another MinimapScale, rescaled around the safe-zone bottom-left corner
-- (the point the whole radar grows from), so saved / configured layouts stay lined up.
-- Layouts made with a different lift (e.g. before the status icons were turned on) are moved
-- up / down by the difference, so they stay on the map.
local function rescale(l, from)
    local k = SCALE / (tonumber(from) or 1.0)
    local d = (tonumber(l.lift) or 0.0) - LIFT
    local out = { x = l.x, y = l.y + d, w = l.w, h = l.h, px = l.px, py = l.py and l.py + d, scale = SCALE, lift = LIFT }
    if math.abs(k - 1.0) < 1e-6 then return out end
    local ox, oy = safeMargin(), 1.0 - safeMargin() - LIFT
    l = { x = out.x, y = out.y, w = out.w, h = out.h, px = out.px, py = out.py }
    out.x, out.y = ox + (l.x - ox) * k, oy - (oy - l.y) * k
    out.w, out.h = l.w * k, l.h * k
    if l.px then out.px = ox + (l.px - ox) * k end
    if l.py then out.py = oy - (oy - l.py) * k end
    return out
end

local function defaultLayout()
    local a = getRadarAnchor()
    local px, py = a.x + a.w * 0.5, a.y + a.h * PLAYER_Y

    if Config.Layout then
        local l = rescale(Config.Layout, Config.Layout.scale)
        l.px, l.py = l.px or px, l.py or py
        return l
    end

    -- Panel = GTA's map area (radar minus the bar strip). 'wide' also extends it equally on
    -- both sides (the radar is shifted to make room).
    local pad = radarShift() * aspectScale()
    return { x = a.x - pad, y = a.y, w = a.w + pad * 2, h = a.h - BAR_STRIP_H, px = px, py = py, scale = SCALE, lift = LIFT }
end

local function screenKey()
    local rx, ry = GetActiveScreenResolution()
    return ('%dx%d@%.3f:%s'):format(rx, ry, GetSafeZoneSize(), Config.Shape)
end

local function loadLayout()
    local saved = GetResourceKvpString(KVP_PREFIX .. screenKey())
    if saved then
        local ok, t = pcall(json.decode, saved)
        if ok and type(t) == 'table' and t.w and t.h and t.px and t.py then return rescale(t, t.scale) end
    end
    return defaultLayout()
end

-- ---------------------------------------------------------------------------
-- Runtime mask: a rounded rect cut exactly where the frame is
-- ---------------------------------------------------------------------------

local function maskAlpha(l)
    local rx, ry = GetActiveScreenResolution()
    local b = getMaskBounds()
    local bx, by, bw, bh = b.x * rx, b.y * ry, b.w * rx, b.h * ry
    local tsx, tsy = bw / MASK_W, bh / MASK_H            -- screen px per texel
    local aa = math.max(tsx, tsy)

    local fx, fy, fw, fh = l.x * rx, l.y * ry, l.w * rx, l.h * ry
    local hw, hh = fw / 2, fh / 2
    local cx, cy = fx + hw, fy + hh
    local r = math.min(fh * RADIUS, hw, hh)

    -- texel bounding box of the frame (+1 texel for anti-aliasing)
    local x0 = math.max(0, math.floor((fx - bx) / tsx) - 1)
    local x1 = math.min(MASK_W - 1, math.ceil((fx + fw - bx) / tsx) + 1)
    local y0 = math.max(0, math.floor((fy - by) / tsy) - 1)
    local y1 = math.min(MASK_H - 1, math.ceil((fy + fh - by) / tsy) + 1)

    local sqrt, max, min, abs, floor = math.sqrt, math.max, math.min, math.abs, math.floor
    local ix, iy = hw - r, hh - r

    local function at(tx, ty)
        local qx = abs(bx + (tx + 0.5) * tsx - cx) - ix
        local qy = abs(by + (ty + 0.5) * tsy - cy) - iy
        local ox, oy = max(qx, 0), max(qy, 0)
        local d = sqrt(ox * ox + oy * oy) + min(max(qx, qy), 0) - r
        local a = 0.5 - d / aa
        if a <= 0 then return 0 elseif a >= 1 then return 255 end
        return floor(a * 255 + 0.5)
    end

    return at, { x0 = x0, x1 = x1, y0 = y0, y1 = y1 }
end

local function buildMask(l)
    if not maskTex or not l then return end
    local at, box = maskAlpha(l)

    -- Fast path: upload the whole texture in one go. All four channels carry the same
    -- value, so channel order doesn't matter.
    if SetRuntimeTextureArgbData then
        local rows, zeroRow = {}, string.rep('\0', MASK_W * 4)
        local char, rep, concat = string.char, string.rep, table.concat
        for ty = 0, MASK_H - 1 do
            if ty < box.y0 or ty > box.y1 then
                rows[#rows + 1] = zeroRow
            else
                local row = { rep('\0', box.x0 * 4) }
                for tx = box.x0, box.x1 do
                    local v = at(tx, ty)
                    row[#row + 1] = char(v, v, v, v)
                end
                row[#row + 1] = rep('\0', (MASK_W - 1 - box.x1) * 4)
                rows[#rows + 1] = concat(row)
            end
        end
        local data = concat(rows)
        local ok, res = pcall(SetRuntimeTextureArgbData, maskTex, data, #data)
        if ok and res ~= false then
            CommitRuntimeTexture(maskTex)
            maskBox = box
            return
        end
    end

    -- Fallback: per-pixel writes over the union of the old and new frame areas
    local u = maskBox and {
        x0 = math.min(box.x0, maskBox.x0), x1 = math.max(box.x1, maskBox.x1),
        y0 = math.min(box.y0, maskBox.y0), y1 = math.max(box.y1, maskBox.y1),
    } or { x0 = 0, x1 = MASK_W - 1, y0 = 0, y1 = MASK_H - 1 }

    for ty = u.y0, u.y1 do
        local inY = ty >= box.y0 and ty <= box.y1
        for tx = u.x0, u.x1 do
            local v = (inY and tx >= box.x0 and tx <= box.x1) and at(tx, ty) or 0
            SetRuntimeTexturePixel(maskTex, tx, ty, v, v, v, v)
        end
    end
    CommitRuntimeTexture(maskTex)
    maskBox = box
end

-- ---------------------------------------------------------------------------
-- NUI sync
-- ---------------------------------------------------------------------------

-- Status icon row (Config.Status), drawn above the map panel
local function statusGeometry()
    if not (Config.Status and Config.Status.Enabled) then return nil end
    return { scale = tonumber(Config.Status.Size) or 1.0 }
end

local function applyLayout(l)
    l = l or loadLayout()
    buildMask(l)
    if not nuiReady then return end
    SendNUIMessage({
        type = 'layout',
        layout = l,
        bounds = getMaskBounds(),
        units = Config.Units,
        navScale = Config.NavScale,
        tint = Config.Tint,
        customArrow = Config.CustomPlayerArrow,
        tilt = Config.RadarTilt,
        stretch = radarStretch(),
        status = statusGeometry(),
    })
end

-- ---------------------------------------------------------------------------
-- Radar setup
-- ---------------------------------------------------------------------------

-- The radar setup only sticks once the player is actually in the game. Run during the
-- loading screen (which is when the resource starts on join), the big-map toggle below
-- can leave GTA's expanded radar stuck open: a huge unmasked map with no panel over it.
local function waitForGame()
    while GetIsLoadingScreenActive()
        or not NetworkIsPlayerActive(PlayerId())
        or IsPlayerSwitchInProgress()
        or not IsScreenFadedIn() do
        Wait(250)
    end
    Wait(500)
end

local function setupRadar()
    if not maskTex then
        local txd = CreateRuntimeTxd(TXD_NAME)
        maskTex = CreateRuntimeTexture(txd, 'radarmasksm', MASK_W, MASK_H)
    end
    buildMask(loadLayout())
    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', TXD_NAME, 'radarmasksm')

    SetMinimapClipType(0)
    -- The mask maths assumes the default component layout, so pin it (undoes other squaremaps)
    -- All three layers move by the same amount, so map, blips and route stay lined up.
    local shift, stretch = radarShift(), radarStretch()
    for name, v in pairs(COMPONENTS) do
        local x, w = v[1] + shift, v[3]
        if name == 'minimap' and stretch ~= 1.0 then
            local centre = x + w / 2 -- stretch around the centre so the player stays put
            w = w * stretch
            x = centre - w / 2
        end
        SetMinimapComponentPosition(name, 'L', 'B', x, v[2], w, v[4])
    end

    local c = Config.RouteColour
    ReplaceHudColourWithRgba(HUD_COLOUR_WAYPOINT, c.r, c.g, c.b, c.a)

    -- Toggling the big map forces the radar to rebuild with the new mask/positions
    SetRadarBigmapEnabled(true, false)
    Wait(50)
    SetRadarBigmapEnabled(false, false)
    -- Make sure it really closed again
    for _ = 1, 20 do
        if not IsBigmapActive() then break end
        SetRadarBigmapEnabled(false, false)
        Wait(50)
    end
end

-- (Re)apply the radar once the player is in the game. Also run on spawn / character load,
-- since spawning (and multicharacter scripts) can reset the radar after we set it up.
local radarBusy, radarAgain = false, false

local function refreshRadar()
    if radarBusy then radarAgain = true return end
    radarBusy = true
    CreateThread(function()
        repeat
            radarAgain = false
            waitForGame()
            setupRadar()
            lastScreen = screenKey()
            applyLayout()
        until not radarAgain
        radarBusy = false
    end)
end

refreshRadar()

AddEventHandler('playerSpawned', refreshRadar)
Bridge.OnPlayerLoaded(refreshRadar)

CreateThread(function()
    if Config.HideHealthArmour or Config.HideSatnavDistance then
        local scaleform = RequestScaleformMovie('minimap')
        while not HasScaleformMovieLoaded(scaleform) do Wait(0) end
        while true do
            if Config.HideHealthArmour then
                BeginScaleformMovieMethod(scaleform, 'SETUP_HEALTH_ARMOUR')
                ScaleformMovieMethodAddParamInt(3)
                EndScaleformMovieMethod()
            end
            if Config.HideSatnavDistance then
                -- GTA's own "0.21mi" GPS distance in the bottom-left of the radar
                BeginScaleformMovieMethod(scaleform, 'HIDE_SATNAV')
                EndScaleformMovieMethod()
            end
            Wait(0)
        end
    end
end)

-- Native player arrow: hidden normally (the minimap has the custom one), shown while editing so the
-- custom one can be lined up on it, and on GTA's full-screen map, which has no other player marker
local function applyPlayerBlip()
    if Config.CustomPlayerArrow then
        SetBlipAlpha(GetMainPlayerBlipId(), (editing or IsPauseMenuActive()) and 255 or 0)
    end
end

-- Pause menu / map opening and closing: switch the arrow straight away rather than on the 1s loop
CreateThread(function()
    if not Config.CustomPlayerArrow then return end
    local was = nil
    while true do
        local now = IsPauseMenuActive()
        if now ~= was then
            was = now
            applyPlayerBlip()
        end
        Wait(50)
    end
end)

-- Hide native north blip / player arrow (re-applied: respawns recreate them) and watch the screen
CreateThread(function()
    while true do
        SetBlipAlpha(GetNorthRadarBlip(), 0)
        applyPlayerBlip()

        local key = screenKey()
        if maskTex and key ~= lastScreen then
            lastScreen = key
            applyLayout()
        end
        Wait(1000)
    end
end)

-- ---------------------------------------------------------------------------
-- Per-frame data -> NUI
-- ---------------------------------------------------------------------------

-- Name shown in the bar above the map: the road you're on, or the area as a fallback
local function streetName(pos)
    local mode = Config.StreetBar
    if not mode then return nil end
    local name = ''
    if mode ~= 'zone' then
        local street = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
        if street and street ~= 0 then name = GetStreetNameFromHashKey(street) or '' end
    end
    if name == '' then
        local zone = GetLabelText(GetNameOfZone(pos.x, pos.y, pos.z))
        if zone and zone ~= 'NULL' then name = zone end
    end
    return name ~= '' and name or nil
end

-- Turn-by-turn from GTA's own satnav, GENERATE_DIRECTIONS_TO_COORD, used the way F5 Studio's
-- GTA VI HUD does (github.com/F5-Studio-FiveM/GTA-VI-HUD-FIVEM):
--   * aim it at the road node nearest the waypoint, not the waypoint itself (often off-road)
--   * ask twice a frame apart: the first answer can still be for the previous request
--   * code 0 shows up at random mid-drive: keep the last instruction
--   * the distance comes in tenths of a metre, and only means something on a turn; when a turn
--     reading has none, count down by how far we've driven
-- Codes: 1 recalculating, 2 follow the route, 3 left, 4 right, 5 straight, 6 sharp left,
-- 7 sharp right, 8 recalculating.
local NAV_KINDS = {
    [1] = 'recalc', [2] = 'follow', [3] = 'left', [4] = 'right', [5] = 'straight',
    [6] = 'sharpleft', [7] = 'sharpright', [8] = 'recalc',
}
local NAV_TURNS = { left = true, right = true, sharpleft = true, sharpright = true }
local ARRIVED_DIST = 25.0   -- metres from the waypoint's road node that count as arrived
local ANNOUNCE_DIST = 250.0 -- a turn is shown from this close; further out it's 'continue
local ANNOUNCE_TIME = 12.0  -- straight' for that distance (or this many seconds ahead at speed)

local navTurn -- what the card shows, nil = nothing

local function flat(a, b) return #(vector2(a.x, a.y) - vector2(b.x, b.y)) end

local function navTarget()
    local blip = IsWaypointActive() and GetFirstBlipInfoId(8) or 0
    if blip == 0 or not DoesBlipExist(blip) then return nil end
    local wp = GetBlipInfoIdCoord(blip)
    local found, node = GetClosestVehicleNode(wp.x, wp.y, wp.z, 1, 3.0, 0)
    return found and node or wp
end

CreateThread(function()
    local code, dist, prevPos = 0, 0.0, nil
    while true do
        Wait(200)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local pos = GetEntityCoords(ped)
        local target = (Config.Directions and veh ~= 0) and navTarget() or nil

        if not target then
            code, dist, navTurn = 0, 0.0, nil
        elseif flat(pos, target) < ARRIVED_DIST then
            code, dist, navTurn = 0, 0.0, { kind = 'arrived' }
        else
            GenerateDirectionsToCoord(target.x, target.y, target.z, true)
            Wait(0)
            local _, c, _, junction = GenerateDirectionsToCoord(target.x, target.y, target.z, true)
            c = math.floor(tonumber(c) or 0)
            if NAV_KINDS[c] then
                local metres = (tonumber(junction) or 0) / 10.0
                if not NAV_TURNS[NAV_KINDS[c]] then
                    dist = 0.0
                elseif metres > 0 then
                    dist = metres
                elseif c == code and prevPos then
                    dist = math.max(0.0, dist - flat(pos, prevPos))
                else
                    dist = 0.0
                end
                code = c
            end

            local kind = NAV_KINDS[code]
            if not kind then
                navTurn = nil
            elseif NAV_TURNS[kind] and dist > 0 then
                local announce = math.max(ANNOUNCE_DIST, GetEntitySpeed(veh) * ANNOUNCE_TIME)
                navTurn = dist > announce and { kind = 'straight', dist = dist } or { kind = kind, dist = dist }
            else
                navTurn = { kind = kind }
            end
        end
        prevPos = pos
    end
end)

-- /vihud_nav: what GTA's satnav says right now (F8 console), for when the card misbehaves
RegisterCommand('vihud_nav', function()
    local target = navTarget()
    if not target then return print('[vi-hud] no waypoint set') end
    local _, c, _, junction = GenerateDirectionsToCoord(target.x, target.y, target.z, true)
    print(('[vi-hud] satnav code=%s junction=%s (%.0f m)  route=%s m  card=%s'):format(
        tostring(c), tostring(junction), (tonumber(junction) or 0) / 10.0,
        tostring(GetGpsBlipRouteLength()), json.encode(navTurn or 'none')))
end, false)

local function nightFactor()
    local t = GetClockHours() + GetClockMinutes() / 60.0
    if t >= 7.0 and t <= 18.0 then return 0.0 end
    if t >= 20.0 or t <= 5.0 then return 1.0 end
    if t > 18.0 then return (t - 18.0) / 2.0 end
    return 1.0 - (t - 5.0) / 2.0
end

-- ---------------------------------------------------------------------------
-- Waypoint: GTA's marker stays on the pause map only; the radar gets our own pink circle
-- blip at the same spot. Because it's a real blip, GTA places it exactly on the tilted
-- map and pins it to the radar edge when the waypoint is off-screen.
-- ---------------------------------------------------------------------------

local wpBlip

local function removeWaypointBlip()
    if wpBlip and DoesBlipExist(wpBlip) then RemoveBlip(wpBlip) end
    wpBlip = nil
end

CreateThread(function()
    local style = Config.WaypointBlip
    local c = Config.RouteColour
    -- SetBlipColour also accepts a 0xRRGGBBAA value for an exact custom colour
    local rgba = (c.r << 24) | (c.g << 16) | (c.b << 8) | 0xFF
    local lastX, lastY

    while true do
        local native = IsWaypointActive() and GetFirstBlipInfoId(8) or 0
        if native ~= 0 and DoesBlipExist(native) then
            SetBlipDisplay(native, 3) -- 3 = pause map only (route is unaffected)
            local wp = GetBlipInfoIdCoord(native)

            if not wpBlip or not DoesBlipExist(wpBlip) then
                wpBlip = AddBlipForCoord(wp.x, wp.y, 0.0)
                SetBlipSprite(wpBlip, style.sprite)
                SetBlipColour(wpBlip, rgba)
                SetBlipScale(wpBlip, style.scale)
                -- No above/below variants: those swap the sprite and make it flicker
                ShowHeightOnBlip(wpBlip, false)
                if style.ring then
                    ShowOutlineIndicatorOnBlip(wpBlip, true)
                    SetBlipSecondaryColour(wpBlip, 255, 255, 255)
                end
                SetBlipDisplay(wpBlip, 5) -- 5 = radar only
                SetBlipAsShortRange(wpBlip, false) -- keep it pinned to the edge when off-screen
                SetBlipPriority(wpBlip, 13)
                SetBlipHiddenOnLegend(wpBlip, true)
                lastX, lastY = wp.x, wp.y
            elseif wp.x ~= lastX or wp.y ~= lastY then
                -- Only touch the blip when the waypoint actually moves
                SetBlipCoords(wpBlip, wp.x, wp.y, 0.0)
                lastX, lastY = wp.x, wp.y
            end
        elseif wpBlip then
            removeWaypointBlip()
        end
        Wait(250)
    end
end)

CreateThread(function()
    local nextSlow, nextNav = 0, 0
    local distance, night = nil, 0.0
    local street, turn = nil, nil
    local wasVisible = nil
    local radarForced = false -- we're hiding / showing the radar (vs leaving it to the game)

    while true do
        local ped = PlayerPedId()

        -- Minimap mode from the /hud menu (settings.lua): always / in vehicles / off
        local mode = HudSettings.Get('minimap.mode')
        local want = nil
        if not HudSettings.Shown('minimap') or mode == 'off' then
            want = false
        elseif mode == 'vehicle' then
            want = IsPedInAnyVehicle(ped, false)
        end
        if want ~= nil then
            DisplayRadar(want)
            radarForced = true
        elseif radarForced then
            DisplayRadar(true) -- back to 'always' after we had it hidden
            radarForced = false
        end

        local visible = editing or (
            not IsRadarHidden()
            and not IsPauseMenuActive()
            and not IsBigmapActive()
            and not IsHudHidden()
        )

        if visible then
            local pos = GetEntityCoords(ped)
            local inVehicle = IsPedInAnyVehicle(ped, false)
            local now = GetGameTimer()
            local slow = now >= nextSlow
            if slow then
                nextSlow = now + 500
                night = nightFactor()
                street = streetName(pos)
            end

            local waypoint = IsWaypointActive() and GetFirstBlipInfoId(8) or 0
            if waypoint ~= 0 and DoesBlipExist(waypoint) then
                if now >= nextNav or not distance then
                    nextNav = now + 250
                    local wp = GetBlipInfoIdCoord(waypoint)
                    local routeLen = GetGpsBlipRouteFound() and GetGpsBlipRouteLength() or 0
                    distance = routeLen > 0 and routeLen or #(vector2(wp.x, wp.y) - vector2(pos.x, pos.y))
                end
                turn = navTurn -- worked out by the satnav thread above
            else
                distance, turn = nil, nil
            end

            SendNUIMessage({
                type = 'update',
                visible = true,
                cam = GetGameplayCamRot(2).z,
                player = GetEntityHeading(ped),
                distance = distance,
                night = night,
                -- street bar + turn card only while in a vehicle
                street = inVehicle and street or nil,
                turn = inVehicle and turn or nil,
            })
            wasVisible = true
            Wait(33)
        else
            if wasVisible ~= false then
                SendNUIMessage({ type = 'update', visible = false })
                wasVisible = false
            end
            Wait(250)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Layout editor
-- ---------------------------------------------------------------------------

-- Opened from the /hud menu (settings.lua: Minimap > Edit layout), which comes back up when
-- the editor closes
local editFromMenu = false

function HudEditMinimap(fromMenu)
    if editing then return end
    editing, editFromMenu = true, fromMenu == true
    applyPlayerBlip()
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'edit', state = true })
end

-- Units / status icon size are part of the layout message
AddEventHandler('vi-hud:settingChanged', function(id)
    if id == 'units' or id == 'status.size' then applyLayout() end
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    applyLayout()
    cb({})
end)

-- Live preview while dragging: re-cut the mask to the frame being edited
RegisterNUICallback('preview', function(data, cb)
    if type(data) == 'table' and type(data.layout) == 'table' then
        buildMask(data.layout)
    end
    cb({})
end)

RegisterNUICallback('reset', function(_, cb)
    DeleteResourceKvp(KVP_PREFIX .. screenKey())
    local l = defaultLayout()
    buildMask(l)
    cb({ layout = l })
end)

-- Closing the editor; `data.layout` is present when the user pressed Save
RegisterNUICallback('close', function(data, cb)
    if type(data) == 'table' and type(data.layout) == 'table' then
        data.layout.scale = SCALE -- remember the size it was made at
        data.layout.lift = LIFT   -- ...and how far the radar was lifted
        SetResourceKvp(KVP_PREFIX .. screenKey(), json.encode(data.layout))
    end
    editing = false
    applyPlayerBlip()
    SetNuiFocus(false, false)
    applyLayout()
    cb({})
    if editFromMenu then
        editFromMenu = false
        TriggerEvent('vi-hud:openSettings')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
    for name, v in pairs(BASE_COMPONENTS) do
        SetMinimapComponentPosition(name, 'L', 'B', v[1], v[2], v[3], v[4])
    end
    SetBlipAlpha(GetNorthRadarBlip(), 255)
    SetBlipAlpha(GetMainPlayerBlipId(), 255)
    removeWaypointBlip()
    local waypoint = GetFirstBlipInfoId(8)
    if waypoint ~= 0 and DoesBlipExist(waypoint) then SetBlipDisplay(waypoint, 2) end
    if editing then SetNuiFocus(false, false) end
end)
