-- ForeverDump v2.2.4 - drift guard (standing design rule: every learned or static value is a STARTING POINT).
-- The game and its abilities change between builds and patches. Seeds (Data/spell-timing.lua, Data/learned-seed.lua,
-- KnowledgePatch, token matrix baselines, secrecy baselines) are keyed by build and spellID (each rank has its own
-- spellID) and re-verified live against fresh observations:
--   * D.Observe(kind, key, seed, obs, tol): agree / disagree counters with decay (older evidence fades). When the
--     observations consistently disagree (>= minDisagree effective samples AND disagree share >= ratio) the item is
--     FLAGGED: D.Value() returns the newer observed value at runtime (the seed stays untouched), and a changelog entry
--     old -> new with build / date is written. Agreement coming back reverts the flag (also logged).
--   * D.Category(kind, key, baseline, obs): the same for categorical values (secrecy codes, token matrix cells).
--   * D.Decay(conf, lastBuild, lastSeen): stale values lose confidence (other build: one step; > 30 days: one step;
--     > 90 days: low).
--   * D.BuildCheck(): client build / patch change detected automatically -> changelog "build-change", ns.buildChanged,
--     Verify.Unexpected; per-build tables start fresh and every seed value is treated as unverified until re-observed.
-- `fdump analyze` reads the changelog and the flagged items and PROPOSES seed updates (never silently overwrites).
-- SV: ForeverDumpDB.drift[build] = { items (LRU-capped, O(1) per observation), changelog ring }. Numbers, IDs, codes.
local _, ns = ...
local D = {}
ns.Drift = D

local function g(n) return rawget(_G, n) end
local function cfg() return (ns.config and ns.config.drift) or {} end
local function epoch() return (g("time") or (rawget(_G, "os") and os.time) or function() return 0 end)() end
local function today() local f = g("date") or (rawget(_G, "os") and os.date) if not f then return "?" end return f("%Y-%m-%d") end
local function build() return ns.Build and ns.Build() or "?" end

function D.DB()
    local db = ns.db
    if type(db) ~= "table" then return nil end
    db.drift = type(db.drift) == "table" and db.drift or {}
    local b = build()
    local d = db.drift[b]
    if type(d) ~= "table" then
        d = { v = 1, items = {}, n = 0, seq = 0, changelog = {}, flagged = 0 }
        db.drift[b] = d
    end
    return d
end

