-- v2.2.15 (user decision 2026-10-09): capture level "lab" (FD_Logs default) = diag + parallel candidate rules (shadow)
-- + lab probes; perf there is reported, not gated, except the runaway backstop. Also: promoted rules (aura-me-elim,
-- heal-tgt-frame), GCD bracket sampling, the staged in-combat probe (max per-frame cost), no Blizzard chat writes.
-- usage: lua5.1 tests/lab_v2215.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end

-- 1. pure library: candidates, promoted rules, GCD bracket ------------------------------------------------------------
_G.HybridState = nil
local Lib = dofile(addonDir .. "/Lib/HybridState.lua")
local T = 100
local function mk(c) return Lib.New({ now = function() return T end, candidates = c, clock = function() return os.clock() * 1000 end }) end
local hs = mk(true)
local vlog = {}
hs.onVerdict = function(r) vlog[#vlog + 1] = r end
T = 100 hs:OnAura("player", { addedSecret = true })
local last = hs.inferences[#hs.inferences]
check(last and last.rule == "aura-me-elim" and last.src == "other", "promoted aura-me-elim: secret add on me, no own cast -> other")
check(hs.candLast["c-aura-me-elim"] == "other" and hs.candLast["c-aura-me-tight"] == "other" and hs.candLast["c-aura-me-self"] == "other",
    "candidate claims recorded per rule id (candLast)")
check((hs.verdicts["cand:c-aura-me-elim|P"] or 0) == 1, "each candidate logs one prediction verdict (cand:<id> P)")
T = 101 hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 324, true, "player")
T = 101.1 hs.candLast = {} hs:OnAura("player", { addedSecret = true })
last = hs.inferences[#hs.inferences]
check(last.rule == "own-cast-frame" and last.src == "mine", "own cast in the window: still own-cast-frame mine (old rule untouched)")
check(hs.candLast["c-aura-me-elim"] == "mine" and hs.candLast["c-aura-me-tight"] == "mine", "candidates agree on the own-cast case")
check(#hs.candAura >= 2, "aura candidate claims kept for the post-combat sweep check")
-- heal on a friendly target
T = 110 hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 331, true, "party1")
local r = hs:OnUnitCombat("party1", "HEAL", "", 200, 8, false)
check(r and r.rule == "heal-tgt-frame" and r.src == "mine", "promoted heal-tgt-frame: my cast at that unit in the same frame -> mine")
T = 112 r = hs:OnUnitCombat("party1", "HEAL", "", 150, 8, false)
check(r and r.src == "other", "heal on another unit without my cast -> other (was: unattributed)")
check(hs.candStats["c-heal-tgt-frame"] and hs.candStats["c-heal-tgt-frame"].n == 2, "heal-target candidates counted")
check(hs.candCost["heal-target"] and hs.candCost["heal-target"].n == 2 and hs.candCost["aura-me"].n == 2, "per-family candidate cost recorded")
-- candidates off: no shadow verdicts, promoted rules still live
local h2 = mk(false)
T = 120 h2:OnAura("player", { addedSecret = true })
check(h2.inferences[#h2.inferences].rule == "aura-me-elim" and next(h2.candStats) == nil and next(h2.verdicts) == nil,
    "release (candidates off): promoted rule acts, no candidate work or verdicts")
-- heal on me: cadence candidates all decide
local h3 = mk(true)
T = 200 h3:OnUnitCombat("player", "HEAL", "", 90, 8, true)
for _, id in ipairs({ "c-cad-tight", "c-cad-phase", "c-cad-amount", "c-cad-phase-amount", "c-heal-me-wide" }) do
    check(h3.candLast[id] ~= nil, "heal-on-me candidate " .. id .. " claims")
end
-- export carries the candidate stats
local ex = h3:Export()
check(type(ex.candStats) == "table" and ex.candStats["c-cad-tight"] and type(ex.candCost) == "table", "Export carries candStats/candCost")

-- GCD: due-time bracket
local hg = mk(false)
hg:Learn(403, { gcd = 1.5 })
local gv = {}
hg.onVerdict = function(x) if x.kind == "gcd" then gv[#gv + 1] = x.v end end
T = 300 hg:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 403, true, "target")
local g = hg.cd.gcd
check(g and g.ends, "GCD opened on my cast")
local nx = hg:CDNextSampleAt(T)
check(nx and math.abs(nx - (g.ends - 0.05)) < 1e-6, "due-time sampler: next sample just before the predicted GCD end")
T = g.ends - 0.05 hg:CDObserve(403, true, true)
nx = hg:CDNextSampleAt(T + 0.001)
check(nx and math.abs(nx - (g.ends + 0.05)) < 1e-6, "then just after it (bracket)")
T = g.ends + 0.05 hg:CDObserve(403, false, false)
check(gv[#gv] == "V", "tight bracket around the predicted end -> V")
T = 400 hg:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 403, true, "target")
local g2 = hg.cd.gcd
T = 400.5 hg:CDObserve(403, true, true)
T = g2.ends + 2.0 hg:CDObserve(403, false, false)
check(gv[#gv] == "U", "late first 'off' sample with the predicted end inside the bracket -> U (was C)")
T = 500 hg:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 403, true, "target")
local g3 = hg.cd.gcd
T = g3.ends + 0.6 hg:CDObserve(403, true, true)
T = g3.ends + 0.7 hg:CDObserve(403, false, false)
check(gv[#gv] == "C", "still on well after the predicted end -> C (check not loosened)")

-- 2. addon: lab level, backstop, staged probe, lab probes, taint ------------------------------------------------------
_G.HybridState = nil
local W = require("wowenv")
local S = W.state
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
ForeverDumpDB = { configVersion = 22, config = { replay = { captureLevel = "diag" } } }
local ns = W.loadAddon(addonDir, files, "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 30 do W.tick(1) end
ns.config.logs.autoReload = false
check(ns.db.config.replay.captureLevel == "lab", "migration: a saved diag capture level becomes lab (configVersion 23)")
check(not ns.LabActive(), "not capturing: release level, lab inactive")
local blizz0 = #W.blizzChat
W.slash("logs on") W.tick(2)
check(ns.ReplayLog.IsLab and ns.ReplayLog.IsLab() and ns.LabActive(), "FD_Logs capture elevates to lab by default")
check(ns.ReplayLog.VerifyCap() >= 250000, "lab verify ring cap = diag's")
check(ns.Inference.hs and ns.Inference.hs.candidates == true, "FD_Logs capture at lab: HSM candidates on")
check(ns.LabProbes and ForeverDumpLogDB.labProbes and ForeverDumpLogDB.labProbes.v == 1, "lab probes started with the capture")
-- in-combat events
S.combat = true
W.fire("PLAYER_REGEN_DISABLED")
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1234-0-0-133-000000000A", 133)
W.tick(1)
W.fire("UNIT_AURA", "target", W.SECRET)
W.fire("UNIT_AURA", "player", { addedAuras = { { auraInstanceID = 5, spellId = 324, isHelpful = true } } })
W.fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
W.fire("UNIT_HEALTH", "player")
W.fire("UNIT_HEAL_PREDICTION", "party1")
W.fire("UNIT_ABSORB_AMOUNT_CHANGED", "party1")
W.fire("UNIT_COMBAT", "party1", "ABSORB", "", 0, 1)
W.fire("UNIT_COMBAT", "nameplate7", "WOUND", "", W.SECRET, 1)
W.fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 1)
ns.LabProbes.Sample()
local L = ForeverDumpLogDB.labProbes
check(L.aura and L.aura.player and (L.aura.player.add or 0) >= 1 and L.aura.player.latAdd, "aura add counted per token + cast-to-aura latency histogram")
check(L.aura.target and (L.aura.target.secretInfo or 0) >= 1, "secret UNIT_AURA payload counted (presence only)")
check(L.heal and L.heal.player and L.heal.player.HEAL == 1 and L.heal.player.healAmt == 120 and L.heal.player.ucToHealth,
    "heal detail: HEAL count, clear sum, UNIT_COMBAT->UNIT_HEALTH latency")
check(L.heal.partyN and L.heal.partyN.pred == 1 and L.heal.partyN.absChg == 1 and L.heal.partyN.absToAbsorb and L.heal.partyN.codes,
    "heal prediction / absorb change counts, absorb-change->ABSORB latency, getter codes")
check(L.heal.nameplateN and L.heal.nameplateN.uc == 1, "extra tokens bucketed (nameplateN)")
check(L.sample and L.sample.player, "in-combat sampler: readability codes per extra token")
W.fire("UNIT_DIED", "Player-4619-0ABCDEF1")
W.fire("UNIT_DIED", "Creature-0-1-2-3-4-5")
local guidKey = false
for k in pairs(L.heal) do if tostring(k):find("-", 1, true) then guidKey = true end end
check(not guidKey and L.died and L.died.Player and L.died.Player.n == 1 and L.died.Creature and L.died.Creature.n == 1,
    "UNIT_DIED (GUID payload) counted by GUID type, never keyed by GUID")
-- staged probe: Logs uses RunStaged; one step per frame, timed by Perf
local src = io.open(addonDir .. "/Logs.lua"):read("*a")
check(src:find('pcall(ns.Probe.RunStaged, "capture:combat"', 1, true) ~= nil and not src:find('pcall(ns.Probe.Run, "capture:combat"', 1, true),
    "in-combat capture probe is staged")
local steps = ns.Probe.Steps("test", "inCombat", true)
local maxMs, total = 0, 0
for i = 1, #steps do
    local t0 = os.clock()
    steps[i]()
    local ms = (os.clock() - t0) * 1000
    total = total + ms
    if ms > maxMs then maxMs = ms end
end
print(string.format("  info probe: %d steps, total %.2f ms, max step %.2f ms (mock)", #steps, total, maxMs))
check(#steps >= 10, "probe split into >= 10 steps")
check(maxMs <= 10, "max per-frame probe step <= 10 ms (mock CPU clock; was one 35.75 ms frame in run 12)")
local _, n = ns.Probe.RunStaged("test2", "inCombat", true)
check(ns.Probe.staged and ns.Probe.staged.done == 1 and not ns.Probe.staged.finished, "RunStaged: one step in the first frame")
W.tick(n + 2)
check(ns.Probe.staged.finished and ns.db.sections.probe.inCombat, "RunStaged finishes over frames and stores probe.inCombat")
-- leave combat: sweep
S.combat = false
W.fire("PLAYER_REGEN_ENABLED")
W.tick(12)
check(L.sweeps and #L.sweeps == 1 and next(L.sweeps[1].at) ~= nil, "post-combat un-secret sweep ran")
check(L.sweeps[1].firstClear and next(L.sweeps[1].firstClear) ~= nil, "sweep records first-clear offsets")
-- backstop (lab: report only, user decision 2026-10-09)
local P = ns.Perf
check(P.on and P.trackHeap, "perf monitor on, heap tracked around calls at lab")
P.Add("Lab.test", 300) P.Add("Lab.test", 300)
check(not P.runaway, "two 300 ms calls: no backstop")
local c0 = #W.chat
P.Add("Lab.test", 300)
check(P.runaway and ns.LabActive() and ns.Inference.hs.candidates == true, "third >= 250 ms call within 60 s: backstop reports, lab keeps collecting")
local warned = false
for i = c0 + 1, #W.chat do if tostring(W.chat[i]):find("BACKSTOP REPORT", 1, true) then warned = true end end
check(warned, "backstop warning printed (own frame)")
local ps = ForeverDumpLogDB.perf.sessions[#ForeverDumpLogDB.perf.sessions]
check(ps.backstop and ps.backstop.tripped and ps.backstop.keys["Lab.test"] == 300, "backstop recorded in the SV")
P.SPIKE_MS = 0
P.Run("Lab.spiketest", function() local x = {} for i = 1, 1000 do x[i] = i end return #x end)
check(ps.spikes and ps.spikes.n >= 1 and ps.spikes.list[1].cause and ps.maxCall and ps.maxCall.key, "spikes recorded with GC attribution + max call")
P.SPIKE_MS = 50
W.slash("logs off") W.tick(2)
check(#W.blizzChat == blizz0, "no line went to a Blizzard chat frame")
-- release level: no lab
W.slash("level release")
check(not ns.LabActive(), "release level: lab inactive")

print(string.format("lab_v2215: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
