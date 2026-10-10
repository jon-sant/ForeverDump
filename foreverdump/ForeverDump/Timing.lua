-- ForeverDump v2.2.4 - per-spell GCD / cooldown reference table (self-updating).
-- Seed: Data/spell-timing.lua (ns.SpellTimingSeed), generated offline by `fdump.py analyze` from earlier captures, the
-- combat log and known answers (shaman totems 1.0 s GCD, Lightning Shield 1.5 s). At HSM creation the seed is loaded into
-- the CooldownTracker (HybridState MINOR 5, lowest priority below live data: HS:GCD() uses it when the API is secret).
-- Live learning (HybridState onCDLearn): clear out-of-combat GetSpellCooldown reads ("cal", "gcdcal"), isActive /
-- isOnGCD flips ("cd", "gcd") and gaps between my consecutive cast begins ("gap"). Updates are stored per build in
-- ForeverDumpDB.timing[build].spells[spellID] as running min / max / sum / count: O(1) per update, LRU-capped (cap +
-- slack, one amortised sweep). Numbers and spell IDs only: no names, no GUIDs. Offline the updates are merged back into
-- the seed (conflicts flagged, promotion only above a confidence threshold).
local _, ns = ...
local T = {}
ns.Timing = T

local function g(n) return rawget(_G, n) end
local function cfg() return (ns.config and ns.config.timing) or {} end
local function epoch() return (g("time") or os.time)() end

function T.DB()
    local db = ns.db
    if type(db) ~= "table" then return nil end
    db.timing = type(db.timing) == "table" and db.timing or {}
    local b = ns.Build and ns.Build() or "?"
    local d = db.timing[b]
    if type(d) ~= "table" then
        d = { v = 1, spells = {}, n = 0, seq = 0, first = epoch() }
        db.timing[b] = d
    end
    return d
end

local function cap() return tonumber(cfg().maxSpells) or 300 end

-- LRU: keep the `cap` most recently updated spells once n exceeds cap + slack (one sweep per `slack` inserts)
local function sweep(d)
    local c = cap()
    if d.n <= c + math.max(10, math.floor(c / 10)) then return end
    local list = {}
    for id, e in pairs(d.spells) do list[#list + 1] = { id = id, s = e.s or 0 } end
    table.sort(list, function(a, b) return a.s > b.s end)
    for i = c + 1, #list do d.spells[list[i].id] = nil end
    d.n = math.min(#list, c)
end

local FIELD = { gcd = "gcd", cd = "cd", gap = "gap", cal = "cal", gcdcal = "gcdCal" }
function T.Learn(kind, id, v)
    if cfg().enabled == false or type(id) ~= "number" or type(v) ~= "number" then return end
    local f = FIELD[kind]
    if not f then return end
    local d = T.DB()
    if not d then return end
    local e = d.spells[id]
    if not e then
        e = {}
        d.spells[id] = e
        d.n = d.n + 1
    end
    d.seq = d.seq + 1
    e.s, e.t = d.seq, epoch()
    v = math.floor(v * 1000 + 0.5) / 1000
    if f == "cal" or f == "gcdCal" then
        e[f] = v
    else
        e[f .. "N"] = (e[f .. "N"] or 0) + 1
        e[f .. "Sum"] = (e[f .. "Sum"] or 0) + v
        if not e[f .. "Min"] or v < e[f .. "Min"] then e[f .. "Min"] = v end
        if not e[f .. "Max"] or v > e[f .. "Max"] then e[f .. "Max"] = v end
    end
    sweep(d)
    -- drift guard: a live GCD / cooldown that keeps disagreeing with the shipped seed overrides it at runtime
    if (f == "gcd" or f == "cd" or f == "gcdCal" or f == "cal") and ns.Drift then
        local se = T.SeedEntry(id)
        local sv = se and ((f == "gcd" or f == "gcdCal") and se.gcd or se.cooldown)
        if type(sv) == "number" then
            local it = ns.Drift.Observe(f:sub(1, 3) == "gcd" and "gcd" or "cooldown", id, sv, v)
            if it and it.flag and T.hs and T.hs.CDSeed then
                local x = { confidence = "high", source = "drift" }
                if f:sub(1, 3) == "gcd" then x.gcd = it.new else x.cooldown = it.new end
                T.hs:CDSeed(id, x)
            end
        end
    end
end

function T.SeedEntry(id)
    local seed = ns.SpellTimingSeed
    return type(seed) == "table" and type(seed.spells) == "table" and seed.spells[id] or nil
end

-- seed + this build's learned values -> the CooldownTracker (learned values with >= minSamples win over the seed)
function T.Attach(hs)
    if not (hs and hs.CDSeed) or cfg().enabled == false then return 0 end
    local n = 0
    local seed = ns.SpellTimingSeed
    if ns.Drift then ns.Drift.BuildCheck() end
    for id, e in pairs(type(seed) == "table" and type(seed.spells) == "table" and seed.spells or {}) do
        id = tonumber(id)
        if id and type(e) == "table" then
            -- a seed is a starting point: confidence decays with build / age, drift-flagged values win at runtime
            local x = { gcd = e.gcd, cooldown = e.cooldown, srCategory = e.srCategory, category = e.category,
                confidence = ns.Drift and ns.Drift.Decay(e.confidence, e.lastBuild, e.lastSeen) or e.confidence }
            if ns.Drift then
                local gv, gf = ns.Drift.Value("gcd", id, e.gcd)
                local cv, cf = ns.Drift.Value("cooldown", id, e.cooldown)
                if gf or cf then x.gcd, x.cooldown, x.source, x.confidence = gv, cv, "drift", "high" end
            end
            hs:CDSeed(id, x)
            n = n + 1
        end
    end
    T.hs = hs
    local d = T.DB()
    local minN = math.max(1, tonumber(cfg().minSamples) or 3)   -- v2.2.13: never 0 / 0
    for id, e in pairs((d and d.spells) or {}) do
        local x = {}
        if e.gcdCal then x.gcd = e.gcdCal elseif (e.gcdN or 0) >= minN then x.gcd = e.gcdSum / e.gcdN end
        if e.cal then x.cooldown = e.cal elseif (e.cdN or 0) >= minN then x.cooldown = e.cdSum / e.cdN end
        if next(x) then x.confidence = "high" x.source = "learned" hs:CDSeed(id, x) n = n + 1 end
    end
    hs.onCDLearn = T.Learn
    return n
end

function T.SeedCount()
    local seed = ns.SpellTimingSeed
    local n = 0
    for _ in pairs(type(seed) == "table" and type(seed.spells) == "table" and seed.spells or {}) do n = n + 1 end
    return n
end
