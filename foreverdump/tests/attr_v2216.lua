-- v2.2.16 attribution safety regressions (permanent fixtures). The run 13 14:58:38 ET case: my target was a FRIENDLY
-- raider; my Lesser Healing Wave (8008, a heal, no aura) succeeded at it and 63 ms later a secret aura landed on it from
-- someone else; v2.2.15 own-cast-frame claimed it "mine" (3x within 0.5 s). 437 ms later my 1238640 (a self buff with
-- no aura knowledge) was guessed "at the friendly target" and claimed the next aura on it too.
-- Every "mine" claim now needs target match + spell plausibility + (under ambiguity) a corroborator.
-- usage: lua5.1 tests/attr_v2216.lua ForeverDump
local addonDir = arg[1] or "ForeverDump"
local fails, passed = 0, 0
local function check(c, m) if c then passed = passed + 1 print("  ok   " .. m) else fails = fails + 1 print("  FAIL " .. m) end end
local Lib = dofile(os.getenv("HSLIB") or (addonDir .. "/Lib/HybridState.lua"))
local clock = 1000
local F, E, X = "Player-1-AAAA0001", "Player-2-BBBB0002", "Player-2-BBBB0003"
local function mk(o)
    o = o or {}
    o.now = function() return clock end
    local hs = Lib.New(o)
    hs:Learn(8008, { amount = { kind = "heal", min = 200, max = 260 }, helpful = true })     -- Lesser Healing Wave
    hs:Learn(8052, { aura = { duration = 12, helpful = false }, amount = { kind = "damage", min = 90, max = 120 }, harmful = true })
    hs:SetCensus({ sameClass = 1, sameClassEnemy = 1, n = 9 })   -- BG: another shaman on each side
    return hs
end
local function last(hs) return hs.inferences[#hs.inferences] end
local function auraClaim(hs, unit)
    for i = #hs.inferences, 1, -1 do
        local r = hs.inferences[i]
        if r.unit == unit and r.src then return r end
    end
end

print("run 13 14:58:38 ET: heal at a friendly target, someone else's aura on it 63 ms later")
for _, guard in ipairs({ true, false }) do
    clock = 1000
    local hs = mk({ attrGuard = guard })
    hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8008, true, F)
    hs:OnUnitCombat(F, "HEAL", "", 245, 1, false)
    clock = clock + 0.063
    hs:OnAura(F, { addedSecret = true })
    local r = auraClaim(hs, F)
    if guard then
        check(r and r.src ~= "mine" and tostring(r.ev):find("pl:no", 1, true), "guarded: LHW (heal, no aura) does not claim the aura (src=" .. tostring(r and r.src) .. ", ev=" .. tostring(r and r.ev) .. ")")
        check((hs.attrStats["own-cast-frame"] or {}).implausible == 1, "attrStats counts the implausible rejection")
    else
        check(r and r.src == "mine", "legacy (attrGuard=false) reproduces the v2.2.15 false claim (fixture bites)")
    end
end

print("1238640: a self buff with no aura knowledge, cast while a friendly is targeted")
clock = 2000
local hs = mk()
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 1238640, true, F)
clock = clock + 0.063
hs:OnAura(F, { addedSecret = true })
local r = auraClaim(hs, F)
check(r and r.src ~= "mine", "no link learned yet: aura on the friendly target is not claimed (src=" .. tostring(r and r.src) .. ")")
hs = mk()
hs:SeedSelfLink(1238640, 104, 104)
check(hs:selfLinked(1238640) and Lib.effTarget(hs, { spell = 1238640, target = F }) == "player", "seeded self link: effective target is me, not the friendly")
clock = 2100
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 1238640, true, F)
hs:OnAura("player", { addedSecret = true })
r = auraClaim(hs, "player")
check(r and r.src == "mine" and tostring(r.ev):find("cor:timing", 1, true), "same-frame aura on me after a linked self buff: mine, corroborated by timing (ev=" .. tostring(r and r.ev) .. ")")
clock = clock + 0.063
hs:OnAura(F, { addedSecret = true })
r = auraClaim(hs, F)
check(r and r.src ~= "mine", "the friendly's aura 63 ms later: not mine (target mismatch) src=" .. tostring(r and r.src))
check(not hs:selfLinked(8008) and hs:plausible({ spell = 8008 }, "aura-me") == "no", "a heal with no aura is implausible for an aura")

print("duplicate spells: my Flame Shock at E, someone's debuff on X in the same frame")
clock = 3000
hs = mk()
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8052, true, E)
hs:OnAura(X, { addedSecret = true })
r = auraClaim(hs, X)
check(r and r.src ~= "mine", "aura on another enemy is not mine (target match) src=" .. tostring(r and r.src))
hs:OnAura(E, { addedSecret = true })
r = auraClaim(hs, E)
check(r and r.src ~= "other", "aura on my Flame Shock target: mine or U, never 'other' src=" .. tostring(r and r.src))

