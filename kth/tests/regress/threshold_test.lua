local WROOT = os.getenv("WOWDEV_ROOT") or (function() -- portable root (handoff)
  local s = debug.getinfo(1, "S").source:sub(2)
  if s:sub(1, 1) ~= "/" then local p = io.popen("pwd"); s = p:read("*l") .. "/" .. s; p:close() end
  return s:match("^(.*)/kth/") or s:match("^(.*)/foreverdump/") or ".."
end)()
-- R19 (forever.11, unit test): healer threshold setting. Defaults = forever.10 (E.CFG) exactly; GUI writes reach the
-- verdict code; precedence class+spec -> class -> global -> built-in; "Use global" clears; clamp; reset. Plus the single
-- debug switch: checkbox, /kthdebug alias, migration of the forever.7 /kthdebug off flag. Synthetic values only.
package.path = WROOT .. "/foreverdump/tests/?.lua;" .. WROOT .. "/kth/tests/?.lua;" .. package.path
local W = dofile(WROOT .. "/foreverdump/tests/wowenv.lua"); _G.__W = W
local TF = require("tocfiles")
dofile(WROOT .. "/kth/tests/mockextra.lua")
local ns = {}
for _, f in ipairs(TF.files(arg[1] or WROOT .. "/kth/port/KTH/KTH.toc")) do
  local chunk = assert(loadfile(f)); pcall(chunk, "KTH", ns)
end
pcall(W.fire, "ADDON_LOADED", "KTH")
pcall(W.fire, "PLAYER_LOGIN")
pcall(W.fire, "PLAYER_ENTERING_WORLD", false, false)
local A = LibStub("AceAddon-3.0"):GetAddon("K.T.H.")
local E = A and A.ForeverEvidence
assert(E and E.thresholds and E.sharePct, "forever.11 threshold API missing")
local bad, n = 0, 0
local function check(name, got, want)
  n = n + 1
  if got ~= want then bad = bad + 1; print("R19 FAIL", name, tostring(got), "want", tostring(want)) end
end
local function th(c, s) local a, b, g, k = E.thresholds(c, s); return table.concat({ a, b, g, k }, "/") end
local C = E.CFG
local base = table.concat({ C.healPct, C.dmSharePct, C.grpSharePct, C.kSharePct }, "/")
check("built-in = 60/60/63/65", base, "60/60/63/65")
-- GUI
local reg = LibStub("AceConfigRegistry-3.0")
local opts = reg:GetOptionsTable("KTH_Nameplates", "dialog", "KTHTest-1.0")
local G = opts.args.general.args
local function sel(key) return G["share_" .. key:gsub(":", "_")] end
local entries = 0
for _, e in ipairs(A.KTH_SHARE_ENTRIES) do
  entries = entries + 1
  local o = sel(e[1]); check("entry " .. e[1] .. " exists", o ~= nil, true)
  if o then check(e[1] .. " default Use global", o.get(), "0"); check(e[1] .. " collapsed", o.hidden(), true)
            check(e[1] .. " offers Use global", (type(o.values) == "function" and o.values() or o.values)["0"], "Use global") end
end
check("9 class/spec entries", entries, 9)
-- defaults: every class / spec resolves to E.CFG (forever.10)
for _, c in ipairs({ "PRIEST", "PALADIN", "DRUID", "SHAMAN" }) do
  check("default " .. c, th(c, nil), base); check("default " .. c .. ":Holy", th(c, "Holy"), base); check("default " .. c .. ":Restoration", th(c, "Restoration"), base)
