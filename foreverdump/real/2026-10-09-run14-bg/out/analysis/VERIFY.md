# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | P | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|---|
| cand-heal:c-cad-amount | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-cad-guard | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-cad-phase | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-cad-phase-amount | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-cad-tight | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-heal-me-wide | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-heal-tgt-frame | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-heal-tgt-totem | 14 | 0 | 5 | 9 | 0 | 0 | 0 | 0 | None | 35.7 |
| cand-heal:c-heal-tgt-wide | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-elim | 64 | 0 | 0 | 0 | 64 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-self | 64 | 0 | 0 | 0 | 64 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-tight | 64 | 0 | 0 | 0 | 64 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-amount | 84 | 0 | 0 | 0 | 84 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-guard | 72 | 0 | 0 | 0 | 72 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-phase | 84 | 0 | 0 | 0 | 84 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-phase-amount | 84 | 0 | 0 | 0 | 84 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-tight | 84 | 0 | 0 | 0 | 84 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-me-wide | 84 | 0 | 0 | 0 | 84 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-frame | 590 | 0 | 0 | 0 | 590 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-totem | 590 | 0 | 0 | 0 | 590 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-wide | 590 | 0 | 0 | 0 | 590 | 0 | 0 | 0 | None | 0.0 |
| cand:c-int-wide | 3 | 0 | 0 | 0 | 3 | 0 | 0 | 0 | None | 0.0 |
| cd-fields-clear | 13 | 12 | 1 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cd-ready | 19 | 15 | 4 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cooldown | 207 | 58 | 0 | 149 | 0 | 82 | 5 | 76 | 94.3 | 28.0 |
| damage-range | 14 | 14 | 0 | 0 | 0 | 14 | 0 | 0 | 100.0 | 100.0 |
| dm-damage | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| dm-dispels | 14 | 0 | 5 | 9 | 0 | 0 | 0 | 0 | None | 35.7 |
| dm-healing | 14 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | None | 0.0 |
| dm-interrupts | 14 | 5 | 0 | 9 | 0 | 0 | 0 | 0 | None | 35.7 |
| dm-taken | 14 | 5 | 0 | 9 | 0 | 0 | 0 | 0 | None | 35.7 |
| dm-unit-me | 14 | 0 | 5 | 9 | 0 | 0 | 0 | 0 | None | 35.7 |
| dm-unit-other | 181 | 64 | 0 | 117 | 0 | 0 | 0 | 0 | None | 35.4 |
| gcd | 33 | 28 | 5 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| interrupt-attribution | 3 | 0 | 0 | 3 | 0 | 0 | 0 | 0 | None | 0.0 |
| shadow-dm-type7 | 190 | 34 | 0 | 156 | 0 | 0 | 0 | 0 | None | 17.9 |
| shadow-totem-heal | 84 | 72 | 0 | 12 | 0 | 0 | 0 | 0 | None | 85.7 |
| unexpected:drift | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:payload-shape | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:readability-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:secrecy-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:unknown-own-spell | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

Refuted / missed:

- t=1791580663.742 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580665.102 cooldown U spell 8143: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580675.822 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580675.992 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580676.182 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580676.372 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580677.312 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580677.492 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580681.522 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580681.712 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580681.902 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580682.082 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580682.272 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580682.862 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580682.962 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580683.192 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580683.382 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580683.582 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580684.362 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580684.422 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580684.582 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580684.772 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580684.962 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580686.082 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580686.272 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580686.462 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580686.652 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580686.832 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580690.382 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791580692.312 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| payload-shape | UNIT_AURA | SS-- | 8 | o |
| unknown-own-spell | 1301167 | None | 1 | o |
| unknown-own-spell | 1286850 | None | 1 | c |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:player | CCC | 1 | c |
| readability-flip | restricted|aura.count | u->r | 1 | o |
| secrecy-flip | C_Spell.GetSpellCooldown.isActive/isOnGCD | C/N | 1 | c |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:player | CCNN | 1 | o |
| drift | gcd:370 | drift-update | 1 | c |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:target | SSSC | 1 | c |
| unknown-own-spell | 1322629 | None | 1 | o |
| unknown-own-spell | 1301168 | None | 1 | o |
| unknown-own-spell | 1316048 | None | 1 | o |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

7 spell fact set(s), 0 NPC cast model(s), rules {"swingLag": [0.0, 1.209]}.

- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2, "minRecast": 89.634}
- spell 8056: {"auraId": 8056, "minRecast": 6.021}
- spell 8177: {"minRecast": 253.673}
- spell 17364: {"auraId": 17364, "minRecast": 8.855}
