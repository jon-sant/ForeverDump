-- ForeverDump v2.2.18 - derivation lab: answer every open readability question for the secret families and drive
-- the class evidence engine (Lib/ClassEvidence.lua). Capture level lab only (collect first; perf reported, not gated).
-- Everything is secret-safe: values pass ns.ClassifyValue / ns.Clear* first; codes, counts, clear numbers and RAW
-- identities (v2.2.21: units[key].names / .guids hold every full name and GUID read clear for that key; the key is
-- name:<base name>, a realm-stripped join helper). Own frame and own tables only.
--   read     readability matrix: API x token family x (combat|ooc) x return position -> C/S/N/E/K/T counts, for every
--            getter that can carry class / identity / health / aura / cast information (DERIVE.API below)
--   meter    DAMAGE_METER rosters of both teams: class / name / GUID readability in and out of combat; enemy class
--            composition (-> HSM enemy census) and name-key assignments (-> class engine); out of combat the
--            per-source spell ids of clear-GUID sources (-> learned spellId -> class votes, per client build)
--   score    BG scoreboard (GetBattlefieldScore / C_PvP.GetScoreInfo) field readability; clear name+class -> engine
--   cast     hostile UNIT_SPELLCAST_START/CHANNEL_START: UnitCastingInfo / UnitChannelInfo return codes, planned cast
--            ms when start/end are clear, clear spellIDs (-> engine); per key cast timestamps (offline log join)
--   power    hostile UNIT_POWER_* powerType (clear in BG) -> engine elimination
--   color    plate health-bar colour readability (GetStatusBarColor) and RAID_CLASS_COLORS matches
-- Results: ForeverDumpLogDB.derive; learned tables: ForeverDumpDB.refLearned[build].
local _, ns = ...
local DV = {}
ns.Derive = DV
DV.seenFull = {}   -- v2.2.25: "First Surname" seen on a unit token (UnitName name + realm) -> name key
DV.sharedFirst = {}   -- v2.2.25: first names the scoreboard lists more than once -> tokens key by "First-Surname"

local function g(n) return rawget(_G, n) end
local function code(v) return ns.ClassifyValue(v) end
local function now() return (g("GetTime") or os.clock)() end
local function active() return ns.LabActive and ns.LabActive() and ns.db and ns.db.logs and ns.db.logs.on and true or false end
local function clearStr(v) return ns.ClearStr(v) end
local function clearNum(v) return ns.ClearNum(v) end
local function isTrue(v) return ns.IsTrue(v) end
local function idKey(kind, v) return ns.ReplayLog and ns.ReplayLog.IdKey and ns.ReplayLog.IdKey(kind, v) or nil end

