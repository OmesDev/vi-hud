# vi-hud

A GTA VI inspired HUD for FiveM. Works with **ESX**, **QBCore**, **Qbox** or **standalone**.

## Features

- **Minimap**: glass-style panel, custom player arrow, street name bar, turn-by-turn directions, pink GPS route
- **Radio wheel**: station strip at the top of the screen (hold `Q`)
- **Weapon wheel**: 8-tile wheel (hold `TAB`), with an ITEMS tab when ox_inventory is running
- **Weapon HUD**: ammo and weapon icon, top-right
- **Speedometer**: `minimal` or `gauge` style, with fuel, engine and seatbelt
- **Status icons**: health, armour, stamina, hunger, thirst, oxygen, mic (they only show when relevant)
- **Compass**: heading tape at the top of the screen, with a waypoint marker
- **Money**: cash and bank, shown when they change
- **Notifications**: one feed for the whole server that can take over other notification scripts
- **Pause menu**: replaces GTA's Esc menu, and you can add your own buttons
- **Chat theme**: restyles FiveM's default chat to match the HUD
- **Player settings**: `/hud` lets each player customise their own HUD (saved on their PC)

## Installation

1. Put `vi-hud` in your resources folder.
2. Add `ensure vi-hud` to `server.cfg`, **after** your framework, inventory and notification resources.
3. Set `Config.Framework` in [config.lua](config.lua).

## Commands

| Command       | Description                              |
|---------------|------------------------------------------|
| `/hud`        | Opens the HUD settings menu              |
| `/money`      | Shows cash and bank                      |
| `/notifytest` | Shows example notifications              |

Command names can be changed or turned off in the config.

---

## Notifications

### Client

```lua
-- Table form
exports['vi-hud']:Notify({
    title = 'Paid',
    description = 'You received $500',
    type = 'success',      -- info | success | warning | error
    duration = 5000,       -- ms (optional)
    icon = 'car',          -- Font Awesome icon (optional)
    iconColor = '#37c6aa', -- optional
    id = 'my-notif',       -- optional: sending the same id again updates that card
})

-- Short form: message, type, duration, title
exports['vi-hud']:Notify('Not enough money', 'error', 5000, 'Shop')

-- Event
TriggerEvent('vi-hud:notify', { title = 'Hi', description = 'Hello!', type = 'info' })
```

### Server

```lua
exports['vi-hud']:Notify(source, { title = 'Paid', description = '$500', type = 'success' })
exports['vi-hud']:Notify(source, 'Message', 'error', 5000, 'Title')
exports['vi-hud']:Notify(-1, 'Server restart in 5 minutes', 'warning') -- -1 = everyone

TriggerClientEvent('vi-hud:notify', source, { description = 'Hello', type = 'info' })
```

### Text formatting

| Format                                    | Result                         |
|-------------------------------------------|--------------------------------|
| `**bold**` `*italic*` `` `code` ``        | Markdown style                 |
| `~r~ ~g~ ~b~ ~y~ ~o~ ~p~ ~c~ ~s~`         | GTA colours (`~s~` = reset)    |
| `~h~`                                     | Bold                           |
| `~n~`                                     | New line                       |
| `~INPUT_CONTEXT~`                         | Shows the key for that control |

Type aliases also work, e.g. `inform`, `primary`, `danger`, `warn`.

### Replacing other notification scripts

When the replacement for a script is on in `Config.Notify.Replace`, notifications sent through it show up in vi-hud's feed instead. The scripts that send them don't need any changes.

| Resource                             | What to do                                                      |
|--------------------------------------|-----------------------------------------------------------------|
| `okokNotify`, `mythic_notify`, `pNotify` | Stop or remove that resource. vi-hud handles its exports and events. |
| `ox_lib`                             | Add the line below to `lib.notify`                              |
| `esx_notify`                         | Add the lines below to `Notify`, and keep the esx_notify folder  |
| `qb-core` / Qbox                     | Add the line below to `QBCore.Functions.Notify`                 |

**ox_lib**: `ox_lib/resource/interface/client/notify.lua`, at the top of `function lib.notify(data)`:

```lua
if GetResourceState('vi-hud') == 'started' and pcall(function() exports['vi-hud']:Notify(data) end) then return end
```

**esx_notify**: `esx_notify/Notify.lua`, at the top of `local function Notify(...)`:

```lua
if GetResourceState('vi-hud') == 'started' and pcall(function()
    exports['vi-hud']:Notify({ type = notificatonType, duration = length, description = message, title = title, position = position })
end) then return end
```

**qb-core**: `qb-core/client/functions.lua`, at the top of `QBCore.Functions.Notify`:

```lua
if GetResourceState('vi-hud') == 'started' then return exports['vi-hud']:Notify(text, texttype, length) end
```

> Updating ox_lib, esx_notify or qb-core will overwrite these lines, so add them again after an update.

---

## Other exports (client)

### Money

```lua
exports['vi-hud']:SetMoney(cash, bank) -- number = set, nil = keep, false = hide that row
exports['vi-hud']:ShowMoney()          -- shows the money display
```

