-- v2.2.4: Drift guard (seed = starting point), Learned spell / NPC / class DB, group-aware token scanner, Timing drift.
local addonDir = arg[1] or "ForeverDump"
local passed, failures = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1 else failures = failures + 1 print("  FAIL " .. msg) end
end
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local T = 1000
local combat = false
_G.GetTime = function() return T end
local clock = 0
_G.debugprofilestop = function() return clock end
local units = {}   -- token -> { guid, name, class, exists }
_G.UnitExists = function(u) local x = units[u] clock = clock + 0.002 return x and (x.exists == SECRET and SECRET or true) or false end
_G.UnitGUID = function(u) local x = units[u] clock = clock + 0.002 return x and x.guid end
_G.UnitName = function(u) local x = units[u] return x and x.name end
_G.UnitClass = function(u) local x = units[u] return x and x.class, x and x.class end
_G.UnitIsUnit = function(a, b) return units[a] ~= nil and units[a] == units[b] end
_G.UnitCanAttack = function(_, u) local x = units[u] return x and x.hostile or false end
_G.UnitLevel = function() return 20 end
_G.UnitHealth = function() return SECRET end
for _, n in ipairs({ "UnitHealthMax", "UnitPower", "UnitIsPlayer", "UnitReaction", "UnitIsDeadOrGhost", "UnitAffectingCombat" }) do
    _G[n] = function() return 1 end
end
local roster = { raid = false, group = false, n = 0, inst = "none" }
_G.IsInRaid = function() return roster.raid end
_G.IsInGroup = function() return roster.group end
_G.GetNumGroupMembers = function() return roster.n end
_G.IsInInstance = function() return roster.inst ~= "none", roster.inst end
_G.C_Spell = { GetSpellInfo = function(id) return { name = "Spell" .. id, castTime = 1500 } end,
    GetSpellSubtext = function() return "Rank 3" end, IsSpellHelpful = function() return false end, IsSpellHarmful = function() return true end }
