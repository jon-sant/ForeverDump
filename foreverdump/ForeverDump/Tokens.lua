-- ForeverDump v2.2 - unit token survey. Once per capture context (ooc / combat / restricted / enc) per FD_Logs capture:
-- for every token family (player, target, focus, mouseover, pet, vehicle, npc, softenemy/softfriend/softinteract,
-- party1-4, partypet1-4, raid1-40, raidpet1-40, arena1-5, boss1-8, nameplate1-40, and compound chains) the five-state
-- code of UnitExists, UnitGUID, UnitName, UnitIsUnit(t,'player'), UnitIsUnit(t,'target'), UnitCanAttack, UnitIsPlayer,
-- UnitHealth, UnitHealthMax, C_Secrets.CanCompareUnitTokens, C_Secrets.ShouldUnitIdentityBeSecret, and whether the
-- token resolved (existing unit). Stored aggregated PER FAMILY (counts per code, split by existing / not existing).
local _, ns = ...
local T = {}
ns.Tokens = T

local function fn(path) local f = ns.Resolve(path) if type(f) ~= "function" then return nil end return f end
local function code(v) return ns.ClassifyValue(v) end

local FAMILIES = {
    { "player", { "player" } }, { "target", { "target" } }, { "focus", { "focus" } }, { "mouseover", { "mouseover" } },
    { "pet", { "pet" } }, { "vehicle", { "vehicle" } }, { "npc", { "npc" } },
    { "softenemy", { "softenemy" } }, { "softfriend", { "softfriend" } }, { "softinteract", { "softinteract" } },
    { "party", "party", 4 }, { "partypet", "partypet", 4 }, { "raid", "raid", 40 }, { "raidpet", "raidpet", 40 },
    { "arena", "arena", 5 }, { "boss", "boss", 8 }, { "nameplate", "nameplate", 40 },
    { "targettarget", { "targettarget" } }, { "targettargettarget", { "targettargettarget" } }, { "focustarget", { "focustarget" } },
    { "focustargettarget", { "focustargettarget" } }, { "party1target", { "party1target" } }, { "raid1target", { "raid1target" } },
    { "arena1target", { "arena1target" } }, { "pettarget", { "pettarget" } }, { "mouseovertarget", { "mouseovertarget" } },
}
T.FAMILIES = FAMILIES

local CHECKS = {
    { "UnitExists", "UnitExists", function(t) return t end },
    { "UnitGUID", "UnitGUID", function(t) return t end },
    { "UnitName", "UnitName", function(t) return t end },
    { "UnitIsUnit(player)", "UnitIsUnit", function(t) return t, "player" end },
    { "UnitIsUnit(target)", "UnitIsUnit", function(t) return t, "target" end },
    { "UnitCanAttack", "UnitCanAttack", function(t) return "player", t end },
    { "UnitIsPlayer", "UnitIsPlayer", function(t) return t end },
    { "UnitHealth", "UnitHealth", function(t) return t end },
    { "UnitHealthMax", "UnitHealthMax", function(t) return t end },
    { "CanCompareUnitTokens", "C_Secrets.CanCompareUnitTokens", function(t) return t, "player" end },
    { "ShouldUnitIdentityBeSecret", "C_Secrets.ShouldUnitIdentityBeSecret", function(t) return t end },
}
T.CHECKS = CHECKS

