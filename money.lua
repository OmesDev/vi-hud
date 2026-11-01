-- GTA VI style money display, top-right: bank and cash, each with its icon disc, and the change
-- ("+55,500") under the account that just moved. Hidden until the money changes (just that
-- account pops up) or the command is used (every account), then fades out after
-- Config.Money.ShowTime. See Config.Money.
-- The amounts are drawn in-game in GTA's Pricedown font (same as the ammo counter); the icon
-- discs next to them are drawn by the NUI page (html/money.js) at the row positions sent from here.
-- While it's up, the weapon / ammo display under it is pushed down (MoneyHudOffset, weapons.lua).

MoneyHudOffset = 0.0 -- screen-height fraction; read by weapons.lua

local C = Config.Money or {}
if not C.Enabled then return end

local FONT_PRICEDOWN = 7
local K = C.Scale or 1.0
-- Proportions measured off the reference: disc = 1.67x the digits' height, rows 1.9x apart,
-- the change line 0.6x as tall, centred 1.65x the digits' height under its row.
-- (Pricedown digits at text scale 0.5 are ~0.98u tall.)
local EDGE = 0.25          -- right / top inset (u), same as the weapon HUD
local DISC = 1.63 * K      -- icon disc size (u)
local GAP = 0.55 * K       -- disc -> amount (u)
local PITCH = 1.84 * K     -- row centre -> next row centre (u)
local DELTA_DY = 1.6 * K   -- row centre -> its change line's centre (u)
local DELTA_PITCH = 2.95 * K -- row centre -> next row centre when there's a change line between (u)
local AMOUNT_SCALE = 0.5 * K
local DELTA_SCALE = 0.3 * K
local FADE = 300           -- ms, same as the disc fade in money.css
local ROLL = 900           -- ms the numbers take to count up / down to a new value
local SHOW_TIME = C.ShowTime or 10000

local WHITE = { 245, 245, 245 }
local GAIN = { 96, 172, 97 }
local LOSS = { 240, 98, 150 }

