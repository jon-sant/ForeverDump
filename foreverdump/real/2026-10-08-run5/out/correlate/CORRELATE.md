## Co-occurrence miner (tools/fdump/correlate.py)

Captures: run3, run4, run5. 1-hop windows 50/150/300/750 ms; higher-order adds 1.5 s and depth <= 4 (profile full). Lift uses add-½ smoothing (finite, with CI); status = cross-run / held-1 / provisional / failed. Tokens are canonicalized (alias collapse) before mining.


## Distinct findings (v2.2.5)

One row per real finding after token-alias collapse, lift smoothing, chain minimality, and echo filtering. Status: **cross-run** = held on ≥2 other captures; **held-1** = held on 1 other; **provisional** = single-run / one fight; **failed** = holdout failed. Proposed live rules are review-only unless marked already live.

| # | id | status | already live? | meaning | best evidence | proposed rule |
|---|---|---|---|---|---|---|
| 1 | dm-type-7 | cross-run | no | DAMAGE_METER update type 7 fires on every enemy melee hit on me (best 47/47, prec 1.0). | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=7 → SWING_DAMAGE|npc>me` support 47/47 prec 1.0 lift 19.57 [7.75–58.71]; captures run3,run4,run5; 6 variant(s) | MeterType7: DAMAGE_METER_COMBAT_SESSION_UPDATED arg0=7 -> enemy melee taken; optional live hint when UNIT_COMBAT woun... |
| 2 | cd-payload-clear | cross-run | yes | SPELL_UPDATE_COOLDOWN carries my spellID in the clear during combat (arg0=370 matched SPELL_CAST_SUCCESS spell=370, support 6/6, prec 1.0). arg3 is the GCD start-recovery category (133 = on GCD, 0 = off). Already wire... | `SPELL_UPDATE_COOLDOWN|arg0=370 → SPELL_CAST_SUCCESS|me>npc|spell=370` support 6/6 prec 1.0 lift 10.49 [1.73–31.48]; captures run3,run5; 4 variant(s) | — |
| 3 | meter-frame-join | cross-run | yes | DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target | `UNIT_COMBAT|player|arg1=HEAL → DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2 → SPELL_PERIODIC_HEAL|mine>me|spell=6371` support 25/31 prec 0.806 lift 43.66 [3.93–130.99]; captures run3,run4,run5; 35 variant(s) | — |
| 4 | totem-heal-live | cross-run | no | Totem heal ticks (e.g. spell 6371) show live as UNIT_COMBAT HEAL + UNIT_HEAL_PREDICTION on player with no own cast nearby (~0.9 precision). | `UNIT_COMBAT|player|arg4=1 → UNIT_HEAL_PREDICTION|player → SPELL_PERIODIC_HEAL|mine>me|spell=6371` support 68/85 prec 0.8 lift 8.65 [3.51–25.95]; captures run3,run4,run5; 36 variant(s) | TotemHealLive: UNIT_COMBAT/player HEAL + UNIT_HEAL_PREDICTION/player without UNIT_SPELLCAST_SUCCEEDED/player in-frame... |
| 5 | token-alias | cross-run | no | Unit-token aliasing: when a mob targets me, targettarget (and often nameplate/softenemy) refers to the same unit as player, so every player signal is duplicated on those tokens. Mining collapses aliases to a canonical... | 4 alias edge(s); e.g. targettarget→player | Offline: canonicalize tokens via same-frame payload identity + Ledger token→GUID before mining. Live: Ledger already ... |
| 6 | identity-interrupt | provisional | no | target cast interrupted (secret interrupter) + my Earth Shock SUCCEEDED in the same frame -> the interrupt was mine | `UNIT_SPELLCAST_INTERRUPTED|target → UNIT_SPELLCAST_SUCCEEDED|player → SPELL_INTERRUPT|me>npc` support 1/1 prec 1.0 lift 3.0 [0.0–9.0]; captures run5; 6 variant(s) | InterruptAttribution: UNIT_SPELLCAST_INTERRUPTED on target/nameplate/softenemy in the same frame as UNIT_SPELLCAST_SU... |
| 7 | chain:SPELL_UPDATE_COOLDOWN=>SPELL_CAST_SUCCESS|me>none | cross-run | no | SPELL_UPDATE_COOLDOWN links via UNIT_AURA / player / arg1.has=addedAuras to ground truth SPELL_CAST_SUCCESS / me>none (end-to-end precision 0.405, lift 12.83 vs shuffled-time null) | `SPELL_UPDATE_COOLDOWN → UNIT_AURA|player|arg1.has=addedAuras → SPELL_CAST_SUCCESS|me>none` support 15/37 prec 0.405 lift 12.83 [1.22–38.5]; captures run3,run4; 10 variant(s) | Chain: on SPELL_UPDATE_COOLDOWN, look for UNIT_AURA / player / arg1.has=addedAuras within the hop windows, then treat... |
| 8 | chain:UNIT_AURA|player|arg1.has=isFullUpdate=>SPELL_CAST_SUCCESS|me>none | cross-run | no | UNIT_AURA / player / arg1.has=isFullUpdate links via SPELL_ACTIVATION_OVERLAY_HIDE to ground truth SPELL_CAST_SUCCESS / me>none (end-to-end precision 0.364, lift 9.0 vs shuffled-time null) | `UNIT_AURA|player|arg1.has=isFullUpdate → SPELL_ACTIVATION_OVERLAY_HIDE → SPELL_CAST_SUCCESS|me>none` support 4/11 prec 0.364 lift 9.01 [0.23–27.02]; captures run3; 1 variant(s) | Chain: on UNIT_AURA / player / arg1.has=isFullUpdate, look for SPELL_ACTIVATION_OVERLAY_HIDE within the hop windows, ... |
| 9 | chain:UNIT_COMBAT|target=>SPELL_DAMAGE|me>npc | held-1 | no | UNIT_COMBAT / target / arg1=WOUND links via SPELL_UPDATE_COOLDOWN to ground truth SPELL_DAMAGE / me>npc (end-to-end precision 0.5, lift 8.8 vs shuffled-time null) | `UNIT_COMBAT|target|arg1=WOUND → SPELL_UPDATE_COOLDOWN → SPELL_DAMAGE|me>npc` support 5/10 prec 0.5 lift 8.8 [0.46–26.4]; captures run4; 1 variant(s) | Chain: on UNIT_COMBAT / target / arg1=WOUND, look for SPELL_UPDATE_COOLDOWN within the hop windows, then treat SPELL_... |
| 10 | chain:UNIT_SPELLCAST_SUCCEEDED|target=>SPELL_CAST_SUCCESS|npc>me | provisional | no | UNIT_SPELLCAST_SUCCEEDED / target links via UNIT_SPELLCAST_STOP / target to ground truth SPELL_CAST_SUCCESS / npc>me / spell=7951 (end-to-end precision 1.0, lift 12.75 vs shuffled-time null) | `UNIT_SPELLCAST_SUCCEEDED|target → UNIT_SPELLCAST_STOP|target → SPELL_CAST_SUCCESS|npc>me|spell=7951` support 8/8 prec 1.0 lift 12.76 [2.38–38.27]; captures run4; 1 variant(s) | Chain: on UNIT_SPELLCAST_SUCCEEDED / target, look for UNIT_SPELLCAST_STOP / target within the hop windows, then treat... |
| 11 | chain:PLAYER_TOTEM_UPDATE=>SPELL_PERIODIC_DAMAGE|npc>player | provisional | no | PLAYER_TOTEM_UPDATE links via SPELL_UPDATE_USABLE -> PLAYER_TOTEM_UPDATE to ground truth SPELL_PERIODIC_DAMAGE / npc>player / spell=744 (end-to-end precision 0.833, lift 10.15 vs shuffled-time null) | `PLAYER_TOTEM_UPDATE → SPELL_UPDATE_USABLE → PLAYER_TOTEM_UPDATE` support 5/6 prec 0.833 lift 10.16 [0.96–30.47]; captures run4; 1 variant(s) | Chain: on PLAYER_TOTEM_UPDATE, look for SPELL_UPDATE_USABLE / PLAYER_TOTEM_UPDATE within the hop windows, then treat ... |
| 12 | chain:UNIT_SPELLCAST_SENT|player=>SPELL_PERIODIC_DAMAGE|npc>player | provisional | no | UNIT_SPELLCAST_SENT / player links via PLAYER_TOTEM_UPDATE to ground truth SPELL_PERIODIC_DAMAGE / npc>player / spell=744 (end-to-end precision 0.312, lift 10.15 vs shuffled-time null) | `UNIT_SPELLCAST_SENT|player → PLAYER_TOTEM_UPDATE → SPELL_PERIODIC_DAMAGE|npc>player|spell=744` support 5/16 prec 0.312 lift 10.14 [0.32–30.42]; captures run4; 2 variant(s) | Chain: on UNIT_SPELLCAST_SENT / player, look for PLAYER_TOTEM_UPDATE within the hop windows, then treat SPELL_PERIODI... |

### Echoes / side-effects (appendix, not leads)

33 pair(s)/chain(s) parked here (BAG/ACTIONBAR cooldown UI, mouse globals, SENT→SUCCEEDED, happiness, range checks, etc.) unless they uniquely carry a clear combat spellID.

| capture | pattern | hops (short) | support | prec | lift |
|---|---|---|---|---|---|
| run3 | sequence | CURSOR_CHANGED|arg0=True → PLAYER_STARTED_TURNING | 7 | 0.583 | 12.86 |
| run3 | sequence | PLAYER_STOPPED_TURNING → PLAYER_TARGET_CHANGED | 4 | 0.5 | 9.0 |
| run3 | chain | UNIT_SPELLCAST_SENT|player → PLAYER_TOTEM_UPDATE → UNIT_SPELLCAST_SUCCEEDED|player | 4 | 0.5 | 9.0 |
| run3 | chain | UNIT_SPELLCAST_SENT|player → PLAYER_TOTEM_UPDATE → UNIT_SPELLCAST_SUCCEEDED|player | 4 | 0.5 | 9.0 |
| run3 | chain | UNIT_SPELLCAST_SENT|player → PLAYER_TOTEM_UPDATE → UNIT_SPELLCAST_SUCCEEDED|player | 4 | 0.5 | 9.0 |
| run3 | chain | UNIT_SPELLCAST_SENT|player → PLAYER_TOTEM_UPDATE → UNIT_SPELLCAST_SUCCEEDED|player | 4 | 0.5 | 9.0 |
| run3 | chain | UNIT_SPELLCAST_SENT|player → UNIT_AURA|player|arg1.has=isFullUpdate → SPELL_UPDATE_COOLDOWN | 4 | 0.5 | 9.0 |
| run3 | chain | UNIT_SPELLCAST_SENT|player → UNIT_AURA|player|arg1.has=isFullUpdate → SPELL_UPDATE_COOLDOWN | 4 | 0.5 | 9.0 |
| run3 | chain | CURSOR_CHANGED|arg0=True → UNIT_TARGET|player → PLAYER_STOPPED_TURNING | 4 | 0.333 | 8.3 |
| run3 | chain | CURSOR_CHANGED|arg0=True → UNIT_TARGET|player → PLAYER_STOPPED_TURNING | 4 | 0.333 | 8.3 |
| run3 | chain | UNIT_SPELLCAST_SENT|player → PLAYER_TOTEM_UPDATE → UNIT_SPELLCAST_SUCCEEDED|player | 4 | 0.5 | 7.72 |
| run3 | chain | UNIT_SPELLCAST_SENT|player → PLAYER_TOTEM_UPDATE → UNIT_SPELLCAST_SUCCEEDED|player | 4 | 0.5 | 7.72 |
| run3 | chain | CURSOR_CHANGED|arg0=True → UNIT_TARGET|player → PLAYER_STOPPED_TURNING | 4 | 0.333 | 7.71 |
| run3 | sequence | PLAYER_TARGET_CHANGED → PLAYER_STARTED_TURNING | 4 | 0.571 | 6.75 |
| run5 | chain | BAG_UPDATE_COOLDOWN → DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0 → SPELL_DAMAGE|me>npc | 16 | 0.444 | 13.2 |
| run5 | sequence | BAG_UPDATE_COOLDOWN → DAMAGE_METER_COMBAT_SESSION_UPDATED | 21 | 0.583 | 9.72 |
| run5 | chain | BAG_UPDATE_COOLDOWN → DAMAGE_METER_COMBAT_SESSION_UPDATED → SPELL_UPDATE_COOLDOWN | 15 | 0.417 | 12.01 |
| run5 | sequence | DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0 → BAG_UPDATE_COOLDOWN | 18 | 0.45 | 9.86 |
| run3 | echo-1hop | CURSOR_CHANGED|arg0=True → PLAYER_STARTED_TURNING | 8 | 0.667 | 5.07 |
| run3 | echo-1hop | PLAYER_TARGET_CHANGED → PLAYER_STARTED_TURNING | 5 | 0.714 | 5.35 |
| run3 | echo-1hop | PLAYER_STOPPED_TURNING → PLAYER_TARGET_CHANGED | 5 | 0.625 | 4.35 |
| run3 | echo-1hop | PLAYER_STARTED_TURNING → UNIT_TARGET|player | 5 | 0.625 | 4.35 |
| run3 | echo-1hop | PLAYER_STOPPED_TURNING → CURSOR_CHANGED|arg0=True | 4 | 0.5 | 3.56 |
| run3 | echo-1hop | PLAYER_STOPPED_MOVING → PLAYER_STOPPED_TURNING | 4 | 0.571 | 4.58 |
| run3 | echo-1hop | PLAYER_STOPPED_TURNING → SPELL_AURA_APPLIED|player>player | 4 | 0.5 | 3.56 |
### Rules not already encoded in the HSM (new leads)

| capture | kind | A | B | window ms | support | precision | recall | lift | lag s | flags | holdout |
|---|---|---|---|---|---|---|---|---|---|---|---|
| run3 | live->truth | `UNIT_HEAL_PREDICTION|player` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 25/32 | 0.781 | 1.0 | 18.3 | -0.022 |  | run4:held(0.625); run5:held(0.895) |
| run3 | live->truth | `UNIT_HEAL_PREDICTION|player` | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 50 | 24/32 | 0.75 | 0.96 | 17.59 | -0.023 |  | run4:held(0.583); run5:held(0.877) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN` | `UNIT_SPELLCAST_SENT|player` | 300 | 16/20 | 0.8 | 1.0 | 8.32 | 0.054 |  | run4:held(0.838); run5:held(0.773) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN` | `UNIT_SPELLCAST_SUCCEEDED|player` | 300 | 15/20 | 0.75 | 1.0 | 7.81 | 0.0 |  | run4:held(0.784); run5:held(0.712) |
| run3 | live->truth | `SPELL_ACTIVATION_OVERLAY_HIDE` | `SPELL_AURA_APPLIED|player>player` | 50 | 8/34 | 0.235 | 1.0 | 5.64 | -0.021 |  | run4:failed(0.0); run5:held(0.242) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN` | `PLAYER_TOTEM_UPDATE` | 300 | 10/20 | 0.5 | 1.0 | 5.29 | 0.0 |  | run4:held(0.324); run5:failed(0.242) |
| run3 | live->live | `UNIT_AURA|player|arg1.has=isFullUpdate` | `SPELL_UPDATE_COOLDOWN` | 300 | 7/11 | 0.636 | 0.6 | 6.62 | 0.0 |  | run4:held(0.8); run5:held(0.762) |
| run3 | live->truth | `SPELL_UPDATE_COOLDOWN` | `SPELL_CAST_SUCCESS|me>none` | 150 | 7/20 | 0.35 | 1.0 | 5.53 | -0.021 |  | run4:held(0.351); run5:held(0.258) |
| run3 | live->truth | `SPELL_UPDATE_COOLDOWN` | `SPELL_SUMMON|me>mine` | 150 | 7/20 | 0.35 | 1.0 | 5.53 | -0.021 |  | run4:held(0.216); run5:failed(0.152) |
| run3 | live->live | `UNIT_AURA|player|arg1.has=addedAuras` | `SPELL_UPDATE_COOLDOWN` | 300 | 5/8 | 0.625 | 0.45 | 6.59 | 0.0 |  | run4:held(0.8); run5:held(1.0) |
| run3 | live->truth | `SPELL_UPDATE_COOLDOWN|arg0=370` | `SPELL_CAST_SUCCESS|me>npc|spell=370` | 300 | 6/6 | 1.0 | 1.0 | 10.49 | 0.056 | id-match | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg0=370` | `UNIT_SPELLCAST_SENT|player|arg1=Savannah Huntress` | 300 | 6/6 | 1.0 | 1.0 | 10.49 | 0.078 | provisional | run4:failed(0.0); run5:failed(0.0) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg0=370` | `UNIT_SPELLCAST_SUCCEEDED|player|arg2=370` | 300 | 6/6 | 1.0 | 1.0 | 10.49 | 0.078 | id-match | run4:held(1.0); run5:held(1.0) |
| run3 | live->truth | `PLAYER_TOTEM_UPDATE` | `SPELL_CAST_SUCCESS|me>none` | 300 | 6/8 | 0.75 | 1.0 | 8.31 | -0.021 |  | run4:held(1.0); run5:held(0.778) |
| run3 | live->live | `UNIT_AURA|player|arg1.has=isFullUpdate` | `SPELL_ACTIVATION_OVERLAY_HIDE` | 50 | 6/11 | 0.545 | 0.176 | 10.72 | 0.0 | provisional | run4:failed(0.2); run5:failed(0.238) |
| run3 | live->live | `PLAYER_TARGET_CHANGED` | `UNIT_TARGET|player` | 750 | 7/7 | 1.0 | 1.0 | 7.3 | 0.313 |  | run4:held(1.0); run5:held(0.917) |
| run3 | live->live | `UNIT_AURA|player|arg1.has=isFullUpdate` | `PLAYER_TOTEM_UPDATE` | 300 | 5/11 | 0.455 | 0.875 | 4.86 | 0.0 |  | run4:held(0.333); run5:held(0.286) |
| run3 | live->live | `PLAYER_STOPPED_MOVING` | `PLAYER_STARTED_MOVING` | 750 | 6/7 | 0.857 | 0.857 | 6.62 | -0.166 |  | run4:held(0.667); run5:failed(0.222) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|player` | `PLAYER_TOTEM_UPDATE` | 300 | 4/8 | 0.5 | 0.75 | 5.39 | 0.0 |  | run4:held(0.375); run5:held(0.28) |
| run3 | live->live | `UNIT_SPELLCAST_SUCCEEDED|player` | `PLAYER_TOTEM_UPDATE` | 300 | 4/8 | 0.5 | 0.75 | 5.39 | 0.0 |  | run4:held(0.375); run5:held(0.28) |
| run3 | live->live | `UNIT_AURA|player|arg1.has=addedAuras` | `SPELL_ACTIVATION_OVERLAY_HIDE` | 50 | 5/8 | 0.625 | 0.147 | 9.89 | 0.0 |  | run4:failed(0.3); run5:held(0.5) |
| run3 | live->live | `CURSOR_CHANGED|arg0=True` | `PLAYER_TARGET_CHANGED` | 750 | 8/12 | 0.667 | 0.571 | 5.07 | 0.0 | provisional | run4:failed(0.238); run5:failed(0.304) |
| run3 | truth->truth | `SPELL_CAST_SUCCESS|me>none` | `SPELL_SUMMON|me>mine` | 50 | 4/4 | 1.0 | 1.0 | 8.88 | 0.0 |  | run4:held(0.6); run5:held(0.6) |
| run3 | truth->truth | `SPELL_SUMMON|me>mine` | `SPELL_CAST_SUCCESS|me>none` | 50 | 4/4 | 1.0 | 1.0 | 8.88 | 0.0 |  | run4:held(0.833); run5:failed(0.333) |
| run3 | live->truth | `UNIT_SPELLCAST_SENT|player` | `SPELL_SUMMON|me>mine` | 50 | 4/8 | 0.5 | 1.0 | 8.09 | -0.021 |  | run4:held(0.375); run5:failed(0.24) |
| run3 | live->truth | `UNIT_SPELLCAST_SUCCEEDED|player` | `SPELL_SUMMON|me>mine` | 50 | 4/8 | 0.5 | 1.0 | 8.09 | -0.021 |  | run4:held(0.375); run5:failed(0.24) |
| run3 | live->truth | `UNIT_AURA|player|arg1.has=isFullUpdate` | `SPELL_CAST_SUCCESS|me>none` | 50 | 4/11 | 0.364 | 1.0 | 7.44 | -0.021 |  | run4:held(0.4); run5:held(0.429) |
| run3 | live->truth | `UNIT_AURA|player|arg1.has=isFullUpdate` | `SPELL_SUMMON|me>mine` | 50 | 4/11 | 0.364 | 1.0 | 7.44 | -0.021 |  | run4:held(0.2); run5:held(0.238) |
| run3 | live->live | `CURSOR_CHANGED|arg0=True` | `UNIT_TARGET|player` | 750 | 8/12 | 0.667 | 0.5 | 5.07 | 0.322 |  | run4:failed(0.19); run5:held(0.348) |
| run3 | live->live | `CURSOR_CHANGED|arg0=True` | `PLAYER_STARTED_TURNING` | 750 | 8/12 | 0.667 | 0.5 | 5.07 | 0.021 | provisional | run4:failed(0.143); run5:failed(0.196) |
| run3 | live->truth | `SPELL_ACTIVATION_OVERLAY_HIDE` | `SPELL_CAST_SUCCESS|me>none` | 50 | 4/34 | 0.118 | 1.0 | 3.0 | -0.021 |  | run4:held(0.286); run5:held(0.182) |
| run3 | live->truth | `SPELL_ACTIVATION_OVERLAY_HIDE` | `SPELL_SUMMON|me>mine` | 50 | 4/34 | 0.118 | 1.0 | 3.0 | -0.021 |  | run4:held(0.286); run5:held(0.182) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN` | `PLAYER_TOTEM_UPDATE|arg0=2` | 300 | 5/20 | 0.25 | 1.0 | 2.77 | 0.0 |  | run4:held(0.162); run5:failed(0.106) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|player` | `UNIT_AURA|player|arg1.has=isFullUpdate` | 300 | 5/8 | 0.625 | 0.455 | 6.59 | 0.0 |  | run4:held(0.5); run5:held(0.4) |
| run3 | live->live | `UNIT_SPELLCAST_SUCCEEDED|player` | `UNIT_AURA|player|arg1.has=isFullUpdate` | 300 | 5/8 | 0.625 | 0.455 | 6.59 | 0.0 |  | run4:held(0.562); run5:held(0.44) |
| run3 | live->live | `UNIT_TARGET|player` | `NAME_PLATE_UNIT_ADDED|nameplateN` | 750 | 5/6 | 0.833 | 0.714 | 5.74 | 0.541 | provisional | run4:failed(0.25); run5:failed(0.1) |
| run3 | live->live | `PLAYER_TARGET_CHANGED` | `SPELL_UPDATE_USABLE` | 50 | 7/7 | 1.0 | 0.031 | 13.82 | 0.0 |  | run4:held(1.0); run5:held(0.75) |
| run3 | live->live | `PLAYER_TARGET_CHANGED` | `PLAYER_STARTED_TURNING` | 750 | 5/7 | 0.714 | 0.625 | 5.35 | 0.167 | provisional | run4:failed(0.0); run5:failed(0.167) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|player` | `SPELL_ACTIVATION_OVERLAY_HIDE` | 50 | 4/8 | 0.5 | 0.118 | 8.09 | 0.0 |  | run4:held(0.375); run5:failed(0.24) |
| run3 | live->live | `UNIT_SPELLCAST_SUCCEEDED|player` | `SPELL_ACTIVATION_OVERLAY_HIDE` | 50 | 4/8 | 0.5 | 0.118 | 8.09 | 0.0 |  | run4:held(0.375); run5:failed(0.24) |

