# Inference lab report

Each rule: were its inputs readable per context (addon capture), did its inference match the ground truth
(WoWCombatLog file, offline), accuracy. Inference uses only values the API reported non-secret plus event timing.

Ground truth player: `Player-4618-00EB40D8` (log owner, unit flags 0x511). Truth counts: {'casts': 5, 'starts': 1, 'auras': 8, 'amounts': 14, 'misses': 0, 'summons': 0, 'summonsWithEnd': 0, 'dispels': 0}

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

Recall (real applications caught): {'applications': 5, 'caught': 0, 'recall': 0.0}

## Offline replay (clear mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 2 | 2 | 0 | 0 | 100.0% |
| iid-map | combat | 2 | 2 | 0 | 0 | 100.0% |
| observed | combat | 5 | 5 | 0 | 0 | 100.0% |

Recall: {'applications': 5, 'caught': 5, 'recall': 100.0}; live contradictions: 1

## Offline replay (secret mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 2 | 2 | 0 | 0 | 100.0% |
| iid-map | combat | 2 | 1 | 0 | 1 | 100.0% |
| single-applier | combat | 1 | 1 | 0 | 0 | 100.0% |

Recall: {'applications': 5, 'caught': 1, 'recall': 20.0}; live contradictions: 1

## Offline replay (secret-pretrained mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 2 | 2 | 0 | 0 | 100.0% |
| iid-map | combat | 2 | 2 | 0 | 0 | 100.0% |
| single-applier | combat | 2 | 2 | 0 | 0 | 100.0% |

Recall: {'applications': 5, 'caught': 2, 'recall': 40.0}; live contradictions: 1

