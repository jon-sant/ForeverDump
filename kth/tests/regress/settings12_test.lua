local WROOT = os.getenv("WOWDEV_ROOT") or (function() -- portable root (handoff)
  local s = debug.getinfo(1, "S").source:sub(2)
  if s:sub(1, 1) ~= "/" then local p = io.popen("pwd"); s = p:read("*l") .. "/" .. s; p:close() end
  return s:match("^(.*)/kth/") or s:match("^(.*)/foreverdump/") or ".."
end)()
-- R21 (forever.12, unit test): General-tab detection settings and Reset-all. Synthetic values only.
--  * defaults: E.cfg == E.CFG for every mapped key (= forever.11); teamMax / teamClaims gone
--  * each GUI control is saved and reaches the verdict code (actVote / kRange / E.cfg read by evaluate)
--  * remove-mark threshold clamps below the lowest healer threshold in use
--  * Reset tab "Reset All to Defaults": every forever.11/12 setting, icons (live: drawn from the new table at once),
--    debug switch back to its default (on, forever.7 off-flag cleared)
package.path = WROOT .. "/foreverdump/tests/?.lua;" .. WROOT .. "/kth/tests/?.lua;" .. package.path
local W = dofile(WROOT .. "/foreverdump/tests/wowenv.lua"); _G.__W = W
local TF = require("tocfiles")
dofile(WROOT .. "/kth/tests/mockextra.lua")
local ns = {}
for _, f in ipairs(TF.files(arg[1] or WROOT .. "/kth/port/KTH/KTH.toc")) do
  local chunk = assert(loadfile(f)); pcall(chunk, "KTH", ns)
end
pcall(W.fire, "ADDON_LOADED", "KTH"); pcall(W.fire, "PLAYER_LOGIN"); pcall(W.fire, "PLAYER_ENTERING_WORLD", false, false)
local A = LibStub("AceAddon-3.0"):GetAddon("K.T.H.")
local E = A.ForeverEvidence
local bad, n = 0, 0
local function check(name, got, want)
  n = n + 1
  if got ~= want then bad = bad + 1; print("R21 FAIL", name, tostring(got), "want", tostring(want)) end
