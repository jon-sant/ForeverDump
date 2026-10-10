# PERF: ForeverDump self-performance

Source: perf (addon 2.2.23). Rule (PERFORMANCE.md): <1% of wall time, cost per call flat over the session, bounded tables.

## Capture 1 (cap-20261010003729-81, v2.2.23)

- 1334 s, 796413 handler calls, 27108.0 ms total = **2.0328%** of wall time
- flags: impact 2.03% of wall time >= 2%; WorldCapture.Slice: mean 0.1271 ms per slice > budget 0.10 ms (real client, 6397 slices); size hsm.inferences still growing at the end (8 -> 10767); size hsm.predictions still growing at the end (0 -> 148)

| handler | calls | total ms | mean ms | max ms | first-third mean | last-third mean | grows |
|---|---|---|---|---|---|---|---|
| Recorder.onEvent | 224421 | 6848.04 | 0.0305 | 9.23 | 0.0305 | 0.0306 | no |
| OocFill.step | 6397 | 4564.94 | 0.7136 | 12.88 | 0.7174 | 0.7097 | no |
| DamageMeter.struct | 9957 | 1718.29 | 0.1726 | 5.01 | 0.1792 | 0.1774 | no |
| CombatLog.onEvent | 111495 | 1643.72 | 0.0147 | 8.75 | 0.0145 | 0.0151 | no |
| Derive.DAMAGE_METER_COMBAT_SESSION_UPDATED | 74160 | 1510.78 | 0.0204 | 8.75 | 0.0212 | 0.0238 | no |
| DamageMeter.DAMAGE_METER_COMBAT_SESSION_UPDATED | 74160 | 1337.89 | 0.0180 | 0.26 | 0.0179 | 0.0183 | no |
| TokenScan.Slice | 12792 | 1232.07 | 0.0963 | 0.28 | 0.0961 | 0.0961 | no |
| Identity.poll | 1332 | 1057.15 | 0.7937 | 4.58 | 0.8325 | 0.7735 | no |
| Inference.UNIT_COMBAT | 11412 | 958.99 | 0.0840 | 1.14 | 0.0822 | 0.0878 | no |
| WorldCapture.Slice | 6397 | 812.93 | 0.1271 | 3.00 | 0.1292 | 0.1259 | no |
| Derive.tick | 444 | 722.62 | 1.6275 | 3.73 | 1.6726 | 1.6353 | no |
| Derive.UPDATE_BATTLEFIELD_SCORE | 142 | 390.26 | 2.7483 | 6.25 | 3.3629 | 2.4101 | no |
| OocFill.UPDATE_BATTLEFIELD_SCORE | 142 | 382.74 | 2.6953 | 9.92 | 3.1742 | 2.3798 | no |
| CombatProbe.UNIT_AURA | 9160 | 324.46 | 0.0354 | 0.44 | 0.0367 | 0.0347 | no |
| Lab.dmSnap | 3047 | 275.38 | 0.0904 | 1.07 | 0.0939 | 0.0974 | no |
| CombatProbe.Run | 238 | 239.27 | 1.0053 | 4.93 | 1.4245 | 0.4309 | no |
| Inference.UNIT_AURA | 9160 | 236.40 | 0.0258 | 0.33 | 0.0292 | 0.0253 | no |
| CombatProbe.UNIT_HEALTH | 11583 | 222.37 | 0.0192 | 0.93 | 0.0185 | 0.0202 | no |
| Lab.DAMAGE_METER_COMBAT_SESSION_UPDATED | 74160 | 218.94 | 0.0030 | 0.14 | 0.003 | 0.003 | no |
| HSM.Census | 1332 | 208.36 | 0.1564 | 0.62 | 0.162 | 0.1478 | no |
| Derive.UNIT_POWER_FREQUENT | 40575 | 201.22 | 0.0050 | 0.13 | 0.005 | 0.0044 | no |
| Inference.UNIT_HEALTH | 11583 | 171.68 | 0.0148 | 0.14 | 0.0147 | 0.0149 | no |
| Lab.UNIT_AURA | 9160 | 133.22 | 0.0145 | 0.10 | 0.0145 | 0.0146 | no |
| Identity.UNIT_TARGET | 3285 | 126.91 | 0.0386 | 0.64 | 0.0429 | 0.037 | no |
| Lab.sample | 2665 | 123.89 | 0.0465 | 0.27 | 0.0416 | 0.0532 | no |

Samples (268): heapKB 194586 -> 601403 (min 194586, max 631232); fps 40.1 -> 46.9 (min 40.1, max 48.1); app 20.483 -> 20.833 (min 20.483, max 21.017); all 0.031 -> 0.016 (min 0.015, max 0.099); own 0.012 -> 0.003 (min 0.002, max 0.054); ownPeak 10423.091 -> 10423.091 (min 10423.091, max 10423.091)

Table sizes: hsm.inferences 8 -> 10767 (still growing); hsm.predictions 0 -> 148 (still growing); hsm.units 0 -> 2; identity.state 27 -> 49; inference.signals 10 -> 15093 (still growing, capped at 250000); ledger.aura 0 -> 0; ledger.cast 0 -> 1; ledger.fingerprint 1 -> 9 (still growing, capped at 375); ledger.guid 18 -> 45 (still growing, capped at 375); ledger.plate 0 -> 0; ledger.token 27 -> 48 (still growing, capped at 80); verify.ring 0 -> 7198 (still growing, capped at 250000); verify.unexpected 0 -> 12 (still growing, capped at 216)

Own PeakTime marks (v2.2.16): load:begin 10423.091; load:svunpack 10423.091; load:initdb 10423.091; login:begin 10423.091; login:handlers 10423.091; capture:begin 10423.091; start:self-perf monitor 10423.091; start:replay log (session_hdr + tape) 10423.091; start:combat probe set 10423.091; start:unit token survey 10423.091; start:group-aware token scanner 10423.091; start:container schema 10423.091; start:spell knowledge + HSM inference 10423.091; start:damage meter evidence (C_DamageMeter) 10423.091; start:identity ledger (token/GUID correlation) 10423.091; start:live verification loop 10423.091; start:world-state capture (casts/auras/hp/threat/range/target-of) 10423.091; start:learned spell / NPC / class DB 10423.091; start:lab probes (capture level lab) 10423.091; start:derivation lab (capture level lab) 10423.091; start:ooc fill + unit-token sweep (capture level lab) 10423.091; start:HSM window 10423.091
All-time peak 10423.091 ms set between `(addon load)` and `load:begin`.

## Profile snapshots (capture:on vs capture:off)

C_AddOnProfiler and memory at the start and end of each FD_Logs capture. Per-addon counters undercount time spent in an addon's OnUpdate/timers on this client; the application frame time is the reliable signal.

- 1334 s capture: application RecentAverageTime 20.5 -> 20.8 ms, PeakTime 1865.0 -> 1865.0
- flags: ForeverDump memory +351.3 MB during the capture

| addon | memory KB | session avg ms | recent avg ms | +frames >1 ms | >10 ms | >50 ms |
|---|---|---|---|---|---|---|
| ForeverDump | 8136.0 -> 367825.0 | 0.2793 -> 0.1803 | 0.0125 -> 0.0031 | 24 | 1 | 0 |
| KTH_ForeverDiag | 130.0 -> 2412.0 | 0.0182 -> 0.017 | 0.0056 -> 0.0045 | 143 | 0 | 0 |
| KTH | 1196.0 -> 2247.0 | 0.0026 -> 0.0076 | 0.0125 -> 0.0086 | 5 | 0 | 0 |

