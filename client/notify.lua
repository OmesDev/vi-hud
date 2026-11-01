-- GTA VI style notifications (html/notify.js). One feed for the whole server:
--   * vi-hud's own:  exports['vi-hud']:Notify(data | message, type, duration, title)
--                    TriggerClientEvent('vi-hud:notify', src, ...)  (or the server export, server.lua)
--   * other notification systems (Config.Notify.Replace): scripts written for ox_lib, esx_notify,
--     okokNotify, mythic_notify or pNotify show up here without being edited. See the comments
--     on Config.Notify for what each one needs.
-- Text can use GTA colour codes (~r~ ~g~ ~b~ ~y~ ~o~ ~p~ ~c~ ~s~, ~h~ bold, ~n~ new line),
-- **bold** / *italic* / `code`, and key tokens like ~INPUT_CONTEXT~.

local C = Config.Notify or {}
if not C.Enabled then return end

local DEFAULT_DURATION = C.Duration or 5000

-- Every name a script might use for a type -> one of ours
local TYPES = {
    info = 'info', inform = 'info', primary = 'info', default = 'info', neutral = 'info',
    alert = 'info', phonemessage = 'info', police = 'info', ambulance = 'info',
    success = 'success', ok = 'success', good = 'success',
    warning = 'warning', warn = 'warning',
    error = 'error', err = 'error', danger = 'error', fail = 'error', failed = 'error',
}

local POSITIONS = {
    ['top'] = 'top', ['top-middle'] = 'top', ['top-center'] = 'top',
    ['top-left'] = 'top-left', ['top-right'] = 'top-right',
    ['bottom'] = 'bottom', ['bottom-middle'] = 'bottom', ['bottom-center'] = 'bottom',
    ['bottom-left'] = 'bottom-left', ['bottom-right'] = 'bottom-right',
    ['center-left'] = 'center-left', ['middle-left'] = 'center-left',
    ['center-right'] = 'center-right', ['middle-right'] = 'center-right',
}


local function str(v)
    if v == nil or v == false then return nil end
    if type(v) ~= 'string' then v = tostring(v) end
    return v ~= '' and v or nil
end

-- Accepts every shape the supported systems use:
--   table   { title, description | text | message, type, duration | length | time | timeout, icon, iconColor, id, position, sound }
--           QBCore: ({ text = 'body', caption = 'title' }, type, length)
--   strings (message, type, duration, title)
local function normalize(a, b, c, d)
    local n
    if type(a) == 'table' then
        n = {
            id = a.id,
            title = a.title or a.caption or a.header,
            description = a.description or a.text or a.message or a.msg or a.content,
            type = a.type or a.status,
            duration = a.duration or a.length or a.time or a.timeout,
            icon = a.icon,
            iconColor = a.iconColor,
            iconAnimation = a.iconAnimation,
            position = a.position,
            sound = a.sound,
            showDuration = a.showDuration,
        }
        if type(n.description) == 'table' then -- QBCore { text, caption }
            local t = n.description
            n.description = t.text or t.message
            n.title = n.title or t.caption or t.title
        end
        if n.type == nil then n.type = b end
        if n.duration == nil then n.duration = c end
    else
        n = { description = a, type = b, duration = c, title = d }
    end

    n.title, n.description = str(n.title), str(n.description)
    if not n.title and not n.description then return nil end

    n.type = TYPES[type(n.type) == 'string' and n.type:lower() or ''] or 'info'

    local dur = tonumber(n.duration) or DEFAULT_DURATION
    if dur > 0 and dur < 100 then dur = dur * 1000 end -- some scripts pass seconds
    n.duration = math.floor(math.max(1000, math.min(120000, dur)))

    n.position = C.ScriptPositions and POSITIONS[n.position] or POSITIONS[C.Position] or 'center-left'
    n.id = n.id ~= nil and tostring(n.id) or nil
    if type(n.icon) == 'table' then -- ox_lib { 'fas', 'car' }
        n.icon = (n.icon[1] and n.icon[2]) and (tostring(n.icon[1]) .. ' ' .. tostring(n.icon[2])) or nil
    end
    n.icon, n.iconColor, n.iconAnimation = str(n.icon), str(n.iconColor), str(n.iconAnimation)
    return n
end

local function Notify(a, b, c, d)
    local n = normalize(a, b, c, d)
    if not n then return end
    n.sound = nil -- scripts' own (GTA) sound requests are ignored; the feed has its own sounds
    local m = 0.5 * math.abs(GetSafeZoneSize() - 1.0)
    SendNUIMessage({
        type = 'notify', n = n, max = C.Max or 5, scale = C.Scale or 1.0,
        margin = math.floor(m * 10000 + 0.5) / 10000,
        -- the sound is synthesised by the page (html/notify.js), one per type
        sound = C.Sound ~= false, volume = C.Volume or 0.6,
    })