local function tokens(fam)
    if type(fam[2]) == "table" then return fam[2] end
    local out = {}
    for i = 1, fam[3] do out[#out + 1] = fam[2] .. i end
    return out
end

local function db()
    local log = rawget(_G, "ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    log.tokens = log.tokens or { v = 1, ctx = {}, absent = {} }
    return log.tokens
end
T.DB = db

local function docOK(path)
    local docs = rawget(_G, "ForeverDumpDocsDB")
    if type(docs) ~= "table" or type(docs.systems) ~= "table" or #docs.systems == 0 then return true end
    return ns.Secrets and ns.Secrets.DocRow and ns.Secrets.DocRow("api:" .. path) ~= nil
end

-- one survey for the current context; skipped when this capture already surveyed it (force = re-run)
function T.Survey(reason, force)
    if ns.SelfThrottled and ns.SelfThrottled() then return nil end
    -- v2.2.4: in combat the budgeted discovery scanner (T.Scan) covers every family; the one-shot survey stays out of combat
    if ns.InCombat() and not force and not (ns.config.tokenscan and ns.config.tokenscan.enabled == false) then return nil end
    local d = db()
    if not d then return nil end
    local ctx = ns.CombatProbe and ns.CombatProbe.Context() or (ns.InCombat() and "combat" or "ooc")
    local sid = ns.db and ns.db.logs and ns.db.logs.session and ns.db.logs.session.sid
    d.done = d.done or {}
    if not force and d.done[ctx] and d.done[ctx] == sid then return nil end
    d.done[ctx] = sid
    local fns = {}
    for _, c in ipairs(CHECKS) do
        local f = fn(c[2])
        if f and docOK(c[2]) then fns[c[1]] = f else d.absent[c[1]] = f and "undocumented" or "runtime" end
    end
    local out = { reason = reason, families = {} }
    for _, fam in ipairs(FAMILIES) do
        local r = { tokens = 0, exist = 0, notExist = 0, existSecret = 0, errors = 0, checks = {} }
        for _, tok in ipairs(tokens(fam)) do
            r.tokens = r.tokens + 1
            local okE, ex = pcall(fns.UnitExists or function() return nil end, tok)
            local split
            if not okE then r.errors = r.errors + 1 split = "err"
            elseif ns.IsSecret(ex) then r.existSecret = r.existSecret + 1 split = "exist?"
            elseif ns.IsTrue(ex) then r.exist = r.exist + 1 split = "exist"
            else r.notExist = r.notExist + 1 split = "none" end
            -- non-existent tokens: sample only the first index per family (they all behave alike)
            if split ~= "none" or r.notExist == 1 then
                for _, c in ipairs(CHECKS) do
                    local f = fns[c[1]]
                    if f then
                        if ns.ProbeMark then ns.ProbeMark("Tokens", tostring(c[2] or c[1]), tok) end
                        local res = ns.Pack(pcall(f, c[3](tok)))
                        if ns.ProbeDone then ns.ProbeDone() end
                        local st = res[1] and code(res[2]) or "E"
                        r.checks[c[1]] = r.checks[c[1]] or {}
                        local b = r.checks[c[1]]
                        b[split] = b[split] or {}
                        b[split][st] = (b[split][st] or 0) + 1
                    end
                end
            end
        end
        out.families[fam[1]] = r
    end
    ns.Stamp(out)
    d.ctx[ctx] = out
    return out
end

local frame
function T.Start()
    if ns.config.tokens and ns.config.tokens.enabled == false then return false end
    local d = db()
    if d then d.done = {} end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function()
            local after = rawget(_G, "C_Timer") and C_Timer.After
            local run = function() local ok, err = pcall(T.Survey, "event") if not ok then ns.NoteSelfError("Tokens.Survey", err) end end
            if after then after(1.5, run) else run() end
        end)
    end
    for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "ADDON_RESTRICTION_STATE_CHANGED", "ENCOUNTER_START" }) do
        pcall(frame.RegisterEvent, frame, ev)
    end
    pcall(T.Survey, "capture:on")
    return true
end
function T.Stop()
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    local d = db()
    local n = 0
    for _ in pairs((d and d.ctx) or {}) do n = n + 1 end
    return n
end


