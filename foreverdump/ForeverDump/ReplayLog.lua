-- ForeverDump v2.2.6 - capture verbosity, session header, sealed replay tape, cast sync anchors.
-- ONE build: default level = release (<2%, user 2026-10-08). FD_Logs ON elevates to test (or diag if configured) (<=10%);
-- FD_Logs OFF restores the prior level. /fdump level <release|test|diag> is a manual override.
-- v2.2.21 (user decision 2026-10-09): identities are stored RAW - kind:<GUID or name exactly as read>. Nothing is hashed,
-- scrubbed or anonymized. Secret values are never stored (classified first; secret stays recorded as secret).
local _, ns = ...
local R = {}
ns.ReplayLog = R

local GetTime = GetTime
local function g(n) return rawget(_G, n) end
local function now() return (GetTime and GetTime()) or 0 end

-- levels ------------------------------------------------------------------
-- v2.2.15 (user decision 2026-10-09): "lab" = diag + every shadow candidate rule and lab probe. FD_Logs captures use it
-- by default; its frame cost is measured and reported, never gated (only the runaway backstop in Perf.lua acts).
local LEVELS = { release = 1, test = 2, diag = 3, lab = 4 }
R.LEVELS = LEVELS
local cfgDone   -- v2.2.10: the replay config table whose defaults are already filled (cfg() runs on every event)
local function cfg()
    local nc = ns.config
    local c0 = nc and nc.replay
    if c0 ~= nil and c0 == cfgDone then return c0 end
    ns.config = ns.config or {}
    ns.config.replay = ns.config.replay or {}
    local c = ns.config.replay
    cfgDone = c
    if c.level == nil then c.level = "release" end
    if c.captureLevel == nil then c.captureLevel = "lab" end  -- FD_Logs elevates to this (v2.2.15 default lab)
    if c.anchorEveryN == nil then c.anchorEveryN = 8 end       -- release: every Nth own SUCCEEDED
    -- v2.2.10: diag numbers are safety ceilings (runaway backstop, warning once), not data budgets
    if c.byteBudgetKB == nil then c.byteBudgetKB = { release = 512, test = 10240, diag = 4194304, lab = 4194304 } end
    if c.tapeCap == nil then c.tapeCap = { release = 800, test = 68000, diag = 2000000, lab = 2000000 } end
    if c.verifyCap == nil then c.verifyCap = { release = 600, test = 12000, diag = 250000, lab = 250000 } end
    if c.ringCaps == nil then
        c.ringCaps = {
            release = { record = 4000, combat = 10000, signals = 3000 },
            test    = { record = 38000, combat = 85000, signals = 6000 },
            diag    = { record = 2000000, combat = 1000000, signals = 250000, perEventPerSec = 1000 },
            lab     = { record = 2000000, combat = 1000000, signals = 250000, perEventPerSec = 1000 },
        }
    end
    return c
end

local state = {
    level = "release",
    priorLevel = nil,       -- restored after FD_Logs OFF
    priorRings = nil,       -- record/combat/signals caps restored after OFF
    captureElevated = false,
    session = nil,          -- active capture session table (in ForeverDumpLogDB.replay)
    seq = 0,
    castN = 0,
    bytes = 0,
    dropped = {},           -- priority -> count
    ruleIds = {},           -- rule string -> small int
    nextRule = 1,
}

local function levelNum(name) return LEVELS[name] or 1 end
function R.Level() return state.level end
function R.LevelNum() return levelNum(state.level) end
function R.IsTest() return levelNum(state.level) >= 2 end
function R.IsDiag() return levelNum(state.level) >= 3 end
function R.IsLab() return levelNum(state.level) >= 4 end

function R.SyncFromConfig()
    local c = cfg()
    if not state.captureElevated and c.level and LEVELS[c.level] then
        state.level = c.level
    end
    return state.level
end

function R.SetLevel(name, _)
    name = tostring(name or ""):lower()
    if not LEVELS[name] then return false, "unknown level" end
    local prev = state.level
    state.level = name
    cfg().level = name
    if ns.HSMUI and ns.HSMUI.MarkDirty then ns.HSMUI.MarkDirty() end
    return true, prev
