# ForeverDump v2.2.15 - ranked leads for the live engine

Inputs: the offline miner (analysis.json `miner`: first/second/third-order chains, timing, identity joins, elimination)
of BG runs 9, 10, 11, 12 and PvE runs 6/6b; the per-rule error breakdown of the current HSM replayed on every run
(rule x claim x combat-log truth); live verdict rings of run 12. Every lead below is implementable at runtime from
Forever-observable events only (no combat-log dependency).

Ranking = cross-run consistency (4 BG runs) x sample size x accuracy against the combat log x runtime cost.
Candidate rules run in parallel in shadow mode at capture level `lab`, each with its own ID, a prediction verdict per
decision (`cand:<id>` P) and a live check where one exists (`cand-heal:<id>` vs the meter, `cand-aura:<id>` vs the
post-combat aura sweep). Promotion rule: better accuracy and no more false "mine" claims on every run with scorable
events; otherwise the candidate stays shadow ("never loosen existing checks").

## Ranked leads

| # | lead | target | evidence (runs 9 / 10 / 11 / 12) | runtime rule | candidate IDs | replay before -> after | status |
|---|------|--------|----------------------------------|--------------|---------------|------------------------|--------|
| 1 | secret aura add on me with no own cast in the timing window is someone else's | aura-on-me (~40 %) | wrong/unscored "none" claims whose truth is another player: 41 / 60 / 60 / 29; missed-self only 1 / 14 / 5 / 3 | own cast within 0.35 s -> mine (old rule) else other | c-aura-me-elim (promoted as `aura-me-elim`), c-aura-me-tight (0.175 s), c-aura-me-self (only casts at me) | 40.3 / 45.3 / 37.3 / 38.8 -> 97.2 / 87.4 / 88.8 / 91.0 %, falseSelf 1/6/10/3 unchanged | PROMOTED |
| 2 | heal on another unit: mine iff my cast at that unit succeeded in the same frame | heal-on-target (0 %) | all claims "none"; truth player 11/16/10, me 4/5/6 | own SUCCEEDED, target == unit, within 0.06 s -> mine else other | c-heal-tgt-frame (promoted as `heal-tgt-frame`), c-heal-tgt-wide (0.35 s), c-heal-tgt-totem (+ summon beat) | 0 / 0 / 0 / n.a. -> 100 / 100 / 100 / n.a. % (n 15 / 21 / 16 / 0), falseSelf 0 | PROMOTED |
| 3 | own totem heals are phase-locked to the drop time | heal-on-me cadence false claims (7/10/5/1 falseSelf) incl. the run-12 dm-unit-me C | heal-cadence/summon-cadence claims with truth = another player: 4+3 / 7+3 / 2+3 / 1 | beat relative to a live summon's drop time only, jitter 0.1 s | c-cad-phase | 87.6 / 69.5 / 90.6 / 94.4 -> 87.6 / 71.2 / 86.8 / 88.9 % | shadow (mixed) |
| 4 | tighter cadence jitter | same | as 3 | jitter 0.15 -> 0.075 s | c-cad-tight | -> 86.6 / 72.0 / 88.7 / 88.9 % | shadow (mixed) |
| 5 | totem tick amounts are constant | same + elimination misses on own totem heals (5/26/0/0) | as 3 | cadence claims kept only within +-20 % of my last 4 accepted ticks | c-cad-amount, c-cad-phase-amount | c-cad-amount 94.8 / 25.4 / 84.9 / 94.4 %; phase+amount 92.8 / 29.7 / 81.1 / 88.9 % | shadow (fails run 10: the seed locks on a wrong amount) |
| 6 | cast-time heals land a frame or two after SUCCEEDED | heal-on-me missed self | missed-self 5 / 26 / 0 / 0 | own helpful cast at me within 0.35 s -> mine | c-heal-me-wide | 87.6 / 69.5 / 90.6 / 94.4 -> 87.6 / 68.6 / 88.7 / 94.4 % | shadow (no gain) |
| 7 | interrupt landing after my kick | interrupt (tiny n: 9 / 3 / 0 / 1) | elimination->other where the log has no interrupt | own offensive cast within 0.35 s or DM interrupt tick | c-int-wide | 77.8 / 33.3 / - / 100 -> 77.8 / 33.3 / - / 100 % (falseSelf +1 on run 9) | shadow |
| 8 | UNIT_COMBAT target/player -> UNIT_HEALTH within 150-300 ms | hp timing (miner p 0.68-0.94 on all 4 BG runs) | miner chain | latency histogram per token (probe) before any rule | lab probe `heal.*.ucToHealth` | - | probe |
| 9 | UNIT_ABSORB_AMOUNT_CHANGED partyN -> UNIT_COMBAT ABSORB | absorbs (miner p 0.71-0.78) | miner chain | latency histogram per token class | lab probe `heal.*.absToAbsorb` | - | probe |
| 10 | UNIT_DIED -> DAMAGE_METER session update type 9 | deaths (miner p 0.85-0.92) | miner chain | latency histogram | lab probe `diedToDm9` | - | probe |
| 11 | own cast -> own aura (e.g. 1238640 -> aura, p 0.96-1.0) | aura timing | miner chain | cast-to-aura latency histogram per token (adds and removes, also when secret) | lab probe `aura.*.latAdd/latRem` | - | probe |
| 12 | UNIT_SPELLCAST_FAILED -> SPELL_CAST_FAILED (p 0.87-0.98) | fail-inside-cd rules | miner chain | already live (fail-* rules) | - | - | live already |

### dm-unit-me mismatch (run 12, 13:19:58: live heal 94 vs meter 0)

Not a timing mismatch. The only heal-on-me error of run 12 is a `summon-cadence` false claim: amount 94 at 13:19:48.160,
truth = another player's heal on me. The per-unit meter reconcile then compared 94 (live mine) with 0 (meter) -> C.
Fix path = cadence precision (leads 3-5). No cadence variant beats the live rule on all four runs yet, so the live rule
is unchanged and all variants run in shadow; the next BG scores them live (`cand-heal:<id>` per meter session).

### Expected gain (replay, runs 9-12)

- aura-on-me: ~40 % -> 87-97 % (promoted).
- heal-on-target: 0 % -> 100 % on the three runs with scorable events (promoted).
- heal-on-me: unchanged live; shadow variants measured live next BG.

## Not leads (checked, rejected)

- dm-frame in groups: invalid by construction (the meter event fires for every member; v2.2.12).
- elimination alone for heal-on-me: precision low (run 10: 26 own heals credited to others came FROM elimination).
