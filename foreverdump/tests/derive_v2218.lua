-- v2.2.18 class derivation: ClassEvidence engine + RefData + Derive.lua driver (mocked client).
-- usage: lua5.1 tests/derive_v2218.lua ForeverDump
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local CE = dofile(addonDir .. "/Lib/ClassEvidence.lua")
local ns = {}
assert(loadfile(addonDir .. "/Data/RefData.lua"))("ForeverDump", ns)
local clock = 100
local function mk() return CE.new({ ref = ns.RefData, clock = function() return clock end }) end

print("engine: elimination never assigns a class by itself unless one candidate is left")
local e = mk()
e:MarkEnemy("k1")
check(e:Power("k1", "RAGE") == nil, "rage alone: warrior or druid -> unassigned")
local _, _, uk1 = e:Get("k1")
local nk1 = 0 for _ in pairs(uk1.cand) do nk1 = nk1 + 1 end
check(nk1 == 2 and uk1.cand.WARRIOR and uk1.cand.DRUID, "rage leaves {WARRIOR, DRUID}")
e:Composition({ WARRIOR = 1, PRIEST = 3, SHAMAN = 3 })
-- v2.2.20 (run 15): a meter composition is a lower bound of the team -> provisional only, never an assignment
check(e:Get("k1") == nil and e:Provisional("k1") == "WARRIOR", "meter composition without a druid -> provisional WARRIOR, unassigned")
e:Composition({ SHAMAN = 1 })   -- a later partial session must not shrink the set
check(e:Provisional("k1") == "WARRIOR", "composition is cumulative (a later partial session does not shrink it)")

print("engine: assigning sources and contradictions")
e = mk()
e:MarkEnemy("k2")
e:Power("k2", "MANA")
check(e:Assign("k2", "SHAMAN", "meter") == "SHAMAN", "meter row class assigns")
e:Assign("k2", "MAGE", "score")
check(e:Get("k2") == "SHAMAN" and e.stats.contradictions == 1, "a later conflicting reading source is counted, the first reading stays")
e:MarkEnemy("k2b") e:Power("k2b", "RAGE") e:Allow("k2b", { WARRIOR = true }, "summon", 1)
check(e:Get("k2b") == "WARRIOR", "elimination settles WARRIOR")
e:Assign("k2b", "DRUID", "score")
check(e:Get("k2b") == "DRUID" and select(2, e:Get("k2b")) == "score", "a reading source overrides an elimination-made class")
e:MarkEnemy("k3")
e:Power("k3", "ENERGY")
e:Power("k3", "RAGE")   -- druid shapeshift: energy then rage -> DRUID
check(e:Get("k3") == "DRUID", "energy + rage over time -> DRUID (shapeshift)")
e:MarkEnemy("k4")
e:Power("k4", "ENERGY")
e:Allow("k4", { MAGE = true }, "test")
check(e:Get("k4") == nil and e.stats.contradictions >= 2, "an empty candidate set falls back to unknown (never guesses)")
e:Power("k4", "RAGE") e:Allow("k4", { WARRIOR = true }, "test")
check(e:Get("k4") == nil, "a contested unit is never settled by elimination again")
e:Assign("k4", "WARRIOR", "meter")
check(e:Get("k4") == "WARRIOR", "a contested unit still takes a reading source")
-- run 15 regression: 10 mana / rage / energy enemies, a partial comp of shamans only -> no assignment at all
e = mk()
for i = 1, 10 do e:MarkEnemy("r" .. i) e:Power("r" .. i, i <= 7 and "MANA" or (i <= 9 and "RAGE" or "ENERGY")) end
e:Composition({ SHAMAN = 3 })
local nA = 0 for i = 1, 10 do if e:Get("r" .. i) then nA = nA + 1 end end
check(nA == 0, "run 15: partial shaman-only comp assigns nobody (was 10 SHAMAN, >= 6 false)")
check(e:Provisional("r8") == nil and e:Provisional("r1") == "SHAMAN", "rage unit gets no provisional; mana units provisional SHAMAN only")

