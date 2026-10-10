-- v2.2.29: replay a stored run's ForeverDumpDB through an addon's real AuraPresence (BG, capture on) for SIM seconds at
-- FPS and measure: (unit, candidate) coverage, per-frame cost (virtual clock: every mocked API call costs COST ms, the
-- per-call cost measured in runs 19-21 incl. classification), wall share, and staleness (longest gap between two checks
-- of the same (unit, spellID); never checked = uncovered). Works for v2.2.28 (per-tick, cut) and v2.2.29 (sliced).
-- usage: lua5.1 tools/fdump/measure_sched.lua <addonDir> <cost ms> <sim s> <sv> [<sv> ...]
package.path = "./tests/?.lua;" .. package.path
local addonDir, COST, SIM = arg[1], tonumber(arg[2]) or 0.012, tonumber(arg[3]) or 120
local FPS = 60
local W = require("wowenv")
local S = W.state
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$"):gsub("\\", "/") end
end
-- a BG: me, an enemy target, 15 friendly raid members, 10 enemy nameplates (class / level secret = unknown)
local EXIST = { player = true, target = true }
for i = 1, 15 do EXIST["raid" .. i] = true end
for i = 1, 10 do EXIST["nameplate" .. i] = true end
local vclock = 0
local function cost(fn) return function(...) vclock = vclock + COST return fn(...) end end

