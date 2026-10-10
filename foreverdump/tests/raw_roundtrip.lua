-- v2.2.21 (user decision 2026-10-09: store raw identities, never scrub): capture -> SavedVariables round trip.
-- Feeds known raw GUIDs and full names (with realm) through the capture paths (HSM engine, tape map / world samples,
-- class-engine units, ooc fill cache, damage-meter snapshot), stops the capture, runs PLAYER_LOGOUT (SVPack) and writes
-- the SV file the client would write. tests/test_v2221.py then asserts every value arrives byte-identical through
-- SVPack -> converter -> analysis. usage: lua5.1 tests/raw_roundtrip.lua ForeverDump tests/out/raw_roundtrip_sv.lua
package.path = "./tests/?.lua;" .. package.path
local addonDir, outPath = arg[1] or "ForeverDump", arg[2] or "tests/out/raw_roundtrip_sv.lua"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local S = W.state
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local ns = W.loadAddon(addonDir, files, "ForeverDump")
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
W.slash("logs on")
W.tick(3)
local PG = "Player-4619-0ABCDEF1"
local CG = "Creature-0-1234-5678-90-12345-0000ABCDEF"
local FULL = "Grukk-Stonefist Realm"
local hs = ns.Inference and ns.Inference.hs
check(hs ~= nil, "live engine running")
S.combat = true
hs:OnCombatState(true)
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8050, true, PG)
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8050, true, CG)
hs:OnUnitCombat(PG, "WOUND", nil, 100, 4, false)
hs:OnCombatState(false)
S.combat = false
local R = ns.ReplayLog
R.OnMapDelta("nameplate3", R.IdKey("player", PG), "live", PG)
R.OnMapDelta("nameplate4", R.IdKey("npc", CG), "live", CG)
ns.Derive.NoteRaw(R.IdKey("name", "Grukk"), FULL, PG)
local OF = ns.OocFill
local c = OF and OF.Cache()
check(c ~= nil, "ooc fill cache")
if c then
    local key = R.IdKey("player", PG)
    c:Put(key, "name", FULL, "nameplate", "ooc")
    c:Put(key, "guid", PG, "nameplate", "ooc")
    c:Put(key, "class", "SHAMAN", "nameplate", "ooc")
end
check(R.IdKey("player", PG) == "player:" .. PG, "key = player:<raw GUID>")
W.slash("logs off")
W.tick(3)
if OF then OF.Stop() end
if ns.Derive and ns.Derive.Stop then ns.Derive.Stop() end
W.fire("PLAYER_LOGOUT")
W.writeSavedVariables(outPath, W.SV_NAMES)
local f = io.open(outPath)
local body = f:read("*a")
f:close()
check(body:find(PG, 1, true) ~= nil, "SV file holds the raw player GUID")
check(body:find(CG, 1, true) ~= nil, "SV file holds the raw creature GUID")
check(body:find(FULL, 1, true) ~= nil, "SV file holds the full name with realm")
check(not body:find(":redacted", 1, true) and not body:find("<redacted>", 1, true), "no redaction placeholders")
print(string.format("raw_roundtrip: %d passed, %d failed", passed, fails))
if fails > 0 then os.exit(1) end
