# Inference lab report

Each rule: were its inputs readable per context (addon capture), did its inference match the ground truth
(WoWCombatLog file, offline), accuracy. Inference uses only values the API reported non-secret plus event timing.

Ground truth player: `Player-4618-00EB40D8` (log owner, unit flags 0x511). Truth counts: {'casts': 17, 'starts': 4, 'auras': 25, 'amounts': 16, 'misses': 0}

_no addon inference data in this SV (v2.2 FD_Logs records it); offline replay below uses the file log only._

## Offline replay (clear mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 5 | 4 | 1 | 0 | 80.0% |
| iid-map | ooc | 4 | 4 | 0 | 0 | 100.0% |
| observed | combat | 6 | 6 | 0 | 0 | 100.0% |
| observed | ooc | 4 | 4 | 0 | 0 | 100.0% |

Recall: {'applications': 9, 'caught': 9, 'recall': 100.0}; live contradictions: 3

## Offline replay (secret mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | ooc | 1 | 1 | 0 | 0 | 100.0% |
| cast-pair | combat | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 5 | 1 | 0 | 4 | 100.0% |
| iid-map | ooc | 4 | 0 | 0 | 4 | - |

Recall: {'applications': 9, 'caught': 1, 'recall': 11.1}; live contradictions: 1

## Offline replay (secret-pretrained mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | ooc | 4 | 4 | 0 | 0 | 100.0% |
| cast-pair | combat | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 5 | 2 | 0 | 3 | 100.0% |
| iid-map | ooc | 4 | 3 | 0 | 1 | 100.0% |
| single-applier | combat | 1 | 1 | 0 | 0 | 100.0% |

Recall: {'applications': 9, 'caught': 5, 'recall': 55.6}; live contradictions: 1

