# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | P | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|---|
| cd-fields-clear | 9 | 7 | 2 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cd-ready | 22 | 17 | 5 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cooldown | 129 | 84 | 1 | 44 | 0 | 94 | 2 | 15 | 97.9 | 65.9 |
| damage-range | 35 | 23 | 2 | 10 | 0 | 34 | 0 | 0 | 100.0 | 71.4 |
| dm-damage | 10 | 1 | 2 | 7 | 0 | 0 | 0 | 0 | None | 30.0 |
| dm-dispels | 10 | 1 | 2 | 7 | 0 | 0 | 0 | 0 | None | 30.0 |
| dm-healing | 10 | 1 | 2 | 7 | 0 | 0 | 0 | 0 | None | 30.0 |
| dm-interrupts | 10 | 3 | 0 | 7 | 0 | 0 | 0 | 0 | None | 30.0 |
| dm-taken | 10 | 3 | 0 | 7 | 0 | 0 | 0 | 0 | None | 30.0 |
| dm-unit-me | 9 | 0 | 2 | 7 | 0 | 0 | 0 | 0 | None | 22.2 |
| dm-unit-other | 108 | 11 | 0 | 97 | 0 | 0 | 0 | 0 | None | 10.2 |
| gcd | 19 | 2 | 17 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| interrupt-attribution | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 100.0 | 100.0 |
| shadow-dm-type7 | 207 | 48 | 0 | 159 | 0 | 0 | 0 | 0 | None | 23.2 |
| shadow-totem-heal | 18 | 1 | 0 | 17 | 0 | 0 | 0 | 0 | None | 5.6 |
| unexpected:drift | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:payload-shape | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:readability-flip | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:secrecy-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:unknown-own-spell | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

Refuted / missed:

- t=1791566364.383 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566364.533 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566380.243 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566380.553 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566380.993 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566381.183 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566381.643 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566381.783 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566382.223 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566383.343 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566611.323 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566617.673 cooldown U spell 8046: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566712.183 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566712.313 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566712.473 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791566726.163 cooldown V spell 17364: refuted (log reason: Out of range)
- t=1791566726.313 cooldown V spell 17364: refuted (log reason: Out of range)

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| payload-shape | UNIT_AURA | S--S | 11 | o |
| drift | gcd:6364 | drift-update | 2 | o |
| secrecy-flip | C_Spell.GetSpellCooldown.isActive/isOnGCD | C/N | 2 | c |
| drift | gcd:1238640 | drift-update | 2 | o |
| unknown-own-spell | 1316048 | None | 1 | o |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:player | CCNN | 1 | c |
| unknown-own-spell | 439440 | None | 1 | c |
| readability-flip | restricted|totem.startTime | u->r | 1 | o |
| unknown-own-spell | 1301168 | None | 1 | o |
| unknown-own-spell | 1301167 | None | 1 | o |
| drift | gcd:8052 | drift | 1 | c |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:player | CCC | 1 | o |
| readability-flip | restricted|totem.name | u->r | 1 | o |
| readability-flip | restricted|totem.haveTotem | u->r | 1 | o |
| readability-flip | restricted|totem.duration | u->r | 1 | o |
| readability-flip | restricted|aura.count | u->r | 1 | o |
| drift | gcd:8177 | drift | 1 | c |
| drift | cooldown:8056 | drift | 1 | o |
| drift | gcd:370 | drift-update | 1 | c |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

10 spell fact set(s), 0 NPC cast model(s), rules {"swingLag": [0.0, 1.284]}.

- spell 2484: {"minRecast": 55.442}
- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2, "minRecast": 210.427}
- spell 8052: {"auraId": 8052, "minRecast": 6.004}
- spell 8056: {"auraId": 8056, "minRecast": 10.748}
- spell 8177: {"minRecast": 16.549}
- spell 17364: {"auraId": 17364, "minRecast": 6.916}
- spell 20572: {"minRecast": 215.199}