end

-- Fast 32-bit mix (Lua 5.1, no bitlib). Used only for seed-table fingerprints (seedHash), never for identities.
local function hash32(str)
    str = tostring(str or "")
    local h = 2166136261
    for i = 1, #str do
        -- h = h XOR byte; then multiply-add mix (avoid 32 XOR bit loops)
        h = h + string.byte(str, i)
        h = (h * 16777619 + (h % 65521) * 31) % 4294967296
    end
    return h
end

-- v2.2.21: identity key = kind .. ":" .. raw value (GUID / full name with realm as given), unmodified.
-- NPC kind additionally collapses Creature/Vehicle GUIDs to the public npc:<id> group key (per-NPC joins); callers that
-- store an NPC identity store the raw GUID next to it (R.RawGuid / field g).
function R.Salt() return nil end   -- v2.2.21: no salt (kept for API compatibility)

function R.IdKey(kind, rawId)
    local id = ns.ClearOf(rawId)   -- v2.2.7: nil/secret never keyed, never compared (classified before any test)
    if id == nil or id == "" then return nil end
    if id == "player" then return "player" end
    kind = tostring(kind or "guid")
    if kind == "npc" and type(id) == "string" then
        -- v2.2.7 (run 6b): Creature-0-<server>-<instance>-<zoneUID>-<npcID>-<spawnUID>; the 6th field is the npc id.
        local nid = id:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or id:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
            or id:match("^npc:(%d+)$")
        if nid then return "npc:" .. nid end
    end
    if type(id) == "string" and id:sub(1, #kind + 1) == kind .. ":" then return id end
    return kind .. ":" .. tostring(id)
end

-- raw clear GUID string (or nil): stored next to derived keys
function R.RawGuid(v)
    local id = ns.ClearOf(v)
    if type(id) == "string" and id ~= "" and id:find("^%a+%-") then return id end
    return nil
end

-- seed hashes (spell ids + numbers only files) ----------------------------
local function seedHash(tbl, tag)
    if type(tbl) ~= "table" then return tag .. ":0" end
    local parts = { tag }
    local n = 0
    local function walk(t, depth)
        if depth > 3 or n > 400 then return end
        for k, v in pairs(t) do
            if type(k) == "number" or (type(k) == "string" and k:sub(1, 1) ~= "_") then
                parts[#parts + 1] = tostring(k)
                if type(v) == "number" then parts[#parts + 1] = tostring(v) n = n + 1
                elseif type(v) == "table" then walk(v, depth + 1) end
                if n > 400 then return end
            end
        end
    end
    walk(tbl, 0)
    return tag .. ":" .. string.format("%08x", hash32(table.concat(parts, ",")))
end

local function groupInfo()
    local gt, size = "solo", 1
    local ig = g("IsInGroup")
    local ir = g("IsInRaid")
    local nm = g("GetNumGroupMembers")
    -- v2.2.7: results are classified before any truth test / compare (run 6b secret-boolean class)
    local okG, inG = pcall(function() if ig then return ig() end end)
    local okR, inR = pcall(function() if ir then return ir() end end)
    local okN, rawN = pcall(function() if nm then return nm() end end)
    if okR and ns.IsTrue(inR) then gt = "raid" elseif okG and ns.IsTrue(inG) then gt = "party" end
    local n = okN and ns.ClearNum(rawN) or nil
    if n and n > 0 then size = n end
    return gt, size
end

R.GroupInfo = groupInfo   -- v2.2.12: Inference group size (dm-frame gating)

local function mapInfo()
    local out = {}
    local gi = g("GetInstanceInfo")
    if type(gi) == "function" then
        local packed = { pcall(gi) }
        local ok = packed[1]
        local typ, instanceId = packed[3], packed[9]
        if ok then
            -- name may be secret / personal — store type + id only
            out.instanceType = ns.ClearStr(typ)
            out.instanceId = ns.ClearNum(instanceId)
        end
    end
    local zm = g("C_Map") and g("C_Map").GetBestMapForUnit
    if type(zm) == "function" then
        local ok, mapId = pcall(zm, "player")
        if ok then out.uiMapId = ns.ClearNum(mapId) end
    end
    return out
end

local function combatLogOn()
    local C = g("C_ChatInfo")
    if type(C) == "table" and type(C.IsLoggingCombat) == "function" then
        local ok, v = pcall(C.IsLoggingCombat)
        if ok then return ns.ClearBool(v) end
    end
    return nil
end

-- DB ----------------------------------------------------------------------
local function db()
    local log = g("ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.replay = type(log.replay) == "table" and log.replay or { v = 1, sessions = {} }
    return log.replay
end

-- Keep decide/verdict/anchor for the whole session when possible.
-- Reconcile is KEEP via decide (rule dm-reconcile) + verdict (dm-*/dm-unit-*); shadow findings are verdicts.
-- High-rate rows drop first: ws (world-capture) > sec/api > map/dm/sig. Counted in session.dropped / overflow.
local PRI = { hdr = 0, overflow = 0, decide = 1, verdict = 1, anchor = 2, sig = 3, map = 4, dm = 4, ws = 5, sec = 5, api = 6 }
local KEEP_PRI = 2

local function budgetKB()
    local b = cfg().byteBudgetKB
    return (b and (b[state.level] or (state.level == "lab" and b.diag))) or 512
end

local function tapeCap()
    local t = cfg().tapeCap
    return math.max(1, tonumber(t and (t[state.level] or (state.level == "lab" and t.diag))) or 800)   -- v2.2.13: never % 0
end

function R.VerifyCap()
    local t = cfg().verifyCap
    return (t and (t[state.level] or (state.level == "lab" and t.diag))) or 600
end

local function estimateBytes(rec)
    -- rough: 8 bytes/number field, 2 per short string key — avoid formatting
    local n = 24
    for _ in pairs(rec) do n = n + 12 end
    return n
end

local function append(kind, rec)
    local s = state.session
    if not s then return nil end
    local cap = tapeCap()
    local ring = s.tape
    if not ring then return nil end
    -- byte budget: drop lower-priority kinds first
    local est = estimateBytes(rec)
    local lim = budgetKB() * 1024
    if state.bytes + est > lim then
        local p = PRI[kind] or 9
        if p >= 3 then
            s.dropped = s.dropped or {}
            s.dropped[kind] = (s.dropped[kind] or 0) + 1
            s.overflow = (s.overflow or 0) + 1
            R.CeilingWarn("tape bytes", budgetKB() .. " KB")
            return nil
        end
    end
    local pNew = PRI[kind] or 9
    state.seq = state.seq + 1
    rec.k = kind
    rec.i = state.seq
    rec.d = math.floor((now() - (s.t0 or now())) * 1000 + 0.5)  -- ms since session start
    local head = (s.head or 0) % cap + 1
    local old = ring[head]
    if old then
        R.CeilingWarn("tape", cap)
        local pOld = PRI[old.k] or 9
        -- low-value must not erase a keeper; drop the new row (counted overflow)
        if pNew > KEEP_PRI and pOld <= KEEP_PRI then
            s.dropped = s.dropped or {}
            s.dropped[kind] = (s.dropped[kind] or 0) + 1
            s.overflow = (s.overflow or 0) + 1
            state.seq = state.seq - 1
            return nil
        end
        -- inserting a keeper onto a keeper slot: prefer overwriting a low-pri slot instead
        if pNew <= KEEP_PRI and pOld <= KEEP_PRI and (s.n or 0) >= cap then
            local found
            for i = 1, math.min(cap, 256) do
                local j = (head + i - 1) % cap + 1
                local e = ring[j]
                if e and (PRI[e.k] or 9) > KEEP_PRI then found = j break end
            end
            if found then head = found
            else s.keeperOverwrites = (s.keeperOverwrites or 0) + 1 end
        end
        s.overwritten = (s.overwritten or 0) + 1
    end
    s.head = (s.head or 0) % cap + 1
    ring[head] = rec
    if (s.n or 0) < cap then s.n = (s.n or 0) + 1 end
    state.bytes = state.bytes + est
    s.bytes = state.bytes
    return rec.i
end

function R.RuleId(rule)
    if type(rule) ~= "string" then return 0 end
    local id = state.ruleIds[rule]
    if id then return id end
    id = state.nextRule
    state.nextRule = id + 1
    state.ruleIds[rule] = id
    local s = state.session
    if s then
        s.rules = s.rules or {}
        s.rules[id] = rule
    end
    return id
end

-- session lifecycle -------------------------------------------------------
-- Lazy: rings allocate slots only as events arrive; ApplyRingCaps only raises the max.
function R.ApplyRingCaps(levelName)
    local c = cfg()
    local rc = (c.ringCaps and (c.ringCaps[levelName] or (levelName == "lab" and c.ringCaps.diag))) or (c.ringCaps and c.ringCaps.release) or {}
    ns.config.record = ns.config.record or {}
    ns.config.cl = ns.config.cl or {}
    ns.config.hsm = ns.config.hsm or {}
    if not state.priorRings then
        state.priorRings = {
            record = ns.config.record.maxEvents,
            combat = ns.config.cl.maxEvents,
            signals = ns.config.hsm.maxSignals,
            perEventPerSec = ns.config.record.perEventPerSec,
        }
    end
    if rc.record then ns.config.record.maxEvents = rc.record end
    if rc.combat then ns.config.cl.maxEvents = rc.combat end
    if rc.signals then ns.config.hsm.maxSignals = rc.signals end
    if rc.perEventPerSec then ns.config.record.perEventPerSec = rc.perEventPerSec end
    return rc
end

function R.RestoreRingCaps()
    local pr = state.priorRings
    if not pr then return end
    if ns.config.record and pr.record ~= nil then ns.config.record.maxEvents = pr.record end
    if ns.config.cl and pr.combat ~= nil then ns.config.cl.maxEvents = pr.combat end
    if ns.config.hsm and pr.signals ~= nil then ns.config.hsm.maxSignals = pr.signals end
    if ns.config.record and pr.perEventPerSec ~= nil then ns.config.record.perEventPerSec = pr.perEventPerSec end
    state.priorRings = nil
end

function R.ElevateForCapture()
    R.SyncFromConfig()
    local c = cfg()
    if not state.captureElevated then
        state.priorLevel = state.level
        local elev = c.captureLevel or "diag"
        if levelNum(elev) < 2 then elev = "test" end
        state.level = elev
        state.captureElevated = true
        cfg().level = elev
        R.ApplyRingCaps(elev)
    end
    return state.level
end

function R.BeginCapture()
    R.SyncFromConfig()
    local c = cfg()
    -- elevate from release to captureLevel (diag by default since v2.2.9)
    if not state.captureElevated then
        state.priorLevel = state.level
        local elev = c.captureLevel or "diag"
        if levelNum(elev) < 2 then elev = "test" end
        state.level = elev
        state.captureElevated = true
        R.ApplyRingCaps(elev)
    elseif not state.priorRings then
        R.ApplyRingCaps(state.level)
    end
    local store = db()
    if not store then return nil end
    state.seq, state.castN, state.bytes = 0, 0, 0
    state.ceilWarned = {}
    state.rle = ns.RLE and ns.RLE.New() or nil
    state.ruleIds, state.nextRule = {}, 1
    local gt, gsz = groupInfo()
    local map = mapInfo()
    local hdr = {
        v = 1,
        addonVersion = ns.VERSION,
        schemaVersion = ns.SCHEMA,
        verbosity = state.level,
        captureElevated = true,
        priorLevel = state.priorLevel,
        identity = "raw",   -- v2.2.21: GUIDs / names stored as read (kind:<raw>)
        seeds = {
            spellTiming = seedHash(ns.SpellTimingSeed, "st"),
            learned = seedHash(ns.LearnedSeed, "ln"),
            knowledgePatch = seedHash(ns.KnowledgePatch, "kp"),
        },
        groupType = gt,
        groupSize = gsz,
        mapStart = map,
        combatLogStart = combatLogOn(),
        ringCaps = {
            record = (ns.config.record and ns.config.record.maxEvents) or 4000,
            combat = (ns.config.cl and ns.config.cl.maxEvents) or 10000,
            signals = (ns.config.hsm and ns.config.hsm.maxSignals) or 3000,
            tape = tapeCap(),
            verify = R.VerifyCap(),
        },
        byteBudgetKB = budgetKB(),
        t0 = now(),
        sid = ns.SessionId and ns.SessionId() or nil,
        anchor = ns.TimeAnchor and ns.TimeAnchor() or nil,
        build = ns.Build and ns.Build() or nil,
    }
    local sess = {
        hdr = hdr,
        tape = {},
        head = 0,
        n = 0,
        overwritten = 0,
        overflow = 0,
        dropped = {},
        anchors = {},
        t0 = hdr.t0,
        rules = {},
    }
    state.session = sess
    store.current = sess
    append("hdr", { verbosity = state.level, groupType = gt, groupSize = gsz })
    if ns.Inference and ns.Inference.hs then ns.Inference.hs.shadowFindings = R.IsTest() or nil end
    if ns.HSMUI and ns.HSMUI.MarkDirty then ns.HSMUI.MarkDirty() end
    return sess
end

-- rough SavedVariables serialize proxy: count tape rows + estimate (no full AceSerializer; O(n) numbers only)
function R.SerializeProxy(sess)
    local s = sess or state.session
    if not s then return nil end
    local t0 = (type(debugprofilestop) == "function" and debugprofilestop()) or (now() * 1000)
    local n, keepers, ws, dm, decide, verdict, anchor = s.n or 0, 0, 0, 0, 0, 0, 0
    local ring = s.tape or {}
    local packed = 0
    for _, e in pairs(ring) do
        if type(e) == "table" then
            local k = e.k
            packed = packed + 1
            if k == "decide" then decide = decide + 1 keepers = keepers + 1
            elseif k == "verdict" then verdict = verdict + 1 keepers = keepers + 1
            elseif k == "anchor" or k == "hdr" then anchor = anchor + 1 keepers = keepers + 1
            elseif k == "ws" then ws = ws + 1
            elseif k == "dm" then dm = dm + 1 end
        end
    end
    local est = (s.bytes or state.bytes or 0) + packed * 24
    local dur = 0
    if s.t0 then dur = math.max(0.001, now() - s.t0) end
    local t1 = (type(debugprofilestop) == "function" and debugprofilestop()) or (now() * 1000)
    return {
        rows = n, packed = packed, keepers = keepers, decide = decide, verdict = verdict, anchor = anchor,
        ws = ws, dm = dm, estBytes = est, durSec = dur,
        mbPerMin = dur > 0 and (est / 1048576) / (dur / 60) or 0,   -- v2.2.13: no t0 -> dur 0 (client raises on /0)
        serializeMs = math.floor((t1 - t0) * 100 + 0.5) / 100,
        dropped = s.dropped, overflow = s.overflow, overwritten = s.overwritten,
    }
end

-- v2.2.8: engine + guard counters at OFF (numbers / short module names only; no names, GUIDs or payloads). Runs 6/6b
-- could not show from the SV whether the HSM ran or whether the combat guard skipped anything.
function R.CollectStats(sid)
    local out = { v = 1 }
    local I = ns.Inference
    local h = I and I.health
    out.hsm = (type(h) == "table" and h.state) or "off"
    if type(h) == "table" and type(h.failed) == "table" and next(h.failed) then
        out.hsmFailed = {}
        for k in pairs(h.failed) do out.hsmFailed[#out.hsmFailed + 1] = k end
        table.sort(out.hsmFailed)
    end
    out.hsmRunning = (I and I.running) and true or false
    local hs = I and I.hs
    if type(hs) == "table" and type(hs.counters) == "table" then
        out.counters = {}
        for k, v in pairs(hs.counters) do
            if type(k) == "string" and type(v) == "number" then out.counters[k] = v end
        end
    end
    local guard = {}
    local T = ns.Tokens and ns.Tokens.Scan
    local cur = T and T.cur
    if type(cur) == "table" then guard.tokenScan = tonumber(cur.guardSkips) or 0 end
    local W = ns.WorldCapture
    if W and W.Stats then
        local ws   -- WorldCapture's own counters, assigned inside the closure
        local okW = pcall(function() ws = W.Stats() end)
        if okW and type(ws) == "table" then
            guard.worldCapture = tonumber(ws.guardSkips) or 0
            out.worldCapture = { samples = ws.samples, slices = ws.slices, dropped = ws.dropped }
        end
    end
    out.guard = guard
    local n = 0
    local L = rawget(_G, "ForeverDumpLogDB")
    for _, e in ipairs((type(L) == "table" and type(L.selfErrors) == "table") and L.selfErrors or {}) do
        if type(e) == "table" and e.sid == sid then n = n + 1 end
    end
    out.selfErrors = n
    return out
end

function R.EndCapture()
    local s = state.session
    if s and s.hdr then
        local sid, collected = s.hdr.sid, nil
        local okS, err = pcall(function() collected = R.CollectStats(sid) end)
        if okS and type(collected) == "table" then
            s.hdr.stats = collected
        else
            s.hdr.stats = { v = 1, err = string.sub(tostring(err or "no stats"), 1, 120) }
        end
        s.hdr.mapEnd = mapInfo()
        s.hdr.combatLogEnd = combatLogOn()
        s.hdr.verbosityEnd = state.level
        s.hdr.groupTypeEnd, s.hdr.groupSizeEnd = groupInfo()
        s.bytes = state.bytes
        s.seqEnd = state.seq
        s.rle = ns.RLE and ns.RLE.Summary(state.rle) or nil   -- v2.2.10 dm run-length rows (lossless)
        state.rle = nil
        s.serialize = R.SerializeProxy(s)
        local store = db()
        if store then
            store.sessions = store.sessions or {}
            store.sessions[#store.sessions + 1] = s
            while #store.sessions > 4 do table.remove(store.sessions, 1) end
            store.current = nil
        end
    end
    state.session = nil
    -- restore prior level + ring caps so normal play / release stay small
    local restore = state.priorLevel or "release"
    state.captureElevated = false
    state.priorLevel = nil
    state.level = restore
    cfg().level = restore
    R.RestoreRingCaps()
    if ns.HSMUI and ns.HSMUI.MarkDirty then ns.HSMUI.MarkDirty() end
    return s
end

-- ring overflow helper (shared) -------------------------------------------
-- v2.2.10: at diag every cap is a safety ceiling; reaching one means a runaway loop or an extreme session. Warn once
-- per ring per capture (chat line + session.ceilingHit) - rows then overwrite oldest-first instead of growing forever.
function R.CeilingWarn(ringName, cap)
    if not R.IsDiag() then return end
    state.ceilWarned = state.ceilWarned or {}
    if state.ceilWarned[ringName] then return end
    state.ceilWarned[ringName] = true
    local s = state.session
    if s then s.ceilingHit = s.ceilingHit or {} s.ceilingHit[ringName] = cap or true end
    if ns.Print then
        ns.Print(string.format("|cffff8800ForeverDump: %s reached its safety ceiling (%s rows)|r - runaway loop? Oldest rows are "
            .. "overwritten from now on. Please report this capture.", tostring(ringName), tostring(cap or "?")))
    end
end

function R.NoteOverflow(ringName, n, cap)
    local s = state.session
    if not s then return end
    s.ringOverflow = s.ringOverflow or {}
    s.ringOverflow[ringName] = (s.ringOverflow[ringName] or 0) + (n or 1)
    R.CeilingWarn(ringName, cap)
end

-- cast sync anchors -------------------------------------------------------
function R.OnOwnSucceeded(spellId, unit)
    if type(spellId) ~= "number" then return end
    if unit and unit ~= "player" then return end
    state.castN = state.castN + 1
    local every = math.max(1, tonumber(cfg().anchorEveryN) or 8)
    local take = R.IsTest() or (state.castN % every == 1)
    if not take then return end
    local rec = { spell = spellId, n = state.castN }
    local id = append("anchor", rec)
    local s = state.session
    if s and id then
        s.anchors[#s.anchors + 1] = { i = id, spell = spellId, d = rec.d, t = now() }
    end
end

-- decide / verdict tape ---------------------------------------------------
-- input bitmap bits: 1 cast 2 aura 3 combat 4 meter 5 ledgerToken 6 ledgerAura 7 cd 8 knowledge
function R.OnInfer(rec)
    if not state.session then return end
    local bits = 0
    local rule = rec.rule or "?"
    if rule:find("cast", 1, true) or rule == "own-cast-frame" then bits = bits + 1 end
    if rule:find("aura", 1, true) or rule == "observed" or rule:find("applier", 1, true) then bits = bits + 2 end
    if rule:find("combat", 1, true) or rule == "elimination" then bits = bits + 4 end
    if rule:find("meter", 1, true) or rule:find("dm", 1, true) then bits = bits + 8 end
    if rule:find("ledger", 1, true) then bits = bits + 16 end
    if rule == "ledger" or rule == "ledger-elimination" then bits = bits + 32 end
    if rule:find("cd", 1, true) or rule:find("cooldown", 1, true) or rule:find("gcd", 1, true) then bits = bits + 64 end
    if rec.known or rule:find("knowledge", 1, true) or rule:find("single-applier", 1, true) then bits = bits + 128 end
    local conf = rec.conf
    local confN = (conf == "observed" and 4) or (conf == "high" and 3) or (conf == "medium" and 2) or (conf == "low" and 1) or 0
    append("decide", {
        id = rec.id,
        r = R.RuleId(rule),
        c = confN,
        b = bits,
        u = type(rec.unit) == "string" and (rec.unit == "player" and "player" or R.IdKey("guid", rec.unit)) or nil,
        sp = type(rec.spell) == "number" and rec.spell or nil,
        kind = rec.kind,
    })
end

function R.OnVerdict(rec)
    if not state.session then return end
    append("verdict", {
        kind = rec.kind,
        v = rec.v,
        sp = type(rec.spell) == "number" and rec.spell or nil,
        src = type(rec.src) == "string" and rec.src:sub(1, 40) or nil,
        cf = rec.conf,
        -- link to last decide id when present
        id = rec.id,
    })
end

-- test-only extras --------------------------------------------------------
local CRITICAL = {
    UNIT_SPELLCAST_SUCCEEDED = true, UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_SENT = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_STOP = true,
    UNIT_COMBAT = true, SPELL_UPDATE_COOLDOWN = true,
    DAMAGE_METER_COMBAT_SESSION_UPDATED = true, UNIT_AURA = true,
}

local SEC_CODE = { N = 0, S = 1, T = 2, K = 3, C = 4 }
-- states: array of ClassifyValue codes; nStates (v2.2.10, optional): how many are valid when the caller passes a reused
-- buffer (Recorder hands over the live observer's codes without copying). Same packed value as before.
function R.OnCriticalEvent(event, _args, states, nStates)
    if not R.IsTest() or not state.session then return end
    if not CRITICAL[event] then return end
    -- pack up to 8 arg states into one integer (4 bits each): 0=N 1=S 2=T 3=K 4=C 5=?
    local cnt = type(states) == "table" and (tonumber(nStates) or #states) or 0
    local pack, n, mul = 0, math.min(cnt, 8), 1
    for i = 1, n do
        local c = SEC_CODE[states[i] or "?"] or 5
        pack = pack + c * mul
        mul = mul * 16
    end
    append("sec", { e = event, n = n, p = pack })
end

function R.OnApiSample(apiId, spellId, states, clearVals)
    if not R.IsTest() or not state.session then return end
    append("api", {
        a = apiId,
        sp = spellId,
        st = states,  -- small array of state letters or packed
        -- clearVals: numbers only
        v = clearVals,
    })
end

function R.OnMapDelta(tok, idKey, how, guidStr)
    if not R.IsTest() or not state.session then return end
    -- tok family (player/target/nameplateN) for grouping; v2.2.21 also the exact token (tk) and raw GUID (g)
    local fam = tok
    if type(tok) == "string" then
        fam = tok:gsub("%d+$", "N")
    end
    append("map", { tok = fam, tk = tok, id = idKey, how = how, g = R.RawGuid(guidStr) })   -- v2.2.21 raw GUID
end

function R.OnDmUpdate(ty, sessionId, states)
    if not R.IsTest() or not state.session then return end
    -- v2.2.10: identical consecutive-or-not dm rows fold losslessly into one run row (rc, q, dt ms, dq seq deltas)
    local s, RLE = state.session, ns.RLE
    local stTab, stN = nil, 0
    if type(states) == "table" then stTab, stN = states, #states end
    local key = RLE and RLE.Key("dm", nil, stTab, stN)
    key = key and (tostring(ty) .. "|" .. tostring(sessionId) .. "|" .. key)
    if key and s.tape then
        local seq = state.seq + 1
        local d = math.floor((now() - (s.t0 or now())) * 1000 + 0.5)
        if RLE.Fold(state.rle, key, d, seq, s.tape) then
            state.seq = seq
            return
        end
        local i = append("dm", { ty = ty, sid = sessionId, st = states })
        local row = i and s.tape[s.head]
        if row and row.i == i then RLE.Open(state.rle, key, row, s.head, row.d, i) end
        return
    end
    append("dm", { ty = ty, sid = sessionId, st = states })
end

-- v2.2.6: world-state sample (codes packed; IdKeys only; clear numbers only). Droppable under budget (PRI ws=5).
function R.OnWorldSample(rec)
    if not R.IsTest() or not state.session then return nil end
    if type(rec) ~= "table" then return nil end
    return append("ws", rec)
end

function R.StatusLine()
    local elev = state.captureElevated and " (capture)" or ""
    return "log:" .. state.level .. elev
end

function R.Command(rest)
    R.SyncFromConfig()
    rest = tostring(rest or ""):match("^%s*(.-)%s*$") or ""
    local sub, arg = rest:match("^(%S+)%s*(.*)$")
    sub = sub and sub:lower() or "status"
    if sub == "status" or sub == "" then
        ns.Print(string.format("replay verbosity: %s%s; tape seq=%d bytes≈%d budget=%dKB; captureElevated=%s",
            state.level, state.captureElevated and " (FD_Logs capture)" or "",
            state.seq, state.bytes, budgetKB(), tostring(state.captureElevated)))
        return
    end
    if sub == "release" or sub == "test" or sub == "diag" or sub == "lab" then
        if state.captureElevated then
            ns.Print("FD_Logs capture is active — level is pinned to capture mode (" .. state.level .. "). Stop capture first, or set captureLevel.")
            return
        end
        local ok, prev = R.SetLevel(sub, "cmd")
        if ok then ns.Print("verbosity " .. tostring(prev) .. " -> " .. sub .. " (manual override; FD_Logs will still elevate on next capture)") end
        return
    end
    if sub == "capturelevel" and arg ~= "" then
        local a = arg:lower()
        if LEVELS[a] and LEVELS[a] >= 2 then
            cfg().captureLevel = a
            ns.Print("FD_Logs capture will elevate to " .. a)
        else
            ns.Print("captureLevel must be test, diag or lab")
        end
        return
    end
    ns.Print("usage: /fdump level [status|release|test|diag|lab|capturelevel test|diag|lab]")
end

-- wire capture module -----------------------------------------------------
ns.captureModules = ns.captureModules or {}
-- Start before HSM/Inference so IsTest() is true when NewHSM enables shadow findings
table.insert(ns.captureModules, math.min(2, #ns.captureModules + 1), {
    name = "replay log (session_hdr + tape)",
    start = function()
        R.BeginCapture()
        if ns.Inference and ns.Inference.hs then ns.Inference.hs.shadowFindings = true end
        return true
    end,
    stop = function()
        local s = R.EndCapture()
        if not s then return nil end
        if ns.Inference and ns.Inference.hs then ns.Inference.hs.shadowFindings = false end
        return string.format("replay tape %s: %d records, %d overwritten, %d overflow-drops, ~%d bytes",
            (s.hdr and s.hdr.verbosity) or "?", s.n or 0, s.overwritten or 0, s.overflow or 0, s.bytes or 0)
    end,
})

return R
