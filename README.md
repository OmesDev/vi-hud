# vi-hud

A GTA VI inspired HUD for FiveM. Works with **ESX**, **QBCore**, **Qbox** or **standalone** (no framework).

---

## Contents

1. [Features](#features)
2. [Requirements](#requirements)
3. [What's in the download](#whats-in-the-download)
4. [Installation](#installation)
5. [Optional: ox_inventory](#optional-ox_inventory)
6. [Controls and commands](#controls-and-commands)
7. [Configuration](#configuration)
8. [Notifications](#notifications)
9. [Exports and events](#exports-and-events)
10. [Customisation](#customisation)
11. [Troubleshooting](#troubleshooting)
12. [License](#license)

---

## Features

| Feature              | What it does                                                                         |
|----------------------|--------------------------------------------------------------------------------------|
| **Minimap**          | Glass-style panel, custom player arrow, street name bar, turn-by-turn directions, pink GPS route |
| **Radio wheel**      | Station strip at the top of the screen (hold `Q`)                                    |
| **Weapon wheel**     | 8-tile wheel (hold `TAB`), with an ITEMS tab when ox_inventory is installed          |
| **Weapon HUD**       | Ammo and weapon icon, top-right                                                      |
| **Speedometer**      | `minimal` or `gauge` style, with fuel, engine and seatbelt                           |
| **Status icons**     | Health, armour, stamina, hunger, thirst, oxygen, mic (only shown when relevant)      |
| **Compass**          | Heading tape at the top of the screen, with a waypoint marker                        |
| **Money**            | Cash and bank, shown when they change                                                |
| **Notifications**    | One feed for the whole server that can take over other notification scripts         |
| **Pause menu**       | Replaces GTA's Esc menu, and you can add your own buttons                            |
| **Chat theme**       | Restyles FiveM's default chat to match the HUD                                       |
| **Player settings**  | `/hud` lets each player customise their own HUD (saved on their PC)                  |

---

## Requirements

vi-hud works on its own. Everything below is **optional** and only adds extra features.

| Resource                                                  | Needed?  | What it adds                                         |
|-----------------------------------------------------------|----------|------------------------------------------------------|
| A framework (ESX, QBCore or Qbox)                         | Optional | Money, hunger and thirst are picked up automatically |
| [ox_inventory](#optional-ox_inventory) (included)         | Optional | Inventory weapons in the wheel, ammo counts, ITEMS tab |
| [pma-voice](https://github.com/AvarianKnight/pma-voice)   | Optional | Mic indicator and voice range                        |

---

## What's in the download

```
vi-hud/              <- the HUD (required)
└── ox_inventory/    <- optional, themed copy of ox_inventory (GPL-3.0, see License)
```

The `ox_inventory` folder comes **inside** `vi-hud`. FiveM doesn't load a resource that sits inside another one, so it does nothing there. To use it, move it out into your `resources` folder (see [Installing ox_inventory](#installing-ox_inventory)). If you don't want it, delete it.

---

## Installation

### Step 1: Copy the files

Copy the `vi-hud` folder into your server's `resources` folder.

Don't rename the folder. Other scripts call it by the name `vi-hud`.

### Step 2: Add it to `server.cfg`

Add this line to `server.cfg`:

```cfg
ensure vi-hud
```

It must come **after** your framework, inventory and notification resources. For example:

```cfg
ensure oxmysql
ensure ox_lib
ensure es_extended     # your framework (es_extended, qb-core or qbx_core)
ensure ox_inventory    # only if you use it
ensure pma-voice       # only if you use it
ensure vi-hud          # last
```

> **Using a folder like `ensure [standalone]`?** Resources inside a folder start in alphabetical order. That's fine as long as your framework starts **before** that folder.

### Step 3: Choose your framework

Open [config.lua](config.lua) and set `Config.Framework`:

```lua
Config.Framework = 'esx'   -- 'esx', 'qbcore', 'qbox', 'standalone', or 'auto' to detect it
```

### Step 4: Restart and test

1. Restart your server (or type `refresh` and then `ensure vi-hud` in the server console).
2. Join the server and get in a vehicle. The minimap, speedometer and compass should appear.
3. Type `/notifytest` in chat to see example notifications.
4. Type `/hud` to open the settings menu.

That's it. vi-hud is installed. Keep reading only if you want ox_inventory or want to change settings.

---

## Optional: ox_inventory

ox_inventory is a slot-based inventory made by [Overextended](https://github.com/overextended/ox_inventory). A copy is included in the download, and vi-hud works with or without it.

### Do I need it?

| Your situation                        | What to do                                                          |
|---------------------------------------|---------------------------------------------------------------------|
| You don't want ox_inventory           | Skip this section and delete the included `ox_inventory` folder.     |
| You already have ox_inventory         | Keep your own copy and delete the included one. vi-hud uses it automatically. |
| You use another inventory             | Skip this section. See [Other inventories](#other-inventories).     |
| You want to install it                | Follow the steps below.                                             |

> **QBCore servers:** ox_inventory supports **ESX**, **Qbox**, **ox_core** and **ND Core**. It does not officially support QBCore.

### What ox_inventory needs

| Requirement                                               | Notes                                    |
|-----------------------------------------------------------|------------------------------------------|
| [oxmysql](https://github.com/overextended/oxmysql)        | Plus a working database                  |
| [ox_lib](https://github.com/overextended/ox_lib)          |                                          |
| OneSync                                                   | Turned on in your server settings        |
| Server artifact **6116** or newer                         | Update your FXServer if it's older       |

### Installing ox_inventory

1. Move the included `vi-hud/ox_inventory` folder **out of `vi-hud`** and into your `resources` folder, next to `vi-hud`.
2. In `server.cfg`, make sure it starts after `oxmysql`, `ox_lib` and your framework, and **before** `vi-hud`:

   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure es_extended
   ensure ox_inventory
   ensure vi-hud
   ```

3. Tell ox_inventory which framework you use by adding **one** of these lines to `server.cfg`:

   ```cfg
   setr inventory:framework "esx"    # ESX
   setr inventory:framework "qbx"    # Qbox
   ```

4. Follow the framework setup in the [ox_inventory documentation](https://overextended.dev/docs/ox_inventory). Some frameworks need extra database or config steps.
5. Restart the server.

vi-hud finds ox_inventory by itself. You don't need to change anything in vi-hud.

### What it adds to the HUD

- **Weapons come from the inventory.** The wheel lists the weapons in your inventory and equips them through ox_inventory.
- **Ammo is read from the inventory.** Spare ammo comes from ammo items, throwables show their stack count, and a weapon you're not holding shows the rounds still loaded in it.
- **WEAPONS / ITEMS tabs.** Hold `TAB` to open the wheel, then press `E` (`RB` on a controller) to switch to **ITEMS**. The inventory opens and stays open until you press `TAB` again.
- **Inventory key.** `F2` opens the inventory straight onto the ITEMS tab, and pressing it again closes it. Players can rebind it in **Settings > Key Bindings > FiveM > vi-hud**.

### ox_inventory settings in vi-hud

In [config.lua](config.lua):

```lua
Config.WeaponWheel.Items = true          -- false = no ITEMS tab
Config.WeaponWheel.SwitchControl = 206   -- control that switches to ITEMS (206 = E / RB)
Config.WeaponWheel.InventoryKey = 'F2'   -- false = no inventory key from vi-hud
```

### Other inventories

With **qb-inventory**, **ps-inventory**, **lj-inventory** or **qs-inventory**, the wheel shows the weapons your character is carrying and only takes the weapon **icons** from the inventory. There's no ITEMS tab for these.

---

## Controls and commands

### Controls

| Key          | Action                                                      |
|--------------|-------------------------------------------------------------|
| Hold `Q`     | Radio wheel (in a vehicle)                                  |
| Hold `TAB`   | Weapon wheel                                                |
| `E` / `RB`   | Switch the weapon wheel to the ITEMS tab (ox_inventory only) |
| `F2`         | Open the inventory on the ITEMS tab (ox_inventory only)     |
| `Esc`        | Pause menu                                                  |

### Commands

| Command       | Description                     |
|---------------|---------------------------------|
| `/hud`        | Opens the HUD settings menu     |
| `/money`      | Shows cash and bank             |
| `/notifytest` | Shows example notifications     |

Command names can be changed or turned off in [config.lua](config.lua).

---

## Configuration

All settings are in [config.lua](config.lua). Each part of the HUD has its own section, and every section has `Enabled = true` so you can turn that part off.

| Section              | Controls                                                  |
|----------------------|-----------------------------------------------------------|
| General              | Framework, `/hud` command name, `mi` or `km`              |
| Minimap              | Shape, scale, street bar, GPS route colour, tint, layout  |
| `Config.Radio`       | Radio wheel                                               |
| `Config.WeaponWheel` | Weapon wheel, ITEMS tab, inventory key, add-on weapons    |
| `Config.WeaponHud`   | Ammo and weapon icon                                      |
| `Config.Speedometer` | Style, units, fuel, engine, seatbelt                      |
| `Config.Status`      | Health, armour, hunger, thirst icons                      |
| `Config.Compass`     | Compass tape                                              |
| `Config.Voice`       | Mic indicator (pma-voice)                                 |
| `Config.Money`       | Cash and bank display                                     |
| `Config.Notify`      | Notification position, sound, replacing other scripts     |
| `Config.PauseMenu`   | Pause menu title, heading, custom buttons                 |

Players can also change their own HUD in game with `/hud`. Those settings are saved on their PC and don't affect anyone else.

---

## Notifications

### From a client script

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

### From a server script

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

vi-hud can show other scripts' notifications in its own feed. Turn each one on or off in `Config.Notify.Replace`. The scripts that send notifications don't need any changes.

| Resource                                 | What to do                                                       |
|------------------------------------------|------------------------------------------------------------------|
| `okokNotify`, `mythic_notify`, `pNotify` | Stop or remove that resource. vi-hud handles its exports and events. |
| `ox_lib`                                 | Add one line to `lib.notify` (below)                             |
| `esx_notify`                             | Add the lines below to `Notify`, and keep the esx_notify folder  |
| `qb-core` / Qbox                         | Add one line to `QBCore.Functions.Notify` (below)                |

**ox_lib**: in `ox_lib/resource/interface/client/notify.lua`, at the top of `function lib.notify(data)`:

```lua
if GetResourceState('vi-hud') == 'started' and pcall(function() exports['vi-hud']:Notify(data) end) then return end
```

**esx_notify**: in `esx_notify/Notify.lua`, at the top of `local function Notify(...)`:

```lua
if GetResourceState('vi-hud') == 'started' and pcall(function()
    exports['vi-hud']:Notify({ type = notificatonType, duration = length, description = message, title = title, position = position })
end) then return end
```

**qb-core**: in `qb-core/client/functions.lua`, at the top of `QBCore.Functions.Notify`:

```lua
if GetResourceState('vi-hud') == 'started' then return exports['vi-hud']:Notify(text, texttype, length) end
```

> Updating ox_lib, esx_notify or qb-core overwrites these lines, so add them again after an update.

---

## Exports and events

All of these are **client-side**.

### Money

```lua
exports['vi-hud']:SetMoney(cash, bank) -- number = set, nil = keep, false = hide that row
exports['vi-hud']:ShowMoney()          -- shows the money display
```

ESX and QBCore/Qbox balances are picked up automatically. `SetMoney` is for standalone servers.

### Hunger and thirst

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

## Customisation

### Pause menu buttons

```lua
Config.PauseMenu.Buttons = {
    { label = 'Rules',   icon = 'fa-solid fa-scroll',         url = 'https://example.com/rules' },
    { label = 'Emotes',  icon = 'fa-solid fa-person-walking', command = 'emotemenu' },
    { label = 'Phone',   icon = 'fa-solid fa-mobile',         event = 'phone:open' },
    { label = 'Report',  icon = 'fa-solid fa-flag',           serverEvent = 'reports:open', keepOpen = true },
}
```

These show as small link buttons in the bottom-right corner, below the main tiles (mouse, or `↑` / `↓` to move between the two rows). Each button needs one action: `url`, `command`, `event` (client) or `serverEvent`. Add `keepOpen = true` to keep the menu open after it's pressed.

### Weapon icons

Put a PNG in `html/weapons/` named after the weapon, e.g. `WEAPON_PISTOL.png`.

Weapons without a custom PNG use icons from your inventory (ox_inventory, qb-inventory, ps-inventory, lj-inventory, qs-inventory, esx_weaponshop), or from `Config.WeaponWheel.IconUrl`.

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

1. In game, type `/hud` and go to **Minimap** > **Edit layout**.
2. Arrange the minimap, then press **Copy values**.
3. Paste the result into `Config.Layout` in [config.lua](config.lua).

---

## Troubleshooting

| Problem                                              | Fix                                                                                       |
|------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Money, hunger or thirst don't show                   | Check `Config.Framework`, and make sure `vi-hud` starts **after** your framework.          |
| The GPS route disappears                             | Set `Config.HideSatnavDistance = false`.                                                   |
| The GPS route is cut off at the edge of the map      | Use `Config.Shape = 'fit'` (recommended). In `'wide'` mode, GTA can't draw the route past its normal radar area. |
| The minimap is in the wrong place                    | Don't move GTA's radar with another script. vi-hud depends on its default position.        |
| No mic indicator or voice range                      | Install and start **pma-voice** before vi-hud.                                             |
| No ITEMS tab in the weapon wheel                     | It needs ox_inventory. Check that ox_inventory is started and `Config.WeaponWheel.Items = true`. |
| The inventory flashes open when pressing `TAB`       | That player has ox_inventory's own inventory key bound to `TAB`. vi-hud prints a warning in their F8 console. Have them rebind ox_inventory's key (e.g. to `F2`) in **Settings > Key Bindings > FiveM**. |
| Other scripts' notifications stopped using vi-hud    | You probably updated ox_lib, esx_notify or qb-core. Add the lines from [Replacing other notification scripts](#replacing-other-notification-scripts) again. |

---

## License

### ox_inventory (bundled)

The `ox_inventory` folder is a modified copy of [ox_inventory](https://github.com/overextended/ox_inventory) v2.48.1 by Overextended (Linden, Luke, Dunak and contributors). It's licensed under **GPL-3.0-or-later**, and vi-hud's own terms don't apply to it.

- Full license text: [ox_inventory/LICENSE](ox_inventory/LICENSE)
- Copyright and attribution: [ox_inventory/NOTICE.md](ox_inventory/NOTICE.md)
- What was changed (only the vi-hud theme): [ox_inventory/MODIFICATIONS.md](ox_inventory/MODIFICATIONS.md)
- Original source: https://github.com/overextended/ox_inventory

You're free to use, modify and redistribute it under the GPL-3.0. It's kept unencrypted on purpose (`escrow_ignore` in [fxmanifest.lua](fxmanifest.lua)). Keep it that way if you repackage vi-hud.
