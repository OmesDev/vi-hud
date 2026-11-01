-- GTA VI style speedometer, bottom-right while driving. See Config.Speedometer.

local S = Config.Speedometer
if not S or not S.Enabled then return end

-- Style and units can change from the /hud menu (settings.lua), so they're read every update
local function unitsNow() return S.Units or (Config.Units == 'km' and 'kmh' or 'mph') end

-- Vehicle classes without a gearbox / rev counter worth showing
local NO_GEAR = { [13] = true, [15] = true, [16] = true, [21] = true } -- cycles, helis, planes, trains
local NO_RPM = { [13] = true, [21] = true }
local FLYING = { [15] = true, [16] = true } -- helis, planes: altitude readout in the minimal style

local lastSent = {}

local function send(msg)
    local changed = false
    for k, v in pairs(msg) do
        if lastSent[k] ~= v then changed = true break end
    end
    if not changed then return end
    for k, v in pairs(msg) do lastSent[k] = v end
    msg.type = 'speedo'
    SendNUIMessage(msg)
end

local function hide()
    if lastSent.show ~= false then
        lastSent = { show = false }
        SendNUIMessage({ type = 'speedo', show = false })
    end
end

local function gearOf(veh, speed)
    local gear = GetVehicleCurrentGear(veh)
    if gear == 0 then
        return 'R'
    end
    if speed < 0.5 then return 'N' end
    return tostring(gear)
end

local function engineOf(veh)
    -- Engine health runs 1000 (perfect) down to 0 (dead) and below (on fire)
    return math.floor(math.max(0.0, math.min(1000.0, GetVehicleEngineHealth(veh))) / 10 + 0.5)
end

local function fuelOf(veh)
    -- Fuel scripts (LegacyFuel, ox_fuel, cdn-fuel, ps-fuel, ...) keep the level as 0-100 on the vehicle
    if GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume') <= 0.0 then return -1 end
    return math.floor(math.max(0.0, math.min(100.0, GetVehicleFuelLevel(veh))) + 0.5)
end

-- Seatbelt state from the seatbelt script (see bridge.lua: esx_cruisecontrol, qb-smallresources,
-- qbx_seatbelt or the SetSeatbelt export).
-- 1 = buckled, 0 = not, -1 = hide the icon (no seatbelts in this vehicle / script not running)
local BELT_CLASSES = { -- classes that have seatbelts (no bikes, boats, aircraft...)
    [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true,
    [9] = true, [10] = true, [11] = true, [12] = true, [17] = true, [18] = true, [19] = true, [20] = true,
}

local function seatbeltOf(class)
    if not BELT_CLASSES[class] then return -1 end
    return Bridge.GetSeatbelt()
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        local driving = veh ~= 0
            and (S.Passengers or GetPedInVehicleSeat(veh, -1) == ped)
            and not IsPauseMenuActive()
            and not IsHudHidden()
            and not IsEntityDead(ped)
            and HudSettings.Shown('speedo')

        if not driving then
            hide()
            Wait(250)
        else
            local units = unitsNow()
            local FACTOR = units == 'kmh' and 3.6 or 2.236936      -- m/s ->
            local ALT_FACTOR = units == 'kmh' and 1.0 or 3.28084   -- metres -> m / ft
            local STYLE = S.Style == 'minimal' and 'minimal' or 'gauge'
            local class = GetVehicleClass(veh)
            local mps = GetEntitySpeed(veh)
            local margin = 0.5 * math.abs(GetSafeZoneSize() - 1.0)

            send({
                show = true,
                style = STYLE,
                -- altitude above sea level, -1 = not a flying vehicle
                alt = (STYLE == 'minimal' and FLYING[class])
                    and math.floor(math.max(0.0, GetEntityCoords(veh).z) * ALT_FACTOR + 0.5) or -1,
                units = units,
                margin = math.floor(margin * 10000 + 0.5) / 10000,
                speed = math.floor(mps * FACTOR + 0.5),
                rpm = NO_RPM[class] and -1 or math.floor(GetVehicleCurrentRpm(veh) * 100 + 0.5) / 100,
                gear = (S.Gear and not NO_GEAR[class]) and gearOf(veh, mps) or '',
                fuel = S.Fuel and fuelOf(veh) or -1,
                engine = S.Engine and engineOf(veh) or -1,
                belt = S.Seatbelt and seatbeltOf(class) or -1,
                redline = S.Redline or 0.85,
            })
            Wait(S.UpdateRate or 50)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SendNUIMessage({ type = 'speedo', show = false })
end)
