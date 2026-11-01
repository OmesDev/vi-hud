-- Per-player HUD settings. /hud (Config.SettingsCommand) opens the menu (html/settings.js).
-- config.lua stays the server default; each player's changes are saved on their own PC (KVP)
-- and written into the Config tables, which the modules read live. Anything the server turned
-- off in config.lua (Enabled = false) isn't offered here.
--
-- Other files use:
--   HudSettings.Shown(name)  false when the player hid that element (or the whole HUD)
--   HudSettings.Get(id)      current value of an option
--   'vi-hud:settingChanged'  local event (id, value) after a change

HudSettings = {}

local KVP = 'settings_v1'
local COMMAND = Config.SettingsCommand or 'hud'

local values = {}          -- id -> value the player picked (defaults aren't stored)
local OPTIONS, BY_ID = {}, {}
local TAB_ORDER = {
    { id = 'general', label = 'General' },
    { id = 'minimap', label = 'Minimap' },
    { id = 'status', label = 'Status' },
    { id = 'vehicle', label = 'Vehicle' },
    { id = 'weapons', label = 'Weapons' },
    { id = 'alerts', label = 'Notifications' },
}

-- ---------------------------------------------------------------------------
-- Option list
--   kind 'toggle' | 'choice' (choices = { { value, label } }) | 'slider' (min, max, step, fmt)
--        | 'action' (a button)
--   default = server value from config.lua, apply(v) writes the value into Config
--   fmt: 'pct' = value is already %, 'frac' = 0-1 shown as %, 'x' = multiplier
-- ---------------------------------------------------------------------------

local function add(tab, o)
    o.tab = tab
    OPTIONS[#OPTIONS + 1] = o
    BY_ID[o.id] = o
end

local function on(t) return type(t) == 'table' and t.Enabled end

-- Toggle / slider straight onto a Config field
local function field(tab, id, tbl, key, o)
    o.id = id
    if o.default == nil then o.default = tbl[key] end
    o.apply = o.apply or function(v) tbl[key] = v end
    add(tab, o)
end

local function show(tab, name, label, desc)
    add(tab, { id = 'show.' .. name, kind = 'toggle', label = label, desc = desc, default = true })
end

-- General
show('general', 'hud', 'Show HUD', 'Turn the whole HUD off for screenshots and cinematics. Notifications still show.')
add('general', {
    id = 'units', kind = 'choice', label = 'Distance units',
    desc = 'Waypoint distance, turn directions and the speedometer.',
    choices = { { 'mi', 'Miles' }, { 'km', 'Kilometres' } },
    default = Config.Units == 'km' and 'km' or 'mi',
    apply = function(v) Config.Units = v end,
})

-- Minimap. 'Always' is only offered when the server allows the map on foot
-- (Config.OnlyInVehicle = false); a saved 'always' is ignored otherwise.
local minimapModes = { { 'vehicle', 'In vehicles' }, { 'off', 'Off' } }
if not Config.OnlyInVehicle then table.insert(minimapModes, 1, { 'always', 'Always' }) end
add('minimap', {
    id = 'minimap.mode', kind = 'choice', label = 'Show minimap',
    desc = 'When the minimap is on screen.',
    choices = minimapModes,
    default = Config.OnlyInVehicle and 'vehicle' or 'always',
    apply = function(v) Config.OnlyInVehicle = v == 'vehicle' end,
})
add('minimap', {
    id = 'minimap.street', kind = 'choice', label = 'Location bar',
    desc = 'The bar above the minimap while driving.',
    choices = { { 'street', 'Street name' }, { 'zone', 'Area name' }, { 'off', 'Off' } },
    default = Config.StreetBar == 'zone' and 'zone' or Config.StreetBar and 'street' or 'off',
    apply = function(v) Config.StreetBar = v ~= 'off' and v or false end,
})
field('minimap', 'minimap.directions', Config, 'Directions', {
    kind = 'toggle', label = 'Turn-by-turn directions', default = Config.Directions ~= false,
    desc = 'Next turn and distance above the minimap while a waypoint is set.',
})
add('minimap', {
    id = 'minimap.edit', kind = 'action', label = 'Edit layout', button = 'Edit',
    desc = 'Move and resize the minimap panel. Enter saves, Esc cancels.',
})

-- Status icons + mic
if on(Config.Status) then
    local ST = Config.Status
    show('status', 'status', 'Status icons', 'Health, armour, stamina, hunger, thirst and oxygen above the minimap.')
    field('status', 'status.always', ST, 'AlwaysShow', {
        kind = 'toggle', label = 'Always show every icon', default = ST.AlwaysShow == true,
        desc = 'Off: icons only appear when they matter (hurt, out of breath, hungry...).',
    })
    field('status', 'status.needs', ST, 'ShowNeedsBelow', {
        kind = 'slider', label = 'Hunger / thirst appear at', min = 10, max = 100, step = 10, fmt = 'pct',
        default = ST.ShowNeedsBelow or 50,
        desc = 'Show the hunger and thirst icons once they drop to this level.',
    })
    field('status', 'status.size', ST, 'Size', {
        kind = 'slider', label = 'Icon size', min = 0.7, max = 1.5, step = 0.05, fmt = 'x',
        default = ST.Size or 1.0,
    })
    if on(Config.Voice) then
        local V = Config.Voice
        add('status', {
            id = 'mic.mode', kind = 'choice', label = 'Microphone icon',
            desc = 'Voice indicator at the start of the status row.',
            choices = { { 'always', 'Always' }, { 'talking', 'While talking' }, { 'off', 'Off' } },
            default = V.AlwaysShow ~= false and 'always' or 'talking',
            apply = function(v) V.AlwaysShow = v == 'always' end,
        })
    end
end

-- Vehicle: speedometer, compass, radio
if on(Config.Speedometer) then
    local S = Config.Speedometer
    show('vehicle', 'speedo', 'Speedometer')
    field('vehicle', 'speedo.style', S, 'Style', {
        kind = 'choice', label = 'Speedometer style',
        choices = { { 'minimal', 'Minimal' }, { 'gauge', 'Gauge' } },
        default = S.Style == 'minimal' and 'minimal' or 'gauge',
        desc = 'Minimal: just the speed next to the minimap. Gauge: round RPM gauge in the corner.',
    })
    field('vehicle', 'speedo.passengers', S, 'Passengers', {
        kind = 'toggle', label = 'Speedometer as passenger', default = S.Passengers == true,
    })
end
if on(Config.Compass) then
    local C = Config.Compass
    show('vehicle', 'compass', 'Compass', 'Heading tape at the top of the screen.')
    -- Only offered when the server allows the compass on foot (Config.Compass.OnlyInVehicle = false)
    if not C.OnlyInVehicle then
        add('vehicle', {
            id = 'compass.onfoot', kind = 'toggle', label = 'Compass on foot', default = true,
            apply = function(v) C.OnlyInVehicle = not v end,
        })
    end
    add('vehicle', {
        id = 'compass.follow', kind = 'choice', label = 'Compass follows',
        choices = { { 'camera', 'Camera' }, { 'vehicle', 'Vehicle' } },
        default = C.FollowCamera ~= false and 'camera' or 'vehicle',
        apply = function(v) C.FollowCamera = v == 'camera' end,
    })
    field('vehicle', 'compass.degrees', C, 'Degrees', {
        kind = 'toggle', label = 'Heading in degrees', default = C.Degrees ~= false,
    })
    field('vehicle', 'compass.size', C, 'Scale', {
        kind = 'slider', label = 'Compass size', min = 0.7, max = 1.5, step = 0.05, fmt = 'x',
        default = C.Scale or 1.0,
    })
end
if on(Config.Radio) then
    local R = Config.Radio
    field('vehicle', 'radio.onenter', R, 'ShowOnEnter', {
        kind = 'toggle', label = 'Radio strip on entering', default = R.ShowOnEnter == true,
        desc = 'Briefly show the station strip when getting into a vehicle with the radio on.',
    })
    field('vehicle', 'radio.sounds', R, 'Sounds', {
        kind = 'toggle', label = 'Radio strip sounds', default = R.Sounds ~= false,
    })
end

-- Weapons
if on(Config.WeaponWheel) then
    local W = Config.WeaponWheel
    field('weapons', 'wheel.sens', W, 'MouseSensitivity', {
        kind = 'slider', label = 'Wheel mouse sensitivity', min = 0.4, max = 3.0, step = 0.1, fmt = 'x',
        default = W.MouseSensitivity or 1.2,
    })
    field('weapons', 'wheel.blur', W, 'Blur', {
        kind = 'toggle', label = 'Blur behind the wheel', default = W.Blur ~= false,
    })
    field('weapons', 'wheel.glow', W, 'LastWeaponGlow', {
        kind = 'toggle', label = 'Last weapon glow', default = W.LastWeaponGlow ~= false,
        desc = 'Pink glow on the weapon you held before.',
    })
    field('weapons', 'wheel.sounds', W, 'Sounds', {
        kind = 'toggle', label = 'Wheel sounds', default = W.Sounds ~= false,
    })
end
if on(Config.WeaponHud) then
    show('weapons', 'ammo', 'Ammo display', 'Ammo count and weapon icon in the top-right corner.')
end

-- Notifications + money
if on(Config.Notify) then
    local N = Config.Notify
    field('alerts', 'notify.position', N, 'Position', {
        kind = 'choice', label = 'Position',
        choices = {
            { 'top-left', 'Top left' }, { 'top', 'Top' }, { 'top-right', 'Top right' },
            { 'center-left', 'Middle left' }, { 'center-right', 'Middle right' },
            { 'bottom-left', 'Bottom left' }, { 'bottom', 'Bottom' }, { 'bottom-right', 'Bottom right' },
        },
        default = N.Position or 'top-right',
    })
    field('alerts', 'notify.size', N, 'Scale', {
        kind = 'slider', label = 'Size', min = 0.8, max = 1.4, step = 0.05, fmt = 'x', default = N.Scale or 1.0,
    })
    field('alerts', 'notify.sound', N, 'Sound', {
        kind = 'toggle', label = 'Sound', default = N.Sound ~= false,
    })
    field('alerts', 'notify.volume', N, 'Volume', {
        kind = 'slider', label = 'Volume', min = 0, max = 1, step = 0.05, fmt = 'frac', default = N.Volume or 0.6,
    })
    if N.TestCommand then
        add('alerts', {
            id = 'notify.test', kind = 'action', label = 'Test notification', button = 'Send',
            desc = 'Shows a few sample notifications with these settings.',
        })
    end
end
if on(Config.Money) then
    local M = Config.Money
    show('alerts', 'money', 'Money display', 'Cash and bank in the top-right corner.')
    field('alerts', 'money.onchange', M, 'ShowOnChange', {
        kind = 'toggle', label = 'Pop up when money changes', default = M.ShowOnChange ~= false,
    })
end

-- ---------------------------------------------------------------------------
-- Values
-- ---------------------------------------------------------------------------

local function valid(o, v)
    if o.kind == 'toggle' then
        if type(v) == 'boolean' then return v end
        return nil
    end
    if o.kind == 'choice' then
        for _, c in ipairs(o.choices) do if c[1] == v then return v end end
        return nil
    end
    if o.kind == 'slider' then
        v = tonumber(v)
        if not v then return nil end
        v = math.max(o.min, math.min(o.max, v))
        v = o.min + math.floor((v - o.min) / o.step + 0.5) * o.step
        return math.floor(v * 1000 + 0.5) / 1000
    end
    return nil
end

function HudSettings.Get(id)
    local v = values[id]
    if v ~= nil then return v end
    local o = BY_ID[id]
    return o and o.default
end

function HudSettings.Shown(name)
    if values['show.hud'] == false then return false end
    if name and values['show.' .. name] == false then return false end
    return true
end

local function save()
    SetResourceKvp(KVP, json.encode(values))
end

local function set(o, v)
    if v == o.default then values[o.id] = nil else values[o.id] = v end
    if o.apply then o.apply(v) end
    TriggerEvent('vi-hud:settingChanged', o.id, v)
end

-- Saved values -> Config, before the other files start reading it
do
    local raw = GetResourceKvpString(KVP)
    local ok, saved = pcall(json.decode, raw or '')
    if ok and type(saved) == 'table' then
        for id, v in pairs(saved) do
            local o = BY_ID[id]
            if o and o.kind ~= 'action' then
                local good = valid(o, v)
                if good ~= nil then
                    values[id] = good
                    if o.apply then o.apply(good) end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------

local menuOpen = false

local function payload()
    local tabs = {}
    for _, t in ipairs(TAB_ORDER) do
        local list = {}
        for _, o in ipairs(OPTIONS) do
            if o.tab == t.id then
                local choices
                if o.choices then
                    choices = {}
                    for i, c in ipairs(o.choices) do choices[i] = { value = c[1], label = c[2] } end
                end
                list[#list + 1] = {
                    id = o.id, kind = o.kind, label = o.label, desc = o.desc or '', button = o.button,
                    choices = choices, min = o.min, max = o.max, step = o.step, fmt = o.fmt,
                    value = HudSettings.Get(o.id), default = o.default,
                }
            end
        end
        if #list > 0 then tabs[#tabs + 1] = { id = t.id, label = t.label, options = list } end
    end
    return tabs
end

local function openMenu()
    if menuOpen then return end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'settings', action = 'open', tabs = payload(), command = COMMAND })
    -- no driving / walking / shooting underneath the menu (the page has the keyboard and mouse)
    CreateThread(function()
        while menuOpen do
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
end

-- temporary = closed for the minimap editor, which brings the menu back afterwards
local function closeMenu(temporary)
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'settings', action = 'close' })
    if not temporary then TriggerEvent('vi-hud:settingsClosed') end -- pause.lua returns to its menu
