Config = {}

-- Framework: 'auto' (works with whatever is running), 'esx', 'qbcore', 'qbox' or 'standalone'.
-- Only used for the character-loaded hook, hunger / thirst and the seatbelt (see bridge.lua).
-- Standalone servers can feed those through exports['vi-hud']:SetNeeds(hunger, thirst) and
-- exports['vi-hud']:SetSeatbelt(true / false / nil).
Config.Framework = 'esx'

-- 'fit'  = panel is exactly GTA's radar map area (~1.56:1). The GPS route, waypoint and blips
--          reach every edge. Recommended.
-- 'wide' = wider GTA VI style panel (Config.WideAspect). GTA can't draw the GPS route outside
--          its default map area (engine limitation), so the route stops short of the right
--          edge whenever it heads off to the right.
Config.Shape = 'fit'

-- Minimap size (1.0 = GTA's normal radar size). The map, panel, arrow and markers all scale
-- together from the bottom-left corner, so they stay lined up; saved minimap layouts are
-- rescaled to match. Note: GTA only draws the GPS route inside its normal-size radar area, so
-- above 1.0 the route can stop short of the panel's top / right edges.
Config.MinimapScale = 1.0
Config.WideAspect = 1.8   -- only used by 'wide'

-- Waypoint marker on the minimap: a pink circle, drawn by GTA at the waypoint's real spot
-- and pinned to the radar edge when it's off-screen.
-- The pause-menu map keeps GTA's normal waypoint marker.
--   sprite = blip sprite (1 = plain circle), scale = size, ring = white outline ring
Config.WaypointBlip = { sprite = 1, scale = 0.85, ring = false }

-- 'wide' only: GTA pins blips at the edge of its own radar area, which is narrower than the
-- wide panel. true = stretch GTA's radar sideways so blips reach the panel's side edges
-- (the map gets wider too). false = no stretch, blips stop short of the side edges.
Config.StretchRadar = true

-- GTA's radar is tilted, so "straight ahead" is squashed on screen. This is the squash
-- factor used to aim the N marker at where a line from the player really leaves the panel
-- (1.0 = flat map). Measured from an in-game screenshot.
Config.RadarTilt = 0.66

-- Show the minimap only while in a vehicle
Config.OnlyInVehicle = true

-- Waypoint distance readout in the top-left corner: 'mi' or 'km'
Config.Units = 'mi'

-- Bar above the minimap with where you are:
-- 'street' = the road you're on (area name when you're off-road), 'zone' = area name, false = off
Config.StreetBar = 'street'

-- Turn-by-turn card above the minimap while a waypoint is set ("Turn Right / 173 ft")
Config.Directions = true

-- Size of the street bar + turn card (1.0 = same proportions to the map as the reference)
Config.NavScale = 0.85

-- Replace the native player arrow with the GTA VI style arrow (dark disc, white arrow)
Config.CustomPlayerArrow = true

-- Hide the native health / armour bars under the radar
Config.HideHealthArmour = true

-- Hide GTA's own GPS distance readout ("0.21mi") in the bottom-left of the radar; the panel
-- already shows it top-left. If the pink GPS route disappears with this on, set it to false.
Config.HideSatnavDistance = true

-- GPS route + waypoint blip colour (the pink line in the reference)
Config.RouteColour = { r = 240, g = 98, b = 150, a = 255 }

-- Glass tint drawn over the map. Day = pale wash, night = navy, blended by in-game clock.
Config.Tint = {
    day   = 'rgba(230, 228, 236, 0.30)',
    night = 'rgba(28, 30, 70, 0.38)',
}

-- Command that opens the HUD settings menu. Every player can change their own HUD there (what's
-- shown, minimap / speedometer / compass options, wheel sensitivity, notification position...);
-- it's saved on their PC. The values in this file are the server defaults, and anything turned
-- off here (Enabled = false) isn't offered in the menu. Minimap > Edit layout opens the
-- drag / resize editor for the minimap panel.
Config.SettingsCommand = 'hud'

-- Optional server-wide layout (screen fractions). Leave nil to auto-place over the radar.
-- Open /hud > Minimap > Edit layout, press "Copy values" and paste the result here to apply it
-- for everyone.
-- x/y/w/h = panel, px/py = where GTA draws the player on the radar.
Config.Layout = nil

