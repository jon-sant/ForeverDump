-- v2.2.26 aura probes: (a) U unknown while restricted, (b) dynamic tracked list (curated + seed + learned),
-- (c) out-of-combat AuraData detail + learning, (d) totems per slot, (e) own-cast derivation -> D, (f) restriction flips
-- per env, (4) health context with PvP flag. usage: lua5.1 tests/v2226_aura.lua ForeverDump
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
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
local S = W.state
local function env(it, combat) itype, S.combat = it, combat ns.InvalidateEnv() return ns.Env() end
local AP = ns.AuraPresence
ns.LearnedAuras = nil   -- v2.2.28: the generated offline file is tested in v2228_coldstart

print("(b) tracked list (v2.2.27: dynamic only)")
check(ns.AuraSeed == nil and AP.SPELLS == nil, "no curated / mined list in the addon")
AP.listDirty = true
check(#AP.List() == 0, "fresh profile: no candidates until something is seen")

print("(a) unknown, never absent, while restricted")
check(AP.Classify(false, true, nil, true) == "U", "nil while restricted -> U")
check(AP.Classify(false, true, W.SECRET or setmetatable({}, {}), true) == "U", "secret while restricted -> U")
check(AP.Classify(false, true, nil, false) == "A", "nil while open -> A (true absence)")
check(AP.Classify(false, true, { spellId = 1 }, true) == "P", "a table while restricted is still P")
check(select(1, AP.Restricted(true)) == false and select(1, AP.Restricted(false)) == true, "player GetAuraSlots not clear -> restricted")
env("none", true)
check(select(1, AP.Restricted(true)) == true, "combat -> restricted")
env("none", false)

print("(c) out-of-combat detail + learning")
C_UnitAuras.GetUnitAuraBySpellID = function() return nil end
C_UnitAuras.GetAuraSlots = function() return nil, 1 end
C_UnitAuras.GetAuraDataByIndex = function(u, i, filter)
    if S.combat then error("Auras cannot be accessed when secret while tainted by 'ForeverDump'") end
    if u == "player" and filter == "HELPFUL" and i == 1 then
        return { spellId = 905, name = "Lightning Shield", applications = 3, duration = 600, expirationTime = 1234.5,
                 auraInstanceID = 7, sourceUnit = "player", isFromPlayerOrPlayerPet = true, points = { 11, 22 } }
    end
    if u == "player" and filter == "HELPFUL" and i == 2 then
        return { spellId = 999001, name = "Learned Buff", applications = 0, duration = 30, expirationTime = 50,
                 auraInstanceID = 8, sourceUnit = "player", isFromPlayerOrPlayerPet = false }
    end
    return nil
end
ForeverDumpLogDB.auraPresence = nil
ns.db.auraLearned = nil
AP.Tick()
local d = ForeverDumpLogDB.auraPresence
local row
for _, r in ipairs(d.detail or {}) do if r:find("|905|") then row = r end end
check(row and row:find("|3|600|1234.5|11;22|player|1|HELPFUL|Lightning Shield|7|world%-solo/ooc/"),
    "detail row: stacks|duration|expiration|points|source|mine|filter|name|iid|tag: " .. tostring(row))
check(AP.Store("auraLearned")[999001] and AP.Store("auraLearned")[999001].dur == 30, "unknown aura learned (per build) with its duration")
AP.Tick()
check(AP.inList[999001] == "learned", "learned aura joins the tracked list on the next tick")
local nD = #d.detail
AP.Tick()
check(#d.detail == nD, "detail is change-only")

print("(d) totems")
local totem = { false }
GetTotemInfo = function(slot)
    if slot == 1 and totem[1] then return true, "Grounding Totem", 100.5, 45, 136039, 1, 8177 end
    return false, "", 0, 0, 0, 1, nil
end
AP.Tick()
local n0 = #d.totems
totem[1] = true
ns.AuraPresence.Totems(d, ns.EnvTag(), "event", 1)
local last = d.totems[#d.totems]
check(#d.totems == n0 + 1 and last:find("|1|event|CCCCCCC|1|Grounding Totem|100.5|45|8177|"), "PLAYER_TOTEM_UPDATE row: " .. last)
check(d.totemCodes[ns.EnvTag()]["event:1"].CCCCCCC == 1, "totem codes per env tag / slot")

print("(e) own clear cast -> derived aura (D)")
UnitGUID = function(u) return u == "player" and "Player-1234-0ABCDEF0" or "Creature-0-1-1-1-1-1" end
S.time = (S.time or 0) + 5   -- v2.2.28: auras seen in the same instant as a cast pair with it (AP.EARLY_WINDOW)
AP.Store("auraPairs")[17364] = { [17364] = { n = 2, target = 2 }, [1238931] = { n = 2, self = 2 } }
AP.Store("auraLearned")[17364] = { n = 1, dur = 3.1 }
AP.Store("auraLearned")[1238931] = { n = 1, dur = 15 }
AP.listDirty = true
AP.OnOwnCast(17364)
local r2
for i = #d.derived - 1, #d.derived do if d.derived[i] and d.derived[i]:find("|1238931|") then r2 = d.derived[i] end end
check(#d.derived == 2 and r2 and r2:find("|17364|1238931|player|Player%-1234%-0ABCDEF0|15.0|learned|"), "derived tape: " .. tostring(r2))
check(AP.DerivedActive("Player-1234-0ABCDEF0", 1238931) and AP.DerivedActive("Creature-0-1-1-1-1-1", 17364), "derived active by GUID")
AP.OnOwnCast(17364)
AP.OnOwnCast(W.SECRET or setmetatable({}, {}))
check(#d.derived == 4, "a secret spellID derives nothing")
env("none", true)
AP.Tick()
local ct = ns.EnvTag()
local hasD, hasA = false, false
for _, r in ipairs(d.tape) do
    if r:find("|1238931|D|" .. ct:gsub("%-", "%%-")) then hasD = true end
    if r:find("|A|" .. ct:gsub("%-", "%%-")) then hasA = true end
end
check(hasD, "combat: nil for 1238931 with an active own-cast derivation -> D")
check(not hasA, "combat: no A (absent) state is ever written")

print("(f) restriction flips per env; (4) health context")
AP.OnRestriction(0, 1)
check(d.restrict[ct]["0:1:combat"] == 1, "ADDON_RESTRICTION_STATE_CHANGED counted per env + combat flag")
UnitIsPVP = function(u) return u == "player" end
UnitIsUnit = function(a, b) return a == b end
UnitInParty = function() return false end
UnitInRaid = function() return nil end
UnitHealth = function() return W.SECRET or setmetatable({}, {}) end
env("none", false)
AP.Tick()
local found
for k, v in pairs(d.hctx[ns.EnvTag()]) do if k:find("^player|pvp=1|") and v["health:S"] then found = k end end
check(found and found:find("|self=1|restr=0|"), "health code recorded with PvP flag, self, restriction: " .. tostring(found))
local rs = ns.Restrictions
check(rs ~= nil, "Restrictions module present")

print("event wiring (Start registers UNIT_SPELLCAST_SUCCEEDED / PLAYER_TOTEM_UPDATE / ADDON_RESTRICTION_STATE_CHANGED)")
ns.LabActive = function() return true end
ns.db.logs = ns.db.logs or {}
ns.db.logs.on = true
C_Timer.NewTicker = function(sec, fn) return { Cancel = function() end } end
check(AP.Start() == true, "AP.Start ok")
local d2 = ForeverDumpLogDB.auraPresence
S.time = S.time + 5
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 17364)
check(d2.derived and #d2.derived == 2, "own cast event -> derived rows")
W.fire("PLAYER_TOTEM_UPDATE", 1)
check(d2.totems and #d2.totems >= 1, "totem event -> totem row")
W.fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
local any = false
for _, t in pairs(d2.restrict or {}) do for k in pairs(t) do if k:find("^0:1:") then any = true end end end
check(any, "restriction flip counted")
check(AP.Stop() ~= nil, "AP.Stop ok")

print(string.format("v2226_aura: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
