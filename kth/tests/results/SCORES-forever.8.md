# Scores, forever.8 (real BG replays, runs 16-18; ForeverDump raw)

| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| orig | 0/0 | 0/9 = 0% | None | 0/9 | 0/34 | 0/2 | 1/1 | 0/8 = 0% | 0/0 | 0/8 = 0% | 0/9 = 0% | 0 | 0/0 |
| port3 | 8/10 = 80% | 8/9 = 89% | 0.0 | 2/9 | 23/34 | 2/2 | 0/1 | 7/8 = 88% | 7/10 = 70% | 7/8 = 88% | 0/9 = 0% | 2 | 224/224 = 100% |
| port5 | 5/5 = 100% | 5/9 = 56% | 205.4 | 0/9 | 0/34 | 0/2 | 0/1 | 5/8 = 62% | 12/12 = 100% | 7/8 = 88% | 5/9 = 56% | 0 | 72/72 = 100% |
| port6 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| port7 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| port8 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |

Enemy healers (seen on plates) first marked, by match phase (match time from the gates):
| variant | 0-2 min | 2-5 min | 5-10 min | 10 min+ | never |
|---|---|---|---|---|---|
| orig | 0 (cum 0/9) | 0 (cum 0/9) | 0 (cum 0/9) | 0 (cum 0/9) | 9 |
| port3 | 0 (cum 0/9) | 3 (cum 3/9) | 5 (cum 8/9) | 0 (cum 8/9) | 1 |
| port5 | 0 (cum 0/9) | 0 (cum 0/9) | 3 (cum 3/9) | 2 (cum 5/9) | 4 |
| port6 | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |
| port7 | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |
| port8 | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |

port8 per enemy healer: run, name, class, log heal share, first seen s, first mark s, why, heal links, dmg links, revokes
  ('run16', 'Bleep', 'PRIEST', 0.82, 484, 749, 'meter class PRIEST', 0, 0, None)
  ('run16', 'Frobby', 'PRIEST', 0.82, 235, 530, 'meter class PRIEST', 0, 0, None)
  ('run16', 'Invictusap', 'DRUID', 0.98, 379, 584, 'meter heal 2944 dmg 208 median 339.5', 0, 0, None)
  ('run17', 'Gorrotar', 'PALADIN', 0.59, 105, 1106, 'meter-possible PALADIN + heal-links 1/1', 1, 0, None)
  ('run17', 'Aerie', 'PRIEST', 0.99, 359, 359, 'meter class PRIEST', 0, 0, None)
  ('run17', 'Brocky', 'PRIEST', 0.85, 459, 459, 'meter class PRIEST', 1, 0, None)
  ('run18', 'Randess', 'PRIEST', 0.39, 380, 715, 'meter class PRIEST', 0, 0, None)
  ('run18', 'Ank', 'PRIEST', 0.86, 273, 1052, 'meter class PRIEST', 0, 1, None)
  ('run18', 'Karen', 'PRIEST', 0.82, 143, 1036, 'meter class PRIEST', 0, 0, None)

## Time to mark after first heal (live replay, port8)
| run | healer | class | log share | first heal on other s | first plate s | first heal link s | claim s | plate mark s | mark - first heal s | first kept meter snapshot s | why |
|---|---|---|---|---|---|---|---|---|---|---|---|
| run16 | Bleep | - | 0.82 | 135 | 484 | - | 523 | 749 | 614 | 381 | meter class PRIEST |
| run16 | Invictusap | - | 0.98 | 152 | 379 | - | 391 | 584 | 433 | 381 | meter heal 2944 dmg 208 median 339.5 |
| run16 | Frobby | - | 0.82 | 143 | 235 | - | 523 | 530 | 387 | 381 | meter class PRIEST |
| run17 | Gorrotar | PALADIN | 0.59 | 100 | 105 | 1105 | 1105 | 1106 | 1006 | 230 | meter-possible PALADIN + heal-links 1/1 |
| run17 | Aerie | PRIEST | 0.99 | 85 | 359 | - | 229 | 359 | 274 | 230 | meter class PRIEST |
| run17 | Brocky | PRIEST | 0.85 | 87 | 459 | 480 | 229 | 459 | 372 | 230 | meter class PRIEST |
| run18 | Ank | PRIEST | 0.86 | 272 | 273 | - | 693 | 1052 | 780 | 593 | meter class PRIEST |
| run18 | Karen | PRIEST | 0.82 | 288 | 143 | - | 693 | 1036 | 748 | 593 | meter class PRIEST |
| run18 | Randess | PRIEST | 0.39 | 301 | 380 | - | 693 | 715 | 413 | 593 | meter class PRIEST |