ESX and QBCore/Qbox balances are picked up automatically. `SetMoney` is for standalone servers.

### Hunger / thirst

```lua
exports['vi-hud']:SetNeeds(hunger, thirst) -- 0-100, nil or -1 = hide
```

Picked up automatically from `esx_status` (ESX), player metadata (QBCore/Qbox) and state bags.

### Seatbelt

```lua
exports['vi-hud']:SetSeatbelt(true)  -- buckled
exports['vi-hud']:SetSeatbelt(false) -- unbuckled
exports['vi-hud']:SetSeatbelt(nil)   -- back to auto-detection
```

Auto-detects `esx_cruisecontrol`, `qb-smallresources` and `qbx_seatbelt`. For another script, set `SeatbeltResource` and `SeatbeltExport` in `Config.Speedometer`.

### Pause menu

```lua
exports['vi-hud']:BlockPauseMenu(true)  -- stop Esc from opening it (e.g. while your UI uses Esc)
exports['vi-hud']:BlockPauseMenu(false)
exports['vi-hud']:OpenPauseMenu()
exports['vi-hud']:ClosePauseMenu()
exports['vi-hud']:IsPauseMenuOpen()     -- returns true / false
```

### Events

Each export above has a matching client event:

```lua
TriggerEvent('vi-hud:setMoney', cash, bank)
TriggerEvent('vi-hud:showMoney')
TriggerEvent('vi-hud:setNeeds', hunger, thirst)
TriggerEvent('vi-hud:setSeatbelt', state)
TriggerEvent('vi-hud:openSettings') -- opens /hud
```

---

## Inventory (ox_inventory)

When **ox_inventory** is running, the weapon wheel uses it automatically. No setup is needed.

- **Weapons come from the inventory**: the wheel lists the weapons in your inventory and equips them through ox_inventory.
- **Ammo is read from the inventory**: spare ammo comes from ammo items, throwables show their stack count, and a weapon you're not holding shows the rounds still loaded in it.
- **WEAPONS / ITEMS tabs**: hold `TAB` to open the wheel, then press `E` (`RB` on a controller) to switch to **ITEMS**. The inventory opens and stays open until you press `TAB` again.
- **Inventory key**: `F2` opens the inventory straight onto the ITEMS tab, and pressing it again closes it. Players can rebind it in **Settings > Key Bindings > FiveM > vi-hud**.

```lua
Config.WeaponWheel.Items = true          -- false = no ITEMS tab
Config.WeaponWheel.SwitchControl = 206   -- control that switches to ITEMS (206 = E / RB)
Config.WeaponWheel.InventoryKey = 'F2'   -- false = no inventory key from vi-hud
```

> If a player has ox_inventory's own inventory key bound to `TAB`, it flashes open before the wheel, and vi-hud prints a warning in their F8 console. Have them rebind ox_inventory's key (e.g. to `F2`) in **Settings > Key Bindings > FiveM**.

**Other inventories** (qb-inventory, ps-inventory, lj-inventory, qs-inventory): the wheel uses the weapons your character is carrying and only takes the weapon **icons** from the inventory. There's no ITEMS tab for these.

---

## Customisation

### Pause menu buttons

```lua
Config.PauseMenu.Buttons = {
    { label = 'Rules',   icon = 'fa-solid fa-scroll',          url = 'https://example.com/rules' },
    { label = 'Emotes',  icon = 'fa-solid fa-person-walking', command = 'emotemenu' },
    { label = 'Phone',   icon = 'fa-solid fa-mobile',         event = 'phone:open' },
    { label = 'Report',  icon = 'fa-solid fa-flag',           serverEvent = 'reports:open', keepOpen = true },
}
```

Each button needs one action: `url`, `command`, `event` (client) or `serverEvent`. Add `keepOpen = true` to keep the menu open after it's pressed.

### Weapon icons

Put a PNG in `html/weapons/` named after the weapon, e.g. `WEAPON_PISTOL.png`. Weapons without a custom PNG use icons from your inventory (ox_inventory, qb-inventory, ps-inventory, lj-inventory, qs-inventory, esx_weaponshop), or from `Config.WeaponWheel.IconUrl`.

### Add-on weapons

```lua
Config.WeaponWheel.Extra = {
    { name = 'WEAPON_MYGUN', label = 'My Gun', kind = 'rifle' },
}
```

Kinds: `handgun`, `smg`, `mg`, `melee`, `gadget`, `shotgun`, `rifle`, `sniper`, `explosive`, `throwable`, `heavy`

### Radio logos

Put a square PNG in `html/stations/` named after the station, e.g. `RADIO_01_CLASS_ROCK.png`.

### Server-wide minimap layout

In game, go to `/hud` > **Minimap** > **Edit layout**, press **Copy values**, and paste the result into `Config.Layout`.

---

## Notes

- `Config.Shape = 'fit'` is recommended. In `'wide'` mode, GTA can't draw the GPS route past its normal radar area.
- Voice range and the radio indicator need **pma-voice**.
- Don't move GTA's radar with another script, because the minimap depends on its default position.
