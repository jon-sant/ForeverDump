# Combat secrets matrix

Item x unit class x context. Cell = observed code (documented class in brackets); **bold** = mismatch with the
70245 docs. Codes: N nil, S secret, T container w/ secrets, K container clear, C clear, E error, * mixed.

## Detectability (yes / partial / no / n/a per unit class x context)

**Is it casting/channelling?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| mouseover:hostile-npc | yes | yes | idle (nil return is readable) |
| nameplate:hostile-npc | yes | yes | idle (nil return is readable) |
| player | yes | yes | idle (nil return is readable) |
| target:hostile-npc | yes | yes | idle (nil return is readable) |
| targettarget:self | - | yes | idle (nil return is readable) |

**Which spell?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| mouseover:hostile-npc | n/a | n/a |  |
| nameplate:hostile-npc | n/a | n/a | spellID=S name=S texture=S notInterruptible=S |
| player | n/a | n/a |  |
| target:hostile-npc | n/a | n/a | spellID=S name=S texture=S notInterruptible=S |
| targettarget:self | - | n/a |  |

**Any buff/debuff?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| nameplate:hostile-npc | yes | no | aura APIs error |
| player | yes | no | aura APIs error |
| target:hostile-npc | yes | no | aura APIs error |

**MY buff/debuff?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| nameplate:hostile-npc | yes | no | aura APIs error |
| player | yes | no | aura APIs error |
| target:hostile-npc | yes | no | aura APIs error |

**WHAT aura?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| nameplate:hostile-npc | n/a | n/a |  |
| player | yes | n/a | spellId=C name=C icon=C |
| target:hostile-npc | n/a | n/a |  |

**Stacks / duration?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| nameplate:hostile-npc | n/a | n/a |  |
| player | yes | n/a | applications=C duration=C durObj=K |
| target:hostile-npc | n/a | n/a |  |

**Dispellable?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| nameplate:hostile-npc | n/a | n/a |  |
| player | n/a | n/a |  |
| target:hostile-npc | n/a | n/a |  |

## Matrix

### UnitExists

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### UnitThreatSituation

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | N [conditional] | S [conditional] |
| 1 | nameplate:hostile-npc | N [conditional] | C [conditional] |
| 1 | player | N [conditional] | N [conditional] |
| 1 | target:hostile-npc | N [conditional] | C [conditional] |
| 1 | targettarget:self |  | N [conditional] |

### UnitGUID

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [conditional] | C [conditional] |
| 1 | nameplate:hostile-npc | C [conditional] | C [conditional] |
| 1 | player | C [conditional] | C [conditional] |
| 1 | target:hostile-npc | C [conditional] | C [conditional] |
| 1 | targettarget:self |  | C [conditional] |

### UnitRace

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| raceName | mouseover:hostile-npc | N [conditional] | N [conditional] |
| raceName | nameplate:hostile-npc | N [conditional] | N [conditional] |
| raceName | player | C [conditional] | C [conditional] |
| raceName | target:hostile-npc | N [conditional] | N [conditional] |
| raceName | targettarget:self |  | C [conditional] |
| raceFile | player | C [conditional] | C [conditional] |
| raceFile | targettarget:self |  | C [conditional] |
| raceID | player | C [conditional] | C [conditional] |
| raceID | targettarget:self |  | C [conditional] |

### UnitInRange

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| checked | mouseover:hostile-npc | S [always] | S [always] |
| checked | nameplate:hostile-npc | S [always] | S [always] |
| checked | player | S [always] | S [always] |
| checked | target:hostile-npc | S [always] | S [always] |
| checked | targettarget:self |  | S [always] |
| inRange | mouseover:hostile-npc | S [always] | S [always] |
| inRange | nameplate:hostile-npc | S [always] | S [always] |
| inRange | player | S [always] | S [always] |
| inRange | target:hostile-npc | S [always] | S [always] |
| inRange | targettarget:self |  | S [always] |

