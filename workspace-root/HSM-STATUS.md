# ForeverDump HSM status (v2.2.16 final state-engine build, signed off on run 14; v2.2.17 = one bug fix)

Scope: every value and rule the Hybrid State Machine (`ForeverDump/Lib/HybridState.lua`, driven by `Inference.lua`)
produces, its status, the evidence, and what cannot be solved by design. Evidence = replay of BG runs 9-13 against the
combat log (truth used offline only; nothing at runtime depends on the combat log), live verdict rings, and the
post-combat un-secret sweep. Status words:

- **live** - acts in release builds; passed every gate on every run with scorable events.
- **provisional** - live, but with a known weakness (named) that the next BG must settle.
- **shadow** - runs only at capture level `lab`, own rule ID, prediction verdict per decision, never acts.
- **unsolved** - no Forever-observable signal found yet.
- **unsolvable by design** - the value is secret in BGs and no clear side signal exists (no side-channel extraction).

## 1. Attribution safety (the v2.2.16 gate)

Every claim "this change was mine" passes `HybridState:gate(rule, what, unit, now, ownCast, corroborator)`:

1. **target match** - my cast's effective target equals the unit that changed. Effective target = "me" for self
   buffs, summons/totems and spells with a learned self link (>= 4 casts, >= 60 % same-frame aura on me); otherwise the
   unit targeted at cast time. Melee (swing rules) additionally needs the hit to be on my current target; a group
   member's (raidN/partyN) WOUND is never my damage.
2. **spell plausibility** - the learned spell link fits: a heal or damage spell with no aura never claims an aura, a
   heal never claims damage, a self buff never claims an aura on another unit, an interrupt needs an interrupt spell.
3. **ambiguity guard** - if same-class actors are around (live census: clear `UnitClass` of raid/party members and of
   enemy players on plates/arena in the last 60 s) or several events hit the unit in one frame, the claim is U unless
   corroborated: same-frame timing for a learned self link, the amount inside my learned band, the interrupt lockout
   signature. An unlearned spell with a target match and no competitor stays allowed (identical replay results on runs
   9-13 either way; keeps solo/PvE claims).

Every inference carries its evidence string (`ev`): `tm,pl` (matched, plausible), `pl:no`, `tm:no`,
`amb:same-class,cor:band`, `amb:crowd`, `token:swing` ... Per-rule gate counters: `inference.attr.stats` (SV) and per
fight in the lab sweep (`labProbes.sweeps[n].attr`, with the census).

### False-self gate in replay scoring

A rule may not raise false-self claims (claimed mine, log says someone else) on ANY run and may not lose accuracy beyond
noise (max(2 pt, 100/n)) on any run; promotion needs at least one run strictly better (`tools/fdump/candscore.py`
`gate_run` / `verdict`, `rule_metrics`; `ANALYSIS.md` lists `mine:<rule>` precision and false-self).

### Per category (accuracy % / false-self claims / coverage %), v2.2.15 live -> v2.2.16 gated

| category | run | before | after | gate |
|---|---|---|---|---|
| aura-on-me | 9 | 97.2 / fs 1 / cov 100 | 97.2 / fs 0 / cov 99 | better |
| aura-on-me | 10 | 87.4 / fs 6 / cov 100 | 88.1 / fs 1 / cov 98 | better |
| aura-on-me | 11 | 88.8 / fs 10 / cov 100 | 92.5 / fs 0 / cov 98 | better |
| aura-on-me | 12 | 91.0 / fs 3 / cov 100 | 89.6 / fs 2 / cov 97 | better |
| aura-on-me | 13 | 87.4 / fs 2 / cov 100 | 86.5 / fs 1 / cov 98 | better |
| aura-on-target | 9 | 96.7 / fs 1 / cov 100 | 100.0 / fs 0 / cov 100 | better |
| aura-on-target | 10 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| aura-on-target | 11 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| aura-on-target | 12 | 50.0 / fs 1 / cov 100 | 100.0 / fs 0 / cov 100 | better |
| aura-on-target | 13 | 80.0 / fs 4 / cov 100 | 100.0 / fs 0 / cov 100 | better |
| damage-on-target | 9 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| damage-on-target | 10 | 83.3 / fs 1 / cov 100 | 100.0 / fs 0 / cov 100 | better |
| damage-on-target | 11 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| damage-on-target | 12 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| damage-on-target | 13 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| heal-on-me | 9 | 87.6 / fs 7 / cov 100 | 87.6 / fs 7 / cov 100 | ok |
| heal-on-me | 10 | 69.5 / fs 10 / cov 100 | 69.5 / fs 10 / cov 100 | ok |
| heal-on-me | 11 | 90.6 / fs 5 / cov 100 | 90.6 / fs 5 / cov 100 | ok |
| heal-on-me | 12 | 94.4 / fs 1 / cov 100 | 94.4 / fs 1 / cov 100 | ok |
| heal-on-me | 13 | 95.3 / fs 0 / cov 100 | 95.3 / fs 0 / cov 100 | ok |
| heal-on-target | 9 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| heal-on-target | 10 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| heal-on-target | 11 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| heal-on-target | 13 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| interrupt | 9 | 77.8 / fs 1 / cov 100 | 77.8 / fs 0 / cov 89 | better |
| interrupt | 10 | 33.3 / fs 2 / cov 100 | 66.7 / fs 0 / cov 67 | better |
| interrupt | 12 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| interrupt | 13 | 75.0 / fs 1 / cov 100 | 75.0 / fs 0 / cov 75 | better |
| miss-on-target | 9 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| miss-on-target | 10 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| miss-on-target | 11 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| miss-on-target | 12 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |
| miss-on-target | 13 | 100.0 / fs 0 / cov 100 | 100.0 / fs 0 / cov 100 | ok |

False-self claims, all categories, runs 9-13: **56 -> 27**

Out-of-sample check (run 13 with the self-link seed learned from runs 9-12 only): aura-on-me 86.5 / fs 1 / cov 98; aura-on-target 100.0 / fs 0 / cov 100; damage-on-target 100.0 / fs 0 / cov 100; heal-on-me 95.3 / fs 0 / cov 100; heal-on-target 100.0 / fs 0 / cov 100; interrupt 75.0 / fs 0 / cov 75; miss-on-target 100.0 / fs 0 / cov 100

### Per rule: mine claims / false-self / precision (runs 9-13 summed)

| rule | before mine | before fs | before prec | after mine | after fs | after prec | after U |
|---|---|---|---|---|---|---|---|
| own-cast-frame | 220 | 28 | 87.3 | 186 | 4 | 97.8 | 0 |
| heal-cadence | 104 | 13 | 87.5 | 104 | 13 | 87.5 | 0 |
| heal-tgt-frame | 31 | 0 | 100.0 | 31 | 0 | 100.0 | 0 |
| secret-timing | 27 | 0 | 100.0 | 27 | 0 | 100.0 | 0 |
| summon-cadence | 24 | 10 | 58.3 | 24 | 10 | 58.3 | 0 |
| cast-frame | 14 | 1 | 92.9 | 13 | 0 | 100.0 | 0 |
| aura-ambiguous | 0 | 0 | — | 0 | 0 | — | 12 |
| interrupt-cast+dm | 6 | 3 | 50.0 | 3 | 0 | 100.0 | 0 |
| interrupt-ambiguous | 0 | 0 | — | 0 | 0 | — | 3 |
| interrupt-cast-frame | 1 | 1 | 0.0 | 0 | 0 | — | 0 |

