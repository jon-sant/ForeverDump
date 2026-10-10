local WROOT = os.getenv("WOWDEV_ROOT") or (function() -- portable root (handoff)
  local s = debug.getinfo(1, "S").source:sub(2)
  if s:sub(1, 1) ~= "/" then local p = io.popen("pwd"); s = p:read("*l") .. "/" .. s; p:close() end
  return s:match("^(.*)/kth/") or s:match("^(.*)/foreverdump/") or ".."
end)()
-- R18 (forever.10, unit test): meter minimum healer count, elimination, druid form share. Row values are real C_DamageMeter
-- reads from the replays (kmin_sim.py); the elimination cases are synthetic records (labelled), no names from any run.
package.path = WROOT .. "/foreverdump/tests/?.lua;" .. WROOT .. "/kth/tests/?.lua;" .. package.path
local W = dofile(WROOT .. "/foreverdump/tests/wowenv.lua"); _G.__W = W
local TF = require("tocfiles")
dofile(WROOT .. "/kth/tests/mockextra.lua")
local ns = {}
for _, f in ipairs(TF.files(arg[1] or WROOT .. "/kth/port/KTH/KTH.toc")) do
  local chunk = assert(loadfile(f)); pcall(chunk, "KTH", ns)
end
pcall(W.fire, "ADDON_LOADED", "KTH")
local A = LibStub("AceAddon-3.0"):GetAddon("K.T.H.")
local E = A and A.ForeverEvidence
assert(E and E.kRange and E.elimCandidate and E.formShare, "forever.10 helpers missing")
local bad, n = 0, 0
local function check(name, got, want)
  n = n + 1
  if got ~= want then bad = bad + 1; print("R18 FAIL", name, tostring(got), "want", tostring(want)) end
end
-- real rows: { label, n, heal rows, damage rows, kmin, kmax }
local rows = {
  { "run19 PRIEST t+488 (Moun proof)", 2, { 1353, 1215 }, { 6084 }, 1, 1 },
  { "run19 PRIEST t+111 (no proof yet)", 2, { 1353, 803 }, { 1825, 46 }, 0, 1 },
  { "run19 DRUID t+111 (1 non-healer)", 3, { 5965, 4644, 354 }, { 1346, 16, 16 }, 2, 2 },
  { "run18 DRUID t+1170 (DPS druid at 60.05%: margin)", 2, { 1416, 745 }, { 942, 651 }, 0, 1 },
  { "run18 PRIEST t+1233 (kmin 2 of 3 healers: never a cap)", 3, { 3138, 2651, 2256 }, { 1930, 314 }, 2, 3 },
  { "run17 PALADIN t+451", 3, { 1737, 1650, 22 }, { 1814, 843, 685 }, 1, 2 },
  { "run19 PALADIN t+488 (Aurelís group: no proof)", 2, { 3101 }, { 3115, 1021 }, 0, 1 },
}
for _, c in ipairs(rows) do
  local a, b = E.kRange(c[2], c[3], c[4])
  check(c[1] .. " kmin", a, c[5]); check(c[1] .. " kmax", b, c[6])
end
check("kRange n > kMaxN gives nil", (E.kRange(E.CFG.kMaxN + 1, {}, {})), nil)
-- form share: (RAGE+ENERGY)/samples, nil below formMin samples
check("formShare few samples", E.formShare({ pw = { RAGE = 3 }, pwN = 3 }), nil)
check("formShare", E.formShare({ pw = { RAGE = 6, ENERGY = 2, MANA = 2 }, pwN = 10 }), 0.8)
-- elimination (synthetic records): kmin 1, two players; X has a damage link and no heal link -> Y is the healer
E.reset()
local X = E.get(false, "SynthX One"); X.dmg = 1
local Y = E.get(false, "SynthY Two")
local px, py = { full = "SynthX One", first = "SynthX", class = "PRIEST" }, { full = "SynthY Two", first = "SynthY", class = "PRIEST" }
local K = { kmin = 1, players = { px, py } }
check("elim: remaining player marked", E.elimCandidate(K, py, "PRIEST"), true)
check("elim: eliminated player never", E.elimCandidate(K, px, "PRIEST"), false)
check("elim: kmin 0 marks nobody", E.elimCandidate({ kmin = 0, players = { px, py } }, py, "PRIEST"), false)
X.dmg = 0
check("elim: nobody eliminated -> no mark", E.elimCandidate(K, py, "PRIEST"), false)
check("elim: excluded (form) player eliminated", E.elimCandidate({ kmin = 1, players = { px, py }, excl = { ["SynthX One"] = true } }, py, "PRIEST"), true)
print("R18", bad == 0 and "ok" or "FAIL", "meter minimum count / elimination / form share: " .. n .. " checks")
os.exit(bad == 0 and 0 or 1)
