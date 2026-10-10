-- ForeverDump v2.2.3 - self-performance monitor, always on during an FD_Logs capture (perf.enabled, default true).
-- Run 4: the frame rate fell as the session went on because hot paths called ns.Meta(), which walked all of _G
-- (see Core.lua ns.ProjectInfo). The addon never measured itself, so this module now does:
--   * handler timing: every event handler / OnUpdate / timer body of the capture modules runs through P.Run(key, fn, ...),
--     which adds debugprofilestop() deltas to ForeverDumpLogDB.perf.sessions[n].handlers[key] = { n, ms, max, w = { [window] =
--     { n, ms } } } (15 s windows, so the converter can see whether the cost PER CALL grows with session length)
--   * samples every perf.sampleInterval (5 s): Lua heap (collectgarbage "count", all addons), GetFramerate(),
--     C_AddOnProfiler metrics when present (application/overall/ForeverDump RecentAverageTime, PeakTime) and the sizes of
--     ForeverDump's own growing tables (registered with P.Size)
-- Numbers only (no values from the game state). Bounded: 480 windows per handler, 720 samples, 4 sessions.
-- Cost: two debugprofilestop() calls and one table update per handler call; the sampler is a C_Timer chain that runs
-- only while capturing (no OnUpdate). PERFORMANCE.md lists the rules this monitor enforces.
local _, ns = ...
local P = { on = false, WINDOW = 15 }
ns.Perf = P

local function g(n) return rawget(_G, n) end
local function cfg() return (ns.config and ns.config.perf) or {} end
local clock = g("debugprofilestop") or function() return ((rawget(_G, "os") and os.clock and os.clock()) or 0) * 1000 end
local gettime = g("GetTime") or os.clock
local floor = math.floor

local cur            -- current session record
local handlers       -- cur.handlers
local start = 0
local maxWin = 480

local function db()
    local log = g("ForeverDumpLogDB")
    if type(log) ~= "table" then return nil end
    if type(log.perf) ~= "table" or log.perf.v ~= 1 then log.perf = { v = 1, sessions = {} } end
    return log.perf
end
P.DB = db