----------------------------------------------------------------------------- v2.2.4 group-aware discovery scanner
-- Broad first version (prune later from dungeon / BG evidence): EVERY token family is scanned round-robin on a C_Timer
-- ticker (never OnUpdate) under a hard per-slice TIME budget (debugprofilestop; default 0.12 ms per 0.1 s slice = at most
-- 1.2 ms per second = 0.12% of frame time, far under the 1% rule). Priority tokens jump the queue on group / target /
-- focus / mouseover / nameplate / UNIT_TARGET events. Per token: UnitExists, then (existing tokens) GUID / name / class /
-- level / health / power / player / reaction / attackable / is-me / is-target / dead / combat / identity-secret codes,
-- aggregated per context key "ctx|instanceType|group" x family (digits -> N) x field x code. Token -> GUID map with
-- timestamps lives in memory only (deduped across tokens); a secret GUID is resolved by alias learning from a cast seen
-- at the same instant on a token whose GUID is clear (castGUID when clear, else same-frame same-event unique match).
-- SV: ForeverDumpDB.tokenscan[build] = { m (matrix), cost (per capture), dup (family pairs), alias, baseline }.
-- Codes, counts, family names only: no GUIDs, no names. Every capture re-verifies the matrix against the stored baseline
-- (change alerts -> Drift changelog + Verify.Unexpected). Scan cost per capture is logged for later trimming.
local S = {}
T.Scan = S
local function g(n) return rawget(_G, n) end
local function scfg() return (ns.config and ns.config.tokenscan) or {} end
local pclockF
local pclock = function()
    if pclockF == nil then pclockF = g("debugprofilestop") or false end
    return pclockF and pclockF() or os.clock() * 1000
end

local function sdb()
    local sv = ns.db
    if type(sv) ~= "table" then return nil end
    sv.tokenscan = type(sv.tokenscan) == "table" and sv.tokenscan or {}
    local b = ns.Build and ns.Build() or "?"
    local d = sv.tokenscan[b]
    if type(d) ~= "table" then d = { v = 1, m = {}, cost = {}, dup = {}, alias = {}, baseline = nil } sv.tokenscan[b] = d end
    return d
end
S.DB = sdb

local famCache, famN = {}, 0   -- token -> family (no gsub string churn per read; bounded: the token list is ~420)
local function family(tok)
    local f = famCache[tok]
    if f then return f end
    f = tok:gsub("%d+", "N")
    famN = famN + 1
    if famN > 1024 then famCache, famN = {}, 0 end
    famCache[tok] = f
    return f
end
S.Family = family

-- group context, detected (never assumed): BGs are usually raid units, arenas use arenaN
function S.Context()
    local function call(name, ...) local f = g(name) if type(f) ~= "function" then return nil end local ok, a, b = pcall(f, ...) if ok then return a, b end end
    -- v2.2.7: every return is cleared before use (was `raid == true`, `v == true`, `type(n) == "number" and n or 0`)
    local _, rawType = call("IsInInstance")
    local itype = ns.ClearStr(rawType)
    local raid, grp = ns.IsTrue(call("IsInRaid")), ns.IsTrue(call("IsInGroup"))
    local n = ns.ClearNum(call("GetNumGroupMembers")) or 0
    local pvp = g("C_PvP")
    local bg, arena
    if type(pvp) == "table" then
        if type(pvp.IsBattleground) == "function" then local ok, v = pcall(pvp.IsBattleground) bg = ok and ns.IsTrue(v) end
        if type(pvp.IsArena) == "function" then local ok, v = pcall(pvp.IsArena) arena = ok and ns.IsTrue(v) end
    end
    local it = "world"
    if itype and itype ~= "none" then it = itype elseif arena then it = "arena" elseif bg then it = "pvp" end
    local group = (raid and "raid") or (grp and "party") or "solo"
    return { instance = it, group = group, members = n, bg = bg, arena = arena,
        key = (ns.CombatProbe and ns.CombatProbe.Context() or (ns.InCombat() and "combat" or "ooc")) .. "|" .. it .. "|" .. group }
end

local BASE = { "player", "pet", "target", "focus", "mouseover", "softenemy", "softfriend", "softinteract", "npc", "vehicle",
    "targettarget", "targettargettarget", "focustarget", "focustargettarget", "pettarget", "mouseovertarget" }