_G.GetSpellBaseCooldown = function() return 6000, 1500 end
local tickers = {}
_G.C_Timer = { NewTicker = function(sec, fn) local t = { sec = sec, fn = fn } function t:Cancel() self.cancelled = true end tickers[#tickers + 1] = t return t end,
    After = function(_, fn) fn() end }
local frames = {}
_G.CreateFrame = function() local f = { ev = {} } function f:SetScript(_, fn) self.fn = fn end function f:RegisterEvent(e) self.ev[e] = true end
    function f:UnregisterAllEvents() self.ev = {} end frames[#frames + 1] = f return f end
_G.date = os.date
_G.time = os.time
local ns = { db = {}, config = { drift = {}, learned = {}, tokenscan = { budgetMs = 0.05, maxTokensPerSlice = 50 }, timing = {} } }
ns.Build = function() return "70245" end
ns.InCombat = function() return combat end
ns.ClassifyValue = function(v) if v == SECRET then return "S" elseif v == nil then return "N" elseif type(v) == "table" then return "K" end return "C" end
ns.IsSecret = function(v) return v == SECRET end
-- v2.2.7 Core clearing helpers (same contract as Core.lua: classify first, hand out clear copies only)
ns.ClearOf = function(v, want) if ns.ClassifyValue(v) ~= "C" then return nil end if want ~= nil and type(v) ~= want then return nil end return v end
ns.ClearNum = function(v) return ns.ClearOf(v, "number") end
ns.ClearStr = function(v) return ns.ClearOf(v, "string") end
ns.ClearBool = function(v) return ns.ClearOf(v, "boolean") end
ns.ClearWithCode = function(v, c, want) if c ~= "C" then return nil end if want ~= nil and type(v) ~= want then return nil end return v end
ns.ClearTable = function(v) if type(v) ~= "table" or ns.ClassifyValue(v) == "S" then return nil end return v end
ns.IsTrue = function(v) return type(v) == "boolean" and ns.ClassifyValue(v) == "C" and rawequal(v, true) end
ns.IsNil = function(v) return type(v) == "nil" end
ns.Resolve = function(path) local cur = _G for part in path:gmatch("[^%.]+") do if type(cur) ~= "table" then return nil end cur = cur[part] end return cur end
ns.Pack = function(...) return { n = select("#", ...), ... } end
local unexpected = {}
ns.Verify = { Unexpected = function(kind, key) unexpected[#unexpected + 1] = kind .. ":" .. tostring(key) end }
local function load(f) assert(loadfile(addonDir .. "/" .. f))("ForeverDump", ns) end
load("Drift.lua")
load("Data/spell-timing.lua")
load("Data/learned-seed.lua")
load("Timing.lua")
load("Learned.lua")
load("Tokens.lua")
_G.HybridState = nil
local Lib = dofile(addonDir .. "/Lib/HybridState.lua")
local D, L, S = ns.Drift, ns.Learned, ns.Tokens.Scan

------------------------------------------------------------------ Drift guard
check(ns.LearnedSeed and ns.LearnedSeed.schema == "foreverdump.learned/1", "learned seed loads")
local it
for _ = 1, 2 do it = D.Observe("gcd", 9999, 1.5, 1.0) end
check(it and not it.flag, "2 disagreeing observations: not yet drift")
it = D.Observe("gcd", 9999, 1.5, 1.0)
check(it.flag and it.new == 1.0, "seed 1.5 contradicted by 3 observations of 1.0 -> drift flagged, new value 1.0")
local v, flagged = D.Value("gcd", 9999, 1.5)
check(v == 1.0 and flagged, "runtime prefers the newer observed value (seed untouched)")
local cl = ns.db.drift["70245"].changelog
check(#cl == 1 and cl[1].old == 1.5 and cl[1].new == 1.0 and cl[1].build == "70245" and cl[1].date, "changelog old -> new with build / date")
check(unexpected[#unexpected]:match("^drift:gcd:9999"), "drift raises a Verify.Unexpected change alert")
for _ = 1, 30 do D.Observe("gcd", 9999, 1.5, 1.5) end
check(not D.Value("gcd", 9999, 1.5) or select(2, D.Value("gcd", 9999, 1.5)) == false, "agreement coming back reverts the flag")
check(ns.db.drift["70245"].changelog[2].what == "reverted", "revert logged")
local agree = D.Observe("gcd", 8888, 1.5, 1.52)
check(agree and not agree.flag, "within tolerance: agreement")
for _ = 1, 3 do it = D.Category("secrecy", "UnitGUID/target/combat", "C", "S") end
check(it.flag and it.new == "S", "categorical baseline (secrecy code) contradicted 3x -> flagged")
check(D.Decay("high", "60000", os.date("%Y-%m-%d")) == "medium", "other build: confidence decays one step")
check(D.Decay("high", "70245", "2020-01-01") == "low", "> 90 days: low")
check(D.Decay("high", "70245", os.date("%Y-%m-%d")) == "high", "same build, fresh: unchanged")
ns.db.lastClientBuild = "69000"
local bc = D.BuildCheck()
check(bc and bc.old == "69000" and bc.new == "70245", "client build change detected (re-baseline)")
check(D.BuildCheck() == nil, "build change logged once")

------------------------------------------------------------------ Timing seed drift -> CooldownTracker override
local hs = Lib.New({ now = function() return T end })
ns.Timing.Attach(hs)
local sv = ns.SpellTimingSeed.spells[2484].gcd
check(sv == 1.0, "Earthbind seed GCD 1.0")
-- seed says 1.0; the live isOnGCD flips keep measuring 1.25 (a hypothetical patch) -> override after 3
for _ = 1, 3 do ns.Timing.Learn("gcd", 2484, 1.25) end
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 2484, true, nil)
local gq = hs:GCD()
check(gq and math.abs(gq.length - 1.25) < 1e-6, "seed GCD contradicted by 3 live observations -> HS:GCD() uses the observed 1.25 s")
check(select(2, D.Value("gcd", 2484, 1.0)) == true, "drift flagged for the Earthbind GCD")
local hs2 = Lib.New({ now = function() return T end })
ns.Timing.Attach(hs2)
hs2:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 2484, true, nil)
check(math.abs(hs2:GCD().length - 1.25) < 1e-6, "next session: the drift override is applied at Attach (seed stays 1.0)")

------------------------------------------------------------------ Learned DB
L.Start()
L.Attach(hs)
units.target = { guid = "Creature-0-1-2-3-4119-0000AAAA", name = "Elder Cloud Serpent", hostile = true }
units.nameplate3 = units.target
units.targettarget = { guid = "Player-1-0000AAAA", name = "Me" }
units.player = units.targettarget
units.party1 = { guid = "Player-1-0000BBBB", name = "Someone", class = "MAGE" }
T = 2000
L.OnCast("UNIT_SPELLCAST_START", "target", "Cast-1", 8246)
L.OnCast("UNIT_SPELLCAST_START", "nameplate3", "Cast-1", 8246)   -- same cast via another token
T = 2003.5
L.OnCast("UNIT_SPELLCAST_SUCCEEDED", "target", "Cast-1", 8246)
L.OnCast("UNIT_SPELLCAST_SUCCEEDED", "nameplate3", "Cast-1", 8246)
local d = ns.db.learned["70245"]
local e = d.spells[8246]
check(e and e.n == 1 and e.cast.npc[1] == 1 and math.abs(e.cast.npc[2] - 3.5) < 1e-6, "NPC cast time 3.5 s learned once (deduped across tokens)")
local ne = d.npcs[4119]
check(ne and ne.name == "Elder Cloud Serpent" and ne.spells[8246] == 1 and ne.cast[8246][1] == 1, "NPC DB: name, spells, cast model")
check(ne.tgt and ne.tgt.me == 1, "NPC typical target: me")
-- secret spellID (hostile in combat): counted per NPC as 'secret', nothing derived from the secret
T = 2010
L.OnCast("UNIT_SPELLCAST_START", "target", SECRET, SECRET)
T = 2012
L.OnCast("UNIT_SPELLCAST_INTERRUPTED", "target", SECRET, SECRET)
check(ne.spells.secret == 1 and ne.interrupted == 1, "secret spellID: counted as 'secret' + interrupted, no value stored")
-- other player's class catalog (no name / GUID stored)
L.OnCast("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-9", 133)
check(d.classes.MAGE and d.classes.MAGE.spells[133] == 1, "class catalog: MAGE cast 133")
-- own cast -> aura map + amounts
T = 2020
L.OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-10", 8052)
L.OnAura("Creature-0-1-2-3-4119-0000AAAA", { spellId = 8052, duration = 12, helpful = false, fromPlayer = true, dispelName = "Magic" }, 2020.3)
L.OnAmount(8052, "damage", 38, false, 4)
L.OnAmount(8052, "damage", 70, true, 4)
local fs = d.spells[8052]
check(fs.aura[8052] and fs.aura[8052].dur[2] == 12 and fs.aura[8052].helpful == false and fs.aura[8052].dispel == "Magic", "cast -> aura map: Flame Shock debuff 12 s, Magic")
check(fs.amt.damage[2] == 38 and fs.amt.damageCrit[3] == 70 and fs.school == 4, "damage ranges (normal / crit) + school")
-- nothing personal in the SV tables
local function scan(t, path)
    for k, x in pairs(t) do
        local p = path .. "." .. tostring(k)
        if type(x) == "string" then check(not x:match("^Player%-") and not x:match("^Creature%-") and x ~= "Someone" and x ~= "Me", "no GUID / player name at " .. p) end
        if type(k) == "string" then check(not k:match("Player%-"), "no GUID key at " .. p) end
        if type(x) == "table" then scan(x, p) end
    end
end
scan(d, "learned")
-- info queue: out of combat only, ticker only while non-empty
check(L.QueueSize() > 0 and #tickers > 0, "new spells queued for the out-of-combat info read (ticker started)")
combat = true
check(L.Drain() == L.QueueSize() and L.QueueSize() > 0, "in combat: no info reads")
combat = false
for _ = 1, 10 do for _, t in ipairs(tickers) do if not t.cancelled then t.fn() end end end
check(L.QueueSize() == 0 and d.spells[8246].name == "Spell8246" and d.spells[8246].rank == 3 and d.spells[8246].ct == 1.5, "OOC drain: name / rank / cast time read")
local live = 0 for _, t in ipairs(tickers) do if not t.cancelled then live = live + 1 end end
check(live == 0, "queue empty -> ticker cancelled (no idle work)")
-- cast-time drift vs the learned seed (castMedian 3.5 seed -> observed 4.5 repeatedly)
ns.LearnedSeed.spells[8246] = ns.LearnedSeed.spells[8246] or {}
ns.LearnedSeed.spells[8246].castTime = 3.5
for i = 1, 3 do
    T = 3000 + i * 10
    L.OnCast("UNIT_SPELLCAST_START", "target", "C-" .. i, 8246)
    T = T + 4.5
    L.OnCast("UNIT_SPELLCAST_SUCCEEDED", "target", "C-" .. i, 8246)
end
check(select(2, D.Value("castTime", 8246, 3.5)) == true, "learned seed cast time contradicted 3x -> drift flagged")
-- LRU cap
ns.config.learned.maxSpells = 20
for i = 1, 40 do L.OnAmount(500000 + i, "damage", 1, false, 1) end
check(d.n.spells <= 32, "spells LRU-capped (cap + slack)")
-- perf: OnCast O(1)
local t0 = os.clock()
for i = 1, 20000 do T = 5000 + i L.OnCast("UNIT_SPELLCAST_SUCCEEDED", "target", "P" .. i, 8246) end
local us = (os.clock() - t0) / 20000 * 1e6
check(us < 30, string.format("Learned.OnCast O(1): %.2f us per event", us))

------------------------------------------------------------------ token scanner (group-aware, time budget)
roster.raid, roster.group, roster.n, roster.inst = true, true, 40, "pvp"
for i = 1, 40 do units["raid" .. i] = { guid = "Player-1-000" .. (1000 + i), name = "R" .. i, class = "WARRIOR" } end
units.raid7 = units.party1
units["raid3target"] = units.target
S.Start()
local ctx = S.Context()
check(ctx.group == "raid" and ctx.instance == "pvp" and ctx.members == 40 and ctx.key:match("|pvp|raid$"), "BG detected as raid group in a pvp instance (detected, not assumed)")
local list = S.state.list
local hasRaid40, hasArena, hasPlate, hasRTT = false, false, false, false
for _, tk in ipairs(list) do
    if tk == "raid40" then hasRaid40 = true end
    if tk == "arena1" then hasArena = true end
    if tk == "nameplate40target" then hasPlate = true end
    if tk == "raid12targettarget" then hasRTT = true end
end
check(hasRaid40 and hasArena and hasPlate and hasRTT and #list > 300, "broad list: raid1-40 (+target/targettarget), arena, nameplate (+target): " .. #list)
check(list[1] == "player" and list[17] == "raid1", "expected families first (raid in a BG)")
-- budget: each UnitGUID costs 0.002 'ms' in this mock -> slice stops at the 0.05 ms budget
S.Slice()
local c = S.cur
check(c.slices == 1 and c.tokens >= 1 and c.tokens < 50, "slice stops at the time budget (" .. c.tokens .. " tokens)")
for _ = 1, 400 do S.Slice() end
check(c.sweeps >= 1, "full sweep of the list completed (" .. c.sweeps .. ")")
local sdb = ns.db.tokenscan["70245"]
local m = sdb.m[ctx.key]
check(m and m.raidN and m.raidN.guid.C >= 40 and m.raidN.health.S >= 40, "matrix: raidN guid clear, health secret (codes per family / field)")
check(sdb.dup["party1=raidN"] or sdb.dup["raidN=party1"] or sdb.dup["nameplateN=target"] or sdb.dup["raidNtarget=target"], "dedupe: identical GUIDs across tokens counted per family pair")
-- alias: target GUID secret, a cast seen the same instant on raid3target (clear) -> alias learned
units.nameplate5 = { guid = SECRET, exists = SECRET, name = SECRET }
S.state.map.nameplate5 = nil
T = 9000
S.OnCast("UNIT_SPELLCAST_START", "raid3target", "Cast-X")
S.OnCast("UNIT_SPELLCAST_START", "nameplate5", "Cast-X")
local g5, _, via = S.GUIDOf("nameplate5")
check(g5 == units.target.guid and via == "raid3target", "secret-GUID token resolved by alias (same castGUID on a clear token)")
check(sdb.alias["nameplateN<-raidNtarget:castGUID"] == 1, "alias counted per family pair (no GUIDs in the SV)")
local cost = S.Stop()
check(cost and cost.ms > 0 and cost.maxSliceMs <= 0.05 + 0.01 and cost.reads > 0, string.format("scan cost logged per capture: %.3f ms, max slice %.4f ms", cost.ms, cost.maxSliceMs))
check(sdb.baseline and next(sdb.baseline), "matrix baseline stored at capture stop")
-- next capture: a cell changes (raidN health becomes clear) -> change alert
S.Start()
_G.UnitHealth = function() return 100 end
for _ = 1, 400 do S.Slice() end
local c2 = S.Stop()
check(c2.changes >= 1, "token matrix re-verified: change alert on raidN health S -> C (" .. c2.changes .. ")")
local found = false
for _, x in ipairs(ns.db.drift["70245"].changelog) do if x.kind == "token-matrix" and tostring(x.key):match("raidN/health") then found = true end end
check(found, "matrix change written to the drift changelog")
scan(sdb, "tokenscan")

-- perf gate (v2.2.4): the slice deadline is checked after EVERY field read, not per token. One slow API (UnitName
-- 0.03 'ms', more than half the 0.05 ms budget) -> slices stop mid-token and the next slice resumes at the next field.
do
    _G.UnitHealth = function() return SECRET end
    local baseName = _G.UnitName
    _G.UnitName = function(u) clock = clock + 0.03 return baseName(u) end
    S.Start()
    local soft = 0.05 - math.min(0.04, 0.05 * 0.5)   -- budget - bail (bail capped at half the budget)
    local worst, resumed = 0, 0
    for _ = 1, 900 do
        local c0 = clock
        S.Slice()
        if clock - c0 > worst then worst = clock - c0 end
        if S.state.resume then resumed = resumed + 1 end
    end
    local c3 = S.Stop()
    check(worst <= soft + 0.03 + 0.002 + 1e-9, string.format("slice overrun bounded by one call past the soft deadline: worst %.3f ms (soft %.3f + slowest call 0.03)", worst, soft))
    check(resumed > 0, "a token interrupted by the deadline resumes in the next slice (" .. resumed .. " resumes)")
    local cm = S.state.cm[S.state.ctx.key]
    local rf = cm and cm.raidN
    local function tot(x) local n = 0 for _, cnt in pairs(x or {}) do n = n + cnt end return n end
    check(rf and tot(rf.guid) > 0 and math.abs(tot(rf.guid) - tot(rf.dead)) <= 1 and math.abs(tot(rf.name) - tot(rf.combat)) <= 1,
        string.format("resumed tokens complete every field (raidN guid %d / name %d / dead %d reads)", tot(rf and rf.guid), tot(rf and rf.name), tot(rf and rf.dead)))
    check(c3.overBudget ~= nil and c3.maxSliceMs > 0, "per-capture cost records over-budget slices (" .. tostring(c3.overBudget) .. ")")
    _G.UnitName = baseName
end

-- perf gate: SPELL_UPDATE_COOLDOWN re-check list is O(due + budget), not O(cooling spells) (incremental heap + RR)
do
    local tt = 500
    local h = Lib.New({ now = function() return tt end })
    for i = 1, 60 do h:CDSeed(7000 + i, { cooldown = 30 + i, gcd = 1.5 }) end
    for i = 1, 60 do tt = 500 + i * 0.01 h:CDCast(7000 + i, tt) end
    check(h.cd.nActive == 60 and #h.cd.list == 60, "60 spells cooling, dense active list kept incrementally")
    tt = 502
    local l1 = {}
    for i, id in ipairs(h:CDCheckList(2, 4)) do l1[i] = id end   -- the returned buffer is reused by the next call
    check(#l1 <= 4 + 1, "far from ready: only the GCD spell + <= 4 round-robin spells re-read (" .. #l1 .. ")")
    local l2 = h:CDCheckList(2, 4)
    local same = 0
    for _, a in ipairs(l1) do for _, b in ipairs(l2) do if a == b and a ~= (h.cd.gcd and h.cd.gcd.spell) then same = same + 1 end end end
    check(same == 0, "far spells re-read at most once per second each (no repeat in the next event)")
    -- spell 7001 (31 s) gets close to ready -> the heap moves it into the due set; it is re-read on every event
    tt = 500.01 + 31 - 1.5
    local due1, due2 = false, false
    for _, id in ipairs(h:CDCheckList(2, 4)) do if id == 7001 then due1 = true end end
    for _, id in ipairs(h:CDCheckList(2, 4)) do if id == 7001 then due2 = true end end
    check(due1 and due2, "spell within 2 s of predicted ready re-read on every event (heap -> due set)")
    -- ready observed -> leaves the active set (O(1) swap-remove) and the due set
    h:CDObserve(7001, false, false)
    check(not h.cd.active[7001] and not h.cd.due[7001] and #h.cd.list == h.cd.nActive, "observed ready: swap-removed from list + due set")
    check(h.cd.latest ~= 7001 and h.cd.latest ~= nil, "latest-cooldown pointer re-picked when it settles (UI bar O(1) per step)")
    -- predicted expiry without an observation: retired 2 s after predicted ready when visited
    tt = 500.6 + 60 + 2.5
    for _ = 1, 40 do h:CDCheckList(2, 4) end
    check(h.cd.nActive < 60 and #h.cd.list == h.cd.nActive, "expired spells retired incrementally (" .. h.cd.nActive .. " left)")
    -- many reschedules do not grow the heap without bound
    for _ = 1, 500 do h:cdSchedule(7060, h.cd.spells[7060]) end
    check(#h.cd.heap <= 4 * (h.cd.nActive + 16) + 1, "heap rebuilt when stale entries pile up (" .. #h.cd.heap .. ")")
end

print(string.format("learned: %d passed, %d failed", passed, failures))
if failures > 0 then os.exit(1) end