print("heal on me while my cast went at an enemy")
clock = 4000
hs = mk()
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8052, true, E)
hs:OnUnitCombat("player", "HEAL", "", 230, 1, true)
r = last(hs)
check(r and r.src ~= "mine", "heal on me is not claimed by an offensive cast (src=" .. tostring(r and r.src) .. ", rule=" .. tostring(r and r.rule) .. ")")

print("run 13 dm-damage C's: WOUNDs on raid members / other nameplates inside my cast or swing frame")
clock = 4500
hs = mk()
hs:SetCensus({ sameClass = 0, sameClassEnemy = 0 })
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8052, true, E)
hs.ucFriendly = true
r = hs:OnUnitCombat(F, "WOUND", "", 300, 1, false)
hs.ucFriendly = nil
check(r and r.src ~= "mine", "a raid member's WOUND in my cast frame is not my damage (src=" .. tostring(r and r.src) .. ")")
r = hs:OnUnitCombat(X, "WOUND", "", 100, 4, false)
check(r and r.src ~= "mine", "another enemy's WOUND in my cast frame: target mismatch, not mine (src=" .. tostring(r and r.src) .. ")")
r = hs:OnUnitCombat(E, "WOUND", "", 100, 4, false)
check(r and r.src == "mine", "my Flame Shock target's WOUND in the frame, amount in band: mine (" .. tostring(r and r.rule) .. ")")
clock = 4510
hs:OnSwing()
hs.ucIsTarget = false
r = hs:OnUnitCombat(X, "WOUND", "", 120, 1, false)
hs.ucIsTarget = nil
check(r and r.src ~= "mine", "melee in my swing frame on a non-target unit is not mine (src=" .. tostring(r and r.src) .. ")")
hs.ucIsTarget = true
r = hs:OnUnitCombat(E, "WOUND", "", 120, 1, false)
hs.ucIsTarget = nil
check(r and r.src == "mine" and r.rule:find("swing"), "melee on my target in the swing frame: mine (" .. tostring(r and r.rule) .. ")")

print("c-hp-net: per-unit net HP estimate, live predicted vs actual (shadow)")
clock = 4600
hs = mk({ candidates = true })
hs:OnHealthMax(E, 1000)
hs:OnUnitCombat(E, "WOUND", "", 300, 1, false)
hs:OnUnitCombat(E, "HEAL", "", 100, 1, false)
check(select(1, hs:Health(E)) == 800, "estimate follows readable WOUND/HEAL amounts (1000 - 300 + 100 = 800)")
check(hs:CandHealthActual(E, 790, 1000) == "V" and hs.candStats["c-hp-net"].V == 1, "clear UnitHealth 790 vs estimate 800: V (1% of max)")
hs:OnUnitCombat(E, "WOUND", "", 100, 1, false)
check(hs:CandHealthActual(E, 400, 1000) == "C", "unseen damage: estimate 690 vs 400 -> C (and re-anchored)")
check(select(1, hs:Health(E)) == 400, "re-anchored on the clear value")
local hs0 = mk()
hs0:OnHealthMax(E, 1000)
hs0:OnUnitCombat(E, "WOUND", "", 300, 1, false)
check(select(1, hs0:Health(E)) == 1000 and hs0:CandHealthActual(E, 700, 1000) == nil, "release (no candidates): no per-unit estimate, no verdict")

print("run 14: one Purge = several DAMAGE_METER type-6 updates in the same frame -> one dispel")
clock = 4700
hs = mk()
hs:Learn(370, { dispel = true, harmful = true })
hs:OnCombatState(true)
local fd = hs:Fight()
local d0 = fd.dispels.mine
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 370, true, E)
hs:OnDamageMeter(6) hs:OnDamageMeter(6) hs:OnDamageMeter(6)
check(hs:Fight().dispels.mine == d0 + 1, "three type-6 meter updates after one Purge count one dispel (" .. tostring(hs:Fight().dispels.mine - d0) .. ")")
clock = 4702
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 370, true, E)
hs:OnDamageMeter(6)
check(hs:Fight().dispels.mine == d0 + 2, "the next Purge counts again")

print("dead: a cast failure while dead is not cooldown evidence")
clock = 5000
hs = mk()
hs:Learn(2484, { cooldown = 15 })
hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 2484, true, "player")
clock = 5003
local nv = hs.verdicts["cooldown|V"] or 0
r = hs:OnCastFailed(2484, "UNIT_SPELLCAST_FAILED", true)
check(r and r.rule == "fail-dead" and (hs.verdicts["cooldown|V"] or 0) == nv and (hs.verdicts["cooldown|U"] or 0) >= 1, "dead: rule fail-dead, verdict U, no cooldown confirm")
r = hs:OnCastFailed(2484, "UNIT_SPELLCAST_FAILED")
check(r and r.rule ~= "fail-dead", "alive: normal cooldown judgement (" .. tostring(r and r.rule) .. ")")
print(string.format("attr_v2216: %d passed, %d failed", passed, fails))
os.exit(fails == 0 and 0 or 1)
