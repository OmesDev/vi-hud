-- GTA VI style compass tape, top-centre of the screen while in a vehicle. See Config.Compass.

local C = Config.Compass
if not C or not C.Enabled then return end

local shown = nil
local last = {}

local function hide()
    if shown ~= false then
        shown = false
        last = {}
        SendNUIMessage({ type = 'compass', show = false })
    end
end

-- GTA headings run counter-clockwise from north; a compass bearing runs clockwise
local function bearing(heading) return (360.0 - heading) % 360.0 end

local function round1(v) return math.floor(v * 10 + 0.5) / 10 end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        local active = (veh ~= 0 or not C.OnlyInVehicle)
            and not IsPauseMenuActive()
            and not IsHudHidden()
            and not IsEntityDead(ped)
            and HudSettings.Shown('compass')

        if not active then
            hide()
            Wait(250)
        else
            local heading = C.FollowCamera ~= false and GetGameplayCamRot(2).z
                or GetEntityHeading(veh ~= 0 and veh or ped)

            -- Bearing from the player to the waypoint, -1 = none
            local wp = -1
            if C.Waypoint ~= false and IsWaypointActive() then
                local blip = GetFirstBlipInfoId(8)
                if blip ~= 0 and DoesBlipExist(blip) then
                    local to, from = GetBlipInfoIdCoord(blip), GetEntityCoords(ped)
                    local dx, dy = to.x - from.x, to.y - from.y
                    if dx * dx + dy * dy > 4.0 then
                        wp = round1(math.deg(math.atan(dx, dy)) % 360.0)
                    end
                end
            end

            local msg = {
                type = 'compass',
                show = true,
                heading = round1(bearing(heading)),
                wp = wp,
                margin = math.floor(0.5 * math.abs(GetSafeZoneSize() - 1.0) * 10000 + 0.5) / 10000,
                span = C.Span or 150,
                scale = C.Scale or 1.0,
                degrees = C.Degrees ~= false,
            }

            local changed = shown ~= true
            for k, v in pairs(msg) do
                if last[k] ~= v then changed = true break end
            end
            if changed then
                shown = true
                last = msg
                SendNUIMessage(msg)
            end
            Wait(C.UpdateRate or 33)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SendNUIMessage({ type = 'compass', show = false })
end)
