-- Microphone icon in the status row (status.js draws it). See Config.Voice.
-- Works with FiveM's built-in voice (Mumble), so pma-voice and anything else built on it.
-- pma-voice extras: the proximity range (whisper / normal / shout) and radio transmissions.

local V = Config.Voice
if not V or not V.Enabled then return end

local radioOn = false
AddEventHandler('pma-voice:radioActive', function(on) radioOn = on and true or false end)

-- pma-voice keeps the current range on the player's state bag: { index, distance, mode }.
-- Returned as how full the ring is: 1/3 whisper, 2/3 normal, full shout. No pma-voice = full.
local function level()
    local p = LocalPlayer.state.proximity
    if type(p) == 'table' and type(p.index) == 'number' then
        return math.floor(math.max(1, math.min(3, p.index)) / 3 * 1000 + 0.5) / 1000
    end
    return 1.0
end

local last = {}
local talkUntil = 0

local function push(msg)
    local changed = false
    for k, v in pairs(msg) do
        if last[k] ~= v then changed = true break end
    end
    if not changed then return end
    last = msg
    msg.type = 'mic'
    SendNUIMessage(msg)
end

CreateThread(function()
    while true do
        if IsPauseMenuActive() or IsHudHidden() or not HudSettings.Shown('mic')
            or HudSettings.Get('mic.mode') == 'off' then
            push({ show = false })
            Wait(250)
        else
            local pid = PlayerId()
            local connected = MumbleIsConnected()
            local talking = connected and NetworkIsPlayerTalking(pid) or false
            local now = GetGameTimer()
            if talking then talkUntil = now + (V.Linger or 1500) end

            push({
                show = true,
                state = not connected and 'off'
                    or (talking and radioOn) and 'radio'
                    or talking and 'talk'
                    or 'idle',
                level = V.ShowRange ~= false and level() or 1.0,
                -- AlwaysShow = false: only while talking (+ Linger), or when voice is down
                visible = V.AlwaysShow ~= false or not connected or now < talkUntil,
            })
            Wait(V.UpdateRate or 100)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SendNUIMessage({ type = 'mic', show = false })
end)