end

exports('Notify', Notify)
RegisterNetEvent('vi-hud:notify', Notify)

-- Hidden in the pause menu (they keep counting down).
-- The top-right stack sits under the money display (money.lua) and the weapon / ammo display
-- (weapons.lua) and slides up / down as those come and go (eased in notify.css).
CreateThread(function()
    local hidden, lastOff = false, -1
    while true do
        local h = IsPauseMenuActive()
        if h ~= hidden then
            hidden = h
            SendNUIMessage({ type = 'notify-hidden', hidden = h })
        end

        local off = (MoneyHudOffset or 0.0) + (WeaponHudHeight or 0.0)
        if off > 0 then
            local uh = math.min(0.01, 0.017778 / GetAspectRatio(false)) * GetAspectRatio(false)
            off = off + 0.6 * uh -- gap under whatever is up there
        end
        off = math.floor(off * 1000 + 0.5) / 1000
        if off ~= lastOff then
            lastOff = off
            SendNUIMessage({ type = 'notify-offset', top = off })
        end

        Wait(100)
    end
end)

-- ------------------------------------------------------------------ other notification systems
-- Exports: answered by vi-hud. FiveM looks an export up through the event
-- '__cfx_export_<resource>_<name>'; whichever resource answers it last wins, so vi-hud takes the
-- export over when it starts after that resource (or when that resource isn't running at all).
-- Net events: only handled while that resource isn't running; when it is, it shows its own
-- notification for them, unless it has the vi-hud forwarding lines (see Config.Notify).

local function provideExport(res, name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(res, name), function(setCB) setCB(fn) end)
end

local function provideEvent(res, event, fn)
    RegisterNetEvent(event, function(...)
        if GetResourceState(res) == 'started' then return end
        fn(...)
    end)
end

local COMPAT = {
    ox_lib = function(res)
        local function notify(data) Notify(data) end
        local function defaultNotify(data) -- v3 style, { status = 'inform' | ... }
            if type(data) == 'table' then data.type = data.type or data.status end
            Notify(data)
        end
        provideExport(res, 'notify', notify)
        provideExport(res, 'defaultNotify', defaultNotify)
        provideEvent(res, 'ox_lib:notify', notify)
        provideEvent(res, 'ox_lib:defaultNotify', defaultNotify)
    end,

    esx_notify = function(res)
        -- ESX.ShowNotification -> exports.esx_notify:Notify(type, length, message, title, position)
        local function notify(kind, length, message, title, position)
            Notify({ type = kind, duration = length, description = message, title = title, position = position })
        end
        provideExport(res, 'Notify', notify)
        provideEvent(res, 'ESX:Notify', notify)
    end,

    okokNotify = function(res)
        local function alert(title, message, time, kind)
            Notify({ title = title, description = message, duration = time, type = kind })
        end
        provideExport(res, 'Alert', alert)
        provideEvent(res, 'okokNotify:Alert', alert)
    end,

    mythic_notify = function(res)
        local function send(kind, text, length) Notify({ type = kind, description = text, duration = length }) end
        provideExport(res, 'SendAlert', send)
        provideExport(res, 'DoCustomHudText', send)
        provideExport(res, 'DoHudText', function(kind, text) send(kind, text, 2500) end)
        provideExport(res, 'DoShortHudText', function(kind, text) send(kind, text, 1000) end)
        provideExport(res, 'DoLongHudText', function(kind, text) send(kind, text, 5000) end)
        provideEvent(res, 'mythic_notify:client:SendAlert', function(data)
            if type(data) == 'table' then send(data.type, data.text, data.length) end
        end)
    end,

    pNotify = function(res)
        local function send(data)
            if type(data) ~= 'table' then return end
            Notify({ type = data.type, description = data.text, duration = data.timeout })
        end
        provideExport(res, 'SendNotification', send)
        provideEvent(res, 'pNotify:SendNotification', send)
    end,
}

for res, enabled in pairs(C.Replace or {}) do
    if enabled and COMPAT[res] then COMPAT[res](res) end
end

-- ------------------------------------------------------------------ preview

if C.TestCommand then
    RegisterCommand(C.TestCommand, function()
        CreateThread(function()
            Notify({ title = 'Deposit Received', description = '**$2,500** was added to your bank account.', type = 'success' })
            Wait(700)
            Notify({ title = 'Vehicle Impounded', description = 'Your ~p~Bravado Banshee~s~ was towed to the Davis impound lot.', type = 'warning' })
            Wait(700)
            Notify('You need a ~r~lockpick~s~ to do that.', 'error')
            Wait(700)
            Notify({ title = 'Unknown Number', description = 'Meet me at the docks. Press ~INPUT_CONTEXT~ to mark it on your map.', icon = 'comment-dots', iconColor = '#37c6aa' })
        end)
    end, false)
end