### UnitIsEnemy

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### UnitClass

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| classID | mouseover:hostile-npc | C [conditional] | C [conditional] |
| classID | nameplate:hostile-npc | C [conditional] | C [conditional] |
| classID | player | C [conditional] | C [conditional] |
| classID | target:hostile-npc | C [conditional] | C [conditional] |
| classID | targettarget:self |  | C [conditional] |
| classFile | mouseover:hostile-npc | C [conditional] | C [conditional] |
| classFile | nameplate:hostile-npc | C [conditional] | C [conditional] |
| classFile | player | C [conditional] | C [conditional] |
| classFile | target:hostile-npc | C [conditional] | C [conditional] |
| classFile | targettarget:self |  | C [conditional] |
| className | mouseover:hostile-npc | C [conditional] | C [conditional] |
| className | nameplate:hostile-npc | C [conditional] | C [conditional] |
| className | player | C [conditional] | C [conditional] |
| className | target:hostile-npc | C [conditional] | C [conditional] |
| className | targettarget:self |  | C [conditional] |

### GetUnitSpeed

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| flight | mouseover:hostile-npc | C [conditional] | S [conditional] |
| flight | nameplate:hostile-npc | C [conditional] | S [conditional] |
| flight | player | C [conditional] | S [conditional] |
| flight | target:hostile-npc | C [conditional] | S [conditional] |
| flight | targettarget:self |  | S [conditional] |
| current | mouseover:hostile-npc | C [conditional] | S [conditional] |
| current | nameplate:hostile-npc | C [conditional] | S [conditional] |
| current | player | C [conditional] | S [conditional] |
| current | target:hostile-npc | C [conditional] | S [conditional] |
| current | targettarget:self |  | S [conditional] |
| run | mouseover:hostile-npc | C [conditional] | S [conditional] |
| run | nameplate:hostile-npc | C [conditional] | S [conditional] |
| run | player | C [conditional] | S [conditional] |
| run | target:hostile-npc | C [conditional] | S [conditional] |
| run | targettarget:self |  | S [conditional] |
| swim | mouseover:hostile-npc | C [conditional] | S [conditional] |
| swim | nameplate:hostile-npc | C [conditional] | S [conditional] |
| swim | player | C [conditional] | S [conditional] |
| swim | target:hostile-npc | C [conditional] | S [conditional] |
| swim | targettarget:self |  | S [conditional] |

### UnitCastingInfo

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| name | mouseover:hostile-npc | N [conditional] | N [conditional] |
| name | nameplate:hostile-npc | N* [conditional] | N* [conditional] |
| name | player | N [conditional] | N [conditional] |
| name | target:hostile-npc | N [conditional] | N* [conditional] |
| name | targettarget:self |  | N [conditional] |
| isTradeSkill | nameplate:hostile-npc | C [never] | C [never] |
| isTradeSkill | target:hostile-npc |  | C [never] |
| notInterruptible | nameplate:hostile-npc | S [conditional] | S [conditional] |
| notInterruptible | target:hostile-npc |  | S [conditional] |
| endTimeMS | nameplate:hostile-npc | S [conditional] | S [conditional] |
| endTimeMS | target:hostile-npc |  | S [conditional] |
| text | nameplate:hostile-npc | S [conditional] | S [conditional] |
| text | target:hostile-npc |  | S [conditional] |
| 11 | nameplate:hostile-npc | C [never] | C [never] |
| 11 | target:hostile-npc |  | C [never] |
| 10 | nameplate:hostile-npc | C [never] | C [never] |
| 10 | target:hostile-npc |  | C [never] |
| castID | nameplate:hostile-npc | S [conditional] | S [conditional] |
| castID | target:hostile-npc |  | S [conditional] |
| spellID | nameplate:hostile-npc | S [conditional] | S [conditional] |
| spellID | target:hostile-npc |  | S [conditional] |
| startTimeMS | nameplate:hostile-npc | S [conditional] | S [conditional] |
| startTimeMS | target:hostile-npc |  | S [conditional] |
| texture | nameplate:hostile-npc | S [conditional] | S [conditional] |
| texture | target:hostile-npc |  | S [conditional] |

### UnitIsUnit(u,player)

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [conditional] | C [conditional] |
| 1 | nameplate:hostile-npc | C [conditional] | C [conditional] |
| 1 | player | C [conditional] | C [conditional] |
| 1 | target:hostile-npc | C [conditional] | C [conditional] |
| 1 | targettarget:self |  | C [conditional] |