local function logChange(d, e)
    e.build, e.date, e.t = build(), today(), epoch()
    local cl = d.changelog
    cl[#cl + 1] = e
    local cap = tonumber(cfg().maxChangelog) or 200
    if #cl > cap + 20 then   -- amortised trim (one shift per 20 inserts)
        local keep = {}
        for i = #cl - cap + 1, #cl do keep[#keep + 1] = cl[i] end
        d.changelog = keep
    end
    if ns.Verify and ns.Verify.Unexpected then pcall(ns.Verify.Unexpected, "drift", e.kind .. ":" .. tostring(e.key), e.what) end
end
D.LogChange = function(e) local d = D.DB() if d then logChange(d, e) end end

local function sweep(d)
    local cap = tonumber(cfg().maxItems) or 500
    if d.n <= cap + math.max(10, math.floor(cap / 10)) then return end
    local list = {}
    for k, it in pairs(d.items) do list[#list + 1] = { k = k, s = it.s or 0, f = it.flag and 1 or 0 } end
    table.sort(list, function(a, b) if a.f ~= b.f then return a.f > b.f end return a.s > b.s end)   -- keep flagged first
    for i = cap + 1, #list do d.items[list[i].k] = nil end
    d.n = math.min(#list, cap)
end

local function item(d, kind, key, seed)
    local k = kind .. ":" .. tostring(key)
    local it = d.items[k]
    if not it then
        it = { kind = kind, key = key, seed = seed, a = 0, x = 0, xs = 0, xn = 0 }
        d.items[k] = it
        d.n = d.n + 1
    end
    d.seq = d.seq + 1
    it.s, it.t = d.seq, epoch()
    return it
end

-- numeric: returns the item (it.flag true = drift, it.new = observed value preferred at runtime)
function D.Observe(kind, key, seed, obs, tol)
    if cfg().enabled == false or type(seed) ~= "number" or type(obs) ~= "number" then return nil end
    local d = D.DB()
    if not d then return nil end
    local it = item(d, kind, key, seed)
    if it.seed ~= seed then it.seed, it.a, it.x, it.xs, it.xn = seed, 0, 0, 0, 0 end   -- seed replaced: start over
    tol = tol or math.max(tonumber(cfg().absTol) or 0.15, (tonumber(cfg().relTol) or 0.10) * math.abs(seed))
    local decay = tonumber(cfg().decay) or 0.9
    it.a, it.x = it.a * decay, it.x * decay
    if math.abs(obs - seed) > tol then
        it.x = it.x + 1
        it.xs, it.xn = it.xs * decay + obs, it.xn * decay + 1   -- decayed mean of the disagreeing observations
    else
        it.a = it.a + 1
    end
    local minX = tonumber(cfg().minDisagree) or 2.5     -- ~3 recent disagreeing observations
    local ratio = tonumber(cfg().ratio) or 0.6
    local share = it.x / math.max(it.a + it.x, 1e-9)
    if not it.flag and it.x >= minX and share >= ratio then
        it.flag = true
        it.new = math.floor(it.xs / math.max(it.xn, 1e-9) * 1000 + 0.5) / 1000
        d.flagged = (d.flagged or 0) + 1
        logChange(d, { kind = kind, key = key, old = seed, new = it.new, n = math.floor(it.x + 0.5), what = "drift" })
    elseif it.flag then
        local nv = math.floor(it.xs / math.max(it.xn, 1e-9) * 1000 + 0.5) / 1000
        if share < 0.3 then
            it.flag, it.new = nil, nil
            d.flagged = math.max(0, (d.flagged or 1) - 1)
            logChange(d, { kind = kind, key = key, old = seed, new = seed, what = "reverted" })
        elseif math.abs(nv - it.new) > tol then
            logChange(d, { kind = kind, key = key, old = it.new, new = nv, what = "drift-update" })
            it.new = nv
        end
    end
    sweep(d)
    return it
end

-- categorical (secrecy code, token matrix cell): flagged after minDisagree consistent different observations
function D.Category(kind, key, baseline, obs)
    if cfg().enabled == false or baseline == nil or obs == nil then return nil end
    local d = D.DB()
    if not d then return nil end
    local it = item(d, kind, key, baseline)
    if it.seed ~= baseline then it.seed, it.a, it.x, it.cand = baseline, 0, 0, nil end
    local decay = tonumber(cfg().decay) or 0.9
    it.a, it.x = it.a * decay, it.x * decay
    if obs ~= baseline then
        if it.cand ~= obs then it.cand, it.x = obs, 1 else it.x = it.x + 1 end
    else it.a = it.a + 1 end
    local minX = tonumber(cfg().minDisagree) or 2.5
    if not it.flag and it.x >= minX and it.x >= 1.5 * it.a then
        it.flag, it.new = true, it.cand
        d.flagged = (d.flagged or 0) + 1
        logChange(d, { kind = kind, key = key, old = baseline, new = it.cand, n = math.floor(it.x + 0.5), what = "drift" })
    elseif it.flag and it.a > 2 * it.x then
        it.flag, it.new = nil, nil
        logChange(d, { kind = kind, key = key, old = baseline, new = baseline, what = "reverted" })
    end
    sweep(d)
    return it
end

-- runtime value: the newer observed value once drift is flagged, else the seed
function D.Value(kind, key, seed)
    local db = ns.db
    local d = type(db) == "table" and type(db.drift) == "table" and db.drift[build()]
    local it = d and d.items[kind .. ":" .. tostring(key)]
    if it and it.flag and it.new ~= nil then return it.new, true end
    return seed, false
end

local STEP = { high = "medium", medium = "low", low = "low" }

-- days since 1970-01-01 of a civil date (Howard Hinnant's days_from_civil); pure integer arithmetic
function D.DayNumber(y, m, d)
    y = (m <= 2) and (y - 1) or y
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local mp = (m > 2) and (m - 3) or (m + 9)   -- March = 0
    local doy = math.floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end
function D.Decay(conf, lastBuild, lastSeen)
    conf = conf or "medium"
    if lastBuild and tostring(lastBuild) ~= build() then conf = STEP[conf] or "low" end
    local age = 0
    if type(lastSeen) == "string" then
        local y, m, dd = lastSeen:match("^(%d+)-(%d+)-(%d+)")
        -- time audit 2026-10-10: plain civil-day arithmetic (no time(table): Core v2.2.11 taint rule, no DST/zone)
        local ty, tm, td = today():match("^(%d+)-(%d+)-(%d+)")
        if y and ty then
            age = D.DayNumber(tonumber(ty), tonumber(tm), tonumber(td)) - D.DayNumber(tonumber(y), tonumber(m), tonumber(dd))
        end
    elseif type(lastSeen) == "number" then age = (epoch() - lastSeen) / 86400 end
    if age > 90 then return "low" end
    if age > 30 then conf = STEP[conf] or "low" end
    return conf
end

-- client build / patch change: logged once per change, re-baseline per-build tables
function D.BuildCheck()
    local db = ns.db
    if type(db) ~= "table" then return nil end
    local b = build()
    local last = db.lastClientBuild
    db.lastClientBuild = b
    if last and last ~= b then
        ns.buildChanged = { old = last, new = b }
        local d = D.DB()
        if d then logChange(d, { kind = "build", key = "client", old = last, new = b, what = "build-change" }) end
        return ns.buildChanged
    end
    return nil
end

function D.Summary()
    local d = D.DB()
    if not d then return { flagged = 0, items = 0, changes = 0 } end
    return { flagged = d.flagged or 0, items = d.n, changes = #d.changelog }
end