print("engine + RefData")
check(ns.RefData and ns.RefData.build == 70291, "RefData carries its client build (70291)")
local ref370 = ns.RefData.spells[370]
check(ref370 and ns.RefData.classes[ref370[1]] == "SHAMAN", "Purge (370) -> SHAMAN in the mined table")
e = mk()
check(e:Spell("k5", 370) == "SHAMAN", "a clear spellId assigns via RefData")
local nsp, ncls = 0, 0
for _, r in pairs(ns.RefData.spells) do nsp = nsp + 1 if r[1] > 0 then ncls = ncls + 1 end end
check(nsp > 300 and ncls > 200, "RefData: " .. nsp .. " spells, " .. ncls .. " with a class")
e = mk()
e:MarkEnemy("a") e:Assign("a", "SHAMAN", "meter")
e:Composition({ SHAMAN = 3 })
check(e:CountEnemy("SHAMAN") == 3, "same-class enemy count = max(assigned, meter composition)")

print("Derive.lua driver (mocked client)")
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local G = setmetatable({}, { __index = _G })
G._G = G
local env = G
local function isSecret(v) return rawequal(v, SECRET) end
local dns = { RefData = ns.RefData, ClassEvidence = CE }
dns.ClassifyValue = function(v) if v == nil then return "N" end if isSecret(v) then return "S" end
    if type(v) == "table" then return "K" end return "C" end
dns.ClearOf = function(v, want) if v == nil or isSecret(v) then return nil end if want and type(v) ~= want then return nil end return v end
dns.ClearStr = function(v) return dns.ClearOf(v, "string") end
dns.ClearTable = function(v) if type(v) ~= "table" or isSecret(v) then return nil end return v end
dns.ClearNum = function(v) return dns.ClearOf(v, "number") end
dns.ClearWithCode = function(v, c, want) if c ~= "C" then return nil end if want and type(v) ~= want then return nil end return v end
dns.IsTrue = function(v) return v == true end
dns.LabActive = function() return true end
dns.db = { logs = { on = true, session = { sid = "t" } } }
dns.ReplayLog = { IdKey = function(kind, id) if id == nil or isSecret(id) then return nil end local h = 7 for i = 1, #tostring(id) do h = (h * 31 + tostring(id):byte(i)) % 4294967296 end
    return kind .. ":" .. string.format("%08x", h) end }
local census
dns.Inference = { SetMeterEnemyCensus = function(n, t) census = n end }
G.ForeverDumpLogDB = {}
G.GetTime = function() return clock end
G.InCombatLockdown = function() return true end
local plates = { nameplate1 = { name = "Grukk", player = true, enemy = true }, nameplate2 = { name = SECRET, player = true, enemy = true } }
G.UnitExists = function(u) return plates[u] ~= nil end
G.UnitIsPlayer = function(u) return plates[u] and plates[u].player or false end
G.UnitCanAttack = function(_, u) return plates[u] and plates[u].enemy or false end
G.UnitName = function(u) return plates[u] and plates[u].name end
G.UnitClass = function(u) if u == "player" then return "Shaman", "SHAMAN", 7 end return SECRET, SECRET, SECRET end
local roster = {}
dns.DamageMeter = { Roster = function(ty) return roster end, SourceSpells = function() return { [370] = true } end }
local f = assert(loadfile(addonDir .. "/Derive.lua"))
setfenv(f, env)
f("ForeverDump", dns)
local DV = dns.Derive
check(DV ~= nil, "Derive.lua loads")
DV.OnPower("nameplate1", "RAGE")
local key = DV.UnitKey("nameplate1")
local eng = DV.Engine()
local _, _, uu = eng:Get(key)
check(uu and uu.enemy and uu.cand.WARRIOR and uu.cand.DRUID and not uu.cand.MAGE, "plate RAGE -> enemy unit narrowed to {WARRIOR, DRUID}")
DV.OnPower("nameplate2", "MANA")
check(DV.UnitKey("nameplate2") == nil, "secret plate name -> no key, no unit")
roster = {
    { class = "WARRIOR", displayType = 2, isLocal = false, kind = nil, nameKey = key, nameCode = "C", guidCode = "S" },
    { class = "SHAMAN", displayType = 2, isLocal = false, nameKey = nil, nameCode = "S", guidCode = "S" },
    { class = "SHAMAN", displayType = 2, isLocal = false, nameKey = nil, nameCode = "S", guidCode = "S" },
    { class = "PRIEST", displayType = 1, isLocal = false, guidKey = "player:1", nameKey = "name:x", nameCode = "C", guidCode = "C" },
}
DV.MeterSweep("test")
check(eng:Get(key) == "WARRIOR", "meter row with the same name key assigns WARRIOR")
local d = G.ForeverDumpLogDB.derive
check(d.meterCompLast and d.meterCompLast.SHAMAN == 2 and d.meterCompLast.WARRIOR == 1 and not d.meterCompLast.PRIEST,
    "enemy composition counts displayType 2 rows only (SHAMAN 2, WARRIOR 1; group PRIEST excluded)")
