# forever.12 frame-time estimate (tools/perf11.py, E.cfg settings proxy)

Per-handler CPU cost, runs 16-19 replays (sum 4680 s of match), mock timing (os.clock). Mean / max per call.

| handler | calls | mean us (debug off) | max ms (off) | mean us (debug on) | max ms (on) | total ms off / on |
|---|---|---|---|---|---|---|
| event:UNIT_COMBAT | 41551 | 8.4 | 0.35 | 8.7 | 0.50 | 351.0 / 361.4 |
| event:UPDATE_BATTLEFIELD_SCORE | 446 | 191.6 | 0.38 | 206.3 | 0.46 | 85.4 / 92.0 |
| ticker:1s | 4650 | 13.9 | 0.07 | 14.2 | 0.08 | 64.4 / 66.0 |
| event:UPDATE_MOUSEOVER_UNIT | 2745 | 11.9 | 0.04 | 12.3 | 0.06 | 32.7 / 33.9 |
| event:PLAYER_REGEN_ENABLED | 76 | 414.8 | 0.75 | 478.1 | 0.81 | 31.5 / 36.3 |
| event:UNIT_SPELLCAST_SUCCEEDED | 3138 | 9.9 | 0.04 | 10.2 | 0.04 | 31.0 / 31.9 |
| tick:plateLog+updateZone | 4243 | 2.9 | 0.01 | 46.6 | 0.16 | 12.2 / 197.9 |
| event:NAME_PLATE_UNIT_ADDED | 1092 | 8.8 | 0.34 | 9.3 | 0.36 | 9.6 / 10.2 |
| event:NAME_PLATE_UNIT_REMOVED | 1089 | 5.7 | 0.02 | 5.8 | 0.02 | 6.2 / 6.4 |
| ticker:2s | 2337 | 1.2 | 0.00 | 44.4 | 0.14 | 2.9 / 103.9 |
| event:PLAYER_ENTERING_WORLD | 4 | 232.7 | 0.24 | 234.2 | 0.24 | 0.9 / 0.9 |
| event:ADDON_LOADED | 4 | 154.0 | 0.16 | 141.5 | 0.16 | 0.6 / 0.6 |
| event:PLAYER_LOGIN | 4 | 71.2 | 0.07 | 65.2 | 0.07 | 0.3 / 0.3 |

Whole-match average: K.T.H. CPU per second of match = 0.134 ms (debug off), 0.201 ms (debug on) = 0.0134% / 0.0201% of one CPU second.

Worst-case event rates (combat logs; replay streams = what K.T.H. was measured to receive):

| run | combat events max/s | max/frame | casts max/s | max/frame | replay UNIT_COMBAT max/s | replay casts max/s |
|---|---|---|---|---|---|---|
| run16 | 39 | 10 | 16 | 5 | 50 | 5 |
| run17 | 38 | 8 | 16 | 6 | 56 | 7 |
| run18 | 36 | 7 | 14 | 4 | 54 | 6 |
| run19 | 41 | 9 | 19 | 5 | 51 | 8 |

Estimate at the worst second / worst frame of runs 16-19 (pessimistic token fan-out x3 / x2, plus 5 hovers, 10 plate adds and 1 scoreboard update per second):

| debug | busiest second: K.T.H. ms per s | = average per 60 fps frame | % of 16.67 ms budget | busiest frame (event burst) ms | % of budget | largest single call ms (meter read / scoreboard / scan) |
|---|---|---|---|---|---|---|
| off | 1.77 | 0.029 ms | 0.18% | 0.372 | 2.23% | 0.75 |
| on | 1.85 | 0.031 ms | 0.19% | 0.383 | 2.30% | 0.81 |
