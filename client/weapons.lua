-- GTA VI style weapon wheel (replaces GTA's weapon wheel) + the weapon / ammo display in the
-- top-right corner. See Config.WeaponWheel and Config.WeaponHud.

local W = Config.WeaponWheel or {}
local HUD = Config.WeaponHud or {}
if not W.Enabled and not HUD.Enabled then return end

local CONTROL_WHEEL = 37 -- INPUT_SELECT_WEAPON (TAB / LB / L1)

-- Everything the mouse / sticks / buttons would otherwise do while the wheel is open
local BLOCK_WHILE_OPEN = {
    1, 2, 3, 4, 5, 6,                  -- look
    12, 13, 14, 15, 16, 17, 99, 100, 115, 116, 241, 242, 261, 262, -- weapon wheel / scroll switching
    24, 25, 68, 69, 70, 91, 92, 114, 140, 141, 142, 257, 263, 264, -- attack / aim / melee
    157, 158, 159, 160, 161, 162, 163, 164, 165, -- number keys weapon slots
    174, 175, 172, 173,                -- arrows / d-pad
    200, 199,                          -- pause (closing the wheel takes priority)
    38, 46, 51, 86, 206,               -- E / RB (switches to the ITEMS tab)
}
local PREV_KEYS = { 15, 17, 241, 174 } -- scroll up, left arrow / d-pad left
local NEXT_KEYS = { 14, 16, 242, 175 } -- scroll down, right arrow / d-pad right

-- ---------------------------------------------------------------------------
-- Weapons
-- ---------------------------------------------------------------------------

-- Slots, clockwise from the top (same order as html/weapons.js):
-- 1 top, 2 top-right, 3 right, 4 bottom-right, 5 bottom, 6 bottom-left, 7 left, 8 top-left
-- Direction (degrees, 0 = up, clockwise) of each tile from the wheel centre, measured off the
-- reference frame, so pointing the mouse / stick at a tile picks that tile.
local SLOT_ANGLE = { 0, 53.3, 90, 126.9, 180, 233.1, 270, 306.7 }

-- kind -> slot, category line under the weapon name, what goes in the ammo strip
--   ammo 'clip' = "<in clip> <reserve>", 'count' = total, nil = no strip
local KINDS = {
    handgun   = { slot = 1, cat = 'Handguns',        ammo = 'clip' },
    smg       = { slot = 2, cat = 'Submachine Guns', ammo = 'clip' },
    mg        = { slot = 2, cat = 'Machine Guns',    ammo = 'clip' },
    melee     = { slot = 3, cat = 'Melee' },
    gadget    = { slot = 4, cat = 'Gadgets' },
    shotgun   = { slot = 5, cat = 'Shotguns',        ammo = 'clip' },
    rifle     = { slot = 6, cat = 'Rifles',          ammo = 'clip' },
    sniper    = { slot = 7, cat = 'Sniper Rifles',   ammo = 'clip' },
    explosive = { slot = 8, cat = 'Explosives',      ammo = 'count' },
    throwable = { slot = 8, cat = 'Throwables',      ammo = 'count' },
    heavy     = { slot = 8, cat = 'Heavy Weapons',   ammo = 'clip' },
}

-- Kinds that can be picked inside a vehicle (drive-by capable)
local VEHICLE_KINDS = { handgun = true, smg = true, melee = true, explosive = true, throwable = true }

-- { weapon name, label, kind [, noAmmo] }. Add-on weapons can be added in Config.WeaponWheel.Extra.
local WEAPONS = {
    { 'WEAPON_UNARMED', 'Unarmed', 'melee' },
    { 'WEAPON_KNUCKLE', 'Brass Knuckles', 'melee' },
    { 'WEAPON_KNIFE', 'Knife', 'melee' },
    { 'WEAPON_DAGGER', 'Antique Cavalry Dagger', 'melee' },
    { 'WEAPON_SWITCHBLADE', 'Switchblade', 'melee' },
    { 'WEAPON_MACHETE', 'Machete', 'melee' },
    { 'WEAPON_HATCHET', 'Hatchet', 'melee' },
    { 'WEAPON_STONE_HATCHET', 'Stone Hatchet', 'melee' },
    { 'WEAPON_BATTLEAXE', 'Battle Axe', 'melee' },
    { 'WEAPON_BAT', 'Baseball Bat', 'melee' },
    { 'WEAPON_GOLFCLUB', 'Golf Club', 'melee' },
    { 'WEAPON_POOLCUE', 'Pool Cue', 'melee' },
    { 'WEAPON_CROWBAR', 'Crowbar', 'melee' },
    { 'WEAPON_HAMMER', 'Hammer', 'melee' },
    { 'WEAPON_WRENCH', 'Pipe Wrench', 'melee' },
    { 'WEAPON_NIGHTSTICK', 'Nightstick', 'melee' },
    { 'WEAPON_FLASHLIGHT', 'Flashlight', 'melee' },
    { 'WEAPON_BOTTLE', 'Broken Bottle', 'melee' },
    { 'WEAPON_CANDYCANE', 'Candy Cane', 'melee' },
    { 'WEAPON_STUNROD', 'The Shocker', 'melee' },

    { 'WEAPON_PISTOL', 'Pistol', 'handgun' },
    { 'WEAPON_PISTOL_MK2', 'Pistol Mk II', 'handgun' },
    { 'WEAPON_COMBATPISTOL', 'Combat Pistol', 'handgun' },
    { 'WEAPON_APPISTOL', 'AP Pistol', 'handgun' },
    { 'WEAPON_PISTOL50', 'Pistol .50', 'handgun' },
    { 'WEAPON_SNSPISTOL', 'SNS Pistol', 'handgun' },
    { 'WEAPON_SNSPISTOL_MK2', 'SNS Pistol Mk II', 'handgun' },
    { 'WEAPON_HEAVYPISTOL', 'Heavy Pistol', 'handgun' },
    { 'WEAPON_VINTAGEPISTOL', 'Vintage Pistol', 'handgun' },
    { 'WEAPON_MARKSMANPISTOL', 'Marksman Pistol', 'handgun' },
    { 'WEAPON_REVOLVER', 'Heavy Revolver', 'handgun' },
    { 'WEAPON_REVOLVER_MK2', 'Heavy Revolver Mk II', 'handgun' },
    { 'WEAPON_DOUBLEACTION', 'Double-Action Revolver', 'handgun' },
    { 'WEAPON_NAVYREVOLVER', 'Navy Revolver', 'handgun' },
    { 'WEAPON_CERAMICPISTOL', 'Ceramic Pistol', 'handgun' },
    { 'WEAPON_GADGETPISTOL', 'Perico Pistol', 'handgun' },
    { 'WEAPON_PISTOLXM3', 'WM 29 Pistol', 'handgun' },
    { 'WEAPON_FLAREGUN', 'Flare Gun', 'handgun' },
    { 'WEAPON_STUNGUN', 'Stun Gun', 'handgun', true },
    { 'WEAPON_STUNGUN_MP', 'Stun Gun', 'handgun', true },
    { 'WEAPON_RAYPISTOL', 'Up-n-Atomizer', 'handgun', true },

    { 'WEAPON_MICROSMG', 'Micro SMG', 'smg' },
    { 'WEAPON_SMG', 'SMG', 'smg' },
    { 'WEAPON_SMG_MK2', 'SMG Mk II', 'smg' },
    { 'WEAPON_ASSAULTSMG', 'Assault SMG', 'smg' },
    { 'WEAPON_COMBATPDW', 'Combat PDW', 'smg' },
    { 'WEAPON_MACHINEPISTOL', 'Machine Pistol', 'smg' },
    { 'WEAPON_MINISMG', 'Mini SMG', 'smg' },
    { 'WEAPON_TECPISTOL', 'Tactical SMG', 'smg' },
    { 'WEAPON_MG', 'MG', 'mg' },
    { 'WEAPON_COMBATMG', 'Combat MG', 'mg' },
    { 'WEAPON_COMBATMG_MK2', 'Combat MG Mk II', 'mg' },
    { 'WEAPON_GUSENBERG', 'Gusenberg Sweeper', 'mg' },
    { 'WEAPON_RAYCARBINE', 'Unholy Hellbringer', 'mg' },

    { 'WEAPON_PUMPSHOTGUN', 'Pump Shotgun', 'shotgun' },
    { 'WEAPON_PUMPSHOTGUN_MK2', 'Pump Shotgun Mk II', 'shotgun' },
    { 'WEAPON_SAWNOFFSHOTGUN', 'Sawed-Off Shotgun', 'shotgun' },
    { 'WEAPON_ASSAULTSHOTGUN', 'Assault Shotgun', 'shotgun' },
    { 'WEAPON_BULLPUPSHOTGUN', 'Bullpup Shotgun', 'shotgun' },
    { 'WEAPON_HEAVYSHOTGUN', 'Heavy Shotgun', 'shotgun' },
    { 'WEAPON_DBSHOTGUN', 'Double Barrel Shotgun', 'shotgun' },
    { 'WEAPON_AUTOSHOTGUN', 'Sweeper Shotgun', 'shotgun' },
    { 'WEAPON_COMBATSHOTGUN', 'Combat Shotgun', 'shotgun' },
    { 'WEAPON_MUSKET', 'Musket', 'shotgun' },

    { 'WEAPON_ASSAULTRIFLE', 'Assault Rifle', 'rifle' },
    { 'WEAPON_ASSAULTRIFLE_MK2', 'Assault Rifle Mk II', 'rifle' },
    { 'WEAPON_CARBINERIFLE', 'Carbine Rifle', 'rifle' },
    { 'WEAPON_CARBINERIFLE_MK2', 'Carbine Rifle Mk II', 'rifle' },
    { 'WEAPON_ADVANCEDRIFLE', 'Advanced Rifle', 'rifle' },
    { 'WEAPON_SPECIALCARBINE', 'Special Carbine', 'rifle' },
    { 'WEAPON_SPECIALCARBINE_MK2', 'Special Carbine Mk II', 'rifle' },
    { 'WEAPON_BULLPUPRIFLE', 'Bullpup Rifle', 'rifle' },
    { 'WEAPON_BULLPUPRIFLE_MK2', 'Bullpup Rifle Mk II', 'rifle' },
    { 'WEAPON_COMPACTRIFLE', 'Compact Rifle', 'rifle' },
    { 'WEAPON_MILITARYRIFLE', 'Military Rifle', 'rifle' },
    { 'WEAPON_HEAVYRIFLE', 'Heavy Rifle', 'rifle' },
    { 'WEAPON_TACTICALRIFLE', 'Service Carbine', 'rifle' },
    { 'WEAPON_BATTLERIFLE', 'Battle Rifle', 'rifle' },

    { 'WEAPON_SNIPERRIFLE', 'Sniper Rifle', 'sniper' },
    { 'WEAPON_HEAVYSNIPER', 'Heavy Sniper', 'sniper' },
    { 'WEAPON_HEAVYSNIPER_MK2', 'Heavy Sniper Mk II', 'sniper' },
    { 'WEAPON_MARKSMANRIFLE', 'Marksman Rifle', 'sniper' },
    { 'WEAPON_MARKSMANRIFLE_MK2', 'Marksman Rifle Mk II', 'sniper' },
    { 'WEAPON_PRECISIONRIFLE', 'Precision Rifle', 'sniper' },

    { 'WEAPON_GRENADE', 'Grenade', 'explosive' },
    { 'WEAPON_MOLOTOV', 'Molotov', 'explosive' },
    { 'WEAPON_STICKYBOMB', 'Sticky Bomb', 'explosive' },
    { 'WEAPON_PIPEBOMB', 'Pipe Bomb', 'explosive' },
    { 'WEAPON_PROXMINE', 'Proximity Mine', 'explosive' },
    { 'WEAPON_BZGAS', 'BZ Gas', 'explosive' },
    { 'WEAPON_SMOKEGRENADE', 'Tear Gas', 'explosive' },
    { 'WEAPON_FLARE', 'Flare', 'throwable' },
    { 'WEAPON_ACIDPACKAGE', 'Acid Package', 'throwable' },
    { 'WEAPON_SNOWBALL', 'Snowball', 'throwable' },
    { 'WEAPON_BALL', 'Ball', 'throwable' },
    { 'WEAPON_RPG', 'RPG', 'heavy' },
    { 'WEAPON_GRENADELAUNCHER', 'Grenade Launcher', 'heavy' },
    { 'WEAPON_GRENADELAUNCHER_SMOKE', 'Smoke Grenade Launcher', 'heavy' },
    { 'WEAPON_COMPACTLAUNCHER', 'Compact Grenade Launcher', 'heavy' },
    { 'WEAPON_HOMINGLAUNCHER', 'Homing Launcher', 'heavy' },
    { 'WEAPON_FIREWORK', 'Firework Launcher', 'heavy' },
    { 'WEAPON_EMPLAUNCHER', 'Compact EMP Launcher', 'heavy' },
    { 'WEAPON_MINIGUN', 'Minigun', 'heavy' },
    { 'WEAPON_RAYMINIGUN', 'Widowmaker', 'heavy', true },
    { 'WEAPON_RAILGUN', 'Railgun', 'heavy' },
    { 'WEAPON_RAILGUNXM3', 'Railgun', 'heavy' },

    { 'WEAPON_PETROLCAN', 'Jerry Can', 'gadget' },
    { 'WEAPON_HAZARDCAN', 'Hazardous Jerry Can', 'gadget' },
    { 'WEAPON_FERTILIZERCAN', 'Fertilizer Can', 'gadget' },
    { 'WEAPON_FIREEXTINGUISHER', 'Fire Extinguisher', 'gadget' },
}

local function u32(h)
    return (math.tointeger(h) or 0) & 0xFFFFFFFF
end

local list, byHash = {}, {}
local function addWeapon(name, label, kind, noAmmo)
    local k = KINDS[kind]
    if not k then
        print(('[vi-hud] weapon wheel: unknown kind "%s" for %s'):format(tostring(kind), tostring(name)))
        return
    end
    local native = GetHashKey(name)
    local hash = u32(native)
    local w = byHash[hash]
    if not w then
        w = { hash = hash, native = native } -- native = value handed to natives, hash = for comparing
        list[#list + 1] = w
        byHash[hash] = w
    end
    w.name, w.label, w.kind, w.slot, w.cat = name, label, kind, k.slot, k.cat
    w.ammo = not noAmmo and k.ammo or nil
end

for _, e in ipairs(WEAPONS) do addWeapon(e[1], e[2], e[3], e[4]) end
for _, e in ipairs(W.Extra or {}) do addWeapon(e.name, e.label, e.kind, e.noAmmo) end

local UNARMED = u32(GetHashKey('WEAPON_UNARMED'))

-- ---------------------------------------------------------------------------
-- ox_inventory: weapons are inventory items there and the ped only carries the one in hand,
-- so the wheel lists the inventory's weapons and equips them through ox_inventory.
-- ---------------------------------------------------------------------------

local OX = 'ox_inventory'
local function oxRunning() return Bridge.Started(OX) end -- cached, kept current by resource start / stop

local ITEMS = W.Items ~= false
local SWITCH = W.SwitchControl or 206
local function itemsOn() return ITEMS and oxRunning() end

-- Add-on weapons that are in the inventory but not in the list above: kind from the weapon group
local GROUP_KIND = {}
for g, k in pairs({
    GROUP_MELEE = 'melee', GROUP_PISTOL = 'handgun', GROUP_STUNGUN = 'handgun', GROUP_SMG = 'smg',
    GROUP_MG = 'mg', GROUP_RIFLE = 'rifle', GROUP_SHOTGUN = 'shotgun', GROUP_SNIPER = 'sniper',
    GROUP_HEAVY = 'heavy', GROUP_THROWN = 'throwable', GROUP_PETROLCAN = 'gadget',
    GROUP_FIREEXTINGUISHER = 'gadget',
}) do GROUP_KIND[u32(GetHashKey(g))] = k end

local oxDefs = {} -- weapon name -> { ammo = ammo item name | false }, false = not an ox item
local function oxDef(name)
    local d = oxDefs[name]
    if d == nil then
        local ok, item = pcall(function() return exports[OX]:Items(name) end)
        d = ok and type(item) == 'table'
            and { ammo = type(item.ammoname) == 'string' and item.ammoname or false } or false
        oxDefs[name] = d
    end
    return d
end

local counts = {} -- item name -> { count, time }; the ammo display asks every frame
local function oxCount(name)
    local now = GetGameTimer()
    local c = counts[name]
    if not c or now - c[2] > 500 then
        local ok, n = pcall(function() return exports[OX]:GetItemCount(name) end)
        c = { ok and tonumber(n) or 0, now }
        counts[name] = c
    end
    return c[1]
end

local oxSlot, oxMeta = {}, {} -- weapon hash -> inventory slot / item metadata (rebuilt on open)

local function oxWeapons()
    oxSlot, oxMeta = {}, {}
    if not oxRunning() then return end
    local ok, inv = pcall(function() return exports[OX]:GetPlayerItems() end)
    if not ok or type(inv) ~= 'table' then return end
    local okc, cur = pcall(function() return exports[OX]:getCurrentWeapon() end)
    local curSlot = okc and type(cur) == 'table' and cur.slot or nil

    local now, tally = GetGameTimer(), {}
    for _, it in pairs(inv) do
        if type(it) == 'table' and type(it.name) == 'string' then
            tally[it.name] = (tally[it.name] or 0) + (tonumber(it.count) or 0)
            local name = it.name:upper()
            if name:sub(1, 7) == 'WEAPON_' then
                local hash = u32(GetHashKey(name))
                if not byHash[hash] then
                    local kind = GROUP_KIND[u32(GetWeapontypeGroup(GetHashKey(name)))]
                    if kind then addWeapon(name, it.label or name, kind) end
                end
                -- Same weapon in several slots: the one in hand, else the first found
                if byHash[hash] and (not oxSlot[hash] or it.slot == curSlot) then
                    oxSlot[hash] = it.slot
                    oxMeta[hash] = type(it.metadata) == 'table' and it.metadata or {}
                end
            end
        end
    end
    counts = {}
    for name, n in pairs(tally) do counts[name] = { n, now } end
end

local function oxUse(slot)
    CreateThread(function() -- useSlot waits on the server
        local ok, err = pcall(function() exports[OX]:useSlot(slot, W.InstantEquip == true) end)
        if not ok then print(('[vi-hud] weapon wheel: ox_inventory useSlot failed: %s'):format(err)) end
    end)
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local open = false
local slots = {}       -- [1..8] = { list = { weapon... }, idx = n }
local chosen = {}      -- [slot] = hash last picked in that slot (kept between openings)
local hover = 0        -- highlighted slot (0 = none)
local equipped, lastWeapon = nil, nil
local equippedAt = 0       -- when `equipped` was drawn
local UNARMED_BLIP = 2000  -- ms; unarmed for less than this between two weapons = holstering, not a pick

local function click(name)
    if W.Sounds then PlaySoundFrontend(-1, name, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
end

local function ammoOf(ped, w)
    if not w.ammo then return nil end
    local def = oxRunning() and oxDef(w.name)
    -- ox_inventory: throwables are stacks of items, spare ammo is ammo items, and a weapon that
    -- isn't in hand keeps its loaded rounds in the item's metadata
    if def and w.ammo == 'count' then return { count = oxCount(w.name) } end
    if def and w.hash ~= equipped then
        local m = oxMeta[w.hash]
        return { clip = m and tonumber(m.ammo) or 0, reserve = def.ammo and oxCount(def.ammo) or 0 }
    end
    local total = GetAmmoInPedWeapon(ped, w.native)
    if w.ammo == 'count' then return { count = total } end
    local ok, clip = GetAmmoInClip(ped, w.native)
    clip = ok and clip or 0
    if def then return { clip = clip, reserve = def.ammo and oxCount(def.ammo) or 0 } end
    return { clip = clip, reserve = math.max(0, total - clip) }
end

local function buildSlots(ped, inVehicle)
    slots = {}
    for s = 1, 8 do slots[s] = { list = {}, idx = 1 } end
    oxWeapons()

    for _, w in ipairs(list) do
        if (not inVehicle or VEHICLE_KINDS[w.kind])
            and (w.hash == UNARMED or oxSlot[w.hash] or HasPedGotWeapon(ped, w.native, false)) then
            local s = slots[w.slot]
            s.list[#s.list + 1] = w
        end
    end

    for s = 1, 8 do
        local sl = slots[s]
        local pick
        for i, w in ipairs(sl.list) do
            if w.hash == equipped then pick = i break end
        end
        if not pick then
            for i, w in ipairs(sl.list) do
                if w.hash == chosen[s] then pick = i break end
            end
        end
        sl.idx = pick or 1
    end
end

local function slotOf(hash)
    for s = 1, 8 do
        for _, w in ipairs(slots[s].list) do
            if w.hash == hash then return s end
        end
    end
    return 0
end

local function payload(ped)
    local out = {}
    for s = 1, 8 do
        local items = {}
        for i, w in ipairs(slots[s].list) do
            local a = ammoOf(ped, w)
            items[i] = {
                name = w.name,
                label = w.label,
                cat = w.cat,
                clip = a and a.clip or -1,
                reserve = a and a.reserve or -1,
                count = a and a.count or -1,
                equipped = w.hash == equipped,
                last = W.LastWeaponGlow and w.hash == lastWeapon or false,
            }
        end
        out[s] = { items = items, idx = slots[s].idx - 1, n = #items }
    end
    return out
end

local function pushSelection()
    local idx = {}
    for s = 1, 8 do idx[s] = slots[s].idx - 1 end
    SendNUIMessage({ type = 'wheel', action = 'select', hover = hover - 1, idx = idx })
end

local function fx(on)
    if W.Blur then
        if on then TriggerScreenblurFadeIn(W.BlurTime or 150) else TriggerScreenblurFadeOut(W.BlurTime or 150) end
    end
    if W.SlowMotion and W.SlowMotion < 1.0 then
        SetTimeScale(on and W.SlowMotion or 1.0)
    end
end

-- Key shown in the badge above the tabs: E / RB on the wheel (-> ITEMS), Tab / LB in the
-- inventory (-> WEAPONS)
local function keyLabel(control, kb, pad)
    if not IsUsingKeyboard(0) then return pad or '' end
    local b = GetControlInstructionalButton(0, control, true)
    if type(b) == 'string' and b:sub(1, 2) == 't_' then return b:sub(3) end
    return kb or ''
end

local function switchLabel()
    return keyLabel(SWITCH, SWITCH == 206 and 'E' or '', SWITCH == 206 and 'RB' or '')
end

local function openWheel(ped, inVehicle)
    buildSlots(ped, inVehicle)
    hover = slotOf(equipped)
    open = true
    WeaponWheelOpen = true -- pause.lua: Esc doesn't open the pause menu over the wheel
    fx(true)
    local items = itemsOn()
    SendNUIMessage({
        type = 'wheel',
        action = 'open',
        slots = payload(ped),
        hover = hover - 1,
        iconUrl = Bridge.WeaponIconUrls(W.IconUrl),
        tabs = W.ShowTabs ~= false or items,
        items = items,
        key = items and switchLabel() or '',
    })
    click('NAV_UP_DOWN')
end

local function equip(ped, w)
    if oxSlot[w.hash] then return oxUse(oxSlot[w.hash]) end
    if w.hash == UNARMED and oxRunning() then
        -- ox_inventory holsters when the slot in hand is used again
        local ok, cur = pcall(function() return exports[OX]:getCurrentWeapon() end)
        if ok and type(cur) == 'table' and cur.slot then return oxUse(cur.slot) end
    end
    SetCurrentPedWeapon(ped, w.native, W.InstantEquip == true)
end

local function closeWheel(ped, pick)
    open = false
    WeaponWheelOpen = false
    fx(false)
    SendNUIMessage({ type = 'wheel', action = 'close' })

    if not pick or hover == 0 then return end
    local sl = slots[hover]
    local w = sl and sl.list[sl.idx]
    if not w then return end
    chosen[hover] = w.hash
    if w.hash ~= equipped then equip(ped, w) end
    click('SELECT')
end

-- ---------------------------------------------------------------------------
-- ITEMS tab = ox_inventory, with the WEAPONS / ITEMS header kept on top of it
-- ---------------------------------------------------------------------------

local itemsMode, itemsSince, itemsSeen = false, 0, false

local function toItems(ped)
    closeWheel(ped, false)
    itemsMode, itemsSince, itemsSeen = true, GetGameTimer(), false
    SendNUIMessage({ type = 'wheel', action = 'items', key = keyLabel(CONTROL_WHEEL, 'TAB', 'LB') })
    click('NAV_LEFT_RIGHT')
    CreateThread(function() -- openInventory waits on the server
        local ok, err = pcall(function() exports[OX]:openInventory() end)
        if not ok then print(('[vi-hud] weapon wheel: ox_inventory openInventory failed: %s'):format(err)) end
    end)
end

local function leaveItems()
    itemsMode = false
    SendNUIMessage({ type = 'wheel', action = 'itemsoff' })
end

-- Inventory opened some other way (F2 below, ox_inventory's own key, a stash...): same ITEMS
-- header on top, Tab goes to the wheel
local function enterItems()
    itemsMode, itemsSince, itemsSeen = true, GetGameTimer(), true
    SendNUIMessage({ type = 'wheel', action = 'items', key = keyLabel(CONTROL_WHEEL, 'TAB', 'LB') })
end

-- Quick open: F2 (Config.WeaponWheel.InventoryKey; players can rebind it in Settings > Key
-- Bindings > FiveM > vi-hud). Opens straight onto the ITEMS tab, F2 again closes it.
if W.Enabled and ITEMS and W.InventoryKey ~= false then
    local function boundKey(cmd)
        return GetControlInstructionalButton(0, GetHashKey(cmd) | 0x80000000, true)
    end

    RegisterCommand('+vi_inventory', function()
        if not itemsOn() or IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end
        -- ox_inventory's own key on the same button (F2 by default) already toggles it
        local oxSameKey = boundKey('+vi_inventory') == boundKey('+inv')

        if LocalPlayer.state.invOpen then
            if not oxSameKey then TriggerEvent('ox_inventory:closeInventory') end
        elseif open then
            toItems(PlayerPedId())
        elseif not oxSameKey and not IsNuiFocused() then
            CreateThread(function() -- openInventory waits on the server
                local ok, err = pcall(function() exports[OX]:openInventory() end)
                if not ok then print(('[vi-hud] ox_inventory openInventory failed: %s'):format(err)) end
            end)
        end
    end, false)
    RegisterCommand('-vi_inventory', function() end, false)
    RegisterKeyMapping('+vi_inventory', 'Inventory (ITEMS tab)', 'keyboard', W.InventoryKey or 'F2')
end

-- Nearest slot that has something in it, in the direction the cursor points
local function slotAt(angle)
    local best, bestDiff = 0, 999
    for s = 1, 8 do
        if #slots[s].list > 0 then
            local d = math.abs((angle - SLOT_ANGLE[s] + 540) % 360 - 180)
            if d < bestDiff then best, bestDiff = s, d end
        end
    end
    return best
end

local function anyJustPressed(keys)
    for i = 1, #keys do
        if IsDisabledControlJustPressed(0, keys[i]) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

CreateThread(function()
    if not W.Enabled then return end
    local cx, cy = 0.0, 0.0  -- virtual cursor (mouse) / stick direction, length 0..1
    local lastTab, invWas, warned = -100000, false, false
    -- Right after the inventory closes its NUI focus / hidden HUD can linger a frame; ignore
    -- them until then so the wheel isn't shut straight away
    local graceUntil = 0
    local dimOn = false

    while true do
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)

        -- ox_inventory open: darken the game behind it (see #invdim in html/weapons.css)
        local inv = oxRunning() and LocalPlayer.state.invOpen == true
        if inv ~= dimOn then
            dimOn = inv
            SendNUIMessage({ type = 'wheel', action = 'invdim', on = inv })
        end

        -- Remember what was held before, for the "last weapon" glow. ox_inventory (and other
        -- scripts) holster on the way to the next weapon, so A -> B passes through unarmed for a
        -- moment; that blip isn't "the last weapon", only fists held for a while are.
        local cur = u32(GetSelectedPedWeapon(ped))
        if cur ~= equipped then
            local t = GetGameTimer()
            if equipped and not (equipped == UNARMED and t - equippedAt < UNARMED_BLIP) then
                lastWeapon = equipped
            end
            equipped, equippedAt = cur, t
        end

        if inVehicle and not W.InVehicle then
            -- No weapon wheel at all in vehicles (GTA's own one stays blocked too)
            if open then closeWheel(ped, false) end
            if itemsMode then leaveItems() end
            BlockWeaponWheelThisFrame()
            DisableControlAction(0, CONTROL_WHEEL, true)
            Wait(0)
        else
            -- Kill GTA's own wheel
            BlockWeaponWheelThisFrame()
            DisableControlAction(0, CONTROL_WHEEL, true)

            local now = GetGameTimer()
            local blocked = IsPauseMenuActive() or IsEntityDead(ped) or IsPedRagdoll(ped)
            -- other UIs; the inventory hides the HUD and holds NUI focus while it's open
            local busy = IsNuiFocused() or IsHudHidden()
            local tabDown = IsDisabledControlPressed(0, CONTROL_WHEEL)
            local tabHit = IsDisabledControlJustPressed(0, CONTROL_WHEEL)
            if tabHit then lastTab = now end

            if inv and not invWas and not itemsMode and now - lastTab < 500 then
                -- The inventory popped up off the same Tab press: this player has ox_inventory's
                -- key bound to Tab (key bindings are per client and carry over from other servers).
                -- Tab belongs to the wheel, so shut the inventory again (the wheel is up while
                -- Tab is still held, as usual).
                TriggerEvent('ox_inventory:closeInventory')
                graceUntil = now + 300
                if not warned then
                    warned = true
                    print('^3[vi-hud] ox_inventory\'s inventory key is bound to Tab on this client, so it flashes open before the weapon wheel. Rebind it in Settings > Key Bindings > FiveM (ox_inventory), e.g. to F2.^0')
                end
            elseif inv and not invWas and not itemsMode and itemsOn() then
                enterItems() -- opened with F2 / its own key / a stash: ITEMS header on top
            end
            invWas = inv

            if itemsMode then
                if inv then itemsSeen = true end
                if blocked or (not inv and (itemsSeen or now - itemsSince > 1500)) then
                    leaveItems() -- inventory closed (esc / its own key), or it refused to open
                elseif inv and tabHit then
                    -- Back to WEAPONS: the wheel is up while Tab is held, letting go picks
                    itemsMode = false
                    TriggerEvent('ox_inventory:closeInventory')
                    graceUntil = now + 300
                    openWheel(ped, inVehicle)
                    cx, cy = 0.0, 0.0
                end
            elseif open then
                if blocked or (busy and now > graceUntil) then
                    closeWheel(ped, false)
                elseif not tabDown then
                    closeWheel(ped, true)
                elseif itemsOn() and IsDisabledControlJustPressed(0, SWITCH) then
                    toItems(ped) -- the inventory stays up until Tab is pressed again
                end
            elseif tabDown and not blocked and (not busy or now <= graceUntil) then
                openWheel(ped, inVehicle)
                cx, cy = 0.0, 0.0
            end

            if open then
                for i = 1, #BLOCK_WHILE_OPEN do DisableControlAction(0, BLOCK_WHILE_OPEN[i], true) end
                HideHudComponentThisFrame(2)  -- weapon icon
                HideHudComponentThisFrame(14) -- reticle
                HideHudComponentThisFrame(19) -- GTA's weapon wheel
                HideHudComponentThisFrame(20) -- GTA's weapon wheel stats

                local x, y = GetDisabledControlNormal(0, 1), GetDisabledControlNormal(0, 2)
                if IsUsingKeyboard(0) then
                    local k = W.MouseSensitivity or 1.2
                    cx, cy = cx + x * k, cy + y * k
                    local len = math.sqrt(cx * cx + cy * cy)
                    if len > 1.0 then cx, cy = cx / len, cy / len end
                else
                    -- either stick (the left one stops walking while the wheel is up)
                    for c = 30, 35 do DisableControlAction(0, c, true) end
                    local lx, ly = GetDisabledControlNormal(0, 30), GetDisabledControlNormal(0, 31)
                    if lx * lx + ly * ly > x * x + y * y then x, y = lx, ly end
                    if x * x + y * y > 0.25 then cx, cy = x, y end
                end

                if cx * cx + cy * cy > 0.35 * 0.35 then
                    local s = slotAt(math.deg(math.atan(cx, -cy)) % 360)
                    if s ~= 0 and s ~= hover then
                        hover = s
                        click('NAV_LEFT_RIGHT')
                        pushSelection()
                    end
                end

                -- Cycle weapons inside the highlighted slot
                if hover ~= 0 and #slots[hover].list > 1 then
                    local step = anyJustPressed(PREV_KEYS) and -1 or anyJustPressed(NEXT_KEYS) and 1 or 0
                    if step ~= 0 then
                        local sl = slots[hover]
                        sl.idx = (sl.idx - 1 + step) % #sl.list + 1
                        click('NAV_UP_DOWN')
                        pushSelection()
                    end
                end
            end

            Wait(0)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Weapon in hand: ammo + icon in the top-right corner
-- ---------------------------------------------------------------------------

-- The ammo is drawn with GTA's own text renderer in font 7 (Pricedown, the font GTA uses for its
-- cash / ammo counters); the icon is drawn by the NUI page right under it. Both are right-aligned
-- to the same edge, EDGE (in the page's unit, u = 1% of a 16:9 screen width) in from the corner.
local FONT_PRICEDOWN = 7
local EDGE = 0.25

local function hudGeometry()
    local m = 0.5 * math.abs(GetSafeZoneSize() - 1.0)
    local aspect = GetAspectRatio(false)
    local u = math.min(0.01, 0.017778 / aspect) -- 1u as a fraction of the screen width
    return m, u, u * aspect                     -- ..., and of the screen height
end

local function textWidth(str, scale)
    BeginTextCommandGetWidth('STRING')
    AddTextComponentSubstringPlayerName(str)
    SetTextFont(FONT_PRICEDOWN)
    SetTextScale(0.0, scale)
    return EndTextCommandGetWidth(true)
end

local function drawText(str, x, y, scale, c, alpha)
    SetTextFont(FONT_PRICEDOWN)
    SetTextScale(0.0, scale)
    SetTextColour(c[1], c[2], c[3], alpha)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(str)
    EndTextCommandDisplayText(x, y)
end

local CLIP_COLOUR, SPARE_COLOUR = { 238, 234, 230 }, { 185, 186, 181 }

-- Text widths only change with the string (or the screen), so they're measured once and reused.
-- Cleared when the aspect ratio / resolution changes, and when it gets big.
local widthCache, widthCount = {}, 0

local function clearWidths() widthCache, widthCount = {}, 0 end

local function cachedWidth(str, scale)
    local w = widthCache[str]
    if not w then
        if widthCount >= 256 then clearWidths() end
        w = textWidth(str, scale)
        widthCache[str] = w
        widthCount = widthCount + 1
    end
    return w
end

local function round4(v) return math.floor(v * 10000 + 0.5) / 10000 end

-- parts = { '13', '80' } (clip, spare) or { '3' } (count); right-aligned to the icon's edge
local widths = {}
local function drawAmmo(parts, alpha, scale, m, u, uh)
    local right = 1.0 - m - EDGE * u
    local y = m + EDGE * uh + (MoneyHudOffset or 0.0) -- pushed down while the money display (money.lua) is up
    local total = 0.0
    local space = cachedWidth('0', scale) * 0.55
    for i, p in ipairs(parts) do
        widths[i] = cachedWidth(p, scale)
        total = total + widths[i] + (i > 1 and space or 0.0)
    end
    local x = right - total
    for i, p in ipairs(parts) do
        drawText(p, x, y, scale, i == 1 and CLIP_COLOUR or SPARE_COLOUR, alpha)
        x = x + widths[i] + space
    end
end

CreateThread(function()
    if not HUD.Enabled then return end
    local scale = HUD.AmmoScale or 0.4
    local FADE = 300 -- ms, same as the icon's fade in weaponhud.css
    local parts
    local alpha, lastT = 0.0, GetGameTimer()
    -- What the NUI was last sent: sent = true (shown) / false (hidden) / nil (nothing yet)
    local sent, sentName, sentMargin, sentAmmoH, sentOffset = nil, nil, nil, nil, nil
    -- Rendered height of the ammo line, re-measured once a second (it only changes with the screen)
    local charH, nextMeasure, screenKey, screenAspect = 0, 0, nil, nil
    local lastClip, lastReserve, lastCount -- parts is only rebuilt when the ammo changes

    while true do
        local now = GetGameTimer()
        local dt = now - lastT
        lastT = now

        local ped = PlayerPedId()
        local hash = u32(GetSelectedPedWeapon(ped))
        local w = byHash[hash]
        local show = w and hash ~= UNARMED
            and not IsPauseMenuActive() and not IsHudHidden() and not IsEntityDead(ped)
            and not open
            and HudSettings.Shown('ammo')

        local m, u, uh
        if show or (alpha > 0 and parts) then
            m, u, uh = hudGeometry()
            -- Aspect ratio changed: cached text widths are stale
            local aspect = uh / u
            if aspect ~= screenAspect then
                screenAspect = aspect
                clearWidths()
            end
        end

        if show then
            -- Kill GTA's own weapon icon / ammo counter up there
            HideHudComponentThisFrame(2)
            HideHudComponentThisFrame(20)

            local a = ammoOf(ped, w)
            if a and a.clip then
                if not parts or #parts ~= 2 or a.clip ~= lastClip or a.reserve ~= lastReserve then
                    parts = { tostring(a.clip), tostring(a.reserve) }
                end
                lastClip, lastReserve, lastCount = a.clip, a.reserve, nil
            elseif a then
                if not parts or #parts ~= 1 or a.count ~= lastCount then parts = { tostring(a.count) } end
                lastClip, lastReserve, lastCount = nil, nil, a.count
            else
                parts, lastClip, lastReserve, lastCount = nil, nil, nil, nil
            end

            if now >= nextMeasure then
                nextMeasure = now + 1000
                charH = round4(GetRenderedCharacterHeight(scale, FONT_PRICEDOWN))
                local rx, ry = GetActiveScreenResolution()
                local key = rx * 100000 + ry
                if key ~= screenKey then
                    screenKey = key
                    clearWidths()
                end
            end

            local margin = round4(m)
            -- height of the ammo line (screen-height fraction) so the icon sits right under it
            local ammoH = parts and charH or 0
            local offset = round4(MoneyHudOffset or 0.0)
            if sent ~= true or w.name ~= sentName or margin ~= sentMargin
                or ammoH ~= sentAmmoH or offset ~= sentOffset then
                sent, sentName, sentMargin, sentAmmoH, sentOffset = true, w.name, margin, ammoH, offset
                SendNUIMessage({
                    type = 'weaponhud',
                    show = true,
                    name = w.name,
                    label = w.label,
                    margin = margin,
                    ammoH = ammoH,
                    iconUrl = Bridge.WeaponIconUrls(W.IconUrl or HUD.IconUrl),
                    iconSize = HUD.IconSize or 1.0,
                    offset = offset,
                })
            end

            -- How far down from the top margin this block reaches (inset + ammo + gap + icon at its
            -- max height, see weaponhud.css), so top-right notifications can sit under it
            WeaponHudHeight = (0.5 + 1.8 * (HUD.IconSize or 1.0)) * uh + ammoH
        elseif sent ~= false then
            sent = false
            WeaponHudHeight = 0.0
            SendNUIMessage({ type = 'weaponhud', show = false })
        end

        -- Native text can't use CSS, so fade it here in step with the icon
        alpha = math.max(0.0, math.min(255.0, alpha + (show and 1 or -1) * 255.0 * dt / FADE))
        if alpha > 0 and parts then drawAmmo(parts, math.floor(alpha), scale, m, u, uh) end

        if not show and alpha <= 0 then Wait(150) else Wait(0) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SendNUIMessage({ type = 'weaponhud', show = false })
    if not open then return end
    open = false
    TriggerScreenblurFadeOut(0)
    SetTimeScale(1.0)
end)
