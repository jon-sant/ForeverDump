# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | P | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|---|
| cand-heal:c-cad-amount | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-cad-guard | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-cad-phase | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-cad-phase-amount | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-cad-tight | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-heal-me-wide | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-heal-tgt-frame | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-heal-tgt-totem | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand-heal:c-heal-tgt-wide | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-elim | 96 | 0 | 0 | 0 | 96 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-self | 96 | 0 | 0 | 0 | 96 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-tight | 96 | 0 | 0 | 0 | 96 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-amount | 19 | 0 | 0 | 0 | 19 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-guard | 13 | 0 | 0 | 0 | 13 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-phase | 19 | 0 | 0 | 0 | 19 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-phase-amount | 19 | 0 | 0 | 0 | 19 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-tight | 19 | 0 | 0 | 0 | 19 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-me-wide | 19 | 0 | 0 | 0 | 19 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-frame | 829 | 0 | 0 | 0 | 829 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-totem | 829 | 0 | 0 | 0 | 829 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-wide | 829 | 0 | 0 | 0 | 829 | 0 | 0 | 0 | None | 0.0 |
| cd-fields-clear | 14 | 12 | 2 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cd-ready | 32 | 26 | 4 | 2 | 0 | 0 | 0 | 0 | None | 93.8 |
| cooldown | 264 | 131 | 0 | 133 | 0 | 152 | 8 | 50 | 95.0 | 49.6 |
| damage-range | 14 | 14 | 0 | 0 | 0 | 14 | 0 | 0 | 100.0 | 100.0 |
| dm-damage | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| dm-dispels | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| dm-healing | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| dm-interrupts | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| dm-taken | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| dm-unit-me | 12 | 0 | 0 | 12 | 0 | 0 | 0 | 0 | None | 0.0 |
| dm-unit-other | 156 | 0 | 0 | 156 | 0 | 0 | 0 | 0 | None | 0.0 |
| gcd | 55 | 39 | 14 | 2 | 0 | 0 | 0 | 0 | None | 96.4 |
| shadow-dm-type7 | 264 | 33 | 0 | 231 | 0 | 0 | 0 | 0 | None | 12.5 |
| shadow-totem-heal | 19 | 13 | 0 | 6 | 0 | 0 | 0 | 0 | None | 68.4 |
| unexpected:drift | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:new-npc | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:payload-shape | 7 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:readability-flip | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:secrecy-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:unknown-own-spell | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

Refuted / missed:

- t=1791588542.158 cooldown U spell 905: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588543.628 cooldown U spell 5675: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588593.918 cooldown U spell 8143: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588598.168 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588598.348 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588599.058 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588599.248 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588599.438 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588599.648 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588600.558 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588601.788 cooldown V spell 8052: refuted (log reason: Out of range)
- t=1791588602.418 cooldown V spell 8052: refuted (log reason: Out of range)
- t=1791588602.648 cooldown V spell 8052: refuted (log reason: Out of range)
- t=1791588602.788 cooldown V spell 8052: refuted (log reason: Out of range)
- t=1791588602.918 cooldown V spell 8052: refuted (log reason: Out of range)
- t=1791588679.418 cooldown V spell 8046: refuted (log reason: Out of range)
- t=1791588679.498 cooldown V spell 8046: refuted (log reason: Out of range)
- t=1791588822.748 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588865.468 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588865.598 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588866.368 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588866.498 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588866.598 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588866.868 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588866.998 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588869.828 cooldown U spell 8160: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588872.518 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588951.938 cooldown U spell 8052: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588952.378 cooldown U spell 8052: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791588998.428 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| payload-shape | UNIT_AURA | SS-S | 9 | o |
| drift | gcd:8177 | drift | 4 | c |
| secrecy-flip | C_Spell.GetSpellCooldown.isActive/isOnGCD | C/N | 2 | c |
| new-npc | npc:268048 | None | 2 | o |
| drift | gcd:8008 | drift | 2 | c |
| unknown-own-spell | 18849 | None | 1 | o |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:player | CCNN | 1 | c |
| unknown-own-spell | 1322629 | None | 1 | c |
| new-npc | npc:3322 | None | 1 | o |
| payload-shape | UNIT_SPELLCAST_CHANNEL_STOP:target | NSS | 1 | o |
| readability-flip | combat|unitCast.castGUID | u->r | 1 | c |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:player | CCC | 1 | c |
| payload-shape | UNIT_SPELLCAST_START:target | CCC | 1 | c |
| drift | gcd:370 | drift | 1 | c |
| readability-flip | combat|playerCast.castGUID | r->u | 1 | c |
| readability-flip | combat|unitCast.spellID | u->r | 1 | c |
| drift | build:client | build-change | 1 | o |
| payload-shape | UNIT_SPELLCAST_START:player | NCC | 1 | c |
| payload-shape | UNIT_SPELLCAST_FAILED:player | CCC | 1 | o |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

8 spell fact set(s), 0 NPC cast model(s), rules {"swingLag": [0.0, 1.19]}.

- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2}
- spell 8052: {"auraId": 8052, "minRecast": 12.007}
- spell 8056: {"auraId": 8056, "minRecast": 6.104}
- spell 8177: {"minRecast": 15.005}
- spell 17364: {"auraId": 17364, "minRecast": 13.549}
