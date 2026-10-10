-- ForeverDump v2 - probe: live fixtures for offline tests.
-- /fdump probe          -> sample now; stored under probe.outOfCombat or probe.inCombat
-- /fdump probe combat   -> arm: sample automatically ~1s after you next enter combat
-- /fdump probe add item|spell|quest|unit|achievement|currency <id>, remove ..., list
-- Read-only getters only (safe in combat). Secret returns are recorded as
-- "<secret>" plus their return positions in `secret`.
local _, ns = ...
local P = {}
ns.Probe = P

local R = ns.Resolve
-- every probe call also feeds the secrets map (per API and return position, out of / in combat)
local fnNames = setmetatable({}, { __mode = "k" })
local function SC(fn, ...)
    local res = ns.SafeCall(fn, ...)
    local name = fnNames[fn]
    if name and ns.Secrets then
        local a = ns.Pack(...)
        local unit = type(a[1]) == "string" and a[1] or nil
        ns.Secrets.ObserveResult(name, res, unit, a)
    end
    return res
end
local function nameFn(path)
    local fn = R(path)
    if type(fn) == "function" then fnNames[fn] = path end
    return fn
end

local UNIT_FUNCS = {
    "UnitExists", "UnitGUID", "UnitName", "UnitLevel", "UnitEffectiveLevel", "UnitClass", "UnitRace",
    "UnitSex", "UnitHealth", "UnitHealthMax", "UnitHealthPercent", "UnitHealthMissing", "UnitPower",
    "UnitPowerMax", "UnitPowerType", "UnitIsPlayer", "UnitIsDead", "UnitIsGhost", "UnitCreatureType",
    "UnitCreatureFamily", "UnitClassification", "UnitAffectingCombat", "UnitCastingInfo", "UnitChannelInfo",
    "UnitIsVisible", "UnitInRange", "UnitFactionGroup", "UnitIsTapDenied", "UnitGetIncomingHeals",
    "UnitGetTotalAbsorbs", "GetUnitSpeed", "UnitArmor", "UnitAttackPower",
}
local UNIT_PAIR_FUNCS = { "UnitIsUnit", "UnitReaction", "UnitCanAttack", "UnitIsFriend", "UnitIsEnemy",
                          "UnitThreatSituation", "UnitDetailedThreatSituation" }
local ITEM_FUNCS = { "C_Item.GetItemInfo", "C_Item.GetItemInfoInstant", "C_Item.GetItemNameByID",
    "C_Item.GetItemQualityByID", "C_Item.GetItemIconByID", "C_Item.GetItemSpell", "C_Item.GetItemCount",
    "C_Item.GetDetailedItemLevelInfo", "C_Item.IsItemDataCachedByID",
    "C_Item.GetItemCooldown", "C_Container.GetItemCooldown" }
local SPELL_FUNCS = { "C_Spell.GetSpellInfo", "C_Spell.GetSpellName", "C_Spell.GetSpellTexture",
    "C_Spell.GetSpellDescription", "C_Spell.GetSpellCooldown", "C_Spell.GetSpellCharges",
    "C_Spell.GetSpellCastCount", "C_Spell.IsSpellUsable", "C_Spell.GetSpellPowerCost",
    "C_Spell.GetSpellCooldownDuration", "C_Spell.DoesSpellExist", "C_Spell.IsSpellPassive",
    "C_Spell.GetSpellLink", "C_SpellBook.IsSpellKnown", "C_SpellBook.IsSpellInSpellBook",
    "C_Secrets.GetSpellAuraSecrecy", "C_Secrets.GetSpellCastSecrecy", "C_Secrets.GetSpellCooldownSecrecy" }
local QUEST_FUNCS = { "C_QuestLog.GetTitleForQuestID", "C_QuestLog.IsQuestFlaggedCompleted",
    "C_QuestLog.GetQuestObjectives", "C_QuestLog.GetLogIndexForQuestID", "C_QuestLog.IsOnQuest",
    "C_QuestLog.GetQuestTagInfo", "C_QuestLog.ReadyForTurnIn" }

local function each(paths, ...)
    local out = {}
    for _, path in ipairs(paths) do
        local fn = nameFn(path)
        if type(fn) == "function" then out[path] = SC(fn, ...) end
    end
    return out
end

local function unitExists(unit)
    local ok, v = pcall(UnitExists, unit)
    if not ok or ns.IsSecret(v) then return true end -- unknown: still probe
    return v == true
end

