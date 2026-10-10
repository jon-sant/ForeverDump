# PERF: ForeverDump self-performance

Source: perf (addon 2.2.25). Rule (PERFORMANCE.md): <1% of wall time, cost per call flat over the session, bounded tables.

## Capture 1 (cap-20261010102414-92, v2.2.25)

- 1025 s, 634623 handler calls, 24640.9 ms total = **2.4041%** of wall time
- flags: impact 2.40% of wall time >= 2%; WorldCapture.Slice: mean 0.1284 ms per slice > budget 0.10 ms (real client, 4793 slices); size hsm.inferences still growing at the end (6 -> 8258); size hsm.predictions still growing at the end (0 -> 88)

| handler | calls | total ms | mean ms | max ms | first-third mean | last-third mean | grows |
|---|---|---|---|---|---|---|---|
| Recorder.onEvent | 184398 | 5877.24 | 0.0319 | 5.94 | 0.0309 | 0.0313 | no |
| OocFill.step | 4793 | 3872.33 | 0.8079 | 11.67 | 0.7655 | 0.766 | no |
| Derive.DAMAGE_METER_COMBAT_SESSION_UPDATED | 52992 | 1660.40 | 0.0313 | 15.36 | 0.0229 | 0.0342 | no |
| DamageMeter.struct | 7870 | 1612.50 | 0.2049 | 6.61 | 0.1842 | 0.2098 | no |
| CombatLog.onEvent | 84717 | 1341.33 | 0.0158 | 1.75 | 0.015 | 0.016 | no |
| AuraPresence.tick | 1022 | 1084.94 | 1.0616 | 2.38 | 0.9962 | 1.1143 | no |
| DamageMeter.DAMAGE_METER_COMBAT_SESSION_UPDATED | 52992 | 1018.22 | 0.0192 | 0.16 | 0.0183 | 0.0194 | no |
| TokenScan.Slice | 9577 | 928.42 | 0.0969 | 0.47 | 0.0965 | 0.0959 | no |
| Identity.poll | 1022 | 858.02 | 0.8395 | 3.24 | 0.7701 | 0.8315 | no |
| Inference.UNIT_COMBAT | 8657 | 822.04 | 0.0950 | 1.32 | 0.091 | 0.0968 | no |
| WorldCapture.Slice | 4793 | 615.59 | 0.1284 | 1.12 | 0.1271 | 0.1296 | no |
| Derive.tick | 341 | 548.15 | 1.6075 | 10.38 | 1.4242 | 2.062 | no |
| Derive.UPDATE_BATTLEFIELD_SCORE | 109 | 521.90 | 4.7881 | 8.12 | 4.875 | 4.4699 | no |
| OocFill.UPDATE_BATTLEFIELD_SCORE | 109 | 503.28 | 4.6173 | 7.92 | 4.9275 | 4.2855 | no |
| CombatProbe.UNIT_AURA | 8267 | 326.69 | 0.0395 | 5.69 | 0.0353 | 0.0388 | no |
| Inference.UNIT_AURA | 8267 | 253.41 | 0.0307 | 0.58 | 0.03 | 0.0311 | no |
| CombatProbe.Run | 141 | 218.15 | 1.5471 | 5.68 | 1.6007 | 1.402 | no |
| CombatProbe.UNIT_HEALTH | 9631 | 198.17 | 0.0206 | 0.19 | 0.0196 | 0.0209 | no |
| Lab.dmSnap | 2418 | 197.22 | 0.0816 | 1.04 | 0.0856 | 0.0903 | no |
| Lab.DAMAGE_METER_COMBAT_SESSION_UPDATED | 52992 | 170.63 | 0.0032 | 0.12 | 0.0031 | 0.0032 | no |
| HSM.Census | 1022 | 157.74 | 0.1543 | 0.81 | 0.1531 | 0.1539 | no |
| Derive.UNIT_POWER_FREQUENT | 37128 | 152.24 | 0.0041 | 0.12 | 0.0034 | 0.005 | no |
| Identity.UNIT_TARGET | 2692 | 148.20 | 0.0551 | 1.39 | 0.0473 | 0.0548 | no |
| Inference.UNIT_HEALTH | 9631 | 143.83 | 0.0149 | 0.11 | 0.0147 | 0.015 | no |
| Lab.UNIT_AURA | 8267 | 128.20 | 0.0155 | 0.23 | 0.0142 | 0.0157 | no |

Samples (206): heapKB 201709 -> 608988 (min 201709, max 608988); fps 12.4 -> 8 (min 8, max 48); app 20.483 -> 122.933 (min 20.483, max 122.933); all 0.126 -> 0.078 (min 0.013, max 1.074); own 0.006 -> 0.006 (min 0.005, max 0.925); ownPeak 739.357 -> 739.357 (min 739.357, max 739.357)

Table sizes: hsm.inferences 6 -> 8258 (still growing); hsm.predictions 0 -> 88 (still growing); hsm.units 5 -> 2; identity.state 29 -> 49; inference.signals 18 -> 12106 (still growing, capped at 250000); ledger.aura 0 -> 5 (still growing, capped at 500); ledger.cast 0 -> 1; ledger.fingerprint 1 -> 5 (still growing, capped at 375); ledger.guid 17 -> 30 (still growing, capped at 375); ledger.plate 0 -> 0; ledger.token 30 -> 54 (still growing, capped at 80); verify.ring 5 -> 7948 (still growing, capped at 250000); verify.unexpected 2 -> 17 (still growing, capped at 216)

Own PeakTime marks (v2.2.16): load:begin 0.727; load:svunpack 0.727; load:initdb 0.727; login:begin 0.727; login:handlers 0.727; capture:begin 739.357; start:self-perf monitor 739.357; start:replay log (session_hdr + tape) 739.357; start:combat probe set 739.357; start:unit token survey 739.357; start:group-aware token scanner 739.357; start:container schema 739.357; start:spell knowledge + HSM inference 739.357; start:damage meter evidence (C_DamageMeter) 739.357; start:identity ledger (token/GUID correlation) 739.357; start:live verification loop 739.357; start:world-state capture (casts/auras/hp/threat/range/target-of) 739.357; start:learned spell / NPC / class DB 739.357; start:lab probes (capture level lab) 739.357; start:derivation lab (capture level lab) 739.357; start:aura presence probe (v2.2.25) 739.357; start:ooc fill + unit-token sweep (capture level lab) 739.357; start:HSM window 739.357
All-time peak 739.357 ms set between `login:handlers` and `capture:begin`.

## Profile snapshots (capture:on vs capture:off)

C_AddOnProfiler and memory at the start and end of each FD_Logs capture. Per-addon counters undercount time spent in an addon's OnUpdate/timers on this client; the application frame time is the reliable signal.

- 1025 s capture: application RecentAverageTime 20.5 -> 122.9 ms, PeakTime 2482.0 -> 2482.0
- flags: application frame time rose x6.0 during the capture (20.5 -> 122.9 ms/frame); ForeverDump memory +297.4 MB during the capture

| addon | memory KB | session avg ms | recent avg ms | +frames >1 ms | >10 ms | >50 ms |
|---|---|---|---|---|---|---|
| ForeverDump | 7652.0 -> 312200.0 | 0.0466 -> 0.0198 | 0.0065 -> 0.0058 | 20 | 1 | 0 |
| KTH | 1578.0 -> 4000.0 | 0.0142 -> 0.0179 | 0.0219 -> 0.0575 | 66 | 0 | 0 |
| KTH_ForeverDiag | 691.0 -> 3167.0 | 0.0078 -> 0.0191 | 0.0972 -> 0.0148 | 109 | 2 | 0 |

