-- GTA VI style pause menu: Esc opens it in place of GTA's own (html/pause.js). See Config.PauseMenu.
-- Map / Settings / Key Bindings still open GTA's own screens (those can't be redrawn); backing
-- out of them, or out of the /hud menu, comes back here.
--
-- While it's open IsPauseMenuActive() (for this resource) reports true, so every part of the HUD
-- that hides in GTA's pause menu hides in this one too.
--
-- Other files / scripts use:
--   PauseMenuOpen                                  true while it's on screen (or one of GTA's screens opened from it)
--   exports['vi-hud']:BlockPauseMenu(true / false) stop Esc from opening it (e.g. while your UI uses Esc)
--   exports['vi-hud']:OpenPauseMenu() / ClosePauseMenu() / IsPauseMenuOpen()

PauseMenuOpen = false

local P = Config.PauseMenu or {}
if not P.Enabled then return end

local ESC = 200     -- INPUT_FRONTEND_PAUSE_ALTERNATE; P (199) still opens GTA's map
local SOUNDSET = 'HUD_FRONTEND_DEFAULT_SOUNDSET'

-- Everything in this resource that checks the pause menu also sees ours
local GameMenuActive = IsPauseMenuActive
function IsPauseMenuActive() return PauseMenuOpen or GameMenuActive() end

-- "FiveM" in the header of GTA's map / settings screens -> the server's title
if P.Title and P.Title ~= '' then AddTextEntry('FE_THDR_GTAO', P.Title) end

-- GTA screens the tiles open
local FRONTEND = {
    map = GetHashKey('FE_MENU_VERSION_MP_PAUSE'),
    settings = GetHashKey('FE_MENU_VERSION_LANDING_MENU'),
    keys = GetHashKey('FE_MENU_VERSION_LANDING_KEYMAPPING_MENU'),
}

-- ---------------------------------------------------------------------------
-- Tiles
-- ---------------------------------------------------------------------------

local BUTTONS = {
    { id = 'resume', label = 'Resume' },
    { id = 'map', label = 'Map' },
    { id = 'hud', label = 'HUD' },
    { id = 'settings', label = 'Settings' },
    { id = 'keys', label = 'Key Bindings' },
}