### UnitGetTotalAbsorbs

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | S [always] | S [always] |
| 1 | nameplate:hostile-npc | S [always] | S [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | S [always] | S [always] |
| 1 | targettarget:self |  | S [always] |

### GetRaidTargetIndex

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | N [always] | N [always] |
| 1 | nameplate:hostile-npc | N [always] | N [always] |
| 1 | player | N [always] | N [always] |
| 1 | target:hostile-npc | N [always] | N [always] |
| 1 | targettarget:self |  | N [always] |

### UnitPosition

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| y | mouseover:hostile-npc | N [none] | N [none] |
| y | nameplate:hostile-npc | N [none] | N [none] |
| y | player | C [none] | C [none] |
| y | target:hostile-npc | N [none] | N [none] |
| y | targettarget:self |  | C [none] |
| x | mouseover:hostile-npc | N [none] | N [none] |
| x | nameplate:hostile-npc | N [none] | N [none] |
| x | player | C [none] | C [none] |
| x | target:hostile-npc | N [none] | N [none] |
| x | targettarget:self |  | C [none] |
| mapID | mouseover:hostile-npc | C [none] | C [none] |
| mapID | nameplate:hostile-npc | C [none] | C [none] |
| mapID | player | C [none] | C [none] |
| mapID | target:hostile-npc | C [none] | C [none] |
| mapID | targettarget:self |  | C [none] |
| z | mouseover:hostile-npc | N [none] | N [none] |
| z | nameplate:hostile-npc | N [none] | N [none] |
| z | player | C [none] | C [none] |
| z | target:hostile-npc | N [none] | N [none] |
| z | targettarget:self |  | C [none] |

### UnitFullName

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| name | mouseover:hostile-npc | C [conditional] | C [conditional] |
| name | nameplate:hostile-npc | C [conditional] | C [conditional] |
| name | player | C [conditional] | C [conditional] |
| name | target:hostile-npc | C [conditional] | C [conditional] |
| name | targettarget:self |  | C [conditional] |
| realm | mouseover:hostile-npc | N [conditional] | N [conditional] |
| realm | nameplate:hostile-npc | N [conditional] | N [conditional] |
| realm | player | C [conditional] | C [conditional] |
| realm | target:hostile-npc | N [conditional] | N [conditional] |
| realm | targettarget:self |  | C [conditional] |

### UnitGetIncomingHeals

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | N [always] | N [always] |
| 1 | nameplate:hostile-npc | N [always] | N [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | N [always] | N [always] |
| 1 | targettarget:self |  | S [always] |

### UnitPower

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | S [conditional] | S [conditional] |
| 1 | nameplate:hostile-npc | S [conditional] | S [conditional] |
| 1 | player | S [conditional] | S [conditional] |
| 1 | target:hostile-npc | S [conditional] | S [conditional] |
| 1 | targettarget:self |  | S [conditional] |

### UnitIsFriend

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### UnitHealth

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | S [always] | S [always] |
| 1 | nameplate:hostile-npc | S [always] | S [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | S [always] | S [always] |
| 1 | targettarget:self |  | S [always] |

### UnitGetTotalHealAbsorbs

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | S [always] | S [always] |
| 1 | nameplate:hostile-npc | S [always] | S [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | S [always] | S [always] |
| 1 | targettarget:self |  | S [always] |

### UnitLevel

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### CheckInteractDistance

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] |  |
| 1 | target:hostile-npc | C [none] | C [none] |

### UnitCanAttack

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### UnitReaction

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### UnitIsDeadOrGhost

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### UnitName

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| name | mouseover:hostile-npc | C [conditional] | C [conditional] |
| name | nameplate:hostile-npc | C [conditional] | C [conditional] |
| name | player | C [conditional] | C [conditional] |
| name | target:hostile-npc | C [conditional] | C [conditional] |
| name | targettarget:self |  | C [conditional] |
| realm | mouseover:hostile-npc | N [conditional] | N [conditional] |
| realm | nameplate:hostile-npc | N [conditional] | N [conditional] |
| realm | player | C [conditional] | C [conditional] |
| realm | target:hostile-npc | N [conditional] | N [conditional] |
| realm | targettarget:self |  | C [conditional] |

### UnitChannelInfo

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| name | mouseover:hostile-npc | N [conditional] | N [conditional] |
| name | nameplate:hostile-npc | N [conditional] | N [conditional] |
| name | player | N [conditional] | N [conditional] |
| name | target:hostile-npc | N [conditional] | N [conditional] |
| name | targettarget:self |  | N [conditional] |

### C_Spell.IsSpellInRange

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | N [none] | N [none] |
| 1 | nameplate:hostile-npc | N [none] | N [none] |
| 1 | player | N [none] | N [none] |
| 1 | target:hostile-npc | N [none] | N [none] |
| 1 | targettarget:self |  | N [none] |

### UnitHealthMax

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | S [conditional] | S [conditional] |
| 1 | nameplate:hostile-npc | S [conditional] | S [conditional] |
| 1 | player | C [conditional] | C [conditional] |
| 1 | target:hostile-npc | S [conditional] | S [conditional] |
| 1 | targettarget:self |  | C [conditional] |

### UnitAffectingCombat

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### UnitPowerType

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| powerType | mouseover:hostile-npc | C [none] | C [none] |
| powerType | nameplate:hostile-npc | C [none] | C [none] |
| powerType | player | C [none] | C [none] |
| powerType | target:hostile-npc | C [none] | C [none] |
| powerType | targettarget:self |  | C [none] |
| 3 | mouseover:hostile-npc | N [none] | N [none] |
| 3 | nameplate:hostile-npc | N [none] | N [none] |
| 3 | player | N [none] | N [none] |
| 3 | target:hostile-npc | N [none] | N [none] |
| 3 | targettarget:self |  | N [none] |
| powerToken | mouseover:hostile-npc | C [none] | C [none] |
| powerToken | nameplate:hostile-npc | C [none] | C [none] |
| powerToken | player | C [none] | C [none] |
| powerToken | target:hostile-npc | C [none] | C [none] |
| powerToken | targettarget:self |  | C [none] |
| 5 | mouseover:hostile-npc | N [none] | N [none] |
| 5 | nameplate:hostile-npc | N [none] | N [none] |
| 5 | player | N [none] | N [none] |
| 5 | target:hostile-npc | N [none] | N [none] |
| 5 | targettarget:self |  | N [none] |
| 4 | mouseover:hostile-npc | N [none] | N [none] |
| 4 | nameplate:hostile-npc | N [none] | N [none] |
| 4 | player | N [none] | N [none] |
| 4 | target:hostile-npc | N [none] | N [none] |
| 4 | targettarget:self |  | N [none] |

### UnitHealthPercent

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | S [always] | S [always] |
| 1 | nameplate:hostile-npc | S [always] | S [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | S [always] | S [always] |
| 1 | targettarget:self |  | S [always] |

### UnitDetailedThreatSituation

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| scaledPct | mouseover:hostile-npc |  | S [conditional] |
| scaledPct | nameplate:hostile-npc |  | S [conditional] |
| scaledPct | target:hostile-npc |  | C [conditional] |
| status | mouseover:hostile-npc |  | S [conditional] |
| status | nameplate:hostile-npc |  | S [conditional] |
| status | target:hostile-npc |  | C [conditional] |
| isTanking | mouseover:hostile-npc | N [conditional] | S [conditional] |
| isTanking | nameplate:hostile-npc | N [conditional] | S [conditional] |
| isTanking | player | N [conditional] | N [conditional] |
| isTanking | target:hostile-npc | N [conditional] | C [conditional] |
| isTanking | targettarget:self |  | N [conditional] |
| rawThreat | mouseover:hostile-npc |  | S [conditional] |
| rawThreat | nameplate:hostile-npc |  | S [conditional] |
| rawThreat | target:hostile-npc |  | C [conditional] |
| rawPct | mouseover:hostile-npc |  | S [conditional] |
| rawPct | nameplate:hostile-npc |  | S [conditional] |
| rawPct | target:hostile-npc |  | C [conditional] |

### UnitIsPlayer

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### ShouldUnitIdentityBeSecret

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### UnitPowerMax

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | S [conditional] | S [conditional] |
| 1 | nameplate:hostile-npc | S [conditional] | S [conditional] |
| 1 | player | C [conditional] | C [conditional] |
| 1 | target:hostile-npc | S [conditional] | S [conditional] |
| 1 | targettarget:self |  | C [conditional] |

### CanCompareUnitTokens

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | targettarget:self |  | C [none] |

### C_Map.GetPlayerMapPosition

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | mouseover:hostile-npc | N [none] | N [none] |
| 1 | nameplate:hostile-npc | N [none] | N [none] |
| 1 | player | K [none] | K [none] |
| 1 | target:hostile-npc | N [none] | N [none] |
| 1 | targettarget:self |  | K [none] |
| .RotateDirection | player | C [none] | C [none] |
| .RotateDirection | targettarget:self |  | C [none] |
| .GetLength | player | C [none] | C [none] |
| .GetLength | targettarget:self |  | C [none] |
| .Normalize | player | C [none] | C [none] |
| .Normalize | targettarget:self |  | C [none] |
| .Dot | player | C [none] | C [none] |
| .Dot | targettarget:self |  | C [none] |
| .GetLengthSquared | player | C [none] | C [none] |
| .GetLengthSquared | targettarget:self |  | C [none] |
| .GetXY | player | C [none] | C [none] |
| .GetXY | targettarget:self |  | C [none] |
| .OnLoad | player | C [none] | C [none] |
| .OnLoad | targettarget:self |  | C [none] |
| .IsZero | player | C [none] | C [none] |
| .IsZero | targettarget:self |  | C [none] |
| .DivideBy | player | C [none] | C [none] |
| .DivideBy | targettarget:self |  | C [none] |
| .ScaleBy | player | C [none] | C [none] |
| .ScaleBy | targettarget:self |  | C [none] |
| .y | player | C [none] | C [none] |
| .y | targettarget:self |  | C [none] |
| .Subtract | player | C [none] | C [none] |
| .Subtract | targettarget:self |  | C [none] |
| .Clone | player | C [none] | C [none] |
| .Clone | targettarget:self |  | C [none] |
| .Cross | player | C [none] | C [none] |
| .Cross | targettarget:self |  | C [none] |
| .IsEqualTo | player | C [none] | C [none] |
| .IsEqualTo | targettarget:self |  | C [none] |
| .SetXY | player | C [none] | C [none] |
| .SetXY | targettarget:self |  | C [none] |
| .x | player | C [none] | C [none] |
| .x | targettarget:self |  | C [none] |
| .Add | player | C [none] | C [none] |
| .Add | targettarget:self |  | C [none] |

### IsSwimming

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] | C [none] |

### IsFlying

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] | C [none] |

### GetPlayerFacing

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] | C [none] |

### IsFalling

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] | C [none] |

