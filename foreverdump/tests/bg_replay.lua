-- v2.2.10 real-data load replay: fire a CAPTURED event stream (tools/fdump/bgreplay.py export of runs 6/6b/8) back
-- through the whole addon in the mock client - accelerated (no real-time waits), tiled to --duration simulated seconds,
-- optionally densified (--scale 2: a second copy with raid/nameplate tokens shifted by 20 = 40-man-like load).
-- Measures: Lua memory (collectgarbage count) at --checkpoints, addon handler time per simulated second (frame cost;
-- events + OnUpdate + timers, harness excluded) for the first and last 5 minutes, ring sizes/drops, and one SV save
-- (writeSavedVariables) time + size. Writes the SavedVariables (--out) for the converter's hit/miss scoring.
-- usage: lua5.1 tests/bg_replay.lua STREAM.lua [--duration 1800] [--scale 1] [--fps 30] [--out SV.lua] [--json R.json]
--        [--no-rle] [--checkpoints 1200,1800] [--level diag] [--assert] [--group N]
-- --assert (v2.2.10 diag perf gate, in-game cost only; the frame-time limits are the perf bench's, unchanged):
--   level is diag; capture-mode impact <= 10 % overall and in the first/last 5 min; last/first 5 min ratio <= 1.5
--   (aged vs fresh); nothing lost: no safety ceiling hit, no recorder throttle drops, no tape overflow, no signal drops.
package.path = "./tests/?.lua;" .. package.path
local streamPath = arg[1]
local opts = { duration = nil, scale = 1, fps = 30, checkpoints = { 1200, 1800 }, level = "diag" }
do local i = 2 while arg[i] do
    local a, v = arg[i], arg[i + 1]
    if a == "--duration" then opts.duration = tonumber(v) i = i + 1
    elseif a == "--scale" then opts.scale = tonumber(v) i = i + 1
    elseif a == "--fps" then opts.fps = tonumber(v) i = i + 1
    elseif a == "--out" then opts.out = v i = i + 1
    elseif a == "--json" then opts.json = v i = i + 1
    elseif a == "--level" then opts.level = v i = i + 1
    elseif a == "--no-rle" then opts.norle = true
    elseif a == "--logout" then opts.logout = true          -- v2.2.11: fire PLAYER_LOGOUT (SVPack) before --out
    elseif a == "--no-svpack" then opts.nosvpack = true     -- v2.2.11 control: save without packing
    elseif a == "--group" then opts.group = tonumber(v) i = i + 1   -- v2.2.12: group size the capture had (run 9 BG: 15)
    elseif a == "--assert" then opts.assert = true
    elseif a == "--spikes" then opts.spikes = true   -- diagnostic: print every handler call >= 50 ms with its heap delta
    elseif a == "--biggest" then opts.biggest = true  -- diagnostic: list the largest single tables (one GC step each)
    elseif a == "--gc-stop" then opts.gcstop = true   -- diagnostic: no GC during the run (separates GC pauses from handler work)
    elseif a == "--dump-streams" then opts.dumpStreams = v i = i + 1
    elseif a == "--checkpoints" then opts.checkpoints = {} for x in v:gmatch("%d+") do opts.checkpoints[#opts.checkpoints + 1] = tonumber(x) end i = i + 1 end
    i = i + 1 end end

local W = require("wowenv")
local S, SECRET = W.state, W.SECRET
local chunk = assert(loadfile(streamPath))
setfenv(chunk, { X = SECRET })
local data = chunk()
local ev = data.events
local t0, tEnd = ev[1].t, ev[#ev].t
local span = tEnd - t0 + 1
local duration = opts.duration or span
local anc = data.anchor or {}
-- epoch clock tied to the captured anchor so the converter can align the replayed SV with the real combat log
if anc.epoch and anc.gameTime then
    local e0, g0 = anc.epoch, anc.gameTime
    time = function() return math.floor(e0 + (S.time - g0)) end
    GetServerTime = time
end
-- v2.2.12: group membership as captured (GetNumGroupMembers; the dm-frame rule is solo-only)
if opts.group and opts.group > 1 then
    local n = opts.group
    GetNumGroupMembers = function() return n end
    IsInGroup = function() return true end
    IsInRaid = function() return n > 5 end
end
-- timers at simulated time (the mock runs them on the next tick)
local delayed = {}
C_Timer.After = function(sec, fn) delayed[#delayed + 1] = { at = S.time + (tonumber(sec) or 0), fn = fn } end
local tickers = {}
C_Timer.NewTicker = function(sec, fn)
    local tk = { sec = sec, fn = fn, next = S.time + sec }
    tk.Cancel = function() tk.cancelled = true end
    tickers[#tickers + 1] = tk
    return tk
end

local function tocFiles(dir)
    local files = {}
    for line in io.lines(dir .. "/ForeverDump.toc") do
        if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    end
    return files
end
S.time = t0 - 10
local ns = W.loadAddon("ForeverDump", tocFiles("ForeverDump"), "ForeverDump")
if opts.norle then ns.RLE = nil end
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
ns.config.logs.fullDump = false
ns.config.logs.autoReload = false
ns.config.static = ns.config.static or {}
ns.config.static.auto = false
if ns.config.replay then ns.config.replay.captureLevel = opts.level end

local addonMs = 0
local clock = os.clock
local function timed(fn, ...)
    local c0 = clock()
    fn(...)
    addonMs = addonMs + (clock() - c0) * 1000
end
local frameDt = 1 / opts.fps
local nextFrame = S.time
local function frames(untilT)
    while nextFrame <= untilT do
        S.time = nextFrame
        for f, fn in pairs(S.onUpdate) do
            if f.__scripts and f.__scripts.OnUpdate == fn then timed(fn, f, frameDt) else S.onUpdate[f] = nil end
        end
        local q = S.timers
        S.timers = {}
        for _, fn in ipairs(q) do timed(fn) end
        if #delayed > 0 then
            local due, keep = {}, {}
            for _, d in ipairs(delayed) do if d.at <= S.time then due[#due + 1] = d else keep[#keep + 1] = d end end
            delayed = keep
            table.sort(due, function(x, y) return x.at < y.at end)
            for _, d in ipairs(due) do timed(d.fn) end
        end
        for _, tk in ipairs(tickers) do
            if not tk.cancelled and tk.next <= S.time then tk.next = tk.next + tk.sec timed(tk.fn) end
        end
        nextFrame = nextFrame + frameDt
    end
    S.time = math.max(S.time, untilT)
end

frames(t0 - 8)
collectgarbage("collect")
local memBaseKB = collectgarbage("count")   -- stream + mock + idle addon (excluded from the capture delta)
if opts.gcstop then collectgarbage("stop") end
if opts.spikes and ns.Perf then
    local run = ns.Perf.Run
    ns.Perf.Run = function(key, fn, ...)
        local k0, c0 = collectgarbage("count"), os.clock()
        local a, b = run(key, fn, ...)
        local ms = (os.clock() - c0) * 1000
        if ms >= 50 then print(string.format("  spike %s %.1f ms heap %+.0f KB (now %.0f MB)", key, ms, collectgarbage("count") - k0, collectgarbage("count") / 1024)) end
        return a, b
    end
end
W.slash("logs on")
frames(t0 - 0.5)

local function shifted(a, n, k)
    local u = a[1]
    if type(u) ~= "string" then return nil end
    local fam, num = u:match("^(raid)(%d+)$")
    if not fam then fam, num = u:match("^(raidpet)(%d+)$") end
    if not fam then fam, num = u:match("^(nameplate)(%d+)$") end
    if not fam then return nil end
    local b = {}
    for i = 1, n do b[i] = a[i] end
    b[1] = fam .. (tonumber(num) + 20 * (k or 1))
    return b
end

local fired, wall0 = 0, clock()
local cps, cpi = {}, 1
local window = { first = { ms = 0, sec = 0 }, last = { ms = 0, sec = 0 } }
local simStart = t0
local tile = 0
local function memKB() if opts.gcstop then return collectgarbage("count") end collectgarbage("collect") return collectgarbage("count") end
local done = false
while not done do
    local off = tile * span
    for _, e in ipairs(ev) do
        local tt = e.t + off
        local el = tt - simStart
        if el >= duration then done = true break end
        while opts.checkpoints[cpi] and el >= opts.checkpoints[cpi] do
            cps[#cps + 1] = { sec = opts.checkpoints[cpi], memKB = memKB(), fired = fired, addonMs = addonMs }
            cpi = cpi + 1
        end
        local ms0 = addonMs
        frames(tt)
        S.combat = e.c and true or false
        timed(W.fire, e.e, unpack(e.a, 1, e.n))
        fired = fired + 1
        if opts.scale and opts.scale >= 2 then
            -- v2.2.11: --scale N fires N-1 shifted copies (token +20, +40, ...) - 10x density for the SV-load gate
            for k = 1, math.floor(opts.scale) - 1 do
                local b = shifted(e.a, e.n, k)
                if b then timed(W.fire, e.e, unpack(b, 1, e.n)) fired = fired + 1 end
            end
        end
        if el < 300 then window.first.ms = window.first.ms + (addonMs - ms0) end
        if el >= duration - 300 then window.last.ms = window.last.ms + (addonMs - ms0) end
    end
    tile = tile + 1
    if tile * span > duration + span then done = true end
end
local simEnd = math.min(duration, tile * span)
while opts.checkpoints[cpi] and opts.checkpoints[cpi] <= simEnd + 1 do
    cps[#cps + 1] = { sec = opts.checkpoints[cpi], memKB = memKB(), fired = fired, addonMs = addonMs }
    cpi = cpi + 1
end
window.first.sec, window.last.sec = math.min(300, simEnd), math.min(300, simEnd)
local memBeforeOff = memKB()
local level = ns.ReplayLog and ns.ReplayLog.Level and ns.ReplayLog.Level()
local cur = ForeverDumpLogDB and ForeverDumpLogDB.replay and ForeverDumpLogDB.replay.current
local tapeRows = cur and cur.n or 0
local tapeDropped = cur and (cur.overflow or 0) or 0
-- leave combat first (a stream/tile can end mid-fight; FD_Logs refuses to stop in combat)
if S.combat then S.combat = false W.fire("PLAYER_REGEN_ENABLED") end
frames(S.time + 1)
W.slash("logs off")
frames(S.time + 3)
if opts.biggest then
    local seen, top = {}, {}
    local function walk(t, path, depth)
        if seen[t] or depth > 8 then return end
        seen[t] = true
        local n = 0
        for k, v in pairs(t) do
            n = n + 1
            if type(v) == "table" then walk(v, path .. "." .. tostring(k):sub(1, 30), depth + 1) end
        end
        if n >= 20000 then top[#top + 1] = { path, n } end
    end
    walk(_G, "_G", 0)
    table.sort(top, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(15, #top) do print(string.format("  big %8d %s", top[i][2], top[i][1])) end
end
local res = { stream = streamPath, events = #ev, fired = fired, tiles = tile, simSec = simEnd, scale = opts.scale,
    level = level, rle = not opts.norle, wallSec = clock() - wall0, addonMs = addonMs,
    impactPct = addonMs / (simEnd * 1000) * 100, firstImpactPct = window.first.ms / (window.first.sec * 1000) * 100,
    lastImpactPct = window.last.ms / (window.last.sec * 1000) * 100, checkpoints = cps, memBeforeOffKB = memBeforeOff, memBaseKB = memBaseKB,
    tapeRows = tapeRows, tapeDropped = tapeDropped }
local cls = ForeverDumpCombatLogDB.sessions
local cs = cls[#cls]
if not cs then io.stderr:write("no combat session; chat: " .. table.concat(W.chat or {}, " / "):sub(1, 2000) .. "\n") end
res.combatKept, res.combatOverwritten, res.combatTotal = #(cs.events or {}), cs.overwritten, cs.total
res.combatRle = cs.rle
local rss = ForeverDumpRecordDB.sessions
local rs = rss[#rss]
res.recordKept, res.recordOverwritten, res.recordDropped = #(rs.events or {}), rs.overwritten, 0
for _, v in pairs(rs.dropped or {}) do res.recordDropped = res.recordDropped + v end
res.recordRle = rs.rle
local rp = ForeverDumpLogDB.replay.sessions
local last = rp[#rp]
res.tapeKept, res.tapeOverflow, res.tapeRle, res.ceilingHit = last.n, last.overflow, last.rle, last.ceilingHit
res.signalsDropped = ForeverDumpLogDB.inference and ForeverDumpLogDB.inference.signalsDropped or 0
if opts.out then
    local s0 = clock()
    if opts.logout then
        if opts.nosvpack then ns.config.svpack = false end
        local names = { "ForeverDumpDB", "ForeverDumpLogDB", "ForeverDumpRecordDB", "ForeverDumpCombatLogDB" }
        local before = {}
        for _, n in ipairs(names) do before[n] = _G[n] end
        W.fire("PLAYER_LOGOUT")
        res.logoutMs = (clock() - s0) * 1000
        res.svpack = ns.SVPack and ns.SVPack.lastPack
        if ns.SVPack and not opts.nosvpack then
            -- lossless: unpack a copy of what will be written and compare with the live (final) tables
            local P = ns.SVPack
            local function eq(a, b)
                if type(a) ~= type(b) then return false end
                if type(a) == "number" then return a == b or (a ~= a and b ~= b) end
                if type(a) ~= "table" then return a == b end
                for k, v in pairs(a) do if type(v) ~= "function" and not eq(v, b[k]) then return false end end
                for k in pairs(b) do if a[k] == nil then return false end end
                return true
            end
            res.svpackExact, res.svpackPacked = true, 0
            for _, n in ipairs(names) do
                local cv = _G[n]
                if P.IsPacked(cv) then
                    res.svpackPacked = res.svpackPacked + 1
                    local t = P.UnpackValue(cv)
                    if not (t and eq(before[n], t)) then res.svpackExact = false end
                end
            end
        end
        s0 = clock()
    end
    W.writeSavedVariables(opts.out, { "ForeverDumpDB", "ForeverDumpLogDB", "ForeverDumpRecordDB", "ForeverDumpCombatLogDB" })
    res.saveMs = (clock() - s0) * 1000
    local f = io.open(opts.out, "rb")
    res.svBytes = f:seek("end")
    f:close()
end
local function jstr(v)
    return '"' .. tostring(v):gsub('[%c"\\\128-\255]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end
local function js(v)
    local t = type(v)
    if t == "table" then
        local isArr = #v > 0
        local o = {}
        if isArr then for _, x in ipairs(v) do o[#o + 1] = js(x) end return "[" .. table.concat(o, ",") .. "]" end
        for k, x in pairs(v) do o[#o + 1] = jstr(k) .. ":" .. js(x) end
        return "{" .. table.concat(o, ",") .. "}"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        if v == math.floor(v) and math.abs(v) < 2^53 then return string.format("%d", v) end
        return string.format("%.17g", v)
    elseif t == "string" then return jstr(v)
    elseif t == "boolean" then return tostring(v) end
    return "null"
end
if opts.json then local f = assert(io.open(opts.json, "w")) f:write(js(res)) f:close() end
-- --dump-streams FILE: combat ring + recorder rows + tape dm rows as JSON lines, args exact up to n (round-trip test)
if opts.dumpStreams then
    local f = assert(io.open(opts.dumpStreams, "w"))
    local function row(kind, r)
        local o = {}
        for k, v in pairs(r) do
            if k == "a" and type(v) == "table" then
                local n = r.n or #v
                local parts = {}
                for i = 1, n do parts[i] = js(v[i]) end
                o[#o + 1] = '"a":[' .. table.concat(parts, ",") .. "]"
            elseif k == "t" then o[#o + 1] = string.format('"t":%.3f', v)
            else o[#o + 1] = jstr(k) .. ":" .. js(v) end
        end
        f:write('{"stream":' .. jstr(kind) .. ',"r":{' .. table.concat(o, ",") .. '}}\n')
    end
    for _, r in ipairs(cs.events or {}) do row("combat", r) end
    for _, r in ipairs(rs.events or {}) do row("record", r) end
    local tp = {}
    for _, r in pairs(last.tape or {}) do tp[#tp + 1] = r end
    table.sort(tp, function(x, y) return x.i < y.i end)
    for _, r in ipairs(tp) do row("tape", r) end
    f:close()
end
print(string.format("bg_replay %s: %d events fired (%d tiles, scale %d) over %.0f sim s in %.1f s wall; level=%s rle=%s; "
    .. "impact %.3f%% (first 5 min %.3f%%, last 5 min %.3f%%); mem %s; combat kept %d (rle folded %s), record kept %d dropped %d, "
    .. "tape %d overflow %d; save %.0f ms, SV %.1f MB",
    streamPath, fired, tile, opts.scale, simEnd, res.wallSec, tostring(level), tostring(res.rle), res.impactPct, res.firstImpactPct,
    res.lastImpactPct, (function() local o = {} for _, c in ipairs(cps) do o[#o + 1] = string.format("%ds=+%.1fMB", c.sec, (c.memKB - memBaseKB) / 1024) end return table.concat(o, " ") end)(),
    res.combatKept, tostring(res.combatRle and res.combatRle.folded), res.recordKept, res.recordDropped, res.tapeKept or 0,
    res.tapeOverflow or 0, res.saveMs or -1, (res.svBytes or 0) / 1048576))
if opts.assert then
    local fails = 0
    local function check(c, m) if c then print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
    -- v2.2.15 (user decision 2026-10-09): level lab = perf MEASURED and REPORTED, not gated, except the runaway
    -- backstop; the diag gates below are unchanged and still run at diag (tests/bg_replay_gate.py default)
    local lab = opts.level == "lab"
    local function gate(c, m) if lab then print("  info " .. m .. (c and "" or "  [over the diag limit; lab = report only]")) else check(c, m) end end
    check(level == opts.level, "measured at the requested capture level " .. tostring(opts.level) .. " (got " .. tostring(level) .. ")")
    check(simEnd >= 1200, string.format("load test spans >= 20 sim min (%.0f s)", simEnd))
    gate(res.impactPct <= 10, string.format("capture-mode impact %.3f%% <= 10%% (whole run)", res.impactPct))
    gate(res.firstImpactPct <= 10 and res.lastImpactPct <= 10, string.format("first/last 5 min impact %.3f%% / %.3f%% <= 10%%",
        res.firstImpactPct, res.lastImpactPct))
    gate(res.lastImpactPct <= 1.5 * res.firstImpactPct, string.format("aged/fresh: last 5 min %.3f%% <= 1.5 x first 5 min %.3f%% (ratio %.2f)",
        res.lastImpactPct, res.firstImpactPct, res.lastImpactPct / math.max(res.firstImpactPct, 1e-9)))
    gate(not res.ceilingHit, "no diag safety ceiling hit")
    do
        local P = ns.Perf
        local sess = ForeverDumpLogDB.perf and ForeverDumpLogDB.perf.sessions
        local ps = sess and sess[#sess]
        local worst, wkey = 0, nil
        local labMs = {}
        for k, h in pairs(ps and ps.handlers or {}) do
            if (h.max or 0) > worst then worst, wkey = h.max, k end
            local fam = k:match("^Lab") and "Lab" or (k:match("^Probe") and "Probe") or nil
            if fam then labMs[fam] = (labMs[fam] or 0) + (h.ms or 0) end
        end
        local top = {}
        for k, h in pairs(ps and ps.handlers or {}) do top[#top + 1] = { k, h.max or 0, h.n or 0 } end
        table.sort(top, function(x, y) return x[2] > y[2] end)
        local parts = {}
        for i = 1, math.min(6, #top) do parts[i] = string.format("%s %.1f", top[i][1], top[i][2]) end
        print("  info top single calls (ms): " .. table.concat(parts, ", "))
        print(string.format("  info lab: worst single call %.2f ms (%s); lab probes %.1f ms total; staged probe %.1f ms total",
            worst, tostring(wkey), labMs.Lab or 0, labMs.Probe or 0))
        local cand = ForeverDumpLogDB.inference and ForeverDumpLogDB.inference.cand
        for fam, c in pairs(cand and cand.cost or {}) do
            print(string.format("  info shadow rules %-12s n=%d total %.2f ms max %.3f ms", fam, c.n or 0, c.ms or 0, c.max or 0))
        end
        if lab then
            -- user decision 2026-10-09: at lab the backstop is a report (warning + SV record), not a failure
            print("  info backstop " .. ((P and P.runaway) and "TRIPPED (reported)" or "not tripped"))
            local spk = ps and ps.spikes
            if spk then print(string.format("  info spikes >= 50 ms: %d (gc-attributed %d, own work %d)", spk.n, spk.gc, spk.own)) end
            -- mock: the worst calls are Lua 5.1 incremental-GC atomic steps (rows appended during a long cycle are
            -- re-traversed at once; --gc-stop removes them, --spikes shows them); the handlers' own work is < 10 ms
            print(string.format("  info single-call worst %.2f ms (report only at lab)", worst))
        end
    end
    check((res.recordDropped or 0) == 0, "recorder dropped nothing (" .. tostring(res.recordDropped) .. ")")
    check((res.tapeOverflow or 0) == 0 and (tapeDropped or 0) == 0, "tape overflow 0")
    check((res.signalsDropped or 0) == 0, "signals dropped 0")
    print(fails == 0 and "BG REPLAY PERF OK" or ("BG REPLAY PERF FAILED (" .. fails .. ")"))
    os.exit(fails == 0 and 0 or 1)
end
