# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | P | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|---|
| cand-heal:c-cad-amount | 23 | 0 | 2 | 21 | 0 | 0 | 0 | 0 | None | 8.7 |
| cand-heal:c-cad-guard | 23 | 0 | 2 | 21 | 0 | 0 | 0 | 0 | None | 8.7 |
| cand-heal:c-cad-phase | 23 | 0 | 2 | 21 | 0 | 0 | 0 | 0 | None | 8.7 |
| cand-heal:c-cad-phase-amount | 23 | 0 | 2 | 21 | 0 | 0 | 0 | 0 | None | 8.7 |
| cand-heal:c-cad-tight | 23 | 0 | 2 | 21 | 0 | 0 | 0 | 0 | None | 8.7 |
| cand-heal:c-heal-me-wide | 23 | 0 | 2 | 21 | 0 | 0 | 0 | 0 | None | 8.7 |
| cand-heal:c-heal-tgt-frame | 23 | 1 | 0 | 22 | 0 | 0 | 0 | 0 | None | 4.3 |
| cand-heal:c-heal-tgt-totem | 23 | 0 | 6 | 17 | 0 | 0 | 0 | 0 | None | 26.1 |
| cand-heal:c-heal-tgt-wide | 23 | 1 | 2 | 20 | 0 | 0 | 0 | 0 | None | 13.0 |
| cand:c-aura-me-elim | 220 | 0 | 0 | 0 | 220 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-self | 220 | 0 | 0 | 0 | 220 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-tight | 220 | 0 | 0 | 0 | 220 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-amount | 165 | 0 | 0 | 0 | 165 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-guard | 83 | 0 | 0 | 0 | 83 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-phase | 165 | 0 | 0 | 0 | 165 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-phase-amount | 165 | 0 | 0 | 0 | 165 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-tight | 165 | 0 | 0 | 0 | 165 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-me-wide | 165 | 0 | 0 | 0 | 165 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-frame | 1528 | 0 | 0 | 0 | 1528 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-totem | 1528 | 0 | 0 | 0 | 1528 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-wide | 1528 | 0 | 0 | 0 | 1528 | 0 | 0 | 0 | None | 0.0 |
| cand:c-int-wide | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | None | 0.0 |
| cd-fields-clear | 28 | 21 | 7 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cd-ready | 54 | 40 | 11 | 3 | 0 | 0 | 0 | 0 | None | 94.4 |
| cooldown | 679 | 313 | 0 | 366 | 0 | 417 | 6 | 134 | 98.6 | 46.1 |
| damage-range | 23 | 23 | 0 | 0 | 0 | 23 | 0 | 0 | 100.0 | 100.0 |
| dm-damage | 23 | 1 | 0 | 22 | 0 | 0 | 0 | 0 | None | 4.3 |
| dm-dispels | 23 | 6 | 0 | 17 | 0 | 0 | 0 | 0 | None | 26.1 |
| dm-healing | 23 | 0 | 2 | 21 | 0 | 0 | 0 | 0 | None | 8.7 |
| dm-interrupts | 23 | 6 | 0 | 17 | 0 | 0 | 0 | 0 | None | 26.1 |
| dm-taken | 23 | 3 | 0 | 20 | 0 | 0 | 0 | 0 | None | 13.0 |
| dm-unit-me | 23 | 0 | 6 | 17 | 0 | 0 | 0 | 0 | None | 26.1 |
| dm-unit-other | 271 | 49 | 0 | 222 | 0 | 0 | 0 | 0 | None | 18.1 |
| gcd | 75 | 53 | 22 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| interrupt-attribution | 1 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | None | 0.0 |
| shadow-dm-type7 | 530 | 114 | 0 | 416 | 0 | 0 | 0 | 0 | None | 21.5 |
| shadow-totem-heal | 151 | 83 | 0 | 68 | 0 | 0 | 0 | 0 | None | 55.0 |
| unexpected:drift | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:payload-shape | 7 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:readability-flip | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:secrecy-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:unknown-own-spell | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

Refuted / missed:

- t=1791600882.631 cooldown U spell 8046: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791600956.951 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791600957.131 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791600966.921 cooldown U spell 6375: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791600989.511 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791600989.651 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601039.281 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601040.931 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601054.931 cooldown U spell 8143: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601057.641 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601058.991 cooldown U spell 6375: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601132.391 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601132.511 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601132.621 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601132.761 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601132.871 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601206.011 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601215.651 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601215.741 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601221.241 cooldown U spell 8056: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601221.591 cooldown U spell 8008: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601221.861 cooldown U spell 8008: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601232.801 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601232.971 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601233.131 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601233.281 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601233.451 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601233.611 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601234.321 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791601234.511 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| payload-shape | UNIT_AURA | S--S | 8 | o |
| secrecy-flip | C_Spell.GetSpellCooldown.isActive/isOnGCD | C/N | 7 | c |
| drift | gcd:8056 | drift | 2 | c |
| drift | gcd:17364 | drift | 2 | c |
| drift | cooldown:17364 | drift | 1 | c |
| readability-flip | restricted|unitCast.spellID | u->r | 1 | o |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:target | CCC | 1 | o |
| unknown-own-spell | 1316048 | None | 1 | o |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:player | CCNN | 1 | o |
| unknown-own-spell | 1322629 | None | 1 | o |
| unknown-own-spell | 1301168 | None | 1 | o |
| unknown-own-spell | 1301167 | None | 1 | o |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:player | CCC | 1 | c |
| readability-flip | restricted|aura.count | u->r | 1 | o |
| readability-flip | restricted|playerCast.castGUID | r->u | 1 | o |
| payload-shape | UNIT_SPELLCAST_STOP:target | CCC | 1 | o |
| drift | gcd:8177 | drift-update | 1 | c |
| payload-shape | UNIT_SPELLCAST_START:player | NCC | 1 | o |
| readability-flip | restricted|unitCast.castGUID | u->r | 1 | o |
| payload-shape | UNIT_SPELLCAST_START:target | CCC | 1 | o |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

10 spell fact set(s), 0 NPC cast model(s), rules {"swingLag": [0.0, 1.065]}.

- spell 2484: {"minRecast": 127.361}
- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2, "minRecast": 454.805}
- spell 8052: {"auraId": 8052, "minRecast": 25.358}
- spell 8056: {"auraId": 8056, "minRecast": 6.254}
- spell 8177: {"minRecast": 16.805}
- spell 17364: {"auraId": 17364, "minRecast": 8.001}
- spell 1299026: {"minRecast": 402.188}
