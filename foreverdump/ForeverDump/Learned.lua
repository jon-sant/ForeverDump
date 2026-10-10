-- ForeverDump v2.2.4 - persistent learned-spell / NPC / class DB ("collect while available, retain, re-verify").
-- For EVERY spellID seen from any unit while it is clear: name, rank, school, API cast time, observed cast and channel
-- durations (START -> SUCCEEDED / CHANNEL_START -> STOP) per caster type (player / pc / npc), helpful / harmful, typical
-- target type (self / friendly / enemy), the cast -> aura map (aura IDs, durations, dispel type, buff / debuff),
-- damage / heal ranges, GCD / cooldown (own: from Timing.lua), sample counts, confidence, first / last seen.
-- Per NPC (npcID parsed from a clear GUID): name, spells cast (counts), cast-time model, interruptible, typical targets.
-- Per player CLASS (other players): spell catalog with counts + cast times. Never names / GUIDs of players.
-- Rules: values only when ns.ClassifyValue says clear ("C"/"K"); secret values are never stored or derived from.
-- O(1) per event (a few table lookups + at most one UnitGUID read); spell info (name / rank / cast time / helpful) is read
-- from a queue OUT OF COMBAT, a few per tick, on a ticker that exists only while the queue is non-empty (no idle work).
-- LRU caps per table (cap + slack, one amortised sweep). Seeds (Data/learned-seed.lua) are starting points: observed
-- values are checked against them through Drift.lua and override them at runtime when they consistently disagree.
-- SV: ForeverDumpDB.learned[build] = { spells, npcs, classes, n, seq, first }. `fdump analyze` merges it into the seed
-- (anonymized, promotion thresholds, conflicts flagged).
local _, ns = ...
local L = {}
ns.Learned = L

local function g(n) return rawget(_G, n) end
local function cfg() return (ns.config and ns.config.learned) or {} end
local function code(v) return ns.ClassifyValue(v) end
local function clear(v) local c = code(v) if c == "C" or c == "K" then return v end return nil end   -- keeps false
local function now() return (g("GetTime") or os.clock)() end
local function today() local f = g("date") or os.date return f("%Y-%m-%d") end
local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end

function L.DB()
    local db = ns.db
    if type(db) ~= "table" then return nil end
    db.learned = type(db.learned) == "table" and db.learned or {}
    local b = ns.Build and ns.Build() or "?"
    local d = db.learned[b]
    if type(d) ~= "table" then
        d = { v = 1, spells = {}, npcs = {}, classes = {}, n = { spells = 0, npcs = 0, classes = 0 }, seq = 0, first = today() }
        db.learned[b] = d
    end
    return d
end

