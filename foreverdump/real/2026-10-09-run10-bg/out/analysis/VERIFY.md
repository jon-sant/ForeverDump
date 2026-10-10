# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | P | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|---|
| cd-fields-clear | 33 | 25 | 8 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cd-ready | 39 | 5 | 34 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cooldown | 601 | 349 | 2 | 250 | 0 | 402 | 4 | 100 | 99.0 | 58.4 |
| damage-range | 115 | 70 | 7 | 38 | 0 | 115 | 0 | 0 | 100.0 | 67.0 |
| dm-damage | 34 | 0 | 14 | 20 | 0 | 0 | 0 | 0 | None | 41.2 |
| dm-dispels | 34 | 20 | 6 | 8 | 0 | 0 | 0 | 0 | None | 76.5 |
| dm-healing | 34 | 10 | 0 | 24 | 0 | 0 | 0 | 0 | None | 29.4 |
| dm-interrupts | 34 | 32 | 2 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-taken | 34 | 8 | 0 | 26 | 0 | 0 | 0 | 0 | None | 23.5 |
| dm-unit-me | 34 | 0 | 34 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-unit-other | 447 | 0 | 447 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| gcd | 61 | 11 | 50 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| interrupt-attribution | 2 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | None | 50.0 |
| shadow-dm-type7 | 599 | 84 | 0 | 515 | 0 | 0 | 0 | 0 | None | 14.0 |
| shadow-totem-heal | 118 | 72 | 0 | 46 | 0 | 0 | 0 | 0 | None | 61.0 |
| unexpected:drift | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:new-foreign-spell | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:payload-shape | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:readability-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:secrecy-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:unknown-own-spell | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

Refuted / missed:

- t=1791518287.668 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518288.448 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518288.628 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518288.838 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518289.648 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518289.778 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518395.028 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518466.508 cooldown U spell 8143: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518469.488 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518469.678 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518470.048 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518470.238 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518470.818 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518471.008 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518471.218 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518471.378 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518471.588 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518475.838 cooldown U spell 8046: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518475.988 cooldown U spell 8046: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518476.588 cooldown U spell 8046: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518499.228 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518499.828 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518500.038 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518510.878 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518610.138 cooldown U spell 8008: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518733.008 cooldown V spell 17364: refuted (log reason: Out of range)
- t=1791518734.868 cooldown U spell 8160: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518739.558 cooldown U spell 8052: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518803.458 cooldown U spell 8143: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791518815.248 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| payload-shape | UNIT_AURA | S-S- | 9 | o |
| secrecy-flip | C_Spell.GetSpellCooldown.isActive/isOnGCD | C/N | 8 | c |
| drift | gcd:8056 | drift | 7 | c |
| drift | gcd:370 | drift | 7 | c |
| drift | gcd:17364 | drift | 5 | c |
| drift | gcd:1238640 | drift | 4 | c |
| drift | gcd:8177 | drift | 4 | c |
| drift | cooldown:17364 | drift | 3 | c |
| unknown-own-spell | 430 | None | 1 | o |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:player | CCNN | 1 | c |
| new-foreign-spell | 1243120 | None | 1 | o |
| unknown-own-spell | 1322629 | None | 1 | c |
| unknown-own-spell | 1301168 | None | 1 | o |
| unknown-own-spell | 1301167 | None | 1 | o |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:player | CCC | 1 | o |
| new-foreign-spell | 25228 | None | 1 | o |
| readability-flip | restricted|aura.count | u->r | 1 | o |
| payload-shape | UNIT_SPELLCAST_START:target | NSC | 1 | c |
| unknown-own-spell | 1316048 | None | 1 | o |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

10 spell fact set(s), 0 NPC cast model(s), rules {"swingLag": [0.0, 1.29]}.

- spell 2484: {"minRecast": 15.567}
- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2, "minRecast": 6.689}
- spell 8052: {"auraId": 8052, "minRecast": 18.804}
- spell 8056: {"auraId": 8056, "minRecast": 5.989}
- spell 8177: {"minRecast": 17.405}
- spell 17364: {"auraId": 17364, "minRecast": 1.52}
- spell 1299026: {"minRecast": 185.522}