check(census == 2, "HSM enemy census fed with the meter's same-class (SHAMAN) count: " .. tostring(census))
check(d.meter.combat.enemyRows == 9 and d.meter.combat.enemyNameClear == 3, "meter readability counters (3 types x 3 enemy rows, 1 clear name each)")
-- scoreboard: clear name + classToken assigns
G.GetNumBattlefieldScores = function() return 1 end
G.C_PvP = { GetScoreInfo = function(i) return { name = "Zqmockpriest-Realm", classToken = "PRIEST", damageDone = SECRET } end }
DV.ScoreSweep()
check(eng:Get(DV.UnitKey and dns.ReplayLog.IdKey("name", "Zqmockpriest")) == "PRIEST", "scoreboard clear name+class assigns (realm stripped)")
check(d.score["GetScoreInfo|combat"].damageDone.S == 1, "scoreboard field readability recorded (damageDone secret)")
-- v2.2.20 (run 15): GetBattlefieldScore name / faction / LOCALIZED class clear, classToken secret -> enemy class
G.LOCALIZED_CLASS_NAMES_MALE = { HUNTER = "Jaeger", ROGUE = "Schurke" }
G.LOCALIZED_CLASS_NAMES_FEMALE = { HUNTER = "Jaegerin", ROGUE = "Schurkin" }
G.GetBattlefieldArenaFaction = function() return 0 end
G.GetNumBattlefieldScores = function() return 2 end
G.C_PvP = nil
G.GetBattlefieldScore = function(i)
    if i == 1 then return "Zqmockhunt-Other", SECRET, SECRET, SECRET, SECRET, 1, "Orc", "Jaegerin", SECRET, SECRET, SECRET end
    return "Zqmockfriend", SECRET, SECRET, SECRET, SECRET, 0, "Troll", "Schurke", SECRET, SECRET, SECRET
end
DV.ScoreSweep()
local hk = dns.ReplayLog.IdKey("name", "Zqmockhunt")
local hv, hvia, hu = eng:Get(hk)
check(hv == "HUNTER" and hvia == "score" and hu.enemy, "GetBattlefieldScore: localized class (female form) -> HUNTER, other faction -> enemy")
local fv, _, fu = eng:Get(dns.ReplayLog.IdKey("name", "Zqmockfriend"))
check(fv == "ROGUE" and not fu.enemy, "GetBattlefieldScore: own faction row -> ROGUE, not enemy")
check(d.score["bfRow|combat"] and d.score["bfRow|combat"][1].enemy == 1 and d.score["bfRow|combat"][1].friend == 1, "bfRow counters: 1 enemy, 1 friend")
-- v2.2.22: Forever scoreboard "First Surname" joins UnitName "First"; ambiguous first names stay unassigned
G.GetNumBattlefieldScores = function() return 3 end
G.GetBattlefieldScore = function(i)
    if i == 1 then return "Johnny Snowden", SECRET, SECRET, SECRET, SECRET, 1, "Human", "Schurke", SECRET, SECRET, SECRET end
    if i == 2 then return "Johnny Morningwind", SECRET, SECRET, SECRET, SECRET, 0, "Tauren", "Schamane", SECRET, SECRET, SECRET end
    return "Rei Skyshatter", SECRET, SECRET, SECRET, SECRET, 1, "Orc", "Krieger", SECRET, SECRET, SECRET
