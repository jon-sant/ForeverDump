# run 22 - BG (Darkspear Islands), 2026-10-10 13:39-13:57 ET, FD 2.2.27, client 1.60.1 / 70338

Verified: ForeverDumpDB.addonVersion 2.2.27 (versionHistory 2.2.25 -> 2.2.27 at 13:34 ET; 2.2.26 was never live),
meta.build 70338. Capture 1048 s (13:39:25-13:56:53). CL cut from the 13:39:25.879 header (original kept).

| item | measured |
|---|---|
| Lua errors | 0 (errors {}, ownErrors 0) |
| blocked rows | 50, all ADDON_RESTRICTION_STATE_CHANGED (type 0 Combat 24 on / 24 off; type 3, 5 off at post); 0 ADDON_ACTION_BLOCKED/FORBIDDEN |
| FD own time | 23.0 s / 1048 s = 2.20 % wall (AuraPresence.tick 1.75 s = 0.17 %, 1046 ticks, mean 1.67 ms, max 3.47 ms) |
| aura-presence candidates | 0 all session (auraLearned/auraPairs/spellCache[70338] empty; no /fdump static run); 0 presence calls -> no U/A/D data |
| per-check cost | not measurable (0 calls); limit stayed 357 (initial estimate) |
| rotation | bug: 21 existing units probed per tick instead of <= 7 (fixed in 2.2.28) |
| GetAuraSlots | E 'Auras cannot be accessed when secret while tainted' in prep, gates, combat; N/N clear in post |
| totems (GetTotemInfo) | prep/gates/combat: all fields S except icon; post: clear. icon N = empty slot, S = totem (see below) |
| UnitHealth / UnitPower | S for every unit, every phase, PvP flag 1 or S, friend 0/1, self 1, restriction vector with or without Chat/PvPMatch/Combat |
| restriction flips | Combat type 0 Activating x24 at PLAYER_REGEN_DISABLED (env stamp still ooc), Inactive x24; Chat + PvPMatch Inactive at post; Map stays active |

## Totem presence via the icon field (tools/fdump/totemscore.py)
34 own SPELL_SUMMON; slots from PLAYER_TOTEM_UPDATE rows: 1:6 (Flametongue), 2:8 (Tremor/Earthbind), 3:6 (Poison
Cleansing), 4:14 (Grounding). 0.5 s samples, 0.7 s edges excluded:

| truth | icon N | icon S |
|---|---|---|
| empty | 5076 | 0 |
| totem (end known) | 190 | 2480 (92.9 %) |
| totem (end unknown, capped 120 s) | 148 | 261 |

## Derivation rule vs CL (tools/fdump/derivesim.py, same-ID rule, knowledge durations)
| cast -> aura | applied | miss | end ok (+-1.5 s) | early | refreshed/open |
|---|---|---|---|---|---|
| 17364 Stormstrike | 14 | 7 | 1 | 12 (median -8.8 s, charges) | 1 |
| 8056 Frost Shock | 15 | 5 | 5 | 10 (median -3.0 s) | 0 |
| 905 Lightning Shield | 5 | 0 | 0 | 5 (charges) | 0 |
| 8053 Flame Shock | 2 | 0 | 1 | 0 | 1 |
Observed pairs on me <= 0.6 s after my cast: 17364 -> 1238931 (Improved Stormstrike) 15, 1238640 -> 1238640 18, 905 -> 905 5.
