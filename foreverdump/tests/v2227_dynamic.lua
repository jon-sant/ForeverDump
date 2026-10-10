-- v2.2.27: aura-presence candidates are dynamic only (no curated / mined list).
-- (1) Earthborer Acid 18070 is learned from an out-of-combat read (UNIT_AURA payload and slot scan) without being listed
-- (2) own clear cast -> aura pair observed out of combat -> derivation (D) in combat
-- (3) the measured limit: warning + counter when hit, candidates prioritised (on me / mine, recent, most seen)
-- (4) per-build spellbook cache (built by /fdump static run) adds aura-like spells; per-build stores; v2.2.26 migration
-- (5) lint: no static spell list in the addon's aura code, no Data/AuraSeed.lua, no AuraSeed in the toc
-- usage: lua5.1 tests/v2227_dynamic.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local itype = "none"
local ns = W.loadAddon(addonDir, files, "ForeverDump")
IsInInstance = function() return itype ~= "none", itype end
IsInGroup = function() return false end
-- v2.2.26 profile: flat auraLearned (spellID keys) must move under the current build
ForeverDumpDB = ForeverDumpDB or {}
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
local S = W.state
local function env(it, combat) itype, S.combat = it, combat ns.InvalidateEnv() return ns.Env() end
local AP = ns.AuraPresence
ns.LearnedAuras = nil   -- v2.2.28: the generated offline file is tested in v2228_coldstart
local B = tostring(ns.Build())

