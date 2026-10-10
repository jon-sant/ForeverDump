# Inference lab report

Each rule: were its inputs readable per context (addon capture), did its inference match the ground truth
(WoWCombatLog file, offline), accuracy. Inference uses only values the API reported non-secret plus event timing.

Ground truth player: `Player-4618-00EB40D8` (log owner, unit flags 0x511). Truth counts: {'casts': 47, 'starts': 19, 'auras': 54, 'amounts': 39, 'misses': 0, 'summons': 13, 'summonsWithEnd': 0, 'dispels': 0}

## Rule inputs (addon capture): readable / unreadable per context

| signal | combat | ooc |
|---|---|---|
| aura.addedAuras | 0/9 | 0/0 |
| aura.applications | 0/0 | 2/0 |
| aura.auraInstanceID | 0/0 | 2/0 |
| aura.count | 0/28 | 6/0 |
| aura.duration | 0/0 | 2/0 |
| aura.fromPlayer | 0/0 | 2/0 |
| aura.removedID | 0/0 | 2/0 |
| aura.spellId | 0/0 | 2/0 |
| aura.updateInfo | 14/0 | 3/0 |
| playerCast.castGUID | 13/0 | 7/0 |
| playerCast.event | 13/0 | 7/0 |
| playerCast.spellID | 13/0 | 7/0 |
| totem.duration | 0/6 | 0/0 |
| totem.haveTotem | 0/6 | 0/0 |
| totem.name | 0/6 | 0/0 |
| totem.slot | 6/0 | 0/0 |
| totem.startTime | 0/6 | 0/0 |
| unitCast.castGUID | 0/46 | 0/2 |
| unitCast.event | 46/0 | 2/0 |
| unitCast.spellID | 0/46 | 0/2 |

## Addon inferences vs truth

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 27 | 0 | 3 | 24 | 0.0% |
| cast-pair | ooc | 1 | 0 | 1 | 0 | 0.0% |
| observed | combat | 1 | 1 | 0 | 0 | 100.0% |
| observed | ooc | 1 | 0 | 1 | 0 | 0.0% |

Recall (real applications caught): {'applications': 19, 'caught': 1, 'recall': 5.3}

## Offline replay (clear mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 19 | 19 | 0 | 0 | 100.0% |
| cast-pair | ooc | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 15 | 13 | 2 | 0 | 86.7% |
| iid-map | ooc | 5 | 5 | 0 | 0 | 100.0% |
| observed | combat | 17 | 17 | 0 | 0 | 100.0% |
| observed | ooc | 4 | 4 | 0 | 0 | 100.0% |

Recall: {'applications': 19, 'caught': 19, 'recall': 100.0}; live contradictions: 7

## Offline replay (secret mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 6 | 6 | 0 | 0 | 100.0% |
| cast-correlation | ooc | 1 | 1 | 0 | 0 | 100.0% |
| cast-pair | combat | 19 | 19 | 0 | 0 | 100.0% |
| cast-pair | ooc | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 15 | 8 | 1 | 6 | 88.9% |
| iid-map | ooc | 5 | 0 | 0 | 5 | - |
| single-applier | combat | 3 | 3 | 0 | 0 | 100.0% |

Recall: {'applications': 19, 'caught': 9, 'recall': 47.4}; live contradictions: 5

## Offline replay (secret-pretrained mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 6 | 6 | 0 | 0 | 100.0% |
| cast-correlation | ooc | 4 | 4 | 0 | 0 | 100.0% |
| cast-pair | combat | 19 | 19 | 0 | 0 | 100.0% |
| cast-pair | ooc | 7 | 7 | 0 | 0 | 100.0% |
| iid-map | combat | 15 | 9 | 1 | 5 | 90.0% |
| iid-map | ooc | 5 | 3 | 0 | 2 | 100.0% |
| single-applier | combat | 4 | 4 | 0 | 0 | 100.0% |

Recall: {'applications': 19, 'caught': 13, 'recall': 68.4}; live contradictions: 5