end
check("default unknown class", th(nil, nil), base)
check("GUI global shows 60", G.healerShare.get(), 60)
G.healerShareShow.set(nil, true); check("section expands", sel("PRIEST").hidden(), false)
-- global
G.healerShare.set(nil, 55)
check("global saved", _G.KTH_NameplateSettings.healerSharePct, 55)
check("global 55 -> margins kept", th("DRUID", nil), "55/55/58/60")
G.healerShare.set(nil, 60); check("global back to default stores nil", _G.KTH_NameplateSettings.healerSharePct, nil)
G.healerShare.set(nil, 55)
-- class override beats global; spec unknown -> class
sel("PRIEST").set(nil, "70")
check("class override saved", _G.KTH_NameplateSettings.healerShareOverrides.PRIEST, 70)
check("PRIEST spec unknown -> class", th("PRIEST", nil), "70/70/73/75")
check("PRIEST:Holy unset -> class", th("PRIEST", "Holy"), "70/70/73/75")
check("DRUID -> global", th("DRUID", "Restoration"), "55/55/58/60")
-- class+spec override beats class
sel("PRIEST:Holy").set(nil, "80")
check("PRIEST:Holy -> spec", th("PRIEST", "Holy"), "80/80/83/85")
check("PRIEST:Discipline -> class", th("PRIEST", "Discipline"), "70/70/73/75")
check("PRIEST unknown -> class", th("PRIEST", nil), "70/70/73/75")
check("GUI shows 80", sel("PRIEST:Holy").get(), "80")
-- the verdict code uses it: links 4 heal / 2 damage = 66.7%
local r = { heal = 4, dmg = 2 }
check("actVote PRIEST at class 70 -> no", E.actVote(r, "PRIEST"), 0)
check("actVote DRUID at global 55 -> yes", E.actVote(r, "DRUID"), 1)
r.specName = "Holy"; sel("PRIEST:Holy").set(nil, "60")
check("actVote PRIEST:Holy spec 60 -> yes", E.actVote(r, "PRIEST"), 1)
-- meter rows: run 18 druid read t+1170 proves 1 healer once DRUID is set to 55 (kSharePct 60)
local km = E.kRange(2, { 1416, 745 }, { 942, 651 }, "DRUID")
check("kRange DRUID at global 55", km, 1)
check("kRange PRIEST at 70 (no proof)", (E.kRange(2, { 1416, 745 }, { 942, 651 }, "PRIEST")), 0)
-- Use global clears; clamp; reset
sel("PRIEST:Holy").set(nil, "0"); check("Use global clears", _G.KTH_NameplateSettings.healerShareOverrides["PRIEST:Holy"], nil)
_G.KTH_NameplateSettings.healerSharePct = 10; check("clamp low -> 40", E.sharePct("DRUID"), 40)
_G.KTH_NameplateSettings.healerSharePct = 99; check("clamp high -> 90", E.sharePct("DRUID"), 90)
G.healerShareReset.func()
check("reset global", _G.KTH_NameplateSettings.healerSharePct, nil)
check("reset overrides", next(_G.KTH_NameplateSettings.healerShareOverrides), nil)
check("reset -> forever.10", th("PRIEST", "Holy"), base)
-- debug switch
local S, g = _G.KTH_NameplateSettings, A.db.global
S.debugEnabled = nil; g.ForeverDebugOff = nil
check("debug default on (forever.10 timeline state)", A.KTH_DebugOn(), true)
S.debugEnabled = nil; g.ForeverDebugOff = true
check("migrates /kthdebug off", A.KTH_DebugOn(), false)
check("migration persisted", S.debugEnabled, false)
local D = G.debugEnabled
D.set(nil, true); check("checkbox on", A.KTH_DebugOn(), true); check("old flag cleared", g.ForeverDebugOff, nil); check("checkbox get", D.get(), true)
check("MNP DebugLog follows", A.MNP_GetDebug(), true)
SlashCmdList["KTHDEBUG"](""); check("/kthdebug flips off", A.KTH_DebugOn(), false); check("checkbox reflects", D.get(), false)
check("MNP DebugLog follows off", A.MNP_GetDebug(), false); check("old flag set", g.ForeverDebugOff, true)
SlashCmdList["KTHDEBUG"](""); check("/kthdebug flips on", A.KTH_DebugOn(), true)
SlashCmdList["KTHDEBUG"]("off"); check("/kthdebug off", D.get(), false)
SlashCmdList["KTHDEBUG"]("status"); check("/kthdebug status keeps", D.get(), false)
SlashCmdList["KTHDEBUG"]("on"); check("/kthdebug on", D.get(), true)
print("R19", bad == 0 and "ok" or "FAIL", "healer threshold setting + overrides + debug switch: " .. n .. " checks")
os.exit(bad == 0 and 0 or 1)
