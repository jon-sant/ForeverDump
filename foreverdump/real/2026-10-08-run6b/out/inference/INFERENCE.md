# Inference lab report

Each rule: were its inputs readable per context (addon capture), did its inference match the ground truth
(WoWCombatLog file, offline), accuracy. Inference uses only values the API reported non-secret plus event timing.

Ground truth player: `Player-4618-00EB40D8` (log owner, unit flags 0x511). Truth counts: {'casts': 15, 'starts': 4, 'auras': 19, 'amounts': 32, 'misses': 0, 'summons': 2, 'summonsWithEnd': 0, 'dispels': 0}

## Rule inputs (addon capture): readable / unreadable per context

| signal |  |
|---|

## Addon inferences vs truth

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | ooc | 22 | 0 | 8 | 14 | 0.0% |
| count-delta | ooc | 5 | 0 | 1 | 4 | 0.0% |
| iid-map | ooc | 4 | 0 | 4 | 0 | 0.0% |
| observed | ooc | 6 | 0 | 6 | 0 | 0.0% |
| secret-timing | ooc | 6 | 0 | 6 | 0 | 0.0% |
| totem-update | ooc | 6 | 0 | 0 | 6 | - |

Recall (real applications caught): {'applications': 9, 'caught': 0, 'recall': 0.0}

## Offline replay (clear mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 5 | 5 | 0 | 0 | 100.0% |
| iid-map | ooc | 1 | 1 | 0 | 0 | 100.0% |
| observed | combat | 8 | 8 | 0 | 0 | 100.0% |
| observed | ooc | 1 | 1 | 0 | 0 | 100.0% |

Recall: {'applications': 9, 'caught': 9, 'recall': 100.0}; live contradictions: 1

## Offline replay (secret mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 1 | 1 | 0 | 0 | 100.0% |
| cast-pair | combat | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 5 | 2 | 0 | 3 | 100.0% |
| iid-map | ooc | 1 | 0 | 0 | 1 | - |
| single-applier | combat | 2 | 2 | 0 | 0 | 100.0% |

Recall: {'applications': 9, 'caught': 3, 'recall': 33.3}; live contradictions: 1

## Offline replay (secret-pretrained mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 2 | 2 | 0 | 0 | 100.0% |
| cast-correlation | ooc | 1 | 1 | 0 | 0 | 100.0% |
| cast-pair | combat | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 5 | 5 | 0 | 0 | 100.0% |
| iid-map | ooc | 1 | 0 | 0 | 1 | - |
| single-applier | combat | 3 | 3 | 0 | 0 | 100.0% |

Recall: {'applications': 9, 'caught': 6, 'recall': 66.7}; live contradictions: 1