end

HudSettings.Open = openMenu

RegisterCommand(COMMAND, function()
    if menuOpen then closeMenu() else openMenu() end
end, false)
TriggerEvent('chat:addSuggestion', '/' .. COMMAND, 'Open the HUD settings')
AddEventHandler('vi-hud:openSettings', openMenu)

RegisterNUICallback('settingsSet', function(data, cb)
    local o = type(data) == 'table' and BY_ID[data.id]
    if not o or o.kind == 'action' then return cb({}) end
    local v = valid(o, data.value)
    if v ~= nil then
        set(o, v)
        save()
    end
    cb({ value = HudSettings.Get(o.id) })
end)

RegisterNUICallback('settingsReset', function(_, cb)
    values = {}
    for _, o in ipairs(OPTIONS) do
        if o.kind ~= 'action' then set(o, o.default) end
    end
    save()
    cb({ tabs = payload() })
end)

RegisterNUICallback('settingsAction', function(data, cb)
    local id = type(data) == 'table' and data.id
    if id == 'minimap.edit' then
        closeMenu(true)
        HudEditMinimap(true) -- client.lua; comes back to this menu when the editor closes
    elseif id == 'notify.test' and Config.Notify and Config.Notify.TestCommand then
        ExecuteCommand(Config.Notify.TestCommand)
    end
    cb({})
end)

RegisterNUICallback('settingsClose', function(_, cb)
    closeMenu()
    cb({})
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and menuOpen then SetNuiFocus(false, false) end
end)
