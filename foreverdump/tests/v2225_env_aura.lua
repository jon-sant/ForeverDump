-- v2.2.25: ns.Env (world-solo / party / dungeon / raid / arena / bg x combat x phase), ns.AuraGate (env-keyed
-- circuit breaker) and the AuraPresence probe (GetUnitAuraBySpellID codes per env, tape). usage: lua5.1 tests/v2225_env_aura.lua ForeverDump
package.path = "./tests/?.lua;" .. package.path
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local W = require("wowenv")
local files = {}
for line in io.lines(addonDir .. "/ForeverDump.toc") do
    if line:match("%.lua%s*$") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
end
local itype, grouped = "none", false
local ns = W.loadAddon(addonDir, files, "ForeverDump")
IsInInstance = function() return itype ~= "none", itype end
IsInGroup = function() return grouped end
W.fire("ADDON_LOADED", "ForeverDump")
W.fire("PLAYER_LOGIN")
local S = W.state
local function env(it, grp, combat)
    itype, grouped, S.combat = it, grp, combat
    ns.InvalidateEnv()
    return ns.Env()
end

print("ns.Env mapping")
check(env("none", false, false).env == "world-solo", "no instance, no group -> world-solo")
check(env("none", true, false).env == "party", "no instance, grouped -> party")
check(env("party", true, false).env == "dungeon", "instance party -> dungeon")
check(env("scenario", false, false).env == "dungeon", "scenario -> dungeon")
check(env("raid", true, false).env == "raid", "instance raid -> raid")
check(env("arena", true, false).env == "arena", "arena")
local e = env("pvp", true, true)
check(e.env == "bg" and e.combat == "combat" and e.tag:find("^bg/combat/"), "pvp + combat -> bg/combat/<phase>: " .. e.tag)
check(env("none", false, true).tag == "world-solo/combat/-", "world combat tag")

print("ns.AuraGate: env-keyed, held 30 s, re-sampled")
local AG = ns.AuraGate
AG.Reset()
local calls = 0
local function bad() calls = calls + 1 error("Auras cannot be accessed when secret while tainted by 'ForeverDump'") end
env("pvp", true, true)
local held, ok = AG.Call("X", "target", bad)
check(held == false and ok == false and calls == 1, "first call runs (error)")
held = AG.Call("X", "target", bad)
check(held == true and calls == 1, "second call in bg/combat is held (no call)")
check(AG.Call("X", "focus", function() return 1 end) == false, "another unit family is not held")
env("none", false, true)
held, ok = AG.Call("X", "target", function() return 7 end)
check(held == false and ok == true, "same api/family in world/combat is NOT held (env-keyed, nothing disabled elsewhere)")
env("pvp", true, true)
S.time = S.time + 31
ns.InvalidateEnv()
held = AG.Call("X", "target", bad)
check(held == false and calls == 2, "after 30 s the bg key is re-sampled")
local st = ForeverDumpLogDB.auraGate
local bgTag
for t in pairs(st) do if t:find("^bg/combat/") then bgTag = t end end
check(bgTag and st[bgTag]["X|target"].held == 1 and st[bgTag]["X|target"].err == 2, "per-env stats: calls / err / held")
held, ok = AG.Call("Y", "t", function() error("some other error") end)
check(held == false and ok == false and AG.Call("Y", "t", function() return 1 end) == false, "other errors never hold")

print("AuraPresence probe")
local AP = ns.AuraPresence
ns.LearnedAuras = nil   -- v2.2.28: the generated offline file is tested in v2228_coldstart
check(AP and AP.SPELLS == nil, "v2.2.27: no curated list")
AP.Learn(774, "Rejuvenation", 15, {}) AP.Learn(139, "Renew", 15, {}) AP.Learn(20216, "Divine Favor", 0, {})   -- candidates come from learned auras only
check(#AP.List() == 3, "learned candidates only: " .. #AP.List())
local mode = "clear"
C_UnitAuras.GetUnitAuraBySpellID = function(u, sid)
    if mode == "error" then error("Auras cannot be accessed when secret while tainted by 'ForeverDump'") end
    if mode == "secret" then return W.SECRET or setmetatable({}, {}) end
    if u == "target" and sid == 774 then return { spellId = 774, auraInstanceID = 55, sourceUnit = "target", duration = 15, expirationTime = 9 } end
    return nil
end
local casterCalls = 0
C_UnitAuras.GetAuraCasterGUID = function(u, iid) casterCalls = casterCalls + 1 return "Player-1-00000001" end
C_UnitAuras.GetAuraSlots = function(u, f) return nil, 1, 2 end
C_UnitAuras.AuraIsBigDefensive = function(sid) return sid == 20216 end
ForeverDumpLogDB.auraPresence = nil
env("none", false, false)
AP.Tick()
local d = ForeverDumpLogDB.auraPresence
local tag = ns.EnvTag()
check(d and d.codes[tag] and d.codes[tag].target[774].K == 1, "target 774 present -> K in " .. tag)
check(d.codes[tag].target[139].N == 1, "absent spell -> N")
check(d.fields[tag].auraInstanceID.C == 1 and casterCalls == 1 and d.caster[tag].C == 1, "fields coded; GetAuraCasterGUID called for the clear instance id")
check(d.slots[tag].target["N/C"] == 1, "GetAuraSlots HELPFUL|PLAYER coded")
check(d.bigDef[tag][20216] == "true" and d.bigDef[tag][774] == "false", "AuraIsBigDefensive once per env")
AP.Tick()   -- v2.2.26: the first tick may learn auras out of combat (list grows); measure change-only after it
local nTape = #d.tape
check(nTape > 0 and d.tape[1]:find("|target|") or d.tape[1]:find("|player|"), "tape written (" .. nTape .. ")")
AP.Tick()
check(#d.tape == nTape, "change-only tape: an unchanged second tick adds nothing")
mode = "error"
env("pvp", true, true)
AP.Tick()
local bt = ns.EnvTag()
local nE, nH = 0, 0
for _, cc in pairs(d.codes[bt].target) do nE = nE + (cc.E or 0) nH = nH + (cc.held or 0) end
check(nE == 1 and nH == #AP.List() - 1, "bg/combat: first call errors, the rest held (E " .. nE .. ", held " .. nH .. ")")
check(d.err[bt] and d.err[bt].GetUnitAuraBySpellID:find("Auras cannot be accessed"), "error message kept per env")
mode = "secret"
env("arena", true, true)
AP.Tick()
local at = ns.EnvTag()
check(d.codes[at].target[774].S == 1, "arena secret result -> code S")
local pres = false
for _, row in ipairs(d.tape) do if row:find("|U|arena/") then pres = true end end
check(pres, "v2.2.26: restricted secret -> tape state U (unknown) with the env tag")

print(string.format("v2225_env_aura: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