### Rediscovered (already known)

| capture | kind | A | B | window ms | support | precision | recall | lift | lag s | flags | holdout |
|---|---|---|---|---|---|---|---|---|---|---|---|
| run3 | truth->truth | `SWING_DAMAGE|npc>me` | `SWING_DAMAGE_LANDED|npc>me` | 50 | 48/49 | 0.98 | 0.98 | 31.33 | 0.0 | log structure | run4:held(1.0); run5:held(1.0) |
| run3 | truth->truth | `SWING_DAMAGE_LANDED|npc>me` | `SWING_DAMAGE|npc>me` | 50 | 46/49 | 0.939 | 0.939 | 30.03 | 0.0 | log structure | run4:held(0.933); run5:held(1.0) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=7` | `SWING_DAMAGE|npc>me` | 50 | 47/47 | 1.0 | 0.959 | 19.57 | -0.023 | damage meter | run4:held(0.714); run5:held(0.952) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=7` | `SWING_DAMAGE_LANDED|npc>me` | 50 | 47/47 | 1.0 | 0.959 | 19.57 | -0.023 | damage meter | run4:held(0.714); run5:held(0.952) |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED` | `UNIT_HEALTH|player` | 50 | 74/76 | 0.974 | 0.796 | 13.45 | 0.0 | damage meter | run4:held(0.83); run5:held(0.648) |
| run3 | truth->truth | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 24/25 | 0.96 | 0.96 | 31.72 | 0.0 | id-match,same spell | run4:held(0.933); run5:held(0.847) |
| run3 | live->live | `UNIT_POWER_UPDATE|player|arg1=MANA` | `UNIT_HAPPINESS|player` | 50 | 34/36 | 0.944 | 1.0 | 21.15 | 0.0 | ui echo | run4:held(0.936); run5:held(0.976) |
| run3 | live->live | `UNIT_COMBAT|player|arg1=HEAL` | `UNIT_HEAL_PREDICTION|player` | 50 | 31/31 | 1.0 | 0.969 | 23.56 | 0.0 | unit combat | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `UNIT_COMBAT|player|arg3=6` | `UNIT_HEAL_PREDICTION|player` | 50 | 29/29 | 1.0 | 0.906 | 23.91 | 0.0 | unit combat | run4:held(1.0); run5:absent |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED` | `SWING_DAMAGE|npc>me` | 50 | 49/76 | 0.645 | 1.0 | 8.94 | -0.023 | provisional,damage meter | run4:failed(0.319); run5:failed(0.242) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED` | `SWING_DAMAGE_LANDED|npc>me` | 50 | 49/76 | 0.645 | 1.0 | 8.94 | -0.023 | provisional,damage meter | run4:failed(0.319); run5:failed(0.242) |
| run3 | live->live | `UNIT_COMBAT|player|arg1=HEAL` | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | 50 | 28/31 | 0.903 | 1.0 | 21.31 | 0.0 | unit combat | run4:held(0.652); run5:held(0.566) |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | `UNIT_HEAL_PREDICTION|player` | 50 | 28/28 | 1.0 | 0.875 | 24.09 | 0.0 | damage meter | run4:held(1.0); run5:held(1.0) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 25/28 | 0.893 | 1.0 | 21.56 | -0.022 | damage meter | run4:held(0.933); run5:held(0.967) |
| run3 | live->live | `UNIT_COMBAT|player|arg3=6` | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | 50 | 26/29 | 0.897 | 0.929 | 21.49 | 0.0 | unit combat | run4:held(0.667); run5:absent |
| run3 | live->live | `GLOBAL_MOUSE_DOWN` | `GLOBAL_REGION_MOUSE_DOWN` | 50 | 23/23 | 1.0 | 1.0 | 24.42 | 0.0 | ui echo | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `UNIT_POWER_FREQUENT|player|arg1=MANA` | `SPELL_UPDATE_USABLE` | 50 | 112/115 | 0.974 | 0.496 | 9.35 | 0.0 | health side effect | run4:held(0.982); run5:held(0.97) |
| run3 | live->truth | `UNIT_HEALTH|player` | `SWING_DAMAGE_LANDED|npc>me` | 50 | 49/93 | 0.527 | 1.0 | 6.16 | -0.023 | health side effect | run4:failed(0.259); run5:held(0.297) |
| run3 | live->truth | `UNIT_COMBAT|player|arg1=HEAL` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 25/31 | 0.806 | 1.0 | 19.06 | -0.022 | unit combat | run4:held(0.652); run5:held(0.962) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 50 | 24/28 | 0.857 | 0.96 | 20.7 | -0.023 | damage meter | run4:held(0.867); run5:held(0.933) |
| run3 | live->truth | `UNIT_COMBAT|player|arg3=6` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 24/29 | 0.828 | 0.96 | 19.87 | -0.022 | unit combat | run4:held(0.667); run5:absent |
| run3 | live->live | `GLOBAL_REGION_MOUSE_UP` | `GLOBAL_MOUSE_UP` | 50 | 22/23 | 0.957 | 0.957 | 23.39 | 0.0 | ui echo | run4:held(0.96); run5:held(0.974) |
| run3 | live->truth | `UNIT_COMBAT|player|arg1=HEAL` | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 50 | 24/31 | 0.774 | 0.96 | 18.32 | -0.023 | unit combat | run4:held(0.609); run5:held(0.943) |
| run3 | live->truth | `UNIT_HEALTH|player` | `SWING_DAMAGE|npc>me` | 50 | 47/93 | 0.505 | 0.959 | 5.9 | -0.023 | health side effect | run4:held(0.259); run5:held(0.297) |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=7` | `UNIT_HEALTH|player` | 50 | 46/47 | 0.979 | 0.495 | 19.16 | 0.0 | damage meter | run4:held(1.0); run5:held(1.0) |
| run3 | live->truth | `UNIT_COMBAT|player|arg3=6` | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 50 | 23/29 | 0.793 | 0.92 | 19.05 | -0.023 | unit combat | run4:held(0.667); run5:absent |
| run3 | live->live | `ACTIONBAR_UPDATE_COOLDOWN` | `SPELL_UPDATE_COOLDOWN` | 50 | 20/21 | 0.952 | 1.0 | 23.17 | 0.0 | ui echo | run4:held(0.925); run5:held(0.971) |
| run3 | live->live | `CURRENT_SPELL_CAST_CHANGED|arg0=False` | `ACTIONBAR_UPDATE_STATE` | 50 | 17/17 | 1.0 | 1.0 | 23.28 | 0.0 | ui echo | run4:held(1.0); run5:held(1.0) |
| run3 | truth->truth | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 50 | 17/25 | 0.68 | 0.68 | 22.65 | 0.0 | id-match,same spell | run4:held(0.8); run5:held(0.608) |
| run3 | live->live | `ACTIONBAR_UPDATE_STATE` | `SPELL_UPDATE_COOLDOWN` | 50 | 17/17 | 1.0 | 0.85 | 23.28 | 0.0 | ui echo | run4:held(0.943); run5:held(0.933) |
| run3 | live->live | `CURRENT_SPELL_CAST_CHANGED|arg0=False` | `SPELL_UPDATE_COOLDOWN` | 50 | 17/17 | 1.0 | 0.85 | 23.28 | 0.0 | ui echo | run4:held(0.943); run5:held(0.948) |
| run3 | live->live | `ACTIONBAR_UPDATE_COOLDOWN` | `ACTIONBAR_UPDATE_STATE` | 50 | 17/21 | 0.81 | 1.0 | 19.8 | 0.0 | ui echo | run4:held(0.85); run5:held(0.824) |
| run3 | live->live | `CURRENT_SPELL_CAST_CHANGED|arg0=False` | `ACTIONBAR_UPDATE_COOLDOWN` | 50 | 17/17 | 1.0 | 0.81 | 23.28 | 0.0 | ui echo | run4:held(0.971); run5:held(0.948) |
| run3 | live->live | `UNIT_HEALTH|player` | `UNIT_COMBAT|player|arg1=HEAL` | 50 | 31/93 | 0.333 | 1.0 | 3.91 | 0.0 | unit combat | run4:held(0.397); run5:held(0.514) |
| run3 | live->live | `UNIT_HEALTH|player` | `UNIT_HEAL_PREDICTION|player` | 50 | 31/93 | 0.333 | 0.969 | 3.91 | 0.0 | health side effect | run4:held(0.397); run5:held(0.514) |
| run3 | live->live | `UNIT_HEALTH|player` | `UNIT_COMBAT|player|arg3=6` | 50 | 29/93 | 0.312 | 1.0 | 3.67 | 0.0 | health side effect | run4:held(0.31); run5:failed(0.0) |
| run3 | live->live | `UNIT_HEALTH|player` | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | 50 | 28/93 | 0.301 | 1.0 | 3.54 | 0.0 | damage meter | run4:held(0.259); run5:held(0.405) |
| run3 | live->live | `WORLD_CURSOR_TOOLTIP_UPDATE|arg0=1` | `UPDATE_MOUSEOVER_UNIT` | 50 | 13/14 | 0.929 | 1.0 | 20.13 | 0.0 | ui echo | run4:held(1.0); run5:held(0.821) |
| run3 | live->live | `GLOBAL_MOUSE_DOWN|arg0=LeftButton` | `GLOBAL_REGION_MOUSE_DOWN` | 50 | 14/14 | 1.0 | 0.609 | 21.62 | 0.0 | ui echo | run4:held(1.0); run5:held(1.0) |
| run3 | live->truth | `UNIT_HEALTH|player` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 25/93 | 0.269 | 1.0 | 3.17 | -0.022 | health side effect | run4:held(0.259); run5:held(0.486) |

