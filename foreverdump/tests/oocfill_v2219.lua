-- v2.2.19 out-of-combat fill + full unit-token sweep (mocked client): dynamic token enumeration, identity merge across
-- tokens, staleness / drift / contradiction, prefill coverage, target-chain shadow rules, readability matrix, raw identities stored.
-- usage: lua5.1 tests/oocfill_v2219.lua ForeverDump
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local function isSecret(v) return rawequal(v, SECRET) end
local clock = 1000
local G = setmetatable({}, { __index = _G })
G._G = G
local ns = { db = { logs = { on = true, session = { sid = "t" } } } }
ns.ClassifyValue = function(v) if type(v) == "nil" then return "N" end if isSecret(v) then return "S" end
    if type(v) == "table" then return "K" end return "C" end
ns.ClearOf = function(v, want) if v == nil or isSecret(v) then return nil end if want and type(v) ~= want then return nil end return v end
ns.ClearStr = function(v) return ns.ClearOf(v, "string") end
ns.ClearNum = function(v) return ns.ClearOf(v, "number") end
ns.ClearTable = function(v) if type(v) ~= "table" or isSecret(v) then return nil end return v end
ns.IsTrue = function(v) return v == true end
ns.Pack = function(...) return { n = select("#", ...), ... } end
ns.LabActive = function() return true end
ns.ReplayLog = { IdKey = function(kind, id) if id == nil or isSecret(id) then return nil end local h = 7
    for i = 1, #tostring(id) do h = (h * 31 + tostring(id):byte(i)) % 4294967296 end return kind .. ":" .. string.format("%08x", h) end }
ns.Inference = { SetMeterEnemyCensus = function() end }
G.ForeverDumpLogDB = {}
G.GetTime = function() return clock end
local function load(path)
    local f = assert(loadfile(addonDir .. "/" .. path))
    setfenv(f, G)
    return f("ForeverDump", ns)
end
load("Data/RefData.lua")
load("Lib/ClassEvidence.lua")
load("Lib/UnitCache.lua")
load("Derive.lua")
load("OocFill.lua")
local OF, DV = ns.OocFill, ns.Derive
check(OF and ns.UnitCache and DV, "UnitCache + OocFill + Derive load")

-- mocked units ----------------------------------------------------------------------------------------------------
local combat = false
local U = {}
local function unit(t) return t end
U.player = unit { guid = "Player-1-0000AAAA", name = "Mememe", class = "SHAMAN", race = "Orc", level = 25, faction = "Horde", sex = 3,
    hpMax = 1500, ptype = "MANA", pmax = 1200, isPlayer = true, hostile = false }
U.target = unit { guid = "Player-2-0000BBBB", name = "Grukk-Realm", class = "WARRIOR", race = "Human", level = 25, faction = "Alliance",
    sex = 2, hpMax = 1700, ptype = "RAGE", pmax = 100, isPlayer = true, hostile = true }
U.raid1, U.raid2 = U.player, unit { guid = "Player-1-0000CCCC", name = "Otherdude", class = "SHAMAN", race = "Troll", level = 25,
    faction = "Horde", sex = 2, hpMax = 1400, ptype = "MANA", pmax = 1100, isPlayer = true, hostile = false }
U.raidpet2 = unit { guid = "Pet-0-1-2-3-0000DDDD", name = "Wolfie", class = "WARRIOR", level = 24, hpMax = 600, ptype = "FOCUS",
    pmax = 100, isPlayer = false, hostile = false }
U.nameplate1 = U.target
U.nameplate2 = unit { guid = "Creature-0-1-2-3-4242-0000EEEE", name = "Kobold", class = "WARRIOR", level = 10, hpMax = 300,
    ptype = "MANA", pmax = 0, isPlayer = false, hostile = true }
U.arena1 = nil
local inRaid, nGroup = true, 2
local plates = { "nameplate1", "nameplate2" }
local function V(u, f)
    local x = U[u]
    if not x then return nil end
    local v = x[f]
    if combat and x.hostile and x.isPlayer and (f == "guid" or f == "class" or f == "hpMax" or f == "race") then return SECRET end
    return v
end
G.UnitExists = function(u) return U[u] ~= nil end
G.UnitGUID = function(u) return V(u, "guid") end
G.UnitName = function(u) return V(u, "name") end
G.UnitClass = function(u) local c = V(u, "class") return c, c end
G.UnitRace = function(u) local r = V(u, "race") return r, r end
G.UnitLevel = function(u) return V(u, "level") end
G.UnitFactionGroup = function(u) return V(u, "faction") end
G.UnitSex = function(u) return V(u, "sex") end
G.UnitHealthMax = function(u) return V(u, "hpMax") end
G.UnitPowerType = function(u) return 0, V(u, "ptype") end
G.UnitPowerMax = function(u) return V(u, "pmax") end
G.UnitIsPlayer = function(u) return V(u, "isPlayer") end
G.UnitCanAttack = function(_, u) return V(u, "hostile") end
G.UnitIsDeadOrGhost = function() return false end
G.InCombatLockdown = function() return combat end
G.IsInRaid = function() return inRaid end
G.GetNumGroupMembers = function() return nGroup end
G.GetNumSubgroupMembers = function() return 0 end
G.IsInInstance = function() return true, "pvp" end
G.GetBattlefieldInstanceRunTime = function() return 600000 end
G.MAX_BOSS_FRAMES = 8
G.C_NamePlate = { GetNamePlates = function() local out = {} for _, t in ipairs(plates) do out[#out + 1] = { namePlateUnitToken = t } end return out end }
G.C_UnitAuras = { GetAuraDataByIndex = function(u, i, filter)
    if combat then return SECRET end
    if u == "raid2" and i == 1 and filter == "HELPFUL" then return { spellId = 324, duration = 600, sourceUnit = "raid2" } end
    return nil end }

print("token enumeration (dynamic limits)")
local toks, L = OF.Tokens()
local set = {}
for _, t in ipairs(toks) do set[t] = true end
check(set.raid1 and set.raid2 and set.raid2target and set.raidpet2 and not set.raid3, "raid tokens follow GetNumGroupMembers (2): raid1-2, raidNtarget, raidpetN")
check(set.boss8 and set.boss8target and not set.boss9 and L.boss == 8, "boss tokens follow MAX_BOSS_FRAMES (8 here, not a fixed 5)")
check(set.nameplate1 and set.nameplate2target and L.plates == 2, "nameplates come from C_NamePlate.GetNamePlates")
check(not set.arena1 and L.arena == 0, "no arena tokens outside arena")
G.MAX_BOSS_FRAMES = 5
inRaid, nGroup = false, 0
G.GetNumSubgroupMembers = function() return 3 end
toks, L = OF.Tokens()
set = {}
for _, t in ipairs(toks) do set[t] = true end
check(set.party3 and set.partypet3 and set.party3target and not set.party4 and not set.raid1 and not set.boss6, "party 1-3 from GetNumSubgroupMembers; boss limit re-read (5)")
G.GetNumSubgroupMembers = function() return 0 end
inRaid, nGroup = true, 2

print("ooc fill + identity merge")
for _, u in ipairs({ "player", "raid1", "raid2", "raidpet2", "target", "nameplate1", "nameplate2" }) do OF.ReadToken(u, "pvp-ooc") end
local C = OF.Cache()
local kT = OF.KeyOf("target")
check(kT and kT == OF.KeyOf("nameplate1"), "target and nameplate1 (same unit) resolve to one key")
check(C:Get(kT, "class") == "WARRIOR" and C:Get(kT, "level") == 25 and C:Get(kT, "hpMax") == 1700 and C:Get(kT, "faction") == "Alliance",
    "hostile player cached ooc: class, level, max health, faction")
check(OF.KeyOf("raid1") == OF.KeyOf("player"), "raid1 = player: one identity")
local u = C:Unit(kT)
check(u.toks.target == 1 and u.toks.nameplateN == 1, "seen-via families recorded on the merged unit")
check(C:Get(OF.KeyOf("raidpet2"), "ownerKey") == OF.KeyOf("raid2"), "raidpet2 -> owner key = raid2 (pet/owner link)")
local nk = ns.ReplayLog.IdKey("name", "Grukk")
check(C:Resolve(nk) == kT, "name key (realm stripped) is an alias of the GUID key")
local e = DV.Engine()
check(e:Get(nk) == "WARRIOR", "class engine pre-assigned from the cache (keyed by name key)")
local Ld = DV.Learned()
check(Ld and Ld.auraDur and Ld.auraDur[324] and Ld.auraDur[324].min == 600 and Ld.spellClass[324] and Ld.spellClass[324].SHAMAN == 1,
    "ooc aura scan -> learned aura duration and spell -> source class vote")

print("in combat: secrets, cache keeps the knowledge; prefill coverage")
combat = true
OF.OnEvent("PLAYER_REGEN_DISABLED")
OF.ReadToken("nameplate1", "combat")
check(OF.KeyOf("nameplate1") == kT, "in combat (GUID secret) the plate still resolves through the name key alias")
check(C:Fresh(kT, "class") == "WARRIOR", "class stays cached while the live read is secret")
OF.OnEvent("UNIT_COMBAT", "nameplate1", "WOUND")
local d = G.ForeverDumpLogDB.oocfill
check(d.prefill and d.prefill.enemyPlayer and d.prefill.enemyPlayer.n == 1 and d.prefill.enemyPlayer.class == 1 and d.prefill.enemyPlayer.hpMax == 1,
    "prefill: the enemy's first in-combat event found class + max health cached")
check(d.read["nameplateN|class|combat"] and d.read["nameplateN|class|combat"].S == 1 and d.read["nameplateN|class|pvp-ooc"].C == 2,
    "readability matrix per family x field x context (plate class: C ooc, S combat)")

print("staleness, drift, contradiction")
clock = clock + 700
local v, age, stale = C:Get(kT, "hpMax")
check(v == 1700 and age >= 700 and stale == true and C:Fresh(kT, "hpMax") == nil, "max health older than its TTL is stale (Fresh -> nil)")
check(C:Fresh(kT, "class") == "WARRIOR", "static facts do not expire")
combat = false
U.target.level = 26
OF.ReadToken("target", "pvp-ooc")
check(C:Get(kT, "level") == 26 and C.stats.drift >= 1, "level change -> drift (overwritten, counted)")
U.target.class = "PALADIN"
OF.ReadToken("target", "pvp-ooc")
check(C:Get(kT, "class") == nil and C.stats.contradictions == 1, "class contradiction -> unknown (never guessed)")
OF.ReadToken("target", "pvp-ooc")
check(C:Get(kT, "class") == nil, "a contradicted fact stays unknown")
U.target.class = "WARRIOR"

print("target chains -> shadow rules")
U.nameplate1target = U.player
OF.ReadEdge("nameplate1target")
OF.OnWound()
check(d.shadow["tt-attacker"].single == 1, "tt-attacker: one hostile targets me when I am hit -> single candidate")
U.raid2target = U.nameplate2
OF.ReadEdge("raid2target")
combat = true
OF.OnAura("nameplate2")
check(d.shadow["tt-same-class"]["other-single"] == 1, "tt-same-class: another shaman (not me) targets the unit whose auras changed")
U.targettarget = nil
U.target = U.nameplate2
OF.ReadEdge("targettarget")
OF.ReadEdge("target")
combat = false

print("raw identities stored (v2.2.21)")
OF.Stop()
local want = { "Mememe", "Grukk", "Otherdude", "0000BBBB", "0000CCCC" }
local found = {}
local function scan(t, seen)
    seen = seen or {}
    if seen[t] then return end
    seen[t] = true
    for k, x in pairs(t) do
        for _, y in ipairs({ k, x }) do
            if type(y) == "string" then for _, w in ipairs(want) do if y:find(w, 1, true) then found[w] = y end end end
            if type(y) == "table" then scan(y, seen) end
        end
    end
end
scan(G.ForeverDumpLogDB or {}) scan(ns.db or {})
local miss = {}
for _, w in ipairs(want) do if not found[w] then miss[#miss + 1] = w end end
for w, y in pairs(found) do print("    raw " .. w .. " -> " .. y) end
check(#miss == 0, "raw names and GUIDs stored unmodified in the SV (missing: " .. table.concat(miss, ",") .. ")")
check(d.cache and d.summary and d.summary.contradictions == 1, "cache export + summary at stop")

print(string.format("oocfill_v2219: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
