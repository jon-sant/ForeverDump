-- v2.2.22 audit regression: a container with MIXED clear/secret fields ("T") must yield per-field codes and usable
-- clear fields everywhere; it is never discarded / coarse-coded as all-secret, and a secret field is never touched.
-- usage: lua5.1 tests/audit_t_v2222.lua ForeverDump
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end

-- secret scalar: any use but issecretvalue / rawequal / type errors and is counted
local touched = 0
local SECRET = newproxy(true)
do
    local mt = getmetatable(SECRET)
    local function boom() touched = touched + 1 error("attempt to use a secret value", 2) end
    mt.__index, mt.__newindex, mt.__tostring, mt.__concat, mt.__len, mt.__call = boom, boom, boom, boom, boom, boom
    mt.__add, mt.__sub, mt.__lt, mt.__le, mt.__unm = boom, boom, boom, boom, boom
end
local MIXED = setmetatable({}, { __mode = "k" })
issecretvalue = function(v) return rawequal(v, SECRET) end
issecrettable = function(v) return MIXED[v] == true end     -- Forever: true for a table with secret contents
canaccessvalue = function(v) return not rawequal(v, SECRET) end
local function mixed(t) MIXED[t] = true return t end

local ns = {}
pcall(function() assert(loadfile(addonDir .. "/Core.lua"))("ForeverDump", ns) end)   -- stops at CreateFrame; helpers defined

print("Core: classification + Clean")
local aura = mixed({ spellId = 8050, name = "Flame Shock", duration = SECRET, expirationTime = SECRET, sourceUnit = "target" })
check(ns.ClassifyValue(aura) == "T", "mixed aura struct classifies T (container, some secret fields)")
check(ns.IsSecret(aura) == true and ns.IsSecretValue(aura) == false, "IsSecret folds issecrettable; IsSecretValue does not")
check(ns.ClearTable(aura) == aura, "ClearTable hands out a T container (fields classified one by one)")
local cl = ns.Clean(aura)
check(type(cl) == "table", "Clean(T) walks the table (was: whole table -> SECRET_TABLE)")
check(cl and cl.spellId == 8050 and cl.name == "Flame Shock" and cl.sourceUnit == "target", "Clean(T) keeps the clear fields")
check(cl and cl.duration == ns.SECRET and cl.expirationTime == ns.SECRET, "Clean(T) marks the secret fields SECRET")
check(ns.Clean(SECRET) == ns.SECRET, "a secret scalar is still SECRET")
local fs = ns.ClassifyFields(aura)
check(fs and fs.spellId == "C" and fs.duration == "S", "ClassifyFields: per-field codes on a T struct")
if ns.ProbeCall or ns.SafeCall then
    -- optional: the multi-return probe lists T as partial, not secret
end

print("Derive: per-field reads of T structs (GetScoreInfo, GetBattlefieldScore, auras) + BG phase")
local CE = dofile(addonDir .. "/Lib/ClassEvidence.lua")
local rns = {}
assert(loadfile(addonDir .. "/Data/RefData.lua"))("ForeverDump", rns)
local G = setmetatable({}, { __index = _G })
G._G = G
local clock = 500
local dns = { RefData = rns.RefData, ClassEvidence = CE, ClassifyValue = ns.ClassifyValue, ClearOf = ns.ClearOf,
    ClearStr = ns.ClearStr, ClearNum = ns.ClearNum, ClearWithCode = ns.ClearWithCode, ClearTable = ns.ClearTable, IsTrue = ns.IsTrue, IsNil = ns.IsNil,
    IsSecretValue = ns.IsSecretValue, LabActive = function() return true end,
    db = { logs = { on = true, session = { sid = "t" } } } }
