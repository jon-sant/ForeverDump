# ForeverDump v2.2.6 findings (damage-meter self-reconcile + world-state capture)

Times ET. Addon never uses CLEU live. Ground truth for offline joins is `WoWCombatLog.txt` on the box only.
**In-game re-capture with this build is still pending** — reconcile accuracy below is from synthetic HSM re-exec + the prior run-5 meter↔log agreement; treat live numbers as the design target until the next FD_Logs session.

## Self-reconciliation loop (live ↔ meter ↔ CLEU)

### In combat (HSM live estimates)
- Per fight, `liveEst` tracks **my** damage / healing / interrupts / dispels / damage taken from UNIT_COMBAT + own casts + DAMAGE_METER_* timing (incl. type-6 dispel join).
- Per-unit `fight.world[unitKey|IdKey]`: taken, dmg (from me), interrupts, dm tick joins, crude DTPS from inter-hit gaps on that token.
- Tokens covered live for UNIT_COMBAT: player / target / focus / pet; **capture mode** registers all UNIT_COMBAT tokens (party/raid/nameplate/boss/…) filtered in-handler.

### After combat (clear meter read)
- `DamageMeter.ReadClear` (deep in capture) reads every `Enum.DamageMeterType` with all sources IdKey'd (no raw names/GUIDs).
- `HybridState:ReconcileDM` compares liveEst vs meter for damage / healing / interrupts / dispels / taken → verdicts **match / off by Δ / unexplained** into the verify ring + replay tape (`verdict` KEEP) + `f.reconcile` for HSM UI.
- Per-unit: meter `sources[Type][].id` joined to `fight.world[idKey]`; player forced from fight totals.

### Offline (three-way)
- Existing coverage fight table: log mine/others/taken/heal/interrupts vs DM.
- Deep capture adds IdKey'd source rows; coverage reports source-row / distinct-IdKey counts.
- Discrepancies (live≠meter or meter≠log) are regression leads for the next correlate pass (per-unit when sources present).

### In-game reconcile accuracy (FINDINGS target)

| Metric | Synthetic HSM (this build) | Run-5 post-combat meter↔log (prior build) | Notes |
|---|---|---|---|
| Damage (mine) | match within 2% / ±5 | matched log after combat | Over-attribution → contradiction (`dm-damage` C) |
| Healing (mine) | match / unexplained if no HEAL attribution | matched effective heals on me | Overheal does not move meter |
| Interrupts | exact (tol 0) | Earth Shock interrupt chain confirmed | cast+dm type 5 = high |
| Dispels | cast+dm type 6 when knowledge.dispel | not scored in run 5 | live truth weak without CLEU |
| Damage taken | match within 2% | matched | DM type 7 ↔ UNIT_COMBAT wound (shadow finding) |
| Per-unit (IdKey) | player match in harness; NPC via `npc:<id>` | deep sources not yet captured in game | Needs FD_Logs capture session |

**Report line for packaging:** *In-game reconcile accuracy: pending re-capture; synthetic self-reconcile match/off paths green; run-5 meter↔log damage/heal/interrupt/taken agreement stands as the floor.*

## World-state fields: tracked vs gaps

HSM is a **world** state machine. Capture mode now logs broad raw samples (`WorldCapture`, tape kind `ws`, PRI 5 droppable). HSM *inference* for non-meter world fields is deferred to the next version except where already live.