median mark - first heal: 433 s; min 274 s; max 1006 s; n=9

## Healer-only list: COMBAT-LOG SIMULATION (only valid if spell IDs were readable)
| run | player | class | log heal share | label | first listed cast | ID | flag - first heal s |
|---|---|---|---|---|---|---|---|
| 10-08-run8-bg | Wheat | PRIEST | 0.0 | unknown | Penance | 402289 | None |
| 10-08-run9-bg | Wheat | PRIEST | 0.0 | unknown | Penance | 402289 | None |
| 10-09-run10-bg | Barry | PRIEST | 0.785 | healer | Penance | 402284 | -12 |
| 10-09-run10-bg | Darthnik | PRIEST | 0.878 | healer | Penance | 402289 | -1 |
| 10-09-run10-bg | Stiggy | PRIEST | 0.683 | healer | Penance | 402289 | 9 |
| 10-09-run10-bg | Wheat | PRIEST | 0.0 | unknown | Penance | 402289 | None |
| 10-09-run11-bg | Aeddi | PRIEST | 0.864 | healer | Penance | 402289 | -95 |
| 10-09-run11-bg | Arphe | PRIEST | 0.565 | healer | Penance | 402289 | 0 |
| 10-09-run11-bg | Pretty | PRIEST | 0.0 | unknown | Penance | 402284 | None |
| 10-09-run14-bg | Anger | PRIEST | 0.851 | healer | Penance | 402289 | 14 |
| 10-09-run14-bg | Swig | PRIEST | 0.762 | healer | Penance | 402284 | -8 |
| 10-09-run15-bg | Albus | PRIEST | 0.65 | healer | Penance | 402289 | 0 |
| 10-09-run15-bg | Clinic | PRIEST | 0.959 | healer | Penance | 402289 | -1 |
| 10-09-run15-bg | Jalond | PRIEST | 1.0 | unknown | Penance | 402289 | 0 |
| 10-09-run15-bg | Milkshake | PRIEST | 1.0 | unknown | Penance | 402289 | -271 |
| 10-09-run15-bg | Severn | PRIEST | 0.107 | DPS | Penance | 402284 | -256 |
| 10-09-run15-bg | Shartkillero | PRIEST | 0.0 | unknown | Penance | 402289 | None |
| 10-09-run16-bg | Bleep | PRIEST | 0.816 | healer | Penance | 402284 | 117 |
| 10-09-run16-bg | Frobby | PRIEST | 0.82 | healer | Penance | 402284 | 9 |
| 10-09-run16-bg | Rabbit | PRIEST | 0.942 | healer | Penance | 402289 | 3 |
| 10-10-run17-bg | Aerie | PRIEST | 0.989 | healer | Penance | 402289 | -1 |
| 10-10-run17-bg | Brocky | PRIEST | 0.852 | healer | Penance | 402289 | -1 |
| 10-10-run18-bg | Ank | PRIEST | 0.86 | healer | Penance | 402289 | 0 |
| 10-10-run18-bg | Hyllina | PRIEST | 0.844 | healer | Penance | 402289 | 6 |
| 10-10-run18-bg | Karen | PRIEST | 0.822 | healer | Penance | 402289 | -1 |
