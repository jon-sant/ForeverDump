# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | P | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|---|
| cand-heal:c-cad-amount | 22 | 1 | 0 | 21 | 0 | 0 | 0 | 0 | None | 4.5 |
| cand-heal:c-cad-phase | 22 | 1 | 0 | 21 | 0 | 0 | 0 | 0 | None | 4.5 |
| cand-heal:c-cad-phase-amount | 22 | 1 | 0 | 21 | 0 | 0 | 0 | 0 | None | 4.5 |
| cand-heal:c-cad-tight | 22 | 1 | 0 | 21 | 0 | 0 | 0 | 0 | None | 4.5 |
| cand-heal:c-heal-me-wide | 22 | 1 | 0 | 21 | 0 | 0 | 0 | 0 | None | 4.5 |
| cand-heal:c-heal-tgt-frame | 22 | 1 | 2 | 19 | 0 | 0 | 0 | 0 | None | 13.6 |
| cand-heal:c-heal-tgt-totem | 22 | 0 | 3 | 19 | 0 | 0 | 0 | 0 | None | 13.6 |
| cand-heal:c-heal-tgt-wide | 22 | 1 | 2 | 19 | 0 | 0 | 0 | 0 | None | 13.6 |
| cand:c-aura-me-elim | 170 | 0 | 0 | 0 | 170 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-self | 170 | 0 | 0 | 0 | 170 | 0 | 0 | 0 | None | 0.0 |
| cand:c-aura-me-tight | 170 | 0 | 0 | 0 | 170 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-amount | 43 | 0 | 0 | 0 | 43 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-phase | 43 | 0 | 0 | 0 | 43 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-phase-amount | 43 | 0 | 0 | 0 | 43 | 0 | 0 | 0 | None | 0.0 |
| cand:c-cad-tight | 43 | 0 | 0 | 0 | 43 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-me-wide | 43 | 0 | 0 | 0 | 43 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-frame | 558 | 0 | 0 | 0 | 558 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-totem | 558 | 0 | 0 | 0 | 558 | 0 | 0 | 0 | None | 0.0 |
| cand:c-heal-tgt-wide | 558 | 0 | 0 | 0 | 558 | 0 | 0 | 0 | None | 0.0 |
| cand:c-int-wide | 4 | 0 | 0 | 0 | 4 | 0 | 0 | 0 | None | 0.0 |
| cd-fields-clear | 25 | 21 | 4 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| cd-ready | 45 | 38 | 6 | 1 | 0 | 0 | 0 | 0 | None | 97.8 |
| cooldown | 316 | 176 | 0 | 140 | 0 | 219 | 0 | 35 | 100.0 | 55.7 |
| damage-range | 49 | 41 | 4 | 4 | 0 | 49 | 0 | 0 | 100.0 | 91.8 |
| dm-damage | 22 | 0 | 3 | 19 | 0 | 0 | 0 | 0 | None | 13.6 |
| dm-dispels | 22 | 3 | 0 | 19 | 0 | 0 | 0 | 0 | None | 13.6 |
| dm-healing | 22 | 1 | 0 | 21 | 0 | 0 | 0 | 0 | None | 4.5 |
| dm-interrupts | 22 | 3 | 0 | 19 | 0 | 0 | 0 | 0 | None | 13.6 |
| dm-taken | 22 | 3 | 0 | 19 | 0 | 0 | 0 | 0 | None | 13.6 |
| dm-unit-me | 22 | 0 | 3 | 19 | 0 | 0 | 0 | 0 | None | 13.6 |
| dm-unit-other | 245 | 32 | 0 | 213 | 0 | 0 | 0 | 0 | None | 13.1 |
| gcd | 60 | 48 | 12 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| interrupt-attribution | 4 | 2 | 0 | 2 | 0 | 1 | 0 | 0 | 100.0 | 50.0 |
| shadow-dm-type7 | 510 | 45 | 0 | 465 | 0 | 0 | 0 | 0 | None | 8.8 |
| shadow-totem-heal | 43 | 38 | 0 | 5 | 0 | 0 | 0 | 0 | None | 88.4 |
| unexpected:drift | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:payload-shape | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:readability-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |
| unexpected:secrecy-flip | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

Refuted / missed:

- t=1791571750.548 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571751.688 cooldown U spell 8143: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571793.288 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571793.418 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571860.758 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571916.838 cooldown U spell 8160: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571920.338 cooldown U spell 8056: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571935.148 cooldown U spell 6375: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571936.288 cooldown U spell 6375: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571937.668 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571937.828 cooldown U spell 370: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571974.928 cooldown U spell 8056: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571975.008 cooldown U spell 8056: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571975.468 cooldown U spell 8056: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571975.528 cooldown U spell 8008: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571975.718 cooldown U spell 8008: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791571988.808 cooldown U spell 8056: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572193.958 cooldown U spell 8046: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572194.088 cooldown U spell 8046: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572206.908 cooldown U spell 8056: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572308.688 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572308.838 cooldown U spell 8177: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572310.438 cooldown U spell 2484: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572434.578 cooldown U spell 8008: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572534.158 cooldown U spell 6364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572535.278 cooldown U spell 6375: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572578.658 cooldown U spell 8052: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572622.218 cooldown U spell 6375: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572633.758 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)
- t=1791572633.858 cooldown U spell 17364: missed (log says Not yet recovered: the cooldown model had no window)

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| payload-shape | UNIT_AURA | S--S | 8 | o |
| drift | gcd:1238640 | drift-update | 5 | c |
| secrecy-flip | C_Spell.GetSpellCooldown.isActive/isOnGCD | C/N | 4 | c |
| drift | gcd:17364 | drift | 3 | c |
| drift | gcd:8008 | drift | 2 | o |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:target | SSSC | 1 | c |
| drift | gcd:8052 | drift-update | 1 | c |
| readability-flip | restricted|aura.count | u->r | 1 | o |
| payload-shape | UNIT_SPELLCAST_INTERRUPTED:player | CCNN | 1 | c |
| payload-shape | UNIT_SPELLCAST_FAILED:player | CCC | 1 | o |
| drift | cooldown:8056 | reverted | 1 | o |
| payload-shape | UNIT_SPELLCAST_SUCCEEDED:player | CCC | 1 | o |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

10 spell fact set(s), 0 NPC cast model(s), rules {"swingLag": [0.0, 1.259]}.

- spell 2484: {"minRecast": 35.682}
- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2, "minRecast": 64.409}
- spell 8052: {"auraId": 8052, "minRecast": 6.004}
- spell 8056: {"auraId": 8056, "minRecast": 6.917}
- spell 8177: {"minRecast": 15.105}
- spell 17364: {"auraId": 17364, "minRecast": 6.916}
- spell 20572: {"minRecast": 215.199}
