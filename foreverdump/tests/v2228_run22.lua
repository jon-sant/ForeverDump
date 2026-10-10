-- v2.2.28 fixes from run 22 (BG, FD 2.2.27, client 70338):
-- (1) rotation counted presence CALLS: with 0 candidates every rotation token (raid1-40, party, arena, nameplates) was
--     probed each tick (21 units/tick measured). Now at most #FIXED + ROTATE units per tick.
-- (2) candidates also from the stores other modules already learn per build: refLearned[build].auraDur (OocFill,
--     out-of-combat enumeration of any unit) and knowledge[build] parsed auraDuration (spellbook, every session).
-- (3) own-cast derivation without an observed pair: same-ID rule from knowledge; consumable (charge) auras skipped.
-- (4) the list is rebuilt at least every AP.LIST_REFRESH s (those stores grow silently).
-- usage: lua5.1 tests/v2228_run22.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local itype = "pvp"
local ns = W.loadAddon(addonDir, files, "ForeverDump")
IsInInstance = function() return itype ~= "none", itype end
IsInGroup = function() return true end
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
local S = W.state
local AP = ns.AuraPresence
ns.LearnedAuras = nil   -- v2.2.28: the generated offline file is tested in v2228_coldstart
local B = tostring(ns.Build())
ns.InvalidateEnv()

print("(1) rotation counts units, not presence calls")
UnitExists = function(u) return u == "player" or u == "target" or u:find("^raid") ~= nil or u:find("^party") ~= nil end
UnitIsPlayer = function(u) return UnitExists(u) end
C_UnitAuras.GetUnitAuraBySpellID = function() return nil end
ns.db.auraLearned, ns.db.auraPairs, ns.db.spellCache, ns.db.refLearned, ns.db.knowledge = nil, nil, nil, nil, nil
AP.listDirty = true
ForeverDumpLogDB.auraPresence = nil
AP.Tick()
local d = ForeverDumpLogDB.auraPresence
local tot = 0
for _, n in pairs(d.units[ns.EnvTag()]) do tot = tot + n end
check(#AP.List() == 0, "0 candidates (run 22 situation)")
check(tot <= #AP.FIXED + AP.ROTATE and tot >= 2, "units probed in one tick: " .. tot .. " (<= " .. (#AP.FIXED + AP.ROTATE) .. "; v2.2.27: 46 here)")

print("(2) candidates from refLearned.auraDur + knowledge")
ns.db.refLearned = { [B] = { auraDur = { [20050] = { n = 7, min = 30, max = 30 }, [122] = { n = 4, min = 8, max = 8 } }, spellClass = {} } }
ns.db.knowledge = { [B] = { spells = {
    [8056] = { data = { ["info.name"] = "Frost Shock", parsed = { auraDuration = 8 } } },
    [905] = { data = { ["info.name"] = "Lightning Shield", parsed = { auraDuration = 600, consumable = true } } },
    [403] = { data = { ["info.name"] = "Lightning Bolt", parsed = { amountKind = "damage" } } } } } }
AP.listDirty = true
AP.List()
check(AP.inList[20050] == "ooclearn" and AP.inList[122] == "ooclearn", "refLearned auraDur IDs are candidates (ooclearn)")
check(AP.inList[8056] == "knowledge" and AP.inList[905] == "knowledge" and AP.inList[403] == nil, "knowledge auras are candidates, non-aura spells not")
check(select(1, AP.Duration(20050)) == 30 and select(2, AP.Duration(20050)) == "ooclearn" and select(2, AP.Duration(8056)) == "knowledge", "durations from ooclearn / knowledge")

print("(3) derivation without an observed pair: same-ID knowledge rule")
UnitGUID = function(u) return u == "player" and "Player-1-0000AAAA" or "Player-2-0000BBBB" end
S.combat = true ns.InvalidateEnv()
d.derived = nil
AP.OnOwnCast(8056)
check(d.derived and #d.derived == 1 and d.derived[1]:find("|8056|8056|target|Player%-2%-0000BBBB|8.0|knowledge|"), "Frost Shock -> 8056 on target, 8 s: " .. tostring(d.derived and d.derived[1]))
AP.OnOwnCast(905)
check(#d.derived == 1, "consumable (charges) aura not derived")
AP.OnOwnCast(403)
check(#d.derived == 1, "non-aura spell derives nothing")
S.combat = false ns.InvalidateEnv()

print("(4) list refresh picks up silently grown stores")
ns.db.refLearned[B].auraDur[18070] = { n = 1, min = 30, max = 30 }
AP.Tick()
check(AP.inList[18070] == nil, "not yet (list cached)")
S.time = S.time + AP.LIST_REFRESH + 1
AP.Tick()
check(AP.inList[18070] == "ooclearn", "after LIST_REFRESH s: 18070 (Earthborer Acid) learned by OocFill is a candidate")

print(string.format("v2228_run22: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
