-- v2.2.21 (user decision 2026-10-09: store raw, never scrub): converted from the v2.2.12 GUID-scrub gate. Drives the
-- live engine with GUID-keyed units and asserts the exact raw GUIDs reach the export (SavedVariables), the HSM panel
-- and the SV after OFF - unmodified, no salted hashes, no "redacted" placeholders.
-- usage: lua5.1 tests/raw_identity.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
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
local I = ns.Inference
local hs = I and I.hs
check(hs ~= nil, "live engine running")
local PG, CG = "Player-4619-0ABCDEF1", "Creature-0-1234-5678-90-12345-0000ABCDEF"
S.combat = true
hs:OnCombatState(true)
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8050, true, PG)
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8050, true, CG)
hs:OnUnitCombat(PG, "WOUND", nil, 100, 4, false)
hs:OnUnitCombat(CG, "WOUND", nil, 50, 4, false)
hs:OnCombatState(false)
S.combat = false
local rawUnits = 0
for _, p in ipairs(hs.predictions) do if type(p.unit) == "string" and p.unit:find("^Player%-") then rawUnits = rawUnits + 1 end end
check(rawUnits > 0, "setup: engine predictions hold raw GUID unit keys in memory (" .. rawUnits .. ")")
local function find(t, needle)
    local hits, seen = 0, {}
    local function walk(x, depth)
        if type(x) == "string" then if x:find(needle, 1, true) then hits = hits + 1 end return end
        if type(x) ~= "table" or seen[x] or depth > 12 then return end
        seen[x] = true
        for k, v in pairs(x) do walk(k, depth + 1) walk(v, depth + 1) end
    end
    walk(t, 0)
    return hits
end
local function count(t, pat)
    local hits, seen = 0, {}
    local function walk(x, depth)
        if type(x) == "string" then if x:find(pat) then hits = hits + 1 end return end
        if type(x) ~= "table" or seen[x] or depth > 12 then return end
        seen[x] = true
        for k, v in pairs(x) do walk(k, depth + 1) walk(v, depth + 1) end
    end
    walk(t, 0)
    return hits
end
local ex = hs:Export()
check(find(ex, PG) > 0, "Export (SavedVariables): the exact player GUID is stored (" .. find(ex, PG) .. ")")
check(find(ex, CG) > 0, "Export (SavedVariables): the exact creature GUID is stored (" .. find(ex, CG) .. ")")
check(count(ex, ":redacted") == 0 and count(ex, "^player:%x%x%x%x%x%x%x%x$") == 0, "Export: no redacted / hashed keys")
local text = ns.HSMUI and ns.HSMUI.Text and ns.HSMUI.Text() or ""
check(text:find("Last predictions", 1, true) ~= nil, "panel text built")
check(text:find(PG, 1, true) ~= nil or text:find(CG, 1, true) ~= nil, "HSM panel shows the raw GUID")
check(not text:find(":redacted", 1, true), "HSM panel: no redacted placeholder")
check(ns.ReplayLog.IdKey("player", PG) == "player:" .. PG, "IdKey is kind:<raw GUID>")
check(ns.ReplayLog.IdKey("name", "Grukk-Realm") == "name:Grukk-Realm", "IdKey keeps the full name with realm")
check(ns.ReplayLog.IdKey("npc", CG) == "npc:12345" and ns.ReplayLog.RawGuid(CG) == CG, "npc group key + raw GUID helper")
W.slash("logs off")
W.tick(3)
local inf = (ns.db and ns.db.inference) or ForeverDumpLogDB and ForeverDumpLogDB.inference or {}
local n = 0
for _, k in ipairs({ "predictions", "inferences", "contradictions", "fights", "casts", "castModel", "cd" }) do
    n = n + find(inf[k], PG) + find(inf[k], CG)
end
check(inf.predictions ~= nil and n > 0, "after OFF: HSM blocks in the SV hold the raw GUIDs (" .. n .. ")")
print(string.format("raw_identity: %d passed, %d failed", passed, fails))
if fails > 0 then os.exit(1) end