### Rare targets (B seen fewer than min-support times; best A per B by id match, then null probability) - provisional by nature

| capture | kind | A | B | rank | id match | p(null) | precision | lag s | holdout |
|---|---|---|---|---|---|---|---|---|---|
| run3 | live->live | `UPDATE_MACROS` | `ACTIONBAR_SLOT_CHANGED` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `ACTION_RANGE_CHECK_UPDATE|arg0=10` | `ACTIONBAR_SLOT_CHANGED|arg0=10` | 1 | False | 1.2e-05 | 0.667 | 0.0 | run3:failed; run5:failed |
| run4 | live->live | `ACTION_RANGE_CHECK_UPDATE|arg0=11` | `ACTIONBAR_SLOT_CHANGED|arg0=11` | 1 | False | 3.5e-05 | 0.4 | 0.0 | run3:failed; run5:held |
| run3 | live->live | `UPDATE_MACROS` | `ACTIONBAR_SLOT_CHANGED|arg0=60` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `UPDATE_MACROS` | `ACTIONBAR_SLOT_CHANGED|arg0=60` | 1 | False | 0.001177 | 1.0 | 0.0 | run3:held; run5:held |
| run5 | live->live | `UPDATE_MACROS` | `ACTIONBAR_SLOT_CHANGED|arg0=60` | 1 | False | 0.000697 | 1.0 | 0.0 | run3:held; run4:held |
| run4 | live->live | `ACTIONBAR_SLOT_CHANGED|arg0=66` | `UPDATE_SHAPESHIFT_FORM` | 1 | False | 1.2e-05 | 1.0 | 0.0 | run3:absent; run5:absent |
| run3 | live->live | `ADDON_RESTRICTION_STATE_CHANGED` | `ACTIONBAR_UPDATE_USABLE` | 1 | False | 3e-06 | 1.0 | 0.0 | run4:held; run5:held |
| run3 | live->live | `MODIFIER_STATE_CHANGED|arg0=LALT` | `ACTION_RANGE_CHECK_UPDATE|arg0=26` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:absent; run5:held |
| run5 | live->live | `MODIFIER_STATE_CHANGED` | `ACTION_RANGE_CHECK_UPDATE|arg0=26` | 1 | False | 0.001393 | 0.5 | 0.0 | run3:failed; run4:failed |
| run4 | live->truth | `ACTION_RANGE_CHECK_UPDATE|arg0=63` | `SPELL_CAST_START|npc>none` | 1 | False | 0.009415 | 1.0 | 0.026 | run3:absent; run5:absent |
| run4 | live->live | `UNIT_COMBAT|player|arg3=20` | `ACTION_RANGE_CHECK_UPDATE|arg0=63` | 1 | False | 0.005884 | 0.2 | 0.0 | run3:absent; run5:absent |
| run4 | live->truth | `ACTION_RANGE_CHECK_UPDATE|arg0=63` | `SPELL_CAST_START|npc>none|spell=7951` | 2 | False | 0.009415 | 1.0 | 0.026 | run3:absent; run5:absent |
| run3 | live->live | `MODIFIER_STATE_CHANGED|arg0=LALT` | `ACTION_RANGE_CHECK_UPDATE|arg0=68` | 1 | False | 0.000872 | 1.0 | 0.021 | run4:absent; run5:failed |
| run4 | live->live | `UNIT_COMBAT|player|arg3=21` | `ACTION_RANGE_CHECK_UPDATE|arg0=9` | 1 | False | 0.004707 | 0.25 | 0.0 | run3:absent; run5:absent |
| run3 | live->live | `ADDON_RESTRICTION_STATE_CHANGED` | `ACTION_USABLE_CHANGED` | 1 | False | 3e-06 | 1.0 | 0.0 | run4:held; run5:held |
| run3 | live->live | `ADDON_RESTRICTION_STATE_CHANGED` | `UNIT_THREAT_SITUATION_UPDATE|player` | 1 | False | 1.9e-05 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `ADDON_RESTRICTION_STATE_CHANGED` | `ACTION_USABLE_CHANGED` | 1 | False | 1.2e-05 | 1.0 | 0.0 | run3:held; run5:held |
| run3 | live->live | `ADDON_RESTRICTION_STATE_CHANGED|arg0=0` | `UNIT_THREAT_SITUATION_UPDATE|player` | 1 | False | 1.9e-05 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `ADDON_RESTRICTION_STATE_CHANGED|arg0=0` | `ACTION_USABLE_CHANGED` | 1 | False | 1.2e-05 | 1.0 | 0.0 | run3:held; run5:held |
| run5 | live->live | `ZONE_CHANGED` | `AREA_POIS_UPDATED` | 1 | False | 0.000697 | 1.0 | 0.021 | run3:absent; run4:absent |
| run3 | live->truth | `CRITERIA_UPDATE` | `SWING_DAMAGE|me>npc` | 1 | False | 0.001744 | 1.0 | -0.022 | run4:held; run5:held |
| run3 | live->live | `UNIT_DIED` | `CRITERIA_UPDATE` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:failed; run5:failed |
| run4 | live->truth | `CRITERIA_UPDATE` | `UNIT_DIED|none>npc` | 1 | False | 0.003531 | 1.0 | 0.004 | run3:held; run5:held |
| run4 | live->live | `PLAYER_SWING` | `CRITERIA_UPDATE` | 1 | False | 0.001177 | 1.0 | 0.0 | run3:held; run5:failed |
| run3 | live->truth | `CRITERIA_UPDATE` | `SWING_DAMAGE_LANDED|me>npc` | 2 | False | 0.001744 | 1.0 | -0.022 | run4:held; run5:held |
| run5 | live->live | `UNIT_SPELLCAST_FAILED_QUIET|player` | `CURRENT_SPELL_CAST_CHANGED|arg0=True` | 1 | False | 0.000697 | 1.0 | 0.0 | run3:absent; run4:absent |
| run3 | live->live | `GLOBAL_REGION_MOUSE_UP|arg0=<frame:MultiBarBottomRightButton12>` | `CVAR_UPDATE` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `GLOBAL_REGION_MOUSE_DOWN|arg0=<frame:MultiBarBottomRightButton12>` | `CVAR_UPDATE` | 1 | False | 0.001177 | 1.0 | 0.041 | run3:failed; run5:failed |
| run5 | live->live | `GLOBAL_REGION_MOUSE_UP|arg0=<frame:MultiBarBottomRightButton12>` | `CVAR_UPDATE` | 1 | False | 0.000697 | 1.0 | 0.0 | run3:held; run4:held |
| run3 | live->live | `GLOBAL_REGION_MOUSE_UP|arg0=<frame:MultiBarBottomRightButton12>` | `CVAR_UPDATE|arg0=taintLog` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `GLOBAL_REGION_MOUSE_DOWN|arg0=<frame:MultiBarBottomRightButton12>` | `CVAR_UPDATE|arg0=taintLog` | 1 | False | 0.001177 | 1.0 | 0.041 | run3:failed; run5:failed |
| run5 | live->live | `GLOBAL_REGION_MOUSE_UP|arg0=<frame:MultiBarBottomRightButton12>` | `CVAR_UPDATE|arg0=taintLog` | 1 | False | 0.000697 | 1.0 | 0.0 | run3:held; run4:held |
| run3 | live->live | `PLAYER_SWING` | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=0` | 1 | False | 3e-06 | 1.0 | 0.0 | run4:held; run5:held |
| run3 | live->truth | `DAMAGE_METER_CURRENT_SESSION_UPDATED` | `SPELL_AURA_APPLIED|player>player|spell=71` | 1 | False | 0.001744 | 1.0 | -0.021 | run4:failed; run5:failed |
| run3 | live->live | `PLAYER_REGEN_DISABLED` | `DAMAGE_METER_CURRENT_SESSION_UPDATED` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->truth | `DAMAGE_METER_CURRENT_SESSION_UPDATED` | `SPELL_CAST_START|npc>none` | 1 | False | 0.009415 | 1.0 | 0.005 | run3:failed; run5:failed |
| run4 | live->live | `PLAYER_REGEN_DISABLED` | `DAMAGE_METER_CURRENT_SESSION_UPDATED` | 1 | False | 0.001177 | 1.0 | 0.0 | run3:held; run5:held |
| run3 | live->truth | `DAMAGE_METER_CURRENT_SESSION_UPDATED` | `SWING_DAMAGE|me>npc` | 2 | False | 0.001744 | 1.0 | -0.021 | run4:failed; run5:failed |
| run4 | live->truth | `DAMAGE_METER_CURRENT_SESSION_UPDATED` | `SPELL_CAST_START|npc>none|spell=7951` | 2 | False | 0.009415 | 1.0 | 0.005 | run3:failed; run5:failed |

### Durations (shared clear id chains)

| capture | from | to | npc | n | median s | min | max | consistent |
|---|---|---|---|---|---|---|---|---|
| run3 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_DELAYED | player | 2 | 0.221 | 0.221 | 0.221 | True |
| run3 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | player | 2 | 1.718 | 1.718 | 1.718 | True |
| run3 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | player | 2 | 1.718 | 1.718 | 1.718 | True |
| run3 | UNIT_SPELLCAST_DELAYED | UNIT_SPELLCAST_SUCCEEDED | player | 2 | 1.497 | 1.497 | 1.497 | True |
| run3 | UNIT_SPELLCAST_DELAYED | UNIT_SPELLCAST_STOP | player | 2 | 1.497 | 1.497 | 1.497 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | 4007 | 8 | 2.477 | 2.434 | 2.515 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | 4007 | 8 | 2.477 | 2.434 | 2.515 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | player | 4 | 1.510 | 1.499 | 1.521 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | player | 4 | 1.510 | 1.499 | 1.521 | True |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | 4119 | 3 | 3.500 | 3.437 | 3.542 | True |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | player | 8 | 1.459 | 1.417 | 1.583 | False |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | player | 8 | 1.459 | 1.417 | 1.583 | False |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | 4119 | 4 | 3.469 | 1.458 | 3.542 | False |

## Higher-order leads (v2.2.5)

Chains A->B->C (depth <= 4), sequences/timing, identity joins (multi-token same-frame), and elimination (my casts + meter totals subtracted from what is seen). Each row is plain-words reasoning plus a **proposed** live HSM rule (review only -- not auto-enabled). Holdout = re-score on the other captures; provisional = one fight.

| # | capture | pattern | depth | hops | support | prec | lift | flags | holdout |
|---|---|---|---|---|---|---|---|---|---|
| 1 | run3 | chain | 3 | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=7` -> `UNIT_HEALTH|player` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED` -> `SWING_DAMAGE|npc>me` | 46/47 | 0.979 | 46.6 | chain | run4:held; run5:held |
| 2 | run3 | chain | 3 | `DAMAGE_METER_COMBAT_SESSION_UPDATED` -> `UNIT_HEALTH|player` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED` -> `SWING_DAMAGE|npc>me` | 48/76 | 0.632 | 40.22 | chain | run4:held; run5:failed |
| 3 | run3 | chain | 2 | `UNIT_HEALTH|player` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED` -> `SWING_DAMAGE|npc>me` | 48/93 | 0.516 | 29.17 | chain | run4:held; run5:held |
| 4 | run3 | chain | 2 | `UNIT_HEALTH|player` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED` -> `SWING_DAMAGE_LANDED|npc>me` | 48/93 | 0.516 | 29.17 | chain | run4:held; run5:held |
| 5 | run3 | chain | 2 | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `UNIT_HEAL_PREDICTION|player` -> `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 25/28 | 0.893 | 43.67 | chain | run4:held; run5:held |
| 6 | run3 | chain | 2 | `UNIT_COMBAT|player|arg1=HEAL` -> `UNIT_HEAL_PREDICTION|player` -> `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 25/31 | 0.806 | 43.66 | chain | run4:held; run5:held |
| 7 | run3 | chain | 2 | `UNIT_COMBAT|player|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 25/31 | 0.806 | 43.66 | chain | run4:held; run5:held |
| 8 | run3 | chain | 2 | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `UNIT_HEAL_PREDICTION|player` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 24/28 | 0.857 | 45.2 | chain | run4:held; run5:held |
| 9 | run3 | chain | 2 | `UNIT_COMBAT|player|arg3=6` -> `UNIT_HEAL_PREDICTION|player` -> `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 24/29 | 0.828 | 45.34 | chain | run4:held; run5:absent |
| 10 | run3 | chain | 2 | `UNIT_COMBAT|player|arg3=6` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 24/29 | 0.828 | 45.34 | chain | run4:held; run5:absent |
| 11 | run3 | chain | 2 | `UNIT_COMBAT|player|arg1=HEAL` -> `UNIT_HEAL_PREDICTION|player` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 24/31 | 0.774 | 45.33 | chain | run4:held; run5:held |
| 12 | run3 | chain | 2 | `UNIT_COMBAT|player|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 24/31 | 0.774 | 45.33 | chain | run4:held; run5:held |
| 13 | run3 | chain | 2 | `UNIT_COMBAT|player|arg3=6` -> `UNIT_HEAL_PREDICTION|player` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 23/29 | 0.793 | 46.99 | chain | run4:held; run5:absent |
| 14 | run3 | chain | 2 | `UNIT_COMBAT|player|arg3=6` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 23/29 | 0.793 | 46.99 | chain | run4:held; run5:absent |
| 15 | run3 | sequence | 1 | `SPELL_UPDATE_COOLDOWN` -> `UNIT_SPELLCAST_SENT|player` | 16/20 | 0.8 | 26.36 | sequence | run4:held; run5:held |
| 16 | run3 | chain | 2 | `UNIT_HEALTH|player` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 25/93 | 0.269 | 14.23 | chain | run4:held; run5:held |
| 17 | run3 | sequence | 1 | `SPELL_UPDATE_COOLDOWN` -> `UNIT_SPELLCAST_SUCCEEDED|player` | 15/20 | 0.75 | 23.27 | sequence | run4:held; run5:held |
| 18 | run3 | chain | 2 | `UNIT_HEALTH|player` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 24/93 | 0.258 | 14.33 | chain | run4:held; run5:held |
| 19 | run3 | sequence | 1 | `UNIT_SPELLCAST_START` -> `UNIT_SPELLCAST_DELAYED` | 2/2 | 1.0 | 5.0 | provisional,sequence | run4:absent; run5:absent |
| 20 | run3 | sequence | 1 | `UNIT_SPELLCAST_START` -> `UNIT_SPELLCAST_SUCCEEDED` | 2/2 | 1.0 | 5.0 | provisional,sequence | run4:absent; run5:absent |
| 21 | run3 | sequence | 1 | `UNIT_SPELLCAST_START` -> `UNIT_SPELLCAST_STOP` | 2/2 | 1.0 | 5.0 | provisional,sequence | run4:absent; run5:absent |
| 22 | run3 | sequence | 1 | `UNIT_SPELLCAST_DELAYED` -> `UNIT_SPELLCAST_SUCCEEDED` | 2/2 | 1.0 | 5.0 | provisional,sequence | run4:absent; run5:absent |
| 23 | run3 | sequence | 1 | `UNIT_SPELLCAST_DELAYED` -> `UNIT_SPELLCAST_STOP` | 2/2 | 1.0 | 5.0 | provisional,sequence | run4:absent; run5:absent |
| 24 | run3 | sequence | 1 | `SPELL_UPDATE_COOLDOWN` -> `PLAYER_TOTEM_UPDATE` | 10/20 | 0.5 | 14.83 | sequence | run4:held; run5:failed |
| 25 | run3 | chain | 2 | `SPELL_UPDATE_COOLDOWN` -> `PLAYER_TOTEM_UPDATE` -> `SPELL_CAST_SUCCESS|me>none` | 8/20 | 0.4 | 12.76 | chain | run4:held; run5:held |
| 26 | run3 | chain | 2 | `SPELL_UPDATE_COOLDOWN` -> `PLAYER_TOTEM_UPDATE` -> `SPELL_SUMMON|me>mine` | 8/20 | 0.4 | 12.76 | chain | run4:held; run5:failed |
| 27 | run3 | chain | 3 | `SPELL_UPDATE_COOLDOWN` -> `PLAYER_TOTEM_UPDATE` -> `SPELL_ACTIVATION_OVERLAY_HIDE` -> `SPELL_CAST_SUCCESS|me>none` | 8/20 | 0.4 | 12.76 | chain | run4:held; run5:failed |
| 28 | run3 | chain | 3 | `SPELL_UPDATE_COOLDOWN` -> `PLAYER_TOTEM_UPDATE` -> `SPELL_ACTIVATION_OVERLAY_HIDE` -> `SPELL_SUMMON|me>mine` | 8/20 | 0.4 | 12.76 | chain | run4:held; run5:failed |
| 29 | run3 | chain | 3 | `SPELL_UPDATE_COOLDOWN` -> `PLAYER_TOTEM_UPDATE` -> `UNIT_SPELLCAST_SENT|player` -> `SPELL_SUMMON|me>mine` | 8/20 | 0.4 | 12.76 | chain | run4:held; run5:failed |
| 30 | run3 | chain | 3 | `SPELL_UPDATE_COOLDOWN` -> `PLAYER_TOTEM_UPDATE` -> `UNIT_SPELLCAST_SENT|player` -> `SPELL_CAST_SUCCESS|me>none` | 8/20 | 0.4 | 12.76 | chain | run4:held; run5:held |

### Reasoning and proposed rules

**1. [run3 / chain]** DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=7 links via UNIT_HEALTH / player -> DAMAGE_METER_COMBAT_SESSION_UPDATED to ground truth SWING_DAMAGE / npc>me (end-to-end precision 0.979, lift 46.5 vs shuffled-time null)

> proposed: Chain: on DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=7, look for UNIT_HEALTH / player / DAMAGE_METER_COMBAT_SESSION_UPDATED within the hop windows, then treat SWING_DAMAGE / npc>me as the meaning (proposed only -- enable after holdout review).

**2. [run3 / chain]** DAMAGE_METER_COMBAT_SESSION_UPDATED links via UNIT_HEALTH / player -> DAMAGE_METER_COMBAT_SESSION_UPDATED to ground truth SWING_DAMAGE / npc>me (end-to-end precision 0.632, lift 40.14 vs shuffled-time null)

> proposed: Chain: on DAMAGE_METER_COMBAT_SESSION_UPDATED, look for UNIT_HEALTH / player / DAMAGE_METER_COMBAT_SESSION_UPDATED within the hop windows, then treat SWING_DAMAGE / npc>me as the meaning (proposed only -- enable after holdout review).

**3. [run3 / chain]** UNIT_HEALTH / player links via DAMAGE_METER_COMBAT_SESSION_UPDATED to ground truth SWING_DAMAGE / npc>me (end-to-end precision 0.516, lift 29.1 vs shuffled-time null)

> proposed: Chain: on UNIT_HEALTH / player, look for DAMAGE_METER_COMBAT_SESSION_UPDATED within the hop windows, then treat SWING_DAMAGE / npc>me as the meaning (proposed only -- enable after holdout review).

**4. [run3 / chain]** UNIT_HEALTH / player links via DAMAGE_METER_COMBAT_SESSION_UPDATED to ground truth SWING_DAMAGE_LANDED / npc>me (end-to-end precision 0.516, lift 29.1 vs shuffled-time null)

> proposed: Chain: on UNIT_HEALTH / player, look for DAMAGE_METER_COMBAT_SESSION_UPDATED within the hop windows, then treat SWING_DAMAGE_LANDED / npc>me as the meaning (proposed only -- enable after holdout review).

**5. [run3 / chain]** DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2 links via UNIT_HEAL_PREDICTION / player to ground truth SPELL_PERIODIC_HEAL / mine>me / spell=6371 (end-to-end precision 0.893, lift 43.71 vs shuffled-time null)

> proposed: Chain: on DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2, look for UNIT_HEAL_PREDICTION / player within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>me / spell=6371 as the meaning (proposed only -- enable after holdout review).

**6. [run3 / chain]** UNIT_COMBAT / player / arg1=HEAL links via UNIT_HEAL_PREDICTION / player to ground truth SPELL_PERIODIC_HEAL / mine>me / spell=6371 (end-to-end precision 0.806, lift 43.71 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg1=HEAL, look for UNIT_HEAL_PREDICTION / player within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>me / spell=6371 as the meaning (proposed only -- enable after holdout review).

**7. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**8. [run3 / chain]** DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2 links via UNIT_HEAL_PREDICTION / player to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.857, lift 45.23 vs shuffled-time null)

> proposed: Chain: on DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2, look for UNIT_HEAL_PREDICTION / player within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**9. [run3 / chain]** UNIT_COMBAT / player / arg3=6 links via UNIT_HEAL_PREDICTION / player to ground truth SPELL_PERIODIC_HEAL / mine>me / spell=6371 (end-to-end precision 0.828, lift 45.23 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg3=6, look for UNIT_HEAL_PREDICTION / player within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>me / spell=6371 as the meaning (proposed only -- enable after holdout review).

**10. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**11. [run3 / chain]** UNIT_COMBAT / player / arg1=HEAL links via UNIT_HEAL_PREDICTION / player to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.774, lift 45.23 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg1=HEAL, look for UNIT_HEAL_PREDICTION / player within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**12. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**13. [run3 / chain]** UNIT_COMBAT / player / arg3=6 links via UNIT_HEAL_PREDICTION / player to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.793, lift 47.0 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg3=6, look for UNIT_HEAL_PREDICTION / player within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**14. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**15. [run3 / sequence]** ordered timing: SPELL_UPDATE_COOLDOWN then UNIT_SPELLCAST_SENT / player within 300 ms (learned lag median 0.054 s)

> proposed: Sequence: watch SPELL_UPDATE_COOLDOWN; expect UNIT_SPELLCAST_SENT / player within 300 ms (or treat absence as the opposite signal).

**16. [run3 / chain]** UNIT_HEALTH / player links via DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2 to ground truth SPELL_PERIODIC_HEAL / mine>me / spell=6371 (end-to-end precision 0.269, lift 14.23 vs shuffled-time null)

> proposed: Chain: on UNIT_HEALTH / player, look for DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2 within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>me / spell=6371 as the meaning (proposed only -- enable after holdout review).

**17. [run3 / sequence]** ordered timing: SPELL_UPDATE_COOLDOWN then UNIT_SPELLCAST_SUCCEEDED / player within 300 ms (learned lag median 0.000 s)

> proposed: Sequence: watch SPELL_UPDATE_COOLDOWN; expect UNIT_SPELLCAST_SUCCEEDED / player within 300 ms (or treat absence as the opposite signal).

**18. [run3 / chain]** UNIT_HEALTH / player links via DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2 to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.258, lift 14.34 vs shuffled-time null)

> proposed: Chain: on UNIT_HEALTH / player, look for DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2 within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**19. [run3 / sequence]** ordered timing: UNIT_SPELLCAST_START then UNIT_SPELLCAST_DELAYED within 332 ms (learned lag median 0.221 s)

> proposed: Sequence: watch UNIT_SPELLCAST_START; expect UNIT_SPELLCAST_DELAYED within 332 ms (or treat absence as the opposite signal).

**20. [run3 / sequence]** ordered timing: UNIT_SPELLCAST_START then UNIT_SPELLCAST_SUCCEEDED within 1500 ms (learned lag median 1.718 s)

> proposed: Sequence: watch UNIT_SPELLCAST_START; expect UNIT_SPELLCAST_SUCCEEDED within 1500 ms (or treat absence as the opposite signal).

**21. [run3 / sequence]** ordered timing: UNIT_SPELLCAST_START then UNIT_SPELLCAST_STOP within 1500 ms (learned lag median 1.718 s)

> proposed: Sequence: watch UNIT_SPELLCAST_START; expect UNIT_SPELLCAST_STOP within 1500 ms (or treat absence as the opposite signal).

**22. [run3 / sequence]** ordered timing: UNIT_SPELLCAST_DELAYED then UNIT_SPELLCAST_SUCCEEDED within 1500 ms (learned lag median 1.497 s)

> proposed: Sequence: watch UNIT_SPELLCAST_DELAYED; expect UNIT_SPELLCAST_SUCCEEDED within 1500 ms (or treat absence as the opposite signal).

**23. [run3 / sequence]** ordered timing: UNIT_SPELLCAST_DELAYED then UNIT_SPELLCAST_STOP within 1500 ms (learned lag median 1.497 s)

> proposed: Sequence: watch UNIT_SPELLCAST_DELAYED; expect UNIT_SPELLCAST_STOP within 1500 ms (or treat absence as the opposite signal).

**24. [run3 / sequence]** ordered timing: SPELL_UPDATE_COOLDOWN then PLAYER_TOTEM_UPDATE within 300 ms (learned lag median 0.000 s)

> proposed: Sequence: watch SPELL_UPDATE_COOLDOWN; expect PLAYER_TOTEM_UPDATE within 300 ms (or treat absence as the opposite signal).

**25. [run3 / chain]** SPELL_UPDATE_COOLDOWN links via PLAYER_TOTEM_UPDATE to ground truth SPELL_CAST_SUCCESS / me>none (end-to-end precision 0.4, lift 12.75 vs shuffled-time null)

> proposed: Chain: on SPELL_UPDATE_COOLDOWN, look for PLAYER_TOTEM_UPDATE within the hop windows, then treat SPELL_CAST_SUCCESS / me>none as the meaning (proposed only -- enable after holdout review).

**26. [run3 / chain]** SPELL_UPDATE_COOLDOWN links via PLAYER_TOTEM_UPDATE to ground truth SPELL_SUMMON / me>mine (end-to-end precision 0.4, lift 12.75 vs shuffled-time null)

> proposed: Chain: on SPELL_UPDATE_COOLDOWN, look for PLAYER_TOTEM_UPDATE within the hop windows, then treat SPELL_SUMMON / me>mine as the meaning (proposed only -- enable after holdout review).

**27. [run3 / chain]** SPELL_UPDATE_COOLDOWN links via PLAYER_TOTEM_UPDATE -> SPELL_ACTIVATION_OVERLAY_HIDE to ground truth SPELL_CAST_SUCCESS / me>none (end-to-end precision 0.4, lift 12.75 vs shuffled-time null)

> proposed: Chain: on SPELL_UPDATE_COOLDOWN, look for PLAYER_TOTEM_UPDATE / SPELL_ACTIVATION_OVERLAY_HIDE within the hop windows, then treat SPELL_CAST_SUCCESS / me>none as the meaning (proposed only -- enable after holdout review).

**28. [run3 / chain]** SPELL_UPDATE_COOLDOWN links via PLAYER_TOTEM_UPDATE -> SPELL_ACTIVATION_OVERLAY_HIDE to ground truth SPELL_SUMMON / me>mine (end-to-end precision 0.4, lift 12.75 vs shuffled-time null)

> proposed: Chain: on SPELL_UPDATE_COOLDOWN, look for PLAYER_TOTEM_UPDATE / SPELL_ACTIVATION_OVERLAY_HIDE within the hop windows, then treat SPELL_SUMMON / me>mine as the meaning (proposed only -- enable after holdout review).

**29. [run3 / chain]** SPELL_UPDATE_COOLDOWN links via PLAYER_TOTEM_UPDATE -> UNIT_SPELLCAST_SENT / player to ground truth SPELL_SUMMON / me>mine (end-to-end precision 0.4, lift 12.75 vs shuffled-time null)

> proposed: Chain: on SPELL_UPDATE_COOLDOWN, look for PLAYER_TOTEM_UPDATE / UNIT_SPELLCAST_SENT / player within the hop windows, then treat SPELL_SUMMON / me>mine as the meaning (proposed only -- enable after holdout review).

**30. [run3 / chain]** SPELL_UPDATE_COOLDOWN links via PLAYER_TOTEM_UPDATE -> UNIT_SPELLCAST_SENT / player to ground truth SPELL_CAST_SUCCESS / me>none (end-to-end precision 0.4, lift 12.75 vs shuffled-time null)

> proposed: Chain: on SPELL_UPDATE_COOLDOWN, look for PLAYER_TOTEM_UPDATE / UNIT_SPELLCAST_SENT / player within the hop windows, then treat SPELL_CAST_SUCCESS / me>none as the meaning (proposed only -- enable after holdout review).


_Elapsed: mine 13.346s, higher-order 3.896s, total 17.41s (profile full)._

