-- v2.2.7 regression (run 6b: DamageMeter.lua:51 "attempt to perform boolean test on local 'v' (a secret boolean value)").
-- Injects secret BOOLEANS, secret NUMBERS and secret STRINGS into every field of every API value the capture modules
-- consume (C_DamageMeter structs at every nesting level, unit APIs, cast/aura/cooldown payloads, event arguments,
-- instance/group info, HybridState inputs) and asserts:
--   1. no error escapes any entry point (secrets error on arithmetic / ordering / index / concat / len / call),
--   2. a line hook sees NO truth test, compare, index, concat or arithmetic on a local holding a secret in
--      DamageMeter / WorldCapture / ReplayLog / Tokens / Identity / Inference (Lua 5.1 cannot raise on `if v`, so the hook
--      inspects the executing source line for each local that currently holds a secret),
--   3. HybridState never holds a secret in any local (boundary guard),
--   4. nothing secret reaches SavedVariables.
-- usage: lua5.1 tests/secret_inject.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state

------------------------------------------------------------------ typed secrets
local rtype = type
local KIND = setmetatable({}, { __mode = "k" })     -- proxy -> claimed Lua type
local touched = {}
local function boom(op)
    return function()
        local tb = debug.traceback("", 2)
        -- v2.2.11 (run 9 taint.log: Controls.lua:154/227, Lab.lua:241): no exemption any more - the ops matrix and
        -- the lab boundary classify first and never operate on a secret, so a touch there is a violation like any other
        touched[#touched + 1] = op .. ": " .. (tb:match("\n%s*([^\n]-ForeverDump/[^\n]+)") or tb:sub(1, 200))
        error("attempt to " .. op .. " a secret value", 2)
    end
end
local function sec(kind)
    local p = newproxy(true)
    local mt = getmetatable(p)
    mt.__index, mt.__newindex = boom("index"), boom("index")
    mt.__concat, mt.__len, mt.__call = boom("concat"), boom("len"), boom("call")
    mt.__add, mt.__sub, mt.__mul, mt.__div, mt.__mod, mt.__pow, mt.__unm = boom("arith"), boom("arith"), boom("arith"),
        boom("arith"), boom("arith"), boom("arith"), boom("arith")
    mt.__lt, mt.__le, mt.__eq = boom("compare"), boom("compare"), boom("compare")
    mt.__tostring = boom("tostring")
    KIND[p] = kind
    return p
end
-- the client's view: type() of a secret is its underlying type; only issecretvalue/canaccessvalue tell it apart
type = function(v) local k = KIND[v] if k then return k end return rtype(v) end
local mockSecret = issecretvalue
issecretvalue = function(v) return KIND[v] ~= nil or mockSecret(v) end
local mockAccess = canaccessvalue
canaccessvalue = function(v) if KIND[v] then return false end return mockAccess(v) end

------------------------------------------------------------------ injection modes
-- SB/SN/SS: EVERY field is a secret boolean / number / string; typed: every field a secret of its natural type;
-- elems: list elements themselves secret; whole: the whole struct secret; mixed: clear structs, secret leaves alternate
local MODE
local MODES = { "SB", "SN", "SS", "typed", "elems", "whole", "mixed" }
-- v2.2.11 speed-up: FD_INJECT_MODES="SB,SN" runs a subset (the runner splits the 7 modes over parallel jobs; every
-- mode still runs, each with all checks); unset = all modes
if os.getenv("FD_INJECT_MODES") then
    local want, sub = {}, {}
    for m in os.getenv("FD_INJECT_MODES"):gmatch("[^,]+") do want[m] = true end
    for _, m in ipairs(MODES) do if want[m] then sub[#sub + 1] = m end end
    assert(#sub > 0, "FD_INJECT_MODES selects no known mode")
    MODES = sub
end
local flip = 0
local function V(natural, clear)
    if MODE == "SB" then return sec("boolean") end
    if MODE == "SN" then return sec("number") end
    if MODE == "SS" then return sec("string") end
    if MODE == "typed" then return sec(natural) end
    if MODE == "mixed" then flip = flip + 1 if flip % 2 == 0 then return sec(natural) end return clear end
    return clear
end
local function list(elem, n)
    if MODE == "whole" then return sec("table") end
    local t = {}
    for i = 1, n or 2 do if MODE == "elems" then t[i] = sec("table") else t[i] = elem(i) end end
    return t
end
local function struct(t) if MODE == "whole" then return sec("table") end return t end

local function detail() return struct({ unitName = V("string", "Someone"), unitClassFilename = V("string", "SHAMAN"),
    classification = V("string", "normal"), isPet = V("boolean", false), isMob = V("boolean", true), amount = V("number", 12),
    specIconID = V("number", 1) }) end
local function spell() return struct({ spellID = V("number", 403), totalAmount = V("number", 50), amountPerSecond = V("number", 5),
    overkillAmount = V("number", 0), creatureName = V("string", "Kobold"), isAvoidable = V("boolean", false),
    isDeadly = V("boolean", false), combatSpellDetails = list(detail) }) end
local function source(i) return struct({ sourceGUID = V("string", "Player-1-0000000" .. i), name = V("string", "Me"),
    classFilename = V("string", "SHAMAN"), isLocalPlayer = V("boolean", i == 1), totalAmount = V("number", 100),
    amountPerSecond = V("number", 10), sourceCreatureID = V("number", 0), classification = V("string", "normal"),
    specIconID = V("number", 1), deathRecapID = V("number", 0), deathTimeSeconds = V("number", 0),
    sourceDisplayType = V("number", 0), combatSpells = list(spell) }) end
local function session() return struct({ durationSeconds = V("number", 30), totalAmount = V("number", 200),
    maxAmount = V("number", 100), combatSources = list(source) }) end
local function avail() return list(function(i) return struct({ sessionID = V("number", i), name = V("string", "Fight"),
    durationSeconds = V("number", 30) }) end) end

local function maybe(natural, clear) if MODE then return V(natural, clear) end return clear end
C_DamageMeter = {
    IsDamageMeterAvailable = function() return maybe("boolean", true) end,
    GetSessionDurationSeconds = function() return maybe("number", 30) end,
    GetAvailableCombatSessions = function() if MODE then return avail() end return {} end,
    GetCombatSessionFromType = function() if MODE then return session() end return { combatSources = {} } end,
    GetCombatSessionFromID = function() if MODE then return session() end return { combatSources = {} } end,
    GetCombatSessionSourceFromType = function() if MODE then return source(1) end return {} end,
    GetCombatSessionSourceFromID = function() if MODE then return source(1) end return {} end,
    ResetAllCombatSessions = function() end,
}
-- unit / world APIs (every return value a secret in a mode)
local function unitAPI(natural, clear, n)
    return function()
        if not MODE then return clear end
        if n then local r = {} for i = 1, n do r[i] = V(natural[i] or "string", nil) end return unpack(r, 1, n) end
        return V(natural, clear)
    end
end
local existsSecret = false
UnitExists = function(tok) if MODE and existsSecret then return V("boolean", true) end return tok == "player" or tok == "target" end
UnitHealth, UnitHealthMax = unitAPI("number", 100), unitAPI("number", 100)
UnitPower, UnitPowerMax = unitAPI("number", 50), unitAPI("number", 100)
UnitThreatSituation = unitAPI("number", 0)
UnitDetailedThreatSituation = unitAPI({ "boolean", "number", "number", "number", "number" }, nil, 5)
UnitInRange, UnitIsDeadOrGhost = unitAPI("boolean", true), unitAPI("boolean", false)
UnitCastingInfo = unitAPI({ "string", "string", "number", "number", "number", "boolean", "string", "boolean", "number", "number" }, nil, 10)
UnitChannelInfo = unitAPI({ "string", "string", "number", "number", "number", "boolean", "boolean", "number", "boolean", "number", "number" }, nil, 11)
UnitGUID = function(tok) if MODE then return V("string", "Player-1-00000001") end if tok == "player" then return "Player-1-00000001" end return "Creature-0-1-2-3-4096-0000" end
UnitIsUnit, UnitCanAttack, UnitIsPlayer = unitAPI("boolean", false), unitAPI("boolean", true), unitAPI("boolean", false)
UnitIsFriend, UnitInParty = unitAPI("boolean", false), unitAPI("boolean", false)
UnitClass, UnitLevel, UnitName = unitAPI("string", "SHAMAN"), unitAPI("number", 10), unitAPI("string", "x")
IsInInstance = unitAPI({ "boolean", "string" }, nil, 2)
IsInRaid, IsInGroup, GetNumGroupMembers = unitAPI("boolean", false), unitAPI("boolean", false), unitAPI("number", 0)
GetInstanceInfo = unitAPI({ "string", "string", "number", "string", "number", "number", "boolean", "number" }, nil, 9)
GetTotemInfo = unitAPI({ "boolean", "string", "number", "number", "number" }, nil, 5)
C_PvP = C_PvP or {}
C_PvP.IsBattleground, C_PvP.IsArena = unitAPI("boolean", false), unitAPI("boolean", false)
C_Map = C_Map or {}
C_Map.GetBestMapForUnit = unitAPI("number", 1)
C_ChatInfo = C_ChatInfo or {}
C_ChatInfo.IsLoggingCombat = unitAPI("boolean", true)
C_UnitAuras = C_UnitAuras or {}
C_UnitAuras.GetAuraSlots = function() if MODE then return V("number", nil), V("number", 1) end return nil, 1 end
C_UnitAuras.GetAuraDataByIndex = function(_, i)
    if i > 2 then return nil end
    if not MODE then return { auraInstanceID = i, spellId = 100 + i, duration = 10, expirationTime = 20, isFromPlayerOrPlayerPet = true } end
    return struct({ auraInstanceID = V("number", i), spellId = V("number", 100), duration = V("number", 10),
        expirationTime = V("number", 20), isFromPlayerOrPlayerPet = V("boolean", true) })
end
C_Spell = C_Spell or {}
C_Spell.GetSpellCooldown = function()
    if not MODE then return { isActive = false, isOnGCD = false, startTime = 0, duration = 0 } end
    return struct({ isActive = V("boolean", false), isOnGCD = V("boolean", false), startTime = V("number", 1), duration = V("number", 2) })
end
UnitAffectingCombat = function() return S.combat end

------------------------------------------------------------------ load + capture on (clear), then hook
local function tocFiles(dir)
    local files = {}
    for line in io.lines(dir .. "/ForeverDump.toc") do
        if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    end
    return files
end
local ns = W.loadAddon(addonDir, tocFiles(addonDir), "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
ns.config.logs.fullDump = false
ns.config.logs.autoReload = false
W.slash("logs on")
for _ = 1, 5 do W.tick(1) end
check(ns.DamageMeter and ns.WorldCapture and ns.Tokens and ns.Identity and ns.ReplayLog and ns.Inference and ns.Inference.hs,
    "capture modules + HSM loaded, capture ON")
check(ns.ReplayLog.IsTest(), "capture level test (deep DamageMeter read, world capture)")

-- source lines of the audited modules (strings blanked, comments dropped)
local AUDITED = { ["DamageMeter.lua"] = true, ["WorldCapture.lua"] = true, ["ReplayLog.lua"] = true, ["Tokens.lua"] = true,
    ["Identity.lua"] = true, ["Inference.lua"] = true, ["OocFill.lua"] = true, ["Derive.lua"] = true }
local SRC = {}
local function srcLines(file)
    local t = SRC[file]
    if t then return t end
    t = {}
    for line in io.lines(addonDir .. "/" .. file) do
        line = line:gsub("\\.", "__"):gsub('"[^"]*"', '""'):gsub("'[^']*'", "''"):gsub("%-%-.*$", "")
        t[#t + 1] = line
    end
    SRC[file] = t
    return t
end
local findings, seenF = {}, {}
local hsSecrets = {}
local AFTER = { "^%s*and%f[^%w_]", "^%s*or%f[^%w_]", "^%s*then%f[^%w_]", "^%s*do%f[^%w_]", "^%s*[=~<>]=", "^%s*[<>]",
    "^%s*%.%.", "^%s*%[", "^%s*%.[%a_]", "^%s*:", "^%s*[%+%-%*/%%%^]" }
local BEFORE = { "%f[%w_]not%s*$", "[=~<>]=%s*$", "[<>]%s*$", "%.%.%s*$", "#%s*$", "[%+%-%*/%%%^]%s*$", "%f[%w_]if%s+$",
    "%f[%w_]elseif%s+$", "%f[%w_]while%s+$", "%f[%w_]until%s+$" }
local function scanLine(file, ln, name)
    local line = srcLines(file)[ln]
    if not line then return end
    local i = 1
    while true do
        local s, e = line:find(name, i, true)
        if not s then return end
        local pc, nc = line:sub(s - 1, s - 1), line:sub(e + 1, e + 1)
        if not pc:match("[%w_%.:]") and not nc:match("[%w_]") then
            local before, after = line:sub(1, s - 1), line:sub(e + 1)
            local bad
            for _, p in ipairs(AFTER) do if after:find(p) then bad = p break end end
            if not bad then for _, p in ipairs(BEFORE) do if before:find(p) then bad = p break end end end
            -- an assignment target is not a use (`v = x`, `local a, v = ...`)
            if bad and after:find("^%s*=[^=]") then bad = nil end
            if bad then
                local key = file .. ":" .. ln .. ":" .. name
                if not seenF[key] then seenF[key] = true findings[#findings + 1] = key .. "  [" .. MODE .. "] " .. line:gsub("^%s+", "") end
            end
        end
        i = e + 1
    end
end
local guardLine
local function guardFrom()
    if not guardLine then
        guardLine = math.huge
        for i, l in ipairs(srcLines("Lib/HybridState.lua")) do if l:find("BOUNDARY GUARD", 1, true) or (l:find("^local issecret = ") and i < guardLine) then guardLine = i break end end
    end
    return guardLine
end
local function hook(ev, ln)
    local info = debug.getinfo(2, "S")
    local src = info and info.source
    if not src or src:sub(1, 1) ~= "@" then return end
    local file = src:match("ForeverDump/(.+)$")
    if not file then return end
    local hsFile = file == "Lib/HybridState.lua"
    if not AUDITED[file] and not hsFile then return end
    local i = 1
    while true do
        local name, val = debug.getlocal(2, i)
        if not name then break end
        if KIND[val] and name:sub(1, 1) ~= "(" then
            if hsFile then
                -- the boundary guard block itself (isSecretValue / scrub / guard wrappers) legitimately sees raw arguments
                if ln < guardFrom() then
                    local fn = debug.getinfo(2, "n")
                    hsSecrets[file .. ":" .. ln .. ":" .. name .. " in " .. tostring(fn and fn.name)] = true
                end
            else
                scanLine(file, ln, name)
            end
        end
        i = i + 1
    end
end

------------------------------------------------------------------ drive every entry point under every mode
local escaped = {}
local function run(label, f, ...)
    local ok, err = pcall(f, ...)
    if not ok then escaped[#escaped + 1] = "[" .. tostring(MODE) .. "] " .. label .. ": " .. tostring(err) end
end
local DM, WC, T, Scan, ID, I, R, hs = ns.DamageMeter, ns.WorldCapture, ns.Tokens, ns.Tokens.Scan, ns.Identity, ns.Inference,
    ns.ReplayLog, ns.Inference.hs
local selfErr0 = #(ForeverDumpLogDB.selfErrors or {})
local function evArgs() return V("string", "target"), V("string", "Cast-3-1"), V("number", 403), V("number", 1), V("number", 2) end
local HS_CALLS = {
    { "OnCast", function() return "UNIT_SPELLCAST_START", V("string", "target"), V("number", 403), V("boolean", false), V("string", "player") end },
    { "OnAura", function() return V("string", "player"), { full = V("boolean", true), added = { { iid = V("number", 1), spellId = V("number", 2) } } } end },
    { "OnCount", function() return V("string", "player"), V("string", "HELPFUL"), V("number", 2) end },
    { "OnTotem", function() return V("number", 1), V("boolean", true), V("string", "Totem"), V("number", 30) end },
    { "OnDamageMeter", function() return V("number", 0) end },
    { "OnUnitCombat", function() return V("string", "target"), V("string", "WOUND"), V("string", ""), V("number", 10), V("number", 1), V("boolean", false) end },
    { "OnInterrupt", function() return V("string", "target") end },
    { "OnEnemyCast", function() return "UNIT_SPELLCAST_START", V("string", "target"), V("string", "npc:1"), V("number", 3), V("number", 4) end },
    { "OnCastFailed", function() return V("number", 403), "UNIT_SPELLCAST_FAILED" end },
    { "OnHealthMax", function() return V("string", "player"), V("number", 100) end },
    { "OnHealthEvent", function() return V("string", "player") end },
    { "CDPayload", function() return V("number", 403), V("number", 403), V("number", 0), V("number", 0) end },
    { "CDObserve", function() return V("number", 403), V("boolean", false), V("boolean", false), V("number", 1), V("number", 2) end },
    { "GCDObserve", function() return V("number", 1), V("number", 1.5) end },
    { "SetRestriction", function() return V("number", 0), V("number", 1) end },
    { "OnCombatState", function() return V("boolean", true) end },
    { "ReconcileDM", function() return { damage = V("number", 1), others = V("number", 2), spells = { [403] = V("number", 5) } } end },
    { "RecordAura", function() return V("string", "player"), { iid = V("number", 1), spellId = V("number", 2) }, "scan" end },
    { "Learn", function() return V("number", 403), { cooldown = V("number", 6) } end },
}
debug.sethook(hook, "l")
for _, mode in ipairs(MODES) do
    MODE = mode
    for pass = 1, 2 do
        existsSecret = pass == 2
        -- DamageMeter: classify (in/after combat), throttled structure sample, event args, post-combat deep read
        S.combat = true
        run("DM.OnEvent(PLAYER_REGEN_DISABLED)", DM.OnEvent, "PLAYER_REGEN_DISABLED")
        run("DM.Classify", DM.Classify, "combat")
        run("DM.OnEvent(DAMAGE_METER_COMBAT_SESSION_UPDATED)", DM.OnEvent, "DAMAGE_METER_COMBAT_SESSION_UPDATED", V("number", 0), V("number", 1))
        run("DM.OnEvent(DAMAGE_METER_CURRENT_SESSION_UPDATED)", DM.OnEvent, "DAMAGE_METER_CURRENT_SESSION_UPDATED", V("number", 1))
        -- world capture + token scanner + identity + inference with every unit API secret
        for _ = 1, 30 do run("WC.Slice", WC.Slice) run("Scan.Slice", Scan.Slice) end
        run("Scan.Context", Scan.Context)
        run("Scan.OnCast", Scan.OnCast, "UNIT_SPELLCAST_START", V("string", "target"), V("string", "Cast-3-1"))
        run("T.Survey", T.Survey, "inject", true)
        run("ID.Observe(target)", ID.Observe, "target", "inject")
        run("ID.Observe(targettarget)", ID.Observe, "targettarget", "inject")
        for _, ev in ipairs({ "UNIT_TARGET", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_PET", "PLAYER_TARGET_CHANGED" }) do
            run("ID.OnEvent(" .. ev .. ")", ID.OnEvent, ev, V("string", "nameplate1"))
        end
        -- v2.2.19 ooc fill + unit-token sweep: every token family read with every unit API secret
        local OF = ns.OocFill
        if OF then
            run("OF.Tokens", OF.Tokens)
            for _, tok in ipairs({ "player", "target", "targettarget", "nameplate1", "nameplate1target", "raid1", "raidpet1", "arena1", "boss1" }) do
                run("OF.ReadToken(" .. tok .. ")", OF.ReadToken, tok, "combat")
                run("OF.ReadToken(" .. tok .. ",ooc)", OF.ReadToken, tok, "ooc")
                run("OF.ReadEdge(" .. tok .. ")", OF.ReadEdge, tok)
            end
            for _, ev in ipairs({ "UNIT_COMBAT", "UNIT_AURA", "UNIT_TARGET", "NAME_PLATE_UNIT_ADDED", "PLAYER_REGEN_DISABLED",
                "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE" }) do
                run("OF.OnEvent(" .. ev .. ")", OF.OnEvent, ev, V("string", "nameplate1"), V("string", "WOUND"))
            end
            run("OF.Step", OF.Step)
            run("OF.OnWound", OF.OnWound)
            run("OF.OnAura", OF.OnAura, "nameplate1")
            run("OF.ScanAuras", OF.ScanAuras, "target", "k", "ooc")
        end
        -- v2.2.20 (run 15: Derive.lua:197 truth-tested UnitChannelInfo's secret notInterruptible): the derivation lab
        local DV = ns.Derive
        if DV then
            for _, ev in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START" }) do
                run("DV.OnCastStart(" .. ev .. ")", DV.OnCastStart, ev, "nameplate1")
                run("DV.OnCastStart(" .. ev .. ",target)", DV.OnCastStart, ev, "target")
                run("DV.OnCastStart(" .. ev .. ",player)", DV.OnCastStart, ev, "player")
            end
            run("DV.OnPower", DV.OnPower, "nameplate1", V("string", "MANA"))
            run("DV.PlateColor", DV.PlateColor, "nameplate1")
            if DV.ScoreSweep then run("DV.ScoreSweep", DV.ScoreSweep) end
            if DV.MeterSweep then run("DV.MeterSweep", DV.MeterSweep, "inject") end
        end
        for _, ev in ipairs(I.CAST_EVENTS) do run("I.OnEvent(" .. ev .. ")", I.OnEvent, ev, evArgs()) end
        run("I.OnEvent(UNIT_AURA)", I.OnEvent, "UNIT_AURA", V("string", "player"), struct({ isFullUpdate = V("boolean", false),
            addedAuras = list(function(i) return struct({ auraInstanceID = V("number", i), spellId = V("number", 100), isHelpful = V("boolean", true),
                isHarmful = V("boolean", false), isFromPlayerOrPlayerPet = V("boolean", true), duration = V("number", 10),
                applications = V("number", 1), expirationTime = V("number", 20) }) end),
            removedAuraInstanceIDs = list(function(i) return V("number", i) end) }))
        run("I.OnEvent(UNIT_COMBAT)", I.OnEvent, "UNIT_COMBAT", V("string", "target"), V("string", "WOUND"), V("string", "CRITICAL"), V("number", 12), V("number", 1))
        run("I.OnEvent(UNIT_SPELLCAST_INTERRUPTED)", I.OnEvent, "UNIT_SPELLCAST_INTERRUPTED", evArgs())
        run("I.OnEvent(PLAYER_TOTEM_UPDATE)", I.OnEvent, "PLAYER_TOTEM_UPDATE", V("number", 1))
        run("I.OnEvent(ADDON_RESTRICTION_STATE_CHANGED)", I.OnEvent, "ADDON_RESTRICTION_STATE_CHANGED", V("number", 0), V("number", 1))
        run("I.OnEvent(UNIT_HEALTH)", I.OnEvent, "UNIT_HEALTH", V("string", "target"))
        run("I.OnEvent(UNIT_MAXHEALTH)", I.OnEvent, "UNIT_MAXHEALTH", V("string", "target"))
        run("I.OnEvent(SPELL_UPDATE_COOLDOWN)", I.OnEvent, "SPELL_UPDATE_COOLDOWN", V("number", 403), V("number", 403), V("number", 0), V("number", 0), V("boolean", false))
        -- HybridState boundary: every public input with secret arguments
        for _, c in ipairs(HS_CALLS) do
            if hs[c[1]] then run("hs:" .. c[1], function() return hs[c[1]](hs, c[2]()) end) end
        end
        run("hs.ledger:Put", function() return hs.ledger:Put("token", V("string", "target"), { guid = V("string", "g") }, "inject") end)
        run("HybridState.NpcKey", HybridState.NpcKey, V("string", "Creature-0-1-2-3-4096-0"))
        -- ReplayLog: IdKey + capture boundary (group/map/combat-log state read at Begin/EndCapture)
        run("R.IdKey", R.IdKey, "guid", V("string", "Player-1-0"))
        S.combat = false
        run("DM.OnEvent(PLAYER_REGEN_ENABLED)", DM.OnEvent, "PLAYER_REGEN_ENABLED")
        run("DM.ReadClear(deep)", DM.ReadClear, "inject")
        run("ID.ScanAuras", ID.ScanAuras, "player", "inject")
        run("logs off", W.slash, "logs off")
        run("logs on", W.slash, "logs on")
        W.tick(2)
    end
end
debug.sethook()
MODE = nil

check(#escaped == 0, "no error escaped any entry point under " .. #MODES .. " injection modes x 2 passes")
for i = 1, math.min(#escaped, 15) do print("       " .. escaped[i]) end
local selfErrs = {}
for i = selfErr0 + 1, #(ForeverDumpLogDB.selfErrors or {}) do selfErrs[#selfErrs + 1] = tostring(ForeverDumpLogDB.selfErrors[i].err) end
check(#selfErrs == 0, "no self-errors recorded by capture modules (" .. #selfErrs .. ")")
for i = 1, math.min(#selfErrs, 10) do print("       " .. selfErrs[i]) end
check(#findings == 0, "line hook: no truth test / compare / index / concat / arithmetic on a local holding a secret (" .. #findings .. ")")
table.sort(findings)
for i = 1, math.min(#findings, 40) do print("       " .. findings[i]) end
local hsList = {}
for k in pairs(hsSecrets) do hsList[#hsList + 1] = k end
table.sort(hsList)
check(#hsList == 0, "HybridState bodies never hold a secret (boundary guard) (" .. #hsList .. ")")
for i = 1, math.min(#hsList, 15) do print("       " .. hsList[i]) end
check((hs.secretDropped or 0) > 0, "boundary guard engaged (" .. tostring(hs.secretDropped) .. " calls scrubbed)")
local tset, tlist = {}, {}
for _, x in ipairs(touched) do if not tset[x] then tset[x] = true tlist[#tlist + 1] = x end end
check(#tlist == 0, "no secret operation attempted outside pcall'd probes (" .. #touched .. " touches, " .. #tlist .. " sites)")
for i = 1, math.min(#tlist, 15) do print("       " .. tlist[i]) end
-- SavedVariables: no secret anywhere (keys or values)
local leaks, seenT = {}, {}
local function walk(v, path, depth)
    if KIND[v] then leaks[#leaks + 1] = path return end
    if rtype(v) ~= "table" or seenT[v] or depth > 40 then return end
    seenT[v] = true
    for k, x in pairs(v) do
        if KIND[k] then leaks[#leaks + 1] = path .. "[<secret key>]" end
        walk(x, path .. "." .. tostring(KIND[k] and "?" or k), depth + 1)
    end
end
for _, n in ipairs({ "ForeverDumpDB", "ForeverDumpLogDB", "ForeverDumpRecordDB", "ForeverDumpCombatDB", "ForeverDumpReplayDB" }) do
    walk(rawget(_G, n), n, 0)
end
check(#leaks == 0, "no secret value or key reached SavedVariables (" .. #leaks .. ")")
for i = 1, math.min(#leaks, 10) do print("       " .. leaks[i]) end
local d = DM.DB()
check(d and d.schema and next(d.schema) ~= nil, "DamageMeter recorded five-state codes for injected structs")
local sCount = 0
if d and d.schema then for _, byPath in pairs(d.schema) do for _, cell in pairs(byPath) do sCount = sCount + (cell.S or 0) end end end
check(sCount > 0, "secret fields classified as S (" .. sCount .. " S codes)")
print(string.format("secret injection: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