DV.HOSTILE = { "target", "focus", "mouseover", "softenemy", "targettarget", "arena1", "arena2", "arena3", "arena4", "arena5" }
for i = 1, 40 do DV.HOSTILE[#DV.HOSTILE + 1] = "nameplate" .. i end
DV.READ_TOKENS = { "target", "focus", "targettarget", "mouseover", "softenemy", "softfriend", "pet", "party1", "raid1",
    "raid2", "arena1", "nameplate1", "nameplate2", "nameplate3", "nameplate4", "nameplate5", "boss1", "partypet1", "raidpet1" }
-- single-unit getters (unit) and pair getters (unit, "player") whose readability decides a derivation path
DV.API = { "UnitClass", "UnitClassBase", "UnitRace", "UnitSex", "UnitLevel", "UnitEffectiveLevel", "UnitFactionGroup",
    "UnitPowerType", "UnitPower", "UnitPowerMax", "UnitName", "GetUnitName", "UnitPVPName", "UnitGUID", "UnitIsPlayer",
    "UnitPlayerControlled", "UnitIsOtherPlayersPet", "UnitCreatureType", "UnitCreatureFamily", "UnitClassification",
    "UnitSelectionType", "UnitSelectionColor", "UnitHonorLevel", "UnitIsPVP", "UnitCastingInfo", "UnitChannelInfo",
    "UnitHealth", "UnitHealthMax", "UnitHealthPercent", "UnitHealthMissing", "UnitGetTotalAbsorbs", "UnitGetIncomingHeals",
    "UnitGetTotalHealAbsorbs", "UnitInRange", "UnitDistanceSquared", "UnitIsVisible", "UnitAffectingCombat",
    "UnitIsDeadOrGhost", "UnitIsFeignDeath", "UnitIsCharmed", "UnitIsPossessed", "UnitInVehicle", "UnitThreatSituation",
    "GetRaidTargetIndex", "UnitIsTapDenied", "UnitArmor", "UnitAttackSpeed", "UnitRangedDamage", "UnitStat",
    "UnitIsGroupLeader", "UnitIsConnected", "UnitIsAFK", "UnitInParty", "UnitInRaid", "UnitInBattleground",
    "UnitIsTrivial", "UnitIsQuestBoss", "UnitCanCooperate", "UnitCreatureID", "UnitTreatAsPlayerForDisplay" }
-- global (non-unit) readability probes: totem slots (same-class tie-break), arena / pvp state
DV.GLOBAL = { { "GetTotemInfo", 1 }, { "GetTotemInfo", 2 }, { "GetTotemInfo", 3 }, { "GetTotemInfo", 4 },
    { "GetNumArenaOpponents" }, { "GetNumBattlefieldScores" }, { "GetBattlefieldWinner" } }
DV.PAIR = { "UnitIsOwnerOrControllerOfUnit", "UnitIsUnit", "UnitCanAttack", "UnitReaction", "UnitIsEnemy",
    "UnitDetailedThreatSituation" }   -- CheckInteractDistance is combat-protected: WorldCapture probes it behind CombatGuard
DV.AURA = { { "C_UnitAuras", "GetAuraDataByIndex", "HARMFUL" }, { "C_UnitAuras", "GetAuraDataByIndex", "HELPFUL" },
    { "C_UnitAuras", "GetAuraSlots", "HARMFUL" }, { "C_UnitAuras", "GetAuraSlots", "HELPFUL" } }
DV.AURA_FIELDS = { "spellId", "name", "duration", "expirationTime", "applications", "sourceUnit", "isFromPlayerOrPlayerPet",
    "auraInstanceID", "dispelName", "isHarmful", "isStealable", "icon", "nameplateShowPersonal", "isBossAura" }
DV.SCORE_FIELDS = { "name", "className", "classToken", "faction", "race", "talentSpec", "killingBlows", "honorableKills",
    "deaths", "damageDone", "healingDone", "honorGained", "guid", "rating", "bgRating" }
-- GetBattlefieldScore(i) positional returns ON FOREVER (verified run 17 via KTH_ForeverDiag, 400 rows x 17 positions):
-- there is NO "rank" return. 1 name, 2-5 KB/HK/deaths/honor, 6 faction, 7 race, 8 className (localized), 9 classToken,
-- 10 damage, 11 healing, 12-13 (stats), 14 nil, 15-17 (stats). v2.2.23 fix: v2.2.22 named these Classic-style (+rank).
DV.GBS_FIELDS = { "name", "killingBlows", "honorableKills", "deaths", "honorGained", "faction", "race", "className",
    "classToken", "damageDone", "healingDone", "p12", "p13", "p14", "p15", "p16", "p17" }
DV.READ_PERIOD, DV.METER_PERIOD, DV.SCORE_PERIOD = 3, 2, 10

local function db()
    local log = g("ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.derive = log.derive or { v = 1 }
    return log.derive
end
DV.DB = db

local function inCombat()
    local f = g("InCombatLockdown")
    local ok, v = pcall(f or function() return false end)
    return ok and isTrue(v) or false
end
local function ctx() return inCombat() and "combat" or "ooc" end
-- v2.2.25: combat state + environment + phase, e.g. "ooc@bg/gates", "combat@dungeon/enc", "ooc@world-solo/-"
local function ctxe()
    local E = ns.Env and ns.Env() or nil
    if not E then return ctx() end
    return E.combat .. "@" .. E.env .. "/" .. E.phase
end
DV.CtxE = ctxe
-- v2.2.22: BG phase for every scoreboard read. post = winner set; combat; prep = before gates (Preparation aura or
-- instance run time < 120 s); gates = after gates, out of combat.
DV.PREP_AURAS = { 44521, 32727 }
function DV.ScorePhase()
    local okW, w = pcall(g("GetBattlefieldWinner") or error)
    if okW and clearNum(w) ~= nil then return "post" end
    if inCombat() then return "combat" end
    local Aur = g("C_UnitAuras")
    if type(Aur) == "table" and type(Aur.GetPlayerAuraBySpellID) == "function" then
        for _, sid in ipairs(DV.PREP_AURAS) do
            local ok, a = pcall(Aur.GetPlayerAuraBySpellID, sid)
            if ok and type(a) == "table" then return "prep" end   -- presence only (type() is safe on any value)
        end
    end
    local okR, rt = pcall(g("GetBattlefieldInstanceRunTime") or error)
    rt = okR and clearNum(rt) or nil
    if rt and rt < 120000 then return "prep" end
    return "gates"
end
local function fam(u) return (u:gsub("%d+$", "N")) end

-- counts: t[key][pos][code] += 1 (bounded by the API / token / position lists)
local function bump(t, key, pos, c)
    local k = t[key]
    if not k then k = {} t[key] = k end
    local p = k[pos]
    if not p then p = {} k[pos] = p end
    p[c] = (p[c] or 0) + 1
end
local function record(t, key, ok, ...)
    if not ok then bump(t, key, 0, "E") return end
    local n = select("#", ...)
    if n == 0 then bump(t, key, 1, "N") return end
    for i = 1, math.min(n, 12) do bump(t, key, i, code((select(i, ...)))) end
end

-- v2.2.22 (audit): a container classified "T" (table with SOME secret contents) is still indexable. Read every field
-- with pcall(index) and classify each one; return the clear fields + per-field codes. Never operate on a secret field.
local function fieldsOf(t, fields)
    local clear, codes = {}, {}
    if type(t) ~= "table" then return clear, codes end
    for _, fld in ipairs(fields) do
        local okF, v = pcall(function() return t[fld] end)
        local c = okF and code(v) or "E"
        codes[fld] = c
        local cv = ns.ClearWithCode(v, c)
        if cv ~= nil then clear[fld] = cv end
    end
    return clear, codes
end
DV.FieldsOf = fieldsOf
-- K (clear container) or T (container with secret fields) -> indexable; S (secret value) -> not
local function indexable(v, c)
    c = c or code(v)
    return type(v) == "table" and (c == "K" or c == "T"), c
end
DV.Indexable = indexable

-- the class engine -----------------------------------------------------------------------------------------------
local CE
local function engine()
    if not CE and ns.ClassEvidence then
        CE = ns.ClassEvidence.new({ ref = ns.RefData, clock = now, onAssign = function(key, class, via)
            local d = db()
            if not d then return end
            d.assign = d.assign or {}
            d.assign[#d.assign + 1] = { t = now(), key = key, class = class, via = via, ctx = ctx() }
        end })
    end
    return CE
end
DV.Engine = engine

-- name key: base name (realm stripped) so plate and meter keys agree across realms
local function baseName(v)
    local s = clearStr(v)
    if not s or s == "" then return nil end
    return (s:match("^([^%-]+)") or s)
end
-- v2.2.22 (KTH / run 16): Forever scoreboard = "First Surname"; UnitName / combat log = "First".
local function firstName(v)
    local s = baseName(v)
    if not s then return nil end
    return (s:match("^([^%s]+)") or s)
end
DV.FirstName = firstName
local noteRaw   -- defined after unitRec
local function unitKey(unit)
    local f = g("UnitName")
    if not f then return nil end
    local ok, n, realm = pcall(f, unit)
    if not ok then return nil end
    local b = baseName(n)
    if not b then return nil end
    local key = idKey("name", b)
    local r = clearStr(realm)
    local full = clearStr(n)
    if key and full and r and r ~= "" then
        -- v2.2.25: on Forever the realm return of a cross-realm player IS the scoreboard surname (runs 16-18:
        -- 45/45 plate "First-Surname" == scoreboard "First Surname") -> exact full-name join. A first name the
        -- scoreboard lists twice keys by "First-Surname" so the two players never share one engine unit.
        if DV.sharedFirst[b] then key = idKey("name", full .. "-" .. r) or key end
        DV.seenFull[full .. " " .. r] = key
        full = full .. "-" .. r
    end
    if key and noteRaw then noteRaw(key, full, nil) end
    return key
end
DV.UnitKey = unitKey
local function hostilePlayer(unit)
    local okE, e = pcall(g("UnitExists") or error, unit)
    if not (okE and isTrue(e)) then return false end
    local okP, p = pcall(g("UnitIsPlayer") or error, unit)
    local okA, a = pcall(g("UnitCanAttack") or error, "player", unit)
    return okP and isTrue(p) and okA and isTrue(a)
end

local function unitRec(key)
    local d = db()
    d.units = d.units or {}
    local u = d.units[key]
    if not u then u = { first = now() } d.units[key] = u end
    return u
end
-- v2.2.21: raw full names / GUIDs seen for a key (clear strings only; capped at 8 each)
local function addRaw(u, fld, nfld, v)
    if not v or v == "" then return end
    local t = u[fld]
    if not t then t = {} u[fld] = t u[nfld] = 0 end
    if not t[v] and u[nfld] < 8 then t[v] = true u[nfld] = u[nfld] + 1 end
end
noteRaw = function(key, name, guid)
    if not key then return end
    local u = unitRec(key)
    addRaw(u, "names", "namesN", clearStr(name))
    addRaw(u, "guids", "guidsN", clearStr(guid))
end
DV.NoteRaw = noteRaw

-- power ------------------------------------------------------------------------------------------------------------
function DV.OnPower(unit, token)
    if type(unit) ~= "string" or not unit:find("^nameplate") and not unit:find("^arena") and unit ~= "target"
        and unit ~= "focus" and unit ~= "softenemy" and unit ~= "mouseover" and unit ~= "targettarget" then return end
    local d = db()
    local tk = clearStr(token)
    d.power = d.power or {}
    bump(d.power, fam(unit), 1, tk and "C" or code(token))
    if not tk or not hostilePlayer(unit) then return end
    local key = unitKey(unit)
    if not key then bump(d.power, fam(unit), 2, "nokey") return end
    local e = engine()
    if not e then return end
    e:MarkEnemy(key)
    e:Power(key, tk)
    DV.ScoreFlush(key, true)   -- v2.2.22: apply pending scoreboard row once hostility is known
end

-- casts ------------------------------------------------------------------------------------------------------------
local learnedDB
-- own casts: learn planned cast time per spell for this build; drift vs the shipped RefData cast time
function DV.LearnOwnCast(event, unit)
    local channel = event == "UNIT_SPELLCAST_CHANNEL_START"
    local f = g(channel and "UnitChannelInfo" or "UnitCastingInfo")
    if not f then return end
    local r = { pcall(f, unit) }
    if not r[1] then return end
    local st, en = clearNum(r[5]), clearNum(r[6])
    -- v2.2.20 (run 15: 6 selfErrors): UnitChannelInfo has no castID, so its spellID is r[9] (r[8] = notInterruptible,
    -- a secret boolean in a BG that `channel and r[8] or` truth-tested); UnitCastingInfo's spellID is r[10]
    local sid = clearNum(r[channel and 9 or 10])
    if not (sid and st and en and en > st) then return end
    local L = learnedDB and learnedDB()
    if not L then return end
    L.castMs = L.castMs or {}
    local c = L.castMs[sid] or { n = 0 }
    L.castMs[sid] = c
    local ms = en - st
    c.n = c.n + 1
    c.min = c.min and math.min(c.min, ms) or ms
    c.max = c.max and math.max(c.max, ms) or ms
    local ref = ns.RefData and ns.RefData.spells and ns.RefData.spells[sid]
    if ref and (ref[2] or 0) > 0 and math.abs(ref[2] * 1000 - c.min) > 250 then
        L.driftSpells = L.driftSpells or {}
        L.driftSpells[sid] = { ref = ref[2], live = c.min }
    end
end

function DV.OnCastStart(event, unit)
    if unit == "player" and event ~= "UNIT_SPELLCAST_SUCCEEDED" then return DV.LearnOwnCast(event, unit) end
    if type(unit) ~= "string" or unit == "player" or unit:find("^raid") or unit:find("^party") then return end
    local d = db()
    d.cast = d.cast or {}
    local channel = event == "UNIT_SPELLCAST_CHANNEL_START"
    local f = g(channel and "UnitChannelInfo" or "UnitCastingInfo")
    if not f then return end
    local r = { pcall(f, unit) }
    record(d.cast, (channel and "channel:" or "cast:") .. fam(unit) .. "|" .. ctxe(), r[1], unpack(r, 2))
    if not hostilePlayer(unit) then return end
    local key = unitKey(unit)
    if not key then return end
    local u = unitRec(key)
    u.casts = u.casts or {}
    u.casts[#u.casts + 1] = math.floor(now() * 1000 + 0.5) / 1000    -- timestamps only: offline log join
    -- planned cast time (Classic UnitCastingInfo: name, text, texture, startMS, endMS, isTrade, castID, notInterruptible, spellID)
    local st, en = clearNum(r[5]), clearNum(r[6])
    -- v2.2.20 (run 15: 6 selfErrors): UnitChannelInfo has no castID, so its spellID is r[9] (r[8] = notInterruptible,
    -- a secret boolean in a BG that `channel and r[8] or` truth-tested); UnitCastingInfo's spellID is r[10]
    local sid = clearNum(r[channel and 9 or 10])
    if st and en and en > st then
        u.planned = u.planned or {}
        u.planned[#u.planned + 1] = en - st
    end
    local e = engine()
    if e then
        e:MarkEnemy(key)
        if sid then e:Spell(key, sid) end
    end
end

-- plate colour ------------------------------------------------------------------------------------------------------
local function colorClass(r, gg, b)
    local cc = g("RAID_CLASS_COLORS")
    if type(cc) ~= "table" then return nil end
    for class, c in pairs(cc) do
        if type(c) == "table" and type(c.r) == "number" and math.abs(c.r - r) < 0.02 and math.abs(c.g - gg) < 0.02
            and math.abs(c.b - b) < 0.02 then return class end
    end
end
function DV.PlateColor(unit)
    local NP = g("C_NamePlate")
    if type(NP) ~= "table" or type(NP.GetNamePlateForUnit) ~= "function" then return end
    local d = db()
    d.color = d.color or {}
    local ok, rawPlate = pcall(NP.GetNamePlateForUnit, unit)
    local plate = ok and ns.ClearTable(rawPlate) or nil
    if not plate then bump(d.color, "plate", 1, ok and code(rawPlate) or "E") return end
    local uf = rawget(plate, "UnitFrame")
    local hb = type(uf) == "table" and rawget(uf, "healthBar") or nil
    if type(hb) ~= "table" or type(hb.GetStatusBarColor) ~= "function" then bump(d.color, "plate", 1, "nobar") return end
    local res = { pcall(hb.GetStatusBarColor, hb) }
    record(d.color, "bar:" .. ctx(), res[1], unpack(res, 2))
    local r, gg, b = clearNum(res[2]), clearNum(res[3]), clearNum(res[4])
    if not (r and gg and b) then return end
    local class = colorClass(r, gg, b)
    bump(d.color, "match", 1, class and "class" or "other")
    if class and hostilePlayer(unit) then
        local key = unitKey(unit)
        local e = engine()
        if key and e then e:MarkEnemy(key) e:Assign(key, class, "color") end
    end
end

-- readability matrix ------------------------------------------------------------------------------------------------
function DV.ReadSweep()
    local d = db()
    d.read = d.read or {}
    local c = ctxe()   -- v2.2.25: env-tagged (was ooc|combat only)
    local ex = g("UnitExists")
    for _, u in ipairs(DV.READ_TOKENS) do
        local okE, e = pcall(ex or error, u)
        if okE and isTrue(e) then
            local f = fam(u)
            local kind = hostilePlayer(u) and "hostileP" or "other"
            -- v2.2.25: note the token's full name (UnitName name + realm = Forever surname) for the exact join
            do local okP, isP = pcall(g("UnitIsPlayer") or error, u) if okP and isTrue(isP) then unitKey(u) end end
            for _, api in ipairs(DV.API) do
                local fn = g(api)
                if type(fn) == "function" then
                    local args = api == "UnitStat" and 1 or nil
                    record(d.read, api .. "|" .. f .. "|" .. kind .. "|" .. c, pcall(fn, u, args))
                end
            end
            for _, api in ipairs(DV.PAIR) do
                local fn = g(api)
                if type(fn) == "function" then
                    record(d.read, api .. "|" .. f .. "|" .. kind .. "|" .. c, pcall(fn, "player", u))
                end
            end
            for _, a in ipairs(DV.AURA) do
                local ns_ = g(a[1])
                local fn = type(ns_) == "table" and ns_[a[2]] or nil
                if type(fn) == "function" then
                    local byIndex = a[2] == "GetAuraDataByIndex"
                    local arg1, arg2 = a[3], nil
                    if byIndex then arg1, arg2 = 1, a[3] end
                    -- v2.2.25: environment-aware circuit breaker (held only where the API errors as secret)
                    local AG = ns.AuraGate
                    local held, ok, r1, r2
                    if AG and AG.Call then held, ok, r1, r2 = AG.Call(a[2], f, fn, u, arg1, arg2)
                    else held, ok, r1, r2 = false, pcall(fn, u, arg1, arg2) end
                    local key = a[2] .. ":" .. a[3] .. "|" .. f .. "|" .. kind .. "|" .. c
                    if held then bump(d.read, key, 0, "held") else record(d.read, key, ok, r1, r2) end
                    -- v2.2.22: T (some fields secret) is read per field too (was K-only: whole struct skipped)
                    if ok and indexable(r1) then
                        local _, codes = fieldsOf(r1, DV.AURA_FIELDS)
                        for _, fld in ipairs(DV.AURA_FIELDS) do bump(d.read, key .. "|field", fld, codes[fld]) end
                    end
                end
            end
            DV.PlateColor(u)
        end
    end
    for _, p in ipairs(DV.GLOBAL) do
        local fn = g(p[1])
        if type(fn) == "function" then record(d.read, p[1] .. (p[2] and ("#" .. p[2]) or "") .. "|global|-|" .. c, pcall(fn, p[2])) end
    end
end

-- meter rosters ----------------------------------------------------------------------------------------------------
local myClass
function learnedDB()
    local root = ns.db
    if type(root) ~= "table" then return nil end
    root.refLearned = root.refLearned or {}
    local okB, _, b = pcall(g("GetBuildInfo") or error)
    local build = okB and tostring(clearStr(b) or clearNum(b) or "?") or "?"
    local L = root.refLearned[build]
    if not L then L = { spellClass = {}, firstSeen = time and time() or 0 } root.refLearned[build] = L end
    L.shipped = ns.RefData and ns.RefData.build or nil
    -- drift: the shipped seeds were mined on another client build -> runtime keeps learning into this build's table
    L.drift = (L.shipped ~= nil and tostring(L.shipped) ~= build) or nil
    return L, build
end
DV.Learned = learnedDB

function DV.MeterSweep(reason)   -- luacheck: ignore reason
    local DM = ns.DamageMeter
    if not (DM and DM.Roster) then return end
    local d = db()
    d.meter = d.meter or {}
    local c = ctx()
    local m = d.meter[c]
    if not m then m = { reads = 0, rows = 0, nameClear = 0, guidClear = 0, classClear = 0, enemyRows = 0, enemyNameClear = 0 } d.meter[c] = m end
    m.reads = m.reads + 1
    local e = engine()
    local comp = {}
    local spellsLearned = 0
    for _, ty in ipairs({ "DamageDone", "HealingDone", "DamageTaken" }) do
        local rows = DM.Roster(ty)
        local tcomp = {}   -- each type lists an enemy at most once; across types keep the max per class
        for _, r in ipairs(rows or {}) do
            m.rows = m.rows + 1
            if r.nameCode == "C" then m.nameClear = m.nameClear + 1 end
            if r.guidCode == "C" then m.guidClear = m.guidClear + 1 end
            if r.class then m.classClear = m.classClear + 1 end
            local enemy = (r.displayType == 2) and not r.isLocal and r.kind ~= "Creature" and not r.creatureID
            if enemy and r.class and r.class ~= "" then
                m.enemyRows = m.enemyRows + 1
                if r.nameCode == "C" then m.enemyNameClear = m.enemyNameClear + 1 end
                tcomp[r.class] = (tcomp[r.class] or 0) + 1
            end
            if r.nameKey then noteRaw(r.nameKey, r.name, r.guid) end
            if e and r.nameKey and r.class and r.class ~= "" then
                if enemy then e:MarkEnemy(r.nameKey) end
                e:Assign(r.nameKey, r.class, "meter")
            end
            if r.nameKey and r.class and r.class ~= "" and ns.OocFill then
                ns.OocFill.Note(r.nameKey, "class", r.class, "meter")
                if r.kind ~= "Creature" and not r.creatureID then ns.OocFill.Note(r.nameKey, "isPlayer", true, "meter") end
                if enemy then ns.OocFill.Note(r.nameKey, "hostile", true, "meter") end
            end
            -- out of combat: learn spellId -> class from clear-GUID sources (both teams), per client build
            -- v2.2.20 (run 15: 25 of 107 votes disagreed with RefData): DamageTaken lists spells that HIT the source,
            -- not its own -> learn spell -> class from DamageDone / HealingDone only
            if c == "ooc" and ty ~= "DamageTaken" and r.guid and r.class and r.class ~= "" and DM.SourceSpells and spellsLearned < 60 then
                local sp = DM.SourceSpells(ty, r.guid)
                if sp then
                    local L = learnedDB()
                    if L then
                        for sid in pairs(sp) do
                            local v = L.spellClass[sid]
                            if not v then v = {} L.spellClass[sid] = v end
                            v[r.class] = (v[r.class] or 0) + 1
                        end
                        spellsLearned = spellsLearned + 1
                    end
                end
            end
            r.guid = nil
        end
        for cl, k in pairs(tcomp) do if k > (comp[cl] or 0) then comp[cl] = k end end
    end
    -- per type the meter lists each enemy once; across types the same enemy repeats -> keep the max per class
    local best = d.meterComp or {}
    if next(comp) ~= nil then
        if e then e:Composition(comp) end
        d.meterCompLast = comp
        for cl, n in pairs(comp) do if n > (best[cl] or 0) then best[cl] = n end end
        d.meterComp = best
        if not myClass then
            local okC, _, f = pcall(g("UnitClass") or error, "player")
            myClass = okC and clearStr(f) or nil
        end
        if myClass and ns.Inference and ns.Inference.SetMeterEnemyCensus then
            ns.Inference.SetMeterEnemyCensus(math.max(comp[myClass] or 0, (d.scoreComp and d.scoreComp[myClass]) or 0), now())
        end
    end
end

-- scoreboard -------------------------------------------------------------------------------------------------------
-- v2.2.20 (run 15): GetBattlefieldScore returns name (1), faction (6), race (7), LOCALIZED class (8) and classToken (9) clear
-- on every row of both teams in every phase (run 17 KTH: prep/gates/combat/post); pos 10 (damage) is the secret one that
-- v2.2.20 mislabelled "classToken" (r[] index vs position off-by-one) -> enemy class per name key
-- for the whole enemy team from the first scoreboard update (BG prep), mapped back through LOCALIZED_CLASS_NAMES_*.
local locClass
local function classFromLocalized(v)
    local s = clearStr(v)
    if not s or s == "" then return nil end
    local function rebuild()
        locClass = {}
        for _, gname in ipairs({ "LOCALIZED_CLASS_NAMES_MALE", "LOCALIZED_CLASS_NAMES_FEMALE" }) do
            local t = g(gname)
            if type(t) == "table" then
                for tok, loc in pairs(t) do if type(tok) == "string" and type(loc) == "string" then locClass[loc] = tok end end
            end
        end
        for _, tok in ipairs(ns.ClassEvidence and ns.ClassEvidence.CLASSES or {}) do locClass[tok] = locClass[tok] or tok end
    end
    if not locClass then rebuild() end
    if not locClass[s] then rebuild() end   -- v2.2.22: pick up late-added locale entries (tests / client)
    return locClass[s]
end
DV.ClassFromLocalized = classFromLocalized
local function hasRealm(v)
    local s = clearStr(v)
    return s ~= nil and s:find("-", 1, true) ~= nil
end
local function myTeam()
    local f = g("GetBattlefieldArenaFaction")
    if type(f) == "function" then
        local ok, v = pcall(f)
        local n = ok and clearNum(v) or nil
        if n then return n end
    end
    local okF, fac = pcall(g("UnitFactionGroup") or error, "player")
    local fs = okF and clearStr(fac) or nil
    if fs == "Horde" then return 0 elseif fs == "Alliance" then return 1 end
    return nil
end
-- v2.2.22: parse one GetBattlefieldScore row (no assign). Returns a table or nil.
function DV.ScoreRow(d, c, _e, gbs, i, phase)
    local r = { pcall(gbs, i) }
    record(d.score, "GetBattlefieldScore|" .. c, r[1], unpack(r, 2))
    phase = phase or c
    if not r[1] then bump(d.score, "GetBattlefieldScore@" .. phase, 0, "E") return nil end
    for j, fld in ipairs(DV.GBS_FIELDS) do bump(d.score, "GetBattlefieldScore@" .. phase, fld, code(r[j + 1])) end
    local full = clearStr(r[2])
    local first = firstName(full)
    -- v2.2.23: r[k+1] = position k. classToken = pos 9 (r[10]), localized className = pos 8 (r[9]). v2.2.20-22 read
    -- r[11] (= pos 10 damage, secret/number -> nil) then fell back to r[10] -> class was right by accident.
    local cls = classFromLocalized(r[10])
    if not cls then cls = classFromLocalized(r[9]) end
    if not (first and cls) then
        bump(d.score, "bfRow|" .. c, 1, first and "noclass" or "noname")
        return nil
    end
    local fac, team = clearNum(r[7]), myTeam()
    local enemy = nil
    if fac ~= nil and team ~= nil then enemy = (fac ~= team) end
    local race = clearStr(r[8])   -- v2.2.23: pos 7 (v2.2.20-22 read r[9] = localized className -> race was wrong)
    bump(d.score, "bfRow|" .. c, 1, enemy == true and "enemy" or (enemy == false and "friend" or "team?"))
    return { first = first, full = full, cls = cls, fac = fac, enemy = enemy, race = race,
             surname = full and full:find("%s") ~= nil, realm = hasRealm(full) }
end

-- Apply a resolved scoreboard row to the class engine (key = name:<First>, matching UnitName).
local function scoreApply(d, c, e, row, how)
    local key = idKey("name", row.first)
    if how == "exact" and row.full then key = idKey("name", (row.full:gsub(" ", "-", 1))) end   -- shared first name
    if not key then return nil end
    noteRaw(key, row.full, nil)
    if e then
        if row.enemy == true then e:MarkEnemy(key)
        elseif row.enemy == false and (how == "unique" or how == "exact-unique" or how == "exact") then e:MarkFriend(key, "score") end   -- v2.2.24 (run 18 MC)
        e:Assign(key, row.cls, "score")
        local _, _, u = e:Get(key)
        local joined = false
        if u then
            for _, ch in ipairs(u.chain or {}) do
                if ch:find("^power=") or ch:find("^cache:") then joined = true break end
            end
            -- also joined when the unit already carried a plate/token name (raw names noted)
            if not joined and u.names then
                for n in pairs(u.names) do
                    if type(n) == "string" and firstName(n) == row.first and n ~= row.full then joined = true break end
                end
            end
        end
        bump(d.score, "bfJoin|" .. c, 1, (joined and "token" or "none") .. ":" .. how
            .. (row.surname and ":surname" or ":plain") .. (row.realm and ":realm" or ":base"))
    end
    if ns.OocFill then
        ns.OocFill.Note(key, "class", row.cls, "score")
        ns.OocFill.Note(key, "isPlayer", true, "score")
        if row.enemy ~= nil then ns.OocFill.Note(key, "hostile", row.enemy, "score") end
        if row.race then ns.OocFill.Note(key, "race", row.race, "score") end
    end
    return key
end

-- Flush a pending scoreboard row when a plate/cache observes the matching name key + hostility.
-- Pending is indexed by the same IdKey as plates (not the raw first-name string).
function DV.ScoreFlush(key, enemy)
    local d = db()
    local pend = d.scorePending
    if not (pend and key) then return nil end
    local facs = {}
    if enemy == true or enemy == false then
        for fac, bucket in pairs(pend) do
            local row = bucket[key]
            if row and not row.ambiguous and row.enemy == enemy then facs[#facs + 1] = { fac, row } end
        end
    else
        for fac, bucket in pairs(pend) do
            local row = bucket[key]
            if row and not row.ambiguous then facs[#facs + 1] = { fac, row } end
        end
    end
    if #facs ~= 1 then return nil end
    local fac, row = facs[1][1], facs[1][2]
    pend[fac][key] = nil
    local e = engine()
    local c = ctx()
    d.score = d.score or {}
    scoreApply(d, c, e, row, "flush")
    bump(d.score, "bfFlush|" .. c, 1, "ok")
    return row.cls
end
function DV.ScoreSweep()
    local d = db()
    d.score = d.score or {}
    d.scorePending = d.scorePending or {}
    local c = ctx()
    local nf = g("GetNumBattlefieldScores")
    if type(nf) ~= "function" then bump(d.score, "api", 1, "missing") return end
    local okN, n = pcall(nf)
    record(d.score, "GetNumBattlefieldScores|" .. c, okN, n)
    n = okN and clearNum(n) or 0
    local phase = DV.ScorePhase()
    d.scorePhase = d.scorePhase or {}
    local ph = d.scorePhase[phase]
    if not ph then ph = { sweeps = 0, players = {} } d.scorePhase[phase] = ph end
    ph.sweeps = ph.sweeps + 1
    ph.players[tostring(n)] = (ph.players[tostring(n)] or 0) + 1
    local e = engine()
    local gbs, PvP = g("GetBattlefieldScore"), g("C_PvP")
    local scoreComp, anyEnemy = {}, false
    -- Pass 1: collect GetBattlefieldScore rows
    local rows = {}
    if type(gbs) == "function" then
        for i = 1, math.min(n, 80) do
            local row = DV.ScoreRow(d, c, e, gbs, i, phase)
            if row then rows[#rows + 1] = row end
        end
    end
    -- Index: first -> list; (first,fac) -> list
    local byFirst, byFirstFac = {}, {}
    for _, row in ipairs(rows) do
        byFirst[row.first] = byFirst[row.first] or {}
        local bf = byFirst[row.first]
        bf[#bf + 1] = row
        local fk = row.first .. "|" .. tostring(row.fac)
        byFirstFac[fk] = byFirstFac[fk] or {}
        local bff = byFirstFac[fk]
        bff[#bff + 1] = row
    end
    -- Pass 2: assign only when first+faction is unique; if first name also exists on the other
    -- faction, require an existing unit with matching hostility (else pending).
    for _, row in ipairs(rows) do
        if row.enemy == true then scoreComp[row.cls] = (scoreComp[row.cls] or 0) + 1 anyEnemy = true end
        local fk = row.first .. "|" .. tostring(row.fac)
        local sameFac = byFirstFac[fk]
        local allFirst = byFirst[row.first]
        -- v2.2.25 PRIMARY join: exact full name. A unit token showed "First" + realm "Surname" == this row's
        -- "First Surname". When the first name is shared on the board, the exact match decides as long as only ONE
        -- of those rows has been seen on a token (both seen -> the shared name key stays ambiguous: skip).
        local exact = row.full ~= nil and DV.seenFull[row.full] ~= nil
        if #allFirst > 1 then DV.sharedFirst[row.first] = true end
        -- primary: exact full name seen on a token (its own "First-Surname" key when the first name is shared)
        if exact and #allFirst > 1 and row.full:find(" ", 1, true) then
            scoreApply(d, c, e, row, "exact")
        elseif #sameFac > 1 then
            -- same first+faction twice (two "Johnny" on one team): never assign — leave unknown
            bump(d.score, "bfSkip|" .. c, 1, "dupFac")
            d.scorePending[row.fac] = d.scorePending[row.fac] or {}
            do local pk = idKey("name", row.first); if pk then d.scorePending[row.fac][pk] = { ambiguous = true } end end
        elseif #allFirst > 1 then
            -- same first on both teams: only assign if unit already known with matching hostility
            local key = idKey("name", row.first)
            local u
            if e then u = select(3, e:Get(key)) end
            local knownEnemy = u and u.enemy
            if u and ((row.enemy == true and knownEnemy == true) or (row.enemy == false and knownEnemy ~= true)) then
                -- further disambiguate with race if the unit cache has race
                local ok = true
                if row.race and ns.OocFill and ns.OocFill.Get then
                    local cached = ns.OocFill.Get(key, "race")
                    if cached and cached ~= row.race then ok = false end
                end
                if ok then
                    scoreApply(d, c, e, row, "crossFac")
                else
                    bump(d.score, "bfSkip|" .. c, 1, "raceMismatch")
                end
            else
                -- pending until a plate/cache marks hostility (indexed by IdKey)
                local pk = idKey("name", row.first)
                if pk then
                    d.scorePending[row.fac] = d.scorePending[row.fac] or {}
                    local prev = d.scorePending[row.fac][pk]
                    if prev and prev ~= row then
                        d.scorePending[row.fac][pk] = { ambiguous = true }
                        bump(d.score, "bfSkip|" .. c, 1, "crossFacAmb")
                    else
                        d.scorePending[row.fac][pk] = row
                        bump(d.score, "bfPending|" .. c, 1, "crossFac")
                    end
                end
            end
        else
            -- unique first name on the whole board (fallback key = first name + faction; exact when also seen)
            scoreApply(d, c, e, row, exact and "exact-unique" or "unique")
        end
    end
    -- GetScoreInfo readability + same firstName join rules (classToken when clear)
    if type(PvP) == "table" and type(PvP.GetScoreInfo) == "function" then
        for i = 1, math.min(n, 80) do
            local ok, rawInfo = pcall(PvP.GetScoreInfo, i)
            -- v2.2.22 (run 16 audit): was `code == "K"` only -> 2787/2877 ooc + 1140/1140 combat "T" tables skipped
            -- with no field codes. Now every field of a K or T table is read with pcall(index) and coded per phase.
            local isTab, cc = false, ok and code(rawInfo) or "E"
            if ok then isTab = indexable(rawInfo, cc) end
            bump(d.score, "GetScoreInfo@" .. phase, 0, cc)
            if cc ~= "K" then bump(d.score, "GetScoreInfo|" .. c, 0, cc) end
            if isTab then
                local info, codes = fieldsOf(rawInfo, DV.SCORE_FIELDS)
                for _, fld in ipairs(DV.SCORE_FIELDS) do
                    bump(d.score, "GetScoreInfo|" .. c, fld, codes[fld])
                    bump(d.score, "GetScoreInfo@" .. phase, fld, codes[fld])
                end
                local nm = type(info.name) == "string" and info.name or nil
                local first = firstName(nm)
                local cls = type(info.classToken) == "string" and info.classToken ~= "" and info.classToken or nil
                local spec = info.talentSpec
                local guid = type(info.guid) == "string" and info.guid or nil
                if first and cls then bump(d.score, "GetScoreInfo@" .. phase, "use", "nameClass") end
                if e and first and cls then
                    -- only assign when this first name was unique in the GBS pass (no pending ambiguous)
                    local amb = false
                    local pk = idKey("name", first)
                    for _, bucket in pairs(d.scorePending) do
                        local p = pk and bucket[pk]
                        if p and p.ambiguous then amb = true break end
                    end
                    local nFirst = byFirst[first] and #byFirst[first] or 0
                    if not amb and nFirst <= 1 then
                        local key = idKey("name", first)
                        if key then
                            noteRaw(key, nm, guid)
                            e:Assign(key, cls, "score")
                            if ns.OocFill then
                                ns.OocFill.Note(key, "class", cls, "score")
                                if spec ~= nil and spec ~= "" then ns.OocFill.Note(key, "spec", spec, "score") end
                            end
                        end
                    else
                        bump(d.score, "bfSkip|" .. c, 1, "infoAmb")
                    end
                end
            end
        end
    end
    -- v2.2.20: the scoreboard lists the WHOLE enemy team (the meter only those met so far: run 15 census 3 vs 4 shamans)
    if anyEnemy then
        d.scoreComp = scoreComp
        if e then e:Composition(scoreComp) end
        if not myClass then
            local okC, _, f = pcall(g("UnitClass") or error, "player")
            myClass = okC and clearStr(f) or nil
        end
        if myClass and ns.Inference and ns.Inference.SetMeterEnemyCensus then
            ns.Inference.SetMeterEnemyCensus(scoreComp[myClass] or 0, now())
        end
    end
    local na, gs = g("GetNumArenaOpponentSpecs"), g("GetArenaOpponentSpec")
    if type(na) == "function" then record(d.score, "GetNumArenaOpponentSpecs|" .. c, pcall(na)) end
    if type(gs) == "function" then for i = 1, 3 do record(d.score, "GetArenaOpponentSpec|" .. c, pcall(gs, i)) end end
end

-- events ------------------------------------------------------------------------------------------------------------
local EVENTS = { "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_DISPLAYPOWER", "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START", "NAME_PLATE_UNIT_ADDED", "DAMAGE_METER_COMBAT_SESSION_UPDATED", "PLAYER_REGEN_ENABLED",
    "UPDATE_BATTLEFIELD_SCORE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS" }
local meterT, scoreT, frame, ticker = 0, 0, nil, nil

function DV.OnEvent(event, a1, a2)
    if event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" or event == "UNIT_DISPLAYPOWER" then
        DV.OnPower(a1, a2)
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        DV.OnCastStart(event, a1)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if type(a1) == "string" then DV.PlateColor(a1) end
    elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        local t = now()
        if t - meterT >= DV.METER_PERIOD then meterT = t DV.MeterSweep("update") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local ct = g("C_Timer")
        if type(ct) == "table" and ct.After then
            ct.After(1, function()
                if not active() then return end
                if ns.Perf then ns.Perf.Run("Derive.meterOoc", DV.MeterSweep, "regen") else pcall(DV.MeterSweep, "regen") end
            end)
        end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" or event == "ARENA_PREP_OPPONENT_SPECIALIZATIONS" then
        local t = now()
        if t - scoreT >= 1 then scoreT = t DV.ScoreSweep() end
    end
end

local function tick()
    DV.ReadSweep()
    local t = now()
    if t - scoreT >= DV.SCORE_PERIOD then
        scoreT = t
        local inst = g("IsInInstance")
        local okI, _, it = pcall(inst or error)
        local kind = okI and clearStr(it) or nil
        if kind == "pvp" or kind == "arena" then
            local req = g("RequestBattlefieldScoreData")
            if type(req) == "function" and not inCombat() then pcall(req) end
            DV.ScoreSweep()
        end
    end
end

local started = false
function DV.Start()
    started = false
    if not active() then return false end
    local d = db()
    if not d then return false end
    for k in pairs(d) do d[k] = nil end
    d.v, d.sid = 1, ns.db.logs.session and ns.db.logs.session.sid
    CE, meterT, scoreT, myClass = nil, 0, 0, nil
    DV.seenFull = {}
    DV.sharedFirst = {}
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...)
            if not active() then return end
            local ok, err
            if ns.Perf then ok, err = ns.Perf.Run(ns.Perf.Key("Derive", event), DV.OnEvent, event, ...)
            else ok, err = pcall(DV.OnEvent, event, ...) end
            if not ok and ns.NoteSelfError then ns.NoteSelfError("Derive." .. event, err) end
        end)
    end
    for _, ev in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
    local ct = g("C_Timer")
    if type(ct) == "table" and type(ct.NewTicker) == "function" then
        ticker = ct.NewTicker(DV.READ_PERIOD, function()
            if not active() then return end
            if ns.Perf then ns.Perf.Run("Derive.tick", tick) else pcall(tick) end
        end)
    end
    started = true
    return true
end

function DV.Stop()
    -- v2.2.20: a stop with nothing gathered (capture off at logout, or a /reload mid-capture: modules do not resume)
    -- must not write empty stub tables into the SV, nor overwrite what the pre-reload session saved
    if not started and not CE then return nil end
    started = false
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    if ticker and ticker.Cancel then ticker:Cancel() end
    ticker = nil
    local d = db()
    if not d then return nil end
    local e = CE
    if e then
        d.summary = e:Summary()
        d.units = d.units or {}
        for key, u in pairs(e.units) do
            local r = d.units[key] or { first = u.first }
            d.units[key] = r
            r.class, r.via, r.t, r.enemy, r.contradiction = u.class, u.via, u.t, u.enemy, u.contradiction
            local n = 0
            for _ in pairs(u.cand) do n = n + 1 end
            r.cands = n
            r.chain = u.chain
        end
    end
    return d.summary
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "derivation lab (capture level lab)", start = function() return DV.Start() end,
    stop = function()
        local s = DV.Stop()
        return s and string.format("derive: %d unit(s), %d assigned (%d enemies, %d assigned), %d contradiction(s)",
            s.units, s.assigned, s.enemies, s.enemyAssigned, s.contradictions)
    end }
