# Inference lab report

Each rule: were its inputs readable per context (addon capture), did its inference match the ground truth
(WoWCombatLog file, offline), accuracy. Inference uses only values the API reported non-secret plus event timing.

Ground truth player: `Player-4618-00EB40D8` (log owner, unit flags 0x511). Truth counts: {'casts': 33, 'starts': 19, 'auras': 45, 'amounts': 30, 'misses': 0, 'summons': 7, 'summonsWithEnd': 0, 'dispels': 0}

## Rule inputs (addon capture): readable / unreadable per context

| signal | combat |
|---|---|
| aura.addedAuras | 0/8 |
| aura.count | 0/22 |
| aura.updateInfo | 11/0 |
| playerCast.castGUID | 10/0 |
| playerCast.event | 10/0 |
| playerCast.spellID | 10/0 |

## Addon inferences vs truth

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 2 | 2 | 0 | 0 | 100.0% |

Recall (real applications caught): {'applications': 15, 'caught': 0, 'recall': 0.0}

## Offline replay (clear mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 19 | 19 | 0 | 0 | 100.0% |
| cast-pair | ooc | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 12 | 10 | 2 | 0 | 83.3% |
| iid-map | ooc | 5 | 5 | 0 | 0 | 100.0% |
| observed | combat | 13 | 13 | 0 | 0 | 100.0% |
| observed | ooc | 4 | 4 | 0 | 0 | 100.0% |

Recall: {'applications': 15, 'caught': 15, 'recall': 100.0}; live contradictions: 6

## Offline replay (secret mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 3 | 3 | 0 | 0 | 100.0% |
| cast-correlation | ooc | 1 | 1 | 0 | 0 | 100.0% |
| cast-pair | combat | 19 | 19 | 0 | 0 | 100.0% |
| cast-pair | ooc | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 12 | 5 | 1 | 6 | 83.3% |
| iid-map | ooc | 5 | 0 | 0 | 5 | - |
| single-applier | combat | 2 | 2 | 0 | 0 | 100.0% |

Recall: {'applications': 15, 'caught': 5, 'recall': 33.3}; live contradictions: 4

## Offline replay (secret-pretrained mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 3 | 3 | 0 | 0 | 100.0% |
| cast-correlation | ooc | 4 | 4 | 0 | 0 | 100.0% |
| cast-pair | combat | 19 | 19 | 0 | 0 | 100.0% |
| cast-pair | ooc | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 12 | 6 | 1 | 5 | 85.7% |
| iid-map | ooc | 5 | 3 | 0 | 2 | 100.0% |
| single-applier | combat | 3 | 3 | 0 | 0 | 100.0% |

Recall: {'applications': 15, 'caught': 9, 'recall': 60.0}; live contradictions: 4

