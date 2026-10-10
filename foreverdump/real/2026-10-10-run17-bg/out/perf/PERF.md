# PERF: ForeverDump self-performance

Source: perf (addon 2.2.21). Rule (PERFORMANCE.md): <1% of wall time, cost per call flat over the session, bounded tables.

## Capture 1 (cap-20261009235202-71, v2.2.21)

- 1270 s, 859702 handler calls, 31339.4 ms total = **2.4668%** of wall time
- flags: impact 2.47% of wall time >= 2%; WorldCapture.Slice: mean 0.1302 ms per slice > budget 0.10 ms (real client, 6084 slices); size hsm.inferences still growing at the end (6 -> 10924); size hsm.predictions still growing at the end (0 -> 164)

| handler | calls | total ms | mean ms | max ms | first-third mean | last-third mean | grows |
|---|---|---|---|---|---|---|---|
| Recorder.onEvent | 244840 | 7806.42 | 0.0319 | 7.14 | 0.0316 | 0.033 | no |
| OocFill.step | 6084 | 4794.67 | 0.7881 | 10.58 | 0.7931 | 0.7615 | no |
| Derive.DAMAGE_METER_COMBAT_SESSION_UPDATED | 77132 | 2667.15 | 0.0346 | 18.52 | 0.0276 | 0.0464 | no |
| DamageMeter.struct | 10247 | 2391.01 | 0.2333 | 7.92 | 0.1973 | 0.2773 | no |
| CombatLog.onEvent | 118800 | 1818.28 | 0.0153 | 3.22 | 0.015 | 0.0159 | no |
| DamageMeter.DAMAGE_METER_COMBAT_SESSION_UPDATED | 77132 | 1500.41 | 0.0195 | 0.33 | 0.0191 | 0.0201 | no |
| TokenScan.Slice | 12168 | 1173.97 | 0.0965 | 0.43 | 0.0955 | 0.0975 | no |
| Identity.poll | 1269 | 1066.78 | 0.8406 | 2.50 | 0.8365 | 0.7626 | no |
| Inference.UNIT_COMBAT | 10929 | 1011.41 | 0.0925 | 1.56 | 0.0926 | 0.0965 | no |
| WorldCapture.Slice | 6084 | 792.16 | 0.1302 | 7.15 | 0.1288 | 0.1273 | no |
| Derive.tick | 423 | 669.52 | 1.5828 | 6.46 | 1.5672 | 1.3917 | no |
| Lab.dmSnap | 3111 | 570.96 | 0.1835 | 10.40 | 0.1801 | 0.2204 | no |
| CombatProbe.UNIT_AURA | 10325 | 403.73 | 0.0391 | 0.33 | 0.0378 | 0.0406 | no |
| Derive.UPDATE_BATTLEFIELD_SCORE | 137 | 376.87 | 2.7508 | 4.88 | 2.7814 | 2.7891 | no |
| OocFill.UPDATE_BATTLEFIELD_SCORE | 137 | 360.51 | 2.6315 | 6.01 | 2.5815 | 2.7919 | no |
| Inference.UNIT_AURA | 10325 | 255.24 | 0.0247 | 1.71 | 0.0243 | 0.0225 | no |
| CombatProbe.UNIT_HEALTH | 12752 | 254.91 | 0.0200 | 0.22 | 0.0193 | 0.0211 | no |
| CombatProbe.Run | 180 | 254.66 | 1.4148 | 11.27 | 1.6524 | 1.148 | no |
| Lab.DAMAGE_METER_COMBAT_SESSION_UPDATED | 77132 | 248.05 | 0.0032 | 0.20 | 0.0032 | 0.0033 | no |
| Derive.UNIT_POWER_FREQUENT | 46164 | 235.19 | 0.0051 | 0.17 | 0.0054 | 0.004 | no |
| HSM.Census | 1269 | 205.33 | 0.1618 | 0.67 | 0.1722 | 0.1544 | no |
| Identity.UNIT_TARGET | 3501 | 197.69 | 0.0565 | 0.72 | 0.0464 | 0.0566 | no |
| Inference.UNIT_HEALTH | 12752 | 188.48 | 0.0148 | 0.10 | 0.0145 | 0.0153 | no |
| Lab.UNIT_AURA | 10325 | 187.77 | 0.0182 | 0.25 | 0.0171 | 0.0193 | no |
| Derive.meterOoc | 24 | 118.72 | 4.9468 | 7.33 |  |  | n/a |

Samples (255): heapKB 193967 -> 603995 (min 193967, max 691900); fps 48 -> 47.8 (min 18, max 48.2); app 20.483 -> 20.483 (min 20.483, max 122.917); all 0.015 -> 0.009 (min 0.008, max 0.156); own 0.003 -> 0.002 (min 0.002, max 0.028); ownPeak 263.465 -> 263.465 (min 263.465, max 263.465)

Table sizes: hsm.inferences 6 -> 10924 (still growing); hsm.predictions 0 -> 164 (still growing); hsm.units 2 -> 1; identity.state 35 -> 53; inference.signals 9 -> 15578 (still growing, capped at 250000); ledger.aura 0 -> 0; ledger.cast 0 -> 1; ledger.fingerprint 1 -> 7 (still growing, capped at 375); ledger.guid 20 -> 58 (still growing, capped at 375); ledger.plate 0 -> 0; ledger.token 35 -> 51 (still growing, capped at 80); verify.ring 4 -> 7868 (still growing, capped at 250000); verify.unexpected 1 -> 17 (still growing, capped at 216)

Own PeakTime marks (v2.2.16): load:begin 241.063; load:svunpack 241.063; load:initdb 241.063; login:begin 241.063; login:handlers 241.063; capture:begin 263.465; start:self-perf monitor 263.465; start:replay log (session_hdr + tape) 263.465; start:combat probe set 263.465; start:unit token survey 263.465; start:group-aware token scanner 263.465; start:container schema 263.465; start:spell knowledge + HSM inference 263.465; start:damage meter evidence (C_DamageMeter) 263.465; start:identity ledger (token/GUID correlation) 263.465; start:live verification loop 263.465; start:world-state capture (casts/auras/hp/threat/range/target-of) 263.465; start:learned spell / NPC / class DB 263.465; start:lab probes (capture level lab) 263.465; start:derivation lab (capture level lab) 263.465; start:ooc fill + unit-token sweep (capture level lab) 263.465; start:HSM window 263.465
All-time peak 263.465 ms set between `login:handlers` and `capture:begin`.

## Profile snapshots (capture:on vs capture:off)

C_AddOnProfiler and memory at the start and end of each FD_Logs capture. Per-addon counters undercount time spent in an addon's OnUpdate/timers on this client; the application frame time is the reliable signal.

- 1270 s capture: application RecentAverageTime 20.5 -> 20.5 ms, PeakTime 1084.0 -> 1084.0
- flags: ForeverDump memory +346.7 MB during the capture

| addon | memory KB | session avg ms | recent avg ms | +frames >1 ms | >10 ms | >50 ms |
|---|---|---|---|---|---|---|
| ForeverDump | 7146.0 -> 362117.0 | 0.108 -> 0.0236 | 0.0034 -> 0.0022 | 22 | 1 | 0 |
| KTH_ForeverDiag | 50.0 -> 1259.0 | 0.0215 -> 0.0256 | 0.0116 -> 0.007 | 141 | 2 | 0 |
| KTH | 1040.0 -> 1048.0 | 0.0054 -> 0.0012 | 0.0004 -> 0 | 0 | 0 | 0 |

