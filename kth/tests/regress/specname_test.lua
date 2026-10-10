local WROOT = os.getenv("WOWDEV_ROOT") or (function() -- portable root (handoff)
  local s = debug.getinfo(1, "S").source:sub(2)
  if s:sub(1, 1) ~= "/" then local p = io.popen("pwd"); s = p:read("*l") .. "/" .. s; p:close() end
  return s:match("^(.*)/kth/") or s:match("^(.*)/foreverdump/") or ".."
end)()
-- R16 (run19 fix, unit test): scoreboard talentSpec name -> kind. Real values seen on Forever post-match (run 19):
-- the class name ("Priest", "Druid", "Paladin"); these must give nil (no unmark), healer spec names HEALER, known DPS
-- spec names DPS, anything unknown nil.
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
assert(E and E.specKindFromName, "ForeverEvidence not loaded")
local cases = {
  { "PRIEST", "Priest", nil }, { "DRUID", "Druid", nil }, { "PALADIN", "Paladin", nil }, { "SHAMAN", "Shaman", nil },
  { "PRIEST", "Holy", "HEALER" }, { "PRIEST", "Discipline", "HEALER" }, { "DRUID", "Restoration", "HEALER" },
  { "PALADIN", "Holy", "HEALER" }, { "SHAMAN", "Restoration", "HEALER" },
  { "PRIEST", "Shadow", "DPS" }, { "DRUID", "Feral", "DPS" }, { "PALADIN", "Retribution", "DPS" }, { "SHAMAN", "Enhancement", "DPS" },
  { "PRIEST", "", nil }, { "PRIEST", "Something", nil },
}
local bad = 0
for _, c in ipairs(cases) do
  local got = E.specKindFromName(c[1], c[2])
  if got ~= c[3] then bad = bad + 1; print("R16 FAIL", c[1], c[2], tostring(got), "want", tostring(c[3])) end
end
print("R16", bad == 0 and "ok" or "FAIL", "scoreboard spec names: " .. #cases .. " cases, class-name values give no verdict")
os.exit(bad == 0 and 0 or 1)
