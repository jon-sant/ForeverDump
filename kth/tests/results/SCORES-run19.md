# run 19 (2026-10-10, Darkspear Islands, held-out; thresholds tuned on 16-18). KTH_RUNS=run19 python3 tools/score5.py ...
| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| orig | 0/0 | 0/2 = 0% | None | 0/2 | 0/13 | 0/1 | 2/2 | 0/2 = 0% | 0/0 | 0/2 = 0% | 0/2 = 0% | 0 | 0/0 |
| port3 | 2/5 = 40% | 2/2 = 100% | 0.0 | 1/2 | 15/13 | 1/1 | 0/2 | 2/2 = 100% | 2/3 = 67% | 1/2 = 50% | 1/2 = 50% | 1 | 107/87 = 123% |
| port5 | 1/2 = 50% | 1/2 = 50% | 6.0 | 0/2 | 0/13 | 1/1 | 1/2 | 1/2 = 50% | 3/5 = 60% | 2/2 = 100% | 1/2 = 50% | 2 | 34/34 = 100% |
| port6 | 2/3 = 67% | 2/2 = 100% | 16.6 | 0/2 | 0/13 | 1/1 | 0/2 | 2/2 = 100% | 4/6 = 67% | 2/2 = 100% | 2/2 = 100% | 2 | 47/47 = 100% |
| port7 | 2/3 = 67% | 2/2 = 100% | 16.6 | 0/2 | 0/13 | 1/1 | 0/2 | 2/2 = 100% | 4/6 = 67% | 2/2 = 100% | 2/2 = 100% | 2 | 47/47 = 100% |
| port8 | 2/3 = 67% | 2/2 = 100% | 16.6 | 0/2 | 0/13 | 1/1 | 0/2 | 2/2 = 100% | 4/6 = 67% | 2/2 = 100% | 2/2 = 100% | 2 | 47/47 = 100% |
| port9 | 2/3 = 67% | 2/2 = 100% | 16.6 | 0/2 | 0/13 | 1/1 | 0/2 | 2/2 = 100% | 4/6 = 67% | 2/2 = 100% | 2/2 = 100% | 2 | 47/47 = 100% |

Enemy healers (seen on plates) first marked, by match phase (match time from the gates):
| variant | 0-2 min | 2-5 min | 5-10 min | 10 min+ | never |
|---|---|---|---|---|---|
| orig | 0 (cum 0/2) | 0 (cum 0/2) | 0 (cum 0/2) | 0 (cum 0/2) | 2 |
| port3 | 2 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 |
| port5 | 1 (cum 1/2) | 0 (cum 1/2) | 0 (cum 1/2) | 0 (cum 1/2) | 1 |
| port6 | 2 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 |
| port7 | 2 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 |
| port8 | 2 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 |
| port9 | 2 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 (cum 2/2) | 0 |

port9 per enemy healer: run, name, class, log heal share, first seen s, first mark s, why, heal links, dmg links, revokes
  ('run19', '汇源', 'DRUID', 0.96, 85, 112, 'meter class DRUID', 0, 0, None)
  ('run19', 'Danukeru', 'DRUID', 0.95, 100, 106, 'heal-links 2/2', 4, 0, None)

## experimental druid form-veto (NOT shipped; /tmp/kthx variant, threshold chosen after seeing run19 => not out-of-sample)
### run16,run17,run18
| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| port9 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| x-form40 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| x-form50 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
### run19
| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| port9 | 2/3 = 67% | 2/2 = 100% | 16.6 | 0/2 | 0/13 | 1/1 | 0/2 | 2/2 = 100% | 4/6 = 67% | 2/2 = 100% | 2/2 = 100% | 2 | 47/47 = 100% |
| x-form40 | 2/2 = 100% | 2/2 = 100% | 16.6 | 0/2 | 0/13 | 0/1 | 0/2 | 2/2 = 100% | 4/5 = 80% | 2/2 = 100% | 2/2 = 100% | 0 | 22/22 = 100% |
| x-form50 | 2/3 = 67% | 2/2 = 100% | 16.6 | 0/2 | 1/13 | 1/1 | 0/2 | 2/2 = 100% | 4/7 = 57% | 2/2 = 100% | 2/2 = 100% | 2 | 34/34 = 100% |
