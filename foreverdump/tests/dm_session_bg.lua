-- v2.2.12 regression for run 9's collapsed damage-meter rules (dm-unit-me 72/72 C, dm-unit-other 910/910 C) on a
-- BG-shaped fixture built from run 9's real fights (tests/fixtures/run9_dm_bg.lua, counts only).
-- Root causes pinned here:
--  A  the meter record is the cumulative C_DamageMeter SESSION (38-159 s), the live fight 1-18 s: compare over the
--     session window (all kept fights, soft included); U when the window is not fully covered (never C);
--  B  in a group DAMAGE_METER_COMBAT_SESSION_UPDATED fires for every member's hit: dm-frame is solo-only;
--  C  meter units never observed live (or observed under the meter: partial view) are U, not C.
-- usage: lua5.1 tests/dm_session_bg.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local Lib = dofile(addonDir .. "/Lib/HybridState.lua")
local FX = dofile("tests/fixtures/run9_dm_bg.lua")
local T0 = 1000
local clock = 0
local function mk(groupSize)
    local hs = Lib.New and Lib.New({ now = function() return clock end, groupSize = groupSize }) or Lib.new({ now = function() return clock end, groupSize = groupSize })
    return hs
end

local function fightOf(x)
    local f = { start = T0 + x.start, stop = x.dur and (T0 + x.start + x.dur) or nil, soft = x.soft or nil,
        lastT = x.lastT and (T0 + x.lastT) or nil,
        dmg = { mine = x.dmg.mine, other = x.dmg.other, mineN = x.dmg.mineN, otherN = 0, crit = 0, miss = 0, rules = {} },
        taken = { amount = x.taken, n = 0, miss = 0 },
        heal = { mine = x.heal.mine, other = 0, mineN = x.heal.mineN, otherN = 0, mineOver = x.heal.mineOver, mineOverN = x.heal.mineOverN, rules = {} },
        interrupts = { mine = x.interrupts, other = 0 }, dispels = { mine = x.dispels, other = 0 }, auras = { mine = 0, other = 0 },
        power = 0, liveEst = { dmTicks = {} }, world = {} }
    for _, w in ipairs(x.world) do
        f.world[w.id] = { taken = w.taken, dmg = w.dmg, heal = w.heal, interrupts = w.interrupts, dispels = w.dispels, idKey = w.id, dmTicks = {} }
    end
    return f
end

