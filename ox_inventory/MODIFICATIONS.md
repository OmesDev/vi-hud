# Modifications

This is a **modified copy** of [ox_inventory](https://github.com/overextended/ox_inventory) by
Overextended (Linden, Luke, Dunak and contributors), shipped with
[vi-hud](https://github.com/OmesDev/vi-hud).

- **Based on:** ox_inventory **v2.48.1**, official release
  ([ox_inventory.zip](https://github.com/overextended/ox_inventory/releases/download/v2.48.1/ox_inventory.zip))
- **Modified by:** Omar Mohamed ([OmesDev](https://github.com/OmesDev)) for vi-hud
- **Date of modification:** 2026-11-02
- **License:** GPL-3.0-or-later, same as the original. See [LICENSE](./LICENSE) and [NOTICE.md](./NOTICE.md).
  vi-hud's own license does **not** apply to anything in this folder.

## What was changed

Everything not listed here is the unmodified v2.48.1 release.

| File | Change |
|------|--------|
| `web/build/assets/vi-theme.css` | **Added.** GTA VI style theme matching vi-hud's weapon wheel. Loaded after ox_inventory's own `index.css` and only restyles its existing markup. |
| `web/build/index.html` | **Edited.** Added three lines in `<head>`, marked with a comment: Google Fonts (Barlow Condensed, Inter), `vi-theme.css`, and a small script that stops `Tab` from moving browser focus (vi-hud uses `Tab` for its weapon wheel). |

No Lua, locale, data or compiled JavaScript files were changed.

## Source code

- The theme is plain, unminified CSS. `vi-theme.css` is its own source.
- The rest of `web/build/` is ox_inventory's unmodified compiled UI. Its source is the `web/` folder
  of the original project at tag v2.48.1:
  https://github.com/overextended/ox_inventory/tree/v2.48.1/web

## Going back to stock

Delete `web/build/assets/vi-theme.css` and remove the three marked lines from `web/build/index.html`.
If you update ox_inventory, add those lines and the CSS file back to keep the theme.
