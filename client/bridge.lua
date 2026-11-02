-- Framework bridge: everything framework-specific lives here, so the HUD works on ESX, QBCore,
-- Qbox or with no framework at all. See Config.Framework.
--   * character loaded       -> re-apply the radar (multicharacter scripts can reset it)
--   * hunger / thirst        -> Bridge.Needs (0-100, -1 = not available -> icon hidden)
--   * seatbelt               -> Bridge.GetSeatbelt() (1 = buckled, 0 = not, -1 = unknown)
--   * weapon icon urls       -> Bridge.WeaponIconUrls()
-- Standalone servers (or custom scripts) can feed it through the exports / events at the bottom.

Bridge = {}

local FW = string.lower(Config.Framework or 'auto')

-- Resource states, cached (several loops ask every frame); kept current by the start / stop events
local states = {}
local stateCbs = {}

local function started(res)
    local s = states[res]
    if s == nil then
        s = GetResourceState(res) == 'started'
        states[res] = s
    end
    return s
end

local function stateChanged(res, on)
    states[res] = on
    for _, cb in ipairs(stateCbs) do cb(res, on) end
end

AddEventHandler('onClientResourceStart', function(res) stateChanged(res, true) end)
AddEventHandler('onClientResourceStop', function(res) stateChanged(res, false) end)

Bridge.Started = started
function Bridge.OnResourceState(cb) stateCbs[#stateCbs + 1] = cb end

-- 'auto' listens to every framework's events (the ones that don't exist simply never fire).
-- Qbox fires QBCore's events too, so 'qbox' also uses the QBCore hooks.
local function uses(name)
    if FW == 'auto' then return true end
    if FW == name then return true end
    return name == 'qbcore' and FW == 'qbox'
end

-- Which framework is actually running (for logging / one-off data pulls)
function Bridge.Detect()
    if FW ~= 'auto' then return FW end
    if started('qbx_core') then return 'qbox' end -- before qb-core: Qbox also provides 'qb-core'
    if started('qb-core') then return 'qbcore' end
    if started('es_extended') then return 'esx' end
    return 'standalone'
end

-- QBCore / Qbox player data, for resource restarts mid-session (the loaded event already fired)
local function qbPlayerData()
    if started('qbx_core') then
        local ok, pd = pcall(function() return exports.qbx_core:GetPlayerData() end)
        if ok and pd then return pd end
    end
    if started('qb-core') then
        local ok, pd = pcall(function() return exports['qb-core']:GetCoreObject().Functions.GetPlayerData() end)
        if ok and pd then return pd end
    end
end

-- ------------------------------------------------------------------ character loaded

local loadedCbs = {}

function Bridge.OnPlayerLoaded(cb) loadedCbs[#loadedCbs + 1] = cb end

local function playerLoaded()
    for _, cb in ipairs(loadedCbs) do cb() end
end

if uses('esx') then RegisterNetEvent('esx:playerLoaded', playerLoaded) end
if uses('qbcore') then RegisterNetEvent('QBCore:Client:OnPlayerLoaded', playerLoaded) end

-- ------------------------------------------------------------------ hunger / thirst

Bridge.Needs = { hunger = -1, thirst = -1 } -- mutated in place; status.lua keeps a reference

local function setNeed(name, value)
    if type(value) ~= 'number' then return end
    Bridge.Needs[name] = value < 0 and -1 or math.floor(math.min(100.0, value) + 0.5)
end

local function clearNeeds()
    Bridge.Needs.hunger, Bridge.Needs.thirst = -1, -1
end

local function needsFromPlayerData(pd)
    local meta = type(pd) == 'table' and pd.metadata
    if type(meta) ~= 'table' then return end
    setNeed('hunger', meta.hunger)
    setNeed('thirst', meta.thirst)
end

-- ESX: esx_status (esx_basicneeds) ticks every second
if uses('esx') then
    AddEventHandler('esx_status:onTick', function(data)
        if type(data) ~= 'table' then return end
        for _, s in ipairs(data) do
            if Bridge.Needs[s.name] and type(s.percent) == 'number' then setNeed(s.name, s.percent) end
        end
    end)
    RegisterNetEvent('esx:onPlayerLogout', clearNeeds)
end

-- QBCore / Qbox: player metadata (hunger / thirst are 0-100)
if uses('qbcore') then
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() needsFromPlayerData(qbPlayerData()) end)
    RegisterNetEvent('QBCore:Client:OnPlayerUnload', clearNeeds)
    RegisterNetEvent('QBCore:Player:SetPlayerData', needsFromPlayerData)
    RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst) -- sent by qb-core / consumables
        setNeed('hunger', hunger)
        setNeed('thirst', thirst)
    end)

    -- Resource restarted mid-session: the loaded event already fired, so pull the current values
    CreateThread(function()
        local pd = qbPlayerData()
        if pd and pd.citizenid then needsFromPlayerData(pd) end
    end)
