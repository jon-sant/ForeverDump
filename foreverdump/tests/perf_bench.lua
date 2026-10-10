-- ForeverDump performance benchmark / regression test (v2.2.3, run 4: "frame rate drops the more I cast").
-- Loads the addon in the mock client with a realistic global table (52,517 globals, as on Forever 70245 with a
-- normal addon set), starts an FD_Logs capture, enters combat and simulates N casts (UNIT_SPELLCAST_SUCCEEDED +
-- UNIT_AURA + UNIT_HEALTH/POWER per cast, 1.5 s apart, 60 frames/s of OnUpdate for SHOWN frames, C_Timer timers and
-- 1 s tickers). Only ForeverDump's handlers are timed (os.clock around the OnEvent/OnUpdate calls; the mock's
-- dispatch is excluded).
-- Reports per window of 25 casts ending at N = 50 / 200 / 1000: mean cost per event, per frame, ms per simulated
-- second and the share of wall time (= frame-time impact). Then 700 s idle: number of OnUpdate scripts still running.
-- usage: lua5.1 tests/perf_bench.lua ADDON_DIR [--assert] [--json FILE] [--casts 100] [--aged 2000] [--cap 100] [--fps 60]
-- Defaults keep every run under the 2-minute rule (PERFORMANCE.md): checkpoints at 25 / 50 / 75 / 100 casts (25-cast windows),
-- then an "aged" checkpoint: --aged more casts are pushed through the event handlers without frames (session state of a
-- ~2,100-cast session in about a second) and five more 25-cast windows are measured. --cap is a hard wall-clock limit in
-- seconds (default 100): the run aborts, prints the trend measured so far and, with --assert, fails if the cap was hit.
-- --assert enforces PERFORMANCE.md + the v2.2.4 perf gate: O(1) Lua instructions per event / frame and garbage per event
-- (aged vs 25 casts), aged/fresh frame-time impact ratio <= 1.5 (medians of the fresh and aged windows), impact < 1 % at
-- every checkpoint, SPELL_UPDATE_COOLDOWN storm <= 0.5 % (median of 3 windows; raw windows logged), 40-man scanner slice max <= its budget
-- (median of N=5 runs' per-run max and p99; every raw run logged; budget exact, no slack),
-- no idle OnUpdate, run finished inside the cap.
package.path = "./tests/?.lua;" .. package.path
-- Allocator: glibc's fastbins make the FIRST large (>= 1 KB) malloc after a big free consolidate every freed small chunk,
-- O(heap). The aged phase frees a large heap (full collect per window), so whichever handler next allocated a >= 1 KB
-- block (a table resize, a 2.7 KB string) paid 5-130 ms: a host-allocator artifact that looked like "cost grows with
-- history" (v2.2.4 perf gate; WoW uses its own allocator). The bench re-executes itself with fastbins disabled so
-- wall-clock numbers measure ForeverDump, not glibc. FD_BENCH_ALLOC=native keeps the default allocator (comparison).
if not os.getenv("FD_BENCH_REEXEC") and os.getenv("FD_BENCH_ALLOC") ~= "native" and not (os.getenv("GLIBC_TUNABLES") or ""):find("mxfast") then
    local interp = arg[-1] or "lua5.1"
    local q = {}
    for i = 0, #arg do q[#q + 1] = "'" .. tostring(arg[i]):gsub("'", "'\\''") .. "'" end
    local rc = os.execute("FD_BENCH_REEXEC=1 GLIBC_TUNABLES=glibc.malloc.mxfast=0 " .. interp .. " " .. table.concat(q, " "))
    if type(rc) == "number" then rc = (rc >= 256) and math.floor(rc / 256) or rc else rc = rc and 0 or 1 end
    os.exit(rc)
end
local addonDir = arg[1] or "ForeverDump"
local opts = { casts = 100, fps = 60, aged = 2000, cap = 100, level = "diag" }
local wall0 = os.time()
do local i = 2 while arg[i] do
    if arg[i] == "--assert" then opts.assert = true
    elseif arg[i] == "--json" then opts.json = arg[i + 1] i = i + 1
    elseif arg[i] == "--casts" then opts.casts = tonumber(arg[i + 1]) i = i + 1
    elseif arg[i] == "--keys" then opts.keys = true
    elseif arg[i] == "--no-storm" then opts.nostorm = true
    elseif arg[i] == "--no-raid" then opts.noraid = true
    elseif arg[i] == "--marks" then opts.marks = arg[i + 1] i = i + 1
    elseif arg[i] == "--win" then opts.win = tonumber(arg[i + 1]) i = i + 1
    elseif arg[i] == "--aged" then opts.aged = tonumber(arg[i + 1]) i = i + 1
    elseif arg[i] == "--cap" then opts.cap = tonumber(arg[i + 1]) i = i + 1
    elseif arg[i] == "--fps" then opts.fps = tonumber(arg[i + 1]) i = i + 1
    elseif arg[i] == "--level" then opts.level = arg[i + 1] i = i + 1 end
    i = i + 1 end end

local W = require("wowenv")
local S, SECRET = W.state, W.SECRET
-- realistic _G size (the run-4 SV counted 52,517 globals)
local nG = 0
for k in pairs(_G) do if k then nG = nG + 1 end end
for i = 1, 52517 - nG do
    local m = i % 3
    _G["BenchGlobal_" .. i] = (m == 0 and {}) or (m == 1 and function() end) or i
end
-- tickers (missing in the mock): chained per simulated second
local tickers = {}
C_Timer.NewTicker = function(sec, fn)
    local t = { sec = sec, fn = fn, next = S.time + sec }
    t.Cancel = function() t.cancelled = true end
    tickers[#tickers + 1] = t
    return t
end
UnitExists = function(u) return u == "player" or u == "target" or u == "nameplate1" end
UnitCanAttack = function(_, u) return u == "target" or u == "nameplate1" end
UnitIsUnit = function(u1, u2) return u1 == u2 or (S.combat and SECRET or false) end
UnitIsPlayer = function(u) return u == "player" end
UnitHealthMax = function() return 1345 end
UnitHealth = function() return SECRET end
UnitGUID = function(u) if u == "player" then return "Player-1234-0ABCDEF0" end if u == "target" then return "Creature-0-1-2-3-3100-0000AAAA" end return SECRET end
C_UnitAuras.GetAuraSlots = function() if S.combat then error("Auras cannot be accessed when secret while tainted by 'ForeverDump'") end return nil end
C_UnitAuras.GetAuraDataByIndex = function() if S.combat then error("Auras cannot be accessed when secret while tainted by 'ForeverDump'") end end
local SPELLS = { 905, 8052, 8044, 403, 8160, 1238640 }
local DESC = { [905] = "The caster is surrounded by 3 balls of lightning. Lasts 10 min.",
    [8052] = "Instantly sears the target with fire, causing 38 Fire damage immediately and 32 Fire damage over 12 sec.",
    [8044] = "Instantly shocks the target with concussive force, causing 35 to 38 Nature damage.",
    [403] = "Casts a bolt of lightning at the target for 15 to 17 Nature damage.",
    [8160] = "Summons a Strength of Earth Totem with 5 health at the feet of the caster for 2 min.",
    [1238640] = "Turns the Shaman into a Ghost Wolf, increasing speed by 40%." }
C_Spell.GetSpellDescription = function(id) if S.combat then return SECRET end return DESC[id] or "Does something." end
C_Spell.GetSpellInfo = function(id) return { name = "Spell" .. id, iconID = 1, castTime = id == 403 and 2000 or 0, minRange = 0, maxRange = 30, spellID = id } end
GetSpellBaseCooldown = function(id)
    if id >= 5001 and id <= 5050 then return 60000, 1500 end   -- SPELL_UPDATE_COOLDOWN storm spells (1 min cooldowns)
    return (id == 8052 or id == 8044) and 6000 or 0, 1500
end
-- CooldownTracker reads: isActive / isOnGCD clear, startTime / duration / modRate secret in combat (run 5)
local CDUNTIL = {}
C_Spell.GetSpellCooldown = function(id)
    local active = (CDUNTIL[id] or 0) > S.time
    if S.combat then return { isActive = active, isOnGCD = false, isEnabled = true, startTime = SECRET, duration = SECRET, modRate = SECRET } end
    return { isActive = active, isOnGCD = false, isEnabled = true, startTime = active and CDUNTIL[id] - 60 or 0, duration = active and 60 or 0, modRate = 1 }
end
C_Spell.IsSpellHelpful = function(id) return id == 905 or id == 1238640 or id == 8160 end
C_Spell.IsSpellHarmful = function(id) return id == 8052 or id == 8044 or id == 403 end

local function tocFiles(dir)
    local files = {}
    for line in io.lines(dir .. "/ForeverDump.toc") do
        if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
    end
    return files
end
local ns = W.loadAddon(addonDir, tocFiles(addonDir), "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
ns.config.logs.fullDump = false
-- v2.2.7: the one-time static dump moved from FD_Logs ON to the login signature check. The bench measures steady-state
-- handler cost, so it keeps excluding that one-off job exactly as before (logs.fullDump = false did it until 2.2.6).
-- Its scheduling (never in combat, never during a capture, once per signature) is gated in tests/static_once.lua.
ns.config.static = ns.config.static or {}
ns.config.static.auto = false
ns.config.logs.autoReload = false
ns.config.probe.spells = SPELLS
if ns.config.knowledge then ns.config.knowledge.maxSpells = 20 end
-- spell list for the knowledge pass
if ns.Knowledge then ns.Knowledge.SpellList = function() return SPELLS end end
-- C_Timer.After with real delays (the mock runs every timer on the next tick, which would make the 5 s perf sampler
-- run every frame here)
-- Lua instruction counter (deterministic O(1) check) around the addon's own callbacks only, not the harness loops
local insN = 0
local function insHook() insN = insN + 1 end
local frAcc = 0   -- ms spent inside the addon's own frame callbacks (OnUpdate / timers / tickers); harness loops excluded
local function addonCall(fn, ...)
    debug.sethook(insHook, "", 100)
    local c0 = os.clock()
    fn(...)
    frAcc = frAcc + (os.clock() - c0) * 1000
    debug.sethook()
end
local delayed = {}
C_Timer.After = function(sec, fn) delayed[#delayed + 1] = { at = S.time + (tonumber(sec) or 0), fn = fn } end
local function runDelayed()
    local due, keep = {}, {}
    for _, d in ipairs(delayed) do if d.at <= S.time then due[#due + 1] = d else keep[#keep + 1] = d end end
    delayed = keep
    table.sort(due, function(x, y) return x.at < y.at end)
    for _, d in ipairs(due) do addonCall(d.fn) end
end
-- v2.2.15: the FD_Logs default became lab (user decision 2026-10-09); the capture gates stay measured at diag, set
-- explicitly (--level lab = report-only run, see the assert block)
if ns.config.replay then ns.config.replay.captureLevel = opts.level end
W.slash("logs on")
for _ = 1, 60 do S.time = S.time + 0.05 runDelayed() W.tick(1) end
-- v2.2.9: FD_Logs ON raises to the DEFAULT capture level (diag); every capture gate below is measured at that level
local CAPTURE_LEVEL = ns.ReplayLog and ns.ReplayLog.Level and ns.ReplayLog.Level() or "?"
io.stdout:write("capture level during the bench: " .. tostring(CAPTURE_LEVEL) .. "\n")

-- timing helpers: only ForeverDump's handlers
local clock = os.clock
local evMs, evN, frMs, frN = 0, 0, 0, 0
local function handlersFor(event)
    local list = {}
    for _, f in ipairs(S.frames) do
        if (f.__all or (f.__events and f.__events[event])) and f.__scripts and f.__scripts.OnEvent then list[#list + 1] = f end
    end
    return list
end
local hcache, hcacheGen = {}, 0
local win = {}   -- current measurement window (alloc + instruction counters); reset by resetWin
local function fire(event, ...)
    local list = hcache[event]
    if not list or hcacheGen ~= #S.frames then hcache = {} hcacheGen = #S.frames list = handlersFor(event) hcache[event] = list end
    local k0 = collectgarbage("count")
    local i0 = insN
    debug.sethook(insHook, "", 100)
    local t0 = clock()
    for i = 1, #list do local f = list[i] if f.__events and (f.__events[event] or f.__all) then f.__scripts.OnEvent(f, event, ...) end end
    evMs = evMs + (clock() - t0) * 1000
    debug.sethook()
    win.evIns = (win.evIns or 0) + (insN - i0)
    evN = evN + 1
    local dk = collectgarbage("count") - k0   -- a GC step inside the handler can only make this an underestimate
    if dk > 0 and win then win.alloc = (win.alloc or 0) + dk end
end
local function shown(f)
    while f do if f.__shown == false then return false end f = rawget(f, "__parent") end
    return true
end
local function activeOnUpdates()
    local n, names = 0, {}
    for f, fn in pairs(S.onUpdate) do
        if f.__scripts and f.__scripts.OnUpdate == fn and shown(f) then n = n + 1 names[#names + 1] = tostring(rawget(f, "__name") or "?") end
    end
    return n, names
end
local function frame(dt)
    S.time = S.time + dt
    local i0 = insN
    frAcc = 0
    for f, fn in pairs(S.onUpdate) do
        if f.__scripts and f.__scripts.OnUpdate == fn then
            if shown(f) then addonCall(fn, f, dt) end   -- the real client runs OnUpdate only for shown frames
        else S.onUpdate[f] = nil end
    end
    local timers = S.timers
    S.timers = {}
    for _, fn in ipairs(timers) do addonCall(fn) end
    runDelayed()
    local live = 0
    for i = 1, #tickers do
        local t = tickers[i]
        if not t.cancelled then
            live = live + 1
            tickers[live] = t
            if S.time >= t.next then t.next = math.max(t.next + t.sec, S.time) addonCall(t.fn) end   -- no catch-up burst after a time jump (as in the client)
        end
    end
    for i = live + 1, #tickers do tickers[i] = nil end   -- cancelled tickers leave the harness list (the client frees them)
    frMs = frMs + frAcc
    win.frIns = (win.frIns or 0) + (insN - i0)
    frN = frN + 1
end

-- combat
S.combat = true
fire("PLAYER_REGEN_DISABLED")
fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 2)
for _ = 1, 120 do frame(1 / opts.fps) end
local WIN = opts.win or 25   -- casts per measured window: back-to-back windows ending at 25/50/75/100 (longer windows: less wall noise)
local marks = {}
if opts.marks then
    for m in opts.marks:gmatch("%d+") do marks[tonumber(m)] = true opts.casts = math.max(tonumber(m), opts.casts) end
else
    for _, m in ipairs({ 25, 50, 75, 100 }) do if m <= opts.casts then marks[m] = true end end
    marks[opts.casts] = true
end
local results = {}
local aborted
-- GC: a full collect starts each window so debt left by an earlier phase (the storm, the aged pump) does not land in an
-- arbitrary window. Wall-clock per-frame time still wobbles with the allocator / heap (Lua instruction counts stay flat),
-- so O(1) is asserted on deterministic Lua VM instruction counts per event and per frame (count hook, every 100
-- instructions) and the frame-time impact (< 1%) on os.clock time. Garbage: KB allocated per event (O(1)).
local function resetWin()
    collectgarbage("collect")
    evMs, evN, frMs, frN = 0, 0, 0, 0 win.t0 = S.time win.alloc = 0 win.evIns, win.frIns = 0, 0
end
local function endWin() return win.alloc or 0 end
local function overCap() return os.time() - wall0 >= opts.cap end
local function castEvents(n)
    local sid = SPELLS[(n - 1) % #SPELLS + 1]
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. n, sid)
    fire("UNIT_AURA", "target", { isFullUpdate = SECRET, addedAuras = SECRET })
    fire("UNIT_AURA", "player", { isFullUpdate = SECRET, updatedAuraInstanceIDs = SECRET })
    for _ = 1, 3 do fire("UNIT_HEALTH", "target") fire("UNIT_POWER_FREQUENT", "player", "MANA") end
    -- v2.2.4 (run 5 mix): per cast ~5 DAMAGE_METER updates, UNIT_COMBAT on target + 3 other tokens + player, a swing
    for ty = 0, 4 do fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", ty % 2 == 0 and 0 or 1, 3) end
    for _, u in ipairs({ "target", "nameplate1", "softenemy", "targettarget" }) do fire("UNIT_COMBAT", u, "WOUND", "", 120, 16) end
    fire("UNIT_COMBAT", "player", "HEAL", "", 6, 8)
    fire("PLAYER_SWING", 3.3, 0)
    fire("SPELL_UPDATE_COOLDOWN")
    -- v2.2.4 identity ledger: target swaps its target + a plate shows up per cast (chained-token reads, plate map)
    -- v2.2.4 MINOR 4 + live verification: enemy cast timing, my failed press, player health events
    fire("UNIT_SPELLCAST_START", "target", SECRET, SECRET, "CastBar-" .. n)
    fire("UNIT_SPELLCAST_SUCCEEDED", "target", SECRET, SECRET, "CastBar-" .. n)
    fire("UNIT_SPELLCAST_FAILED", "player", "Cast-F" .. n, sid)
    fire("UNIT_HEALTH", "player")
    fire("UNIT_TARGET", "target")
    fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. (n % 40 + 1))
    fire("NAME_PLATE_UNIT_REMOVED", "nameplate" .. ((n + 20) % 40 + 1))
end
local function mark(label, n)
    local simS = math.max(S.time - win.t0, 1e-6)
    local tot = evMs + frMs
    local kb = endWin()
    results[#results + 1] = { label = label, casts = n, perEventMs = evMs / math.max(evN, 1), perFrameMs = frMs / math.max(frN, 1),
        kbPerEvent = kb / math.max(evN, 1), insPerEvent = 100 * (win.evIns or 0) / math.max(evN, 1),
        insPerFrame = 100 * (win.frIns or 0) / math.max(frN, 1), pendingTimers = #delayed, tickers = #tickers,
        msPerSec = tot / simS, impactPct = tot / simS / 10, events = evN, frames = frN,
        predictions = ns.Inference.hs and #ns.Inference.hs.predictions or 0, wall = os.time() - wall0 }
    io.stdout:write(string.format("  checkpoint %-6s casts=%-5d %.4f ms/event %.4f ms/frame  (%ds wall)\n", label, n,
        results[#results].perEventMs, results[#results].perFrameMs, os.time() - wall0))
    io.stdout:flush()
end
resetWin()
local n = 0
while n < opts.casts do
    n = n + 1
    if marks[n + WIN - 1] or n == 1 then resetWin() end
    castEvents(n)
    for _ = 1, math.floor(1.5 * opts.fps + 0.5) do frame(1 / opts.fps) end
    if marks[n] then mark(tostring(n), n) end
    if overCap() then aborted = n break end
end
-- SPELL_UPDATE_COOLDOWN storm: 50 spells cooling at once, then one SPELL_UPDATE_COOLDOWN every frame (60/s, ~10x a real
-- rotation) for 10 sim-seconds. Each event re-checks only the cooling set (O(k), k = 50; same-frame events coalesce).
local storm
if not aborted and not opts.nostorm then
    local hs0 = ns.Inference.hs
    for i = 1, 50 do   -- spellbook knowledge (built out of combat in game): 1 min cooldown, 1.5 s GCD
        if hs0 and hs0.Learn then hs0:Learn(5000 + i, { cooldown = 60, gcd = 1.5 }) end
    end
    for i = 1, 50 do
        local id = 5000 + i
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Storm-" .. i, id)
        CDUNTIL[id] = S.time + 60
        fire("SPELL_UPDATE_COOLDOWN", id, nil, i % 5 == 0 and 19 or 0, 133, nil)
        frame(1 / opts.fps)
    end
    local hs = ns.Inference.hs
    local k = hs and hs.CDActive and #hs:CDActive() or 0
    -- three 10 s windows, median reported (wall-clock noise on a shared host is +-15 % per window)
    local wins = {}
    for _ = 1, 3 do
        resetWin()
        for f = 1, 10 * opts.fps do
            fire("SPELL_UPDATE_COOLDOWN", 5000 + (f % 50) + 1, nil, 0, 133, nil)
            frame(1 / opts.fps)
        end
        local simS = math.max(S.time - win.t0, 1e-6)
        endWin()
        wins[#wins + 1] = { events = evN, perEventMs = evMs / math.max(evN, 1), impactPct = (evMs + frMs) / simS / 10 }
    end
    table.sort(wins, function(x, y) return x.impactPct < y.impactPct end)
    storm = wins[2]
    storm.k = k
    storm.windows = { wins[1].impactPct, wins[2].impactPct, wins[3].impactPct }
    io.stdout:write(string.format("  storm  cooling=%d  %d SPELL_UPDATE_COOLDOWN/window  %.4f ms/event  impact %.3f%% (median of %.3f/%.3f/%.3f)\n",
        k, storm.events, storm.perEventMs, storm.impactPct, wins[1].impactPct, wins[2].impactPct, wins[3].impactPct))
    for i = 1, 50 do CDUNTIL[5000 + i] = nil end
end
-- 40-man battleground: raid1-40 (+ raidNtarget) exist, BG detected as raid in a pvp instance; the discovery scanner
-- sweeps ~420 tokens under its per-slice time budget while raid members cast (Learned DB + alias learning see every cast).
local raid40
if not aborted and not opts.noraid then
    -- median helper (odd N preferred); percentile on a copy so callers keep their own order
    local function medianOf(xs)
        local t = {} for i = 1, #xs do t[i] = xs[i] end
        table.sort(t)
        local cnt = #t
        if cnt == 0 then return 0 end
        if cnt % 2 == 1 then return t[(cnt + 1) / 2] end
        return (t[cnt / 2] + t[cnt / 2 + 1]) / 2
    end
    local function pctOf(xs, p)
        local t = {} for i = 1, #xs do t[i] = xs[i] end
        table.sort(t)
        if #t == 0 then return 0 end
        local i = math.max(1, math.min(#t, math.ceil(#t * p / 100)))
        return t[i]
    end
    local RAID = true
    local baseExists, baseGUID, baseName = UnitExists, UnitGUID, UnitName
    IsInRaid = function() return RAID end
    IsInGroup = function() return RAID end
    GetNumGroupMembers = function() return RAID and 40 or 0 end
    IsInInstance = function() return RAID, RAID and "pvp" or "none" end
    UnitExists = function(u)
        local ri = RAID and tonumber(u:match("^raid(%d+)$") or u:match("^raid(%d+)target$") or "")
        if ri then return ri <= 40 end
        return baseExists(u)
    end
    UnitGUID = function(u)
        local ri = RAID and tonumber(u:match("^raid(%d+)$") or "")
        if ri then return string.format("Player-1234-%08X", ri) end
        if RAID and u:match("^raid%d+target$") then return S.combat and SECRET or "Creature-0-1-2-3-3100-0000AAAA" end
        return baseGUID(u)
    end
    UnitName = function(u) if RAID and u:match("^raid%d+$") then return "Member" end return baseName(u) end
    fire("GROUP_ROSTER_UPDATE")
    local Scan = ns.Tokens and ns.Tokens.Scan
    local sc = Scan and Scan.cur
    local NRUN = 5
    local rawMax, rawP99, rawImpact, rawScanPct = {}, {}, {}, {}
    local lastMeta = {}
    -- wrap Slice so each run can compute p99 of per-slice wall time without changing Tokens.lua
    local realSlice = Scan and Scan.Slice
    local sliceSamples
    if realSlice then
        Scan.Slice = function()
            local before = (sc and sc.ms) or 0
            realSlice()
            if sliceSamples and sc then sliceSamples[#sliceSamples + 1] = (sc.ms or 0) - before end
        end
    end
    for run = 1, NRUN do
        local s0 = sc and { ms = sc.ms, tokens = sc.tokens, sweeps = sc.sweeps, slices = sc.slices } or {}
        if sc then sc.maxSliceMs = 0 end
        sliceSamples = {}
        resetWin()
        local k = 0
        for _ = 1, 30 do                       -- 30 simulated seconds, 4 raid casts per second
            for _ = 1, 4 do
                k = k + 1
                local u = "raid" .. (k % 40 + 1)
                fire("UNIT_SPELLCAST_START", u, "RaidCast-" .. k, 403)
                fire("UNIT_TARGET", u)
                for _ = 1, math.floor(opts.fps / 4) do frame(1 / opts.fps) end
                fire("UNIT_SPELLCAST_SUCCEEDED", u, "RaidCast-" .. k, 403)
            end
        end
        local simS = math.max(S.time - win.t0, 1e-6)
        local impact = (evMs + frMs) / simS / 10
        endWin()
        local mx = sc and sc.maxSliceMs or 0
        local p99 = pctOf(sliceSamples, 99)
        rawMax[#rawMax + 1] = mx
        rawP99[#rawP99 + 1] = p99
        rawImpact[#rawImpact + 1] = impact
        local scanMs = sc and (sc.ms - (s0.ms or 0)) or 0
        local scanPct = scanMs / simS / 10
        rawScanPct[#rawScanPct + 1] = scanPct
        lastMeta = {
            list = #(Scan.state.list or {}),
            scanMs = scanMs, scanTokens = sc and (sc.tokens - (s0.tokens or 0)) or 0,
            sweeps = sc and (sc.sweeps - (s0.sweeps or 0)) or 0,
            slices = sc and (sc.slices - (s0.slices or 0)) or 0,
            budgetMs = sc and sc.budgetMs or 0.12,
            nSamples = #sliceSamples,
        }
        io.stdout:write(string.format("  raid40 run %d/%d  maxSlice=%.4f ms  p99=%.4f ms  scanPct=%.3f%%  impact=%.3f%%  slices=%d samples=%d\n",
            run, NRUN, mx, p99, scanPct, impact, lastMeta.slices, lastMeta.nSamples))
    end
    if realSlice then Scan.Slice = realSlice end
    raid40 = {
        list = lastMeta.list, scanTokens = lastMeta.scanTokens, sweeps = lastMeta.sweeps, slices = lastMeta.slices,
        scanMs = lastMeta.scanMs, scanPct = medianOf(rawScanPct), budgetMs = lastMeta.budgetMs,
        impactPct = medianOf(rawImpact), maxSliceMs = medianOf(rawMax), p99SliceMs = medianOf(rawP99),
        runs = NRUN, rawMax = rawMax, rawP99 = rawP99,
    }
    io.stdout:write(string.format("  raid40 median(N=%d) maxSlice=%.4f ms  p99=%.4f ms  (budget %.2f exact)  scanPct=%.3f%%  impact=%.3f%%  rawMax=[%.4f/%.4f/%.4f/%.4f/%.4f]\n",
        NRUN, raid40.maxSliceMs, raid40.p99SliceMs, raid40.budgetMs, raid40.scanPct, raid40.impactPct,
        rawMax[1], rawMax[2], rawMax[3], rawMax[4], rawMax[5]))
    RAID = false
    UnitExists, UnitGUID, UnitName = baseExists, baseGUID, baseName
    fire("GROUP_ROSTER_UPDATE")
end
-- v2.2.6: worst-case 40-man WorldCapture storm — every raid + nameplate exists; Slice under budget while tape accepts ws.
local wc40
if not aborted and not opts.nowc and ns.WorldCapture then
    local baseExists, baseGUID = UnitExists, UnitGUID
    IsInRaid = function() return true end
    IsInGroup = function() return true end
    GetNumGroupMembers = function() return 40 end
    IsInInstance = function() return true, "pvp" end
    UnitExists = function(u)
        if u:match("^raid%d+") or u:match("^nameplate%d+") or u:match("^party%d+") or u == "player" or u == "target" or u == "focus" or u == "pet" then return true end
        return baseExists(u)
    end
    UnitGUID = function(u)
        local ri = tonumber(u:match("^raid(%d+)"))
        if ri then return string.format("Player-1234-%08X", ri) end
        local ni = tonumber(u:match("^nameplate(%d+)"))
        if ni then return string.format("Creature-0-1-2-3-%d-0000AAAA", 3000 + ni) end
        return baseGUID(u)
    end
    UnitHealth = function() return SECRET end
    UnitHealthMax = function() return 10000 end
    UnitPower = function() return SECRET end
    UnitPowerMax = function() return 100 end
    UnitThreatSituation = function() return 0 end
    UnitDetailedThreatSituation = function() return false, 0, 0, 0, 0 end
    CheckInteractDistance = function() return true end
    UnitInRange = function() return true, true end
    UnitCastingInfo = function() return nil end
    UnitChannelInfo = function() return nil end
    UnitIsDeadOrGhost = function() return false end
    UnitIsUnit = function() return false end
    if not ns.WorldCapture.state or not ns.WorldCapture.state.list or #ns.WorldCapture.state.list == 0 then
        pcall(ns.WorldCapture.Start)
    end
    local st = ns.WorldCapture.state
    local s0 = { samples = st.samples or 0, slices = st.slices or 0, ms = st.ms or 0, dropped = st.dropped or 0 }
    resetWin()
    for _ = 1, 30 do   -- 30 s of slices @ ~5 Hz (interval 0.2)
        for _ = 1, 5 do
            local t0 = os.clock()
            pcall(ns.WorldCapture.Slice)
            local dt = (os.clock() - t0) * 1000
            evMs = evMs + dt
            evN = evN + 1
        end
        for _ = 1, opts.fps do frame(1 / opts.fps) end
    end
    local simS = math.max(S.time - win.t0, 1e-6)
    wc40 = {
        impactPct = (evMs + frMs) / simS / 10,
        samples = (st.samples or 0) - s0.samples,
        slices = (st.slices or 0) - s0.slices,
        ms = (st.ms or 0) - s0.ms,
        dropped = (st.dropped or 0) - s0.dropped,
        budgetMs = (ns.config.worldCapture and ns.config.worldCapture.budgetMs) or 0.10,
        list = #(st.list or {}),
    }
    wc40.maxSliceMs = (st.slices - s0.slices) > 0 and (wc40.ms / math.max(st.slices - s0.slices, 1)) or 0
    endWin()
    io.stdout:write(string.format("  wc40   list=%d  samples=%d slices=%d  scan %.3f ms  avgSlice %.4f ms (budget %.2f)  dropped=%d  impact %.3f%%\n",
        wc40.list, wc40.samples, wc40.slices, wc40.ms, wc40.maxSliceMs, wc40.budgetMs, wc40.dropped, wc40.impactPct))
    UnitExists, UnitGUID = baseExists, baseGUID
    fire("GROUP_ROSTER_UPDATE")
end
-- aged session: push opts.aged casts through the handlers (events + one Tick per cast, no frames), then measure again
if not aborted and (opts.aged or 0) > 0 then
    local per = math.floor(1.5 * opts.fps + 0.5)
    for _ = 1, opts.aged do
        n = n + 1
        castEvents(n)
        S.time = S.time + 1.5
        frame(1 / opts.fps)
        if overCap() then aborted = n break end
    end
    if not aborted then   -- five aged windows (median used for the aged/fresh gate)
        for wi = 1, 5 do
            resetWin()
            for _ = 1, WIN do n = n + 1 castEvents(n) for _ = 1, per do frame(1 / opts.fps) end end
            mark(wi == 5 and "aged" or ("aged" .. wi), n)
        end
    end
end
-- perf gate (v2.2.4): aged within 1.5x of fresh, medians over windows (fresh = the 25/50/100-cast windows)
local gate
do
    local fr, ag = {}, {}
    for _, r in ipairs(results) do
        if r.label:match("^aged") then ag[#ag + 1] = r.impactPct else fr[#fr + 1] = r.impactPct end
    end
    local function med(t) table.sort(t) local m = #t if m == 0 then return nil end return (m % 2 == 1) and t[(m + 1) / 2] or (t[m / 2] + t[m / 2 + 1]) / 2 end
    local f, a = med(fr), med(ag)
    if f and a then gate = { fresh = f, aged = a, ratio = a / math.max(f, 1e-9), nFresh = #fr, nAged = #ag } end
end
if gate then print(string.format("  gate   aged/fresh %.2f  (aged %.3f%%, fresh %.3f%%, medians)", gate.ratio, gate.aged, gate.fresh)) end
if aborted then print(string.format("ABORTED by the %d s cap after %d casts; trend measured so far is reported below", opts.cap, aborted)) end
-- idle: combat ends, no events for 700 s (countdowns run out); the HSM window stays open
S.combat = false
fire("PLAYER_REGEN_ENABLED")
fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
if not aborted then for _ = 1, 7000 do frame(0.1) if overCap() then aborted = aborted or -1 break end end end
local idleN, idleNames = activeOnUpdates()
local hsmShown = ns.HSMUI and ns.HSMUI.IsShown()
W.slash("logs off")
for _ = 1, 30 do S.time = S.time + 0.05 runDelayed() W.tick(1) end
-- v2.2.6 release-level window (after FD_Logs restores verbosity): same handlers, no capture tape extras
do
    if ns.ReplayLog and ns.ReplayLog.SetLevel then ns.ReplayLog.SetLevel("release", "bench") end
    resetWin()
    local nRel = 25
    for i = 1, nRel do castEvents(i) for _ = 1, 3 do frame(1 / opts.fps) end end
    local wall = (S.time - win.t0) * 1000
    local releaseImpact = wall > 0 and (100 * (evMs + frMs) / wall) or 0
    results.releaseImpactPct = releaseImpact
    results.releaseLevel = ns.ReplayLog and ns.ReplayLog.Level and ns.ReplayLog.Level() or "?"
    io.stdout:write(string.format("  release-level (%s) %d casts: impact %.3f%% (gate < 2%%)\n",
        tostring(results.releaseLevel), nRel, releaseImpact))
end
local perf = ForeverDumpLogDB.perf
local psess = perf and perf.sessions and perf.sessions[#perf.sessions]

print(string.format("ForeverDump %s perf bench (%s, %d globals, %d fps)", tostring(ns.VERSION), addonDir, 52517, opts.fps))
print(string.format("%-6s %8s %10s %10s %10s %8s %8s %9s %9s %6s", "point", "casts", "ms/event", "ms/frame", "ms/sim-s", "impact%", "KB/ev", "ins/ev", "ins/frame", "preds"))
for _, r in ipairs(results) do
    print(string.format("%-6s %8d %10.4f %10.4f %10.3f %8.3f %8.3f %9d %9d %6d", r.label, r.casts, r.perEventMs, r.perFrameMs, r.msPerSec, r.impactPct,
        r.kbPerEvent, r.insPerEvent, r.insPerFrame, r.predictions))
end
print(string.format("wall time %d s (cap %d s)", os.time() - wall0, opts.cap))
print(string.format("idle after 700 s (HSM window %s): %d OnUpdate script(s) running %s", hsmShown and "open" or "closed", idleN,
    idleN > 0 and ("(" .. table.concat(idleNames, ",") .. ")") or ""))
if psess then print(string.format("self-perf monitor: %d handler keys, %d samples", (function() local k = 0 for _ in pairs(psess.handlers) do k = k + 1 end return k end)(), #psess.samples)) end

-- per-handler growth from the self-perf monitor's 15 s windows (first vs last window with calls)
if psess and opts.keys then
    local rows = {}
    for key, h in pairs(psess.handlers) do
        local wins = {}
        for wi, w in pairs(h.w) do wins[#wins + 1] = { wi, w[1], w[2] } end
        table.sort(wins, function(x, y) return x[1] < y[1] end)
        local f, l = wins[1], wins[#wins]
        rows[#rows + 1] = { key = key, ms = h.ms, n = h.n, first = f and f[3] / math.max(f[2], 1) or 0, last = l and l[3] / math.max(l[2], 1) or 0 }
    end
    table.sort(rows, function(x, y) return x.ms > y.ms end)
    for i = 1, math.min(12, #rows) do local r = rows[i]
        print(string.format("  %-36s %7d calls %9.2f ms  first %.4f  last %.4f ms/call", r.key, r.n, r.ms, r.first, r.last)) end
end
if opts.json then
    local f = assert(io.open(opts.json, "w"))
    local parts = {}
    for _, r in ipairs(results) do
        parts[#parts + 1] = string.format('{"point":"%s","casts":%d,"perEventMs":%.6f,"perFrameMs":%.6f,"msPerSec":%.4f,"impactPct":%.4f,"kbPerEvent":%.4f,"insPerEvent":%d,"insPerFrame":%d,"predictions":%d,"wall":%d}',
            r.label, r.casts, r.perEventMs, r.perFrameMs, r.msPerSec, r.impactPct, r.kbPerEvent, r.insPerEvent, r.insPerFrame, r.predictions, r.wall)
    end
    f:write(string.format('{"version":"%s","captureLevel":"%s","globals":52517,"fps":%d,"results":[%s],"gate":%s,"storm":%s,"raid40":%s,"wc40":%s,"idleOnUpdates":%d,"aborted":%s,"wall":%d,"cap":%d}\n',
        tostring(ns.VERSION), tostring(CAPTURE_LEVEL), opts.fps, table.concat(parts, ","),
        gate and string.format('{"fresh":%.4f,"aged":%.4f,"ratio":%.4f}', gate.fresh, gate.aged, gate.ratio) or "null",
        storm and string.format('{"cooling":%d,"events":%d,"perEventMs":%.6f,"impactPct":%.4f,"windows":[%.4f,%.4f,%.4f]}', storm.k, storm.events, storm.perEventMs, storm.impactPct,
            storm.windows[1], storm.windows[2], storm.windows[3]) or "null",
        raid40 and string.format('{"list":%d,"scanTokens":%d,"slices":%d,"sweeps":%d,"scanMs":%.4f,"scanPct":%.4f,"maxSliceMs":%.4f,"p99SliceMs":%.4f,"budgetMs":%.3f,"impactPct":%.4f,"runs":%d,"rawMax":[%.4f,%.4f,%.4f,%.4f,%.4f]}',
            raid40.list, raid40.scanTokens or 0, raid40.slices or 0, raid40.sweeps or 0, raid40.scanMs or 0, raid40.scanPct or 0, raid40.maxSliceMs or 0,
            raid40.p99SliceMs or 0, raid40.budgetMs or 0, raid40.impactPct, raid40.runs or 0,
            (raid40.rawMax and raid40.rawMax[1]) or 0, (raid40.rawMax and raid40.rawMax[2]) or 0,
            (raid40.rawMax and raid40.rawMax[3]) or 0, (raid40.rawMax and raid40.rawMax[4]) or 0,
            (raid40.rawMax and raid40.rawMax[5]) or 0) or "null",
        wc40 and string.format('{"list":%d,"samples":%d,"slices":%d,"ms":%.4f,"avgSliceMs":%.4f,"budgetMs":%.3f,"dropped":%d,"impactPct":%.4f}',
            wc40.list, wc40.samples, wc40.slices, wc40.ms, wc40.maxSliceMs, wc40.budgetMs, wc40.dropped, wc40.impactPct) or "null",
        idleN, aborted and tostring(aborted) or "null", os.time() - wall0, opts.cap))
    f:close()
end

if opts.assert and opts.level == "lab" then
    -- v2.2.15 lab: numbers reported, not gated (user decision 2026-10-09), except the runaway backstop
    local fails = 0
    local function check(c, m) if c then print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
    check(CAPTURE_LEVEL == "lab", "measured at lab (got " .. tostring(CAPTURE_LEVEL) .. ")")
    for _, r in ipairs(results) do print(string.format("  info lab capture impact %.3f%% at %d casts (diag limit 10%%: report only)", r.impactPct, r.casts)) end
    if storm then print(string.format("  info lab storm %.4f ms/event, impact %.3f%%", storm.perEventMs, storm.impactPct)) end
    if type(results.releaseImpactPct) == "number" then print(string.format("  info release-level impact after lab %.3f%%", results.releaseImpactPct)) end
    check(not (ns.Perf and ns.Perf.runaway), "runaway backstop not tripped")
    print(fails == 0 and "PERF LAB REPORT OK" or "PERF LAB FAILED")
    os.exit(fails == 0 and 0 or 1)
end
if opts.assert then
    local fails = 0
    local function check(c, m) if c then print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
    check(not aborted, string.format("finished inside the %d s cap (%d s)", opts.cap, os.time() - wall0))
    check(CAPTURE_LEVEL == "diag", "capture gates measured at the default capture level diag (got " .. tostring(CAPTURE_LEVEL) .. ")")
    local a, z = results[1], results[#results]
    if not (a and z) then print("PERF FAILED (no checkpoint)") os.exit(1) end
    check(z.insPerEvent <= 1.5 * a.insPerEvent + 200, string.format("O(1) per event: %d Lua instructions at %d casts vs %d at %d (%.4f vs %.4f ms)",
        z.insPerEvent, z.casts, a.insPerEvent, a.casts, z.perEventMs, a.perEventMs))
    check(z.insPerFrame <= 1.5 * a.insPerFrame + 100, string.format("O(1) per frame: %d Lua instructions at %d casts vs %d at %d (%.4f vs %.4f ms)",
        z.insPerFrame, z.casts, a.insPerFrame, a.casts, z.perFrameMs, a.perFrameMs))
    check(z.kbPerEvent <= 2 * a.kbPerEvent + 0.5, string.format("O(1) garbage per event: %.3f KB at %d casts vs %.3f KB at %d", z.kbPerEvent, z.casts, a.kbPerEvent, a.casts))
    -- v2.2.6: capture (test/diag) official gate <=10%; keep aged/storm as tighter regression
    for _, r in ipairs(results) do check(r.impactPct <= 10, string.format("capture-mode impact %.3f%% <= 10%% at %d casts", r.impactPct, r.casts)) end
    -- v2.2.10: release budget 2% (set by the user on 2026-10-08; was 1%)
    check(type(results.releaseImpactPct) == "number" and results.releaseImpactPct < 2,
        string.format("release-mode impact %.3f%% < 2%% (level=%s)", results.releaseImpactPct or -1, tostring(results.releaseLevel)))
    check(storm and storm.k >= 50, string.format("storm: %d spells cooling in the tracker (>= 50)", storm and storm.k or 0))
    -- v2.2.10: storm limit 2% (was 0.5%) at capture AND release level, set by the user on 2026-10-08; the bench runs
    -- the storm at the capture level, so the release-level storm is bounded by the same 2%
    check(storm and storm.impactPct <= 2.0 and storm.perEventMs < 0.5, string.format("SPELL_UPDATE_COOLDOWN storm (50 cooling, 60/s): %.4f ms/event, impact %.3f%% <= 2%% (median of 3; user limit 2026-10-08)",
        storm and storm.perEventMs or -1, storm and storm.impactPct or -1))
    if gate then
        check(gate.ratio <= 1.5, string.format("aged/fresh impact ratio %.2f <= 1.5 (aged %.3f%% median of %d windows vs fresh %.3f%% median of %d)",
            gate.ratio, gate.aged, gate.nAged, gate.fresh, gate.nFresh))
        check(gate.aged <= 0.3 * 1.5, string.format("aged impact %.3f%% <= 0.45%% (target ~0.3%%)", gate.aged))
    end
    if not opts.noraid then
        check(raid40 and raid40.impactPct < 1, string.format("40-man raid scan: total frame-time impact %.3f%% < 1%%", raid40 and raid40.impactPct or -1))
        check(raid40 and raid40.list >= 300 and (raid40.sweeps or 0) >= 1, string.format("40-man raid scan: %d-token list swept %d time(s) in 30 s",
            raid40 and raid40.list or 0, raid40 and raid40.sweeps or 0))
        -- strict budget (no slack): median of N=5 per-run maxSlice and per-run p99 must each be <= budgetMs
        check(raid40 and raid40.maxSliceMs and raid40.maxSliceMs <= raid40.budgetMs, string.format(
            "scanner slice budget holds: median maxSlice %.4f ms <= budget %.2f (N=%d rawMax logged)",
            raid40 and raid40.maxSliceMs or -1, raid40 and raid40.budgetMs or -1, raid40 and raid40.runs or 0))
        check(raid40 and raid40.p99SliceMs and raid40.p99SliceMs <= raid40.budgetMs, string.format(
            "scanner slice budget holds: median p99 %.4f ms <= budget %.2f (N=%d)",
            raid40 and raid40.p99SliceMs or -1, raid40 and raid40.budgetMs or -1, raid40 and raid40.runs or 0))
        if wc40 then
            check(wc40.impactPct < 10, string.format("world-capture 40-man storm impact %.3f%% <= 10%% (capture ceiling)", wc40.impactPct))
            check(wc40.maxSliceMs <= (wc40.budgetMs * 5 + 0.5), string.format("world-capture avg slice %.4f ms within 5x budget %.2f (mock clock)",
                wc40.maxSliceMs, wc40.budgetMs))
        end
    end
    check(idleN == 0, "no idle OnUpdate (HSM window open, nothing to draw)")
    check(psess and psess.handlers and next(psess.handlers) ~= nil and #psess.samples >= 1, "self-perf monitor recorded handlers + samples")
    print(fails == 0 and "PERF OK" or ("PERF FAILED (" .. fails .. ")"))
    os.exit(fails == 0 and 0 or 1)
end