-- Config.PauseMenu.Buttons: small link buttons in the bottom-right corner, not main tiles
local LINKS = {}
local EXTRA = {}
for i, b in ipairs(P.Buttons or {}) do
    if type(b) == 'table' and b.label then
        local id = 'x' .. i
        EXTRA[id] = b
        LINKS[#LINKS + 1] = { id = id, label = b.label, fa = b.icon, url = b.url, keepOpen = b.keepOpen == true }
    end
end

if P.LeaveButton ~= false then
    BUTTONS[#BUTTONS + 1] = { id = 'leave', label = 'Leave', danger = true }
end

-- ---------------------------------------------------------------------------
-- Player card (top-right)
-- ---------------------------------------------------------------------------

local ch = {} -- character name / job, pulled from the framework once per opening

-- fresh = re-read the character (on open); the once-a-second refresh only updates the money
local function info(fresh)
    if fresh then ch = Bridge.Character() end
    return {
        name = ch.name or GetPlayerName(PlayerId()),
        job = ch.job,
        id = GetPlayerServerId(PlayerId()),
        cash = Bridge.Money.cash,
        bank = Bridge.Money.bank,
    }
end

-- Character portrait: a ped headshot, shown by the page through nui-img
local headshot = 0

local function freeHeadshot()
    if headshot ~= 0 then
        UnregisterPedheadshot(headshot)
        headshot = 0
    end
end

-- ---------------------------------------------------------------------------
-- Open / close
-- ---------------------------------------------------------------------------

local open = false
local blocked = false
local token = 0           -- bumps on every open / close, so a late headshot isn't shown
local closedAt, focusAt = 0, 0
local frontendReturn = false -- one of GTA's screens is up, opened from here
local frontendSeen, frontendDeadline = false, 0
local hudReturn = false   -- the /hud menu is up, opened from here

local function sound(name)
    if P.Sounds ~= false then PlaySoundFrontend(-1, name, SOUNDSET, true) end
end

local function loadHeadshot(t)
    freeHeadshot()
    local h = RegisterPedheadshotTransparent(PlayerPedId())
    local deadline = GetGameTimer() + 3000
    while not (IsPedheadshotReady(h) and IsPedheadshotValid(h)) do
        if t ~= token or GetGameTimer() > deadline then
            UnregisterPedheadshot(h)
            return
        end
        Wait(50)
    end
    if t ~= token then
        UnregisterPedheadshot(h)
        return
    end
    headshot = h
    local txd = GetPedheadshotTxdString(h)
    SendNUIMessage({ type = 'pause', action = 'avatar', url = ('https://nui-img/%s/%s'):format(txd, txd) })
end

local function openMenu()
    if open then return end
    open, PauseMenuOpen = true, true
    token = token + 1
    SetNuiFocus(true, true)
    if P.Blur ~= false then TriggerScreenblurFadeIn(150) end
    SendNUIMessage({
        type = 'pause',
        action = 'open',
        title = P.Title or '',
        heading = P.Heading or '',
        buttons = BUTTONS,
        links = LINKS,
        info = info(true),
    })
    sound('SELECT')
    if P.Headshot ~= false then
        local t = token
        CreateThread(function() loadHeadshot(t) end)
    end
end

-- instant = no blur fade-out (GTA's own screen is about to take over)
-- keepPage = leave the page on screen (input goes back to the game); openFrontend hides it later
local function closeMenu(instant, keepPage)
    if not open then return end
    open, PauseMenuOpen = false, false
    token = token + 1
    closedAt = GetGameTimer()
    SetNuiFocus(false, false)
    if not keepPage then SendNUIMessage({ type = 'pause', action = 'close' }) end
    if P.Blur ~= false then TriggerScreenblurFadeOut(instant and 0 or 150) end
    freeHeadshot()
end

-- ---------------------------------------------------------------------------
-- GTA's screens opened from here. GTA draws them; the page (html/mapui.*) covers GTA's key bar
-- with its own, plus on the map the scale bar / area box (waypoint card), and on Settings / Key
-- Bindings the white title bar (our header)
-- ---------------------------------------------------------------------------

local mapMode = false     -- in GTA's full-screen map, opened from the Map tile or P
local returnTo = 'menu'   -- where leaving GTA's screen goes: 'menu' (this menu) or 'game' (opened with P)

-- metres -> { '1.2', 'mi' } in the server's units (Config.Units, /hud > Distance units)
local function distance(m)
    if Config.Units == 'km' then
        if m < 1000 then return { ('%d'):format(math.floor(m / 10 + 0.5) * 10), 'm' } end
        return { ('%.1f'):format(m / 1000), 'km' }
    end
    local mi = m / 1609.344
    if mi < 0.1 then return { ('%d'):format(math.floor(m * 3.28084 / 10 + 0.5) * 10), 'ft' } end
    return { ('%.1f'):format(mi), 'mi' }
end

-- Waypoint distance for the map's card (route length, or straight line while there's no route)
local function mapInfo()
    local out = {}
    local wp, w = HudWaypoint() -- client.lua
    if wp then
        local c = GetEntityCoords(PlayerPedId())
        local len = GetGpsBlipRouteFound() and GetGpsBlipRouteLength() or 0
        if len <= 0 then len = #(vector2(c.x, c.y) - vector2(w.x, w.y)) end
        local d = distance(len)
        out.wp = { dist = d[1], unit = d[2] }
    end
    return out
end

-- The page's frame over GTA's screen (html/mapui.*): mode 'map' (waypoint card + map keys) or
-- 'settings' / 'keys' (our header over GTA's white title bar + menu keys); nil = hide
local function frameUi(mode)
    if not mode then
        SendNUIMessage({ type = 'mapui', show = false })
        return
    end
    SendNUIMessage({
        type = 'mapui', show = true, mode = mode,
        info = mode == 'map' and mapInfo() or nil,
        m = math.floor(0.5 * math.abs(GetSafeZoneSize() - 1.0) * 10000 + 0.5) / 10000,
    })
end

-- Opens one of GTA's screens. The page stays up over it until it's ready, so GTA's tab header
-- never flashes on screen. mode = 'map' (steps from the Map tab straight into the full-screen
-- map), 'settings' or 'keys': which frame goes around it.
-- back = 'menu' (default) returns to this menu afterwards, 'game' straight to the game.
local function openFrontend(hash, mode, back)
    closeMenu(true, true)
    PauseMenuOpen = true -- the HUD stays hidden in between
    frontendReturn, frontendSeen, mapMode = true, false, false
    returnTo = back or 'menu'
    frontendDeadline = GetGameTimer() + 1500
    ActivateFrontendMenu(hash, false, -1)

    CreateThread(function()
        local deadline = GetGameTimer() + 1500
        while not (GameMenuActive() and IsFrontendReadyForControl()) and GetGameTimer() < deadline do
            Wait(0)
        end
        if GameMenuActive() then
            if mode == 'map' then
                PauseMenuceptionGoDeeper(0) -- = Enter on the MAP tab
                mapMode = true
                Wait(120)                   -- let the map finish expanding before the page fades
                if mapMode and GameMenuActive() then frameUi('map') end
            elseif mode then
                frameUi(mode)
            end
        end
        if not open then SendNUIMessage({ type = 'pause', action = 'close' }) end
    end)
end

-- Back (Esc / Backspace / right click) in the full-screen map: GTA would drop to its own tab
-- screen, so shut GTA's menu instead; the main loop then brings this one back
local MAP_BACK = { 200, 202, 177 }
local function mapBackPressed()
    for _, c in ipairs(MAP_BACK) do
        DisableControlAction(2, c, true)
        if IsDisabledControlJustPressed(2, c) or IsDisabledControlJustPressed(0, c) then return true end
    end
    return false
end

-- Player controls (on foot + every vehicle) switched off while the menu or one of GTA's screens
-- opened from it is up, so WASD / mouse / Shift... don't drive, walk or shoot underneath. Only the
-- player group (0) is touched: GTA's screens read their own frontend controls.
local PLAYER_CONTROLS = {
    1, 2, 3, 4, 5, 6,                               -- look
    21, 22, 23, 24, 25, 26, 27, 36, 37, 44, 45, 47, -- sprint, jump, enter, attack, aim, look behind, phone, duck, weapon wheel, cover, reload, detonate
    140, 141, 142, 143, 257, 263, 264,              -- melee
    244, 245, 246,                                  -- interaction menu, chat
}
for c = 30, 35 do PLAYER_CONTROLS[#PLAYER_CONTROLS + 1] = c end   -- walk
for c = 59, 139 do PLAYER_CONTROLS[#PLAYER_CONTROLS + 1] = c end  -- cars, bikes, boats, aircraft, parachute
for c = 278, 285 do PLAYER_CONTROLS[#PLAYER_CONTROLS + 1] = c end -- submarine / vehicle extras

local function blockPlayer()
    for i = 1, #PLAYER_CONTROLS do DisableControlAction(0, PLAYER_CONTROLS[i], true) end
end

local function canOpen(now)
    return not blocked
        and not WeaponWheelOpen
        and not IsNuiFocused()
        and now - focusAt > 300   -- Esc that just closed another UI
        and now - closedAt > 250
        and not IsPlayerSwitchInProgress()
        and not GetIsLoadingScreenActive()
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

CreateThread(function()
    local nextInfo = 0
    while true do
        local now = GetGameTimer()

        if open then
            HideHudAndRadarThisFrame()
            blockPlayer()
            DisableControlAction(0, ESC, true)
            DisableControlAction(0, 199, true)
            if now >= nextInfo then
                nextInfo = now + 1000
                SendNUIMessage({ type = 'pause', action = 'info', info = info() })
            end
        elseif frontendReturn then
            -- Wait for GTA's screen to come up and go again (or not come up at all), then back here
            blockPlayer()
            if GameMenuActive() then
                frontendSeen = true
                if mapMode then
                    if mapBackPressed() then
                        mapMode = false
                        frameUi(nil)
                        SetFrontendActive(false)
                    elseif now >= nextInfo then
                        nextInfo = now + 500
                        SendNUIMessage({ type = 'mapui', show = true, info = mapInfo() })
                    end
                end
            elseif frontendSeen or now > frontendDeadline then
                frameUi(nil)
                frontendReturn, PauseMenuOpen, mapMode = false, false, false
                if returnTo == 'menu' then
                    openMenu()
                else
                    closedAt = now
                    SendNUIMessage({ type = 'pause', action = 'close' })
                end
                nextInfo = 0
            end
        else
            if IsNuiFocused() then focusAt = now end
            if not GameMenuActive() then
                DisableControlAction(0, ESC, true) -- GTA's pause menu stays shut
                -- P (keyboard): straight into the map, with this menu's look; Back goes to the game
                local mapKey = P.MapKey ~= false and IsUsingKeyboard(0)
                if mapKey then DisableControlAction(0, 199, true) end
                if IsDisabledControlJustPressed(0, ESC) and canOpen(now) then
                    openMenu()
                    nextInfo = now + 1000
                elseif mapKey and IsDisabledControlJustPressed(0, 199) and canOpen(now) then
                    sound('SELECT')
                    openFrontend(FRONTEND.map, 'map', 'game')
                    nextInfo = 0
                end
            end
        end

        Wait(0)
    end
end)

-- ---------------------------------------------------------------------------
-- Page -> game
-- ---------------------------------------------------------------------------

local SOUNDS = { move = 'NAV_LEFT_RIGHT', select = 'SELECT', back = 'BACK', error = 'ERROR' }

RegisterNUICallback('pauseSound', function(data, cb)
    local s = type(data) == 'table' and SOUNDS[data.name]
    if s then sound(s) end
    cb({})
end)

RegisterNUICallback('pauseAction', function(data, cb)
    cb({})
    local id = type(data) == 'table' and data.id
    if not open or type(id) ~= 'string' then return end

    if id == 'resume' then
        sound('BACK')
        closeMenu()
    elseif FRONTEND[id] then
        sound('SELECT')
        openFrontend(FRONTEND[id], id)
    elseif id == 'hud' then
        sound('SELECT')
        closeMenu()
        hudReturn = true
        HudSettings.Open()
    elseif id == 'leave' and P.LeaveButton ~= false then
        closeMenu()
        TriggerServerEvent('vi-hud:leave')
    elseif EXTRA[id] then
        local b = EXTRA[id]
        sound('SELECT')
        if not b.keepOpen then closeMenu() end
        local args = type(b.args) == 'table' and b.args or {}
        if b.command then ExecuteCommand(b.command) end
        if b.event then TriggerEvent(b.event, table.unpack(args)) end
        if b.serverEvent then TriggerServerEvent(b.serverEvent, table.unpack(args)) end
        -- b.url is opened by the page
    end
end)

-- /hud closed: back to this menu if it was opened from here
AddEventHandler('vi-hud:settingsClosed', function()
    if not hudReturn then return end
    hudReturn = false
    openMenu()
end)

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------

exports('BlockPauseMenu', function(state) blocked = state == true end)
exports('OpenPauseMenu', openMenu)
exports('ClosePauseMenu', function() closeMenu() end)
exports('IsPauseMenuOpen', function() return open end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    freeHeadshot()
    if open then
        SetNuiFocus(false, false)
        TriggerScreenblurFadeOut(0)
    end
end)
