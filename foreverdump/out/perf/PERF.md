# PERF: ForeverDump self-performance

Source: perf (addon 2.2.25). Rule (PERFORMANCE.md): <1% of wall time, cost per call flat over the session, bounded tables.

## Capture 1 (cap-20261010120549-102, v2.2.25)

- 228 s, 27503 handler calls, 1711.8 ms total = **0.7521%** of wall time
- flags: WorldCapture.Slice: mean 0.1212 ms per slice > budget 0.10 ms (real client, 1090 slices); size hsm.inferences still growing at the end (0 -> 408); size hsm.predictions still growing at the end (0 -> 30)

| handler | calls | total ms | mean ms | max ms | first-third mean | last-third mean | grows |
|---|---|---|---|---|---|---|---|
| Recorder.onEvent | 8553 | 304.00 | 0.0355 | 0.26 | 0.0351 | 0.0358 | no |
| HSMUI.Step | 2112 | 221.41 | 0.1048 | 1.85 | 0.1007 | 0.1096 | no |
| TokenScan.Slice | 2179 | 203.44 | 0.0934 | 0.26 | 0.0929 | 0.0938 | no |
| AuraPresence.tick | 227 | 158.10 | 0.6965 | 1.49 | 0.7174 | 0.6361 | no |
| OocFill.step | 1090 | 153.03 | 0.1404 | 2.68 | 0.1462 | 0.1167 | no |
| WorldCapture.Slice | 1090 | 132.12 | 0.1212 | 0.54 | 0.1219 | 0.1196 | no |
| Derive.tick | 75 | 85.30 | 1.1373 | 2.45 | 1.3448 | 0.8044 | no |
| Identity.poll | 144 | 54.68 | 0.3797 | 0.70 | 0.3849 | 0.3539 | no |
| Probe.step | 33 | 43.70 | 1.3242 | 13.24 |  |  | n/a |
| Inference.UNIT_COMBAT | 495 | 42.83 | 0.0865 | 0.32 | 0.0837 | 0.0842 | no |
| CombatProbe.Run | 39 | 39.08 | 1.0020 | 6.41 |  |  | n/a |
| Lab.sample | 455 | 28.56 | 0.0628 | 0.22 | 0.0645 | 0.0532 | no |
| CombatLog.onEvent | 1815 | 26.28 | 0.0145 | 0.14 | 0.0139 | 0.0144 | no |
| DamageMeter.struct | 248 | 20.80 | 0.0839 | 0.19 | 0.0855 | 0.0808 | no |
| Derive.UNIT_POWER_FREQUENT | 2294 | 19.70 | 0.0086 | 0.09 | 0.0079 | 0.0081 | no |
| HSM.Census | 227 | 16.05 | 0.0707 | 0.24 | 0.072 | 0.0661 | no |
| Inference.UNIT_AURA | 127 | 14.59 | 0.1149 | 0.57 | 0.0966 | 0.1287 | no |
| DamageMeter.DAMAGE_METER_COMBAT_SESSION_UPDATED | 534 | 10.81 | 0.0202 | 0.07 | 0.019 | 0.0197 | no |
| Derive.DAMAGE_METER_COMBAT_SESSION_UPDATED | 534 | 9.16 | 0.0171 | 0.39 | 0.0129 | 0.0182 | no |
| Lab.dmSnap | 123 | 9.09 | 0.0739 | 0.18 | 0.0764 | 0.0759 | no |
| HSM.CDDue | 81 | 7.93 | 0.0980 | 0.20 | 0.1002 | 0.092 | no |
| CombatProbe.UNIT_HEALTH | 439 | 7.78 | 0.0177 | 0.08 | 0.018 | 0.0195 | no |
| OocFill.NAME_PLATE_UNIT_ADDED | 29 | 7.30 | 0.2516 | 0.41 |  |  | n/a |
| HSM.Tick | 227 | 6.20 | 0.0273 | 0.10 | 0.0208 | 0.0293 | no |
| Inference.UNIT_HEALTH | 439 | 5.74 | 0.0131 | 0.05 | 0.0135 | 0.0136 | no |

Samples (47): heapKB 204824 -> 277647 (min 204824, max 277647); fps 48 -> 48 (min 38.2, max 48); app 20.483 -> 20.483 (min 20.483, max 20.5); all 0.018 -> 0.017 (min 0.015, max 0.033); own 0.003 -> 0.002 (min 0.002, max 0.017); ownPeak 7709.417 -> 7709.417 (min 7709.417, max 7709.417)

Table sizes: hsm.inferences 0 -> 408 (still growing); hsm.predictions 0 -> 30 (still growing); hsm.units 0 -> 1; identity.state 2 -> 5; inference.signals 2 -> 738 (still growing, capped at 250000); ledger.aura 1 -> 4; ledger.cast 0 -> 1; ledger.fingerprint 0 -> 1; ledger.guid 2 -> 26 (still growing, capped at 375); ledger.plate 1 -> 4; ledger.token 2 -> 11 (still growing, capped at 80); verify.ring 1 -> 672 (still growing, capped at 250000); verify.unexpected 1 -> 11 (still growing, capped at 216)

Own PeakTime marks (v2.2.16): load:begin 7709.417; load:svunpack 7709.417; load:initdb 7709.417; login:begin 7709.417; login:handlers 7709.417; capture:begin 7709.417; start:self-perf monitor 7709.417; start:replay log (session_hdr + tape) 7709.417; start:combat probe set 7709.417; start:unit token survey 7709.417; start:group-aware token scanner 7709.417; start:container schema 7709.417; start:spell knowledge + HSM inference 7709.417; start:damage meter evidence (C_DamageMeter) 7709.417; start:identity ledger (token/GUID correlation) 7709.417; start:live verification loop 7709.417; start:world-state capture (casts/auras/hp/threat/range/target-of) 7709.417; start:learned spell / NPC / class DB 7709.417; start:lab probes (capture level lab) 7709.417; start:derivation lab (capture level lab) 7709.417; start:aura presence probe (v2.2.25) 7709.417; start:ooc fill + unit-token sweep (capture level lab) 7709.417; start:HSM window 7709.417
All-time peak 7709.417 ms set between `(addon load)` and `load:begin`.

## Profile snapshots (capture:on vs capture:off)

C_AddOnProfiler and memory at the start and end of each FD_Logs capture. Per-addon counters undercount time spent in an addon's OnUpdate/timers on this client; the application frame time is the reliable signal.

- 228 s capture: application RecentAverageTime 20.5 -> 20.5 ms, PeakTime 2482.0 -> 2482.0
- flags: ForeverDump memory +36.0 MB during the capture

| addon | memory KB | session avg ms | recent avg ms | +frames >1 ms | >10 ms | >50 ms |
|---|---|---|---|---|---|---|
| ForeverDump | 8528.0 -> 45362.0 | 0.1564 -> 0.1469 | 0.0027 -> 0.0023 | 21 | 1 | 0 |
| KTH | 1268.0 -> 1529.0 | 0.0169 -> 0.0166 | 0.0114 -> 0.0114 | 0 | 0 | 0 |
| KTH_ForeverDiag | 93.0 -> 111.0 | 0.0099 -> 0.0095 | 0.0038 -> 0.0031 | 0 | 0 | 0 |