local function run(path)
    S.frames, S.timers, S.onUpdate = {}, {}, {}
    for _, n in ipairs(W.SV_NAMES or {}) do _G[n] = nil end
    ForeverDumpDB = nil
    dofile(path)
    local raw = io.open(path):read("*a")
    local b = raw:match('lastClientBuild\\?"?%]?%s*=%s*\\?"(%d+)')
    GetBuildInfo = function() return "1.60.1", b, "", 16001 end
    C_SpellBook = nil
    UnitClass = function() return "Shaman", "SHAMAN", 7 end
    local ns = W.loadAddon(addonDir, files, "ForeverDump")
    if os.getenv("NOLIB") then ns.LearnedAuras = nil end
    IsInInstance = function() return true, "pvp" end
    IsInGroup = function() return true end
    W.fire("ADDON_LOADED", "ForeverDump")
    W.fire("PLAYER_LOGIN")
    ns.InvalidateEnv()
    ns.LabActive = function() return true end
    ns.db.logs = ns.db.logs or {}
    ns.db.logs.on = true
    local tickFn
    C_Timer.NewTicker = function(_, fn) tickFn = fn return { Cancel = function() end } end
    UnitExists = cost(function(u) return EXIST[u] == true end)
    UnitIsPlayer = function(u) return EXIST[u] == true end
    UnitGUID = cost(function(u) return EXIST[u] and ("Player-1-" .. u) or nil end)
    UnitName = cost(function(u) return EXIST[u] and u or nil end)
    UnitClass = cost(function(u) if u == "player" then return "Shaman", "SHAMAN", 7 end return W.SECRET, W.SECRET, W.SECRET end)
    UnitLevel = cost(function(u) if u == "player" then return 25 end return W.SECRET end)
    UnitHealth, UnitPower = cost(function() return W.SECRET end), cost(function() return W.SECRET end)
    C_UnitAuras.GetAuraSlots = cost(function() error("Auras cannot be accessed when secret while tainted by 'ForeverDump'") end)
    local seen, last, maxGap = {}, {}, {}
    local t0
    C_UnitAuras.GetUnitAuraBySpellID = function(u, sid)
        vclock = vclock + COST
        local k = u .. "|" .. sid
        local tt = S.time
        if t0 and tt >= t0 then
            if last[k] then local gp = tt - last[k] if gp > (maxGap[k] or 0) then maxGap[k] = gp end end
            last[k] = tt
            seen[k] = true
        end
        return W.SECRET
    end
    debugprofilestop = function() return vclock end
    -- no per-build rank learn levels have been measured live yet: the replay runs the "class / level unknown" path
    if C_Spell then C_Spell.GetSpellLevelLearned = nil end
    local AP = ns.AuraPresence
    AP.costMs = nil
    assert(AP.Start(), "start")
    local frames, worst, sum, busy = 0, 0, 0, 0
    local list
    for f = 1, SIM * FPS do
        S.time = S.time + 1 / FPS
        local v0 = vclock
        for fr, fn in pairs(S.onUpdate) do
            if fr.__scripts and fr.__scripts.OnUpdate == fn then fn(fr, 1 / FPS) end
        end
        if f % FPS == 1 and tickFn then tickFn() end
        local timers = S.timers
        S.timers = {}
        for _, fn in ipairs(timers) do fn() end
        if f == FPS * 20 then t0 = S.time list = AP.Candidates() end   -- denominator: EVERY candidate, before any cut   -- 20 s warm-up (cost EWMA, rank levels, first cycles)
        if t0 then
            local dv = vclock - v0
            frames = frames + 1
            sum = sum + dv
            if dv > 0 then busy = busy + 1 end
            if dv > worst then worst = dv end
        end
    end
    local win = S.time - t0
    local nUnits, pairsN, covered, gaps = 0, 0, 0, {}
    for u in pairs(EXIST) do
        nUnits = nUnits + 1
        for _, e in ipairs(list) do
            local k = u .. "|" .. e[1]
            pairsN = pairsN + 1
            if seen[k] then covered = covered + 1 gaps[#gaps + 1] = math.max(maxGap[k] or win, 0) end
        end
    end
    table.sort(gaps)
    local outp = os.getenv("OUT")
    if outp and AP.Plan then
        local fh = io.open(outp, "w")
        fh:write("spellID\tname\tsource\ttier_unknown_class\tmax_gap_fixed_s\tmax_gap_rotating_s\n")
        local pl = AP.Plan(nil, nil)
        local tierOf = {}
        for _, t in ipairs({ "H", "W", "C" }) do for _, sid in ipairs(pl[t]) do tierOf[sid] = t end end
        for _, e in ipairs(list) do
            local gf, gr = 0, 0
            for u in pairs(EXIST) do
                local k = u .. "|" .. e[1]
                local gp = seen[k] and (maxGap[k] or win) or math.huge
                if u == "player" or u == "target" then gf = math.max(gf, gp) else gr = math.max(gr, gp) end
            end
            fh:write(string.format("%d\t%s\t%s\t%s\t%.1f\t%.1f\n", e[1], tostring(e[2]), tostring(e[3]), tostring(tierOf[e[1]]), gf, gr))
        end
        fh:close()
    end
    local cand = #list
    local allIds = AP.Count and AP.Count(AP.OfflineAuras and AP.OfflineAuras() or {}) or 0
    return {
        build = b, cand = cand, listed = #AP.List(), units = nUnits, cover = covered / pairsN * 100, coveredIds = #list,
        meanMs = sum / frames, maxMs = worst, wall = sum / (win * 1000) * 100,
        stMed = gaps[math.floor(#gaps * 0.5) + 1] or 0, stP95 = gaps[math.floor(#gaps * 0.95) + 1] or 0, stMax = gaps[#gaps] or 0,
        win = win, rot = (ForeverDumpLogDB.auraPresence.sched or {}).rotate,
        lib = allIds,
    }
end
print("run|build|candidates|checked_ids|unit_x_id_coverage%|frame_ms_mean|frame_ms_max|wall%|staleness_s_median|p95|max|rotate")
for i = 4, #arg do
    local r = run(arg[i])
    print(string.format("%s|%s|%d|%d|%.1f|%.3f|%.3f|%.2f|%.1f|%.1f|%.1f|%s", arg[i]:match("run%d+[%w-]*"), r.build, r.cand,
        r.listed, r.cover, r.meanMs, r.maxMs, r.wall, r.stMed, r.stP95, r.stMax, tostring(r.rot)))
end
