# PERF: ForeverDump self-performance

Source: perf (addon 2.2.3). Rule (PERFORMANCE.md): <1% of wall time, cost per call flat over the session, bounded tables.

## Capture 1 (cap-20261008000120-1, v2.2.3)

- 151 s, 6656 handler calls, 279.9 ms total = **0.1852%** of wall time
- flags: none (flat per-call cost, under 1%)

| handler | calls | total ms | mean ms | max ms | first-third mean | last-third mean | grows |
|---|---|---|---|---|---|---|---|
| Recorder.onEvent | 4226 | 160.52 | 0.0380 | 0.33 | 0.048 | 0.0387 | no |
| HSMUI.Step | 481 | 44.94 | 0.0934 | 1.11 | 0.079 | 0.0878 | no |
| CombatProbe.Run | 21 | 32.07 | 1.5270 | 7.25 |  |  | n/a |
| CombatLog.onEvent | 1143 | 12.87 | 0.0113 | 0.09 | 0.0185 | 0.0115 | no |
| Inference.UNIT_AURA | 56 | 5.25 | 0.0937 | 0.60 |  |  | n/a |
| CombatProbe.UNIT_HEALTH | 216 | 3.90 | 0.0180 | 0.06 | 0.0184 | 0.0193 | no |
| HSM.Tick | 151 | 3.15 | 0.0209 | 0.04 | 0.0125 | 0.0288 | no |
| core.ADDON_RESTRICTION_STATE_CHANGED | 12 | 2.83 | 0.2355 | 0.63 |  |  | n/a |
| Containers.Run | 12 | 2.72 | 0.2268 | 2.13 |  |  | n/a |
| CombatProbe.UNIT_AURA | 56 | 2.16 | 0.0386 | 0.09 |  |  | n/a |
| Inference.UNIT_SPELLCAST_SUCCEEDED | 48 | 1.86 | 0.0388 | 0.19 |  |  | n/a |
| CombatProbe.UNIT_SPELLCAST_START | 16 | 1.54 | 0.0964 | 0.37 |  |  | n/a |
| Perf.sample | 30 | 1.47 | 0.0489 | 0.18 |  |  | n/a |
| CombatProbe.UNIT_SPELLCAST_SUCCEEDED | 48 | 1.46 | 0.0303 | 0.10 |  |  | n/a |
| Inference.UNIT_SPELLCAST_START | 16 | 0.42 | 0.0265 | 0.05 |  |  | n/a |
| Inference.PLAYER_TOTEM_UPDATE | 9 | 0.40 | 0.0444 | 0.07 |  |  | n/a |
| core.PLAYER_REGEN_DISABLED | 21 | 0.39 | 0.0187 | 0.13 |  |  | n/a |
| CombatProbe.UNIT_SPELLCAST_STOP | 18 | 0.38 | 0.0211 | 0.03 |  |  | n/a |
| core.PLAYER_REGEN_ENABLED | 6 | 0.31 | 0.0519 | 0.11 |  |  | n/a |
| Inference.UNIT_SPELLCAST_STOP | 18 | 0.28 | 0.0158 | 0.03 |  |  | n/a |
| core.PLAYER_IN_COMBAT_CHANGED | 6 | 0.21 | 0.0345 | 0.06 |  |  | n/a |
| CombatProbe.UNIT_SPELLCAST_FAILED | 8 | 0.15 | 0.0187 | 0.02 |  |  | n/a |
| Inference.PLAYER_TARGET_CHANGED | 12 | 0.15 | 0.0123 | 0.02 |  |  | n/a |
| Inference.UNIT_SPELLCAST_FAILED | 8 | 0.14 | 0.0171 | 0.04 |  |  | n/a |
| CombatProbe.UNIT_SPELLCAST_INTERRUPTED | 3 | 0.12 | 0.0393 | 0.05 |  |  | n/a |

Samples (32): heapKB 314585 -> 351878 (min 295514, max 351878); fps 48 -> 48 (min 14.5, max 48); app 20.483 -> 20.5 (min 20.483, max 122.917); all 0.252 -> 0.201 (min 0.144, max 0.4); own 0 -> 0 (min 0, max 0.213); ownPeak 665.088 -> 665.088 (min 665.088, max 665.088)

Table sizes: hsm.inferences 0 -> 49 (still growing, capped at 2500); hsm.predictions 0 -> 25 (still growing, capped at 2500); hsm.units 0 -> 1; inference.signals 0 -> 130 (still growing, capped at 3000)

## Profile snapshots (capture:on vs capture:off)

C_AddOnProfiler and memory at the start and end of each FD_Logs capture. Per-addon counters undercount time spent in an addon's OnUpdate/timers on this client; the application frame time is the reliable signal.

- 151 s capture: application RecentAverageTime 20.5 -> 20.5 ms, PeakTime 6261 -> 6261
- flags: none

| addon | memory KB | session avg ms | recent avg ms | +frames >1 ms | >10 ms | >50 ms |
|---|---|---|---|---|---|---|
| ForeverDump | 75270.0 -> 67131.0 | 0.0289 -> 0.0282 | 0 -> 0 | 12 | 1 | 0 |
| QuestieDB | 24617.0 -> 24618.0 | 0 -> 0 | 0 -> 0 | 0 | 0 | 0 |
| Questie | 18191.0 -> 18438.0 | 0.2285 -> 0.2266 | 0.2374 -> 0.1861 | 0 | 0 | 0 |
| Auctionator | 5258.0 -> 5253.0 | 0.0006 -> 0.0006 | 0 -> 0 | 0 | 0 | 0 |
| TweaksForever | 1505.0 -> 1443.0 | 0.0047 -> 0.0046 | 0.0006 -> 0.0006 | 0 | 0 | 0 |
| ForeverDungeonJournal | 1441.0 -> 1440.0 | 0.0012 -> 0.0011 | 0 -> 0 | 0 | 0 | 0 |
| TomTom | 578.0 -> 579.0 | 0.0209 -> 0.0206 | 0.0142 -> 0.0141 | 0 | 0 | 0 |
| idTip | 68.0 -> 65.0 | 0 -> 0 | 0 -> 0 | 0 | 0 | 0 |
| QuestLevelPatch | 10.0 -> 8.0 | 0.0 -> 0.0 | 0 -> 0 | 0 | 0 | 0 |