Gate failures: none

### Shadow candidates through the false-self gate (runs 9-13)

| candidate | category | status | runs | better | worse | why |
|---|---|---|---|---|---|---|
| c-aura-me-elim | aura-on-me | off | 5 | 0 | 5 | run9: falseSelf 0 -> 1; run10: falseSelf 1 -> 6; run11: falseSelf 0 -> 10; run12: falseSelf 2 -> 3; run13: falseSelf 1 - |
| c-aura-me-self | aura-on-me | off | 5 | 0 | 5 | run9: accuracy 97.2 -> 73.6 (noise 2.0); run10: accuracy 88.1 -> 74.8 (noise 2.0); run11: falseSelf 0 -> 2; run12: false |
| c-aura-me-tight | aura-on-me | off | 5 | 0 | 2 | run10: falseSelf 1 -> 4; run11: falseSelf 0 -> 6 |
| c-cad-amount | heal-on-me | off | 5 | 1 | 3 | run10: accuracy 69.5 -> 25.4 (noise 2.0); run11: accuracy 90.6 -> 84.9 (noise 2.0); run13: accuracy 95.3 -> 79.1 (noise  |
| c-cad-guard | heal-on-me | off | 5 | 1 | 3 | run10: accuracy 69.5 -> 36.4 (noise 2.0); run11: accuracy 90.6 -> 84.9 (noise 2.0); run13: accuracy 95.3 -> 88.4 (noise  |
| c-cad-phase | heal-on-me | off | 5 | 2 | 2 | run11: falseSelf 5 -> 7; run12: falseSelf 1 -> 2 |
| c-cad-phase-amount | heal-on-me | off | 5 | 1 | 4 | run10: accuracy 69.5 -> 29.7 (noise 2.0); run11: accuracy 90.6 -> 81.1 (noise 2.0); run12: falseSelf 1 -> 2; run13: accu |
| c-cad-tight | heal-on-me | off | 5 | 2 | 3 | run9: falseSelf 7 -> 8; run11: falseSelf 5 -> 6; run12: falseSelf 1 -> 2 |
| c-heal-me-wide | heal-on-me | off | 5 | 0 | 2 | run10: falseSelf 10 -> 11; run11: falseSelf 5 -> 6 |
| c-heal-tgt-frame | heal-on-target | provisional | 4 | 0 | 0 |  |
| c-heal-tgt-totem | heal-on-target | off | 4 | 0 | 3 | run9: falseSelf 0 -> 2; run10: falseSelf 0 -> 1; run13: falseSelf 0 -> 3 |
| c-heal-tgt-wide | heal-on-target | off | 4 | 0 | 1 | run13: falseSelf 0 -> 1 |
| c-int-wide | interrupt | off | 4 | 0 | 3 | run9: falseSelf 0 -> 2; run10: falseSelf 0 -> 2; run13: falseSelf 0 -> 1 |


Notes:
- Accuracy counts U as not-correct; coverage = share of events decided. The remaining aura-on-me losses (runs 12/13,
  inside noise) are U claims, not errors.
- Run 13 aura-on-me's one remaining false-self claim (14:51:56 ET) is my own Strength of Earth totem cast in the same
  frame; the log has no aura apply from it (totem auras are not in the combat log), so the truth matcher picked another
  player's aura. Likely a truth artifact; kept counted.
- Self-link seed: in-sample (runs 9-13) and out-of-sample (run 13 scored with links learned from runs 9-12 only) give
  identical run-13 numbers.

### Regression fixtures

`tests/attr_v2216.lua` (23 checks): the run-13 14:58:38 ET case (Lesser Healing Wave at a friendly target + someone's
aura 63 ms later; the legacy path reproduces the false claim), the 1238640 self buff guessed at the friendly target,
duplicate Flame Shocks on two enemies, a heal on me during an offensive cast, raid/nameplate WOUNDs in my cast frame
(the run-13 dm-damage contradictions), melee on a non-target, c-hp-net, and the dead cast failure.

## 2. Value / rule inventory

| value / rule | status | evidence (runs 9-13 replay unless noted) | notes |
|---|---|---|---|
| own cast pairing (START/STOP/SUCCEEDED, my spellID) | live | spellID clear for the player on 1.60.1 (all runs) | basis of every "mine" rule |
| `own-cast-frame` (aura on me / my target in my cast's frame) | live | 220 -> 186 mine claims, false-self 28 -> 4, precision 87.3 -> 97.8 % | gated (target, plausibility, ambiguity + timing/self-link) |
| `aura-me-elim` (no matching own cast -> someone else's) | live | aura-on-me 97.2 / 88.1 / 92.5 / 89.6 / 86.5 % (runs 9-13) | now also takes target mismatches (12 of 13 right) |
| `aura-ambiguous` (U) | live | 12 U over runs 9-13 | same-class actors, no corroborator |
| `secret-timing` (predicted aura arrives on the predicted unit) | live | 27 mine, 0 false | v2.2.16: target-matched (unit-less = me only), guarded |
| `single-applier` / `iid-map` / `observed` aura identity | live | clear payload out of combat; iid ledger in combat | identity only; no attribution claim beyond the cast |
| aura-on-target attribution | live | 96.7/100/100/50/80 -> 100 % on every run, false-self 6 -> 0 | self-link effective target fixed run 12/13 |
| `cast-frame` damage on target | live | 14 -> 13 mine, false-self 1 -> 0; damage-on-target 100 % all runs | gated; amount band corroborates under ambiguity |
| `dm-frame` damage / heal (DAMAGE_METER frame) | live (solo only) | run 9 finding: the meter fires for every group member | groupSize <= 1 |
| `swing-frame` / `swing-lag` melee | live | damage-on-target 100 %; v2.2.16 needs the hit on my target | `swing-ambiguous` U under crowd |
| miss-on-target | live | 100 % all runs | |
| damage taken (me) | live | 100 % (run 13: 112 events) | |
| `heal-tgt-frame` (heal on another unit) | live | 31 mine, 0 false, 100 % all runs | gated, amount band under ambiguity |
| heal on me: `cast-frame` | live | gated (target me, band) | |
| heal on me: `heal-cadence` | provisional | 104 mine, 13 false (87.5 %); the ambiguity guard failed the gate (run 10 69.5 -> 36.4 %) | guarded variant = shadow `c-cad-guard` |
| heal on me: `summon-cadence` | provisional | 24 mine, 10 false (58.3 %); phase lock does not separate another shaman's HST | weakest live rule; demoting it loses accuracy beyond noise on run 10 |
| interrupt attribution (`interrupt-cast+dm`, lockout) | live | false-self 5 -> 0; interrupt 77.8 / 66.7 / - / 100 / 75 % (n 9/3/0/1/4) | small n; `interrupt-ambiguous` U |
| dispel (`dispel-cast+dm`) | live (fixed v2.2.17) | meter Dispels row; run 14 double count (live 18-20 vs meter 8-9) fixed: one count per own cast | |
| cooldowns (CooldownTracker: learned cd, GCD, fail-inside-cd) | live | verify:cooldown 97.8 % (run 13, n 316); cooldown-fail scoring now excludes precondition failures | v2.2.16: dead -> `fail-dead` U |
| cast time model (enemy NPC casts) | live | cast-end verdicts vs log NPC cast success | |
| damage range (my spells) | live | verify:damage-range 100 % (run 13, n 49) | |
| player health estimate + overheal | live | overheal-estimate 97.7 % (run 13, n 43) | |
| per-unit net HP (`c-hp-net`) | shadow | run 14: 0 live verdicts (BG target health secret); offline vs combat-log health 89.1 % V (median err 1.2 % max) | readable UNIT_COMBAT amounts + cached max health |
| meter reconcile (`dm-reconcile`, dm-unit-me/other) | live | run 13 had 3 dm-damage C's: root-caused (raid/plate WOUNDs credited to me), fixed | analyzer now joins by meter session |
| self links (cast -> aura on me) | live | seed from runs 9-13; per-account accumulation | spell IDs and counts only |
| census (same-class actors) | live (probe + guard input) | counts only; per fight in the sweep | run 14: friendly matches the log (2 = 2); enemy unreadable (plate class secret) |
| enemy heals | live (tracked per unit in `fight.world[*].heal`) | UNIT_COMBAT HEAL on hostile tokens when readable | no attribution claim |
| shadow candidates | shadow | `c-heal-tgt-frame` provisional (no run worse); all other candidates fail the false-self gate (table above) | |

## 3. Former "unsolvable by design" rows (v2.2.18: each now has a derivation path, see section 6)

No row stays "secret, unsolvable". Each one either has a derivation implemented and scored offline, or has a designed
path plus a live probe:

| former row | derivation path | status | offline estimate (runs 9-14) |
|---|---|---|---|
| aura identity and source on other units (BG) | UNIT_AURA frame + caster cast timing + caster class (class engine) + RefData auraDur, confirmed at removal | bound (identity pending the cast-frame join) | duration alone 1.0% unique, duration + caster class 5.3% |
| other players' cast spellIds (BG) | planned cast time (UnitCastingInfo, probe) x class -> RefData castTime; ooc meter CombatSpells; learned votes | derivable | event START->SUCCESS fingerprint 0-60% (pushback): rejected; planned-time probe |
| exact health of non-group units | c-hp-net (UNIT_COMBAT amounts) on a max from the cache / RefData npcs / classLevelHP | derived | c-hp-net 89.1% within tolerance (run 14) |
| same-class tie-break on me | totem tick phase vs each friendly shaman's raid-token cast timing; RefData summons; GetTotemInfo probe | derived | other shamans' HST ticks exclude me 35/35; mine kept 204/215 (94.9%) |
| meter breakdown per enemy unit | enemy rows ooc: name + classFilename + totals + CombatSpells keyed by name key | derivable | names clear 14/16 ooc observations (run 14) |
| enemy same-class census (newly solved) | meter classFilename composition of displayType 2 rows | derived (live hook) | shaman count = log on runs 10-14 |

## 4. What the next BG must settle (settled by run 14: see section 5)

1. Live census vs log census (stand-in used for runs 9-13).
2. `c-cad-guard` live verdicts and whether any corroborator (meter delta per tick) rescues the cadence chain.
3. `fight.dmg.tok`: claimed damage by token family per fight - must be target-only after the fix (no raid/plate).
4. `peakMarks`: the step that sets the all-time 182.7 ms PeakTime.
5. `c-hp-net` V/C rate.

## 5. Run 14 sign-off (v2.2.16 live, Darkspear Islands, 2026-10-09 17:15-17:24 ET)

Capture 576 s (17:15:16-17:24:52 ET), capture level lab, 0 in-game errors, 32 restriction toggles, no taint.log.
Decode: the converter and the addon's own `SVPack.UnpackAll` agree on all 5 variables (2.15M literals, 0 secrets
dropped, pack 3.7 s at logout). Completeness: tape 73,529 rows (24,581 RLE-folded), overflow / dropped / overwritten 0.
Perf (lab: reported, not gated): own 1.32 % of wall time; worst call 12.98 ms (`Probe.step`); 0 frames > 50 ms; the
250 ms backstop never fired; memory +119 MB (lab is uncapped by design).
Growth flags: `Lab.sample` x2.06 and `HSM.Tick` x2.85. Both stay below 0.06 ms per call, and both come from
lab-uncapped tables.

### The five open items

| # | item | result | status |
|---|---|---|---|
| 1 | live census vs log census | Friendly same-class: live 2 for the whole BG. The log shows 2 persistent friendly shamans, plus a 3rd who cast twice at 17:21:53-58. Live sees them from the roster, about 50 s before the log sees their first cast. Enemy same-class: live 0, log 3. In restricted, pvp and raid state, `nameplateN` class is **secret** (tokenscan), so enemy class cannot be read. | friendly: **done**. Enemy: **unsolvable by design**, low impact (enemies cannot put my class's auras or heals on my units, and the friendly count already flagged ambiguity) |
| 2 | `c-cad-guard` live verdicts and a cadence corroborator | Live: 72 verdicts, 69 mine, 3 blocked. Of the 3 blocked, 1 was false and 2 were correct (heal-on-me fs 3 -> 2, accuracy 83.3 -> 81.0, below noise). Runs 9-14: 1 better, 4 worse. Corroborator tried in replay: an amount veto (a tick outside 0.5-2x of my recent ticks is blocked under ambiguity). It cut false-self 31 -> 24 but dropped run 10 accuracy 69.5 -> 29.7 and run 11 90.6 -> 84.9. Rejected. The heal-cadence band corroborates 64 of 67 claims, but it does not separate another shaman's Healing Stream totem. | **provisional** (heal-cadence 98.5 % on run 14; summon-cadence 3/5). No corroborator exists; shadow only |
| 3 | `fight.dmg.tok` claimed damage by token family | `{target: 2075}` only. The friendly-wound guard rejected 1316 raid WOUNDs; swing target mismatch rejected 852. | **done** |
| 4 | what set the 182.7 ms PeakTime | Run 14 marks: load and login 0, capture:begin 0.733 ms, end 13.0 ms (= `Probe.step` 12.98 ms). Run 13's 182.7 ms was set before capture:begin, outside capture work. It did not happen again. | **done** (not a ForeverDump capture cost) |
| 5 | `c-hp-net` V/C | Live: 0 verdicts, because BG target health and GUIDs are secret (52/59 target signals had no GUID), so there was nothing clear to verify against. Offline vs combat-log health on all player destinations, assuming every hit is readable: V 2291 / C 281 = **89.1 %**; median error 1.2 % of max, p90 5.3 % (heals 634/47, damage 1657/234). | **shadow**. Offline ceiling known; live V/C needs a non-restricted group run |

### Per rule, run 14 (live = replay, identical counts)

| rule | mine | false-self | precision | other / U |
|---|---|---|---|---|
| heal-cadence | 67 | 1 | 98.5 % | - |
| own-cast-frame | 17 | 1 | 94.1 % | - |
| summon-cadence | 5 | 2 | 60.0 % | - |
| heal-tgt-frame | 3 | 0 | 100 % | 2 other (2 missed self) |
| secret-timing | 1 | 0 | 100 % | - |
| interrupt-cast+dm | 1 | 0 | 100 % | - |
| aura-me-elim | 0 | 0 | - | 32 other (10 missed self, conservative) |
| elimination (heal on me) | 0 | 0 | - | 12 other (9 missed self, conservative) |
| aura-ambiguous / heal-ambiguous | 0 | 0 | - | 4 / 2 U |

Categories, run 14 (v2.2.15 -> v2.2.17 rules, replay): aura-on-me 70.4 % fs 6 -> 72.2 % fs 1; heal-on-me 84.5 % fs 4 ->
83.3 % fs 3; heal-on-target 60 % (n 5); interrupt 100 % (n 3); damage taken 100 % (n 40). Runs 9-14 false-self
**66 -> 31**, 0 gate failures, and run 14 is out of sample (self-link seed from runs 9-13). Shadow candidates: all
`off` except `c-heal-tgt-frame` (provisional, never worse). Live verify: cooldown 94.3 % (n 207), damage-range 100 %
(n 14), GCD 28 V / 5 C, dm-interrupts 5 V, dm-taken 5 V, dm-unit-other 64 V / 0 C.

Gate counters (attrStats): own-cast-frame 22 mine (all corroborated), 351 other, 13 mismatch. Cast-frame damage: 14
mine, 54 mismatch, 2 implausible, 10 ambiguous. Secret-timing: 20 mine, 21 ambiguous. Heal-tgt-frame: 3 mine, 587
other. Friendly-wound rejected 1316. Swing mismatch 852. Cooldown fails: fail-dead 3, inside-cd 57, gcd 108, outside-cd
38 (418 casts).

### Bug found and fixed (v2.2.17)

- **Dispel double count.** 5 live C's on `dm-dispels` (live 18-20 vs meter 8-9). The log shows 18 Purge casts and 15
  dispels. `OnDamageMeter(6)` counted every type-6 meter update that landed in the frame of my dispel cast, and the
  meter fires several. Now each own cast counts at most once. A regression test fails on the v2.2.16 lib. No other
  runtime change.

### Regressions

None in attribution: no category or run got worse through the gate. aura-on-me on run 14 (72.2 %) is the lowest of
the six runs, but v2.2.15 was 70.4 % on the same data. The losses are conservative `other` claims (10 missed self,
not false-self). New secrecy flip: `C_CombatText.GetCurrentEventInfo#1` out of combat C -> S (not an HSM input).

### What stays provisional or unsolvable

- Provisional: `heal-cadence` and `summon-cadence` (runs 9-14: 200 mine, 26 false). Another shaman's Healing Stream
  totem in the same frame cannot be told apart from mine. Census, phase lock and amount band all fail the gate.
- Provisional: interrupt attribution (n is small).
- Shadow: `c-hp-net` (offline 89.1 % ceiling, no live verdict in BG) and `c-heal-tgt-frame`.
- Unsolvable: enemy same-class census (plate class is secret), plus everything in section 3.

### Recommendation

**Ready to move to the old-addon migration.** Every live rule except the two cadence rules is at or above 94 %
precision with 0-1 false-self per BG. Run 14, out of sample, matched the replay exactly. The safety gate cut
false-self in half over six BGs with no gate failure. Perf, decode and completeness are clean. The only bug was
a counter (the dispel tally), and it is fixed in v2.2.17. Conditions for the migration:

- Treat cadence heal-on-me claims as "probably mine" (medium confidence), never as proof.
- Keep the enemy census at 0 and do not use it.
- Keep `c-hp-net` in shadow until a non-restricted group run gives live V/C.

## 6. v2.2.18 derivation inventory (alternate APIs and higher-order inference)

Source of truth: `tools/fdump/derivation.py`. It is rendered as the "derivation path" column and the "Derivation paths" table of
SECRETS-GUIDE.html/.md. `tests/test_v2218.py` fails when a guide row has no path. Guide rows by derivation status: direct 83, derived 37, derivable 58, probe 0, bound 23 (201 rows).

### 6.1 Class engine (Lib/ClassEvidence.lua + Derive.lua, lab capture, shadow: it assigns only on proof, never guesses)

| run | enemies | P+K assigned/correct | P+K coverage | P+K mean candidates | M coverage | M median TTI | combined median TTI |
|---|---|---|---|---|---|---|---|
| 9 | 18 | 3/3 | 16.7% | 3.5 (truth in set 94.4%) | 100% | 169.9 s | 163.7 s |
| 10 | 19 | 5/5 | 26.3% | 2.47 | 100% | 48.4 s | 48.4 s |
| 11 | 16 | 3/3 | 18.8% | 5.06 | 100% | 96.2 s | 95.7 s |
| 12 | 15 | 1/1 | 6.7% | 4.6 | 100% | 150.8 s | 150.8 s |
| 13 | 15 | 1/1 | 6.7% | 2.87 | 100% | 168.3 s | 168.3 s |
| 14 | 15 | 1/1 | 6.7% | 4.87 | 100% | 217.2 s | 217.2 s |

- P = power type from UNIT_POWER_* (clear).
- K = meter class composition (classFilename is always clear).
- M = the meter enemy row name, joined by name key out of combat. Its accuracy depends on enemy names being clear out of
  combat: 14/16 in run 14 (probe).
- C = cast-time fingerprints. Rejected for elimination (0-60%, because pushback stretches the cast).
- Scoring uses leave-one-run-out reference data and log truth.

### 6.2 Reference data (Data/RefData.lua, tools/fdump/refdata.py)

- Mined from the 15 combat logs for build 70291:
  - 849 spells (487 with a class); 640 are shipped with class, castTime, auraDur, school and cooldown;
  - 28 summons -> owner class;
  - 35 NPCs -> max HP per level;
  - class power types;
  - 106 class x level median max-HP cells;
  - cast-time fingerprints (poisoned buckets removed);
  - amount bands per spell (dmg/heal, periodic, crit; 2-98 percentile).
- Runtime learning: `ForeverDumpDB.refLearned[build]` stores spellClass votes and own planned cast times. The votes come from the
  meter CombatSpells of clear-GUID sources out of combat.
- Drift: `drift` is set when the client build differs from the shipped seeds. `driftSpells` is set when an own cast time moves
  by more than 250 ms.
- `refdata.py --learned <SV files>` folds the learned tables back into the seeds (newer build wins).

### 6.3 Inventory (non-direct families)

| family | status | path | offline estimate | probe |
|---|---|---|---|---|
| health | derived | UNIT_COMBAT amounts (clear on every token) accumulated per IdKey (GUID, or name key for hostile players) on a cached max (healthMax row) -> c-hp-net running estimate; resync on any clear UnitHealth read and on UNIT_DIED (0) / out-of-combat full | c-hp-net offline (run 14 BG): 89.1% of samples within tolerance of the log value | derive.read UnitHealthPercent/UnitHealthMissing per family/ctx (an alternate API may be clear) |
| healthMax | derived | clear UnitHealthMax reads cached per IdKey / NPC id; otherwise RefData.npcs[npcId].maxHP[level] (mined) or RefData.classLevelHP[class][level] once the class engine knows the class (UnitLevel is clear on target) | NPC max: exact per level from the log; player max: class x level median (gear spread, the HP net corrects with the first clear percentage) | derive.read UnitHealthMax/nameplateN/hostileP/combat and UnitLevel per family |
| power | derivable | power TYPE is clear in UNIT_POWER_* (feeds the class engine); amount: player = UNIT_POWER_UPDATE deltas + own cast costs (RefData cost); others = RefData spell cost x observed casts (mana spent lower bound), rage from UNIT_COMBAT dealt/taken, energy regen model | type: 100% readable (run 14 tape); amount: not scored yet | derive.read UnitPower / UnitPowerMax per family/ctx; UnitPowerType (clear) |
| absorbs | derivable | UNIT_ABSORB_AMOUNT_CHANGED (fires) + UNIT_COMBAT WOUND with the ABSORB flag in the same frame; the shield size from RefData amount bands of the absorb spell (caster class known) | presence: 100% from the event; size: amount band of the spell (2-98 percentile) | derive.read UnitGetTotalAbsorbs per family/ctx |
| incheal | bound | UNIT_HEAL_PREDICTION timing + the healer's cast start (raid tokens: timing clear) + RefData heal amount band | not scored (low value) | derive.read UnitGetIncomingHeals per family/ctx |
| spellid | derivable | (1) UnitCastingInfo planned start/end (if clear) -> planned cast time -> RefData castTime x the caster's class (class engine) -> candidate spells; (2) out of combat the meter's CombatSpells per clear-GUID source lists the spellIds actually used; (3) NPCs: castModel per NPC id | START->SUCCESS duration as the fingerprint: 0-60% (pushback stretches it) -> rejected; planned time needs the probe | derive.cast cast:<family> positions 5/6 (startMS/endMS) and 10 (spellID) codes |
| casttiming | derivable | START->STOP/SUCCEEDED event timing (clear) + RefData castTime of the derived spell; planned end from UnitCastingInfo if clear | planned-time readability pending | derive.cast positions 5/6 |
| interrupt-mine | derived | HSM frame join (my cast / DM type 5 in the INTERRUPTED frame) | HSM accuracy in the guide evidence | - |
| aura-payload | bound | payload wholly secret in BG -> presence/timing only: UNIT_AURA frame joined with a cast SUCCEEDED of a class-known caster in the same frame -> RefData spells of that class with an aura duration | identity from duration alone 1.0% unique (27.6k applications); with caster class 5.3% -> needs the cast-frame join | derive.read GetAuraSlots / GetAuraDataByIndex field codes per family/ctx |
| aura-details | derivable | own auras: HSM cast+aura frame join (proven); others: caster cast frame + class + RefData auraDur, confirmed by the removal time (UNIT_AURA) matching the mined duration | duration+class unique 5.3% offline; cast-frame join not yet scored | derive.read aura field codes (spellId/duration/expirationTime/sourceUnit) |
| aura-count | derivable | count = clear ooc baseline + UNIT_AURA add/remove deltas inferred from the cast-frame join | not scored | derive.read GetAuraSlots per family/ctx |
| aura-mine | derived | HSM my-cast + UNIT_AURA frame join | HSM accuracy in the guide evidence | - |
| guid | derivable | hostile players: name key (UnitName is clear on target C60, plate C6, targettarget C9) replaces the GUID as the identity (IdKey('name', name)); the meter's GUID is clear out of combat | name key covers 100% of named hostile players | derive.meter.ooc guidClear / nameClear counters |
| hit-mine | derived | HSM dm-frame / cast-frame / swing-lag rules | HSM accuracy in the guide evidence | - |
| hit-taken | derived | UNIT_COMBAT player WOUND + DM type 7 | proven | - |
| heal-mine | derived | UNIT_COMBAT HEAL on me; same-class tie-break via the totem tick phase | see same-class tie-break | - |
| heal-hostile | derivable | UNIT_COMBAT HEAL on hostile tokens is clear; record it into the world unit | input clear | - |
| unit-died | derivable | secret player deaths: DM type 9 (deaths) in the same frame + the c-hp-net estimate reaching 0 + UnitIsDeadOrGhost on the name-keyed token | not scored | - |
| threat | bound | n/a for enemy players; NPCs: last clear status + hit-mine damage share | - | derive.read UnitThreatSituation |
| range | derivable | UnitDistanceSquared / UnitInRange probes; else own-spell range errors and swing updates; plates exist only within the plate distance | bound only | derive.read UnitDistanceSquared/UnitInRange |
| cooldown | derived | HSM cd tracker from my casts + SPELL_UPDATE_COOLDOWN | proven | - |
| meter | derived | totals clear after combat; in combat the session update timing + DM ticks | provisional | derive.meter counters |
| class | derived | class engine (Lib/ClassEvidence): power type (P) -> candidates; meter composition per team (K) eliminates absent classes; meter name-key join out of combat (M) assigns; clear spellId / summon -> RefData class; scoreboard name+classToken; plate bar colour; arena spec | P+K 0 false assignments on runs 9-14, coverage 6.7-26.3%; M join 100% coverage, median time-to-identify 48-217 s (accuracy depends on enemy row names being clear ooc: probe) | derive.meter.ooc enemyNameClear, derive.score field codes, derive.color bar:<ctx>, derive.summary |
| census | derived | meter rows with displayType 2 (enemy) carry a clear classFilename -> per-team class composition -> Inference.SetMeterEnemyCensus (max with the plate count, 120 s validity) | enemy shaman count = log on runs 10-14 (0/0, 1/1, 3/3, 0/0, 3/3); full composition 13/15 to 16/19 enemies in the window | derive.meterCompLast vs the log |
| same-class | derived | totem tick phase: a friendly shaman's raid-token cast timing (clear) sets candidate drop times; a tick not on my own drop phase (mod 2 s) is not mine; RefData summons -> owner class; GetTotemInfo for my own slots | Healing Stream ticks on me, runs 9-14: other shamans' ticks exclude me 35/35; my ticks keep me 204/215 (94.9%); unique-owner by phase 132/250 | derive.read GetTotemInfo#1-4/global, UnitIsOwnerOrControllerOfUnit on pet/totem plates |
| aura-source | bound | UNIT_AURA frame + the caster's cast timing in that frame + caster class (engine) + RefData auraDur; confirmed by the removal at the mined duration | duration alone 1.0%, duration + caster class 5.3% unique; cast-frame join not yet scored | derive.read aura field codes |
| others-spellid | derivable | planned cast time (UnitCastingInfo) x class -> RefData; ooc meter CombatSpells per source; learned votes (refLearned[build].spellClass) | see spellid | derive.cast positions 5/6/10 |
| meter-enemy | derivable | enemy rows (displayType 2, no id) out of combat: name + classFilename + totals + CombatSpells clear -> per-enemy breakdown keyed by name key; in combat only the composition | names clear in 14/16 ooc observations (run 14); per-enemy totals ooc | derive.meter.ooc enemyNameClear / rows |
| race-level | derivable | UnitLevel + UnitFactionGroup clear on target; race/sex: probe; scoreboard race field | level/faction: direct on target | derive.read UnitRace/UnitSex per family; derive.score race |
| pet-owner | derivable | RefData.summons npc id -> owner class (28 mined); UnitIsOwnerOrControllerOfUnit pair probe; pet power type FOCUS/HAPPINESS -> hunter pet | 28 summon types, share >= 0.9 used | derive.read UnitIsOwnerOrControllerOfUnit/pair |
| scoreboard | probe | GetBattlefieldScore / C_PvP.GetScoreInfo out of combat (RequestBattlefieldScoreData every 10 s) | - | derive.score field codes |
| spec | derivable | GetArenaOpponentSpec (arena); BG: talent-only spells from RefData via the spellId path | - | derive.score talentSpec, ARENA_PREP |

### 6.4 What the next BG must test

1. Meter enemy row names out of combat (derive.meter.ooc enemyNameClear/enemyRows) and the name-key join rate (gives M accuracy).
2. Scoreboard readability (derive.score: GetBattlefieldScore / C_PvP.GetScoreInfo field codes, name + classToken).
3. UnitCastingInfo/ChannelInfo planned start/end and spellID codes on hostile plates (derive.cast positions 5/6/10).
4. Plate health-bar colour vs RAID_CLASS_COLORS (derive.color bar:<ctx>).
5. The full unit API matrix per family/ctx (derive.read). It includes UnitHealthPercent/Missing, UnitDistanceSquared, UnitRace,
   UnitIsOwnerOrControllerOfUnit, GetTotemInfo 1-4 and the aura field codes.
6. refLearned spell votes and drift flags; derive.summary (assigned, via, contradictions) vs the log.
7. Census: meter composition vs the log. Derive perf at lab (reported, not gated).

## 7. v2.2.19 out-of-combat pre-fill + full unit-token sweep

Modules: `OocFill.lua` (lab capture, `ForeverDumpLogDB.oocfill`) and `Lib/UnitCache.lua` (pure).
Tests: `tests/oocfill_v2219.lua` (27 checks) and `tests/test_v2219.py`. `OocFill.lua` is in the secret lint and in the
secret-injection run (4 modes).

### 7.1 What it does

- **Fill.** Every moment that reads clear triggers a sliced sweep of every existing token. Those moments are: out of combat,
  BG prep (run time < 120 s), post-combat (5 s after REGEN_ENABLED), dead/graveyard, and pvp-ooc. The triggers are event-driven
  and throttled: regen, roster, plate added, target/focus/mouseover change, UNIT_TARGET, arena/boss units, UNIT_PET, entering
  world, death/rez, plus a 2 s tick.
- **Cached facts, per merged identity:** class, race, level, faction, sex, max health, power type, max power, player and
  hostile flags, guild key, owner key (pet tokens), arena spec, and the aura signature. Each fact carries its source, first and
  last time, context, count and a TTL.
- **Verification.** A later read with the same value counts as verified. A different static fact counts as a contradiction
  and the fact becomes unknown. A different dynamic fact counts as drift.
- **Feeds:**
  - the class engine (pre-assigns `cache:<family>`);
  - the HSM ledger (`Identity.Observe` and aura scans out of combat);
  - the learned data (`refLearned[build].auraDur`, plus aura spell -> source-class votes);
  - meter roster and scoreboard classes, written into the cache by Derive.
- **Token sweep.** It covers player, pet(target), target(target), focus(target), mouseover(target), partyN(target),
  partypetN, raidN(target), raidpetN, bossN(target), arenaN(target) and nameplateN(target). Limits come from
  GetNumGroupMembers / GetNumSubgroupMembers / MAX_* / arena counts / C_NamePlate.GetNamePlates, never a fixed list.
  Readability is recorded per family x field x context in `oocfill.read`.
- **Identity merge.** The GUID key and the name key from the same clear read are linked. In combat, a GUID-secret plate
  still resolves through the name key, so one unit seen through target, plate and raid tokens is one key.

### 7.2 New shadow rules (counted, never claimed; timestamps in `oocfill.events` for the log join)

- **tt-attacker:** when I take a WOUND, the hostiles whose *target edge points at me (none / single / multi).
- **tt-same-class:** when a unit's auras change in combat, the same-class friendlies targeting it. The outcomes are
  me-only / me+other / other-single / other-multi / none. This corroborates the tie-break.

### 7.3 Offline pre-fill coverage (runs 9-14; episode = (unit, my regen window); at the unit's first event in that window)

| run | fights | enemy episodes | identity known | class cached | class cached x name readability 14/16 | enemy max-HP est. (median err) | friendlies cached | NPC max HP | class TTI median reset -> cached (mean) |
|---|---|---|---|---|---|---|---|---|---|
| 9 | 38 | 399 | 95.7% | 95.5% | 83.6% | 53.4% (22.4%) | 100% | 91.4% | 6.6 -> 0.0 s (10.6 -> 1.7) |
| 10 | 35 | 397 | 95.2% | 95.2% | 83.3% | 95.2% (25.8%) | 100% | 98.1% | 6.8 -> 0.0 s (10.8 -> 0.3) |
| 11 | 18 | 204 | 92.2% | 92.2% | 80.6% | 92.2% (18.1%) | 100% | 95.3% | 6.9 -> 0.0 s (9.5 -> 0.5) |
| 12 | 10 | 112 | 86.6% | 86.6% | 75.8% | 86.6% (21.9%) | 100% | 90.7% | 9.4 -> 0.0 s (11.0 -> 1.1) |
| 13 | 25 | 260 | 94.2% | 94.2% | 82.5% | 51.9% (12.3%) | 100% | 89.6% | 9.4 -> 0.0 s (10.2 -> 0.5) |
| 14 | 15 | 180 | 91.7% | 91.7% | 80.2% | 67.2% (19.9%) | 100% | 79.0% | 7.0 -> 0.0 s (13.4 -> 4.1) |

Reading the table:

- **reset** = knowledge reset each fight (P+K inside the fight, else the meter after it).
- **cached** = the pre-fill, i.e. knowledge from earlier fights.
- **The scoreboard** is the upper bound (0 s) if its class reads clear (probe).
- **Enemy max health from class x level** is coarse: a median error of 12-26% from gear spread. An exact clear UnitHealthMax
  read (target/mouseover out of combat) is preferred when available.
- **Model limits.** Out-of-combat token reads of enemy class (target/mouseover) cannot be modelled from the log, which has
  no targets. In a BG the hostile plate class is secret even between fights (S52 in pvp), so the meter roster and the
  scoreboard are the main out-of-combat class sources there.

### 7.4 Next BG must test (v2.2.19)

1. `oocfill.read`: readability per family x field x context, especially:
   - hostile class/race/hpMax on target, mouseover, plates and arena in the pvp-ooc / prep / dead / postcombat contexts;
   - raidNtarget / nameplateNtarget names.
2. `oocfill.prefill`: live coverage of class / hpMax / level at each unit's first in-combat event (compare with 7.3).
3. `oocfill.cacheStats`: verified / drift / contradictions (expect 0 class contradictions) and merges (GUID key <-> name key).
4. `oocfill.shadow` + `oocfill.events`: tt-attacker and tt-same-class outcome rates, joined offline with the combat log.
5. `oocfill.limits` (party/raid/boss/arena/plates seen) and `oocfill.sweeps`, plus the perf of OocFill.step / OocFill.* at
   lab (reported, not gated).
6. Learned `auraDur` / `spellClass` votes from out-of-combat aura scans.

## 8. Run 15 sign-off (v2.2.19 live, Darkspear Islands, 2026-10-09 19:28-19:40 ET)

**Identification.** `ForeverDump.lua` (21.9 MB, saved 19:54 ET, addonVersion 2.2.19) holds capture
`cap-20261009192835-45` (lab, 19:28:35-19:53:54 ET, 1519 s, 1 combat probe, 0 resumes). `WoWCombatLog.txt` (6.4 MB,
advanced logging, 19:28:36-19:50:39 ET): the battleground runs 19:28:36-19:40:41, then open world until 19:50:39.
The client build is now **70334** (RefData seeds: 70291); the live learned store flagged the drift. (An earlier
copy of the SV, saved 19:16, held no capture of this BG; it was stale and is superseded.)

| check | result |
|---|---|
| errors / taint | errors 0; **6 selfErrors**, all `Derive.lua:197` on UNIT_SPELLCAST_CHANNEL_START: `channel and r[8] or r[10]` truth-tested UnitChannelInfo's secret notInterruptible (fixed: spellID is r[9]); blocked 31, all ADDON_RESTRICTION_STATE_CHANGED restriction flips during the capture; no taint.log supplied |
| decode | Lua `SVPack.UnpackAll` vs the Python converter: Record / Log / CombatLog digests identical; ForeverDumpDB identical to Lua DB + StaticDB (the converter's static merge) |
| completeness | capture complete: tape 74,891 records, 0 overwritten, 0 overflow drops; oocfill, derive, perf, identity and refLearned all present |
| perf at lab (reported, not gated) | own time 14.6 s over 1518 s = **0.96 %**; Recorder 0.22 %, OocFill 0.18 % (step mean 0.35 ms, max 4.6 ms), Derive 0.13 % (max call 18.7 ms on a meter update), DamageMeter 0.09 %; fps median 35.5 |

### Test items (v2.2.19 and v2.2.18 lists)

1. **oocfill.read matrix (BG).** Hostile players on plates and their targets: name, level, faction, powerType,
   hostile and isPlayer are clear 100 % in every context (prep, pvp-ooc, combat, post-combat, dead). Class, GUID, race,
   sex, max health and max power are secret 100 % in every context, out of combat included. `arenaN` (2 tokens in this
   BG) reads class/GUID/race/sex 91-100 % clear. Group members (raidN): everything clear except max health / max power
   (7-9 % clear). raidNtarget class clear 27-58 % (friendly targets only). Auras: every read errors (E) in every BG
   context; clear only in the open world (mouseover 56 %).
2. **Live pre-fill vs offline.** Live, at each unit's first in-combat event: enemy players 99 episodes, class 0 %,
   max health 0 %, level 100 %; NPCs 53/54 class+level; friendlies 14, level and max health 100 %. Offline
   (real tape, assumed meter-name join) said enemy class 88.2 %. The gap: enemy meter names are secret in a BG
   (item 7), so the M join never fires, and comp assignments were not a cache source.
3. **Cache.** 96,448 puts: 70,822 verified, 1,158 drift, 21 contradictions, 23,851 unknown puts, 49 merges, 86
   units. **Bug:** every friendly read (raidN 4,992, raidNtarget 888, player 790, ...) landed on ONE identity, so its
   class went unknown. The mock does not reproduce it; v2.2.20 never merges two GUID-rooted identities (a name key
   that would join two becomes ambiguous) and saves `oocfill.identCheck` (raid tokens vs distinct keys, link conflicts).
4. **Target-chain shadow rules vs log.** tt-attacker: 74 events. "single" 23: exactly one hostile player hit me within
   -1/+0.5 s in 22 (95.7 %). "multi" 48: actual attackers 0 (4), 1 (30), 2+ (14), so it over-counts. "none" 3: one
   had an attacker. tt-same-class never fired (0 events). Both stay shadow; v2.2.20 logs the single candidate's
   cached power type so the next run can check identity, not just count.
5. **Token limits and sweep cost.** Dynamic limits seen: raid 15, plates 6, arena 2, boss 5, party 0. Sweeps: ooc
   tick 363, pvp-ooc 150, dead 36, combat 28, post-combat 10, prep 9, plus event sweeps (mouseover 117, target 34,
   pets 16, regen 14+14). Cost: OocFill 2.68 s total, 0.18 % of wall time.
6. **Learned (build 70334).** auraDur 48 spells (e.g. 706 = 1800 s); castMs 2 (8008: 1.50 s vs RefData 1.48 s, no
   own-cast drift); spellClass 149 spells, 58 with mixed votes, 82 agree / 25 disagree / 42 new vs RefData. It was
   polluted by DamageTaken sources (those list spells that hit the source); v2.2.20 learns from DamageDone and
   HealingDone only.
7. **Enemy meter names out of combat.** 0 of 5,594 enemy rows had a clear name (friendly rows 6,426/12,417).
   M accuracy cannot be measured live, and the M join is impossible in a BG.
8. **Scoreboard readability.** `GetBattlefieldScore` returns name, faction, rank, race and the **localized class**
   clear on 100 % of rows (2,432 out of combat, 446 in combat, both teams). classToken, kills, deaths, honor, damage
   and healing are secret. `C_PvP.GetScoreInfo` is a clear table on 360/2,432 rows (15 %, all fields clear including
   classToken). GetNumBattlefieldScores is clear 100 %.
9. **UnitCastingInfo / UnitChannelInfo.** Hostile players: never clear (0/226; 2 secret, the rest nil). Enemy plate
   cast events: times and spellID secret (5/5). Own casts: clear (castMs above).
10. **Plate colour.** Bar colour reads clear (327) but matched a class colour 0/327 (reaction colour), so the colour
    rule stays dead.
11. **derive.read (hostile players, BG).** Clear: UnitName/GetUnitName, UnitLevel, UnitFactionGroup, UnitPowerType,
    UnitDistanceSquared (100 %, new: enemy distance), UnitIsUnit (92-98 %), UnitCanAttack/IsEnemy/Reaction,
    UnitAffectingCombat, UnitSelectionColor. Secret: UnitClass/ClassBase, UnitGUID, UnitRace, UnitSex, health, power,
    UnitPVPName, UnitArmor/Stat/AttackSpeed, absorbs. UnitDetailedThreatSituation is 10 % clear in combat.
12. **Census vs log.** The meter composition saw 15 of 16 enemies (SHAMAN 3 vs truth 4; others exact). v2.2.20
    feeds the census from the scoreboard (whole team) and takes the larger of the two.
13. **Class engine live vs log (false assignments).** 15 enemy units; 10 assigned, **all SHAMAN via "comp"**; truth
    has 4 enemy shamans, so **at least 6 are false**, 3 of them provably (rage or energy power type). The cause: the
    meter composition of the current session lists only the enemies met so far (a lower bound), and it was used to
    eliminate. Clear reads contradicted those classes 671 times and lost every time. The salted name keys cannot be
    joined to log names offline (salt not stored), so the bound is the measurable number. Offline on the real tape:
    P+K 1/1 (0 false, 6.2 %, TTI 63.7 s), M 100 % (TTI 40.4 s), but M is refuted live (item 7).

### Rule changes (v2.2.20)

| rule | before | now | why |
|---|---|---|---|
| comp (meter composition) | eliminating, could settle a class | **provisional only**, cumulative | run 15: >= 6/10 false |
| elimination vs reading | first class wins | a reading source (direct/meter/score/spell) overrides an elimination-made class | 671 lost contradictions |
| contested unit | reset to all classes, re-narrowed | never settled by elimination again | prevents re-guessing |
| score-bf (new) | - | **assigning**: GetBattlefieldScore name + localized class -> class; faction -> enemy flag; census from enemy rows | server-provided class, 100 % clear |
| identity Link | any merge | two GUID identities never merge | run 15 identity collapse |
| meter name keys | full name | realm-stripped (same as plates / scoreboard) | keys never met live |
| learned spellClass | all meter types | DamageDone / HealingDone only | 25/107 disagreed |

**Scoreboard rule and the false-claim gate.** The class value comes from the server for that exact name, so a false
claim needs two players with the same base name. Run 15 showed that keys from different sources did not meet, so
v2.2.20 records `derive.score bfJoin` (did the scoreboard key also come from a token; realm-qualified vs base names).
If bfJoin shows no joins, the rule is harmless but ineffective, and the next step is the key form.

**Reference data (16 logs incl. the full run-15 log):** 963 spells (540 with class, +53 newly tagged, 0 class flips),
30 summons, 36 NPCs. Cast time is now the 10th percentile of START->SUCCESS (pushback only lengthens a cast). When the
p10 is under half the median, it is a talent/proc shortcut and the median is used instead (Fel Domination 712). 21
cast times moved by 0.1 s or more vs v2.2.19 (e.g. Lightning Bolt 403 1.74 -> 1.50 s). Seeds stay tagged 70291; the
live store re-learns per build (70334 now).

**Log-only scoring (tooling).** `classderive.log_windows` derives my combat windows from the log alone (hostile flag
0x40, 5 s leave). Checked against the tape: run 13 overlap 72.5/77.4 %, end diff 4.0 s; run 14 74.3/94.7 %, 1.4 s.

**Other.** The SV holds raw GUIDs in the damage-meter source rows and recorder events (31 distinct in run 15, 15 in
run 14). This was pre-existing. v2.2.21 resolves it: the user decided that identities are stored raw everywhere
(section 9).

**Next BG.** (1) `derive.score bfRow / bfJoin`: do scoreboard keys meet plate keys, and how many enemies are assigned
at prep? (2) Class engine: `derive.summary` enemyAssigned / enemyProvisional / overridden, with false assignments
checked against the log by class counts and power types. (3) `oocfill.identCheck`: raid tokens = distinct keys,
linkConflicts. (4) tt-attacker single-candidate power type vs the log attacker's class. (5) Learned spellClass
agreement with RefData after the DamageTaken fix. (6) Census from the scoreboard vs truth. (7) Perf at lab
(target <= 1 % own time) and the 18.7 ms meter-update spike. (8) Optional: `/fdump set logs.autoBG true` starts the
capture on BG entry; the BG reminder (own frame) is on by default.

## 9. v2.2.21 raw identity (user decision 2026-10-09: "we should not be scrubbing any data")

**What is stored now.**
- **Keys:** every identity key is `kind:<raw value>`, i.e. the GUID, or the name exactly as read with its realm
  (`ReplayLog.IdKey`). There is no salt and no hash. NPCs keep the public `npc:<id>` group key, and the raw Creature
  GUID is stored next to it (`ws.g` / `ws.tg`, `map.g`).
- **Raw values added where only a key was written:**
  - damage-meter rows (`guid`, `name`, `unitName`, `creatureName`);
  - the class engine (`derive.units[key].names` / `.guids`; the key is a realm-stripped join helper);
  - the ooc-fill cache (`name`, `guid`, `guild` facts);
  - lab probes (`died.*.guids`);
  - the HSM export and panel.
- **Redaction:** chat and probe redaction are off by default. Only credential CVars stay redacted.
- **Secret safety:** unchanged. A secret value is never stored or compared.

**Raw GUID joins to the combat log, runs 9-15** (`tools/fdump/rawjoin.py`; every raw GUID in the SV against the
log's GUID -> class / hostile truth):

| run | meter GUIDs (joined to log) | meter class wrong | enemies in BG | enemies with a raw meter row during the BG | inference.signals GUIDs (joined) |
|---|---|---|---|---|---|
| 9 | 30 (27) | 0 | 18 | 0 | 13 (13) |
| 10 | 16 (15) | 0 | 19 | 0 | 13 (13) |
| 11 | 16 (15) | 0 | 16 | 0 | 9 (9) |
| 12 | 16 (15) | 0 | 15 | 0 | 6 (6) |
| 13 | 16 (15) | 0 | 15 | 0 | 13 (12) |
| 14 | 16 (15) | 0 | 15 | 0 | 10 (10) |
| 15 | 37 (30) | 0 | 16 | 0 (15 in the stop snapshot 19:53 ET, 13 min after the BG) | 9 (9) |

**What changes in the scores.**
- **M (damage-meter join), measured instead of simulated.** Until v2.2.20 M was simulated from the log composition:
  100 % coverage, TTI 41-217 s. With raw GUIDs the measured value is **0 % during the BG on all seven runs**. Every
  out-of-combat meter snapshot inside a BG lists only my own team with a clear GUID; enemy rows come with a secret
  GUID and name.
- **After the BG:** run 15's capture-stop snapshot lists 15 of 16 enemies with clear GUID, name and class. All
  classes match the log, so the meter class is 100 % correct per unit. That is post-hoc labelling, not a live signal.
- **Combined (P+K plus measured M) on runs 9-15:** the coverage falls to the P+K numbers: 16.7 / 26.3 / 18.8 / 6.7 /
  6.7 / 6.7 / 6.2 %, with 0 false. The live class source for enemies is the scoreboard (score-bf, v2.2.20).
- **Unchanged:** P+K and prefill scores are simulated from the log and do not change.
- **Exact live false assignments:** the class engine keys of runs 9-15 are salted, so they cannot be joined. From
  v2.2.21 captures on, rawjoin scores every live unit by GUID (`live.correct` / `live.wrong`). This replaces the
  class-count bound used in section 8 item 13.
- **Joined identity reads:** `inference.signals` GUIDs (friendly token reads) join 100 % to the log, except one
  run-13 GUID that never appears in that log.

**Toolchain.**
- **Packages:** no scrubber; every zip entry is checked byte-identical to its source.
- **Fixtures:** `fixtures/forever-70245` is raw.
- **Removed:** the anonymizer, the guide privacy gate, correlate redaction and the learned-seed GUID strip.
- **Tests:** leak and name-scan gates became raw round-trip assertions (`tests/raw_identity.lua`,
  `tests/raw_roundtrip.lua`, `tests/test_v2221.py`).

**Next BG (in addition to section 8).** Run `rawjoin` on the capture. The aim is exact per-unit live-vs-log
accuracy of the class engine (`derive.units[*].guids`) and the cache (`player:<GUID>` class). It also shows whether
the scoreboard names (`derive.units[*].names`, raw "First Last" / "Name-Realm") join the log names.

