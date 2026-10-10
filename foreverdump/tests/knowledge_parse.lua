-- v2.2.4 parser regression suite + semantic lint (PERMANENT; run by tests/run_converter_tests.sh in every build).
-- Each case: description text -> expected parse fields (nil = must be absent). Every case must also pass K.Lint.
-- usage: lua5.1 tests/knowledge_parse.lua ForeverDump
local dir = arg[1] or "ForeverDump"
local ns = { IsSecret = function() return false end, On = function() end, config = { knowledge = {} } }
assert(loadfile(dir .. "/Knowledge.lua"))("ForeverDump", ns)
local K = ns.Knowledge
local pass, fail = 0, 0
local function check(cond, msg) if cond then pass = pass + 1 print("  ok   " .. msg) else fail = fail + 1 print("  FAIL " .. msg) end end
local ABSENT = {}
local CASES = {
    { "Earth Shock (lockout must not become an aura)", "Instantly shocks the target with concussive force, causing 83 to 90 Nature damage.  It also interrupts spellcasting and prevents any spell in that school from being cast for 2 sec.  Causes a high amount of threat.",
      { interrupt = true, lockout = 2, auraDuration = ABSENT, amountMin = 83, amountMax = 90 } },
    { "Flame Shock (DoT over N sec = aura)", "Instantly sears the target with fire, causing 38 Fire damage immediately and 32 Fire damage over 12 sec.",
      { auraDuration = 12, overTime = 12, amountMin = 38, lockout = ABSENT } },
    { "Frost Shock (Lasts N = aura)", "Instantly shocks the target with frost, causing 95 to 101 Frost damage and slowing movement speed to 50% of normal.  Lasts 8 sec.  Causes a high amount of threat.",
      { auraDuration = 8, amountMin = 95 } },
    { "Lightning Shield (Lasts 10 min; 'every few seconds' is no period)", "The caster is surrounded by 3 balls of lightning.  When a spell, melee or ranged attack hits the caster, the attacker will be struck for 40 Nature damage.  This expends one lightning ball.  Only one ball will fire every few seconds.  Lasts 10 min.",
      { auraDuration = 600, period = ABSENT } },
    { "Healing Stream Totem (summon lifetime + pulse, 'with N health' is not an amount)", "Summons a Healing Stream Totem with 5 health at the feet of the caster for 5 min that heals group members within 30 yards for 6 every 2 seconds.",
      { summon = true, summonDuration = 300, auraDuration = ABSENT, amountMin = ABSENT, period = 2, pulse = 6 } },
    { "Searing Totem (summon damage = pulse, not a cast amount)", "Summons a Searing Totem with 1 health at the feet of the caster for 30 sec that repeatedly attacks an enemy within 20 yards for 9 to 12 Fire damage.",
      { summon = true, summonDuration = 30, auraDuration = ABSENT, amountMin = ABSENT, pulse = 9 } },
    { "Stoneclaw Totem (summon, health is not an amount)", "Summons a Stoneclaw Totem with 50 health at the feet of the caster for 15 sec that taunts creatures within 8 yards to attack it.",
      { summon = true, summonDuration = 15, amountMin = ABSENT, auraDuration = ABSENT } },
    { "Rockbiter Weapon (imbue duration, AP is not an amount)", "Imbue the Shaman's weapon, increasing melee attack power by 59 and allowing melee attacks to cause additional threat when using that weapon.  Lasts for 60 minutes.",
      { weaponImbue = true, imbueDuration = 3600, auraDuration = ABSENT, amountMin = ABSENT } },
    { "Flametongue Weapon (imbue damage is an imbue amount)", "Imbue the Shaman's weapon with fire, increasing total spell damage by 12. Each hit causes 9 to 25 additional Fire damage. Lasts for 30 minutes.",
      { weaponImbue = true, imbueDuration = 1800, amountMin = ABSENT, auraDuration = ABSENT } },
    { "Stormstrike (buff for N sec = aura)", "Instantly strike for normal weapon damage and increase the damage you deal to the target with your next Lightning Bolt, Chain Lightning, or Earth Shock spell by 20% for 12 sec.",
      { auraDuration = 12 } },
    { "Hammer of Justice (stun = debuff duration)", "Stuns the target for 6 sec.", { stun = 6, auraDuration = 6 } },
    { "Kick-style interrupt with lockout", "A quick kick that interrupts spellcasting and prevents any spell in that school from being cast for 5 sec.",
      { interrupt = true, lockout = 5, auraDuration = ABSENT } },
    { "Lesser Healing Wave (heal range)", "Heals a friendly target for 214 to 243.", { amountMin = 214, amountMax = 243, amountKind = "heal" } },
    { "ambiguous phrase is flagged, not used", "Your next 3 attacks within 10 sec.", { auraDuration = ABSENT, ambiguous = 1 } },
    { "decimal duration stays in its sentence", "Increases attack speed by 10% for 1.5 sec.", { auraDuration = 1.5 } },
}
for _, c in ipairs(CASES) do
    local p = K.Parse(c[2]) or {}
    local okAll, why = true, {}
    for k, want in pairs(c[3]) do
        local got = (k == "pulse") and (p.summonPulse and p.summonPulse.min) or p[k]
        if want == ABSENT then if got ~= nil then okAll = false why[#why + 1] = k .. "=" .. tostring(got) .. " (want absent)" end
        elseif got ~= want then okAll = false why[#why + 1] = k .. "=" .. tostring(got) .. " (want " .. tostring(want) .. ")" end
    end
    check(okAll, c[1] .. (okAll and "" or (": " .. table.concat(why, ", "))))
    local v = K.Lint(c[2], p)
    local msg = {}
    for _, x in ipairs(v) do msg[#msg + 1] = x.rule end
    check(#v == 0, "  lint clean: " .. c[1] .. (#v > 0 and (" -> " .. table.concat(msg, ",")) or ""))
end
-- the lint must catch the old (v2.2.3) mistakes
local old = { amountMin = 83, amountMax = 90, auraDuration = 2 }
local v = K.Lint(CASES[1][2], old)
check(#v > 0 and v[1].rule == "lockout-as-aura", "lint flags the v2.2.3 Earth Shock parse (auraDuration = lockout)")
v = K.Lint(CASES[5][2], { summon = true, summonDuration = 300, summonPulse = { min = 5 }, durations = { {}, {} } })
check(#v > 0 and v[1].rule == "health-as-amount", "lint flags 'with 5 health' read as the pulse (v2.2.3 Healing Stream Totem)")
-- charge-based aura (run 5: Lightning Shield ended 598 s early -> was a contradiction) and Water Walking (aura verb 'allow')
local ls = K.Parse("The caster is surrounded by 3 balls of lightning.  When a spell, melee or ranged attack hits the caster, the attacker will be struck for 13 Nature damage.  This expends one lightning ball.  Only one ball will fire every few seconds.  Lasts 10 min.")
check(ls.consumable == true and ls.auraDuration == 600, "Lightning Shield: consumable aura, 600 s")
local ww = K.Parse("Allows the friendly target to walk across water for 10 min. Any damage will cancel the effect.")
check(ww.auraDuration == 600, "Water Walking: 'allows ... for 10 min' is an aura duration (reparse regression)")
-- header cross-check parser
local h = K.ParseHeader({ { l = "Earth Shock", r = "" }, { l = "80 Mana", r = "20 yd range" }, { l = "Instant", r = "6 sec cooldown" } })
check(h and h.cost == 80 and h.costWord == "Mana" and h.range == 20 and h.cooldown == 6 and h.castTime == 0, "ParseHeader: N Mana / N yd range / Instant / N sec cooldown")
h = K.ParseHeader({ { l = "Lesser Healing Wave" }, { l = "145 Mana", r = "40 yd range" }, { l = "1.5 sec cast" } })
check(h and h.castTime == 1.5 and h.range == 40, "ParseHeader: N sec cast")
h = K.ParseHeader({ { l = "Drain" }, { l = "55 Mana" }, { l = "Channeled", r = "2 min cooldown" } })
check(h and h.channeled and h.cooldown == 120, "ParseHeader: Channeled + N min cooldown")
print(string.format("knowledge_parse: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