end
G.LOCALIZED_CLASS_NAMES_MALE.WARRIOR = "Krieger"
G.LOCALIZED_CLASS_NAMES_MALE.SHAMAN = "Schamane"
G.LOCALIZED_CLASS_NAMES_FEMALE = G.LOCALIZED_CLASS_NAMES_FEMALE or {}
DV.ScoreSweep()
local rei = dns.ReplayLog.IdKey("name", "Rei")
check(eng:Get(rei) == "WARRIOR", "Forever surname Rei Skyshatter assigns to name:Rei (UnitName form)")
local jv, jvia = eng:Get(dns.ReplayLog.IdKey("name", "Johnny"))
check(jv == nil, "two Johnny (diff factions) stay unassigned until plate hostility, got " .. tostring(jv))
-- plate sees enemy Johnny -> flush pending enemy row (ROGUE)
eng:MarkEnemy(dns.ReplayLog.IdKey("name", "Johnny"))
DV.ScoreFlush(dns.ReplayLog.IdKey("name", "Johnny"), true)
jv, jvia = eng:Get(dns.ReplayLog.IdKey("name", "Johnny"))
check(jv == "ROGUE" and jvia == "score", "ScoreFlush applies enemy Johnny Snowden -> ROGUE after hostility")

-- privacy: no raw names anywhere in the stored tables
local function scan(t, seen)
    seen = seen or {}
    if seen[t] then return false end
    seen[t] = true
    for k, v in pairs(t) do
        for _, x in ipairs({ k, v }) do
            if type(x) == "string" and (x:find("Grukk") or x:find("Zqmockpriest") or x:find("Zqmockhunt") or x:find("Zqmockfriend")) then return true end
            if type(x) == "table" and scan(x, seen) then return true end
        end
    end
    return false
end
print("learned reference data: build drift + own cast times")
local dsid, dref
for sid, r in pairs(ns.RefData.spells) do if (r[2] or 0) > 0.5 then dsid, dref = sid, r break end end
G.GetBuildInfo = function() return "1.60.2", "70400", "Oct 1 2026", 11500 end
G.UnitCastingInfo = function(u) if u == "player" then return "x", "", 0, 1000, 1000 + dref[2] * 1000 + 600, false, 1, false, dsid end end
DV.OnCastStart("UNIT_SPELLCAST_START", "player")
local L = dns.db.refLearned and dns.db.refLearned["70400"]
check(L and L.drift == true and L.shipped == 70291, "client build 70400 vs shipped 70291 -> drift flagged, learning goes to refLearned[70400]")
check(L and L.castMs[dsid] and L.castMs[dsid].n == 1, "own planned cast time learned per spell")
check(L and L.driftSpells and L.driftSpells[dsid], "own cast time 600 ms off the shipped value -> spell drift recorded")
G.GetBuildInfo = function() return "1.60.1", "70291", "", 11500 end
local L2 = DV.Learned()
check(L2 and not L2.drift, "same build as the seeds -> no drift")
DV.Stop()
check(scan(G.ForeverDumpLogDB), "v2.2.21: raw names stored in ForeverDumpLogDB.derive (units[key].names)")
check(d.units[key] and d.units[key].class == "WARRIOR" and d.units[key].via == "meter", "unit summary saved at stop (class + via)")

print("v2.2.22: power revokes non-ASSIGNING class")
do
    local ej = CE.new({})
    ej:Assign("johnny", "SHAMAN", "cache:raidN")
    check(ej:Get("johnny") == "SHAMAN", "cache settles shaman")
    ej:Power("johnny", "ENERGY")
    local cls = ej:Get("johnny")
    local u = ej.units.johnny
    check(cls == nil, "power cleared wrong shaman (energy leaves rogue|druid unset), got " .. tostring(cls))
    check(u.cand.ROGUE and u.cand.DRUID and not u.cand.SHAMAN, "cand is energy set without shaman")
    check(u.overrode == "cache:raidN", "overrode records prior via")
end

print(string.format("derive_v2218: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)

