# PERF: ForeverDump self-performance

Source: profile snapshots (legacy, pre-2.2.3) (addon 2.2.2). Rule (PERFORMANCE.md): <1% of wall time, cost per call flat over the session, bounded tables.

## Profile snapshots (capture:on vs capture:off)

C_AddOnProfiler and memory at the start and end of each FD_Logs capture. Per-addon counters undercount time spent in an addon's OnUpdate/timers on this client; the application frame time is the reliable signal.

- 86 s capture: application RecentAverageTime 20.7 -> 59.3 ms, PeakTime 6261 -> 6261
- flags: application frame time rose x2.9 during the capture (20.7 -> 59.3 ms/frame); ForeverDump memory +23.8 MB during the capture

| addon | memory KB | session avg ms | recent avg ms | +frames >1 ms | >10 ms | >50 ms |
|---|---|---|---|---|---|---|
| ForeverDump | 46211.0 -> 70584.0 | 0.0324 -> 0.0342 | 0 -> 0 | 12 | 12 | 1 |
| QuestieDB | 24609.0 -> 24609.0 | 0 -> 0 | 0 -> 0 | 0 | 0 | 0 |
| Questie | 18209.0 -> 18335.0 | 0.2448 -> 0.2422 | 0.1494 -> 0.1426 | 0 | 0 | 0 |
| Auctionator | 5253.0 -> 5253.0 | 0.0009 -> 0.0009 | 0 -> 0 | 0 | 0 | 0 |
| ForeverDungeonJournal | 1440.0 -> 1440.0 | 0.0016 -> 0.0015 | 0 -> 0 | 0 | 0 | 0 |
| TweaksForever | 1301.0 -> 1376.0 | 0.0059 -> 0.0057 | 0.0019 -> 0.001 | 0 | 0 | 0 |
| TomTom | 579.0 -> 581.0 | 0.021 -> 0.0208 | 0.0128 -> 0.0154 | 0 | 0 | 0 |
| idTip | 63.0 -> 66.0 | 0 -> 0 | 0 -> 0 | 0 | 0 | 0 |
| QuestLevelPatch | 8.0 -> 8.0 | 0 -> 0 | 0 -> 0 | 0 | 0 | 0 |