local function probeAuras(unit, filter, max)
    local out = {}
    local UA = rawget(_G, "C_UnitAuras")
    if type(UA) ~= "table" or type(UA.GetAuraDataByIndex) ~= "function" then return out end
    for i = 1, max do
        local r = SC(UA.GetAuraDataByIndex, unit, i, filter)
        out[#out + 1] = r
        if not r.ok or r.values[1] == "<nil>" then break end
    end
    return out
end

-- C_Secrets predicates, argument filled from the documentation when available.
local function probeSecrets(cfg)
    local out = {}
    local S = rawget(_G, "C_Secrets")
    if type(S) ~= "table" then return { unavailable = true } end
    local docArgs = {}
    local docs = ForeverDumpDocsDB
    if type(docs) == "table" and type(docs.systems) == "table" then
        for _, sys in ipairs(docs.systems) do
            if sys.Namespace == "C_Secrets" and type(sys.Functions) == "table" then
                for _, f in ipairs(sys.Functions) do docArgs[f.Name] = f.Arguments or {} end
            end
        end
    end
    for name, fn in next, S do
        if type(fn) == "function" and type(name) == "string" then
            local args = docArgs[name]
            if args == nil or #args == 0 then
                out[name] = SC(fn)
            else
                local t = tostring(args[1].Type or "")
                local samples
                if string.find(t, "Unit") then samples = cfg.units
                elseif string.find(t, "Spell") then samples = cfg.spells
                elseif string.find(t, "PowerType") then samples = { 0, 1, 2, 3 }
                end
                if samples then
                    out[name] = {}
                    for _, s in ipairs(samples) do out[name][tostring(s)] = SC(fn, s) end
                else
                    out[name] = { skipped = "argument type " .. t }
                end
            end
        end
    end
    return out
end

-- v2.2.15 (run 12: one 35.75 ms frame ~1 s after the first pull = this probe, run in one go): the probe is a list of
-- small steps. P.Run (slash command, out of combat) runs them back to back; P.RunStaged runs one step per frame,
-- each wrapped in Perf ("Probe.step"), so the in-combat capture never costs more than one step in a frame.
local function chunks(list, n)
    local out = {}
    for i = 1, #list, n do
        local c = {}
        for j = i, math.min(i + n - 1, #list) do c[#c + 1] = list[j] end
        out[#out + 1] = c
    end
    return out
end

function P.Steps(reason, key, quiet)
    local cfg = ns.config.probe
    local inCombat = ns.InCombat()
    local TI = rawget(_G, "C_TooltipInfo")
    local result = { meta = ns.Meta(), anchor = ns.TimeAnchor(true), sid = ns.SessionId(), reason = reason, tooltips = {}, units = {}, auras = {},
                     items = {}, spells = {}, quests = {} }
    local steps = {}
    local function add(fn) steps[#steps + 1] = fn end
    add(function()
        result.state = {
            InCombatLockdown = SC(R("InCombatLockdown")),
            UnitAffectingCombat = SC(R("UnitAffectingCombat"), "player"),
            GetTime = SC(R("GetTime")),
        }
    end)
    add(function() result.secrets = probeSecrets(cfg) end)
    add(function() if ns.Secrets then result.secretState = select(2, ns.Secrets.Snapshot("probe:" .. tostring(reason))) end end)
    local tips = result.tooltips
    if type(TI) == "table" then
        tips.items, tips.spells, tips.quests, tips.units, tips.achievements, tips.currencies = {}, {}, {}, {}, {}, {}
        for _, c in ipairs(chunks(cfg.items, 8)) do add(function() for _, id in ipairs(c) do tips.items[tostring(id)] = SC(TI.GetItemByID, id) end end) end
        for _, c in ipairs(chunks(cfg.spells, 8)) do add(function() for _, id in ipairs(c) do tips.spells[tostring(id)] = SC(TI.GetSpellByID, id) end end) end
        add(function()
            for _, id in ipairs(cfg.quests) do tips.quests[tostring(id)] = SC(TI.GetHyperlink, "quest:" .. id) end
            for _, id in ipairs(cfg.achievements) do tips.achievements[tostring(id)] = SC(TI.GetAchievementByID, id) end
            for _, id in ipairs(cfg.currencies) do tips.currencies[tostring(id)] = SC(TI.GetCurrencyByID, id, 0) end
        end)
        for _, unit in ipairs(cfg.units) do
            add(function()
                if unitExists(unit) then
                    tips.units[unit] = SC(TI.GetUnit, unit)
                    tips.units[unit .. ":aura1"] = SC(TI.GetUnitAura, unit, 1, "HELPFUL")
                    tips.units[unit .. ":debuff1"] = SC(TI.GetUnitAura, unit, 1, "HARMFUL")
                end
            end)
        end
    else
        tips.unavailable = true
    end
    for _, unit in ipairs(cfg.units) do
        add(function()
            if not unitExists(unit) then return end
            local u = each(UNIT_FUNCS, unit)
            for _, path in ipairs(UNIT_PAIR_FUNCS) do
                local fn = nameFn(path)
                if type(fn) == "function" then u[path] = SC(fn, "player", unit) end
            end
            result.units[unit] = u
        end)
        add(function()
            if not unitExists(unit) then return end
            result.auras[unit] = {
                HELPFUL = probeAuras(unit, "HELPFUL", cfg.maxAuras),
                HARMFUL = probeAuras(unit, "HARMFUL", cfg.maxAuras),
            }
        end)
    end
    for _, c in ipairs(chunks(cfg.items, 4)) do add(function() for _, id in ipairs(c) do result.items[tostring(id)] = each(ITEM_FUNCS, id) end end) end
    for _, c in ipairs(chunks(cfg.spells, 2)) do
        add(function()
            for _, id in ipairs(c) do
                local sp = each(SPELL_FUNCS, id)
                local inRange = R("C_Spell.IsSpellInRange")
                if type(inRange) == "function" then sp["C_Spell.IsSpellInRange(target)"] = SC(inRange, id, "target") end
                result.spells[tostring(id)] = sp
            end
        end)
    end
    add(function() for _, id in ipairs(cfg.quests) do result.quests[tostring(id)] = each(QUEST_FUNCS, id) end end)
    add(function() if cfg.redactPlayers ~= false then P.Redact(result) end end)
    local finalKey = (inCombat and "inCombat") or key or "outOfCombat"
    add(function()
        local db = ns.db
        db.sections.probe = db.sections.probe or {}
        db.sections.probe[finalKey] = ns.Clean(result, { maxDepth = 12, maxKeys = 2000 })
        db.sections.probe.config = ns.Clean(cfg)
        if not quiet then ns.Print("probe stored under probe." .. finalKey .. ". /reload or log out to write it.") end
    end)
    return steps, finalKey
end

function P.Run(reason, key, quiet)
    local steps, finalKey = P.Steps(reason, key, quiet)
    for i = 1, #steps do steps[i]() end
    return finalKey
end

-- one step per frame (C_Timer.After(0)); each step is timed by Perf; a failing step is skipped, the rest still run
function P.RunStaged(reason, key, quiet, done)
    local steps, finalKey = P.Steps(reason, key, quiet)
    local after = rawget(_G, "C_Timer") and C_Timer.After
    local i = 0
    P.staged = { n = #steps, done = 0, key = finalKey }
    local function nextStep()
        i = i + 1
        local st = steps[i]
        if not st then
            P.staged.finished = true
            if done then pcall(done, finalKey) end
            return
        end
        if ns.Perf and ns.Perf.Run then ns.Perf.Run("Probe.step", st) else pcall(st) end
        P.staged.done = i
        if type(after) == "function" then after(0, nextStep) else nextStep() end
    end
    nextStep()
    return finalKey, #steps
end

-- Replace player character names, realm name and player GUIDs with
-- placeholders so fixtures can be shared. Secret values are already markers.
local function plainName(unit)
    local ok, name, realm = pcall(UnitName, unit)
    if ok and type(name) == "string" and not ns.IsSecret(name) and name ~= "" then return name, realm end
end
local function scrub(v, needles)
    if type(v) == "string" then
        v = string.gsub(v, "Player%-%d+%-%x+", "Player-<redacted>")
        for _, n in ipairs(needles) do
            local s, e = string.find(v, n.text, 1, true)
            while s do
                v = string.sub(v, 1, s - 1) .. n.repl .. string.sub(v, e + 1)
                s, e = string.find(v, n.text, s + #n.repl, true)
            end
        end
        return v
    elseif type(v) == "table" then
        for k, val in pairs(v) do v[k] = scrub(val, needles) end
    end
    return v
end
function P.Redact(result)
    local needles = {}
    local function add(text, repl)
        if type(text) == "string" and #text >= 2 then needles[#needles + 1] = { text = text, repl = repl } end
    end
    for _, unit in ipairs(ns.config.probe.units) do
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if okP and isPlayer == true then
            local name, realm = plainName(unit)
            add(name, "<" .. unit .. "-name>")
            add(realm, "<realm>")
        end
    end
    local okR, realm = pcall(GetRealmName)
    if okR and type(realm) == "string" and not ns.IsSecret(realm) then add(realm, "<realm>") end
    table.sort(needles, function(a, b) return #a.text > #b.text end)
    scrub(result, needles)
end

local armed = false
function P.Arm()
    armed = true
    ns.Print("probe armed: it will run ~1s after you next enter combat.")
end

ns.On("PLAYER_REGEN_DISABLED", function()
    if not armed then return end
    armed = false
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function() P.Run("auto:combat") end)
    else
        P.Run("auto:combat")
    end
end)

local KINDS = { item = "items", spell = "spells", quest = "quests", unit = "units",
                achievement = "achievements", currency = "currencies" }

function P.Edit(action, kind, value)
    local cfg = ns.config.probe
    local key = KINDS[kind or ""]
    if not key then ns.Print("kinds: item spell quest unit achievement currency") return end
    local v = (key == "units") and value or tonumber(value)
    if v == nil then ns.Print("missing id") return end
    local list = cfg[key]
    for i = #list, 1, -1 do if list[i] == v then table.remove(list, i) end end
    if action == "add" then list[#list + 1] = v end
    ns.Print(key .. ": " .. table.concat((function() local t = {} for _, x in ipairs(list) do t[#t + 1] = tostring(x) end return t end)(), ", "))
end

function P.List()
    for _, key in ipairs({ "items", "spells", "quests", "units", "achievements", "currencies" }) do
        local t = {}
        for _, x in ipairs(ns.config.probe[key]) do t[#t + 1] = tostring(x) end
        ns.Print(key .. ": " .. table.concat(t, ", "))
    end
end