-- broad list in priority order of the detected context (everything is still scanned, the expected families first)
function S.BuildList(ctx)
    local out, seen = {}, {}
    local function add(t) if not seen[t] then seen[t] = true out[#out + 1] = t end end
    for _, t in ipairs(BASE) do add(t) end
    local function party() for i = 1, 4 do add("party" .. i) add("party" .. i .. "target") add("partypet" .. i) add("party" .. i .. "targettarget") end end
    local function raid() for i = 1, 40 do add("raid" .. i) add("raid" .. i .. "target") end
        for i = 1, 40 do add("raid" .. i .. "targettarget") add("raidpet" .. i) end end
    local function arena() for i = 1, 5 do add("arena" .. i) add("arena" .. i .. "target") add("arenapet" .. i) end end
    if ctx.instance == "arena" then arena() end
    if ctx.group == "raid" then raid() party() else party() raid() end
    arena()
    for i = 1, 8 do add("boss" .. i) add("boss" .. i .. "target") end
    for i = 1, 40 do add("nameplate" .. i) add("nameplate" .. i .. "target") end
    return out
end

local FIELDS = {
    { "guid", "UnitGUID" }, { "name", "UnitName" }, { "class", "UnitClass", 2 }, { "level", "UnitLevel" },
    { "health", "UnitHealth" }, { "healthMax", "UnitHealthMax" }, { "power", "UnitPower" }, { "powerMax", "UnitPowerMax" },
    { "isPlayer", "UnitIsPlayer" },
    { "reaction", "UnitReaction", nil, "player" }, { "canAttack", "UnitCanAttack", nil, nil, true },
    { "isMe", "UnitIsUnit", nil, "player" }, { "isTarget", "UnitIsUnit", nil, "target" }, { "dead", "UnitIsDeadOrGhost" },
    { "combat", "UnitAffectingCombat" }, { "idSecret", "C_Secrets.ShouldUnitIdentityBeSecret" },
    -- v2.2.6: matrix codes for world-state (threat/range/cast); values never stored — codes only
    { "threat", "UnitThreatSituation", nil, nil, true },  -- UnitThreatSituation("player", tok) via fd[5] swap? see below
    { "range28", "CheckInteractDistance", nil, 2 },  -- fd[4] as second arg number
    { "casting", "UnitCastingInfo" },
}
S.FIELDS = FIELDS

local st = { list = {}, pos = 0, prio = {}, prioSet = {}, ctx = nil, map = {}, byGuid = {}, lastCast = {}, cm = {} }
S.state = st
local cur   -- per-capture cost record

local function bump(root, ctxKey, fam, field, c)
    local m = root[ctxKey]
    if not m then m = {} root[ctxKey] = m end
    local f = m[fam]
    if not f then f = {} m[fam] = f end
    local x = f[field]
    if not x then x = {} f[field] = x end
    x[c] = (x[c] or 0) + 1
end
-- cumulative matrix (SV, all captures of this build) + this capture's matrix (memory: re-verification vs the baseline)
local function count(d, ctxKey, fam, field, c)
    bump(d.m, ctxKey, fam, field, c)
    bump(st.cm, ctxKey, fam, field, c)
end

local fnCache = {}
local function api(path)
    local f = fnCache[path]
    if f == nil then f = ns.Resolve(path) or false fnCache[path] = f end
    return f or nil
end

-- reads one token; the slice deadline is checked after EVERY field read (not only per token): when it passes mid-token
-- the read stops and resumes at the next field in the next slice (st.resume), so a slice overruns by at most one call
local PROT = ns.COMBAT_PROTECTED or {}
local function readToken(d, tok, ctxKey, t, deadline, locked)
    local fam = family(tok)
    local guid, i0
    local r = st.resume
    if r and r.tok == tok then
        i0, guid = r.i, r.guid
        st.resume = nil
    else
        st.resume = nil
        local ex = api("UnitExists")
        local ok, e = false, nil
        if ex then ok, e = pcall(ex, tok) end
        local ec = ok and ns.ClassifyValue(e) or "E"
        count(d, ctxKey, fam, "exists", ec)
        cur.reads = cur.reads + 1
        if not (ec == "S" or (ec == "C" and ns.IsTrue(e))) then
            if st.map[tok] then st.map[tok] = nil end
            return true
        end
        cur.existing = cur.existing + 1
        i0 = 1
        if pclock() >= deadline then st.resume = { tok = tok, i = 1 } return false end
    end
    for i = i0, #FIELDS do
        local fd = FIELDS[i]
        local f = api(fd[2])
        -- v2.2.7: combat-protected APIs (CheckInteractDistance) are never called while combat-locked (run 6: 41 blocks)
        if f and locked and (PROT[fd[2]] or (st.blockedSet and st.blockedSet[fd[2]])) then
            f = nil
            cur.guardSkips = (cur.guardSkips or 0) + 1
        end
        if f then
            local ok2, v1, v2   -- no per-call tables (garbage would land in later frames as GC work)
            if fd[5] then ok2, v1, v2 = pcall(f, "player", tok)
            elseif fd[4] then ok2, v1, v2 = pcall(f, tok, fd[4])
            else ok2, v1, v2 = pcall(f, tok) end
            -- v2.2.7: was `(fd[3] == 2) and v2 or v1`, which truth-tested v2 (possibly secret)
            local v = v1
            if fd[3] == 2 then v = v2 end
            local c = ok2 and ns.ClassifyValue(v) or "E"
            count(d, ctxKey, fam, fd[1], c)
            cur.reads = cur.reads + 1
            if fd[1] == "guid" and c == "C" then guid = ns.ClearStr(v) or guid end
        end
        if i < #FIELDS and pclock() >= deadline then st.resume = { tok = tok, i = i + 1, guid = guid } return false end
    end
    -- token -> GUID map (memory only) + dedupe across tokens
    if guid then
        local old = st.map[tok]
        local oldGuid = old and old.guid
        if old and not old.alias then old.guid, old.t = guid, t   -- reuse the entry (no garbage per sweep)
        else st.map[tok] = { guid = guid, t = t } end
        local set = st.byGuid[guid]
        if not set then set = {} st.byGuid[guid] = set end
        set[tok] = t
        for other, ot in pairs(set) do
            if other ~= tok and t - ot < 5 and st.map[other] and st.map[other].guid == guid then
                local a, b = fam, family(other)
                local k = (a < b) and (a .. "=" .. b) or (b .. "=" .. a)
                d.dup[k] = (d.dup[k] or 0) + 1
                cur.dups = cur.dups + 1
                break
            end
        end
        if oldGuid and oldGuid ~= guid then
            local os2 = st.byGuid[oldGuid]
            if os2 then os2[tok] = nil if next(os2) == nil then st.byGuid[oldGuid] = nil end end
        end
    else
        cur.secretGuid = cur.secretGuid + 1
    end
    return true
end

function S.Enqueue(tok)
    if type(tok) ~= "string" or st.prioSet[tok] then return end
    st.prioSet[tok] = true
    st.prio[#st.prio + 1] = tok
    if #st.prio > 64 then local tk = table.remove(st.prio, 1) st.prioSet[tk] = nil end
end

-- one slice: priority tokens, then the round-robin list, until the time budget is spent
function S.Slice()
    local d = sdb()
    if not d or not cur then return end
    if ns.SelfThrottled and ns.SelfThrottled() then return end
    local t0 = pclock()
    local budget = tonumber(scfg().budgetMs) or 0.12
    local maxTok = tonumber(scfg().maxTokensPerSlice) or 24
    local ctx = st.ctx or S.Context()
    st.ctx = ctx
    local ctxKey = ctx.key
    local t = (g("GetTime") or os.clock)()
    -- soft deadline: stop starting reads bailMs before the budget, so one in-flight read (or an allocator hiccup) still
    -- ends inside it (budget 0.12 ms -> no new read after 0.08 ms)
    local deadline = t0 + budget - math.min(tonumber(scfg().bailMs) or 0.04, budget * 0.5)
    local locked = true   -- unknown -> treat as locked (skip protected reads)
    if ns.CombatLocked then locked = ns.CombatLocked() end
    -- paths learned from a real ADDON_ACTION_BLOCKED on this build: skipped while locked (same rule as ns.CombatGuard)
    st.blockedSet = locked and ns.db and type(ns.db.blockedPaths) == "table" and ns.db.blockedPaths[ns.Build()] or nil
    local n = 0
    while n < maxTok do
        local tok
        if st.resume then tok = st.resume.tok   -- finish the token interrupted by the previous slice's deadline
        elseif #st.prio > 0 then tok = table.remove(st.prio, 1) st.prioSet[tok] = nil
        else
            if #st.list == 0 then break end
            st.pos = st.pos + 1
            if st.pos > #st.list then
                st.pos = 1
                cur.sweeps = cur.sweeps + 1
                local dt = t - (cur.sweepStart or t)
                cur.sweepS = math.floor(dt * 100 + 0.5) / 100
                cur.sweepStart = t
            end
            tok = st.list[st.pos]
        end
        local done = readToken(d, tok, ctxKey, t, deadline, locked)
        if done then n = n + 1 end
        if not done or pclock() >= deadline then break end
    end
    local ms = pclock() - t0
    cur.ms = cur.ms + ms
    cur.slices = cur.slices + 1
    cur.tokens = cur.tokens + n
    if ms > cur.maxSliceMs then cur.maxSliceMs = ms end
    if ms > budget then cur.overBudget = (cur.overBudget or 0) + 1 end
end

function S.Refresh(reason)
    st.ctx = S.Context()
    if st.ctx.key ~= st.lastKey or reason == "roster" then
        st.list = S.BuildList(st.ctx)
        st.pos = 0
        st.lastKey = st.ctx.key
        if cur then cur.contexts[st.ctx.key] = (cur.contexts[st.ctx.key] or 0) + 1 cur.listSize = #st.list end
    end
end

local EVK = { UNIT_SPELLCAST_START = 0.0001, UNIT_SPELLCAST_SUCCEEDED = 0.0002, UNIT_SPELLCAST_CHANNEL_START = 0.0003 }
-- alias learning: a cast seen at the same instant on a secret-GUID token and on a clear-GUID token
function S.OnCast(event, rawUnit, castGUID)
    local unit = ns.ClearStr(rawUnit)   -- v2.2.7: event payloads are API values too
    if not unit or unit == "player" then return end
    local d = sdb()
    if not d or not cur then return end
    local t = (g("GetTime") or os.clock)()
    local cg = ns.ClearStr(castGUID)
    local key = cg or (t + (EVK[event] or 0))   -- numeric key: no per-event string (Lua 5.1 interning cost)
    local lc = st.lastCast
    local m = st.map[unit]
    local known = m and m.guid
    local prev = lc[key]
    if prev and prev.unit ~= unit and t - prev.t < 0.05 then
        local a, b = prev, { unit = unit, guid = known }
        if (a.guid == nil) ~= (b.guid == nil) then
            local secretTok, clearTok = b.unit, a
            if a.guid == nil then secretTok, clearTok = a.unit, b end
            local k = family(secretTok) .. "<-" .. family(clearTok.unit) .. (cg and ":castGUID" or ":frame")
            d.alias[k] = (d.alias[k] or 0) + 1
            cur.aliases = cur.aliases + 1
            st.map[secretTok] = { guid = clearTok.guid, t = t, alias = clearTok.unit }
        end
    else
        lc[key] = { unit = unit, guid = known, t = t }
        st.lcN = (st.lcN or 0) + 1
        if st.lcN > 400 then st.lastCast = {} st.lcN = 0 end   -- amortised reset (entries only matter within 50 ms)
    end
end

function S.GUIDOf(tok) local m = st.map[tok] return m and m.guid, m and m.t, m and m.alias end

-- end of capture: dominant code per cell vs the stored baseline -> change alerts; new baseline stored
function S.Verify(d)
    local changes = 0
    local base = d.baseline
    local new = {}
    for k, v in pairs(base or {}) do new[k] = v end   -- cells not seen this capture keep their baseline
    for ctxKey, fams in pairs(st.cm) do
        for fam, fields in pairs(fams) do
            for field, codes in pairs(fields) do
                local best, bn, tot = nil, 0, 0
                for c, n in pairs(codes) do tot = tot + n if n > bn then best, bn = c, n end end
                if tot >= 3 then
                    local k = ctxKey .. "/" .. fam .. "/" .. field
                    new[k] = best
                    local old = base and base[k]
                    if old and old ~= best then
                        changes = changes + 1
                        if ns.Drift and ns.Drift.LogChange then
                            ns.Drift.LogChange({ kind = "token-matrix", key = k, old = old, new = best, n = tot, what = "matrix-change" })
                        end
                    end
                end
            end
        end
    end
    d.baseline = new
    return changes
end

local sframe, sticker
local SEVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_TARGET", "NAME_PLATE_UNIT_ADDED", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "ENCOUNTER_START", "ENCOUNTER_END", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_CHANNEL_START", "ARENA_OPPONENT_UPDATE", "INSTANCE_ENCOUNTER_ENGAGE_UNIT" }
local function onEvent(_, event, rawA1, rawA2)
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        S.OnCast(event, rawA1, rawA2) return   -- OnCast clears its own payload
    end
    local a1 = ns.ClearStr(rawA1)   -- v2.2.7: payload unit tokens only when clear
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then S.Refresh("roster")
    elseif event == "PLAYER_TARGET_CHANGED" then S.Enqueue("target") S.Enqueue("targettarget") S.Enqueue("targettargettarget")
    elseif event == "PLAYER_FOCUS_CHANGED" then S.Enqueue("focus") S.Enqueue("focustarget")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then S.Enqueue("mouseover") S.Enqueue("mouseovertarget")
    elseif event == "UNIT_TARGET" and a1 then S.Enqueue(a1 .. "target") if #a1 < 10 then S.Enqueue(a1 .. "targettarget") end
    elseif event == "NAME_PLATE_UNIT_ADDED" and a1 then S.Enqueue(a1)
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then for i = 1, 5 do S.Enqueue("boss" .. i) end
    elseif event == "ARENA_OPPONENT_UPDATE" and a1 then S.Enqueue(a1)
    else S.Refresh("ctx") end
end

function S.Start()
    if scfg().enabled == false then return false end
    local d = sdb()
    if not d then return false end
    cur = { start = (g("time") or os.time)(), ms = 0, slices = 0, tokens = 0, reads = 0, existing = 0, sweeps = 0, dups = 0,
        aliases = 0, secretGuid = 0, maxSliceMs = 0, overBudget = 0, contexts = {}, budgetMs = tonumber(scfg().budgetMs) or 0.12 }
    d.cost[#d.cost + 1] = cur
    while #d.cost > 12 do table.remove(d.cost, 1) end
    S.cur = cur
    st.lastKey = nil
    st.cm = {}
    fnCache = {}   -- resolved once per capture
    S.Refresh("roster")
    if not sframe then
        sframe = CreateFrame("Frame")
        -- wrapped in the self-perf monitor like every other handler (per-event cost visible per capture)
        sframe:SetScript("OnEvent", function(self, event, a1, a2)
            local ok, err
            if ns.Perf and ns.Perf.on then ok, err = ns.Perf.Run(ns.Perf.Key("TokenScan", event), onEvent, self, event, a1, a2)
            else ok, err = pcall(onEvent, self, event, a1, a2) end
            if not ok and ns.NoteSelfError then ns.NoteSelfError("TokenScan." .. tostring(event), err) end
        end)
    end
    for _, ev in ipairs(SEVENTS) do pcall(sframe.RegisterEvent, sframe, ev) end
    local ct = g("C_Timer")
    if not sticker and type(ct) == "table" and type(ct.NewTicker) == "function" then
        sticker = ct.NewTicker(tonumber(scfg().interval) or 0.1, function()
            if ns.Perf and ns.Perf.on then ns.Perf.Run("TokenScan.Slice", S.Slice) else pcall(S.Slice) end
        end)
    end
    return true
end

function S.Stop()
    if sframe then pcall(sframe.UnregisterAllEvents, sframe) end
    if sticker then sticker:Cancel() sticker = nil end
    local d = sdb()
    if not (d and cur) then return nil end
    cur.stop = (g("time") or os.time)()
    cur.ms = math.floor(cur.ms * 1000 + 0.5) / 1000
    cur.maxSliceMs = math.floor(cur.maxSliceMs * 10000 + 0.5) / 10000
    cur.changes = S.Verify(d)
    local c = cur
    cur = nil
    st.map, st.byGuid, st.lastCast = {}, {}, {}
    return c
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "unit token survey", start = function() return T.Start() end,
    stop = function() return string.format("token survey %d context(s)", T.Stop()) end }
ns.captureModules[#ns.captureModules + 1] = { name = "group-aware token scanner", start = function() return S.Start() end,
    stop = function() local c = S.Stop() return c and string.format("token scan %d tokens / %d slices, %.2f ms, %d sweep(s), %d matrix change(s)",
        c.tokens, c.slices, c.ms, c.sweeps, c.changes or 0) or nil end }
