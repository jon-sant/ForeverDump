# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | P | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|---|
| cd-fields-clear | 67 | 61 | 6 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cd-ready | 90 | 15 | 75 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cooldown | 1229 | 801 | 2 | 426 | 0 | 411 | 13 | 43 | 96.9 | 65.3 |
| damage-range | 237 | 181 | 7 | 49 | 0 | 155 | 0 | 0 | 100.0 | 79.3 |
| dm-damage | 74 | 4 | 39 | 31 | 0 | 0 | 0 | 0 | None | 58.1 |
| dm-dispels | 74 | 46 | 4 | 24 | 0 | 0 | 0 | 0 | None | 67.6 |
| dm-healing | 74 | 27 | 5 | 42 | 0 | 0 | 0 | 0 | None | 43.2 |
| dm-interrupts | 74 | 73 | 0 | 1 | 0 | 0 | 0 | 0 | None | 98.6 |
| dm-taken | 74 | 26 | 0 | 48 | 0 | 0 | 0 | 0 | None | 35.1 |
| dm-unit-me | 72 | 0 | 72 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-unit-other | 910 | 0 | 910 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| gcd | 78 | 7 | 71 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| interrupt-attribution | 12 | 3 | 0 | 9 | 0 | 2 | 0 | 0 | 100.0 | 25.0 |
| shadow-dm-type7 | 1218 | 182 | 0 | 1036 | 0 | 0 | 0 | 0 | None | 14.9 |
| shadow-totem-heal | 164 | 78 | 0 | 86 | 0 | 0 | 0 | 0 | None | 47.6 |
| unexpected:drift | 14 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:payload-shape | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:readability-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:secrecy-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:unknown-own-spell | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

Refuted / missed:

- t=1791511865.525 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512077.325 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512196.925 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512269.115 cooldown V spell 8056: refuted (log reason: Out of range)
- t=1791512269.345 cooldown V spell 8056: refuted (log reason: Out of range)
- t=1791512269.475 cooldown V spell 8056: refuted (log reason: Out of range)
- t=1791512269.595 cooldown V spell 8056: refuted (log reason: Out of range)
- t=1791512269.745 cooldown V spell 8056: refuted (log reason: Out of range)
- t=1791512269.865 cooldown V spell 8056: refuted (log reason: Out of range)
- t=1791512269.995 cooldown V spell 8056: refuted (log reason: Out of range)
- t=1791512271.905 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512272.265 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512272.455 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512272.805 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512273.225 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512273.345 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512304.975 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512310.885 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512311.425 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512311.595 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512312.225 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512312.325 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512313.245 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512313.675 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512313.785 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512313.955 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512314.325 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791512340.805 cooldown V spell 8046: refuted (log reason: Not enough mana)
- t=1791512340.935 cooldown V spell 8046: refuted (log reason: Not enough mana)
- t=1791512341.075 cooldown V spell 8046: refuted (log reason: Not enough mana)

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| payload-shape | UNIT_AURA | SS-- | 11 | o |
| drift | gcd:17364 | drift | 10 | c |
| secrecy-flip | C_Spell.GetSpellCooldown.isActive/isOnGCD | C/N | 6 | c |
| drift | gcd:8056 | drift | 6 | c |
| drift | gcd:1238640 | drift | 4 | c |
| drift | gcd:8177 | drift | 4 | o |
| drift | cooldown:17364 | drift | 3 | c |
| drift | gcd:370 | drift | 3 | c |
| unknown-own-spell | 439440 | None | 2 | c |
| drift | gcd:8008 | drift | 2 | c |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:target | SSSC | 1 | c |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:player | CCNN | 1 | c |
| unknown-own-spell | 1322629 | None | 1 | o |
| payload-shape | UNIT_SPELLCAST_CHANNEL_STOP:target | NSS | 1 | o |
| drift | cooldown:2484 | drift | 1 | c |
| drift | gcd:8046 | drift | 1 | o |
| drift | gcd:6364 | drift | 1 | c |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:player | CCC | 1 | o |
| drift | token-matrix:ooc|world|solo/nameplateN/threat | matrix-change | 1 | o |
| unknown-own-spell | 1133 | None | 1 | o |
| readability-flip | restricted|aura.count | u->r | 1 | o |
| drift | token-matrix:ooc|world|solo/mouseover/threat | matrix-change | 1 | o |
| drift | cooldown:8056 | drift | 1 | c |
| drift | token-matrix:restricted|pvp|raid/mouseovertarget/isTarget | matrix-change | 1 | o |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

9 spell fact set(s), 0 NPC cast model(s), rules {"swingLag": [0.0, 1.276]}.

- spell 2484: {"minRecast": 18.894}
- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2, "minRecast": 6.689}
- spell 8052: {"auraId": 8052, "minRecast": 18.804}
- spell 8056: {"auraId": 8056, "minRecast": 6.023}
- spell 8177: {"minRecast": 17.405}
- spell 17364: {"auraId": 17364, "minRecast": 5.166}