-- replay the 11 fights; reconcile each meter record when its fight is the latest hard fight (as live)
local function run(hs, priorDropped)
    hs.bornAt = T0 - 600                       -- capture started ~10 min before (run 9: ON at the BG entrance)
    local tally = {}
    hs.onVerdict = function(r) local k = r.kind .. "|" .. r.v tally[k] = (tally[k] or 0) + 1 end
    hs.fights, hs.recentFights = {}, {}
    hs.recentPushed = priorDropped             -- earlier fights of the BG had already left the 40-fight ring? (0 = no)
    local outs = {}
    for _, x in ipairs(FX.fights) do
        local f = fightOf(x)
        hs.fights[#hs.fights + 1] = f
        if hs.recentFights then hs.recentFights[#hs.recentFights + 1] = f hs.recentPushed = (hs.recentPushed or 0) + 1 end
        if x.dm then
            clock = (f.stop or f.start) + 0.5
            local rec = { duration = x.dm.duration, damage = x.dm.damage, taken = x.dm.taken, healing = x.dm.healing,
                interrupts = x.dm.interrupts, dispels = x.dm.dispels, sources = x.dm.sources }
            local o = hs:ReconcileDM(rec)
            outs[#outs + 1] = o
        end
    end
    return tally, outs
end

local tally, outs = run(mk(15), 100)   -- run 9: the BG's earlier fights had already left the exported ring
local n = 0 for _, x in ipairs(FX.fights) do if x.dm then n = n + 1 end end
check(n == 5 and #outs == 5, "fixture: 5 meter records over 11 live fights (" .. #outs .. ")")
-- A: session windows
local modes, judged = {}, 0
for _, o in ipairs(outs) do
    local w = o.window or {}
    modes[#modes + 1] = tostring(w.mode) .. "/" .. tostring(w.fights) .. "/" .. (w.complete and "ok" or "U")
    if w.complete then judged = judged + 1 end
end
check(outs[1].window and outs[1].window.mode == "session", "meter session (159 s) longer than the live fight (17.6 s) -> session window ("
    .. table.concat(modes, " ") .. ")")
-- the sessions covered by kept fights: live taken (complete observation) equals the meter == the combat log answer key
-- run 9 as recorded: every session window either reaches past the kept fights (159 s) or cuts through a soft record
-- with my activity inside the window (soft 19.9..87.0 vs windows from 61.7) -> nothing provable: all U, no C
local cAll, vAll = 0, 0
for k, v in pairs(tally) do
    if k:find("^dm%-") then if k:find("|C$") then cAll = cAll + v elseif k:find("|V$") then vAll = vAll + v end end
end
check(judged == 0 and cAll == 0 and (tally["dm-unit-other|U"] or 0) > 5 and (tally["dm-unit-other|C"] or 0) == 0 and (tally["dm-unit-me|U"] or 0) == 5,
    "run 9 as recorded: 0 of 5 sessions coverable at fight granularity -> U, 0 C (was: every dm-unit C)")
check(outs[2].metrics.taken.live == FX.answerKey[2][2] and outs[3].metrics.taken.live == FX.answerKey[3][2],
    "live taken summed over the session window == combat-log answer key (" .. tostring(outs[2].metrics.taken.live) .. ", "
    .. tostring(outs[3].metrics.taken.live) .. ")")
-- the same data with the long soft record ending before the windows (activity cut at 60 s): two sessions coverable
FX.fights[3].lastT = 60
local _, ov = run(mk(15), 100)
FX.fights[3].lastT = 87.0
local function st(o, m) return o.metrics[m] and o.metrics[m].status end
check(ov[2].window.complete and ov[3].window.complete and st(ov[2], "taken") == "match" and st(ov[3], "taken") == "match",
    "covered sessions: live taken over the session matches the meter (573/573 over 1 fight, 666/666 over 3) -> V")
-- live damage recorded WITH the group dm-frame bug (2427 vs 151, 4504 vs 229) is still caught: no loosening
check(st(ov[2], "damage") == "off" and st(ov[3], "damage") == "off" and ov[2].units.player.verdict == "off",
    "group dm-frame over-attribution in the recorded live damage still contradicts the meter (dm-damage, dm-unit-me C)")
-- other units: only damage taken BY the unit is comparable; never-observed units are U
local function others(o) local v, c, u = 0, 0, 0
    for id, r in pairs(o.units) do if not r.isMe and id ~= "player" then
        if r.verdict == "match" then v = v + 1 elseif r.verdict == "off" then c = c + 1 else u = u + 1 end end end
    return v, c, u end
local v2, c2, u2 = others(ov[2])
check(c2 == 0 and u2 > 0, "session 2 others: no C from units never observed or from different quantities (" .. v2 .. "V " .. c2 .. "C " .. u2 .. "U)")
local _, c3 = others(ov[3])
check(c3 == 1 and ov[3].units.u8 and ov[3].units.u8.status.taken.live > ov[3].units.u8.status.taken.dm,
    "session 3: the one other-unit C is live taken ABOVE the meter (540 vs 475: token copies counted twice, fixed in Inference)")
-- no ring eviction: the 159 s session is judged against the 2 kept fights it covers (live taken 55 << meter 2711 -> U,
-- live under the meter; me-unit C only through the over-attributed damage)
local t3 = run(mk(15), 0)
check((t3["dm-taken|C"] or 0) == 0, "live under the meter is U, never C (taken 55 vs 2711 with earlier fights missing)")

-- B: dm-frame is solo-only
local function dmFrameRule(gs)
    local hs = mk(gs)
    clock = 50
    hs:OnCombatState(true)
    hs:OnDamageMeter(0)          -- a meter tick (any group member's hit)
    return hs:damageRule(clock, 1)
end
check(dmFrameRule(1) == "dm-frame", "solo: a meter tick in the same frame still attributes the hit (runs 6/6b rule kept)")
check(dmFrameRule(15) ~= "dm-frame", "group of 15: a meter tick is not evidence the hit was mine")
local hsS = mk(1) hsS:SetGroupSize(15)
check(hsS.groupSize == 15, "SetGroupSize feeds the engine (Inference: GetNumGroupMembers on GROUP_ROSTER_UPDATE)")

-- cd-ready: one verdict per shared-category sample; late sample without proof of error -> U, proven errors -> C
local vt
local function cdEngine()
    local hc = mk(1)
    vt = {}
    hc.onVerdict = function(r) if r.kind == "cd-ready" then vt[#vt + 1] = r end end
    for _, id in ipairs({ 8052, 8056, 8046 }) do hc:CDPayload(id, id, 19, 133) hc:CDSeed(id, { cooldown = 6, gcd = 1.5 }) end
    return hc
end
local function cycle(samples)   -- cast at 100 (predicted ready 106), then { t, isActive } samples of every shock
    local hc = cdEngine()
    clock = 100 hc:CDCast(8056, clock)
    for _, id in ipairs({ 8052, 8056, 8046 }) do hc:CDObserve(id, true, false) end
    for _, sm in ipairs(samples) do
        clock = sm[1]
        for _, id in ipairs({ 8052, 8056, 8046 }) do hc:CDObserve(id, sm[2], false) end
    end
    return hc
end
cycle({ { 107.2, false } })      -- first sample after the predicted end: 1.2 s observation latency
check(#vt == 1, "shared category (shocks, cat 19): one cd-ready verdict per sample, not 3 (" .. #vt .. ")")
check(vt[1] and vt[1].v == "U" and vt[1].why == "sample-latency", "late sample, nothing proves the prediction wrong -> U ("
    .. tostring(vt[1] and vt[1].v) .. ")")
cycle({ { 106.6, true }, { 107, false } })   -- still cooling 0.6 s after the predicted end: proven too short
check(vt[1] and vt[1].v == "C" and vt[1].why == "late", "still cooling after predicted end + tol -> C (late)")
cycle({ { 103, false } })
check(vt[1] and vt[1].v == "C" and vt[1].why == "early", "ready 3 s before the predicted end -> C (early)")
cycle({ { 106.1, false } })
check(vt[1] and vt[1].v == "V", "ready within tolerance of the predicted end -> V")
local hc = cdEngine()
clock = 500 hc:CDCast(8056, clock)
hc:CDCheckList(2, 4)
clock = 505 hc:CDCheckList(2, 4)   -- within 2 s of ready: in the due set
local due = hc:CDNextSampleAt(505)
check(due and math.abs(due - 506.02) < 0.01, "due-time sample scheduled at the predicted end (" .. tostring(due) .. ")")
local due2 = hc:CDNextSampleAt(506.05)
check(due2 and math.abs(due2 - 506.30) < 0.01, "second probe at end + tolerance (" .. tostring(due2) .. ")")
print(string.format("dm_session_bg: %d passed, %d failed", passed, fails))
if fails > 0 then os.exit(1) end