end

-- State bags (Qbox and other scripts set LocalPlayer.state.hunger / .thirst)
if FW ~= 'standalone' then
    for _, name in ipairs({ 'hunger', 'thirst' }) do
        AddStateBagChangeHandler(name, ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
            setNeed(name, value)
        end)
        local now = LocalPlayer.state[name]
        if type(now) == 'number' then setNeed(name, now) end
    end
end

-- ------------------------------------------------------------------ seatbelt

local SP = Config.Speedometer or {}
local BELT_RES = SP.SeatbeltResource         -- nil = esx_cruisecontrol if it's running
local BELT_EXPORT = SP.SeatbeltExport or 'isSeatbeltOn'

local manualBelt = nil           -- set through the SetSeatbelt export / event (overrides everything)
local toggled, toggledVeh = false, 0 -- tracked from 'seatbelt:client:ToggleSeatbelt' (qb-smallresources)
local toggleSeen = false

local function currentVeh() return GetVehiclePedIsIn(PlayerPedId(), false) end

if uses('qbcore') then
    -- qb-smallresources only says "it toggled" (some forks pass the new state), and fires it
    -- again when you leave the vehicle with the belt on, so out-of-vehicle means unbuckled.
    RegisterNetEvent('seatbelt:client:ToggleSeatbelt', function(state)
        toggleSeen = true
        local veh = currentVeh()
        if veh == 0 then
            toggled = false
        elseif type(state) == 'boolean' then
            toggled = state
        else
            if veh ~= toggledVeh then toggled = false end
            toggled = not toggled
        end
        toggledVeh = veh
        Bridge.ResetSeatbeltCache()
    end)
end

local function exportBelt()
    local res = BELT_RES or 'esx_cruisecontrol'
    if not started(res) then return nil end
    local ok, on = pcall(function() return exports[res][BELT_EXPORT](exports[res]) end)
    if not ok then return nil end
    return on and true or false
end

-- 1 = buckled, 0 = not, -1 = no seatbelt script found (icon hidden)
local function readSeatbelt()
    if manualBelt ~= nil then return manualBelt and 1 or 0 end

    local on = exportBelt()
    if on ~= nil then return on and 1 or 0 end

    -- Qbox (qbx_seatbelt) and others keep it in a state bag
    local st = LocalPlayer.state
    if st.seatbelt ~= nil or st.harness ~= nil then
        return (st.seatbelt or st.harness) and 1 or 0
    end

    if toggleSeen or started('qb-smallresources') then
        if currentVeh() ~= toggledVeh then toggled = false end
        return toggled and 1 or 0
    end

    return -1
end

-- The speedometer asks every update; the seatbelt script's export / state bag is only read every
-- BELT_POLL ms (changes through the SetSeatbelt export / toggle event show straight away)
local BELT_POLL = 250
local beltValue, beltAt, beltVeh = -1, -math.huge, 0

function Bridge.ResetSeatbeltCache() beltAt = -math.huge end

function Bridge.GetSeatbelt()
    local now, veh = GetGameTimer(), currentVeh()
    if veh ~= beltVeh or now - beltAt >= BELT_POLL then
        beltValue, beltAt, beltVeh = readSeatbelt(), now, veh
    end
    return beltValue
end

-- ------------------------------------------------------------------ money

Bridge.Money = { cash = nil, bank = nil } -- nil = unknown (row hidden); money.lua keeps a reference

local function setMoney(name, value)
    if type(value) ~= 'number' then return end
    Bridge.Money[name] = math.floor(value + 0.5)
end

local function clearMoney()
    Bridge.Money.cash, Bridge.Money.bank = nil, nil
end

-- ESX: accounts are { name = 'money' | 'bank' | 'black_money', money = n }
if uses('esx') then
    local function esxAccounts(accounts)
        if type(accounts) ~= 'table' then return end
        for _, a in pairs(accounts) do
            if type(a) == 'table' then
                if a.name == 'money' then setMoney('cash', a.money)
                elseif a.name == 'bank' then setMoney('bank', a.money) end
            end
        end
    end

    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        esxAccounts(type(xPlayer) == 'table' and xPlayer.accounts)
    end)
    RegisterNetEvent('esx:setAccountMoney', function(account) esxAccounts({ account }) end)
    RegisterNetEvent('esx:onPlayerLogout', clearMoney)

    CreateThread(function()
        if not started('es_extended') then return end
        local ok, ESX = pcall(function() return exports.es_extended:getSharedObject() end)
        if not ok or type(ESX) ~= 'table' or not ESX.GetPlayerData then return end
        local pd = ESX.GetPlayerData()
        if type(pd) == 'table' then esxAccounts(pd.accounts) end
    end)
end

