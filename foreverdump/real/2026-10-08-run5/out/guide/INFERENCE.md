# Inference lab report

Each rule: were its inputs readable per context (addon capture), did its inference match the ground truth
(WoWCombatLog file, offline), accuracy. Inference uses only values the API reported non-secret plus event timing.

Ground truth player: `Player-4618-00EB40D8` (log owner, unit flags 0x511). Truth counts: {'casts': 73, 'starts': 24, 'auras': 77, 'amounts': 72, 'misses': 3, 'summons': 19, 'summonsWithEnd': 0, 'dispels': 0}

## Rule inputs (addon capture): readable / unreadable per context

| signal | combat | ooc |
|---|---|---|
| aura.addedAuras | 0/10 | 0/0 |
| aura.applications | 0/0 | 6/0 |
| aura.auraInstanceID | 0/0 | 6/0 |
| aura.count | 0/24 | 20/0 |
| aura.duration | 0/0 | 6/0 |
| aura.fromPlayer | 0/0 | 6/0 |
| aura.removedID | 0/0 | 7/0 |
| aura.spellId | 0/0 | 6/0 |
| aura.updateInfo | 21/0 | 10/0 |
| playerCast.castGUID | 23/0 | 14/0 |
| playerCast.event | 23/0 | 14/0 |
| playerCast.spellID | 23/0 | 14/0 |
| totem.duration | 0/5 | 4/0 |
| totem.haveTotem | 0/5 | 4/0 |
| totem.name | 0/5 | 4/0 |
| totem.slot | 5/0 | 4/0 |
| totem.startTime | 0/5 | 4/0 |
| unitCast.castGUID | 0/27 | 0/2 |
| unitCast.event | 27/0 | 2/0 |
| unitCast.spellID | 0/27 | 0/2 |

## Addon inferences vs truth

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 22 | 6 | 2 | 14 | 75.0% |
| count-delta | combat | 3 | 1 | 0 | 2 | 100.0% |
| count-delta | ooc | 2 | 0 | 0 | 2 | - |
| iid-map | combat | 1 | 0 | 1 | 0 | 0.0% |
| iid-map | ooc | 3 | 1 | 2 | 0 | 33.3% |
| observed | combat | 2 | 1 | 1 | 0 | 50.0% |
| observed | ooc | 4 | 1 | 3 | 0 | 25.0% |
| secret-timing | combat | 6 | 6 | 0 | 0 | 100.0% |
| totem-update | ooc | 6 | 0 | 0 | 6 | - |

Recall (real applications caught): {'applications': 28, 'caught': 8, 'recall': 28.6}

## Offline replay (clear mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 28 | 28 | 0 | 0 | 100.0% |
| cast-pair | ooc | 8 | 8 | 0 | 0 | 100.0% |
| iid-map | combat | 22 | 20 | 2 | 0 | 90.9% |
| iid-map | ooc | 7 | 7 | 0 | 0 | 100.0% |
| observed | combat | 25 | 25 | 0 | 0 | 100.0% |
| observed | ooc | 5 | 5 | 0 | 0 | 100.0% |

Recall: {'applications': 28, 'caught': 28, 'recall': 100.0}; live contradictions: 17

## Offline replay (secret mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 8 | 8 | 0 | 0 | 100.0% |
| cast-correlation | ooc | 2 | 2 | 0 | 0 | 100.0% |
| cast-pair | combat | 28 | 28 | 0 | 0 | 100.0% |
| cast-pair | ooc | 8 | 8 | 0 | 0 | 100.0% |
| iid-map | combat | 22 | 13 | 1 | 8 | 92.9% |
| iid-map | ooc | 7 | 2 | 0 | 5 | 100.0% |
| single-applier | combat | 6 | 6 | 0 | 0 | 100.0% |

Recall: {'applications': 28, 'caught': 15, 'recall': 53.6}; live contradictions: 15

## Offline replay (secret-pretrained mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 17 | 17 | 0 | 0 | 100.0% |
| cast-correlation | ooc | 5 | 5 | 0 | 0 | 100.0% |
| cast-pair | combat | 28 | 28 | 0 | 0 | 100.0% |
| cast-pair | ooc | 8 | 8 | 0 | 0 | 100.0% |
| iid-map | combat | 22 | 16 | 1 | 5 | 94.1% |
| iid-map | ooc | 7 | 5 | 0 | 2 | 100.0% |

Recall: {'applications': 28, 'caught': 21, 'recall': 75.0}; live contradictions: 8