end
check("teamMax removed from CFG", E.CFG.teamMax, nil)
check("teamClaims removed", E.teamClaims, nil)
for k in pairs(E.SETTING_KEYS) do check("default cfg." .. k, E.cfg[k], E.CFG[k]) end
check("defaults 35/1000/2/2/3/1/1", table.concat({ E.cfg.offPct, E.cfg.dmMin, E.cfg.linkNet, E.cfg.healMin, E.cfg.unknownHealMin, E.cfg.elim, E.cfg.formTie }, "/"), "35/1000/2/2/3/1/1")
local opts = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("KTH_Nameplates", "dialog", "KTHTest-1.0")
local G = opts.args.general.args
for _, k in ipairs({ "removeShare", "meterMinHeal", "healsNeeded", "elimEnabled", "formTieEnabled" }) do check("GUI has " .. k, G[k] ~= nil, true) end
check("GUI remove default", G.removeShare.get(), 35); check("GUI min default", G.meterMinHeal.get(), 1000)
check("GUI heals default", G.healsNeeded.get(), 2); check("GUI elim default", G.elimEnabled.get(), true); check("GUI form default", G.formTieEnabled.get(), true)
local S = _G.KTH_NameplateSettings
-- remove-mark threshold -> offPct / dmOffPct -> actVote "off" (8 links, 3 heals = 37.5%)
local r = { heal = 3, dmg = 5 }
check("actVote 37.5% at off 35 -> stays", E.actVote(r, "PRIEST"), 0)
G.removeShare.set(nil, 40)
check("remove saved", S.removeSharePct, 40); check("cfg.offPct", E.cfg.offPct, 40); check("cfg.dmOffPct", E.cfg.dmOffPct, 40)
check("actVote 37.5% at off 40 -> remove", E.actVote(r, "PRIEST"), -1)
G.removeShare.set(nil, 80); check("remove clamped below healer 60", S.removeSharePct, 55); check("GUI shows clamped", G.removeShare.get(), 55)
S.healerShareOverrides = { DRUID = 45 }; check("clamped below lowest override 45", E.cfg.offPct, 40)
S.healerShareOverrides = {}; S.healerSharePct = 50; check("clamped below global 50", E.cfg.offPct, 45)
S.healerSharePct = nil
G.removeShare.set(nil, 35); check("remove back to default stores nil", S.removeSharePct, nil)
-- meter minimum -> dmMin -> kRange (run 19 priest read t+488 proves 1 healer at 1000, none at 1400)
check("kRange at 1000", (E.kRange(2, { 1353, 1215 }, { 6084 }, "PRIEST")), 1)
G.meterMinHeal.set(nil, 1400); check("min saved", S.meterMinHeal, 1400); check("cfg.dmMin", E.cfg.dmMin, 1400)
check("kRange at 1400", (E.kRange(2, { 1353, 1215 }, { 6084 }, "PRIEST")), 0)
G.meterMinHeal.set(nil, 1000); check("min default stores nil", S.meterMinHeal, nil)
-- heals needed -> linkNet / healMin / unknownHealMin -> actVote
local h = { heal = 2, dmg = 1 }
check("2 heals 1 hit at N=2 -> no", E.actVote(h, "PRIEST"), 0)
G.healsNeeded.set(nil, 1); check("heals saved", S.healsNeeded, 1)
check("linkNet 1", E.cfg.linkNet, 1); check("healMin 1", E.cfg.healMin, 1); check("unknownHealMin 2", E.cfg.unknownHealMin, 2)
check("2 heals 1 hit at N=1 -> yes", E.actVote(h, "PRIEST"), 1)
check("1 heal 0 hits at N=1 -> yes", E.actVote({ heal = 1, dmg = 0 }, "PRIEST"), 1)
check("1 heal, class unknown at N=1 -> no (needs 2)", E.actVote({ heal = 1, dmg = 0 }, nil), 0)
G.healsNeeded.set(nil, 4); check("4 heals 1 hit at N=4 -> no", E.actVote({ heal = 4, dmg = 1 }, "PRIEST"), 0)
check("5 heals 1 hit at N=4 -> yes", E.actVote({ heal = 5, dmg = 1 }, "PRIEST"), 1)
G.healsNeeded.set(nil, 2); check("heals default stores nil", S.healsNeeded, nil)
-- toggles -> cfg.elim / cfg.formTie (evaluate and readMeter read them; replay effect: R22)
G.elimEnabled.set(nil, false); check("elim saved", S.elimEnabled, false); check("cfg.elim 0", E.cfg.elim, 0); check("GUI elim off", G.elimEnabled.get(), false)
G.formTieEnabled.set(nil, false); check("form saved", S.formTieEnabled, false); check("cfg.formTie 0", E.cfg.formTie, 0)
G.elimEnabled.set(nil, true); check("elim default stores nil", S.elimEnabled, nil); check("cfg.elim 1", E.cfg.elim, 1)
-- detection-settings reset (General tab)
G.removeShare.set(nil, 45); G.meterMinHeal.set(nil, 2000); G.healsNeeded.set(nil, 3); G.elimEnabled.set(nil, false)
G.formTieEnabled.set(nil, false); G.healerShare.set(nil, 70); S.healerShareOverrides = { PRIEST = 80 }
G.healerShareReset.func()
for k in pairs(E.SETTING_KEYS) do check("General reset cfg." .. k, E.cfg[k], E.CFG[k]) end
check("General reset threshold", E.thresholds("PRIEST"), E.CFG.healPct)
-- Reset tab: everything (forever.11/12 settings, icons live, debug default)
G.removeShare.set(nil, 45); G.meterMinHeal.set(nil, 2000); G.healsNeeded.set(nil, 3); G.elimEnabled.set(nil, false)
G.formTieEnabled.set(nil, false); G.healerShare.set(nil, 70); S.healerShareOverrides = { PRIEST = 80, ["DRUID:Restoration"] = 50 }
G.debugEnabled.set(nil, false); check("debug off before reset", A.KTH_DebugOn(), false)
G.enemyIcon = G.enemyIcon or nil
_G.KTH_NameplateSettings.enemyIcon = "skull"
local resetAll = opts.args.resetSection.args.resetAll
resetAll.func()
local S2 = _G.KTH_NameplateSettings
check("reset: new settings table", type(S2) == "table", true)
for _, k in ipairs({ "healerSharePct", "removeSharePct", "meterMinHeal", "healsNeeded", "elimEnabled", "formTieEnabled" }) do check("reset: " .. k, S2[k], nil) end
check("reset: overrides", S2.healerShareOverrides == nil or next(S2.healerShareOverrides) == nil, true)
for k in pairs(E.SETTING_KEYS) do check("reset cfg." .. k, E.cfg[k], E.CFG[k]) end
check("reset thresholds", table.concat({ E.thresholds("PRIEST", "Holy") }, "/"), "60/60/63/65")
check("reset thresholds druid resto", table.concat({ E.thresholds("DRUID", "Restoration") }, "/"), "60/60/63/65")
check("reset: debug default on", A.KTH_DebugOn(), true); check("reset: debug checkbox", G.debugEnabled.get(), true)
check("reset: old debug-off flag cleared", A.db.global.ForeverDebugOff, nil)
check("reset: enemy icon", S2.enemyIcon, "hhtd")
-- live: the nameplate code draws from the new table at once (before forever.12 it kept the old one until /reload)
local function draw(isFriend, cls)
  local rec = {}
  local tex = { SetTexture = function(_, p) rec.path = p end, SetTexCoord = function() end, SetVertexColor = function() end }
  pcall(A.MN_ApplyIndicatorStyle, { texture = tex, SetSize = function() end }, isFriend, cls)
  return rec.path or ""
end
check("reset: enemy drawn with hhtd sheet", draw(false, "PRIEST"):match("healers_icons%.tga$") ~= nil, true)
S2.enemyIcon = "skull"; check("live table used after reset", draw(false, "SHAMAN"):match("UI%-RaidTargetingIcon_8$") ~= nil, true)
S2.enemyIcon = "hhtd"
print("R21", bad == 0 and "ok" or "FAIL", "forever.12 settings + reset all: " .. n .. " checks")
os.exit(bad == 0 and 0 or 1)