-- v2.2.15 runaway backstop. User decision 2026-10-09 ("collect first, optimize later"): at lab it is a REPORT, not a
-- switch: a measured call >= BACKSTOP_MS, BACKSTOP_N times within BACKSTOP_WINDOW s, prints one warning in our own
-- frame and is recorded in the SV (perf.sessions[n].backstop: n, max per key, tripped); lab probes and shadow rules
-- keep running. P.runaway only flags that it tripped.
P.BACKSTOP_MS, P.BACKSTOP_N, P.BACKSTOP_WINDOW = 250, 3, 60
P.runaway = false
local bigTimes = {}
local function backstop(key, ms)
    local t = gettime()
    bigTimes[#bigTimes + 1] = t
    while bigTimes[1] and t - bigTimes[1] > P.BACKSTOP_WINDOW do table.remove(bigTimes, 1) end
    if cur then
        cur.backstop = cur.backstop or { n = 0, keys = {} }
        cur.backstop.n = cur.backstop.n + 1
        cur.backstop.keys[key] = math.max(cur.backstop.keys[key] or 0, ms)
    end
    if not P.runaway and #bigTimes >= P.BACKSTOP_N then
        P.runaway = true
        if cur then cur.backstop.tripped = { t = t - start, key = key, ms = ms } end
        if ns.Print then ns.Print(string.format("|cffff3333BACKSTOP REPORT: %d calls >= %d ms in %d s (last %s %.0f ms); recorded "
            .. "in the capture (perf backstop/spikes); lab keeps collecting.|r", #bigTimes, P.BACKSTOP_MS, P.BACKSTOP_WINDOW, key, ms)) end
    end
end
-- spikes (calls >= SPIKE_MS) with the heap delta of the call: a slow call that allocated little (< 64 KB) or whose heap
-- shrank is attributed to an incremental-GC step ("gc"), else to the handler's own work ("own"). Heap is only read
-- around calls at lab (P.trackHeap), one collectgarbage("count") before and after.
P.SPIKE_MS, P.trackHeap = 50, false
local function spike(key, ms, kbDelta)
    if not cur then return end
    if not cur.maxCall or ms > cur.maxCall.ms then cur.maxCall = { key = key, ms = ms, t = gettime() - start } end
    if ms < P.SPIKE_MS then return end
    cur.spikes = cur.spikes or { n = 0, gc = 0, own = 0, list = {} }
    local sp = cur.spikes
    local gc = kbDelta ~= nil and kbDelta < 64
    sp.n = sp.n + 1
    if gc then sp.gc = sp.gc + 1 else sp.own = sp.own + 1 end
    if #sp.list < 200 then
        local okH, kb = pcall(collectgarbage, "count")
        sp.list[#sp.list + 1] = { t = math.floor((gettime() - start) * 100 + 0.5) / 100, key = key, ms = math.floor(ms * 10 + 0.5) / 10,
            kb = kbDelta and math.floor(kbDelta) or nil, heapMB = okH and math.floor(kb / 1024) or nil, cause = gc and "gc" or "own" }
    end
end
function P.ResetBackstop() P.runaway = false bigTimes = {} end

-- add one measured call
function P.Add(key, ms)
    if ms >= P.BACKSTOP_MS then backstop(key, ms) end
    local h = handlers and handlers[key]
    if not handlers then return end
    if not h then h = { n = 0, ms = 0, max = 0, w = {} } handlers[key] = h end
    h.n = h.n + 1
    h.ms = h.ms + ms
    if ms > h.max then h.max = ms end
    local wi = floor((gettime() - start) / P.WINDOW) + 1
    if wi > maxWin then wi = maxWin end
    local w = h.w[wi]
    if not w then w = { 0, 0 } h.w[wi] = w end
    w[1] = w[1] + 1
    w[2] = w[2] + ms
end

-- run fn(...) under pcall and time it (when the monitor is on); returns pcall's ok, err
function P.Run(key, fn, ...)
    if not P.on then return pcall(fn, ...) end
    local k0 = P.trackHeap and collectgarbage("count") or nil
    local t0 = clock()
    local ok, err = pcall(fn, ...)
    local ms = clock() - t0
    P.Add(key, ms)
    if k0 then spike(key, ms, collectgarbage("count") - k0)
    elseif cur and (not cur.maxCall or ms > cur.maxCall.ms) then cur.maxCall = { key = key, ms = ms, t = gettime() - start } end
    return ok, err
end

-- memoised "prefix.event" keys (no string building per event)
local keys = {}
function P.Key(prefix, event)
    local byP = keys[prefix]
    if not byP then byP = {} keys[prefix] = byP end
    local k = byP[event]
    if not k then k = prefix .. "." .. tostring(event) byP[event] = k end
    return k
end

-- size providers: name -> function returning a number (count of a growing table); sampled, never per event
local sizes = {}
-- v2.2.4: an optional bound (the table's cap) is stored with the session so the converter flags only unbounded growth
-- or growth past the cap (run 5: capped HSM tables filling up to their cap were reported as "still growing")
local bounds = {}
function P.Size(name, fn, bound) sizes[name] = fn bounds[name] = tonumber(bound) end

local METRICS = { "RecentAverageTime", "PeakTime", "CountTimeOver5Ms", "CountTimeOver50Ms" }

-- v2.2.16 probe: where does the all-time own PeakTime come from (run 13: 182.7 ms already at sample t=0)? The profiler
-- peak is cumulative since load, so reading it at load / login / capture begin / after each capture module start
-- brackets the step that set it. Clear numbers only; one row per mark (a handful per session).
P.marks = {}
function P.Mark(label)
    local AP = g("C_AddOnProfiler")
    local E = g("Enum") and Enum.AddOnProfilerMetric
    local pk
    if type(AP) == "table" and type(E) == "table" and type(AP.GetAddOnMetric) == "function" then
        local ok, v = pcall(AP.GetAddOnMetric, ns.ADDON or "ForeverDump", E.PeakTime)
        if ok and type(v) == "number" and not ns.IsSecret(v) then pk = floor(v * 1000 + 0.5) / 1000 end
    end
    local row = { label = tostring(label), peak = pk, t = gettime() }
    if cur then
        cur.peakMarks = cur.peakMarks or {}
        cur.peakMarks[#cur.peakMarks + 1] = row
    else
        P.marks[#P.marks + 1] = row
        if #P.marks > 64 then table.remove(P.marks, 1) end   -- pre-capture marks only (load/login/zone): not data volume
    end
    return pk
end
local function sample()
    if not cur then return end
    local s = { t = gettime() - start }
    local okG, kb = pcall(collectgarbage, "count")
    if okG and type(kb) == "number" then s.heapKB = floor(kb) end
    local gf = g("GetFramerate")
    if gf then local okF, f = pcall(gf) if okF and type(f) == "number" and not ns.IsSecret(f) then s.fps = floor(f * 10 + 0.5) / 10 end end
    local AP = g("C_AddOnProfiler")
    local E = g("Enum") and Enum.AddOnProfilerMetric
    if type(AP) == "table" and type(E) == "table" then
        local function m(f, ...)
            if type(f) ~= "function" then return nil end
            local ok, v = pcall(f, ...)
            if ok and type(v) == "number" and not ns.IsSecret(v) then return floor(v * 1000 + 0.5) / 1000 end
        end
        s.app = m(AP.GetApplicationMetric, E.RecentAverageTime)
        s.all = m(AP.GetOverallMetric, E.RecentAverageTime)
        s.own = m(AP.GetAddOnMetric, ns.ADDON or "ForeverDump", E.RecentAverageTime)
        s.ownPeak = m(AP.GetAddOnMetric, ns.ADDON or "ForeverDump", E.PeakTime)
        s.own5 = m(AP.GetAddOnMetric, ns.ADDON or "ForeverDump", E.CountTimeOver5Ms)
    end
    for name, fn in pairs(sizes) do
        local ok, v = pcall(fn)
        if ok and type(v) == "number" then s.sz = s.sz or {} s.sz[name] = v end
        if bounds[name] and not (cur.bounds and cur.bounds[name]) then cur.bounds = cur.bounds or {} cur.bounds[name] = bounds[name] end
    end
    local list = cur.samples
    list[#list + 1] = s
    if #list > (tonumber(cfg().maxSamples) or 720) then table.remove(list, 1) end
end
P.Sample = sample
P.METRICS = METRICS

local gen = 0
local function schedule(myGen)
    local ct = g("C_Timer")
    if type(ct) ~= "table" or type(ct.After) ~= "function" then return end
    ct.After(tonumber(cfg().sampleInterval) or 5, function()
        if myGen ~= gen or not P.on then return end
        local t0 = clock()
        pcall(sample)
        P.Add("Perf.sample", clock() - t0)
        schedule(myGen)
    end)
end

function P.Start()
    if cfg().enabled == false then P.on = false return false end
    local d = db()
    if not d then return false end
    start = gettime()
    cur = { sid = ns.SessionId and ns.SessionId() or nil, version = ns.VERSION, window = P.WINDOW, start = start,
        epoch = time and time() or nil, handlers = {}, samples = {}, peakMarks = P.marks }
    P.marks = {}
    handlers = cur.handlers
    d.sessions[#d.sessions + 1] = cur
    while #d.sessions > (tonumber(cfg().keepSessions) or 4) do table.remove(d.sessions, 1) end
    P.on = true
    P.ResetBackstop()
    gen = gen + 1
    pcall(sample)
    schedule(gen)
    return true
end

function P.Stop()
    if not cur then return nil end
    pcall(sample)
    P.on = false
    gen = gen + 1
    cur.duration = gettime() - start
    local n, ms = 0, 0
    for _, h in pairs(handlers) do n = n + h.n ms = ms + h.ms end
    cur.totalCalls, cur.totalMs = n, floor(ms * 1000 + 0.5) / 1000
    local r = cur
    cur, handlers = nil, nil
    return r
end

-- top handlers by total time (for /fdump perf)
function P.Top(rec, k)
    rec = rec or cur
    if not rec then local d = db() rec = d and d.sessions[#d.sessions] end
    if not rec then return {} end
    local out = {}
    for key, h in pairs(rec.handlers or {}) do out[#out + 1] = { key = key, n = h.n, ms = h.ms, max = h.max } end
    table.sort(out, function(a, b) return a.ms > b.ms end)
    while #out > (k or 10) do table.remove(out) end
    return out, rec
end

function P.Print()
    local top, rec = P.Top(nil, 12)
    if not rec then ns.Print("perf: no session recorded yet (starts with FD_Logs ON)") return end
    local dur = (rec.duration or (gettime() - (rec.start or gettime())))
    local total = 0
    for _, h in pairs(rec.handlers or {}) do total = total + h.ms end
    ns.Print(string.format("perf: %.0f s, ForeverDump handlers %.1f ms total = %.3f%% of wall time (gates: release <1%%, FD_Logs capture <=10%%)", dur, total,
        dur > 0 and total / (dur * 10) or 0))
    for _, h in ipairs(top) do
        ns.Print(string.format("  %-34s %6d calls  %8.2f ms  mean %.3f  max %.2f", h.key, h.n, h.ms, h.ms / math.max(h.n, 1), h.max))
    end
end

ns.captureModules = ns.captureModules or {}
table.insert(ns.captureModules, 1, { name = "self-perf monitor",
    start = function() return P.Start() end,
    stop = function()
        local r = P.Stop()
        if not r then return nil end
        local dur = r.duration or 0
        return string.format("perf %.1f ms in %d handler calls over %.0f s (%.3f%% of wall time)", r.totalMs or 0, r.totalCalls or 0, dur,
            dur > 0 and (r.totalMs or 0) / (dur * 10) or 0)
    end })
