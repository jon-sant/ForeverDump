# forever.11 scores: settings variants (KTH_SETTINGS, tools/rescore11.sh)

port11 = defaults; f11-debugoff = debug off; f11-g50/g70 = global 50%/70%; f11-priest80 = Priest (spec unknown) 80%. Defaults, explicit 60%, all overrides 60% and debug on/off are identical to forever.10 (R20).

## run16,run17,run18
| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| port10 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| port11 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| f11-debugoff | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 141/141 = 100% |
| f11-g50 | 9/11 = 82% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/21 = 76% | 7/8 = 88% | 9/9 = 100% | 3 | 186/186 = 100% |
| f11-g70 | 8/8 = 100% | 8/9 = 89% | 280.2 | 0/9 | 0/34 | 0/2 | 0/1 | 7/8 = 88% | 15/15 = 100% | 7/8 = 88% | 8/9 = 89% | 0 | 135/135 = 100% |
| f11-priest80 | 9/9 = 100% | 9/9 = 100% | 295.1 | 0/9 | 0/34 | 0/2 | 0/1 | 8/8 = 100% | 16/16 = 100% | 7/8 = 88% | 9/9 = 100% | 0 | 137/137 = 100% |


## run19
| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | icon on->off flips, healers (sum/units) | on->off flips, non-healers | non-healer druids marked | healer druids missed | plate recall, user definition (heal share >= 50%) | claim precision | claim recall F | claim recall E | non-healer druid claims | mouse-over alerts / healer-verdict hovers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| port10 | 2/2 = 100% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 6/6 = 100% | 3/3 = 100% | 3/3 = 100% | 0 | 22/22 = 100% |
| port11 | 2/2 = 100% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 6/6 = 100% | 3/3 = 100% | 3/3 = 100% | 0 | 22/22 = 100% |
| f11-debugoff | 2/2 = 100% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 6/6 = 100% | 3/3 = 100% | 3/3 = 100% | 0 | 22/22 = 100% |
| f11-g50 | 2/3 = 67% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 6/7 = 86% | 3/3 = 100% | 3/3 = 100% | 0 | 47/47 = 100% |
| f11-g70 | 2/2 = 100% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 6/6 = 100% | 3/3 = 100% | 3/3 = 100% | 0 | 22/22 = 100% |
| f11-priest80 | 2/2 = 100% | 2/3 = 67% | 16.6 | 0/3 | 0/12 | 0/1 | 0/2 | 2/3 = 67% | 6/6 = 100% | 3/3 = 100% | 3/3 = 100% | 0 | 22/22 = 100% |

