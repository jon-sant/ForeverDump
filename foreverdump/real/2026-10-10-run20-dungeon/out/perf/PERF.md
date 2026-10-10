# PERF: ForeverDump self-performance

Source: perf (addon 2.2.25). Rule (PERFORMANCE.md): <1% of wall time, cost per call flat over the session, bounded tables.

## Capture 1 (cap-20261010113812-98, v2.2.25)

- 368 s, 39921 handler calls, 3049.6 ms total = **0.8292%** of wall time
- flags: WorldCapture.Slice: mean 0.1282 ms per slice > budget 0.10 ms (real client, 1679 slices); Derive.DAMAGE_METER_COMBAT_SESSION_UPDATED: cost per call grows 0.0238 -> 0.0538 ms (x2.27) over the session; size hsm.inferences still growing at the end (0 -> 689); size hsm.predictions still growing at the end (0 -> 38)

| handler | calls | total ms | mean ms | max ms | first-third mean | last-third mean | grows |
|---|---|---|---|---|---|---|---|
| Recorder.onEvent | 12696 | 571.17 | 0.0450 | 3.64 | 0.0449 | 0.044 | no |
| AuraPresence.tick | 367 | 353.64 | 0.9636 | 2.61 | 0.9397 | 0.9419 | no |
| OocFill.step | 1679 | 331.10 | 0.1972 | 2.86 | 0.1634 | 0.229 | no |
| TokenScan.Slice | 3356 | 328.02 | 0.0977 | 0.27 | 0.0957 | 0.0993 | no |
| WorldCapture.Slice | 1679 | 215.28 | 0.1282 | 0.79 | 0.1265 | 0.1288 | no |
| Derive.tick | 122 | 210.45 | 1.7250 | 4.52 | 1.6626 | 2.0217 | no |
| HSMUI.Step | 1058 | 182.20 | 0.1722 | 1.98 | 0.1651 | 0.1626 | no |
| Identity.poll | 265 | 103.86 | 0.3919 | 1.23 | 0.3357 | 0.4069 | no |
| Lab.sample | 734 | 77.16 | 0.1051 | 0.47 | 0.1019 | 0.1359 | no |
| CombatProbe.Run | 49 | 76.87 | 1.5687 | 8.82 |  |  | n/a |
| Inference.UNIT_COMBAT | 574 | 73.10 | 0.1274 | 1.06 | 0.1352 | 0.1017 | no |
| Derive.UNIT_POWER_FREQUENT | 4085 | 58.70 | 0.0144 | 0.24 | 0.0154 | 0.0166 | no |
| CombatLog.onEvent | 2580 | 47.36 | 0.0184 | 0.17 | 0.0173 | 0.0185 | no |
| Probe.step | 33 | 46.23 | 1.4009 | 16.01 |  |  | n/a |
| DamageMeter.struct | 410 | 38.80 | 0.0946 | 0.24 | 0.0954 | 0.0816 | no |
| HSM.Census | 367 | 37.24 | 0.1015 | 0.58 | 0.0929 | 0.1055 | no |
| Derive.DAMAGE_METER_COMBAT_SESSION_UPDATED | 928 | 23.59 | 0.0254 | 0.50 | 0.0238 | 0.0538 | **yes** |
| DamageMeter.DAMAGE_METER_COMBAT_SESSION_UPDATED | 928 | 23.30 | 0.0251 | 0.11 | 0.0242 | 0.0288 | no |
| Lab.dmSnap | 209 | 21.00 | 0.1005 | 0.32 | 0.0969 | 0.113 | no |
| Identity.NAME_PLATE_UNIT_ADDED | 127 | 17.71 | 0.1394 | 0.31 |  |  | n/a |
| Inference.UNIT_AURA | 162 | 15.77 | 0.0973 | 0.54 | 0.0944 | 0.0807 | no |
| HSM.CDDue | 99 | 12.51 | 0.1264 | 0.40 | 0.1297 | 0.1116 | no |
| HSM.Tick | 367 | 10.99 | 0.0300 | 0.10 | 0.0247 | 0.0354 | no |
| CombatProbe.UNIT_HEALTH | 524 | 10.94 | 0.0209 | 0.07 | 0.0201 | 0.0228 | no |
| OocFill.NAME_PLATE_UNIT_ADDED | 127 | 10.74 | 0.0846 | 0.17 |  |  | n/a |

Samples (75): heapKB 456936 -> 245371 (min 215487, max 499303); fps 48 -> 48 (min 12.3, max 48); app 20.483 -> 20.483 (min 20.483, max 123); all 0.025 -> 0.024 (min 0.015, max 0.067); own 0.013 -> 0.009 (min 0.007, max 0.036); ownPeak 7709.417 -> 7709.417 (min 7709.417, max 7709.417)

Table sizes: hsm.inferences 0 -> 689 (still growing); hsm.predictions 0 -> 38 (still growing); hsm.units 0 -> 2; identity.state 0 -> 2; inference.signals 2 -> 951 (still growing, capped at 250000); ledger.aura 0 -> 7 (still growing, capped at 500); ledger.cast 0 -> 1; ledger.fingerprint 0 -> 1; ledger.guid 1 -> 1; ledger.plate 0 -> 0; ledger.token 0 -> 1; verify.ring 0 -> 1007 (still growing, capped at 250000); verify.unexpected 0 -> 6 (still growing, capped at 216)

Own PeakTime marks (v2.2.16): load:begin 7709.417; load:svunpack 7709.417; load:initdb 7709.417; login:begin 7709.417; login:handlers 7709.417; capture:begin 7709.417; start:self-perf monitor 7709.417; start:replay log (session_hdr + tape) 7709.417; start:combat probe set 7709.417; start:unit token survey 7709.417; start:group-aware token scanner 7709.417; start:container schema 7709.417; start:spell knowledge + HSM inference 7709.417; start:damage meter evidence (C_DamageMeter) 7709.417; start:identity ledger (token/GUID correlation) 7709.417; start:live verification loop 7709.417; start:world-state capture (casts/auras/hp/threat/range/target-of) 7709.417; start:learned spell / NPC / class DB 7709.417; start:lab probes (capture level lab) 7709.417; start:derivation lab (capture level lab) 7709.417; start:aura presence probe (v2.2.25) 7709.417; start:ooc fill + unit-token sweep (capture level lab) 7709.417; start:HSM window 7709.417
All-time peak 7709.417 ms set between `(addon load)` and `load:begin`.

## Profile snapshots (capture:on vs capture:off)

C_AddOnProfiler and memory at the start and end of each FD_Logs capture. Per-addon counters undercount time spent in an addon's OnUpdate/timers on this client; the application frame time is the reliable signal.

- 368 s capture: application RecentAverageTime 20.5 -> 20.5 ms, PeakTime 2482.0 -> 2482.0
- flags: ForeverDump memory +21.2 MB during the capture

| addon | memory KB | session avg ms | recent avg ms | +frames >1 ms | >10 ms | >50 ms |
|---|---|---|---|---|---|---|
| ForeverDump | 18677.0 -> 40414.0 | 0.2176 -> 0.1951 | 0.0129 -> 0.0091 | 26 | 1 | 0 |
| KTH | 2365.0 -> 1996.0 | 0.0171 -> 0.0163 | 0.0078 -> 0.0103 | 0 | 0 | 0 |
| KTH_ForeverDiag | 149.0 -> 101.0 | 0.0124 -> 0.0115 | 0.004 -> 0.0046 | 0 | 0 | 0 |