### C_DamageMeter.IsDamageMeterAvailable

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | global | C [none] | C [none] |
| 2 | global | C [none] | C [none] |

### C_DamageMeter.GetCombatSessionFromType

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | global | K [conditional] | T [conditional] |
| .durationSeconds | global | C [conditional] | S [conditional] |
| .combatSources | global | K [conditional] | K [conditional] |
| .totalAmount | global | C [conditional] | S [conditional] |
| .maxAmount | global | C [conditional] | S [conditional] |

### UnitCastingDuration

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | T [always] | T [always] |
| 1 | target:hostile-npc |  | T [always] |

### aura:GetAuraSlots[HARMFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |

### aura:GetAuraDataByIndex[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | K [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetUnitAuras[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |

### aura:GetAuraDataBySlot[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetAuraSlots[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |
| 2 | player | C [none] |  |
| 3 | player | C [none] |  |

### aura:GetAuraDataBySlot[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetUnitAuras[HARMFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |

### aura:GetAuraDataByIndex[HARMFUL|RAID]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | N [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |

### aura:GetUnitAuras[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |

### aura:GetAuraApplicationDisplayCount[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [conditional] |  |

### aura:GetAuraDataByAuraInstanceID[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetPlayerAuraBySpellID

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetAuraApplicationDisplayCount[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [conditional] |  |

### aura:GetAuraDataByIndex[HARMFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | N [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |

### aura:GetAuraDataByIndex[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | K [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetUnitAuras[HARMFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |

### aura:GetSpellAuraSecrecy

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] |  |

### aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |

### aura:ShouldSpellAuraBeSecret

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] |  |

### aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |

### aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | N [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |

### aura:GetUnitAuras[HARMFUL|RAID]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |

### aura:GetAuraSlots[HARMFUL|RAID]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |

### aura:GetAuraDataByIndex[HARMFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | N [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |

### aura:GetAuraDispelTypeColor[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [conditional] |  |
| .a | player | C [conditional] |  |
| .b | player | C [conditional] |  |
| .GetHSL | player | C [conditional] |  |
| .g | player | C [conditional] |  |
| .GetRGBA | player | C [conditional] |  |
| .IsRGBEqualTo | player | C [conditional] |  |
| .SetRGB | player | C [conditional] |  |
| .GetRGB | player | C [conditional] |  |
| .OnLoad | player | C [conditional] |  |
| .GenerateHexColorMarkup | player | C [conditional] |  |
| .WrapTextInColorCode | player | C [conditional] |  |
| .GenerateHexColor | player | C [conditional] |  |
| .IsEqualTo | player | C [conditional] |  |
| .r | player | C [conditional] |  |
| .GenerateHexColorNoAlpha | player | C [conditional] |  |
| .SetRGBA | player | C [conditional] |  |
| .GetRGBAsBytes | player | C [conditional] |  |
| .GetRGBAAsBytes | player | C [conditional] |  |

