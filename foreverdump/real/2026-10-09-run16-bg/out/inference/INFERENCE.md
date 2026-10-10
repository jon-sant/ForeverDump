# Inference lab report

Each rule: were its inputs readable per context (addon capture), did its inference match the ground truth
(WoWCombatLog file, offline), accuracy. Inference uses only values the API reported non-secret plus event timing.

Ground truth player: `Player-4618-00EB40D8` (log owner, unit flags 0x511). Truth counts: {'casts': 159, 'starts': 23, 'auras': 205, 'amounts': 92, 'misses': 15, 'summons': 38, 'summonsWithEnd': 0, 'dispels': 14}

## Rule inputs (addon capture): readable / unreadable per context

| signal | combat | restricted |
|---|---|---|
| aura.addedAuras | 0/600 | 0/475 |
| aura.count | 0/1314 | 6/880 |
| aura.removedID | 0/0 | 4/0 |
| aura.updateInfo | 1287/0 | 857/0 |
| playerCast.castGUID | 805/0 | 121/1 |
| playerCast.event | 805/0 | 122/0 |
| playerCast.spellID | 805/0 | 122/0 |
| totem.duration | 0/40 | 0/28 |
| totem.haveTotem | 0/40 | 0/28 |
| totem.name | 0/40 | 0/28 |
| totem.slot | 40/0 | 28/0 |
| totem.startTime | 0/40 | 0/28 |
| unitCast.castGUID | 0/123 | 3/81 |
| unitCast.event | 123/0 | 84/0 |
| unitCast.spellID | 0/123 | 3/81 |
| unitCombat.action | 6589/0 | 3687/0 |
| unitCombat.amount | 6589/0 | 3687/0 |
| unitCombat.school | 6589/0 | 3687/0 |

## Addon inferences vs truth

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| aura-ambiguous | combat | 35 | 5 | 30 | 0 | 14.3% |
| aura-ambiguous | ooc | 7 | 0 | 7 | 0 | 0.0% |
| aura-me-elim | combat | 122 | 2 | 1 | 119 | 66.7% |
| aura-me-elim | ooc | 28 | 0 | 0 | 28 | - |
| cast-frame | combat | 23 | 0 | 0 | 23 | - |
| cast-pair | combat | 153 | 29 | 4 | 120 | 87.9% |
| cast-pair | ooc | 54 | 13 | 2 | 39 | 86.7% |
| damage-ambiguous | combat | 13 | 0 | 0 | 13 | - |
| dispel-cast+dm | combat | 14 | 0 | 0 | 14 | - |
| dm-reconcile | combat | 18 | 0 | 0 | 18 | - |
| dm-reconcile | ooc | 5 | 0 | 0 | 5 | - |
| elimination | combat | 4805 | 0 | 0 | 4805 | - |
| elimination | ooc | 1724 | 0 | 0 | 1724 | - |
| fail-dead | combat | 18 | 0 | 0 | 18 | - |
| fail-gcd | combat | 205 | 0 | 0 | 205 | - |
| fail-gcd | ooc | 9 | 0 | 0 | 9 | - |
| fail-inside-cd | combat | 310 | 0 | 0 | 310 | - |
| fail-inside-cd | ooc | 1 | 0 | 0 | 1 | - |
| fail-outside-cd | combat | 123 | 0 | 0 | 123 | - |
| fail-outside-cd | ooc | 11 | 0 | 0 | 11 | - |
| heal-ambiguous | combat | 1 | 0 | 0 | 1 | - |
| heal-cadence | combat | 37 | 0 | 0 | 37 | - |
| heal-cadence | ooc | 15 | 0 | 0 | 15 | - |
| heal-tgt-frame | combat | 1088 | 0 | 0 | 1088 | - |
| heal-tgt-frame | ooc | 440 | 0 | 0 | 440 | - |
| own-cast-frame | combat | 48 | 30 | 18 | 0 | 62.5% |
| own-cast-frame | ooc | 16 | 12 | 4 | 0 | 75.0% |
| regen | combat | 49 | 0 | 0 | 49 | - |
| regen | ooc | 7 | 0 | 0 | 7 | - |
| secret-timing | combat | 44 | 44 | 0 | 0 | 100.0% |
| secret-timing | ooc | 4 | 4 | 0 | 0 | 100.0% |
| summon-cadence | combat | 28 | 0 | 0 | 28 | - |
| summon-cadence | ooc | 3 | 0 | 0 | 3 | - |
| swing-frame | combat | 9 | 0 | 0 | 9 | - |
| swing-lag | combat | 19 | 0 | 0 | 19 | - |
| unit-combat | combat | 315 | 0 | 0 | 315 | - |

Recall (real applications caught): {'applications': 96, 'caught': 74, 'recall': 77.1}

## Offline replay (clear mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-pair | combat | 33 | 33 | 0 | 0 | 100.0% |
| cast-pair | ooc | 12 | 12 | 0 | 0 | 100.0% |
| iid-map | combat | 81 | 79 | 2 | 0 | 97.5% |
| iid-map | ooc | 13 | 12 | 1 | 0 | 92.3% |
| observed | combat | 79 | 79 | 0 | 0 | 100.0% |
| observed | ooc | 21 | 21 | 0 | 0 | 100.0% |

Recall: {'applications': 96, 'caught': 96, 'recall': 100.0}; live contradictions: 68

## Offline replay (secret mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 53 | 53 | 0 | 0 | 100.0% |
| cast-correlation | ooc | 12 | 12 | 0 | 0 | 100.0% |
| cast-pair | combat | 33 | 33 | 0 | 0 | 100.0% |
| cast-pair | ooc | 12 | 12 | 0 | 0 | 100.0% |
| iid-map | combat | 81 | 54 | 0 | 27 | 100.0% |
| iid-map | ooc | 13 | 5 | 0 | 8 | 100.0% |
| predicted-expiry | combat | 10 | 2 | 8 | 0 | 20.0% |

Recall: {'applications': 96, 'caught': 65, 'recall': 67.7}; live contradictions: 59

## Offline replay (secret-pretrained mode)

| rule | context | inferences | matched | wrong | unverifiable | accuracy |
|---|---|---|---|---|---|---|
| cast-correlation | combat | 58 | 58 | 0 | 0 | 100.0% |
| cast-correlation | ooc | 18 | 18 | 0 | 0 | 100.0% |
| cast-pair | combat | 33 | 33 | 0 | 0 | 100.0% |
| cast-pair | ooc | 12 | 12 | 0 | 0 | 100.0% |
| iid-map | combat | 81 | 61 | 0 | 20 | 100.0% |
| iid-map | ooc | 13 | 8 | 1 | 4 | 88.9% |
| predicted-expiry | combat | 10 | 2 | 8 | 0 | 20.0% |

Recall: {'applications': 96, 'caught': 74, 'recall': 77.1}; live contradictions: 48

