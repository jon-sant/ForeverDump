-- ForeverDump v2.2.4 - live in-engine verification loop.
-- The HSM checks each prediction against later readable reality as it happens (HybridState MINOR 4 M:verdict):
--   aura-expiry (predicted expiry vs the removal once readable), cooldown (predicted ready vs a successful recast or a
--   UNIT_SPELLCAST_FAILED inside the window), cast-end (learned enemy cast duration vs SUCCEEDED), damage-range (parsed
--   amount range vs the clear UNIT_COMBAT amount), interrupt-attribution (own cast + meter event agreeing), dm-total
--   (post-combat C_DamageMeter vs summed UNIT_COMBAT), knowledge-aura (parsed tooltip duration vs the observed duration).
-- Verdicts: V verified / C contradicted / U unverified / X unexpected, with time, context (o/c/e), source signal and
-- confidence. Unexpected findings: readability flips vs the stored baseline, unknown spellIDs, new NPC ids, changed
-- payload shapes, new learned mappings. Stored in ForeverDumpDB.verify[build]: a fixed-size ring (O(1) insert) plus
-- bounded counters / an LRU of unexpected keys. No timers: everything is driven by events the addon already handles.
-- v2.2.21: keys are stored raw (npc:<id>, player:<GUID>, raw GUID).
local _, ns = ...
local V = {}
ns.Verify = V

local function g(n) return rawget(_G, n) end
local function cfg() return (ns.config and ns.config.verify) or {} end
local function now() return (g("GetTime") or os.clock)() end
local function ctxCode()
    if ns.Secrets and ns.Secrets.InEncounter and ns.Secrets.InEncounter() then return "e" end
    return ns.InCombat() and "c" or "o"
end

function V.DB()
    local db = ns.db
    if type(db) ~= "table" then return nil end
    db.verify = type(db.verify) == "table" and db.verify or {}
    local b = ns.Build and ns.Build() or "?"
    local d = db.verify[b]
    if type(d) ~= "table" then
        d = { v = 1, ring = {}, head = 0, n = 0, seq = 0, counts = {}, unexpected = {}, unexpectedN = 0, uSeq = 0, base = {}, shapes = {},
              sessions = {} }
        db.verify[b] = d
    end
    return d
end

local function cap()
    if ns.ReplayLog and ns.ReplayLog.VerifyCap then return math.max(1, tonumber(ns.ReplayLog.VerifyCap()) or 600) end
    return math.max(1, tonumber(cfg().ringSize) or 600)   -- v2.2.13: never % 0
end

-- O(1): overwrite the oldest slot
function V.Record(rec)
    if cfg().enabled == false then return end
    local d = V.DB()
    if not d then return end
    local size = cap()
    d.head = d.head % size + 1
    d.seq = d.seq + 1
    if d.n < size then d.n = d.n + 1
    else
        d.overwritten = (d.overwritten or 0) + 1
        if ns.ReplayLog then ns.ReplayLog.NoteOverflow("verify", 1) end
    end
    local t = rec.t or now()
    d.ring[d.head] = { s = d.seq, t = math.floor(t * 100 + 0.5) / 100, c = ctxCode(), k = rec.kind, v = rec.v, src = rec.src, cf = rec.conf,
        sp = type(rec.spell) == "number" and rec.spell or nil, d = type(rec.d) == "number" and math.floor(rec.d * 1000 + 0.5) / 1000 or nil,
        key = type(rec.key) == "string" and rec.key or nil }
    local ck = (rec.kind or "?") .. "|" .. (rec.v or "?")
    d.counts[ck] = (d.counts[ck] or 0) + 1
end

