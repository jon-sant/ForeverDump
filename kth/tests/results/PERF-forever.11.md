# forever.11 frame-time estimate (tools/perf11.py)

Per-handler CPU cost, runs 16-19 replays (sum 4680 s of match), mock timing (os.clock). Mean / max per call.

| handler | calls | mean us (debug off) | max ms (off) | mean us (debug on) | max ms (on) | total ms off / on |
|---|---|---|---|---|---|---|
| event:UNIT_COMBAT | 41551 | 8.9 | 0.35 | 10.3 | 0.41 | 368.4 / 429.9 |
| event:UPDATE_BATTLEFIELD_SCORE | 446 | 186.2 | 0.39 | 220.2 | 0.61 | 83.0 / 98.2 |
| ticker:1s | 4650 | 14.5 | 0.08 | 17.5 | 0.08 | 67.4 / 81.5 |
| event:UPDATE_MOUSEOVER_UNIT | 2745 | 12.5 | 0.04 | 14.8 | 0.06 | 34.3 / 40.5 |
| event:UNIT_SPELLCAST_SUCCEEDED | 3138 | 10.4 | 0.09 | 11.5 | 0.04 | 32.7 / 36.0 |
| event:PLAYER_REGEN_ENABLED | 76 | 362.8 | 0.62 | 457.9 | 0.73 | 27.6 / 34.8 |
| tick:plateLog+updateZone | 4243 | 3.1 | 0.03 | 57.4 | 0.18 | 13.0 / 243.4 |
| event:NAME_PLATE_UNIT_ADDED | 1092 | 9.2 | 0.37 | 10.8 | 0.47 | 10.1 / 11.8 |
| event:NAME_PLATE_UNIT_REMOVED | 1089 | 5.9 | 0.02 | 6.8 | 0.03 | 6.5 / 7.4 |
| ticker:2s | 2337 | 1.3 | 0.01 | 55.2 | 0.18 | 3.0 / 129.0 |
| event:PLAYER_ENTERING_WORLD | 4 | 229.0 | 0.25 | 307.3 | 0.37 | 0.9 / 1.2 |
| event:ADDON_LOADED | 4 | 153.3 | 0.18 | 183.0 | 0.22 | 0.6 / 0.7 |
| event:PLAYER_LOGIN | 4 | 68.5 | 0.07 | 80.5 | 0.09 | 0.3 / 0.3 |

Whole-match average: K.T.H. CPU per second of match = 0.138 ms (debug off), 0.238 ms (debug on) = 0.0138% / 0.0238% of one CPU second.

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
| off | 1.84 | 0.031 ms | 0.18% | 0.391 | 2.35% | 0.62 |
| on | 2.15 | 0.036 ms | 0.22% | 0.448 | 2.69% | 0.73 |
