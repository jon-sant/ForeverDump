| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| orig | 0/0 | 0/9 = 0% | None | 0/9 | 0/34 | 0/2 | 1/1 | 0/8 = 0% | 0/0 | 0/8 = 0% | 0/9 = 0% | 0 | 0/0 |
| port3 | 8/10 = 80% | 8/9 = 89% | 0.0 | 2/9 | 23/34 | 2/2 | 0/1 | 7/8 = 88% | 7/10 = 70% | 7/8 = 88% | 0/9 = 0% | 2 | 224/224 = 100% |
| port5-nometer | 0/0 | 0/9 = 0% | None | 0/9 | 0/34 | 0/2 | 1/1 | 0/8 = 0% | 7/10 = 70% | 7/8 = 88% | 0/9 = 0% | 2 | 0/0 |
| port5 | 5/5 = 100% | 5/9 = 56% | 205.4 | 0/9 | 0/34 | 0/2 | 0/1 | 5/8 = 62% | 12/12 = 100% | 7/8 = 88% | 5/9 = 56% | 0 | 72/72 = 100% |

Enemy healers (seen on plates) first marked, by match phase (match time from the gates):
| variant | 0-2 min | 2-5 min | 5-10 min | 10 min+ | never |
|---|---|---|---|---|---|
| orig | 0 (cum 0/9) | 0 (cum 0/9) | 0 (cum 0/9) | 0 (cum 0/9) | 9 |
| port3 | 0 (cum 0/9) | 3 (cum 3/9) | 5 (cum 8/9) | 0 (cum 8/9) | 1 |
| port5-nometer | 0 (cum 0/9) | 0 (cum 0/9) | 0 (cum 0/9) | 0 (cum 0/9) | 9 |
| port5 | 0 (cum 0/9) | 0 (cum 0/9) | 3 (cum 3/9) | 2 (cum 5/9) | 4 |

port5 per enemy healer: run, name, class, log heal share, first seen s, first mark s, why, heal links, dmg links, revokes
  ('run16', 'Bleep', 'PRIEST', 0.82, 484, 749, 'meter class PRIEST', 0, 0, None)
  ('run16', 'Frobby', 'PRIEST', 0.82, 235, 732, 'meter class PRIEST', 0, 0, None)
  ('run16', 'Invictusap', 'DRUID', 0.98, 379, 584, 'meter heal 2944 dmg 208 median 339.5', 0, 0, None)
  ('run17', 'Gorrotar', 'PALADIN', 0.59, 105, None, None, 1, 0, None)
  ('run17', 'Aerie', 'PRIEST', 0.99, 359, 359, 'meter class PRIEST', 0, 0, None)
  ('run17', 'Brocky', 'PRIEST', 0.85, 459, 459, 'meter class PRIEST', 1, 0, None)
  ('run18', 'Randess', 'PRIEST', 0.39, 380, None, None, 0, 0, None)
  ('run18', 'Ank', 'PRIEST', 0.86, 273, None, None, 0, 1, None)
  ('run18', 'Karen', 'PRIEST', 0.82, 143, None, None, 0, 0, None)