-- Radio station selector: replaces GTA's radio wheel with a GTA VI style strip at the top
-- of the screen. Hold the radio wheel key (Q / D-pad left) and scroll the mouse wheel, move
-- the mouse / right stick, or press the arrow keys to pick a station; release to tune in.
-- Right mouse button (or A on a pad) while holding toggles MUTE. ',' and '.' still skip stations.
-- Custom logos: drop a square PNG named after the station's internal name into html/stations/
-- (e.g. html/stations/RADIO_01_CLASS_ROCK.png); stations without one get a generated tile.
Config.Radio = {
    Enabled = true,
    ShowOnEnter = false, -- briefly show the strip when getting into a vehicle with the radio on
    ShowOnChange = false, -- briefly show it when the station is changed by something else (another script)
    ShowTime = 2500,     -- ms the strip stays up after letting go of the key or skipping a station
    MouseStep = 0.35,    -- how far the mouse has to move to go one station left/right
    Sounds = true,       -- frontend click when moving between stations
    Hidden = {},         -- internal station names to leave out, e.g. { 'RADIO_19_USER' }
    WeaponWheelOffset = 0.08, -- how far (screen fraction) GTA's weapon select pop-up is moved down while the strip is up
}

-- Weapon wheel: replaces GTA's weapon wheel with a GTA VI style one (8 tiles around the
-- screen centre). Hold TAB (LB / L1 on a pad) and move the mouse / a stick towards a tile,
-- release to equip. Scroll the mouse wheel / arrow keys / d-pad left-right to pick between
-- several weapons in the same tile.
-- Icons: a PNG in html/weapons/<WEAPON_NAME>.png wins (e.g. html/weapons/WEAPON_PISTOL.png);
-- otherwise IconUrl is used (%s = lowercase weapon name, %S = uppercase). IconUrl can be one
-- url or a list; nil = borrow from whichever is running: esx_weaponshop, ox_inventory,
-- qb-inventory, ps-inventory, lj-inventory, qs-inventory.
Config.WeaponWheel = {
    Enabled = true,
    InVehicle = false,       -- true = also usable in vehicles (only drive-by weapons are listed there)
    MouseSensitivity = 1.2,  -- how fast the mouse moves the selection around the wheel
    Blur = true,             -- blur the game behind the wheel
    BlurTime = 150,          -- ms
    SlowMotion = 1.0,        -- time scale while open (e.g. 0.3 for GTA's single player slow-mo). 1.0 = off
    InstantEquip = false,    -- true = weapon appears in hand instantly, false = normal draw animation
    LastWeaponGlow = true,   -- pink glow on the weapon you held before (teal = the one in your hand)
    Sounds = true,
    ShowTabs = true,         -- WEAPONS header above the wheel (always shown while Items is on)
    -- WEAPONS / ITEMS tabs (needs ox_inventory). Hold Tab for the wheel, let go to pick. While
    -- it's up, SwitchControl flips to ITEMS: the inventory opens and stays open until Tab is
    -- pressed again, which brings the (hold) wheel back.
    -- With ox_inventory running, the wheel lists the weapons in your inventory and equips them
    -- through it.
    Items = true,
    SwitchControl = 206,     -- 206 = E on keyboard / RB on controller
    InventoryKey = 'F2',     -- quick open straight onto the ITEMS tab (press again to close);
                             -- players can rebind it in Settings > Key Bindings > FiveM. false = off
    IconUrl = nil,           -- e.g. 'nui://ox_inventory/web/images/%S.png'
    -- Add-on weapons: { name = 'WEAPON_MYGUN', label = 'My Gun', kind = 'rifle' }
    -- kinds: handgun, smg, mg, melee, gadget, shotgun, rifle, sniper, explosive, throwable, heavy
    Extra = {},
}

-- Weapon in hand: ammo ("in clip  spare") with the weapon's icon under it, top-right corner.
-- The ammo uses GTA's own Pricedown font. Hidden when unarmed. Uses the same icons as the
-- weapon wheel (html/weapons/<NAME>.png first).
Config.WeaponHud = {
    Enabled = true,
    AmmoScale = 0.4, -- size of the ammo numbers (GTA text scale)
    IconSize = 1.0,  -- size of the weapon icon (1.0 = default)
}

-- Speedometer while driving. Two styles:
--   'gauge'   = round RPM gauge in the bottom-right corner (same safe-zone margin as the
--               minimap); the arc turns pink at the redline.
--   'minimal' = just the speed, next to the minimap's bottom-right corner, with the altitude
--               underneath in helicopters / planes (ft with mph, m with kmh) and the engine /
--               fuel / seatbelt icons in a row below that.
Config.Speedometer = {
    Enabled = true,
    Style = 'minimal',    -- 'gauge' or 'minimal'
    Units = nil,        -- 'mph' / 'kmh'; nil = follow Config.Units ('mi' -> mph, 'km' -> kmh)
    Passengers = false, -- also show it to passengers
    Gear = true,        -- gear box in the gap at the bottom of the arc (R / N / 1-6), gauge style only
    Fuel = true,        -- fuel ring (reads the vehicle's fuel level: LegacyFuel, ox_fuel, cdn-fuel, ps-fuel...)
    Engine = true,      -- engine health ring
    -- Fuel / engine rings turn pink at 15% or less
    Seatbelt = true,    -- seatbelt icon: green ring when buckled, red disc when not
    -- Seatbelt state is picked up automatically from esx_cruisecontrol, qb-smallresources or
    -- qbx_seatbelt. For another script with an export, name it here (called as
    -- exports[SeatbeltResource]:SeatbeltExport()), or push it with exports['vi-hud']:SetSeatbelt().
    SeatbeltResource = nil,          -- nil = esx_cruisecontrol
    SeatbeltExport = 'isSeatbeltOn',
    Redline = 0.85,     -- RPM (0-1) where the arc turns pink (gauge style)
    UpdateRate = 50,    -- ms between updates
}

-- Status icons in a row above the minimap: health, armour, stamina, hunger, thirst, oxygen.
-- Each icon empties from the top down as the value drops, and pulses at 20% or less.
-- Only the ones that matter are shown: health when hurt, armour when you have some, stamina
-- while it's used, O2 underwater, hunger / thirst once they drop to ShowNeedsBelow.
-- They sit on top of the street name / turn card (or right above the map when those are hidden).
-- Hunger / thirst come from the framework: esx_status (esx_basicneeds) on ESX, player metadata on
-- QBCore / Qbox, or exports['vi-hud']:SetNeeds() on standalone. Hidden when nothing provides them.
Config.Status = {
    Enabled = true,
    Size = 1.0,                   -- icon size multiplier (1.0 = same size as the speedometer's engine / fuel rings)
    AlwaysShow = false,           -- true = show every icon all the time
    ShowNeedsBelow = 50,          -- hunger / thirst appear at or below this %
    Linger = 2000,                -- ms an icon stays up after it's back to normal
    -- With the map hidden (e.g. on foot with OnlyInVehicle) the row sits in the map's corner.
    -- How far below the map's bottom edge it drops, in icon sizes (0 = level with the map's bottom)
    NoMapDrop = 0.55,
    UpdateRate = 200,             -- ms between updates
}

-- Compass: heading tape at the top-centre of the screen while in a vehicle (fades out while the
-- radio strip, which sits in the same spot, is up). N is pink; the pink dot is your waypoint,
-- pinned to the tape's edge when it's off to the side or behind you.
Config.Compass = {
    Enabled = true,
    OnlyInVehicle = true, -- false = also on foot
    FollowCamera = true,  -- true = where the camera looks (turns with the minimap), false = where the vehicle points
    Waypoint = true,      -- waypoint marker on the tape
    Degrees = true,       -- heading readout under the tape (e.g. 312°)
    Span = 150,           -- degrees visible across the tape
    Scale = 1.0,          -- size multiplier
    UpdateRate = 33,      -- ms between updates (the tape glides in between)
}

-- Microphone: the first icon in the status row (so it needs Config.Status enabled), drawn like
-- the other status icons. The mic fills up to your voice range and is dimmed while you're
-- silent; talking lights it up with a white rim and a soft glow (pink while transmitting on the
-- radio). Struck through in pink when voice chat isn't connected.
-- Works with FiveM's built-in voice (pma-voice, mumble-voip...); range / radio need pma-voice.
Config.Voice = {
    Enabled = true,
    AlwaysShow = true, -- false = only while you talk (and for Linger ms after)
    Linger = 1500,
    ShowRange = true,  -- fill shows pma-voice's range (1/3 whisper, 2/3 normal, full shout); false = always full
    UpdateRate = 100,  -- ms between checks
}

-- Money: bank and cash in the top-right corner (GTA's Pricedown font, like the ammo), each with
-- an icon disc, and the change ("+55,500" green / "-200" pink) under the account that moved.
-- Hidden until the money changes (only the account that changed pops up) or the command is used
-- (both accounts); then it stays up for ShowTime and fades.
-- The weapon / ammo display slides down under it while it's up.
-- Balances come from the framework: ESX accounts ('money' / 'bank'), QBCore / Qbox
-- PlayerData.money. Standalone: exports['vi-hud']:SetMoney(cash, bank).
-- Other scripts can pop it up with exports['vi-hud']:ShowMoney().
Config.Money = {
    Enabled = true,
    Command = 'money',  -- shows it for ShowTime; false = no command
    Key = nil,          -- optional default key for the command, e.g. 'Z' (players can rebind it in FiveM's key bindings)
    ShowTime = 10000,   -- ms it stays up before fading out
    ShowOnChange = true, -- pop up when the cash / bank balance changes
    CountUp = true,     -- numbers roll to the new balance
    Bank = true,        -- show the bank row
    Cash = true,        -- show the cash row
    Scale = 1.0,        -- size multiplier
    TextNudge = 0.0,    -- moves the amounts up (-) / down (+) against the icons, in u (~1% of screen width)
}

-- Notifications: one GTA VI style feed for the whole server (dark glass card, coloured type tile,
-- time-left bar; repeats merge into one card with a count). Use it from any script:
--   client: exports['vi-hud']:Notify({ title = 'Paid', description = '$500', type = 'success' })
--           exports['vi-hud']:Notify('Message', 'error', 5000, 'Optional title')
--   server: exports['vi-hud']:Notify(playerId, { ... })  or  TriggerClientEvent('vi-hud:notify', playerId, { ... })
-- types: 'info', 'success', 'warning', 'error' (and the usual aliases: inform, primary, danger...).
-- Text takes GTA colour codes (~r~ ~g~ ~b~ ~y~ ~o~ ~p~ ~s~, ~h~ bold, ~n~ new line), **bold**,
-- *italic*, `code` and key tokens like ~INPUT_CONTEXT~. Preview: /notifytest.
--
-- Replace: scripts written for these notification systems show in vi-hud's feed instead, with no
-- edits to those scripts:
--   ox_lib        lib.notify / exports.ox_lib:notify; also TriggerClientEvent('ox_lib:notify') once
--                 ox_lib has the 2 vi-hud lines at the top of lib.notify
--                 (ox_lib/resource/interface/client/notify.lua; re-add them after updating ox_lib)
--   esx_notify    ESX.ShowNotification / 'ESX:Notify'; esx_notify has the same 2 lines at the top of
--                 Notify (esx_notify/Notify.lua). Keep the esx_notify folder: ESX only calls it when it exists.
--   okokNotify, mythic_notify, pNotify: remove / stop that resource and vi-hud answers its exports and events.
-- vi-hud should start after these (it takes their exports over when it starts). Without the 2 lines,
-- ox_lib / esx_notify still show their own popup for notifications sent straight through their event.
-- QBCore / Qbox (qb-core draws its own): add at the top of QBCore.Functions.Notify in
-- qb-core/client/functions.lua:
--     if GetResourceState('vi-hud') == 'started' then return exports['vi-hud']:Notify(text, texttype, length) end
Config.Notify = {
    Enabled = true,
    -- 'top-left', 'top', 'top-right', 'center-left', 'center-right', 'bottom-left', 'bottom', 'bottom-right'
    -- (top-right slides down under the money / weapon display while those are up)
    Position = 'top-right',
    ScriptPositions = false, -- true = use the position a script asks for (ox_lib / esx_notify), false = everything in one feed
    Duration = 5000,         -- ms, when the script doesn't say
    Max = 5,                 -- cards on screen per position; the oldest goes first
    Scale = 1.0,
    -- Soft synthesised chime per type (no GTA sounds): info = single ping, success = rising pair,
    -- warning = two even taps, error = low falling pair. Plays through the NUI, so the game's
    -- volume sliders don't affect it; Volume does (0.0 - 1.0).
    Sound = true,
    Volume = 0.6,
    TestCommand = 'notifytest', -- false = off
    Replace = {
        ox_lib = true,
        esx_notify = true,
        okokNotify = true,
        mythic_notify = true,
        pNotify = true,
    },
}

-- Pause menu: Esc opens a GTA VI style menu instead of GTA's own (same look as the weapon wheel).
-- Map, Settings and Key Bindings open GTA's own screens with this menu's frame around them
-- (GTA's map legend stays: scripts can't read blip names to rebuild it). Backing out of any of
-- them returns to this menu.
-- Other scripts can stop Esc from opening it while they use the key:
--   exports['vi-hud']:BlockPauseMenu(true / false)
Config.PauseMenu = {
    Enabled = true,
    Title = 'Los Santos',      -- title above the tiles (also replaces "FiveM" in GTA's own pause menu header)
    Blur = true,               -- blur the game behind the menu
    Sounds = true,
    Headshot = true,           -- your character's face next to your name
    MapKey = true,             -- P (keyboard) opens the full-screen map with this look, Esc goes straight back to the game.
                               -- false = P opens GTA's own pause menu as usual
    LeaveButton = true,        -- "Leave server" (asks to confirm)
    LeaveMessage = 'Left via the pause menu', -- reason shown in the server console
    -- Extra tiles after the built-in ones. Each runs one of: command (client command), event
    -- (client event), serverEvent, or url (opens in the player's browser).
    --   { label = 'Rules', icon = 'fa-solid fa-scroll', url = 'https://...' },
    --   { label = 'Emotes', icon = 'fa-solid fa-person-walking', command = 'emotemenu' },
    -- icon = a Font Awesome 6 class (optional). keepOpen = true leaves the menu up afterwards.
    Buttons = {},
}

-- Note: the map cut-out is generated in-game for GTA's default radar component positions
-- (this resource pins them on start). Don't move the radar components with another script.