-- unexpected finding, deduplicated by key (LRU of maxUnexpected keys; counts kept per key)
function V.Unexpected(kind, key, detail)
    if cfg().enabled == false then return end
    local d = V.DB()
    if not d then return end
    local k = kind .. ":" .. tostring(key)
    d.uSeq = d.uSeq + 1
    local e = d.unexpected[k]
    if e then e.n, e.last, e.seq = e.n + 1, math.floor(now() * 100) / 100, d.uSeq return end
    d.unexpected[k] = { kind = kind, key = tostring(key), detail = detail, n = 1, first = math.floor(now() * 100) / 100, c = ctxCode(),
        sid = ns.SessionId and ns.SessionId() or nil, seq = d.uSeq }
    d.unexpectedN = d.unexpectedN + 1
    V.Record({ kind = "unexpected:" .. kind, v = "X", src = tostring(key):sub(1, 60) })
    local maxU = tonumber(cfg().maxUnexpected) or 200
    if d.unexpectedN > maxU + 16 then   -- amortised sweep: keep the maxU most recent keys
        local cut = d.uSeq - maxU
        for kk, x in pairs(d.unexpected) do if (x.seq or 0) <= cut then d.unexpected[kk] = nil d.unexpectedN = d.unexpectedN - 1 end end
    end
end

-- readability of a rule input vs the stored baseline (per context): a flip is an unexpected finding
function V.Seen(ctx, sig, readable)
    local d = V.DB()
    if not d then return end
    d.base[ctx] = d.base[ctx] or {}
    local b = d.base[ctx][sig]
    local r = readable and "r" or "u"
    if b == nil then d.base[ctx][sig] = r
    elseif b ~= r and b ~= "m" then
        d.base[ctx][sig] = "m"   -- mixed from now on (reported once)
        V.Unexpected("readability-flip", ctx .. "|" .. sig, b .. "->" .. r)
    end
end

-- payload shape (event -> signature of field names/codes); a new signature after the first is unexpected
function V.Shape(event, sig)
    local d = V.DB()
    if not d or type(sig) ~= "string" then return end
    local s = d.shapes[event]
    if not s then d.shapes[event] = { [sig] = 1 } return end
    if s[sig] then s[sig] = s[sig] + 1 return end
    local n = 0
    for _ in pairs(s) do n = n + 1 end
    if n >= 12 then return end
    s[sig] = 1
    V.Unexpected("payload-shape", event, sig)
end

function V.Start()
    if cfg().enabled == false then return false end
    local d = V.DB()
    if not d then return false end
    d.sessions[#d.sessions + 1] = { sid = ns.SessionId and ns.SessionId() or nil, anchor = ns.TimeAnchor and ns.TimeAnchor() or nil, seq0 = d.seq + 1 }
    while #d.sessions > 8 do table.remove(d.sessions, 1) end
    local hs = ns.Inference and ns.Inference.hs
    if hs then
        local prev = hs.onVerdict
        hs.onVerdict = function(rec)
            V.Record(rec)
            if prev then pcall(prev, rec) end
        end
    end
    if ns.Knowledge then
        ns.Knowledge.onNewMapping = function(x, y) V.Unexpected("new-aura-mapping", tostring(x) .. "->" .. tostring(y)) end
    end
    if ns.Perf then
        ns.Perf.Size("verify.ring", function() local dd = V.DB() return dd and dd.n or 0 end, cap())
        ns.Perf.Size("verify.unexpected", function() local dd = V.DB() return dd and dd.unexpectedN or 0 end,
            (tonumber(cfg().maxUnexpected) or 200) + 16)
    end
    return true
end

function V.Stop()
    local d = V.DB()
    local hs = ns.Inference and ns.Inference.hs
    if d and hs then d.lastCounts = hs.verdicts end
    return d and d.n or 0
end

ns.captureModules = ns.captureModules or {}
ns.captureModules[#ns.captureModules + 1] = { name = "live verification loop", start = function() return V.Start() end,
    stop = function()
        local d = V.DB()
        if not d then return nil end
        local v, c, u = 0, 0, 0
        for k, n in pairs(d.counts) do
            if k:sub(-2) == "|V" then v = v + n elseif k:sub(-2) == "|C" then c = c + n elseif k:sub(-2) == "|U" then u = u + n end
        end
        V.Stop()
        return string.format("verify: %d verified, %d contradicted, %d unverified, %d unexpected key(s)", v, c, u, d.unexpectedN)
    end }
