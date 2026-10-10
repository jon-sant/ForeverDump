-- v2.2.29: aura presence without "accurate but finds fewer": time-sliced queue (OnUpdate, wall-share budget), no
-- candidate dropped, rank tiers by class + level (C_Spell.GetSpellLevelLearned), sticky-present, budget-adaptive
-- rotation, staleness, backstop; combat-flip tagging of ADDON_RESTRICTION_STATE_CHANGED.
-- usage: lua5.1 tests/v2229_sched.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local COST = 0.012
local vclock = 0
local EXIST, PRESENT, LEVELS, CHECKS = {}, {}, nil, {}
local tickFn
local itype = "none"
local function fresh(db)
    S.frames, S.timers, S.onUpdate = {}, {}, {}
    for _, n in ipairs(W.SV_NAMES or {}) do _G[n] = nil end
    ForeverDumpDB = db or {}
    GetBuildInfo = function() return "1.60.1", "70338", "Oct 10 2026", 16001 end
    C_SpellBook = nil
    UnitClass = function(u) if u == "player" then return "Shaman", "SHAMAN", 7 end if EXIST[u] then return "Druid", "DRUID", 11 end end
    local ns = W.loadAddon(addonDir, files, "ForeverDump")
    IsInInstance = function() return itype ~= "none", itype end
    IsInGroup = function() return true end
    W.fire("ADDON_LOADED", "ForeverDump")
    W.fire("PLAYER_LOGIN")
    ns.InvalidateEnv()
    ns.LabActive = function() return true end
    ns.db.logs = ns.db.logs or {}
    ns.db.logs.on = true
    C_Timer.NewTicker = function(_, fn) tickFn = fn return { Cancel = function() end } end
    UnitExists = function(u) vclock = vclock + COST return EXIST[u] == true end
    UnitIsPlayer = function(u) return EXIST[u] == true end
    UnitGUID = function(u) return EXIST[u] and (type(EXIST.guid) == "table" and EXIST.guid[u] or ("Player-1-" .. u)) or nil end
    UnitName = function(u) return EXIST[u] and u or nil end
    UnitLevel = function(u) return EXIST[u] and 30 or 0 end
    C_UnitAuras.GetAuraSlots = function() return nil end
    C_UnitAuras.GetUnitAuraBySpellID = function(u, sid)
        vclock = vclock + COST
        CHECKS[#CHECKS + 1] = { u, sid, S.time }
        if PRESENT[u .. "|" .. sid] then return { spellId = sid, name = "x", auraInstanceID = 5 } end
        return nil
    end
    C_Spell = C_Spell or {}
    C_Spell.GetSpellLevelLearned = function(sid) return LEVELS and LEVELS[sid] or 1 end
    debugprofilestop = function() return vclock end
    return ns, ns.AuraPresence
end
local function frames(n, AP)
    local worst = 0
    for i = 1, n do
        S.time = S.time + 1 / 60
        local v0 = vclock
        if i % 60 == 1 and tickFn then tickFn() end
        for fr, fn in pairs(S.onUpdate) do if fr.__scripts and fr.__scripts.OnUpdate == fn then fn(fr, 1 / 60) end end
        if vclock - v0 > worst then worst = vclock - v0 end
    end
    return worst
end

print("(1) time-sliced queue: the ticker only flags, OnUpdate runs tick + drain within the frame budget")
EXIST = { player = true, target = true }
for i = 1, 15 do EXIST["raid" .. i] = true end
local ns, AP = fresh()
check(AP.Start() == true and AP.async == true and AP.drainFrame ~= nil, "Start: drain frame, async")
local list = AP.List()
check(#list >= 582, "library listed in full: " .. #list .. " candidates (nothing cut)")
tickFn()
check(AP.tickDue == true and #CHECKS == 0, "ticker only flags the tick (no work in the timer)")
local worst = frames(60 * 30, AP)
local cap = AP.FRAME_MAX_MS + AP.CHECK_EVERY * COST + 20 * COST
check(worst <= cap, string.format("worst frame %.3f ms <= %.3f (FRAME_MAX + one check batch + unit start)", worst, cap))
local d = ForeverDumpLogDB.auraPresence
check(d.sched and d.sched.jobs > 0 and d.sched.checks > 0 and d.sched.frames > 30, "sched stats: " .. d.sched.jobs .. " jobs, " .. d.sched.checks .. " checks, " .. d.sched.frames .. " frames")
check(d.sched.rotate and d.sched.rotate > AP.ROTATE, "rotation follows the budget: " .. tostring(d.sched.rotate) .. " units per tick (v2.2.28: " .. AP.ROTATE .. ")")
check(AP.Queued() < 20 and d.sched.deferred == 0, "queue drains (no unit deferred): queued " .. AP.Queued())
check(d.sched.sumMs / (30 * 1000) <= AP.WALL_SHARE + 0.005, string.format("wall share %.2f %% <= %.0f %%", d.sched.sumMs / 300, AP.WALL_SHARE * 100))

local savedTick = tickFn
tickFn = nil
for _ = 1, 600 do
    S.time = S.time + 1 / 60
    for fr, fn in pairs(S.onUpdate) do if fr.__scripts and fr.__scripts.OnUpdate == fn then fn(fr, 1 / 60) end end
end
local live = 0
for fr in pairs(S.onUpdate) do if fr == AP.drainFrame and fr.__scripts.OnUpdate then live = live + 1 end end
check(AP.awake == false and live == 0, "idle (queue empty, levels + BigDefensive done): OnUpdate removed itself")
tickFn = savedTick
tickFn()
check(AP.awake == true and AP.drainFrame.__scripts.OnUpdate ~= nil, "next tick wakes it again")

print("(2) coverage: every candidate checked on every unit within TIER_EVERY.C visits")
local byUnit = {}
for _, c in ipairs(CHECKS) do byUnit[c[1]] = byUnit[c[1]] or {} byUnit[c[1]][c[2]] = true end
local miss = {}
for _, u in ipairs({ "player", "target", "raid1", "raid15" }) do
    local m = 0
    for _, e in ipairs(list) do if not (byUnit[u] and byUnit[u][e[1]]) then m = m + 1 end end
    miss[#miss + 1] = u .. "=" .. m
end
check(table.concat(miss, ","):find("^player=0,target=0,raid1=0,raid15=0$"), "uncovered (unit, id) pairs after 30 s: " .. table.concat(miss, ","))
local st = AP.Staleness(d)
check(st and st.target and math.abs(st.target.W - (AP.TIER_EVERY.W * math.max(d.sched.maxGap.target, 1) + d.sched.maxLag)) < 0.02,
    string.format("staleness target: H %.1f / W %.1f / C %.1f s", st.target.H, st.target.W, st.target.C))
check(st.raidN and st.raidN.C >= st.target.C, string.format("rotating units staler: raidN C %.1f s", st.raidN.C))

print("(3) regression: many queued jobs all finish (no holes in the queue)")
for i = 1, 30 do AP.Enqueue(d, "raid" .. ((i - 1) % 15 + 1), "raidN", "x", false) end
frames(600, AP)
local pend = 0
for _ in pairs(AP.pending) do pend = pend + 1 end
check(AP.Queued() == 0 or pend <= 20, "pending after 10 s: " .. pend .. ", queued " .. AP.Queued())

print("(4) rank tiers by class + level (GetSpellLevelLearned)")
-- Entangling Roots in the library: 5195 19973 1062 19975 19974 -> levels 18 28 8 48 38; unit level 30
LEVELS = { [5195] = 18, [19973] = 28, [1062] = 8, [19975] = 48, [19974] = 38 }
ns, AP = fresh()
AP.List()
AP.FillLevels(100000)
local pl = AP.Plan("DRUID", 30)
local T = {}
for _, t in ipairs({ "H", "W", "C" }) do for _, sid in ipairs(pl[t]) do T[sid] = t end end
check(T[19973] == "W" and T[5195] == "W", "the 2 highest ranks learnable at 30 (28, 18): W")
check(T[1062] == "C" and T[19974] == "C" and T[19975] == "C", "lower rank (8) and ranks above the level (38, 48): C - still checked")
local pu = AP.Plan(nil, nil)
local U = {}
for _, t in ipairs({ "H", "W", "C" }) do for _, sid in ipairs(pu[t]) do U[sid] = t end end
check(U[5195] == "W" and U[19973] == "C" and U[1062] == "C", "class/level unknown: most-seen rank W, all other ranks C")
local tot = #pl.H + #pl.W + #pl.C
check(tot == #AP.List(), "plan covers every candidate: " .. tot .. " = " .. #AP.List())
LEVELS = {}
ns, AP = fresh()
AP.List() AP.FillLevels(100000)
local pe = AP.Plan("DRUID", 30)
local E = {}
for _, t in ipairs({ "H", "W", "C" }) do for _, sid in ipairs(pe[t]) do E[sid] = t end end
check(E[5195] == "W" and E[19973] == "C", "the same level for every rank (client answers 1) = no information -> unknown path")
check(ns.db.spellLevel and ns.db.spellLevel["70338"] and ns.db.spellLevel["70338"][5195] == 1, "levels cached per build in ForeverDumpDB.spellLevel")

print("(5) sticky: a present aura is checked on every visit until absent")
LEVELS = nil
EXIST = { player = true, target = true }
CHECKS = {}
ns, AP = fresh()
AP.Start()
local pc = AP.Plan(nil, nil)
local cSid = pc.C[1]
PRESENT["target|" .. cSid] = true
frames(60 * 12, AP)
local times = {}
for _, c in ipairs(CHECKS) do if c[1] == "target" and c[2] == cSid then times[#times + 1] = c[3] end end
local mg = 0
for i = 2, #times do if times[i] - times[i - 1] > mg then mg = times[i] - times[i - 1] end end
check(#times >= 3 and mg <= 1.5, string.format("tier-C id %d present on target: found by its tier-C check, then every visit (%d checks, max gap %.2f s)", cSid, #times, mg))
PRESENT["target|" .. cSid] = nil
CHECKS = {}
frames(60 * 6, AP)
local after = 0
for _, c in ipairs(CHECKS) do if c[1] == "target" and c[2] == cSid then after = after + 1 end end
check(after <= 2, "absent again -> back to its tier: " .. after .. " checks in 6 s")

print("(6) unit swap / unit gone during a job")
d = ForeverDumpLogDB.auraPresence
AP.Enqueue(d, "target", "target", "x", false)
AP.Drain(0.0001)
EXIST.guid = { target = "Player-1-other" }
AP.Drain(0.0001)
check(AP.pending.target == nil or AP.pending.target.guid == "Player-1-other", "target switched: the job follows the new GUID")
EXIST.guid = nil
frames(120, AP)
EXIST.target = nil
AP.Enqueue(d, "target", "target", "x", false)
local gone0 = d.sched.unitGone
AP.Drain(1)
check(d.sched.unitGone == gone0 + 1 and AP.pending.target == nil, "target gone: job ends, counted")

print("(7) restriction flips: Combat Activating precedes InCombatLockdown -> combat")
S.combat = false
check(ns.CombatAtFlip(0, 1) == true and ns.CombatAtFlip(0, 2) == true, "type 0 Activating / Active = combat")
check(ns.CombatAtFlip(0, 0) == false and ns.CombatAtFlip(3, 1) == false, "Inactive, other types: not combat")
AP.OnRestriction(0, 1)
local r = ForeverDumpLogDB.auraPresence.restrict
local key
for tg, t in pairs(r) do for k in pairs(t) do if k == "0:1:combat" then key = tg end end end
check(key and key:find("/combat/"), "AP restrict counted as combat under a combat tag: " .. tostring(key))
AP.OnRestriction(0, 0)
local k0
for tg, t in pairs(r) do for k in pairs(t) do if k == "0:0:ooc" then k0 = tg end end end
check(k0 and k0:find("/ooc/"), "Inactive stays ooc: " .. tostring(k0))
W.fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
local fl = ForeverDumpLogDB.restrictions and ForeverDumpLogDB.restrictions.flips or {}
local rec = fl[#fl]
check(rec and rec.inCombat == true and rec.combatBy == "flip" and rec.inCombatLockdown == false and rec.env and rec.env:find("/combat/"),
    "Restrictions flip record: inCombat (by flip), raw lockdown false, env " .. tostring(rec and rec.env))
local be
for env, t in pairs(ForeverDumpLogDB.restrictions.byEnv or {}) do for k in pairs(t) do if k:find(":combat$") then be = env .. " " .. k end end end
check(be and be:find("/combat/"), "byEnv counted under combat: " .. tostring(be))

print(string.format("v2229_sched: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