dns.ReplayLog = { IdKey = function(kind, id) if id == nil or issecretvalue(id) then return nil end return kind .. ":" .. tostring(id) end }
local notes = {}
dns.OocFill = { Note = function(key, fld, v, src) notes[#notes + 1] = { key, fld, v, src } end }
G.ForeverDumpLogDB = {}
G.GetTime = function() return clock end
local combat = false
G.InCombatLockdown = function() return combat end
G.UnitFactionGroup = function() return "Horde" end
G.GetBattlefieldArenaFaction = function() return 0 end
G.UnitClass = function() return "Shaman", "SHAMAN", 7 end
local winner, runTime, prepAura = nil, 300000, false
G.GetBattlefieldWinner = function() return winner end
G.GetBattlefieldInstanceRunTime = function() return runTime end
G.C_UnitAuras = { GetPlayerAuraBySpellID = function(sid) if prepAura and sid == 44521 then return { spellId = 44521 } end end,
    GetAuraDataByIndex = function() return aura end }
G.LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Magier", ROGUE = "Schurke" }
G.LOCALIZED_CLASS_NAMES_FEMALE = {}
G.GetNumBattlefieldScores = function() return 2 end
G.GetBattlefieldScore = function(i)
    if i == 1 then return "Zqmix Surname", SECRET, SECRET, SECRET, SECRET, 1, "Orc", "Magier", SECRET, SECRET, SECRET end
    return "Zqfriend Other", SECRET, SECRET, SECRET, SECRET, 0, "Troll", "Schurke", SECRET, SECRET, SECRET
end
local info = {
    mixed({ name = "Zqmix Surname", classToken = "MAGE", talentSpec = "Frost", guid = "Player-1-0001", faction = 1,
            killingBlows = SECRET, damageDone = SECRET, healingDone = SECRET, honorableKills = SECRET, deaths = SECRET }),
    mixed({ name = SECRET, classToken = SECRET, talentSpec = SECRET, faction = 0, damageDone = SECRET }),
}
G.C_PvP = { GetScoreInfo = function(i) return info[i] end }
local f = assert(loadfile(addonDir .. "/Derive.lua"))
setfenv(f, G)
f("ForeverDump", dns)
local DV = dns.Derive
check(DV and DV.FieldsOf and DV.ScorePhase, "Derive exposes FieldsOf + ScorePhase")

local clear, codes = DV.FieldsOf(info[1], DV.SCORE_FIELDS)
check(codes.name == "C" and codes.classToken == "C" and codes.talentSpec == "C" and codes.damageDone == "S" and codes.rating == "N",
    "FieldsOf(T): per-field codes C/S/N")
check(clear.classToken == "MAGE" and clear.talentSpec == "Frost" and clear.damageDone == nil, "FieldsOf(T): only clear fields handed out")

-- phases
check(DV.ScorePhase() == "gates", "phase: after gates, ooc (run time 300 s, no Preparation aura)")
prepAura = true check(DV.ScorePhase() == "prep", "phase: Preparation aura -> prep") prepAura = false
runTime = 60000 check(DV.ScorePhase() == "prep", "phase: run time < 120 s -> prep") runTime = 300000
combat = true check(DV.ScorePhase() == "combat", "phase: in combat") combat = false
winner = 1 check(DV.ScorePhase() == "post", "phase: winner set -> post") winner = nil

touched = 0
DV.ScoreSweep()
local d = G.ForeverDumpLogDB.derive
local gi = d.score["GetScoreInfo@gates"]
check(gi and gi[0] and gi[0].T == 2, "GetScoreInfo: both T tables counted as T (container code)")
check(gi and gi.classToken and gi.classToken.C == 1 and gi.classToken.S == 1, "GetScoreInfo@gates classToken: 1 clear, 1 secret (was: no field reads at all)")
check(gi and gi.damageDone and gi.damageDone.S == 2 and gi.talentSpec.C == 1, "GetScoreInfo@gates: damageDone secret x2, talentSpec clear x1")
check(d.score["GetScoreInfo|ooc"] and d.score["GetScoreInfo|ooc"].classToken.C == 1, "legacy ctx key also carries per-field codes")
local gb = d.score["GetBattlefieldScore@gates"]
check(gb and gb.name.C == 2 and gb.className.C == 2 and gb.classToken.S == 2 and gb.damageDone.S == 2, "GetBattlefieldScore@gates: named per-field codes")
check(d.scorePhase and d.scorePhase.gates and d.scorePhase.gates.sweeps == 1 and d.scorePhase.gates.players["2"] == 1, "phase tag + player count recorded")
-- v2.2.23: Forever GetBattlefieldScore layout (no rank): pos 7 race, 8 className, 9 classToken (clear), 10 damage
-- post-match (clear number) must not be read as the class; race must be pos 7
do
    local DVx = DV
    local dd = { score = {} }
    G.GetBattlefieldScore = function() return "Zqpost Surname", 3, 9, 1, 120, 1, "Undead", "Hexer", "WARLOCK", 45678, 1234 end
    local row = DVx.ScoreRow(dd, "ooc", nil, G.GetBattlefieldScore, 1, "post")
    check(row and row.cls == "WARLOCK", "GBS: class from pos 9 classToken (post: pos 10 damage is a clear number), got " .. tostring(row and row.cls))
    check(row and row.race == "Undead", "GBS: race from pos 7, got " .. tostring(row and row.race))
    local gp = dd.score["GetBattlefieldScore@post"]
    check(gp and gp.race.C == 1 and gp.classToken.C == 1 and gp.damageDone.C == 1 and gp.rank == nil, "GBS@post: Forever field names (no rank)")
    G.GetBattlefieldScore = function() return "Zqloc Surname", SECRET, SECRET, SECRET, SECRET, 0, "Troll", "Magier", SECRET, SECRET end
    local r2 = DVx.ScoreRow(dd, "combat", nil, G.GetBattlefieldScore, 1, "combat")
    check(r2 and r2.cls == "MAGE" and r2.race == "Troll", "GBS: secret classToken falls back to localized pos 8")
end
local eng = DV.Engine()
check(eng:Get("name:Zqmix") == "MAGE", "clear classToken of a T row assigns name:<First> (Forever 'First Surname')")
local spec = false
for _, n in ipairs(notes) do if n[1] == "name:Zqmix" and n[2] == "spec" and n[3] == "Frost" then spec = true end end
check(spec, "clear talentSpec of a T row noted (OocFill spec)")
combat = true DV.ScoreSweep() combat = false
check(d.score["GetScoreInfo@combat"] and d.score["GetScoreInfo@combat"].classToken, "combat sweep tagged @combat")
check(touched == 0, "no secret field was touched (" .. touched .. ")")

print(("audit_t_v2222: %d passed, %d failed"):format(passed, fails))
os.exit(fails == 0 and 0 or 1)
