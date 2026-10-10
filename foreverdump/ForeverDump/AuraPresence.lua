-- ForeverDump v2.2.25 - aura PRESENCE probe (data collection; user idea 2026-10-10). v2.2.26 / v2.2.27:
--   (a) a nil / secret answer while aura access is restricted (combat, BG/arena, or the player's own GetAuraSlots not
--       clear this tick) is state U = unknown, never A = absent (runs 19-21: every combat 'absent' was present);
--   (b) v2.2.27 (user principle: no static / hardcoded lists): the candidate spell IDs come ONLY from dynamic sources,
--       per client build: auras read out of combat (UNIT_AURA payloads + GetAuraDataByIndex when clear), auras
--       observed after the player's own clear casts (cast -> aura pairs), and aura-like spells from the per-build
--       spellbook cache that `/fdump static run` builds (ForeverDumpDB.spellCache[build][class]); all persist in
--       ForeverDumpDB. No curated or mined list ships with the addon;
--   (c) out of combat: per unit full AuraData (stacks, duration, expiration, points/values, source) change-only tape;
--   (d) totems: GetTotemInfo per slot on PLAYER_TOTEM_UPDATE and each tick, coded per env tag, change-only tape;
--   (e) own clear UNIT_SPELLCAST_SUCCEEDED spellID -> aura(s) observed after that cast out of combat (pairs) with the
--       learned duration -> derived tape + state D where the live read is U;
--   (f) ADDON_RESTRICTION_STATE_CHANGED type/state counted per env tag and combat flag (also in Restrictions);
--   (4) health context: UnitHealth / UnitPower codes with UnitIsPVP / FFA / group / friend / self / restriction.
--   v2.2.29 (user: no "accurate but finds fewer" trade-offs): NO candidate is dropped and no rank skipped. The presence
--   checks run as a time-sliced queue (one job per probed unit) drained in OnUpdate under a per-frame budget
--   (AP.WALL_SHARE of the frame time, AP.FRAME_MIN_MS..AP.FRAME_MAX_MS), sized by the measured cost per check. Smart
--   frequency instead of cuts: tier H (own / live-seen / present-on-this-unit) every visit, W (plausible rank for the
--   unit's class + level, single-rank abilities) every AP.TIER_EVERY.W visits, C (other ranks, provisional, unknown
--   class/level) every AP.TIER_EVERY.C visits. Rank learn levels: C_Spell.GetSpellLevelLearned, cached per build in
--   ForeverDumpDB.spellLevel[build]. Worst-case staleness per tier and unit family is recorded (auraPresence.sched).
--   AP.Limit() is only a runaway backstop sized from the cost (thousands), with a warning.
--   Limit (v2.2.27, superseded by v2.2.29): no fixed cap; the per-tick candidate limit follows the measured cost per call so one tick stays
--   within AP.TICK_BUDGET_MS (dev budget); if it is ever reached a warning is logged once, counted, and the candidates
--   are prioritised (on me / my own-cast auras, then most recently seen, then most seen).
-- Question: while unit aura access is restricted (BG, arena, combat ...), is the PRESENCE of one known aura readable?
-- Per the 70245 API inventory: C_UnitAuras.GetUnitAuraBySpellID(unit, spellID) is AllowedWhenTainted +
-- SecretWhenUnitAuraRestricted (+ RequiresNonSecretAura); AuraIsBigDefensive(spellID) and GetAuraCasterGUID(unit,
-- auraInstanceID) take secret arguments when tainted; GetAuraSlots needs unit aura access (also probed, 'HELPFUL|PLAYER').
-- Every result is coded per environment x combat x phase (ns.EnvTag): N nil (absent), S secret value, K/T table
-- (present; fields coded per field), C clear scalar, E error (first message kept), held (circuit breaker).
-- Change-only tape (unit name, spell, state) is scored offline against the combat log's aura applications
-- (tools/fdump/aurapresence.py). Capture level lab only; budget: a few units per second.
local _, ns = ...
local AP = {}
ns.AuraPresence = AP

AP.FIELDS = { "spellId", "auraInstanceID", "sourceUnit", "duration", "expirationTime", "applications",
    "isFromPlayerOrPlayerPet", "name" }
AP.TICK_BUDGET_MS = 30   -- one tick (1 s period) <= 30 ms = 3 % of wall; FD's other lab handlers measured ~2 % (run 19),
                         -- so the dev 10 % budget keeps > 5 % headroom
AP.COST_INIT_MS = 0.012  -- ms per presence call (incl. classify + tape) before the first in-game measurement: worst
                         -- upper bound of runs 19-21 (AuraPresence.tick ms / presence calls: 0.0057 bg, 0.0123 dungeon, 0.0093 world)
