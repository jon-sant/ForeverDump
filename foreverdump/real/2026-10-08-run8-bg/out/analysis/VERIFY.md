# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|
| cd-fields-clear | 31 | 29 | 2 | 0 | 0 | 0 | 0 | None | 100.0 |
| cd-ready | 36 | 6 | 30 | 0 | 0 | 0 | 0 | None | 100.0 |
| cooldown | 669 | 415 | 1 | 253 | 0 | 0 | 0 | None | 62.2 |
| damage-range | 81 | 61 | 3 | 17 | 0 | 0 | 0 | None | 79.0 |
| dm-damage | 34 | 0 | 13 | 21 | 0 | 0 | 0 | None | 38.2 |
| dm-dispels | 34 | 20 | 1 | 13 | 0 | 0 | 0 | None | 61.8 |
| dm-healing | 34 | 1 | 0 | 33 | 0 | 0 | 0 | None | 2.9 |
| dm-interrupts | 34 | 34 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-taken | 34 | 14 | 0 | 20 | 0 | 0 | 0 | None | 41.2 |
| dm-unit-me | 34 | 0 | 34 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-unit-other | 432 | 0 | 432 | 0 | 0 | 0 | 0 | None | 100.0 |
| gcd | 29 | 1 | 28 | 0 | 0 | 0 | 0 | None | 100.0 |
| interrupt-attribution | 2 | 0 | 0 | 2 | 0 | 0 | 0 | None | 0.0 |
| shadow-dm-type7 | 587 | 65 | 0 | 522 | 0 | 0 | 0 | None | 11.1 |
| shadow-totem-heal | 67 | 46 | 0 | 21 | 0 | 0 | 0 | None | 68.7 |
| unexpected:drift | 6 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:payload-shape | 4 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:readability-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:secrecy-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:unknown-own-spell | 1 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| payload-shape | UNIT_AURA | SS-- | 8 | o |
| drift | gcd:17364 | drift | 3 | c |
| secrecy-flip | C_Spell.GetSpellCooldown.isActive/isOnGCD | C/N | 2 | c |
| drift | gcd:8008 | drift | 2 | c |
| drift | gcd:8177 | drift | 2 | o |
| readability-flip | restricted|aura.count | u->r | 1 | o |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:player | CCC | 1 | o |
| drift | token-matrix:ooc|world|solo/nameplateN/threat | matrix-change | 1 | o |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:player | CCNN | 1 | c |
| unknown-own-spell | 439440 | None | 1 | c |
| payload-shape | UNIT_SPELLCAST_CHANNEL_STOP:target | NSS | 1 | o |
| drift | cooldown:8056 | drift | 1 | c |
| drift | token-matrix:ooc|world|solo/mouseover/threat | matrix-change | 1 | o |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

5 spell fact set(s), 0 NPC cast model(s), rules {}.

- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2, "minRecast": 6.689}
- spell 8052: {"auraId": 8052, "minRecast": 18.804}