### aura:GetAuraDuration[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [none] |  |

### aura:GetAuraDuration[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [none] |  |

### aura:GetAuraDataByAuraInstanceID[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetAuraSlots[HARMFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |

### aura:GetAuraSlots[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |
| 2 | player | C [none] |  |
| 3 | player | C [none] |  |
| 4 | player | C [none] |  |

### aura:GetAuraDispelTypeColor[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [conditional] |  |
| .a | player | C [conditional] |  |
| .b | player | C [conditional] |  |
| .GetHSL | player | C [conditional] |  |
| .g | player | C [conditional] |  |
| .GetRGBA | player | C [conditional] |  |
| .IsRGBEqualTo | player | C [conditional] |  |
| .SetRGB | player | C [conditional] |  |
| .GetRGB | player | C [conditional] |  |
| .OnLoad | player | C [conditional] |  |
| .GenerateHexColorMarkup | player | C [conditional] |  |
| .WrapTextInColorCode | player | C [conditional] |  |
| .GenerateHexColor | player | C [conditional] |  |
| .IsEqualTo | player | C [conditional] |  |
| .r | player | C [conditional] |  |
| .GenerateHexColorNoAlpha | player | C [conditional] |  |
| .SetRGBA | player | C [conditional] |  |
| .GetRGBAsBytes | player | C [conditional] |  |
| .GetRGBAAsBytes | player | C [conditional] |  |

## Cast / channel time left

Derived `endTimeMS - GetTime()*1000` vs the sanctioned duration object.

| ctx / unit class | endTimeMS | derived | error | duration object | HasSecretValues | GetRemainingDuration |
|---|---|---|---|---|---|---|
| combat|nameplate:hostile-npc | S | blocked | Interface/AddOns/ForeverDump/Controls.lua:227: attempt to perform arit | T | C | S |
| combat|target:hostile-npc | S | blocked | Interface/AddOns/ForeverDump/Controls.lua:227: attempt to perform arit | T | C | S |
| ooc|nameplate:hostile-npc | S | blocked | Interface/AddOns/ForeverDump/Controls.lua:227: attempt to perform arit | T | C | S |

## Operations on representative secrets (per category)

| ctx | category | state | arith | compare | tostring | concat | format | tableKey | setText | statusBar |
|---|---|---|---|---|---|---|---|---|---|---|
| combat | health | S | err | err | ok/S | ok/S | ok/S | err | err | ok |
| combat | identity | C | err | err | ok | ok | ok | ok | err | err |
| combat | power | S | err | err | ok/S | ok/S | ok/S | err | err | ok |
| ooc | health | S | err | err | ok/S | ok/S | ok/S | err | err | ok |
| ooc | identity | C | err | err | ok | ok | ok | ok | err | err |
| ooc | power | S | err | err | ok/S | ok/S | ok/S | err | err | ok |

## Event payloads per unit class