AP.LIMIT_MIN = 2000      -- v2.2.29: runaway backstop floor (realistic lists: 33-582 on runs 19-22 + library)
AP.LIMIT_ABS = 20000     -- memory / sanity ceiling
AP.WALL_SHARE = 0.05     -- v2.2.29: presence checks may use 5 % of each frame's time (FD rest ~2.2 %: dev budget 10 %)
AP.FRAME_MIN_MS = 0.2    -- ... but at least this per frame (progress at very high frame rates)
AP.FRAME_MAX_MS = 1.5    -- ... and never more (no hitch at low frame rates)
AP.TIER_EVERY = { H = 1, W = 3, C = 10 }   -- checked every Nth visit of a unit (a fixed unit is visited every AP.PERIOD)
AP.PLAUSIBLE_RANKS = 2   -- per ability: the highest ranks learnable at the unit's level are tier W, other ranks tier C
AP.LEVEL_PER_FRAME = 25  -- GetSpellLevelLearned lookups per idle frame (cached per build)
AP.ROT_FILL = 0.7        -- share of the per-period budget the rotation may plan for (the rest: backlog headroom)
AP.ROTATE_MAX = 40       -- rotating units per tick at most
AP.UNIT_EXTRA = 12       -- other calls per unit visit (exists, GUID, name, slots, health context ...), in checks
AP.CHECK_EVERY = 8       -- checks between two debugprofilestop reads
AP.LEARN_ABS = 20000     -- learned IDs per build (memory ceiling only; warns when hit)
AP.EARLY_WINDOW = 0.1     -- s an own aura may precede its UNIT_SPELLCAST_SUCCEEDED and still pair
AP.LIST_REFRESH = 60     -- s: candidate list rebuilt at least this often
AP.PAIR_WINDOW = 0.6     -- s: an aura of mine that appears this soon after my own clear cast pairs with it
AP.DETAIL_MAX = 20000
AP.TOTEM_MAX = 4000
AP.DERIVE_MAX = 8000
AP.HCTX_MAX = 3000
AP.PERIOD = 1.0          -- s
AP.ROTATE = 3            -- rotating units per tick (target / focus / mouseover / player every tick)
AP.TAPE_MAX = 40000
AP.FIXED = { "player", "target", "focus", "mouseover" }
AP.ROT = {}
for i = 1, 40 do AP.ROT[#AP.ROT + 1] = "nameplate" .. i end
for i = 1, 5 do AP.ROT[#AP.ROT + 1] = "arena" .. i end
for i = 1, 4 do AP.ROT[#AP.ROT + 1] = "party" .. i end
for i = 1, 40 do AP.ROT[#AP.ROT + 1] = "raid" .. i end

local function g(n) return rawget(_G, n) end
local function now() local f = g("GetTime") return f and f() or 0 end
local function code(v) return ns.ClassifyValue and ns.ClassifyValue(v) or (v == nil and "N" or "C") end
local function clearStr(v) return ns.ClearStr and ns.ClearStr(v) or nil end
local function fam(u) return (u:gsub("%d+$", "N")) end
local function isTrue(v) return ns.IsTrue and ns.IsTrue(v) or false end
local function clearNum(v) return ns.ClearOf and ns.ClearOf(v, "number") or nil end
local function clearBool(v)
    if type(v) ~= "boolean" or code(v) ~= "C" then return nil end
    return v
end
local function b2s(v) if v == nil then return "?" end return v and "1" or "0" end

local function db()
    local log = g("ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    local d = log.auraPresence
    if not d then
        d = { v = 1, codes = {}, fields = {}, slots = {}, caster = {}, bigDef = {}, err = {}, tape = {}, last = {},
              units = {}, tapeDropped = 0 }
        log.auraPresence = d
    end
    return d
end
local function inc(t, k, c)
    local x = t[k]
    if not x then x = {} t[k] = x end
    x[c] = (x[c] or 0) + 1
end
local function sub(t, k)
    local x = t[k]
    if not x then x = {} t[k] = x end
    return x
end

-- classify one GetUnitAuraBySpellID result -> state P (present table) / A (absent nil) / S / C / E / H (held)
-- v2.2.26: restricted -> a nil or secret answer is U (unknown): the API hides auras then, it does not report absence
function AP.Classify(held, ok, v, restricted)
    if held then return "H", "held" end
    if not ok then return "E", "E" end
    local c = code(v)
    if restricted and (c == "N" or c == "S") then return "U", c end
    if c == "N" then return "A", c end
    if c == "K" or c == "T" then return "P", c end
    return c == "S" and "S" or "C", c
end

local function build() return ns.Build and tostring(ns.Build()) or "?" end
local function epochNow() local tf = g("time") return type(tf) == "function" and tf() or 0 end

-- per-build stores in ForeverDumpDB (persist across sessions; a new client build starts empty and relearns)
local function store(key)
    local db0 = ns.db
    if type(db0) ~= "table" then return nil end
    local root = db0[key]
    if type(root) ~= "table" then root = {} db0[key] = root end
    local b = build()
    -- v2.2.26 kept auraLearned flat (spellID keys): move those entries under the current build once
    if key == "auraLearned" then
        local moved
        for k, v in pairs(root) do if type(k) == "number" then moved = moved or {} moved[k] = v end end
        if moved then
            root[b] = root[b] or {}
            for k, v in pairs(moved) do root[k] = nil if root[b][k] == nil then root[b][k] = v end end
        end
    end
    if type(root[b]) ~= "table" then
        root[b] = {}
        if key == "auraLearned" or key == "auraPairs" then AP.CarryOver(key, root, b) end
    end
    return root[b]
end
AP.Store = store

-- newest build key below b holding a non-empty table (cross-build carry-over source)
local function prevBuild(root, b)
    local nb, best = tonumber(b), nil
    for k, v in pairs(root or {}) do
        local nk = tonumber(k)
        if nk and nb and nk < nb and type(v) == "table" and next(v) ~= nil and (not best or nk > tonumber(best)) then best = k end
    end
    return best
end
AP.PrevBuild = prevBuild

-- (v2.2.28) a new client build starts from the previous build's learned auras / pairs, tagged provisional
-- (prov = "prev-build:<b>") until a clear read or an observed pair on this build confirms them
function AP.CarryOver(key, root, b)
    local pb = prevBuild(root, b)
    if not pb then return 0 end
    local n, dst = 0, root[b]
    for sid, r in pairs(root[pb]) do
        if type(r) == "table" then
            local c = {}
            if key == "auraLearned" then
                c = { n = 0, dur = r.dur, name = r.name, self = r.self, own = r.own, seen = r.seen }
            else
                for aid, pr in pairs(r) do
                    if type(pr) == "table" then c[aid] = { n = 0, self = pr.self, target = pr.target, name = pr.name, prov = "prev-build:" .. tostring(pb) } end
                end
            end
            if key == "auraLearned" then c.prov = "prev-build:" .. tostring(pb) end
            dst[sid] = c
            n = n + 1
        end
    end
    local db0 = ns.db
    if type(db0) == "table" then
        db0.auraCarry = type(db0.auraCarry) == "table" and db0.auraCarry or {}
        db0.auraCarry[b .. ":" .. key] = { from = tostring(pb), n = n, time = epochNow() }
    end
    return n
end

local function warn(d, kind, msg)
    d.warnings = d.warnings or {}
    d.warnCount = d.warnCount or {}
    d.warnCount[kind] = (d.warnCount[kind] or 0) + 1
    if d.warnCount[kind] == 1 then
        d.warnings[#d.warnings + 1] = string.format("%.2f|%s|%s", now(), kind, msg)
        if ns.Print then pcall(ns.Print, "aura presence: " .. msg) end
    end
end

-- (b) learn one aura: flags.self (on the player), flags.own (applied by the player / pet)
function AP.Learn(sid, name, dur, flags)
    local L = store("auraLearned")
    if not L or type(sid) ~= "number" then return end
    local r = L[sid]
    if not r then
        AP.learnedN = AP.learnedN or 0
        if AP.learnedN == 0 then for _ in pairs(L) do AP.learnedN = AP.learnedN + 1 end end
        if AP.learnedN >= AP.LEARN_ABS then
            local d = db()
            if d then warn(d, "learnLimit", "learned aura store full (" .. AP.LEARN_ABS .. " IDs for this build)") end
            return
        end
        r = { n = 0 }
        L[sid] = r
        AP.learnedN = AP.learnedN + 1
        if not AP.inList or not AP.inList[sid] then AP.listDirty = true end
    end
    r.n = (r.n or 0) + 1
    if r.prov then r.prov, r.confirmed = nil, epochNow() AP.listDirty = true end   -- re-confirmed on this build
    if type(name) == "string" then r.name = name end
    if type(dur) == "number" and dur > 0 then r.dur = dur end
    if flags and flags.self then r.self = (r.self or 0) + 1 end
    if flags and flags.own then r.own = (r.own or 0) + 1 end
    r.seen = epochNow()
end

-- (b) candidates: learned (per build) + own-cast pair auras + aura-like spellbook spells of the per-build cache;
-- prioritised (on me / mine, then recently seen, then most seen) and cut at the measured limit
function AP.Candidates()
    local cand, seen = {}, {}
    local function add(sid, name, src, pri, seenAt, n)
        if type(sid) ~= "number" then return end
        local c = seen[sid]
        if not c then
            c = { sid, name, src, pri = pri, seen = seenAt or 0, n = n or 0 }
            seen[sid] = c
            cand[#cand + 1] = c
        elseif pri > c.pri then c.pri, c[3] = pri, src end
    end
    for sid, r in pairs(store("auraLearned") or {}) do
        if type(r) == "table" then
            local pri = ((r.self or 0) > 0 or (r.own or 0) > 0) and 3 or 1
            if r.prov then add(sid, r.name, "prev-build", 1, 0, 0)
            else add(sid, r.name, "learned", pri, r.seen, r.n) end
        end
    end
    for _, auras in pairs(store("auraPairs") or {}) do
        if type(auras) == "table" then
            for asid, pr in pairs(auras) do if type(pr) == "table" then add(asid, pr.name, "pair", 2, pr.seen, pr.n) end end
        end
    end
    for _, byClass in pairs(store("spellCache") or {}) do
        if type(byClass) == "table" and type(byClass.spells) == "table" then
            for sid, sp in pairs(byClass.spells) do
                if type(sp) == "table" and sp.aura then add(sid, sp.name, "spellcache", 0, 0, 0) end
            end
        end
    end
    -- v2.2.28 (run 22: 0 candidates all BG): two per-build stores other modules already learn dynamically
    for sid, r in pairs(AP.RefAuraDur()) do
        if type(sid) == "number" and type(r) == "table" then add(sid, nil, "ooclearn", 1, 0, r.n or 0) end
    end
    for sid, k in pairs(AP.KnowledgeAuras()) do add(sid, k.name, "knowledge", 2, 0, 0) end
    -- (v2.2.28) offline feedback: Data/LearnedAuras.lua, GENERATED from every stored combat log by
    -- tools/fdump/learnedauras.py (all auras incl. enemy debuffs never readable live); optional, lowest priority
    for sid, r in pairs(AP.OfflineAuras()) do
        if type(sid) == "number" and type(r) == "table" then
            if AP.Confirmed(r) then add(sid, r.name, "offline", -1, 0, r.n or 0)
            else add(sid, r.name, "offline-prov", -2, 0, r.n or 0) end
        end
    end
    table.sort(cand, function(a, b)
        if a.pri ~= b.pri then return a.pri > b.pri end
        if a.seen ~= b.seen then return a.seen > b.seen end
        if a.n ~= b.n then return a.n > b.n end
        return a[1] < b[1]
    end)
    return cand
end

-- OocFill learns every clear aura it enumerates out of combat (any unit, any class) with its duration:
-- ForeverDumpDB.refLearned[build].auraDur[spellID] = { n, min, max }
local function withAuraDur(root, b)
    local L = type(root) == "table" and root[b] or nil
    return type(L) == "table" and type(L.auraDur) == "table" and next(L.auraDur) ~= nil and L.auraDur or nil
end
function AP.RefAuraDur()
    local rl = ns.db and ns.db.refLearned
    local b = build()
    local cur = withAuraDur(rl, b)
    if cur then return cur, b end
    -- (v2.2.28) new build: the previous build's OOC-learned durations, provisional
    if type(rl) == "table" then
        local best
        for k in pairs(rl) do
            if tonumber(k) and tonumber(b) and tonumber(k) < tonumber(b) and withAuraDur(rl, k) and (not best or tonumber(k) > tonumber(best)) then best = k end
        end
        if best then return withAuraDur(rl, best), best end
    end
    return {}, nil
end
-- (v2.2.28) ns.LearnedAuras (Data/LearnedAuras.lua): the GENERATED growing library (tools/fdump/learnedauras.py, schema 2)
-- spells[spellID] = { n, dur, name, builds = "70334,70338", base, cls }; pairs[cast][aura] = { n, self, target, builds }.
-- An entry not confirmed on the running build is provisional. config auraPresence.offline = false switches it off.
local function libOn()
    local cfgAP = ns.config and ns.config.auraPresence
    if type(cfgAP) == "table" and cfgAP.offline == false then return nil end
    local LA = ns.LearnedAuras
    return type(LA) == "table" and type(LA.spells) == "table" and LA or nil
end
function AP.Confirmed(entry)
    local bs = type(entry) == "table" and entry.builds
    if type(bs) ~= "string" then return false end
    local b = build()
    for x in bs:gmatch("[^,]+") do if x == b then return true end end
    return false
end
function AP.OfflineAuras()
    local LA = libOn()
    return LA and LA.spells or {}
end
function AP.OfflinePairs(cast)
    local LA = libOn()
    local P = LA and type(LA.pairs) == "table" and LA.pairs[cast] or nil
    return type(P) == "table" and P or nil
end
-- Knowledge collects the player's spellbook every session (no /fdump static run needed) and parses the description:
-- ForeverDumpDB.knowledge[build].spells[spellID].data.parsed.auraDuration (+ consumable = charges)
function AP.KnowledgeAuras()
    local kn = ns.db and ns.db.knowledge
    local K = type(kn) == "table" and kn[build()] or nil
    if (type(K) ~= "table" or type(K.spells) ~= "table" or next(K.spells) == nil) and type(kn) == "table" then
        local pb = prevBuild(kn, build())     -- (v2.2.28) new build: previous build's spellbook knowledge, provisional
        K = pb and kn[pb] or K
    end
    local out = {}
    if type(K) ~= "table" or type(K.spells) ~= "table" then return out end
    for sid, rec in pairs(K.spells) do
        local dd = type(rec) == "table" and type(rec.data) == "table" and rec.data or nil
        local p = dd and type(dd.parsed) == "table" and dd.parsed or nil
        if type(sid) == "number" and p and type(p.auraDuration) == "number" and p.auraDuration > 0 then
            out[sid] = { dur = p.auraDuration, consumable = p.consumable == true,
                name = type(dd["info.name"]) == "string" and dd["info.name"] or nil }
        end
    end
    return out
end

function AP.Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

-- v2.2.29: runaway BACKSTOP only (nothing realistic reaches it): the candidates that still fit the per-frame budget if
-- every one of them were tier C on #FIXED + ROTATE units: (checks per second) x TIER_EVERY.C / units
function AP.Capacity()
    local per = AP.costMs or AP.COST_INIT_MS
    if per ~= per or per <= 0 then per = AP.COST_INIT_MS end   -- NaN or <= 0
    return AP.WALL_SHARE * 1000 / per            -- checks per second at the wall share
end
function AP.Limit()
    local units = #AP.FIXED + AP.ROTATE
    local lim = math.floor(AP.Capacity() * AP.TIER_EVERY.C * AP.PERIOD / units)
    if lim < AP.LIMIT_MIN then lim = AP.LIMIT_MIN end
    if lim > AP.LIMIT_ABS then lim = AP.LIMIT_ABS end
    return lim
end

-- rank learn level per build (C_Spell.GetSpellLevelLearned: AllowedWhenTainted per the 70245 inventory); 0 = no answer
function AP.LevelLearned(sid)
    local L = store("spellLevel")
    local v = L and L[sid]
    if v ~= nil then return v > 0 and v or nil end
    return nil
end
local levelQ, levelPos = {}, 1
function AP.FillLevels(maxN)
    local L = store("spellLevel")
    local CS = g("C_Spell")
    local fn = type(CS) == "table" and CS.GetSpellLevelLearned or nil
    if not L or type(fn) ~= "function" then levelQ, levelPos = {}, 1 return 0 end
    local n = 0
    while levelPos <= #levelQ and n < maxN do
        local sid = levelQ[levelPos]
        levelPos = levelPos + 1
        if L[sid] == nil then
            local ok, v = pcall(fn, sid)
            v = ok and clearNum(v) or nil
            L[sid] = (v and v > 0) and v or 0
            n = n + 1
            if v and v > 0 then AP.plans = {} end   -- tiers depend on it
        end
    end
    return n
end
function AP.LevelsPending() return #levelQ - levelPos + 1 end

-- own / live sources: checked on every visit (tier H)
AP.HOT_SRC = { learned = true, pair = true, knowledge = true, spellcache = true, ["prev-build"] = true }

function AP.List()
    if AP.LIST and not AP.listDirty then return AP.LIST end
    local cand = AP.Candidates()
    local lim = AP.Limit()
    local d = db()
    local LS = AP.OfflineAuras()
    -- v2.2.29: ranks are GROUPED (one ability = one name) but never dropped; the group decides the tier per unit
    local list, inList, groups, ng, multi = {}, {}, {}, 0, 0
    for i = 1, math.min(#cand, lim) do
        local c = cand[i]
        local e = LS[c[1]]
        local nm = (type(c[2]) == "string" and c[2]) or (type(e) == "table" and e.name) or nil
        local key = nm and nm:lower() or c[1]
        local ent = { c[1], nm, c[3], key = key, n = c.n or 0, cls = type(e) == "table" and e.cls or nil,
            prov = c[3] == "offline-prov" or c[3] == "prev-build" }
        list[i] = ent
        inList[c[1]] = c[3]
        local gr = groups[key]
        if not gr then gr = {} groups[key] = gr ng = ng + 1 end
        gr[#gr + 1] = ent
        if #gr == 2 then multi = multi + 1 end
    end
    levelQ, levelPos = {}, 1
    local L = store("spellLevel") or {}
    for _, gr in pairs(groups) do
        if #gr > 1 then for _, ent in ipairs(gr) do if L[ent[1]] == nil then levelQ[#levelQ + 1] = ent[1] end end end
    end
    AP.listStats = { candidates = #cand, listed = #list, groups = ng, multiRank = multi, limit = lim }
    if d then
        local src = {}
        for _, s2 in ipairs(list) do src[s2[3]] = (src[s2[3]] or 0) + 1 end
        d.list = { n = #list, candidates = #cand, limit = lim, costMs = AP.costMs, bySource = src, groups = ng,
            multiRankGroups = multi, levelsPending = #levelQ }
        if #cand > lim then
            d.limitHit = (d.limitHit or 0) + 1
            warn(d, "limit", string.format("%d candidates > runaway backstop %d (%.4f ms per check): lowest-priority "
                .. "candidates skipped - raise AP.LIMIT_ABS or check the learners", #cand, lim, AP.costMs or AP.COST_INIT_MS))
        end
    end
    AP.LIST, AP.inList, AP.groups, AP.listDirty, AP.listAt, AP.plans = list, inList, groups, false, now(), {}
    return list
end

-- v2.2.29 tier plan for a unit (cached per class|level): H every visit, W every TIER_EVERY.W, C every TIER_EVERY.C.
-- Rank plausibility needs BOTH the unit's class and level clear (BG: often secret) and every rank's learn level known;
-- then the AP.PLAUSIBLE_RANKS highest ranks learnable at that level are W, the rest C. Otherwise (unknown): the most
-- seen rank W, the others C - still checked, only less often. Single-rank abilities W (provisional ones C).
function AP.Plan(class, level)
    AP.List()
    local key = tostring(class) .. "|" .. tostring(level)
    local pl = AP.plans[key]
    if pl then return pl end
    pl = { H = {}, W = {}, C = {}, key = key }
    local function put(t, ent) pl[t][#pl[t] + 1] = ent[1] end
    for _, gr in pairs(AP.groups or {}) do
        local rest = {}
        for _, ent in ipairs(gr) do
            if AP.HOT_SRC[ent[3]] then put("H", ent) else rest[#rest + 1] = ent end
        end
        if #rest == 1 and #gr == 1 then
            put(rest[1].prov and "C" or "W", rest[1])
        elseif #rest > 0 then
            local known = class ~= nil and level ~= nil
            local lv = {}
            local lv1, varies
            for _, ent in ipairs(rest) do
                lv[ent] = AP.LevelLearned(ent[1])
                if not lv[ent] then known = false end
                if lv1 and lv[ent] ~= lv1 then varies = true end
                lv1 = lv1 or lv[ent]
            end
            -- one level for every rank (e.g. a client that answers 1 for spells outside the own spellbook) says nothing
            if #rest > 1 and not varies then known = false end
            if known then
                table.sort(rest, function(a, b)
                    local la, lb = lv[a] <= level, lv[b] <= level
                    if la ~= lb then return la end
                    if lv[a] ~= lv[b] then return lv[a] > lv[b] end
                    return a[1] < b[1]
                end)
                for i, ent in ipairs(rest) do put((i <= AP.PLAUSIBLE_RANKS and lv[ent] <= level) and "W" or "C", ent) end
            else
                table.sort(rest, function(a, b) if a.n ~= b.n then return a.n > b.n end return a[1] < b[1] end)
                -- an ability whose own-spellbook rank is hot already has its plausible rank covered: rest C
                for i, ent in ipairs(rest) do put((i == 1 and #rest == #gr) and "W" or "C", ent) end
            end
        end
    end
    for _, t in ipairs({ "H", "W", "C" }) do table.sort(pl[t]) end
    AP.plans[key] = pl
    return pl
end

-- cached duration of an aura: learned out of combat (AuraData.duration), else the spellbook cache hint
function AP.Duration(sid)
    local r = (store("auraLearned") or {})[sid]
    if r and type(r.dur) == "number" then return r.dur, "learned" end
    local ra = AP.RefAuraDur()[sid]
    if type(ra) == "table" and type(ra.min) == "number" and ra.min > 0 then return ra.min, "ooclearn" end
    local ka = AP.KnowledgeAuras()[sid]
    if ka then return ka.dur, "knowledge" end
    local oa = AP.OfflineAuras()[sid]
    if type(oa) == "table" and type(oa.dur) == "number" and oa.dur > 0 then return oa.dur, AP.Confirmed(oa) and "offline" or "offline-prov" end
    for _, byClass in pairs(store("spellCache") or {}) do
        local sp = type(byClass) == "table" and type(byClass.spells) == "table" and byClass.spells[sid] or nil
        if type(sp) == "table" and type(sp.dur) == "number" then return sp.dur, "spellcache" end
    end
    return nil, nil
end

-- (e) derived auras: key (guid or token) | spellID -> expiry (GetTime)
AP.derived = {}
AP.lastCast = nil
function AP.DerivedActive(who, sid)
    local e = AP.derived[who .. "|" .. sid]
    return e and e > now() or false
end
function AP.OnOwnCast(spellID)
    local sid = clearNum(spellID)
    if not sid then return end
    local okG, tg = pcall(g("UnitGUID") or error, "target")
    AP.lastCast = { sid = sid, t = now(), target = okG and clearStr(tg) or nil }
    local early = AP.recentAuras
    AP.recentAuras = nil
    if early then
        for _, r in ipairs(early) do
            local dt = AP.lastCast.t - r[1]
            if dt >= 0 and dt <= AP.EARLY_WINDOW then AP.PairFromAura(r[2], r[3], r[4]) end
        end
    end
    local map = (store("auraPairs") or {})[sid]
    if type(map) ~= "table" then
        -- v2.2.28: library pairs observed in the stored combat logs (n >= 3), e.g. 17364 Stormstrike -> 1238931
        -- Improved Stormstrike on self (567 in the logs; the same-ID rule cannot find it)
        local lp = AP.OfflinePairs(sid)
        if lp then
            for aid, pr in pairs(lp) do
                if type(pr) == "table" and (pr.n or 0) >= 3 then
                    map = map or {}
                    map[aid] = { n = pr.n, self = pr.self, target = pr.target, rule = "library" }
                end
            end
        end
    end
    if type(map) ~= "table" then
        -- v2.2.28: no observed pair yet -> the cached per-build spell data: a spell whose description states an aura
        -- duration applies the aura of the same ID (self when the cast had no other target). Run 22 CL check: applied
        -- 36/48, but only 7/34 ended at cast + duration (charges, dispels, PvP) -> D = "applied by my cast, may have
        -- ended early"; consumable (charge) auras are skipped.
        local ka = AP.KnowledgeAuras()[sid]
        if not ka or ka.consumable then return end
        local okT, tex = pcall(g("UnitExists") or error, "target")
        local hasT = okT and isTrue(tex)
        map = { [sid] = { n = 0, self = hasT and 0 or 1, target = hasT and 1 or 0, rule = "knowledge" } }
    end
    local d = db()
    if not d then return end
    d.derived = d.derived or {}
    local tag = ns.EnvTag and ns.EnvTag() or "?"
    for aid, pr in pairs(map) do
        if type(pr) == "table" then
            local who = (pr.self or 0) >= (pr.target or 0) and "self" or "target"
            local dur, dsrc = AP.Duration(aid)
            local tok = who == "self" and "player" or "target"
            local okU, guid = pcall(g("UnitGUID") or error, tok)
            guid = okU and clearStr(guid) or nil
            if dur then
                AP.derived[(guid or tok) .. "|" .. aid] = now() + dur
                if guid then AP.derived[tok .. "|" .. aid] = now() + dur end
            end
            if #d.derived < AP.DERIVE_MAX then
                d.derived[#d.derived + 1] = string.format("%.2f|%d|%d|%s|%s|%s|%s|%s|%d", now(), sid, aid, tok, guid or "",
                    dur and string.format("%.1f", dur) or "", dsrc or "", tag, pr.n or 0)
            end
        end
    end
end

-- an aura of mine just appeared on u (clear read): pair it with my own cast if that was AP.PAIR_WINDOW ago or less
function AP.PairFromAura(u, sid, name)
    local lc = AP.lastCast
    if not lc or now() - lc.t > AP.PAIR_WINDOW then
        -- the aura can show up a few ms BEFORE its cast (run 22 CL: 1238931 at .243, the 17364 cast at .245):
        -- keep it briefly, OnOwnCast pairs it
        local r = AP.recentAuras or {}
        AP.recentAuras = r
        r[#r + 1] = { now(), u, sid, name }
        if #r > 4 then table.remove(r, 1) end
        return
    end
    lc.paired = lc.paired or {}
    if lc.paired[u .. "|" .. sid] then return end      -- UNIT_AURA payload and the slot scan both see it: count once
    lc.paired[u .. "|" .. sid] = true
    local P = store("auraPairs")
    if not P then return end
    local m = P[lc.sid]
    if type(m) ~= "table" then m = {} P[lc.sid] = m end
    local pr = m[sid]
    if type(pr) ~= "table" then pr = { n = 0 } m[sid] = pr AP.listDirty = true end
    pr.n = pr.n + 1
    pr.prov = nil
    if u == "player" then pr.self = (pr.self or 0) + 1 else pr.target = (pr.target or 0) + 1 end
    if type(name) == "string" then pr.name = name end
    pr.seen = epochNow()
end

-- (a)/(b) UNIT_AURA payload (clear only out of combat): learn every added aura, pair mine with my last own cast
function AP.OnUnitAura(u, info)
    if type(u) ~= "string" or code(info) ~= "K" then return end
    local okA, added = pcall(function() return info.addedAuras end)
    if not okA or type(added) ~= "table" or code(added) ~= "K" then return end
    for i = 1, 40 do
        local okI, a = pcall(function() return added[i] end)
        if not okI or a == nil then break end
        if type(a) == "table" and code(a) == "K" then
            local sid = clearNum(a.spellId)
            if sid then
                local mine = clearBool(a.isFromPlayerOrPlayerPet)
                AP.Learn(sid, clearStr(a.name), clearNum(a.duration), { self = u == "player", own = mine == true })
                if mine then AP.PairFromAura(u, sid, clearStr(a.name)) end
            end
        end
    end
end

-- dispel-like spells of the player's class from the per-build spellbook cache (CombatProbe; replaces the v2.2.25
-- configured 10-ID list). A user-set config combatProbe.dispelSpells is still honoured.
function AP.DispelSpells()
    local out = {}
    local okC, _, class = pcall(g("UnitClass") or error, "player")
    class = okC and clearStr(class) or "?"
    local c = (store("spellCache") or {})[class]
    if type(c) == "table" and type(c.spells) == "table" then
        for sid, sp in pairs(c.spells) do if type(sp) == "table" and sp.dispel then out[#out + 1] = sid end end
    end
    table.sort(out)
    return out
end

-- (b) per-build spellbook cache, built by `/fdump static run` (Static.lua finish): every spellbook spell with its
-- name; aura = the description states a duration ("for 30 sec", "lasts 10 min", "over 12 sec"), dur = that duration.
-- Kept per build and class (ForeverDumpDB.spellCache[build][class]), so every class the user plays adds its spells.
local function descDuration(desc)
    if type(desc) ~= "string" then return nil end
    local n, unit = desc:match("(%d+%.?%d*) (sec)")
    if not n then n, unit = desc:match("(%d+%.?%d*) (min)") end
    if not n then return nil end
    return tonumber(n) * (unit == "min" and 60 or 1)
end
AP.DescDuration = descDuration
-- own spellbook spell IDs (C_SpellBook skill lines). Run 19 / 22: Knowledge read 77/77 spellbook spells + clear
-- descriptions in BG prep (capture:on 13:39:25) and in BG combat, so this is not restricted in a BG.
function AP.SpellbookIDs()
    local sb = g("C_SpellBook")
    local ids, seen = {}, {}
    if type(sb) ~= "table" or type(sb.GetNumSpellBookSkillLines) ~= "function" then return ids end
    local bank = (g("Enum") and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local okN, n = pcall(sb.GetNumSpellBookSkillLines)
    n = okN and clearNum(n) or 0
    for i = 1, n do
        local okI, info = pcall(sb.GetSpellBookSkillLineInfo, i)
        if okI and type(info) == "table" then
            local off, num = clearNum(info.itemIndexOffset) or 0, clearNum(info.numSpellBookItems) or 0
            for idx = off + 1, off + num do
                local okT, _, _, sid = pcall(sb.GetSpellBookItemType, idx, bank)
                sid = okT and clearNum(sid) or nil
                if sid and not seen[sid] then seen[sid] = true ids[#ids + 1] = sid end
            end
        end
    end
    return ids
end
function AP.SpellEntry(sid)
    local cs = g("C_Spell")
    local name, desc
    if type(cs) == "table" then
        if type(cs.GetSpellName) == "function" then local okS, v = pcall(cs.GetSpellName, sid) name = okS and clearStr(v) or nil end
        if type(cs.GetSpellDescription) == "function" then
            local okD, v = pcall(cs.GetSpellDescription, sid)
            desc = okD and clearStr(v) or nil
        end
    end
    local dur = descDuration(desc)
    local ld = type(desc) == "string" and desc:lower() or ""
    local disp = (ld:find("dispel") or ld:find("remov") or ld:find("purge") or ld:find("cleanse")
        or ld:find("cure ")) and true or nil
    return { name = name, aura = dur ~= nil, dur = dur, dispel = disp, desc = desc ~= nil or nil }
end
local function playerClass()
    local okC, _, class = pcall(g("UnitClass") or error, "player")
    return okC and clearStr(class) or "?"
end
function AP.BuildSpellCache()
    local C = store("spellCache")
    if not C then return 0 end
    local out = { built = epochNow(), spells = {}, how = "static run" }
    local cnt = 0
    for _, sid in ipairs(AP.SpellbookIDs()) do out.spells[sid] = AP.SpellEntry(sid) cnt = cnt + 1 end
    C[playerClass()] = out
    AP.listDirty = true
    return cnt
end

-- (v2.2.28) automatic per-build cache: on login / zoning when this build + class has none yet, spread over frames
-- (AP.AUTO_CHUNK spells per AP.AUTO_STEP s), only out of combat (BG prep is out of combat); a combat pause resumes
-- later. No /fdump static run needed for the aura list.
AP.AUTO_CHUNK, AP.AUTO_STEP, AP.AUTO_WAIT = 20, 0.05, 2
local autoJob
function AP.AutoSpellCache(why)
    local C = store("spellCache")
    if not C or autoJob then return false end
    local class = playerClass()
    if type(C[class]) == "table" and type(C[class].spells) == "table" and next(C[class].spells) ~= nil then return false end
    local ct = g("C_Timer")
    local ids = AP.SpellbookIDs()
    if #ids == 0 then return false end
    autoJob = { ids = ids, i = 0, out = { spells = {}, how = "auto:" .. tostring(why or "?"), started = epochNow() }, class = class }
    local function step()
        local job = autoJob
        if not job then return end
        if ns.InCombat() then
            if type(ct) == "table" and ct.After then ct.After(AP.AUTO_WAIT, step) end
            return
        end
        for _ = 1, AP.AUTO_CHUNK do
            job.i = job.i + 1
            local sid = job.ids[job.i]
            if not sid then break end
            job.out.spells[sid] = AP.SpellEntry(sid)
        end
        if job.i >= #job.ids then
            job.out.built = epochNow()
            local CC = store("spellCache")
            if CC then CC[job.class] = job.out end
            autoJob = nil
            AP.listDirty = true
        elseif type(ct) == "table" and ct.After then ct.After(AP.AUTO_STEP, step)
        else step() end
    end
    step()
    return true
end
function AP.AutoRunning() return autoJob ~= nil end

-- login / zoning hook (independent of captures)
do
    local cf = g("CreateFrame")
    if type(cf) == "function" then
        local okF, fr = pcall(cf, "Frame")
        if okF and fr and fr.RegisterEvent then
            pcall(fr.RegisterEvent, fr, "PLAYER_ENTERING_WORLD")
            pcall(fr.SetScript, fr, "OnEvent", function()
                local ct = g("C_Timer")
                if type(ct) == "table" and ct.After then ct.After(3, function() pcall(AP.AutoSpellCache, "login") end)
                else pcall(AP.AutoSpellCache, "login") end
            end)
        end
    end
end

-- aura access restricted right now? combat, BG/arena, or the player's own aura slots not clear this tick
function AP.Restricted(slotsClear)
    if ns.InCombat and ns.InCombat() then return true, "combat" end
    local e = ns.Env and ns.Env() or {}
    if e.env == "bg" or e.env == "arena" then return true, e.env end
    if slotsClear == false then return true, "slots" end
    return false, nil
end

local function restrictionVector()
    local R = ns.Restrictions
    if not (R and R.States) then return "" end
    local ok, st = pcall(R.States)
    if not ok or type(st) ~= "table" then return "?" end
    local parts = {}
    for k, v in pairs(st) do if type(v) == "number" and v > 0 then parts[#parts + 1] = k .. "=" .. v end end
    table.sort(parts)
    return table.concat(parts, ",")
end
AP.RestrictionVector = restrictionVector

local function unitName(u)
    local f = g("UnitName")
    if type(f) ~= "function" then return "" end
    local ok, n, r = pcall(f, u)
    if not ok then return "" end
    local s = clearStr(n)
    if not s then return "" end
    local rs = clearStr(r)
    if rs and rs ~= "" then s = s .. "-" .. rs end
    return s
end

-- one presence check (unit, spellID): classify, D overlay, codes, fields, caster, change-only tape, sticky-hot set
function AP.Check(d, job, sid, fc, tag, restricted, AG, fn, Aur)
    local u, f, guid, name = job.u, job.f, job.guid, job.name
    local held, ok, v
    if AG and AG.Call then held, ok, v = AG.Call("GetUnitAuraBySpellID", f, fn, u, sid)
    else held, ok, v = false, pcall(fn, u, sid) end
    local st, c = AP.Classify(held, ok, v, restricted)
    if st == "U" and (AP.DerivedActive(guid ~= "" and guid or u, sid) or AP.DerivedActive(u, sid)) then
        st = "D"   -- (e) expected from my own clear cast, live read unknown
    end
    inc(fc, sid, c)
    if st == "E" then
        local et = sub(d.err, tag)
        if not et.GetUnitAuraBySpellID then et.GetUnitAuraBySpellID = tostring(v):sub(1, 160) end
    end
    if st == "P" then
        local flds = sub(d.fields, tag)
        local iid
        for _, fld in ipairs(AP.FIELDS) do
            local okF, fv = pcall(function() return v[fld] end)
            local fcode = okF and code(fv) or "E"
            inc(flds, fld, fcode)
            if fld == "auraInstanceID" and fcode == "C" then iid = fv end
        end
        -- caster GUID for a clear instance ID (needs unit aura access; secret when restricted)
        local gc = Aur.GetAuraCasterGUID
        if iid and type(gc) == "function" then
            local hC, okC, cg = false
            if AG and AG.Call then hC, okC, cg = AG.Call("GetAuraCasterGUID", f, gc, u, iid)
            else okC, cg = pcall(gc, u, iid) end
            inc(d.caster, tag, hC and "held" or (okC and code(cg) or "E"))
        end
    end
    -- change-only tape keyed by (unit name or token, spell)
    local who = name ~= "" and name or u
    local lk = who .. "|" .. sid
    if d.last[lk] ~= st then
        d.last[lk] = st
        -- v2.2.29 smart frequency: an aura present (or derived) on this unit is checked on every visit until it is gone
        if st == "P" or st == "D" then
            local sk = AP.sticky[who]
            if not sk then sk = {} AP.sticky[who] = sk end
            sk[sid] = true
        elseif st == "A" and AP.sticky[who] then
            AP.sticky[who][sid] = nil
        end
        if #d.tape < AP.TAPE_MAX then
            d.tape[#d.tape + 1] = string.format("%.2f|%s|%s|%s|%d|%s|%s", now(), u, name, guid, sid, st, tag)
        else
            d.tapeDropped = d.tapeDropped + 1
        end
    end
end

-- v2.2.29 time-sliced queue: one job per probed unit and visit; items = H all + W / C strided by the visit number (each
-- candidate exactly once per TIER_EVERY visits) + the unit's sticky-present auras
local queue, qHead = {}, 1
AP.pending, AP.visits, AP.lastVisit, AP.sticky, AP.plans = {}, {}, {}, {}, {}
local PH = { "H", "W", "C", "X" }
local function nextSid(job)
    while job.ph <= 4 do
        local t = PH[job.ph]
        local arr = t == "X" and job.extra or job.pl[t]
        local step = AP.TIER_EVERY[t] or 1
        if not job.pos then
            job.pos = step <= 1 and 1 or (step - job.visit % step) % step
            if job.pos == 0 then job.pos = step end
        end
        if job.pos <= #arr then
            local sid = arr[job.pos]
            job.pos = job.pos + step
            return sid
        end
        job.ph, job.pos = job.ph + 1, nil
    end
    return nil
end
function AP.Queued() return #queue - qHead + 1 end
local function schedDB(d)
    d.sched = d.sched or { frames = 0, checks = 0, sumMs = 0, maxMs = 0, maxQueue = 0, maxLag = 0, backlogTicks = 0,
        deferred = 0, unitGone = 0, jobs = 0, maxGap = {}, perTier = {}, every = AP.TIER_EVERY, plans = {} }
    return d.sched
end

-- the 1 s tick only decides WHICH units (exists + is a player: 2 calls per token) and queues them; everything else
-- (name, GUID, class / level -> tier plan, sticky set, slots, detail, health context) runs at the job start in the drain
function AP.Enqueue(d, u, f, tag, restricted)
    local sc = schedDB(d)
    if AP.pending[u] then sc.deferred = sc.deferred + 1 return 0 end   -- still queued: next visit later, nothing dropped
    local v = (AP.visits[u] or 0) + 1
    AP.visits[u] = v
    local t = now()
    local lv = AP.lastVisit[u]
    if lv and t - lv > (sc.maxGap[f] or 0) then sc.maxGap[f] = t - lv end
    AP.lastVisit[u] = t
    local job = { u = u, f = f, tag = tag, restricted = restricted, visit = v, ph = 1, t0 = t }
    queue[#queue + 1] = job
    AP.pending[u] = job
    sc.jobs = sc.jobs + 1
    if AP.Queued() > sc.maxQueue then sc.maxQueue = AP.Queued() end
    return 1
end

function AP.JobStart(d, job)
    local sc = schedDB(d)
    local u = job.u
    if ns.Derive and ns.Derive.UnitKey then pcall(ns.Derive.UnitKey, u) end   -- full name for the exact join
    job.name = unitName(u)
    local okG, guid = pcall(g("UnitGUID") or error, u)
    job.guid = okG and clearStr(guid) or ""
    local okC, _, cls = pcall(g("UnitClass") or error, u)
    local okL, lvl = pcall(g("UnitLevel") or error, u)
    cls = okC and clearStr(cls) or nil
    lvl = okL and clearNum(lvl) or nil
    if lvl and lvl <= 0 then lvl = nil end
    local pl = AP.Plan(cls, lvl)
    sc.plans[pl.key] = (sc.plans[pl.key] or 0) + 1
    if not pl.tier then
        pl.tier = {}
        for _, t in ipairs({ "H", "W", "C" }) do for _, sid in ipairs(pl[t]) do pl.tier[sid] = t end end
        sc.perTier[pl.key] = { H = #pl.H, W = #pl.W, C = #pl.C }
    end
    job.pl = pl
    local extra = {}
    for sid in pairs(AP.sticky[job.name ~= "" and job.name or u] or {}) do
        if pl.tier[sid] ~= "H" then extra[#extra + 1] = sid end
    end
    table.sort(extra)
    job.extra = extra
    AP.UnitWork(d, u, job.f, job.tag, job.restricted, job.name, job.guid)
end

-- drain the queue for budgetMs (math.huge = everything: sync mode / tests); idle time fills rank levels + BigDefensive
function AP.Drain(budgetMs)
    local d = db()
    if not d then return 0 end
    local sc = schedDB(d)
    local Aur = g("C_UnitAuras")
    local fn = type(Aur) == "table" and Aur.GetUnitAuraBySpellID or nil
    local dps = g("debugprofilestop")
    local clock = type(dps) == "function" and dps or nil
    local t0 = clock and clock() or 0
    local tag = ns.EnvTag and ns.EnvTag() or "?"
    local combat = ns.InCombat and ns.InCombat() or false
    local AG = ns.AuraGate
    local checks, cur, fc, restricted = 0, nil, nil, nil
    while qHead <= #queue do
        local job = queue[qHead]
        if cur ~= job then
            cur = job
            -- the token may point at another unit now (target switch) or at nothing: check what is there NOW
            local okE, ex = pcall(g("UnitExists") or error, job.u)
            if not (okE and isTrue(ex)) or type(fn) ~= "function" then
                if type(fn) == "function" then sc.unitGone = sc.unitGone + 1 end
                job.ph = 5
            elseif not job.pl then
                AP.JobStart(d, job)
            else
                local okG, gd = pcall(g("UnitGUID") or error, job.u)
                gd = okG and clearStr(gd) or ""
                if gd ~= job.guid then job.guid, job.name = gd, unitName(job.u) end
            end
            fc = sub(sub(d.codes, tag), job.f)
            restricted = job.restricted or combat
        end
        local sid = job.ph <= 4 and nextSid(job) or nil
        if not sid then
            AP.pending[job.u] = nil
            qHead = qHead + 1        -- no holes: #queue on a table with holes is any border (lost jobs in the sim)
            local lag = now() - job.t0
            if lag > sc.maxLag then sc.maxLag = lag end
            local cj = job.done or 0
            sc.checksPerJob = sc.checksPerJob and (sc.checksPerJob * 0.9 + cj * 0.1) or cj
        else
            AP.Check(d, job, sid, fc, tag, restricted, AG, fn, Aur)
            job.done = (job.done or 0) + 1
            checks = checks + 1
            if clock and checks % AP.CHECK_EVERY == 0 and clock() - t0 >= budgetMs then break end
        end
    end
    if qHead > #queue then queue, qHead = {}, 1 end
    local spent = clock and (clock() - t0) or 0
    if checks >= AP.CHECK_EVERY and spent > 0 then
        local per = spent / checks
        AP.costMs = AP.costMs and (AP.costMs * 0.9 + per * 0.1) or per
    end
    if qHead > #queue and (not clock or clock() - t0 < budgetMs) then
        AP.FillLevels(AP.LEVEL_PER_FRAME)
        pcall(AP.BigDefensive, d, tag, AP.LEVEL_PER_FRAME)
        spent = clock and (clock() - t0) or 0
    end
    if checks > 0 or spent > 0 then
        sc.frames = sc.frames + 1
        sc.checks = sc.checks + checks
        sc.sumMs = sc.sumMs + spent
        if spent > sc.maxMs then sc.maxMs = spent end
    end
    return checks
end

-- worst-case staleness per unit family and tier: TIER_EVERY x the longest gap between two visits of that unit
-- (>= AP.PERIOD) + the longest enqueue -> drained lag
function AP.Staleness(d)
    local sc = d and d.sched
    if not sc then return nil end
    local out = {}
    for f, gap in pairs(sc.maxGap) do
        local gp = math.max(gap, AP.PERIOD)
        out[f] = {}
        for t, every in pairs(AP.TIER_EVERY) do out[f][t] = tonumber(string.format("%.2f", every * gp + sc.maxLag)) end
    end
    sc.worst = out
    return out
end

-- v2.2.29 OnUpdate drain: installed by the 1 s ticker (AP.Wake), runs the tick inside the frame budget, drains the
-- queue, fills rank levels / BigDefensive in idle time, and REMOVES ITSELF when nothing is left (idle frames pay nothing)
local function onDrain(fr, elapsed)
    if not AP.Active() then fr:SetScript("OnUpdate", nil) return end
    local ms = (tonumber(elapsed) or 0.016) * 1000 * AP.WALL_SHARE
    if ms < AP.FRAME_MIN_MS then ms = AP.FRAME_MIN_MS elseif ms > AP.FRAME_MAX_MS then ms = AP.FRAME_MAX_MS end
    -- the 1 s tick runs HERE (the ticker only flags it), so its time comes out of this frame's budget
    if AP.tickDue then
        AP.tickDue = false
        if ns.Perf then ns.Perf.Run("AuraPresence.tick", AP.Tick) else pcall(AP.Tick) end
        ms = ms - (AP.tickMs or 0)
    end
    if ms > 0 then
        if ns.Perf then ns.Perf.Run("AuraPresence.drain", AP.Drain, ms) else pcall(AP.Drain, ms) end
    end
    if not AP.tickDue and AP.Queued() == 0 and not AP.IdleLeft() then fr:SetScript("OnUpdate", nil) AP.awake = false end
end
function AP.Wake()
    local fr = AP.drainFrame
    if fr and fr.SetScript and not AP.awake then
        AP.awake = true
        fr:SetScript("OnUpdate", onDrain)
    end
end
function AP.IdleLeft()
    if AP.LevelsPending() > 0 then return true end
    local d = db()
    local t = d and d.bigDef and d.bigDef[ns.EnvTag and ns.EnvTag() or "?"]
    local Aur = g("C_UnitAuras")
    return type(Aur) == "table" and type(Aur.AuraIsBigDefensive) == "function" and not (t and t.done) or false
end

-- v2.2.29: rotating units per tick follow the budget (more units visited = lower staleness), never below AP.ROTATE:
-- (wall-share ms per period x AP.ROT_FILL) / (measured checks per visit + AP.UNIT_EXTRA calls) x cost - fixed units
function AP.RotateCount(d)
    if not AP.async then return AP.ROTATE end
    local sc = d and d.sched
    local per = AP.costMs or AP.COST_INIT_MS
    if per ~= per or per <= 0 then per = AP.COST_INIT_MS end   -- NaN or <= 0
    local cpv = (sc and sc.jobs > 0 and sc.checksPerJob) or nil
    if not cpv then
        local pl = AP.Plan(nil, nil)
        cpv = #pl.H + #pl.W / AP.TIER_EVERY.W + #pl.C / AP.TIER_EVERY.C
    end
    local n = math.floor(AP.WALL_SHARE * 1000 * AP.PERIOD * AP.ROT_FILL / ((cpv + AP.UNIT_EXTRA) * per)) - #AP.FIXED
    if n < AP.ROTATE then n = AP.ROTATE elseif n > AP.ROTATE_MAX then n = AP.ROTATE_MAX end
    if sc then sc.rotate = n end
    return n
end

-- per-unit non-presence work (slots, unit counter, detail, health context): v2.2.29 runs it at the start of the unit's
-- job inside the drain (sliced), or right away when there is no job / sync mode
function AP.UnitWork(d, u, f, tag, restricted, name, guid)
    local Aur = g("C_UnitAuras")
    if type(Aur) ~= "table" then return end
    local AG = ns.AuraGate
    -- GetAuraSlots(unit, 'HELPFUL|PLAYER'): needs unit aura access
    local gs = Aur.GetAuraSlots
    if type(gs) == "function" then
        local held, ok, a1, a2
        if AG and AG.Call then held, ok, a1, a2 = AG.Call("GetAuraSlots", f, gs, u, "HELPFUL|PLAYER")
        else held, ok, a1, a2 = false, pcall(gs, u, "HELPFUL|PLAYER") end
        inc(sub(d.slots, tag), f, held and "held" or (ok and (code(a1) .. "/" .. code(a2)) or "E"))
        if not held and not ok then
            local et = sub(d.err, tag)
            if not et.GetAuraSlots then et.GetAuraSlots = tostring(a1):sub(1, 160) end
        end
    end
    inc(d.units, tag, f)
    if not restricted then pcall(AP.Detail, d, u, name, guid, tag) end
    pcall(AP.HealthContext, d, u, f, tag, restricted)
end

function AP.ProbeUnit(d, u, tag, restricted)
    local Aur = g("C_UnitAuras")
    if type(Aur) ~= "table" then return 0 end
    local okE, ex = pcall(g("UnitExists") or error, u)
    -- staleness counts gaps only while the unit exists (a nameplate that comes back starts fresh)
    if not (okE and isTrue(ex)) then AP.lastVisit[u] = nil return 0 end
    local okP, isP = pcall(g("UnitIsPlayer") or error, u)
    local f = fam(u)
    if not (okP and isTrue(isP)) and u ~= "target" and u ~= "focus" then AP.lastVisit[u] = nil return 0 end
    if type(Aur.GetUnitAuraBySpellID) == "function" then return AP.Enqueue(d, u, f, tag, restricted), true end
    if ns.Derive and ns.Derive.UnitKey then pcall(ns.Derive.UnitKey, u) end
    local name = unitName(u)
    local okG, guid = pcall(g("UnitGUID") or error, u)
    AP.UnitWork(d, u, f, tag, restricted, name, okG and clearStr(guid) or "")
    return 0, true   -- v2.2.28: second value = an existing unit was probed (the rotation counts units, not calls)
end

-- (c) out of combat: every aura on the unit with stacks / duration / expiration / points (values) / source;
-- change-only per (unit, spell, instance); every clear spellID is learned for the tracked list
function AP.Detail(d, u, name, guid, tag)
    local Aur = g("C_UnitAuras")
    local fn = type(Aur) == "table" and Aur.GetAuraDataByIndex or nil
    if type(fn) ~= "function" then return end
    d.detail = d.detail or {}
    d.detailLast = d.detailLast or {}
    local who = name ~= "" and name or u
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 40 do
            local ok, a = pcall(fn, u, i, filter)
            if not ok or code(a) == "N" or type(a) ~= "table" then break end
            local sid = clearNum(a.spellId)
            if not sid then inc(sub(d, "detailCodes"), tag, "spellId:" .. code(a.spellId)) break end
            local apps, dur, exp = clearNum(a.applications), clearNum(a.duration), clearNum(a.expirationTime)
            local iid = clearNum(a.auraInstanceID)
            local pts = {}
            local okP, P = pcall(function() return a.points end)
            if okP and type(P) == "table" and code(P) ~= "S" then
                for k = 1, 8 do
                    local okV, pv = pcall(function() return P[k] end)
                    if not okV or pv == nil then break end
                    local cv = clearNum(pv)
                    pts[#pts + 1] = cv and tostring(cv) or code(pv)
                end
            end
            local src = clearStr(a.sourceUnit) or ""
            local mine = clearBool(a.isFromPlayerOrPlayerPet)
            local aname = clearStr(a.name)
            AP.Learn(sid, aname, dur, { self = u == "player", own = mine == true })
            local key = who .. "|" .. sid .. "|" .. tostring(iid)
            local sig = string.format("%s|%s|%s|%s", tostring(apps), tostring(dur), exp and string.format("%.1f", exp) or "",
                table.concat(pts, ";"))
            if d.detailLast[key] ~= sig then
                if mine and d.detailLast[key] == nil then AP.PairFromAura(u, sid, aname) end
                d.detailLast[key] = sig
                if #d.detail < AP.DETAIL_MAX then
                    d.detail[#d.detail + 1] = string.format("%.2f|%s|%s|%s|%d|%s|%s|%s|%s|%s|%s|%s",
                        now(), u, name, guid, sid, sig, src, b2s(mine), filter, aname or "", tostring(iid), tag)
                else
                    d.detailDropped = (d.detailDropped or 0) + 1
                end
            end
        end
    end
end

-- (4) health / power readability with the unit's PvP flag, group, friendliness and the restriction vector
function AP.HealthContext(d, u, f, tag, restricted)
    local function call(name, ...)
        local fn = g(name)
        if type(fn) ~= "function" then return "-", nil end
        local ok, v = pcall(fn, ...)
        if not ok then return "E", nil end
        return code(v), v
    end
    local hc = call("UnitHealth", u)
    local pc = call("UnitPower", u)
    local pvpC, pvp = call("UnitIsPVP", u)
    local ffaC, ffa = call("UnitIsPVPFreeForAll", u)
    local _, inP = call("UnitInParty", u)
    local _, inR = call("UnitInRaid", u)
    local _, fr = call("UnitIsFriend", "player", u)
    local _, me = call("UnitIsUnit", u, "player")
    local key = string.format("%s|pvp=%s|ffa=%s|grp=%s|friend=%s|self=%s|restr=%s|%s", f,
        pvpC == "C" and b2s(clearBool(pvp)) or pvpC, ffaC == "C" and b2s(clearBool(ffa)) or ffaC,
        (isTrue(inP) or clearNum(inR)) and "1" or "0", b2s(clearBool(fr)), b2s(clearBool(me)), restricted and "1" or "0",
        restrictionVector())
    local t = sub(sub(d, "hctx"), tag)
    local x = t[key]
    if not x then x = {} t[key] = x end
    x["health:" .. hc] = (x["health:" .. hc] or 0) + 1
    x["power:" .. pc] = (x["power:" .. pc] or 0) + 1
end

-- (d) totems: GetTotemInfo(slot) -> haveTotem, name, startTime, duration, icon, modRate, spellID; coded per env tag
function AP.Totems(d, tag, why, only)
    local fn = g("GetTotemInfo")
    if type(fn) ~= "function" then return end
    d.totems = d.totems or {}
    d.totemCodes = d.totemCodes or {}
    d.totemLast = d.totemLast or {}
    local tc = sub(d.totemCodes, tag)
    for slot = only or 1, only or 4 do
        local r = { pcall(fn, slot) }
        local ok = table.remove(r, 1)
        local codes = {}
        if not ok then codes[1] = "E" else
            for i = 1, 7 do codes[i] = code(r[i]) end
        end
        local cs = table.concat(codes, "")
        inc(tc, why .. ":" .. slot, cs)
        local have = ok and clearBool(r[1])
        local sig = string.format("%s|%s|%s|%s|%s|%s", cs, b2s(have), ok and (clearStr(r[2]) or "") or "",
            ok and (clearNum(r[3]) and string.format("%.1f", r[3]) or "") or "", ok and tostring(clearNum(r[4]) or "") or "",
            ok and tostring(clearNum(r[7]) or "") or "")
        if d.totemLast[slot] ~= sig or why == "event" then
            d.totemLast[slot] = sig
            if #d.totems < AP.TOTEM_MAX then
                d.totems[#d.totems + 1] = string.format("%.2f|%d|%s|%s|%s", now(), slot, why, sig, tag)
            end
        end
    end
end

-- (f) restriction flips per env tag (type:state, combat flag at dispatch)
function AP.OnRestriction(rtype, rstate)
    local d = db()
    if not d then return end
    local tag = ns.EnvTag and ns.EnvTag() or "?"
    local t = code(rtype) == "C" and tostring(rtype) or code(rtype)
    local s = code(rstate) == "C" and tostring(rstate) or code(rstate)
    -- v2.2.29: Combat restriction Activating / Active is dispatched at PLAYER_REGEN_DISABLED BEFORE InCombatLockdown
    -- turns true (run 22: 24 activations stamped ooc) -> counted as combat, and the env tag says combat
    local cmb = ns.CombatAtFlip and ns.CombatAtFlip(rtype, rstate) or (ns.InCombat and ns.InCombat())
    if cmb then tag = tag:gsub("/ooc/", "/combat/") end
    inc(sub(d, "restrict"), tag, t .. ":" .. s .. ":" .. (cmb and "combat" or "ooc"))
end

-- AuraIsBigDefensive(spellID): static per spell; once per env tag
function AP.BigDefensive(d, tag, maxN)
    local Aur = g("C_UnitAuras")
    local fn = type(Aur) == "table" and Aur.AuraIsBigDefensive or nil
    if type(fn) ~= "function" then return end
    local t = sub(d.bigDef, tag)
    if t.done then return end
    local list = AP.List()
    local i, n = t.pos or 1, 0
    -- v2.2.29: in slices (idle frame time), not the whole list in one tick
    while i <= #list and n < (maxN or math.huge) do
        local sid = list[i][1]
        local ok, v = pcall(fn, sid)
        local c = ok and code(v) or "E"
        t[sid] = c == "C" and (v and "true" or "false") or c
        i, n = i + 1, n + 1
    end
    t.pos = i
    if i > #list then t.done, t.pos = true, nil end
end

local rot = 0
function AP.Active()
    return ns.LabActive and ns.LabActive() and ns.db and ns.db.logs and ns.db.logs.on and true or false
end
function AP.Tick()
    local d = db()
    if not d then return end
    local dps = g("debugprofilestop")
    local tk0 = type(dps) == "function" and dps() or nil
    local tag = ns.EnvTag and ns.EnvTag() or "?"
    if not d.anchor then
        -- time audit 2026-10-10: a bare time() is whole seconds, so the run 20 anchor sat up to 1 s early (offline fit
        -- +1.000 s). Core.TimeAnchor refines epochTick/gameTimeTick on the next second edge and adds utcOffset.
        local tf = g("time")
        d.anchor = ns.TimeAnchor and ns.TimeAnchor() or { gameTime = now(), epoch = type(tf) == "function" and tf() or nil }
    end
    d.v = 3
    if AP.LIST and AP.Limit() ~= (d.list and d.list.limit) and #AP.LIST >= (d.list and d.list.limit or 0) then
        AP.listDirty = true   -- the backstop moved and was binding
    end
    -- other modules' stores (OocFill refLearned, Knowledge) grow without telling us: rebuild the list once a minute
    if AP.LIST and now() - (AP.listAt or 0) >= AP.LIST_REFRESH then AP.listDirty = true end
    if not AP.async then AP.BigDefensive(d, tag) end
    local sc = schedDB(d)
    if AP.Queued() > 0 then sc.backlogTicks = sc.backlogTicks + 1 end
    -- is aura access open this tick? the player's own GetAuraSlots must answer clear (it errors when restricted)
    local slotsClear
    local Aur = g("C_UnitAuras")
    if type(Aur) == "table" and type(Aur.GetAuraSlots) == "function" then
        local AG = ns.AuraGate
        local held, ok, a1
        if AG and AG.Call then held, ok, a1 = AG.Call("GetAuraSlots", "player", Aur.GetAuraSlots, "player", "HELPFUL")
        else held, ok, a1 = false, pcall(Aur.GetAuraSlots, "player", "HELPFUL") end
        slotsClear = (not held) and ok and code(a1) ~= "S" or false
    end
    local restricted, why = AP.Restricted(slotsClear)
    inc(sub(d, "restricted"), tag, restricted and ("yes:" .. why) or "no")
    pcall(AP.Totems, d, tag, "tick")
    local done = {}
    for _, u in ipairs(AP.FIXED) do AP.ProbeUnit(d, u, tag, restricted) done[u] = true end
    local tried, probed = 0, 0
    local rotN = AP.RotateCount(d)
    while probed < rotN and tried < #AP.ROT do
        rot = rot + 1
        if rot > #AP.ROT then rot = 1 end
        tried = tried + 1
        local u = AP.ROT[rot]
        -- run 22 bug: counted presence CALLS, so with 0 candidates no unit ever counted and all 89 rotation tokens were
        -- probed every tick (slots + health context per unit: 1.67 ms/tick vs 1.06 in run 19 with 43 spells)
        if not done[u] and select(2, AP.ProbeUnit(d, u, tag, restricted)) then probed = probed + 1 end
    end
    -- no OnUpdate frame (tests / no CreateFrame): drain now, same order and tiers
    if not AP.async then AP.Drain(math.huge) end
    AP.tickMs = tk0 and (dps() - tk0) or 0
end

local ticker, evFrame
local function onEvent(_, event, a1, a2, a3)
    if not AP.Active() then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if a1 == "player" then pcall(AP.OnOwnCast, a3) end
    elseif event == "PLAYER_TOTEM_UPDATE" then
        local d = db()
        local slot = clearNum(a1)
        if d then pcall(AP.Totems, d, ns.EnvTag and ns.EnvTag() or "?", "event", slot) end
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        pcall(AP.OnRestriction, a1, a2)
    elseif event == "UNIT_AURA" then
        pcall(AP.OnUnitAura, a1, a2)
    end
end
function AP.Start()
    local ct = g("C_Timer")
    if not (type(ct) == "table" and type(ct.NewTicker) == "function") then return false end
    if ticker then return true end
    if not AP.Active() then return false end
    local log = g("ForeverDumpLogDB")
    if type(log) == "table" then log.auraPresence = nil end   -- fresh per capture
    local d = db()
    if not d then return false end
    rot = 0
    AP.listDirty, AP.derived = true, {}
    local L0 = AP.List()
    if #L0 == 0 then
        -- (v2.2.28) run 22 ran a whole BG with 0 candidates without anyone noticing
        d.emptyAtStart = string.format("%.2f|%s|learned=%d,ooclearn=%d,knowledge=%d,offline=%d", now(),
            ns.EnvTag and ns.EnvTag() or "?", AP.Count(store("auraLearned")), AP.Count(AP.RefAuraDur()),
            AP.Count(AP.KnowledgeAuras()), AP.Count(AP.OfflineAuras()))
        warn(d, "empty", "0 aura candidates at capture start - presence probe measures nothing (play out of combat "
            .. "first, or keep Data\\LearnedAuras.lua)")
    end
    local cf = g("CreateFrame")
    if not evFrame and type(cf) == "function" then
        local okF, fr = pcall(cf, "Frame")
        if okF and fr then
            evFrame = fr
            fr:SetScript("OnEvent", onEvent)
        end
    end
    if evFrame then
        if not pcall(evFrame.RegisterUnitEvent, evFrame, "UNIT_SPELLCAST_SUCCEEDED", "player") then
            pcall(evFrame.RegisterEvent, evFrame, "UNIT_SPELLCAST_SUCCEEDED")
        end
        pcall(evFrame.RegisterEvent, evFrame, "PLAYER_TOTEM_UPDATE")
        pcall(evFrame.RegisterEvent, evFrame, "ADDON_RESTRICTION_STATE_CHANGED")
        if not pcall(evFrame.RegisterUnitEvent, evFrame, "UNIT_AURA", "player", "target") then
            pcall(evFrame.RegisterEvent, evFrame, "UNIT_AURA")
        end
    end
    -- v2.2.29: the presence checks run in OnUpdate slices (AP.WALL_SHARE of each frame's time)
    if not AP.drainFrame and type(cf) == "function" then
        local okD, df = pcall(cf, "Frame")
        if okD and df then AP.drainFrame = df end
    end
    queue, qHead, AP.pending, AP.visits, AP.lastVisit, AP.sticky = {}, 1, {}, {}, {}, {}
    if AP.drainFrame and AP.drainFrame.SetScript then
        AP.async = true
    end
    ticker = ct.NewTicker(AP.PERIOD, function()
        if not AP.Active() then return end
        if AP.async then AP.tickDue = true AP.Wake() return end
        if ns.Perf then ns.Perf.Run("AuraPresence.tick", AP.Tick) else pcall(AP.Tick) end
    end)
    return true
end
function AP.Stop()
    if ticker and ticker.Cancel then ticker:Cancel() end
    ticker = nil
    if AP.drainFrame and AP.drainFrame.SetScript then AP.drainFrame:SetScript("OnUpdate", nil) end
    AP.async, AP.awake, AP.tickDue = false, false, false
    queue, qHead, AP.pending = {}, 1, {}
    local dS = g("ForeverDumpLogDB") and ForeverDumpLogDB.auraPresence
    if dS then pcall(AP.Staleness, dS) end
    if evFrame and evFrame.UnregisterAllEvents then pcall(evFrame.UnregisterAllEvents, evFrame) end
    local d = g("ForeverDumpLogDB") and ForeverDumpLogDB.auraPresence
    if not d then return nil end
    d.last, d.detailLast, d.totemLast = nil, nil, nil   -- transient (reset next capture)
    return #d.tape
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "aura presence probe (v2.2.26)",
    start = function() return AP.Start() end,
    stop = function()
        local n = AP.Stop()
        return n and string.format("aura presence: %d tape entries", n) or nil
    end }