local CAPS = { spells = "maxSpells", npcs = "maxNpcs", classes = "maxClasses" }
local DEFCAP = { spells = 2000, npcs = 800, classes = 20 }
local function sweep(d, kind)
    local cap = tonumber(cfg()[CAPS[kind]]) or DEFCAP[kind]
    if d.n[kind] <= cap + math.max(10, math.floor(cap / 10)) then return end
    local list = {}
    for id, e in pairs(d[kind]) do list[#list + 1] = { id = id, s = e.s or 0 } end
    table.sort(list, function(a, b) return a.s > b.s end)
    for i = cap + 1, #list do d[kind][list[i].id] = nil end
    d.n[kind] = math.min(#list, cap)
end

local infoQueue, queued = {}, {}
local function entry(d, kind, id)
    local e = d[kind][id]
    if not e then
        e = { f = today(), n = 0 }
        d[kind][id] = e
        d.n[kind] = d.n[kind] + 1
        sweep(d, kind)
        if kind == "spells" and not queued[id] then queued[id] = true infoQueue[#infoQueue + 1] = id L.Kick() end
    end
    d.seq = d.seq + 1
    e.s, e.l = d.seq, today()
    return e
end
L.Entry = function(kind, id) local d = L.DB() return d and entry(d, kind, id) end

-- running stats {n, min, max, sum} in a sub-table (O(1))
local function stat(t, k, v)
    local s = t[k]
    if not s then s = { 0, v, v, 0 } t[k] = s end
    s[1] = s[1] + 1
    if v < s[2] then s[2] = v end
    if v > s[3] then s[3] = v end
    s[4] = s[4] + v
    return s
end
L.Stat = stat

local function npcOf(guid)
    if type(guid) ~= "string" then return nil, nil end
    local kind = guid:match("^(%a+)-")
    if kind == "Player" then return nil, "pc" end
    if kind == "Creature" or kind == "Vehicle" or kind == "Pet" then
        local id = tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        return id, (kind == "Pet") and "pet" or "npc"
    end
    return nil, kind and kind:lower() or nil
end
L.NpcOf = npcOf

----------------------------------------------------------------------------- casts (any unit)
local pending = {}      -- castKey -> { t, sid, ctype, npc, class, chan }
local pendingN = 0
local own = nil         -- last own SUCCEEDED { sid, t, tgt }

local function casterOf(unit)
    if unit == "player" then return "player", nil, nil, nil end
    local f = g("UnitGUID")
    local guid = type(f) == "function" and clear((select(2, pcall(f, unit)))) or nil   -- in memory only
    if not guid then return nil end
    local npc, ctype = npcOf(guid)
    local class
    if ctype == "pc" then
        local uc = g("UnitClass")
        if type(uc) == "function" then
            local ok, _, cf = pcall(uc, unit)
            class = ok and clear(cf) or nil
        end
    end
    return ctype, npc, class, guid
end

local function targetType(unit)
    local f = g("UnitExists")
    local tgt = unit .. "target"
    if unit == "player" then tgt = "target" end
    if type(f) ~= "function" then return nil end
    local ok, ex = pcall(f, tgt)
    ex = ok and clear(ex)
    if ex == nil then return nil end
    if not ex then return "self" end
    local uu = g("UnitIsUnit")
    if type(uu) == "function" then
        local ok2, me = pcall(uu, tgt, "player")
        me = ok2 and clear(me)
        if me == true then return (unit == "player") and "self" or "me" end
    end
    local ca = g("UnitCanAttack")
    if type(ca) == "function" then
        local ok3, hostile = pcall(ca, "player", tgt)
        hostile = ok3 and clear(hostile)
        if hostile == true then return (unit == "player") and "enemy" or "my-side?" end
        if hostile == false then return (unit == "player") and "friendly" or "their-side?" end
    end
    return nil
end

local function finish(p, outcome, t)
    local d = L.DB()
    if not d then return end
    local dur = t - p.t
    if dur < 0 or dur > 30 then return end
    if p.npc then
        local ne = entry(d, "npcs", p.npc)
        ne.cast = ne.cast or {}
        if outcome == "ok" then stat(ne.cast, p.sid or "secret", r3(dur)) end
        if outcome == "interrupted" then ne.interrupted = (ne.interrupted or 0) + 1 end
    end
    if not p.sid then return end
    local e = entry(d, "spells", p.sid)
    local bucket = p.chan and "chan" or "cast"
    e[bucket] = e[bucket] or {}
    if outcome == "ok" then
        stat(e[bucket], p.ctype or "?", r3(dur))
        -- drift guard vs the shipped seed cast time (seed = starting point)
        local seed = ns.LearnedSeed and ns.LearnedSeed.spells and ns.LearnedSeed.spells[p.sid]
        if seed and type(seed.castTime) == "number" and not p.chan and seed.castTime > 0 and ns.Drift then
            ns.Drift.Observe("castTime", p.sid, seed.castTime, dur, 0.25)
        end
    else
        e.stop = e.stop or {}
        e.stop[outcome] = (e.stop[outcome] or 0) + 1
    end
end

local doneCast, doneN = {}, 0   -- castKey -> t of the counted SUCCEEDED (dedupe across tokens)
local function prune(t)
    for k, p in pairs(pending) do if t - p.t > 30 then pending[k] = nil pendingN = pendingN - 1 end end
    doneN = 0
    for k, v in pairs(doneCast) do if t - v > 30 then doneCast[k] = nil else doneN = doneN + 1 end end
end

local function guidOf(unit)
    local f = g("UnitGUID")
    return type(f) == "function" and clear((select(2, pcall(f, unit)))) or nil
end

function L.OnCast(event, unit, castGUID, spellID)
    if cfg().enabled == false or type(unit) ~= "string" then return end
    local t = now()
    local cg = clear(castGUID)
    local sid = clear(spellID)
    if type(sid) ~= "number" then sid = nil end
    -- one cast seen through several tokens (raid5 + nameplate3 + target) has one key: castGUID, else caster GUID, else token
    local guid = (unit ~= "player") and guidOf(unit) or nil
    local key = cg or (guid and (guid .. ":" .. tostring(sid))) or (unit .. ":" .. tostring(sid))
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local old = pending[key]
        if old and t - old.t < 0.25 then return end     -- duplicate via another token
        local ctype, npc, class = casterOf(unit)
        if not old then pendingN = pendingN + 1 end
        pending[key] = { t = t, sid = sid, ctype = ctype, npc = npc, class = class, chan = event == "UNIT_SPELLCAST_CHANNEL_START" }
        if pendingN > 200 then prune(t) end
        if npc then
            local d = L.DB()
            if d then
                local ne = entry(d, "npcs", npc)
                ne.n = ne.n + 1
                ne.spells = ne.spells or {}
                local sk = sid or "secret"
                ne.spells[sk] = (ne.spells[sk] or 0) + 1
                local tt = targetType(unit)
                if tt then ne.tgt = ne.tgt or {} ne.tgt[tt] = (ne.tgt[tt] or 0) + 1 end
                if not ne.name then
                    local un = g("UnitName")
                    local nm = type(un) == "function" and clear((select(2, pcall(un, unit)))) or nil
                    if type(nm) == "string" then ne.name = nm end   -- NPC names are game data (players: never)
                end
            end
        end
        return
    end
    local p = pending[key]
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if doneCast[key] and t - doneCast[key] < 0.25 then return end
        doneCast[key] = t
        doneN = doneN + 1
        if doneN > 300 then prune(t) end
        if p and not p.chan then pending[key] = nil pendingN = pendingN - 1 p.sid = p.sid or sid finish(p, "ok", t) end
        if not sid then return end
        local d = L.DB()
        if not d then return end
        local e = entry(d, "spells", sid)
        e.n = e.n + 1
        local ctype, class = p and p.ctype, p and p.class
        if not ctype then local c1, _, c3 = casterOf(unit) ctype, class = c1, c3 end
        if ctype then e.by = e.by or {} e.by[ctype] = (e.by[ctype] or 0) + 1 end
        local tt = targetType(unit)
        if tt then e.tgt = e.tgt or {} e.tgt[tt] = (e.tgt[tt] or 0) + 1 end
        if unit == "player" then
            own = { sid = sid, t = t, tgt = tt }
        elseif class then
            local ce = entry(d, "classes", class)
            ce.n = ce.n + 1
            ce.spells = ce.spells or {}
            ce.spells[sid] = (ce.spells[sid] or 0) + 1
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if p and p.chan then pending[key] = nil pendingN = pendingN - 1 finish(p, "ok", t) end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        if p and not p.chan then
            pending[key] = nil pendingN = pendingN - 1
            finish(p, event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupted" or "failed", t)
        end
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        if p and p.npc then
            local d = L.DB()
            local ne = d and entry(d, "npcs", p.npc)
            if ne then
                ne.intr = ne.intr or {}
                local k = event == "UNIT_SPELLCAST_INTERRUPTIBLE" and "yes" or "no"
                ne.intr[k] = (ne.intr[k] or 0) + 1
            end
        end
    end
end

----------------------------------------------------------------------------- auras + amounts (HSM callbacks)
-- an aura recorded while clear (UNIT_AURA addedAuras / out-of-combat scan) shortly after my own cast -> cast -> aura map
function L.OnAura(unitKey, ad, t)
    if cfg().enabled == false or not own or type(ad) ~= "table" then return end
    local aid = clear(ad.spellId)
    if type(aid) ~= "number" then return end
    t = t or now()
    if t - own.t > (tonumber(cfg().auraWindow) or 1.0) then return end
    local from = clear(ad.fromPlayer)
    if from == false then return end
    local d = L.DB()
    if not d then return end
    local e = entry(d, "spells", own.sid)
    e.aura = e.aura or {}
    local a = e.aura[aid]
    if not a then a = { n = 0 } e.aura[aid] = a end
    a.n = a.n + 1
    local dur = clear(ad.duration)
    if type(dur) == "number" and dur > 0 then
        stat(a, "dur", r3(dur))
        local seed = ns.LearnedSeed and ns.LearnedSeed.spells and ns.LearnedSeed.spells[own.sid]
        local sd = seed and seed.auras and seed.auras[aid]
        if type(sd) == "number" and ns.Drift then ns.Drift.Observe("auraDuration", own.sid .. ">" .. aid, sd, dur, 0.5) end
    end
    local h = clear(ad.helpful)
    if h ~= nil then a.helpful = h and true or false end
    local disp = clear(ad.dispelName)
    if type(disp) == "string" and #disp < 16 then a.dispel = disp end
    a.unit = (unitKey == "player") and "self" or "other"
end

function L.OnAmount(spellID, kind, amount, crit, school)
    if cfg().enabled == false or type(spellID) ~= "number" or type(amount) ~= "number" then return end
    local d = L.DB()
    if not d then return end
    local e = entry(d, "spells", spellID)
    e.amt = e.amt or {}
    stat(e.amt, kind .. (crit and "Crit" or ""), amount)
    if type(school) == "number" and school > 0 then e.school = school end
end

----------------------------------------------------------------------------- spell info queue (out of combat)
local ticker
local function readInfo(id)
    local d = L.DB()
    local e = d and d.spells[id]
    if not e then return end
    local cs = g("C_Spell")
    if type(cs) == "table" and type(cs.GetSpellInfo) == "function" then
        local ok, info = pcall(cs.GetSpellInfo, id)
        -- v2.2.22 (audit): was `code(info) ~= "T"` (a struct with ANY secret field skipped). K or T: each field read
        -- with pcall(index) and used only when clear.
        local ci = ok and code(info) or "E"
        if ok and type(info) == "table" and (ci == "K" or ci == "T") then
            local okN, rn = pcall(function() return info.name end)
            local nm = okN and clear(rn) or nil
            if type(nm) == "string" then e.name = nm end
            local okC, rc = pcall(function() return info.castTime end)
            local ct = okC and clear(rc) or nil
            if type(ct) == "number" then e.ct = ct / 1000 end
            if ci == "T" then e.infoT = true end
        end
    end
    if type(cs) == "table" and type(cs.GetSpellSubtext) == "function" then
        local ok, st = pcall(cs.GetSpellSubtext, id)
        st = ok and clear(st)
        if type(st) == "string" then e.rank = tonumber(st:match("(%d+)")) end   -- clear static text only
    end
    for k, fname in pairs({ helpful = "IsSpellHelpful", harmful = "IsSpellHarmful" }) do
        local f = type(cs) == "table" and cs[fname]
        if type(f) == "function" then
            local ok, v = pcall(f, id)
            v = ok and clear(v)
            if v ~= nil then e[k] = v and true or false end
        end
    end
    local bc = g("GetSpellBaseCooldown")
    if type(bc) == "function" then
        local ok, cdms, gcdms = pcall(bc, id)
        if ok and type(clear(cdms)) == "number" then e.bcd = cdms / 1000 end
        if ok and type(clear(gcdms)) == "number" then e.bgcd = gcdms / 1000 end
    end
    e.info = today()
end

function L.Drain(budget)
    if ns.InCombat() then return #infoQueue end   -- heavy-ish work only out of combat
    budget = budget or tonumber(cfg().infoPerTick) or 6
    local n = 0
    while n < budget and #infoQueue > 0 do
        local id = table.remove(infoQueue)
        queued[id] = nil
        pcall(readInfo, id)
        n = n + 1
    end
    return #infoQueue
end

function L.Kick()
    if ticker or #infoQueue == 0 or not L.running then return end
    local ct = g("C_Timer")
    if type(ct) ~= "table" or type(ct.NewTicker) ~= "function" then return end
    ticker = ct.NewTicker(tonumber(cfg().infoInterval) or 0.5, function()
        if L.Drain() == 0 and ticker then ticker:Cancel() ticker = nil end   -- queue empty: no ticker at all
    end)
end
function L.QueueSize() return #infoQueue end

----------------------------------------------------------------------------- lifecycle
local frame
local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }
function L.Attach(hs)
    if not hs or cfg().enabled == false then return end
    hs.onAuraRecord = function(unitKey, ad, t) L.OnAura(unitKey, ad, t) end
    hs.onAmount = function(sid, kind, amt, crit, school) L.OnAmount(sid, kind, amt, crit, school) end
end
function L.Start()
    if cfg().enabled == false then return false end
    if ns.Drift then ns.Drift.BuildCheck() end
    L.DB()
    L.running = true
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
            if ns.Perf and ns.Perf.on then ns.Perf.Run("Learned." .. event, L.OnCast, event, unit, castGUID, spellID)
            else pcall(L.OnCast, event, unit, castGUID, spellID) end
        end)
    end
    for _, ev in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
    if ns.Inference and ns.Inference.hs then L.Attach(ns.Inference.hs) end
    L.Kick()
    return true
end
function L.Stop()
    if frame then pcall(frame.UnregisterAllEvents, frame) end
    L.running = false
    if ticker then ticker:Cancel() ticker = nil end
    local d = L.DB()
    return d and d.n or nil
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "learned spell / NPC / class DB", start = function() return L.Start() end,
    stop = function() local n = L.Stop() return n and string.format("learned %d spells, %d npcs, %d classes", n.spells, n.npcs, n.classes) or nil end }