| Field | Already in HSM / Identity / Tokens | Readable / secret (1.60.1) | Capture logging (v2.2.6) | Planned workaround (next version+) |
|---|---|---|---|---|
| **Cast / channel** (spell, start/end, interruptible) | Yes: `casts[unitKey]`, enemy cast model (`ecast`/`castModel`), castBarID | Spell name/ID often **S** in combat; castBarID / notInterruptible / delay often **C** (NeverSecret) | `ws` codes for casting/channeling/notInt + clear spellId/castBar when C | Keep predicting from clear bar id + duration model; ledger last clear cast |
| **Auras** (buffs/debuffs) | Yes: `units[].auras`, ledger aura cache, GetAuraSlots counts | Instance lists / spellIds often **S** in combat; counts sometimes C OOC | `ws` buffN/debuffN slot counts; existing UNIT_AURA path | Collect-while-clear ledger; single-applier / cast-correlation (already) |
| **Health / health %** | Player running estimate (`hp`); UnitHealthMax in ledger | UnitHealth **S** in/out of combat for player; max often **C** | `ws` health/healthMax codes + clear max; UNIT_HEALTH/MAX in capture for all tokens | Anchor quiet-full OOC; UNIT_COMBAT ±amount; % from cur/max estimate |
| **Power** | Not inferred in HSM | Often **S** in combat | `ws` power/powerMax codes | Same as health: max clear + event deltas when available |
| **DTPS / healing received** | Live: player taken + per-token taken/dmg in `fight.world`; meter post-combat | UNIT_COMBAT amount **C**; meter in-combat container **S**, post-combat **C** | Meter deep sources; DM update timing joins | Offline CLEU join per IdKey; live DTPS from UC gaps (started) |
| **Distance / range bands** | Tokens matrix has no range yet | CheckInteractDistance often **C**; UnitInRange returns may be **S** | `ws` range10/range28/inRange codes | Band logic only on clear bools; never store yards from secret |
| **Threat** | Not in HSM inference | UnitThreatSituation / Detailed restricted when threat secret | `ws` threat + scaled % when C | Cache last clear status; UI only when C |
| **Target-of** (who → whom) | Identity chains (targettarget, focustarget, partyNtarget); map deltas on tape | GUID often **S** in combat; UnitIsUnit sometimes **C** | `ws` tgt IdKey when GUID clear; `me` if their target is player | Alias/fingerprint via Identity ledger (already); IdKey join |
| **Meter per-source / per-target** | ReconcileDM + DamageMeter deep read | Post-combat sources **C** (amounts); names ConditionalSecret → IdKey only | Full deep read in capture; light me/others in release | Offline per-unit CLEU↔meter↔liveEst |
| **Group/raid/nameplate coverage** | Tokens scanner matrix; Identity | Mixed | WorldCapture round-robins BuildList (all families) under budget | Inference next version |

### Perf / caps
- Release: WorldCapture **no-ops**; DamageMeter light; UNIT_COMBAT limited to player/target/focus/pet → **&lt;1%** goal unchanged.
- Capture: WorldCapture ≤0.10 ms/slice + tokenscan ≤0.12 ms; tape `ws` drops before decide/verdict/anchor; session still aimed at **~30 MB** / 25 min 40-man BG.

## What to do next in game
1. FD_Logs ON → combat with party/raid + nameplates + meter → OFF.
2. Pull `ForeverDumpLogDB.replay` + `damageMeter.fights` (deep) + verify ring; run `fdump coverage` / `correlate`.
3. Fill the reconcile accuracy table from real `f.reconcile.summary` + log joins.

## SV growth / serialize proxy (v2.2.6)

`ReplayLog.SerializeProxy` runs at capture end: row counts (keepers / ws / dm) + estimated bytes + MB/min.
Design targets (25 min 40-man BG, capture/test):

| Band | MB/min (est.) | 25 min total | Notes |
|---|---|---|---|
| Release solo/5/40 | 0.15 / 0.35 / 0.90 | small | no WorldCapture, light DM |
| Capture test (pre-ws) | 0.22 / 0.50 / 1.18 | ~29 MB @ 40 | tapeCap binds before byteBudget |
| Capture + WorldCapture ws | +~0.05–0.15 | still ≤~30 MB | delta+heartbeat; ws drops first under budget |

Logout/load: rings grow lazily; priority keep preserves decide/verdict/anchor/shadow for the session.

## Run-5 smoke: meter three-way join (v2.2.6 offline)

`fdump` `damagemeter_join` on run 5 (pre-deep-capture SV; no IdKey sources yet):

| Fights | match cells | off | unexplained | per-unit rows |
|---|---|---|---|---|
| 3 | 9 | 1 (healing fight 3) | 5 (mostly interrupts/dispels without meter) | 0 (no deep sources) |

Damage/taken match fight-over-fight; healing off once; interrupts/dispels unexplained when meter silent. Deep per-unit join awaits a capture with `DamageMeter` deepRead.
