Config = {}

-- General
Config.Framework = 'esx'          -- 'auto', 'esx', 'qbcore', 'qbox', 'standalone'
Config.SettingsCommand = 'hud'
Config.Units = 'mi'               -- 'mi' / 'km'

-- Minimap
Config.Shape = 'fit'              -- 'fit' (recommended) / 'wide'
Config.WideAspect = 1.8           -- 'wide' only
Config.StretchRadar = true        -- 'wide' only
Config.MinimapScale = 1.0
Config.OnlyInVehicle = true
Config.CustomPlayerArrow = true
Config.HideHealthArmour = true
Config.HideSatnavDistance = true  -- set false if the GPS route disappears
Config.RadarTilt = 0.66
Config.StreetBar = 'street'       -- 'street' / 'zone' / false
Config.Directions = true
Config.NavScale = 0.85
Config.WaypointBlip = { sprite = 1, scale = 0.85, ring = false }
Config.RouteColour = { r = 240, g = 98, b = 150, a = 255 }
Config.Tint = { day = 'rgba(230, 228, 236, 0.30)', night = 'rgba(28, 30, 70, 0.38)' }
Config.Layout = nil               -- paste from /hud > Minimap > Edit layout > Copy values

-- Radio wheel (logos: html/stations/<NAME>.png)
Config.Radio = {
    Enabled = true,
    ShowOnEnter = false,
    ShowOnChange = false,
    ShowTime = 2500,
    MouseStep = 0.35,
    Sounds = true,
    Hidden = {},              -- e.g. { 'RADIO_19_USER' }
    WeaponWheelOffset = 0.08,
}

-- Weapon wheel (icons: html/weapons/<NAME>.png)
Config.WeaponWheel = {
    Enabled = true,
    InVehicle = false,
    MouseSensitivity = 1.2,
    Blur = true,
    BlurTime = 150,
    SlowMotion = 1.0,         -- 1.0 = off
    InstantEquip = false,
    LastWeaponGlow = true,
    Sounds = true,
    ShowTabs = true,
    Items = true,             -- ITEMS tab, needs ox_inventory
    SwitchControl = 206,      -- E / RB
    InventoryKey = 'F2',      -- false = off
    IconUrl = nil,            -- nil = auto
    Extra = {},               -- { name = 'WEAPON_X', label = 'X', kind = 'rifle' }
}

-- Weapon HUD
Config.WeaponHud = {
    Enabled = true,
    AmmoScale = 0.4,
    IconSize = 1.0,
}

-- Speedometer
Config.Speedometer = {
    Enabled = true,
    Style = 'minimal',        -- 'gauge' / 'minimal'
    Units = nil,              -- nil = follow Config.Units
    Passengers = false,
    Gear = true,
    Fuel = true,
    Engine = true,
    Seatbelt = true,
    SeatbeltResource = nil,   -- nil = auto
    SeatbeltExport = 'isSeatbeltOn',
    Redline = 0.85,
    UpdateRate = 50,
}

-- Status icons
Config.Status = {
    Enabled = true,
    Size = 1.0,
    AlwaysShow = false,
    ShowNeedsBelow = 50,
    Linger = 2000,
    NoMapDrop = 0.55,
    UpdateRate = 200,
}

-- Compass
Config.Compass = {
    Enabled = true,
    OnlyInVehicle = true,
    FollowCamera = true,      -- false = vehicle direction
    Waypoint = true,
    Degrees = true,
    Span = 150,
    Scale = 1.0,
    UpdateRate = 33,
}

-- Voice (pma-voice)
Config.Voice = {
    Enabled = true,
    AlwaysShow = true,
    Linger = 1500,
    ShowRange = true,
    UpdateRate = 100,
}

-- Money
Config.Money = {
    Enabled = true,
    Command = 'money',        -- false = off
    Key = nil,                -- e.g. 'Z'
    ShowTime = 10000,
    ShowOnChange = true,
    CountUp = true,
    Bank = true,
    Cash = true,
    Scale = 1.0,
    TextNudge = 0.0,
}

-- Notifications: exports['vi-hud']:Notify({ title = '', description = '', type = 'success' })
Config.Notify = {
    Enabled = true,
    Position = 'top-right',   -- top/center/bottom + left/right, or 'top' / 'bottom'
    ScriptPositions = false,
    Duration = 5000,
    Max = 5,
    Scale = 1.0,
    Sound = true,
    Volume = 0.6,
    TestCommand = 'notifytest',
    Replace = {
        ox_lib = true,
        esx_notify = true,
        okokNotify = true,
        mythic_notify = true,
        pNotify = true,
    },
}

-- Pause menu
Config.PauseMenu = {
    Enabled = true,
    Heading = 'Pause Menu',  -- tab in the top-left corner ('' = none)
    Title = 'Los Santos',
    Blur = true,
    Sounds = true,
    Headshot = true,
    MapKey = true,
    LeaveButton = true,
    LeaveMessage = 'Left via the pause menu',
    -- Small link buttons in the bottom-right corner. Each needs one action: url, command, event or serverEvent
    -- (keepOpen = true keeps the menu up). Icons: any Font Awesome 6 class. {} = none
    Buttons = {
        { label = 'Rules',   icon = 'fa-solid fa-scroll',        url = 'https://example.com/rules' },
        { label = 'Discord', icon = 'fa-brands fa-discord',      url = 'https://discord.gg/example' },
        { label = 'Website', icon = 'fa-solid fa-globe',         url = 'https://example.com' },
        { label = 'Store',   icon = 'fa-solid fa-cart-shopping', url = 'https://example.com/store' },
    },
}
