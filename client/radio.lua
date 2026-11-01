-- GTA VI style radio station strip (replaces GTA's radio wheel). See Config.Radio.

local R = Config.Radio
if not R or not R.Enabled then return end

local CONTROL_WHEEL = 85                   -- INPUT_VEH_RADIO_WHEEL (Q / D-pad left)
local CONTROL_NEXT, CONTROL_PREV = 81, 82  -- INPUT_VEH_NEXT_RADIO / PREV ('.' / ',')

-- Everything the mouse/stick/scroll wheel would otherwise do while the strip is open
local BLOCK_WHILE_OPEN = {
    1, 2,                   -- look (mouse / right stick)
    14, 15, 16, 17, 99, 100, 241, 242, -- scroll wheel weapon switching
    24, 25, 68, 69, 70, 91, 92, 114, -- attack / aim (incl. vehicle + passenger)
    174, 175, 201,          -- arrows / accept
}
local PREV_KEYS = { 15, 17, 241, 174, CONTROL_PREV } -- scroll up, left arrow, ','
local NEXT_KEYS = { 14, 16, 242, 175, CONTROL_NEXT } -- scroll down, right arrow, '.'
local MUTE_KEYS = { 25, 68, 70, 91 }                 -- right mouse button (on foot / vehicle / passenger)

local stations, indexOf, listKey = {}, {}, ''
local open, sel, muted = false, 1, false
local hideAt = 0
local lastStation        -- last station that was on (used when coming back from mute)
local lastSent = {}

-- ---------------------------------------------------------------------------
-- Stations
-- ---------------------------------------------------------------------------

local function sendStations()
    SendNUIMessage({ type = 'radio', action = 'stations', stations = stations })
end

local function buildStations()
    local hidden = {}
    for _, n in ipairs(R.Hidden or {}) do hidden[n] = true end

    local list, names = {}, {}
    for i = 0, GetNumUnlockedRadioStations() - 1 do
        local name = GetRadioStationName(i)
        if name and name ~= '' and not hidden[name] then
            local label = GetLabelText(name)
            if not label or label == '' or label == 'NULL' then label = name end
            list[#list + 1] = { name = name, label = label }
            names[#names + 1] = name
        end
    end

    local key = table.concat(names, ',')
    if key == listKey then return end
    stations, listKey, indexOf = list, key, {}
    for i, s in ipairs(list) do indexOf[s.name] = i end
    sendStations()
end

local function playingStation()
    local name = GetPlayerRadioStationName()
    if not name or name == '' or name == 'OFF' then return nil end
    return name
end

-- Song + artist of what's audible right now (GTA keeps them as text labels "<id>S" / "<id>A")
local function trackInfo()
    local id = GetAudibleMusicTrackTextId()
    if not id or id <= 0 then return nil, nil end
    local title, artist = GetLabelText(id .. 'S'), GetLabelText(id .. 'A')
    if title == 'NULL' or title == '' then return nil, nil end
    if artist == 'NULL' or artist == '' then artist = nil end
    return title, artist
end

-- Point the selection at what's playing
local function syncSelection()
    local playing = playingStation()
    muted = playing == nil
    sel = indexOf[playing] or indexOf[lastStation] or sel
    if sel < 1 or sel > #stations then sel = 1 end
end

local function click(name)
    if R.Sounds then PlaySoundFrontend(-1, name, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
end

local function move(step)
    if #stations == 0 then return end
    if muted then
        muted = false -- first step out of mute lands back on the highlighted station
    else
        sel = (sel - 1 + step) % #stations + 1
    end
    click('NAV_LEFT_RIGHT')
end

-- What should be playing once the current selection is applied (nil = off)
local function expectedStation()
    if muted then return nil end
    local s = stations[sel]
    return s and s.name
end

local function apply(veh)
    local playing = playingStation()
    if muted then
        if playing then SetVehRadioStation(veh, 'OFF') end
        return
    end
    local s = stations[sel]
    if s and s.name ~= playing then
        SetVehRadioStation(veh, s.name)
        SetRadioToStationName(s.name)
    end
end

-- ---------------------------------------------------------------------------
-- NUI
-- ---------------------------------------------------------------------------

local function push(show, title, artist)
    local msg = {
        show = show,
        sel = sel - 1,
        muted = muted,
        playing = playingStation(),
        title = title,
        artist = artist,
    }
    local changed = false
    for _, k in ipairs({ 'show', 'sel', 'muted', 'playing', 'title', 'artist' }) do
        if lastSent[k] ~= msg[k] then changed = true break end
    end
    if not changed then return end
    lastSent = msg
    SendNUIMessage({ type = 'radio', action = 'state', state = msg })
end

RegisterNUICallback('radioReady', function(_, cb)
    listKey = ''
    buildStations()
    lastSent = {}
    cb({})
end)

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Weapon select pop-up (HUD component 19) position
-- ---------------------------------------------------------------------------

local HUD_WEAPON_WHEEL = 19
local wheelHome   -- GTA's own position, read before we move it
local lowerWheelUntil = 0

local function lowerWheel()
    if not wheelHome then wheelHome = GetHudComponentPosition(HUD_WEAPON_WHEEL) end
    SetHudComponentPosition(HUD_WEAPON_WHEEL, wheelHome.x, wheelHome.y + (R.WeaponWheelOffset or 0.08))
end

local function restoreWheel()
    if not wheelHome then return end
    ResetHudComponentValues(HUD_WEAPON_WHEEL)
    wheelHome = nil
end

local function anyJustPressed(list)
    for i = 1, #list do
        if IsDisabledControlJustPressed(0, list[i]) then return true end
    end
    return false
end

CreateThread(function()
    local lastVeh = nil -- nil until the first check after the resource starts
    local quietUntil, enterShowAt = 0, 0
    local prevPlaying
    local accX, padDir, padNext = 0.0, 0, 0
    local nextTrack, title, artist = 0, nil, nil

    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh == 0 or not DoesPlayerVehHaveRadio() then
            if open or hideAt ~= 0 then
                open, hideAt = false, 0
            end
            push(false)
            restoreWheel()
            lowerWheelUntil = 0
            lastVeh = 0
            Wait(250)
        else
            local now = GetGameTimer()

            -- Kill GTA's own wheel + station name popup
            HideHudComponentThisFrame(16)
            DisableControlAction(0, CONTROL_WHEEL, true)
            DisableControlAction(0, CONTROL_NEXT, true)
            DisableControlAction(0, CONTROL_PREV, true)

            if veh ~= lastVeh then
                buildStations()
                quietUntil = now + 1500 -- the radio takes a moment to start; don't treat that as a change
                -- lastVeh == nil means the resource just started while already in a car: stay hidden
                enterShowAt = (R.ShowOnEnter and lastVeh ~= nil) and now + 700 or 0
                lastVeh = veh
            end

            local playing = playingStation()
            if playing then lastStation = playing end

            local blocked = IsPauseMenuActive() or IsHudHidden()
            local held = IsDisabledControlPressed(0, CONTROL_WHEEL) and not blocked

            if held then
                if not open then
                    open = true
                    syncSelection()
                    accX, padDir = 0.0, 0
                    click('NAV_UP_DOWN')
                end

                for i = 1, #BLOCK_WHILE_OPEN do DisableControlAction(0, BLOCK_WHILE_OPEN[i], true) end

                local step = 0
                if anyJustPressed(PREV_KEYS) then step = -1 elseif anyJustPressed(NEXT_KEYS) then step = 1 end

                local x = GetDisabledControlNormal(0, 1)
                if IsUsingKeyboard(0) then
                    accX = accX + x
                    if accX > R.MouseStep then step, accX = 1, 0.0
                    elseif accX < -R.MouseStep then step, accX = -1, 0.0 end
                elseif math.abs(x) > 0.6 then
                    local dir = x > 0 and 1 or -1
                    if padDir ~= dir then
                        padDir, padNext, step = dir, now + 350, dir
                    elseif now >= padNext then
                        padNext, step = now + 140, dir
                    end
                else
                    padDir = 0
                end

                if step ~= 0 then move(step) end

                if anyJustPressed(MUTE_KEYS) or (not IsUsingKeyboard(0) and IsDisabledControlJustPressed(0, 201)) then
                    muted = not muted
                    click('SELECT')
                end
            elseif open then
                open = false
                apply(veh)
                prevPlaying = expectedStation()
                quietUntil = now + 1000 -- GTA can still report the old station for a moment
                hideAt = now + R.ShowTime
            elseif not blocked then
                -- Quick skip with ',' / '.'
                local step = IsDisabledControlJustPressed(0, CONTROL_NEXT) and 1
                    or IsDisabledControlJustPressed(0, CONTROL_PREV) and -1 or 0
                if step ~= 0 then
                    syncSelection()
                    move(step)
                    apply(veh)
                    prevPlaying = expectedStation()
                    quietUntil = now + 1000
                    hideAt = now + R.ShowTime
                elseif playing ~= prevPlaying then
                    -- Changed by something else (another script, vehicle swap...)
                    prevPlaying = playing
                    if R.ShowOnChange and now >= quietUntil then
                        syncSelection()
                        hideAt = now + R.ShowTime
                    end
                end
            end

            if enterShowAt ~= 0 and now >= enterShowAt then
                enterShowAt = 0
                if playing and not open then
                    syncSelection()
                    hideAt = now + R.ShowTime
                end
            end

            local show = not blocked and (open or now < hideAt)
            if show then
                if now >= nextTrack then
                    nextTrack = now + 500
                    title, artist = trackInfo()
                end
            else
                title, artist, nextTrack = nil, nil, 0
                if not open and hideAt ~= 0 and now >= hideAt then hideAt = 0 end
            end
            push(show, title, artist)

            -- Push GTA's weapon select pop-up down so it doesn't cover the strip. Stays lowered a
            -- moment after the strip hides so a pop-up that's still fading out doesn't jump up.
            if show then lowerWheelUntil = now + 1500 end
            if now < lowerWheelUntil then lowerWheel() else restoreWheel() end

            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SendNUIMessage({ type = 'radio', action = 'state', state = { show = false } })
    restoreWheel()
end)