| ctx | unit class | event | n | arg codes | updateInfo fields |
|---|---|---|---|---|---|
| combat | nameplate:hostile-npc | UNIT_AURA | 11 | 2:T | addedAuras:S* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N* |
| combat | nameplate:hostile-npc | UNIT_HEALTH | 42 |  |  |
| combat | nameplate:hostile-npc | UNIT_SPELLCAST_INTERRUPTED | 1 | 2:S 3:S 4:S 5:C |  |
| combat | nameplate:hostile-npc | UNIT_SPELLCAST_START | 4 | 2:S 3:S 4:C |  |
| combat | nameplate:hostile-npc | UNIT_SPELLCAST_STOP | 5 | 2:S 3:S 4:C |  |
| combat | nameplate:hostile-npc | UNIT_SPELLCAST_SUCCEEDED | 4 | 2:S 3:S 4:C |  |
| combat | player | UNIT_AURA | 11 | 2:T | addedAuras:N* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N* |
| combat | player | UNIT_HEALTH | 48 |  |  |
| combat | player | UNIT_SPELLCAST_FAILED | 4 | 2:C 3:C 4:N |  |
| combat | player | UNIT_SPELLCAST_START | 3 | 2:C 3:C 4:C |  |
| combat | player | UNIT_SPELLCAST_STOP | 2 | 2:C 3:C 4:C |  |
| combat | player | UNIT_SPELLCAST_SUCCEEDED | 14 | 2:C 3:C 4:N* |  |
| combat | softenemy:hostile-npc | UNIT_AURA | 2 | 2:T | addedAuras:N* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N |
| combat | softenemy:hostile-npc | UNIT_HEALTH | 5 |  |  |
| combat | softenemy:hostile-npc | UNIT_SPELLCAST_INTERRUPTED | 1 | 2:S 3:S 4:S 5:C |  |
| combat | softenemy:hostile-npc | UNIT_SPELLCAST_START | 1 | 2:S 3:S 4:C |  |
| combat | softenemy:hostile-npc | UNIT_SPELLCAST_STOP | 2 | 2:S 3:S 4:C |  |
| combat | softenemy:hostile-npc | UNIT_SPELLCAST_SUCCEEDED | 1 | 2:S 3:S 4:C |  |
| combat | target:hostile-npc | UNIT_AURA | 10 | 2:T | addedAuras:S* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N* |
| combat | target:hostile-npc | UNIT_HEALTH | 40 |  |  |
| combat | target:hostile-npc | UNIT_SPELLCAST_INTERRUPTED | 1 | 2:S 3:S 4:S 5:C |  |
| combat | target:hostile-npc | UNIT_SPELLCAST_START | 3 | 2:S 3:S 4:C |  |
| combat | target:hostile-npc | UNIT_SPELLCAST_STOP | 5 | 2:S 3:S 4:C |  |
| combat | target:hostile-npc | UNIT_SPELLCAST_SUCCEEDED | 4 | 2:S 3:S 4:C |  |
| combat | targettarget:self | UNIT_AURA | 11 | 2:T | addedAuras:N* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N* |
| combat | targettarget:self | UNIT_HEALTH | 47 |  |  |
| combat | targettarget:self | UNIT_SPELLCAST_FAILED | 4 | 2:C 3:C 4:N |  |
| combat | targettarget:self | UNIT_SPELLCAST_START | 2 | 2:C 3:C 4:C |  |
| combat | targettarget:self | UNIT_SPELLCAST_STOP | 2 | 2:C 3:C 4:C |  |
| combat | targettarget:self | UNIT_SPELLCAST_SUCCEEDED | 14 | 2:C 3:C 4:N* |  |
| ooc | nameplate:hostile-npc | UNIT_SPELLCAST_START | 1 | 2:S 3:S 4:C |  |
| ooc | player | UNIT_AURA | 10 | 2:K | addedAuras:K* addedAuras[1].applications:C addedAuras[1].auraInstanceID:C addedAuras[1].canActivePlayerDispel:C addedAuras[1].canApplyAura:C addedAuras[1].dispelName:C addedAuras[1].duration:C addedAu |
| ooc | player | UNIT_HEALTH | 14 |  |  |
| ooc | player | UNIT_SPELLCAST_START | 1 | 2:C 3:C 4:C |  |
| ooc | player | UNIT_SPELLCAST_STOP | 2 | 2:C 3:C 4:C |  |
| ooc | player | UNIT_SPELLCAST_SUCCEEDED | 11 | 2:C 3:C 4:N* |  |
| ooc | target:hostile-npc | UNIT_SPELLCAST_START | 1 | 2:S 3:S 4:C |  |

## Mismatches with the docs (0)

none
