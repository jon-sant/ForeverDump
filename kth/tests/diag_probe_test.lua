local WROOT = os.getenv("WOWDEV_ROOT") or (function() -- portable root (handoff)
  local s = debug.getinfo(1, "S").source:sub(2)
  if s:sub(1, 1) ~= "/" then local p = io.popen("pwd"); s = p:read("*l") .. "/" .. s; p:close() end
  return s:match("^(.*)/kth/") or s:match("^(.*)/foreverdump/") or ".."
end)()
-- Diag probe test: secret-flagged score tables still get per-field codes; phase tag present; no Blizzard chat.
package.path = WROOT .. "/foreverdump/tests/?.lua;" .. WROOT .. "/kth/tests/?.lua;" .. package.path
local W = dofile(WROOT .. "/foreverdump/tests/wowenv.lua"); _G.__W = W
dofile(WROOT .. "/kth/tests/mockextra.lua")
local TF = require("tocfiles")
local SECRET = W.SECRET
local flagged = { name = "Uglaz Doomaxe", talentSpec = SECRET, classToken = "PRIEST", healingDone = SECRET }
issecrettable = function(t) return rawequal(t, flagged) end
_G.__inInstance, _G.__instType, _G.__numScores = true, "pvp", 2
GetBattlefieldScore = function(i) return "Uglaz Doomaxe", SECRET, SECRET, SECRET, SECRET, 0, 3, "Orc", "Priest", SECRET, SECRET, SECRET end
C_PvP = C_PvP or {}
C_PvP.GetScoreInfo = function(i) if i == 1 then return flagged end return SECRET end
for _, toc in ipairs({ "../baseline/KTH/KTH.toc", "../baseline/KTH_ForeverDiag/KTH_ForeverDiag.toc" }) do
    local name, ns = toc:match("([^/]+)%.toc$"), {}
    for _, f in ipairs(TF.files(toc)) do local c = loadfile(f); if c then pcall(c, name, ns) end end
end
W.fire("ADDON_LOADED", "KTH"); W.fire("ADDON_LOADED", "KTH_ForeverDiag"); W.fire("PLAYER_LOGIN")
W.state.combat = true
W.fire("UPDATE_BATTLEFIELD_SCORE")
local DB = KTHForeverDiagDB
local keys = {}
for k, v in pairs(DB.score) do local s = {} for c, n in pairs(v) do s[#s + 1] = c .. "=" .. n end keys[#keys + 1] = k .. " " .. table.concat(s, ",") end
table.sort(keys)
for _, k in ipairs(keys) do print(k) end
print("samples", #DB.scoreInfoRows, DB.scoreInfoRows[1] and DB.scoreInfoRows[1].vals._tableCode, DB.scoreInfoRows[1] and DB.scoreInfoRows[1].vals.name)
assert(#W.blizzChat == 0, "Blizzard chat written")
local found = false
for _, k in ipairs(keys) do if k:find("GetScoreInfo.talentSpec@T|combat|p2 S=1", 1, true) then found = true end end
assert(found, "per-field code inside flagged table missing")
print("DIAG PROBE TEST OK")
