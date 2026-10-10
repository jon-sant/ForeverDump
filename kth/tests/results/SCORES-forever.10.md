# forever.10 scores (truth v2: heal share >= 0.30 incl. HoT ticks AND >= 5 heal events on others incl. ticks)

Run 19 is NOT held out any more: forever.10's rules were designed with it (user decisions 2026-10-10).

Variants (KTH_CFG; tools/rescore10.sh): f10-off = all forever.10 switches off (= forever.9b + R16 spec fix), f10-noelim elim=0, f10-noform formTie=0, f10-net2 linkNet=2 (all others default), f10-k60 kSharePct=60, port10 = shipped defaults.

## run16,run17,run18
| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| port9b | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| f10-off | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| f10-noelim | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| f10-noform | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| f10-net2 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| f10-k60 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| port10 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |

Enemy healers (seen on plates) first marked, by match phase (match time from the gates):
| variant | 0-2 min | 2-5 min | 5-10 min | 10 min+ | never |
|---|---|---|---|---|---|
| port9b | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |
| f10-off | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |
| f10-noelim | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |
| f10-noform | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |
| f10-net2 | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |
| f10-k60 | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |
| port10 | 0 (cum 0/9) | 0 (cum 0/9) | 4 (cum 4/9) | 5 (cum 9/9) | 0 |

port10 per enemy healer: run, name, class, log heal share, first seen s, first mark s, why, heal links, dmg links, revokes
  ('run16', 'Bleep', 'PRIEST', 0.82, 484, 749, 'meter class PRIEST', 0, 0, None)
  ('run16', 'Frobby', 'PRIEST', 0.82, 235, 530, 'meter class PRIEST', 0, 0, None)
  ('run16', 'Invictusap', 'DRUID', 0.98, 379, 584, 'meter heal 2944 dmg 208 median 339.5', 0, 0, None)
  ('run17', 'Gorrotar', 'PALADIN', 0.59, 105, 1106, 'meter-proven PALADIN + heal-links 1/1', 1, 0, None)
  ('run17', 'Aerie', 'PRIEST', 0.99, 359, 359, 'meter class PRIEST', 0, 0, None)
  ('run17', 'Brocky', 'PRIEST', 0.85, 459, 459, 'meter class PRIEST', 1, 0, None)
  ('run18', 'Randess', 'PRIEST', 0.39, 380, 715, 'meter class PRIEST', 0, 0, None)
  ('run18', 'Ank', 'PRIEST', 0.86, 273, 1052, 'meter class PRIEST', 0, 1, None)
  ('run18', 'Karen', 'PRIEST', 0.82, 143, 1036, 'meter class PRIEST', 0, 0, None)

## run19
| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| port9b | 2/3 = 67% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 1/1 | 0/2 | 2/3 = 67% | 5/6 = 83% | 3/3 = 100% | 2/3 = 67% | 1 | 47/47 = 100% |
| f10-off | 2/3 = 67% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 1/1 | 0/2 | 2/3 = 67% | 5/6 = 83% | 3/3 = 100% | 2/3 = 67% | 1 | 47/47 = 100% |
| f10-noelim | 2/2 = 100% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 5/5 = 100% | 3/3 = 100% | 2/3 = 67% | 0 | 22/22 = 100% |
| f10-noform | 2/3 = 67% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 1/1 | 0/2 | 2/3 = 67% | 6/7 = 86% | 3/3 = 100% | 3/3 = 100% | 1 | 35/35 = 100% |
| f10-net2 | 2/2 = 100% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 6/6 = 100% | 3/3 = 100% | 3/3 = 100% | 0 | 22/22 = 100% |
| f10-k60 | 2/2 = 100% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 6/6 = 100% | 3/3 = 100% | 3/3 = 100% | 0 | 22/22 = 100% |
| port10 | 2/2 = 100% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 6/6 = 100% | 3/3 = 100% | 3/3 = 100% | 0 | 22/22 = 100% |

Enemy healers (seen on plates) first marked, by match phase (match time from the gates):
| variant | 0-2 min | 2-5 min | 5-10 min | 10 min+ | never |
|---|---|---|---|---|---|
| port9b | 2 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 1 |
| f10-off | 2 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 1 |
| f10-noelim | 2 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 1 |
| f10-noform | 2 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 1 |
| f10-net2 | 2 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 1 |
| f10-k60 | 2 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 1 |
| port10 | 2 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 0 (cum 2/3) | 1 |

port10 per enemy healer: run, name, class, log heal share, first seen s, first mark s, why, heal links, dmg links, revokes
  ('run19', 'Moun', 'PRIEST', 0.74, 85, None, 'meter min 1 PRIEST healer(s), others eliminated', 0, 0, None)
  ('run19', '汇源', 'DRUID', 0.96, 85, 112, 'meter class DRUID', 0, 0, None)
  ('run19', 'Danukeru', 'DRUID', 0.95, 100, 106, 'heal-links 2/2', 4, 0, None)