-- QBCore / Qbox: PlayerData.money.cash / .bank
if uses('qbcore') then
    local function moneyFromPlayerData(pd)
        local m = type(pd) == 'table' and pd.money
        if type(m) ~= 'table' then return end
        setMoney('cash', m.cash)
        setMoney('bank', m.bank)
    end

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() moneyFromPlayerData(qbPlayerData()) end)
    RegisterNetEvent('QBCore:Client:OnPlayerUnload', clearMoney)
    RegisterNetEvent('QBCore:Player:SetPlayerData', moneyFromPlayerData)

    CreateThread(function()
        local pd = qbPlayerData()
        if pd and pd.citizenid then moneyFromPlayerData(pd) end
    end)
end

-- ------------------------------------------------------------------ character (pause menu)

-- { name = 'First Last' | nil, job = 'Police · Sergeant' | nil }, pulled on demand
function Bridge.Character()
    local out = {}
    local fw = Bridge.Detect()
    if fw == 'qbox' or fw == 'qbcore' then
        local pd = qbPlayerData()
        if type(pd) == 'table' then
            local ci = type(pd.charinfo) == 'table' and pd.charinfo
            if ci and ci.firstname then out.name = ('%s %s'):format(ci.firstname, ci.lastname or '') end
            local job = type(pd.job) == 'table' and pd.job
            if job and job.label then
                local grade = type(job.grade) == 'table' and job.grade.name
                out.job = grade and grade ~= '' and ('%s · %s'):format(job.label, grade) or job.label
            end
        end
    elseif fw == 'esx' and started('es_extended') then
        local ok, pd = pcall(function() return exports.es_extended:getSharedObject().GetPlayerData() end)
        if ok and type(pd) == 'table' then
            if pd.firstName then out.name = ('%s %s'):format(pd.firstName, pd.lastName or '') end
            local job = type(pd.job) == 'table' and pd.job
            if job and job.label then
                local grade = job.grade_label
                out.job = grade and grade ~= '' and grade ~= job.label and ('%s · %s'):format(job.label, grade) or job.label
            end
        end
    end
    return out
end

-- ------------------------------------------------------------------ weapon icons

-- Inventories / shops whose weapon images we can borrow (%s = lowercase name, %S = uppercase)
local ICON_SOURCES = {
    { 'esx_weaponshop', 'nui://esx_weaponshop/web/dist/images/weapons/%s.png' },
    { 'ox_inventory',   'nui://ox_inventory/web/images/%S.png' },
    { 'qb-inventory',   'nui://qb-inventory/html/images/%s.png' },
    { 'ps-inventory',   'nui://ps-inventory/html/images/%s.png' },
    { 'lj-inventory',   'nui://lj-inventory/html/images/%s.png' },
    { 'qs-inventory',   'nui://qs-inventory/html/images/%s.png' },
}

-- Config value (string or list) wins; otherwise every running inventory above, in order.
-- Built once and rebuilt when one of those inventories starts / stops (the weapon HUD asks every frame).
local iconAuto, iconSingle = nil, {}

Bridge.OnResourceState(function(res)
    for _, src in ipairs(ICON_SOURCES) do
        if src[1] == res then iconAuto = nil return end
    end
end)

function Bridge.WeaponIconUrls(configured)
    if type(configured) == 'string' and configured ~= '' then
        local l = iconSingle[configured]
        if not l then l = { configured } iconSingle[configured] = l end
        return l
    end
    if type(configured) == 'table' and #configured > 0 then return configured end
    if not iconAuto then
        local list = {}
        for _, src in ipairs(ICON_SOURCES) do
            if started(src[1]) then list[#list + 1] = src[2] end
        end
        iconAuto = list
    end
    return iconAuto
end

-- ------------------------------------------------------------------ exports / events for standalone

-- exports['vi-hud']:SetNeeds(hunger, thirst)   0-100, nil or -1 = hide that icon
local function SetNeeds(hunger, thirst)
    Bridge.Needs.hunger = -1
    Bridge.Needs.thirst = -1
    setNeed('hunger', hunger)
    setNeed('thirst', thirst)
end

-- exports['vi-hud']:SetSeatbelt(state)   true / false, nil = back to automatic detection
local function SetSeatbelt(state)
    if state == nil then manualBelt = nil else manualBelt = state and true or false end
    Bridge.ResetSeatbeltCache()
end

-- exports['vi-hud']:SetMoney(cash, bank)   number = set, nil = leave as is, false = hide that row
-- (a change pops the money display up with the difference, like the framework hooks do)
local function SetMoney(cash, bank)
    if cash == false then Bridge.Money.cash = nil else setMoney('cash', cash) end
    if bank == false then Bridge.Money.bank = nil else setMoney('bank', bank) end
end

exports('SetNeeds', SetNeeds)
exports('SetSeatbelt', SetSeatbelt)
exports('SetMoney', SetMoney)
AddEventHandler('vi-hud:setNeeds', SetNeeds)
AddEventHandler('vi-hud:setSeatbelt', SetSeatbelt)
AddEventHandler('vi-hud:setMoney', SetMoney)
