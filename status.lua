-- Status icons above the minimap (health, armour, stamina, hunger, thirst, oxygen). See Config.Status.

local ST = Config.Status
if not ST or not ST.Enabled then return end

-- Hunger / thirst come from the framework (see bridge.lua). -1 = not available.
local needs = Bridge.Needs

local function pct(v)
    return math.floor(math.max(0.0, math.min(100.0, v)) + 0.5)
end

local maxO2 = 10.0 -- seconds of air; grows if the player's lung capacity allows more
local lastSent = {}

-- Only icons that matter right now are shown; each stays up for ST.Linger ms after it's back
-- to normal so it doesn't flicker. Hidden icons are sent as -1.
local activeUntil = {}

local function shown(name, value, active, now)
    if value < 0 then return -1 end
    if ST.AlwaysShow then return value end
    if active then activeUntil[name] = now + (ST.Linger or 2000) end
    return now < (activeUntil[name] or 0) and value or -1
end

local function push(msg)
    local changed = false
    for k, v in pairs(msg) do
        if lastSent[k] ~= v then changed = true break end
    end
    if not changed then return end
    lastSent = msg
    SendNUIMessage({ type = 'status', state = msg })
end

CreateThread(function()
    while true do
        local ped, pid = PlayerPedId(), PlayerId()
        local show = not IsPauseMenuActive() and not IsHudHidden() and HudSettings.Shown('status')

        if not show then
            push({ show = false })
            Wait(250)
        else
            local maxHp = GetEntityMaxHealth(ped)
            local health = maxHp > 100 and (GetEntityHealth(ped) - 100) / (maxHp - 100) * 100
                or GetEntityHealth(ped) / math.max(1, maxHp) * 100

            local air = GetPlayerUnderwaterTimeRemaining(pid)
            if air > maxO2 then maxO2 = air end
            local underwater = IsPedSwimmingUnderWater(ped)

            local now = GetGameTimer()
            local hp = pct(health)
            local armour = pct(GetPedArmour(ped))
            local stamina = pct(100.0 - GetPlayerSprintStaminaRemaining(pid)) -- native counts stamina *used*
            local oxygen = pct(air / maxO2 * 100)
            local needsAt = ST.ShowNeedsBelow or 50

            push({
                show = true,
                -- radar off (e.g. Config.OnlyInVehicle on foot): row drops into the map's spot
                noMap = IsRadarHidden(),
                drop = ST.NoMapDrop or 0.55,
                health = shown('health', hp, hp < 100, now),
                armour = shown('armour', armour, armour > 0, now),
                stamina = shown('stamina', stamina, stamina < 100, now),
                hunger = shown('hunger', needs.hunger, needs.hunger <= needsAt, now),
                thirst = shown('thirst', needs.thirst, needs.thirst <= needsAt, now),
                oxygen = shown('oxygen', oxygen, underwater or oxygen < 100, now),
            })
            Wait(ST.UpdateRate or 200)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SendNUIMessage({ type = 'status', state = { show = false } })
end)