print("(4a) v2.2.26 flat learned store migrates under the build")
ns.db.auraLearned = { [905] = { n = 4, dur = 600, name = "Lightning Shield" } }
local L = AP.Store("auraLearned")
check(L[905] and L[905].dur == 600 and ns.db.auraLearned[905] == nil and ns.db.auraLearned[B][905], "905 moved to auraLearned[" .. B .. "]")
ns.db.auraLearned, ns.db.auraPairs, ns.db.spellCache = nil, nil, nil
AP.listDirty = true
check(#AP.List() == 0, "empty profile -> no candidates")

print("(1) Earthborer Acid 18070 learned from an out-of-combat read")
local present = {}
C_UnitAuras.GetUnitAuraBySpellID = function(u, sid)
    if S.combat then return nil end
    return present[u .. "|" .. sid] and { spellId = sid, auraInstanceID = 3 } or nil
end
C_UnitAuras.GetAuraSlots = function() if S.combat then return nil end return nil, 1 end
local slot = {}
C_UnitAuras.GetAuraDataByIndex = function(u, i, filter)
    if S.combat then error("Auras cannot be accessed when secret while tainted by 'ForeverDump'") end
    local a = slot[u .. "|" .. filter]
    return i == 1 and a or nil
end
env("none", false)
ForeverDumpLogDB.auraPresence = nil
-- UNIT_AURA payload (clear out of combat) carries the new aura
W.fire("UNIT_AURA", "player", { addedAuras = { { spellId = 18070, name = "Earthborer Acid", duration = 30,
    isFromPlayerOrPlayerPet = false, auraInstanceID = 41 } } })
AP.OnUnitAura("player", { addedAuras = { { spellId = 18070, name = "Earthborer Acid", duration = 30,
    isFromPlayerOrPlayerPet = false, auraInstanceID = 41 } } })
L = AP.Store("auraLearned")
check(L[18070] and L[18070].dur == 30 and L[18070].name == "Earthborer Acid" and (L[18070].self or 0) >= 1,
    "UNIT_AURA payload -> 18070 learned (dur 30, on me)")
present["player|18070"] = true
AP.Tick()
local d = ForeverDumpLogDB.auraPresence
check(AP.inList[18070] == "learned", "18070 is a candidate (source learned)")
local tagO = ns.EnvTag()
check(d.codes[tagO].player[18070].K == 1, "18070 presence read on player out of combat -> K")
-- slot scan alone also learns (no UNIT_AURA)
ns.db.auraLearned = nil
slot["player|HARMFUL"] = { spellId = 18070, name = "Earthborer Acid", duration = 30, expirationTime = 99,
    auraInstanceID = 41, sourceUnit = "", isFromPlayerOrPlayerPet = false }
AP.Tick()
check(AP.Store("auraLearned")[18070] ~= nil, "GetAuraDataByIndex slot scan out of combat -> 18070 learned")

print("(2) own clear cast -> observed pair -> derived in combat")
UnitGUID = function(u) return u == "player" and "Player-1-0000AAAA" or (u == "target" and "Creature-0-1-1-1-1-77") or nil end
S.time = (S.time or 0) + 5
AP.OnOwnCast(8050)                                    -- Flame Shock cast, out of combat
S.time = S.time + 0.2
AP.OnUnitAura("target", { addedAuras = { { spellId = 8050, name = "Flame Shock", duration = 12, isFromPlayerOrPlayerPet = true } } })
slot["target|HARMFUL"] = { spellId = 8050, name = "Flame Shock", duration = 12, expirationTime = 50, auraInstanceID = 9,
    sourceUnit = "player", isFromPlayerOrPlayerPet = true }
AP.Tick()                                             -- slot scan sees the same aura: counted once
local P = AP.Store("auraPairs")
check(P[8050] and P[8050][8050] and P[8050][8050].n == 1 and P[8050][8050].target == 1, "pair 8050 -> 8050 (target) observed once")
S.time = S.time + 3
AP.OnUnitAura("player", { addedAuras = { { spellId = 77777, name = "Late Aura", duration = 5, isFromPlayerOrPlayerPet = true } } })
check(not (P[8050] and P[8050][77777]), "an aura 3 s after the cast does not pair")
S.time = S.time + 1   -- v2.2.28: an aura in the same instant as a cast pairs with it (AP.EARLY_WINDOW)
env("none", true)
local nd = #(d.derived or {})
AP.OnOwnCast(8050)
check(#d.derived == nd + 1 and d.derived[#d.derived]:find("|8050|8050|target|Creature%-0%-1%-1%-1%-1%-77|12.0|learned|"),
    "combat cast derives 8050 on the target, 12 s learned: " .. tostring(d.derived[#d.derived]))
AP.Tick()
local hasD = false
for _, r in ipairs(d.tape) do if r:find("|target|.-|8050|D|") then hasD = true end end
check(hasD, "combat read nil + derivation -> D")
check(AP.inList[8050] ~= nil, "own-cast aura is a candidate")
env("none", false)

print("(4b) per-build spellbook cache (static run)")
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 4 } end,
    GetSpellBookItemType = function(idx) return 1, nil, ({ 324, 403, 2645, 8012 })[idx] end,
}
C_Spell = C_Spell or {}
C_Spell.GetSpellName = function(sid) return ({ [324] = "Lightning Shield", [403] = "Lightning Bolt", [2645] = "Ghost Wolf", [8012] = "Purge" })[sid] end
C_Spell.GetSpellDescription = function(sid)
    return ({ [324] = "Surrounds the caster with balls of lightning. Lasts 10 min.", [403] = "Hurls a bolt of lightning.",
              [2645] = "Turns into a Ghost Wolf.", [8012] = "Purges the enemy target, removing 1 beneficial magic effect." })[sid]
end
UnitClass = function() return "Shaman", "SHAMAN", 7 end
local n = AP.BuildSpellCache()
local C = AP.Store("spellCache")
check(n == 4 and C.SHAMAN and C.SHAMAN.spells[324].aura == true and C.SHAMAN.spells[324].dur == 600 and not C.SHAMAN.spells[403].aura,
    "4 spellbook spells cached; 324 aura (10 min from description), 403 not")
AP.List()
check(AP.inList[324] == "spellcache" and AP.inList[403] == nil, "aura-like spellbook spell is a candidate, others not")
check(ns.db.spellCache[B] and ns.db.auraPairs[B] and ns.db.auraLearned[B], "all stores keyed by build " .. B)
local ds = AP.DispelSpells()
check(#ds == 1 and ds[1] == 8012 and ns.config.combatProbe.dispelSpells == nil, "dispel spells from the cache (8012 Purge), no config ID list")
local src = io.open(addonDir .. "/Static.lua"):read("*a")
check(src:find("ns.AuraPresence.BuildSpellCache", 1, true) ~= nil, "Static finish() (/fdump static run) rebuilds the cache")

print("(3) limit (v2.2.29: runaway backstop sized from the cost), warning + counter, prioritised")
for i = 1, 500 do AP.Learn(900000 + i, "Filler " .. i, 10, {}) end
AP.Learn(18070, "Earthborer Acid", 30, { self = true })
AP.costMs = 0.012
check(AP.Limit() == math.floor(AP.WALL_SHARE * 1000 / 0.012 * AP.TIER_EVERY.C / (#AP.FIXED + AP.ROTATE)) and AP.Limit() > 5000,
    "backstop from cost: " .. AP.Limit() .. " (0.012 ms/check, 5 % wall, tier C every 10 s, 7 units)")
local oldMin, oldAbs = AP.LIMIT_MIN, AP.LIMIT_ABS
AP.LIMIT_MIN, AP.LIMIT_ABS = 50, 71                     -- force a runaway: 504 candidates > 71
AP.listDirty = true
ForeverDumpLogDB.auraPresence.warnings, ForeverDumpLogDB.auraPresence.warnCount, ForeverDumpLogDB.auraPresence.limitHit = nil, nil, nil
local list = AP.List()
d = ForeverDumpLogDB.auraPresence
check(#list == 71 and d.list.limit == 71 and d.list.candidates > 500, "backstop 71 binds (" .. #list .. " of " .. d.list.candidates .. ")")
check(d.limitHit == 1 and d.warnings and d.warnings[1]:find("|limit|") and d.warnings[1]:find("runaway backstop 71"), "backstop warning logged + counted: " .. tostring(d.warnings and d.warnings[1]))
check(AP.inList[18070] and AP.inList[8050] and AP.inList[324] == nil, "kept: on-me / own-cast first; lowest priority (spellcache) beyond the backstop")
AP.listDirty = true AP.List()
check(d.limitHit == 2 and #d.warnings == 1, "counter keeps counting, warning logged once")
AP.LIMIT_MIN, AP.LIMIT_ABS, AP.costMs = oldMin, oldAbs, nil
local def = AP.Limit()
check(def >= 5000, "default backstop with the initial cost estimate: " .. def)
AP.costMs = nil
AP.listDirty = true
AP.Tick() AP.Tick()
check(type(AP.costMs) == "number" and AP.costMs > 0, string.format("cost per call measured: %.5f ms (mock) -> limit %d", AP.costMs, AP.Limit()))

print("(5) lint: no static list")
local ap = io.open(addonDir .. "/AuraPresence.lua"):read("*a")
local code = ap:gsub("%-%-[^\n]*", "")
local worst = 0
for tbl in code:gmatch("%b{}") do
    local k = 0
    for _ in tbl:gmatch("[%[{,%s]%d%d%d+[%]%s,}]") do k = k + 1 end
    if k > worst then worst = k end
end
check(worst < 3, "AuraPresence.lua: no table literal with >= 3 spell-ID-like numbers (max " .. worst .. ")")
check(not code:find("SPELLS%s*=") and not code:find("AuraSeed"), "no AP.SPELLS / AuraSeed reference")
check(io.open(addonDir .. "/Data/AuraSeed.lua") == nil, "Data/AuraSeed.lua removed")
local toc = io.open(addonDir .. "/ForeverDump.toc"):read("*a")
check(not toc:find("AuraSeed"), "toc does not load AuraSeed")

print(string.format("v2227_dynamic: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
