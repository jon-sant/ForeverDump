# PERF: ForeverDump self-performance

Source: perf (addon 2.2.21). Rule (PERFORMANCE.md): <1% of wall time, cost per call flat over the session, bounded tables.

## Capture 1 (cap-20261009225225-51, v2.2.21)

- 1065 s, 651156 handler calls, 22482.6 ms total = **2.1106%** of wall time
- flags: impact 2.11% of wall time >= 2%; WorldCapture.Slice: mean 0.1271 ms per slice > budget 0.10 ms (real client, 5102 slices); Containers.Run: cost per call grows 0.1216 -> 0.2568 ms (x2.11) over the session; size hsm.inferences still growing at the end (4 -> 9801); size hsm.predictions still growing at the end (0 -> 161)

| handler | calls | total ms | mean ms | max ms | first-third mean | last-third mean | grows |
|---|---|---|---|---|---|---|---|
| Recorder.onEvent | 193860 | 5857.54 | 0.0302 | 3.30 | 0.0314 | 0.0291 | no |
| OocFill.step | 5102 | 3386.51 | 0.6638 | 11.58 | 0.7159 | 0.6437 | no |
| DamageMeter.struct | 7489 | 1402.78 | 0.1873 | 7.97 | 0.1702 | 0.18 | no |
| Derive.DAMAGE_METER_COMBAT_SESSION_UPDATED | 51270 | 1317.82 | 0.0257 | 8.18 | 0.0189 | 0.0272 | no |
| CombatLog.onEvent | 85779 | 1250.64 | 0.0146 | 8.65 | 0.0147 | 0.0143 | no |
| TokenScan.Slice | 10200 | 989.78 | 0.0970 | 0.32 | 0.0981 | 0.0961 | no |
| DamageMeter.DAMAGE_METER_COMBAT_SESSION_UPDATED | 51270 | 923.78 | 0.0180 | 0.29 | 0.0182 | 0.0176 | no |
| Inference.UNIT_COMBAT | 10553 | 890.90 | 0.0844 | 4.97 | 0.0884 | 0.0791 | no |
| Identity.poll | 1060 | 868.53 | 0.8194 | 2.98 | 0.9082 | 0.7692 | no |
| Derive.tick | 354 | 810.23 | 2.2888 | 6.99 | 2.3729 | 2.3476 | no |
| WorldCapture.Slice | 5102 | 648.44 | 0.1271 | 0.65 | 0.1288 | 0.1262 | no |
| Lab.dmSnap | 2316 | 318.50 | 0.1375 | 1.82 | 0.1262 | 0.117 | no |
| CombatProbe.UNIT_AURA | 8668 | 297.27 | 0.0343 | 0.21 | 0.0354 | 0.0323 | no |
| CombatProbe.Run | 231 | 253.07 | 1.0955 | 6.11 | 1.4009 | 0.4947 | no |
| Derive.UNIT_POWER_FREQUENT | 38383 | 242.66 | 0.0063 | 0.14 | 0.008 | 0.0058 | no |
| Inference.UNIT_AURA | 8668 | 218.73 | 0.0252 | 0.40 | 0.026 | 0.0252 | no |
| CombatProbe.UNIT_HEALTH | 10336 | 192.76 | 0.0186 | 0.22 | 0.0187 | 0.0184 | no |
| HSM.Census | 1064 | 182.87 | 0.1719 | 0.85 | 0.1915 | 0.1597 | no |
| Lab.DAMAGE_METER_COMBAT_SESSION_UPDATED | 51270 | 156.66 | 0.0031 | 0.10 | 0.0032 | 0.0029 | no |
| Lab.UNIT_AURA | 8668 | 152.65 | 0.0176 | 0.21 | 0.018 | 0.0169 | no |
| Inference.UNIT_HEALTH | 10336 | 147.59 | 0.0143 | 0.24 | 0.0147 | 0.0139 | no |
| OocFill.UPDATE_BATTLEFIELD_SCORE | 54 | 143.21 | 2.6519 | 5.22 |  |  | n/a |
| Lab.sample | 2128 | 130.66 | 0.0614 | 0.42 | 0.0567 | 0.0643 | no |
| Identity.UNIT_TARGET | 2519 | 122.41 | 0.0486 | 1.06 | 0.0534 | 0.0473 | no |
| Derive.meterOoc | 28 | 107.64 | 3.8443 | 6.33 |  |  | n/a |

Samples (214): heapKB 331932 -> 588965 (min 202757, max 591410); fps 48 -> 23.6 (min 23.6, max 48.2); app 20.5 -> 106 (min 20.483, max 106); all 0.008 -> 0.008 (min 0.006, max 0.845); own 0.008 -> 0.008 (min 0.006, max 0.845); ownPeak 1.096 -> 13.072 (min 1.096, max 13.072)

Table sizes: hsm.inferences 4 -> 9801 (still growing); hsm.predictions 0 -> 161 (still growing); hsm.units 1 -> 2; identity.state 23 -> 46; inference.signals 6 -> 14309 (still growing, capped at 250000); ledger.aura 0 -> 0; ledger.cast 0 -> 2; ledger.fingerprint 1 -> 18 (still growing, capped at 375); ledger.guid 13 -> 17 (still growing, capped at 375); ledger.plate 0 -> 0; ledger.token 23 -> 44; verify.ring 6 -> 8330 (still growing, capped at 250000); verify.unexpected 0 -> 20 (still growing, capped at 216)

Own PeakTime marks (v2.2.16): load:begin 0; load:svunpack 0; load:initdb 0; login:begin 0; login:handlers 0; capture:begin 1.096; start:self-perf monitor 1.096; start:replay log (session_hdr + tape) 1.096; start:combat probe set 1.096; start:unit token survey 1.096; start:group-aware token scanner 1.096; start:container schema 1.096; start:spell knowledge + HSM inference 1.096; start:damage meter evidence (C_DamageMeter) 1.096; start:identity ledger (token/GUID correlation) 1.096; start:live verification loop 1.096; start:world-state capture (casts/auras/hp/threat/range/target-of) 1.096; start:learned spell / NPC / class DB 1.096; start:lab probes (capture level lab) 1.096; start:derivation lab (capture level lab) 1.096; start:ooc fill + unit-token sweep (capture level lab) 1.096; start:HSM window 1.096
All-time peak 1.096 ms set between `login:handlers` and `capture:begin`.

## Profile snapshots (capture:on vs capture:off)

C_AddOnProfiler and memory at the start and end of each FD_Logs capture. Per-addon counters undercount time spent in an addon's OnUpdate/timers on this client; the application frame time is the reliable signal.

- 1065 s capture: application RecentAverageTime 20.5 -> 106 ms, PeakTime 1564.0 -> 1564.0
- flags: application frame time rose x5.2 during the capture (20.5 -> 106.0 ms/frame); ForeverDump memory +286.7 MB during the capture

| addon | memory KB | session avg ms | recent avg ms | +frames >1 ms | >10 ms | >50 ms |
|---|---|---|---|---|---|---|
| ForeverDump | 14257.0 -> 307876.0 | 0.0067 -> 0.0089 | 0.0081 -> 0.0085 | 24 | 1 | 0 |

