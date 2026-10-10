-- v2.2.25 exact full-name join (plate UnitName realm == Forever scoreboard surname; runs 16-18 45/45) as the primary
-- scoreboard join, first name + faction as the fallback. usage: lua5.1 tests/v2225_exact.lua ForeverDump
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local CE = dofile(addonDir .. "/Lib/ClassEvidence.lua")
local ns = {}
assert(loadfile(addonDir .. "/Data/RefData.lua"))("ForeverDump", ns)
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local function isSecret(v) return rawequal(v, SECRET) end
local G = setmetatable({}, { __index = _G })
G._G = G
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
local function IK(kind, id) if id == nil or isSecret(id) then return nil end return kind .. ":" .. tostring(id) end
dns.ReplayLog = { IdKey = IK }
dns.Inference = { SetMeterEnemyCensus = function() end }
G.ForeverDumpLogDB = {}
G.GetTime = function() return 100 end
G.InCombatLockdown = function() return true end
local plates = {
    nameplate1 = { name = "Johnny", realm = "Snowden", enemy = true },       -- enemy Johnny (scoreboard faction 1)
    nameplate2 = { name = "Rei", realm = "Skyshatter", enemy = true },
}
G.UnitExists = function(u) return plates[u] ~= nil end
G.UnitIsPlayer = function(u) return plates[u] ~= nil end
G.UnitCanAttack = function(_, u) return plates[u] and plates[u].enemy or false end
G.UnitName = function(u) local p = plates[u] if p then return p.name, p.realm end end
G.UnitClass = function(u) if u == "player" then return "Shaman", "SHAMAN", 7 end return SECRET, SECRET, SECRET end
dns.DamageMeter = { Roster = function() return {} end, SourceSpells = function() return {} end }
local f = assert(loadfile(addonDir .. "/Derive.lua"))
setfenv(f, G)
f("ForeverDump", dns)
local DV = dns.Derive
local eng = DV.Engine()
G.LOCALIZED_CLASS_NAMES_MALE = { ROGUE = "Schurke", SHAMAN = "Schamane", WARRIOR = "Krieger" }
G.LOCALIZED_CLASS_NAMES_FEMALE = {}
G.GetBattlefieldArenaFaction = function() return 0 end
G.GetNumBattlefieldScores = function() return 3 end
G.GetBattlefieldScore = function(i)
    if i == 1 then return "Johnny Snowden", SECRET, SECRET, SECRET, SECRET, 1, "Human", "Schurke", SECRET, SECRET, SECRET end
    if i == 2 then return "Johnny Morningwind", SECRET, SECRET, SECRET, SECRET, 0, "Tauren", "Schamane", SECRET, SECRET, SECRET end
    return "Rei Skyshatter", SECRET, SECRET, SECRET, SECRET, 1, "Orc", "Krieger", SECRET, SECRET, SECRET
end

print("seenFull from UnitName realm (Forever surname)")
local k1 = DV.UnitKey("nameplate1")
check(k1 == "name:Johnny", "before the scoreboard lists Johnny twice, the plate keys by first name")
check(DV.seenFull["Johnny Snowden"] ~= nil, "plate Johnny-Snowden noted as full name 'Johnny Snowden'")
DV.UnitKey("nameplate2")
check(DV.seenFull["Rei Skyshatter"] ~= nil, "Rei-Skyshatter noted")

print("ScoreSweep: exact primary, first+faction fallback")
DV.ScoreSweep()
check(eng:Get("name:Johnny-Snowden") == "ROGUE", "shared first name, exact full name seen -> own key name:Johnny-Snowden = ROGUE")
local _, _, ju = eng:Get("name:Johnny-Snowden")
check(ju and ju.enemy == true, "exact row from the other faction marks its own key enemy")
check(eng:Get("name:Johnny-Morningwind") == nil, "the unseen Johnny (Morningwind) is not assigned by the exact join")
check(eng:Get("name:Johnny") == nil, "the shared first-name key stays unassigned (fallback: pending until hostility)")
check(eng:Get("name:Rei") == "WARRIOR", "unique first name with exact full name seen -> WARRIOR")
local d = G.ForeverDumpLogDB.derive
local joins = {}
for k, byv in pairs(d.score) do if k:find("^bfJoin|") then for _, t in pairs(byv) do
    if type(t) == "table" then for v, n in pairs(t) do joins[v] = (joins[v] or 0) + (type(n) == "number" and n or 0) end end end end end
local hasExact, hasExactU = false, false
for v in pairs(joins) do if v:find(":exact:") then hasExact = true end if v:find(":exact%-unique:") then hasExactU = true end end
check(hasExact and hasExactU, "bfJoin counters record how=exact and how=exact-unique")
print("after the scoreboard: tokens of a shared first name key by First-Surname")
check(DV.UnitKey("nameplate1") == "name:Johnny-Snowden", "plate Johnny-Snowden now keys name:Johnny-Snowden")
plates.nameplate3 = { name = "Johnny", realm = SECRET, enemy = false }
check(DV.UnitKey("nameplate3") == "name:Johnny", "secret realm -> first-name key (fallback path)")
print("friend exact row: MarkFriend on its own key")
plates.nameplate4 = { name = "Johnny", realm = "Morningwind", enemy = false }
DV.UnitKey("nameplate4")
DV.ScoreSweep()
local mv, _, mu = eng:Get("name:Johnny-Morningwind")
check(mv == "SHAMAN" and mu and not mu.enemy and mu.friend, "Johnny Morningwind (own faction) -> SHAMAN, marked friend")

print(string.format("v2225_exact: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
