# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | P | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|---|
| cd-fields-clear | 16 | 13 | 3 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cd-ready | 12 | 0 | 12 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cooldown | 357 | 206 | 1 | 150 | 0 | 203 | 3 | 66 | 98.5 | 58.0 |
| damage-range | 50 | 33 | 1 | 16 | 0 | 49 | 0 | 0 | 100.0 | 68.0 |
| dm-damage | 18 | 3 | 12 | 3 | 0 | 0 | 0 | 0 | None | 83.3 |
| dm-dispels | 18 | 14 | 3 | 1 | 0 | 0 | 0 | 0 | None | 94.4 |
| dm-healing | 18 | 14 | 1 | 3 | 0 | 0 | 0 | 0 | None | 83.3 |
| dm-interrupts | 18 | 18 | 0 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-taken | 18 | 10 | 0 | 8 | 0 | 0 | 0 | 0 | None | 55.6 |
| dm-unit-me | 16 | 0 | 16 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-unit-other | 192 | 0 | 192 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| gcd | 27 | 7 | 20 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| shadow-dm-type7 | 526 | 38 | 0 | 488 | 0 | 0 | 0 | 0 | None | 7.2 |
| shadow-totem-heal | 42 | 13 | 0 | 29 | 0 | 0 | 0 | 0 | None | 31.0 |
| unexpected:drift | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:payload-shape | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:readability-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:secrecy-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:unknown-own-spell | 7 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

Refuted / missed:

- t=1791552736.328 cooldown V spell 8046: refuted (log reason: No target)
- t=1791552736.478 cooldown V spell 8046: refuted (log reason: No target)
- t=1791552736.578 cooldown V spell 8046: refuted (log reason: No target)
- t=1791552797.578 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552797.728 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552798.268 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552798.368 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552798.708 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552838.338 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552838.568 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552838.768 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552839.458 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552839.628 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552839.818 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552839.978 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552840.168 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552840.338 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552840.998 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552841.148 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552841.358 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552841.728 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552842.358 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552842.458 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552842.648 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552842.818 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552842.998 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552843.188 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552843.358 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552896.218 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791552899.638 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| payload-shape | UNIT_AURA | S--S | 8 | o |
| secrecy-flip | C_Spell.GetSpellCooldown.isActive/isOnGCD | C/N | 3 | c |
| drift | gcd:1238640 | drift | 3 | o |
| drift | gcd:370 | drift | 2 | c |
| readability-flip | restricted|aura.count | u->r | 1 | o |
| unknown-own-spell | 1301167 | None | 1 | o |
| unknown-own-spell | 26545 | None | 1 | o |
| unknown-own-spell | 1286850 | None | 1 | o |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:player | CCC | 1 | o |
| unknown-own-spell | 1316048 | None | 1 | o |
| drift | gcd:6364 | drift | 1 | o |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:player | CCNN | 1 | o |
| unknown-own-spell | 439440 | None | 1 | c |
| payload-shape | UNIT_SPELLCAST_CHANNEL_STOP:target | NSN | 1 | o |
| unknown-own-spell | 1301168 | None | 1 | o |
| unknown-own-spell | 1322629 | None | 1 | o |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

10 spell fact set(s), 0 NPC cast model(s), rules {"swingLag": [0.0, 1.071]}.

- spell 8008: {"auraId": 1238640}
- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2}
- spell 8052: {"auraId": 8052, "minRecast": 42.759}
- spell 8056: {"auraId": 8056, "minRecast": 5.992}
- spell 8177: {"minRecast": 15.005}
- spell 17364: {"auraId": 17364, "minRecast": 7.313}
- spell 20572: {"minRecast": 190.727}