local ROWS = {}
if C.Bank ~= false then ROWS[#ROWS + 1] = 'bank' end
if C.Cash ~= false then ROWS[#ROWS + 1] = 'cash' end

-- value = real balance, shown = number on screen (rolls towards value), delta = change since it
-- popped up, active = row is on screen (only the account that changed, or all of them on /money)
local acc = {}
for _, n in ipairs(ROWS) do acc[n] = { value = nil, shown = 0, from = 0, t0 = 0, delta = 0, active = false } end

local hideAt = 0
local alpha = 0.0

-- name = pop up just that account (and keep any already up); nil = every account
local function show(name)
    if type(name) ~= 'string' or not acc[name] then
        for _, n in ipairs(ROWS) do acc[n].active = true end
    else
        -- Was already gone (or fading): start over with only this one
        if alpha <= 0 or GetGameTimer() >= hideAt then
            for _, n in ipairs(ROWS) do acc[n].active = false end
        end
        acc[name].active = true
    end
    hideAt = GetGameTimer() + SHOW_TIME
end

-- ------------------------------------------------------------------ formatting

local function commas(n)
    local s = string.format('%d', math.floor(math.abs(n) + 0.5))
    return (s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
end

local function money(n) return (n < 0 and '-$' or '$') .. commas(n) end
local function change(n) return (n < 0 and '-' or '+') .. commas(n) end

-- ------------------------------------------------------------------ drawing

local function hudGeometry()
    local m = 0.5 * math.abs(GetSafeZoneSize() - 1.0)
    local aspect = GetAspectRatio(false)
    local u = math.min(0.01, 0.017778 / aspect) -- 1u as a fraction of the screen width
    return m, u, u * aspect                     -- ..., and of the screen height
end

local function drawRight(str, right, y, scale, c, a)
    SetTextFont(FONT_PRICEDOWN)
    SetTextScale(0.0, scale)
    SetTextColour(c[1], c[2], c[3], a)
    SetTextOutline()
    SetTextJustification(2)
    SetTextWrap(0.0, right)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(str)
    EndTextCommandDisplayText(right, y)
end

-- Draws the rows; returns the block height (screen-height fraction) and the disc centres for the NUI
local function draw(a)
    local m, u, uh = hudGeometry()
    local textRight = 1.0 - m - (EDGE + DISC + GAP) * u
    local top = m + EDGE * uh
    -- Native text is placed by its top edge; half the rendered line height centres it on a y
    local amountH = GetRenderedCharacterHeight(AMOUNT_SCALE, FONT_PRICEDOWN)
    local deltaH = GetRenderedCharacterHeight(DELTA_SCALE, FONT_PRICEDOWN)
    local nudge = (C.TextNudge or 0.0) * uh

    local cy, bottom, rows = top + DISC * 0.5 * uh, top, {}
    for _, n in ipairs(ROWS) do
        local s = acc[n]
        if s.value and s.active then
            drawRight(money(s.shown), textRight, cy - amountH * 0.5 + nudge, AMOUNT_SCALE, WHITE, a)
            rows[#rows + 1] = { n = n, y = math.floor(cy * 10000 + 0.5) / 10000 }
            bottom = cy + DISC * 0.5 * uh
            if s.delta ~= 0 then
                local dy = cy + DELTA_DY * uh
                drawRight(change(s.delta), textRight, dy - deltaH * 0.5 + nudge, DELTA_SCALE, s.delta > 0 and GAIN or LOSS, a)
                bottom = math.max(bottom, dy + 0.35 * K * uh)
                cy = cy + DELTA_PITCH * uh
            else
                cy = cy + PITCH * uh
            end
        end
    end
    return #rows > 0 and (bottom - top + 0.35 * uh) or 0.0, rows, m
end

-- ------------------------------------------------------------------ balance changes

local function ease(t) return 1 - (1 - t) ^ 3 end

local function poll(now)
    for _, n in ipairs(ROWS) do
        local s = acc[n]
        local v = Bridge.Money[n]
        if v ~= s.value then
            if v == nil or s.value == nil or C.ShowOnChange == false and now >= hideAt then
                -- logged in / out / switched character, or popping up on change is off: no animation
                s.value, s.shown, s.from, s.delta = v, v or 0, v or 0, 0
            else
                s.delta = s.delta + (v - s.value)
                s.from, s.t0, s.value = s.shown, now, v
                if C.CountUp == false then s.shown = v end
                show(n)
            end
        end
        if s.value and s.shown ~= s.value then
            local t = math.min(1.0, (now - s.t0) / ROLL)
            s.shown = t >= 1.0 and s.value or s.from + (s.value - s.from) * ease(t)
        end
    end
end

-- ------------------------------------------------------------------ main loop

CreateThread(function()
    local lastT, lastKey = GetGameTimer(), nil

    while true do
        local now = GetGameTimer()
        local dt = now - lastT
        lastT = now

        poll(now)

        local any = false
        for _, n in ipairs(ROWS) do if acc[n].value and acc[n].active then any = true end end
        local visible = any and now < hideAt and not IsPauseMenuActive() and not IsHudHidden()
            and HudSettings.Shown('money')

        alpha = math.max(0.0, math.min(255.0, alpha + (visible and 1 or -1) * 255.0 * dt / FADE))

        local height, rows, margin = 0.0, nil, nil
        if alpha > 0 then height, rows, margin = draw(math.floor(alpha)) end

        -- Icon discs (NUI): only re-sent when something moved
        local key = 'off'
        if visible and rows then
            local parts = { margin }
            for _, r in ipairs(rows) do parts[#parts + 1] = r.n .. r.y end
            key = table.concat(parts, '|')
        end
        if key ~= lastKey then
            lastKey = key
            if key == 'off' then
                SendNUIMessage({ type = 'money', show = false })
            else
                SendNUIMessage({ type = 'money', show = true, rows = rows, k = K,
                    margin = math.floor(margin * 10000 + 0.5) / 10000 })
            end
        end

        -- Faded out: the next pop-up starts clean (no rows, no change lines)
        if alpha <= 0 and not visible then
            for _, n in ipairs(ROWS) do acc[n].delta, acc[n].active = 0, false end
        end

        -- Slide the weapon HUD down while this is up, back up once it's gone
        local target = alpha > 0 and height or 0.0
        MoneyHudOffset = MoneyHudOffset + (target - MoneyHudOffset) * (1 - math.exp(-dt / 70))
        if math.abs(target - MoneyHudOffset) < 0.0005 then MoneyHudOffset = target end

        if alpha <= 0 and MoneyHudOffset == 0.0 then Wait(150) else Wait(0) end
    end
end)

-- ------------------------------------------------------------------ command / exports

if C.Command then
    RegisterCommand(C.Command, show, false)
    if C.Key then RegisterKeyMapping(C.Command, 'Show cash and bank balance', 'keyboard', C.Key) end
    TriggerEvent('chat:addSuggestion', '/' .. C.Command, 'Show your cash and bank balance')
end

-- exports['vi-hud']:ShowMoney()  pops the display up for ShowTime
exports('ShowMoney', show)
AddEventHandler('vi-hud:showMoney', show)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SendNUIMessage({ type = 'money', show = false }) end
end)
