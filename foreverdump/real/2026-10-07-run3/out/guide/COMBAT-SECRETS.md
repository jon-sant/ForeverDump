# Combat secrets matrix

Item x unit class x context. Cell = observed code (documented class in brackets); **bold** = mismatch with the
70245 docs. Codes: N nil, S secret, T container w/ secrets, K container clear, C clear, E error, * mixed.

## Detectability (yes / partial / no / n/a per unit class x context)

**Is it casting/channelling?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| focus:self | yes | yes | idle (nil return is readable) |
| mouseover:hostile-npc | yes | yes | idle (nil return is readable) |
| mouseover:self | yes | yes | idle (nil return is readable) |
| nameplate:hostile-npc | yes | yes | idle (nil return is readable) |
| player | yes | yes | idle (nil return is readable) |
| target:hostile-npc | yes | yes | idle (nil return is readable) |
| target:self | yes | yes | cast (non-nil return) |
| targettarget:self | yes | yes | idle (nil return is readable) |

**Which spell?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| focus:self | n/a | n/a | spellID=C name=C texture=C notInterruptible=C |
| mouseover:hostile-npc | n/a | n/a |  |
| mouseover:self | n/a | n/a |  |
| nameplate:hostile-npc | n/a | n/a |  |
| player | n/a | n/a |  |
| target:hostile-npc | n/a | n/a |  |
| target:self | n/a | n/a | spellID=C name=C texture=C notInterruptible=C |
| targettarget:self | n/a | n/a |  |

**Any buff/debuff?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| focus:self | yes | no | aura APIs error |
| nameplate:hostile-npc | yes | no | aura APIs error |
| player | yes | no | aura APIs error |
| target:hostile-npc | yes | no | aura APIs error |
| target:self | yes | no | aura APIs error |

**MY buff/debuff?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| focus:self | yes | no | aura APIs error |
| nameplate:hostile-npc | yes | no | aura APIs error |
| player | yes | no | aura APIs error |
| target:hostile-npc | yes | no | aura APIs error |
| target:self | yes | no | aura APIs error |

**WHAT aura?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| focus:self | yes | n/a | spellId=C name=C icon=C |
| nameplate:hostile-npc | n/a | n/a |  |
| player | yes | n/a | spellId=C name=C icon=C |
| target:hostile-npc | n/a | n/a |  |
| target:self | yes | n/a | spellId=C name=C icon=C |

**Stacks / duration?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| focus:self | yes | n/a | applications=C duration=C durObj=K |
| nameplate:hostile-npc | n/a | n/a |  |
| player | yes | n/a | applications=C duration=C durObj=K |
| target:hostile-npc | n/a | n/a |  |
| target:self | yes | n/a | applications=C duration=C durObj=K |

**Dispellable?**

| unit class | out of combat | in combat | evidence (last) |
|---|---|---|---|
| focus:self | n/a | n/a |  |
| nameplate:hostile-npc | n/a | n/a |  |
| player | n/a | n/a |  |
| target:hostile-npc | n/a | n/a |  |
| target:self | n/a | n/a |  |

## Matrix

### UnitExists

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitThreatSituation

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [conditional] | N [conditional] |
| 1 | mouseover:hostile-npc | N [conditional] | S [conditional] |
| 1 | mouseover:self | N [conditional] | N [conditional] |
| 1 | nameplate:hostile-npc | N [conditional] | C [conditional] |
| 1 | player | N [conditional] | N [conditional] |
| 1 | target:hostile-npc | N [conditional] | C [conditional] |
| 1 | target:self | N [conditional] | N [conditional] |
| 1 | targettarget:self | N [conditional] | N [conditional] |

### UnitGUID

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [conditional] | C [conditional] |
| 1 | mouseover:hostile-npc | C [conditional] | C [conditional] |
| 1 | mouseover:self | C [conditional] | C [conditional] |
| 1 | nameplate:hostile-npc | C [conditional] | C [conditional] |
| 1 | player | C [conditional] | C [conditional] |
| 1 | target:hostile-npc | C [conditional] | C [conditional] |
| 1 | target:self | C [conditional] | C [conditional] |
| 1 | targettarget:self | C [conditional] | C [conditional] |

### UnitRace

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| raceName | focus:self | C [conditional] | C [conditional] |
| raceName | mouseover:hostile-npc | N [conditional] | N [conditional] |
| raceName | mouseover:self | C [conditional] | C [conditional] |
| raceName | nameplate:hostile-npc | N [conditional] | N [conditional] |
| raceName | player | C [conditional] | C [conditional] |
| raceName | target:hostile-npc | N [conditional] | N [conditional] |
| raceName | target:self | C [conditional] | C [conditional] |
| raceName | targettarget:self | C [conditional] | C [conditional] |
| raceFile | focus:self | C [conditional] | C [conditional] |
| raceFile | mouseover:self | C [conditional] | C [conditional] |
| raceFile | player | C [conditional] | C [conditional] |
| raceFile | target:self | C [conditional] | C [conditional] |
| raceFile | targettarget:self | C [conditional] | C [conditional] |
| raceID | focus:self | C [conditional] | C [conditional] |
| raceID | mouseover:self | C [conditional] | C [conditional] |
| raceID | player | C [conditional] | C [conditional] |
| raceID | target:self | C [conditional] | C [conditional] |
| raceID | targettarget:self | C [conditional] | C [conditional] |

### UnitInRange

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| checked | focus:self | S [always] | S [always] |
| checked | mouseover:hostile-npc | S [always] | S [always] |
| checked | mouseover:self | S [always] | S [always] |
| checked | nameplate:hostile-npc | S [always] | S [always] |
| checked | player | S [always] | S [always] |
| checked | target:hostile-npc | S [always] | S [always] |
| checked | target:self | S [always] | S [always] |
| checked | targettarget:self | S [always] | S [always] |
| inRange | focus:self | S [always] | S [always] |
| inRange | mouseover:hostile-npc | S [always] | S [always] |
| inRange | mouseover:self | S [always] | S [always] |
| inRange | nameplate:hostile-npc | S [always] | S [always] |
| inRange | player | S [always] | S [always] |
| inRange | target:hostile-npc | S [always] | S [always] |
| inRange | target:self | S [always] | S [always] |
| inRange | targettarget:self | S [always] | S [always] |

### UnitIsEnemy

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitClass

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| classFile | focus:self | C [conditional] | C [conditional] |
| classFile | mouseover:hostile-npc | C [conditional] | C [conditional] |
| classFile | mouseover:self | C [conditional] | C [conditional] |
| classFile | nameplate:hostile-npc | C [conditional] | C [conditional] |
| classFile | player | C [conditional] | C [conditional] |
| classFile | target:hostile-npc | C [conditional] | C [conditional] |
| classFile | target:self | C [conditional] | C [conditional] |
| classFile | targettarget:self | C [conditional] | C [conditional] |
| classID | focus:self | C [conditional] | C [conditional] |
| classID | mouseover:hostile-npc | C [conditional] | C [conditional] |
| classID | mouseover:self | C [conditional] | C [conditional] |
| classID | nameplate:hostile-npc | C [conditional] | C [conditional] |
| classID | player | C [conditional] | C [conditional] |
| classID | target:hostile-npc | C [conditional] | C [conditional] |
| classID | target:self | C [conditional] | C [conditional] |
| classID | targettarget:self | C [conditional] | C [conditional] |
| className | focus:self | C [conditional] | C [conditional] |
| className | mouseover:hostile-npc | C [conditional] | C [conditional] |
| className | mouseover:self | C [conditional] | C [conditional] |
| className | nameplate:hostile-npc | C [conditional] | C [conditional] |
| className | player | C [conditional] | C [conditional] |
| className | target:hostile-npc | C [conditional] | C [conditional] |
| className | target:self | C [conditional] | C [conditional] |
| className | targettarget:self | C [conditional] | C [conditional] |

### GetUnitSpeed

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| current | focus:self | C [conditional] | S [conditional] |
| current | mouseover:hostile-npc | C [conditional] | S [conditional] |
| current | mouseover:self | C [conditional] | S [conditional] |
| current | nameplate:hostile-npc | C [conditional] | S [conditional] |
| current | player | C [conditional] | S [conditional] |
| current | target:hostile-npc | C [conditional] | S [conditional] |
| current | target:self | C [conditional] | S [conditional] |
| current | targettarget:self | C [conditional] | S [conditional] |
| flight | focus:self | C [conditional] | S [conditional] |
| flight | mouseover:hostile-npc | C [conditional] | S [conditional] |
| flight | mouseover:self | C [conditional] | S [conditional] |
| flight | nameplate:hostile-npc | C [conditional] | S [conditional] |
| flight | player | C [conditional] | S [conditional] |
| flight | target:hostile-npc | C [conditional] | S [conditional] |
| flight | target:self | C [conditional] | S [conditional] |
| flight | targettarget:self | C [conditional] | S [conditional] |
| run | focus:self | C [conditional] | S [conditional] |
| run | mouseover:hostile-npc | C [conditional] | S [conditional] |
| run | mouseover:self | C [conditional] | S [conditional] |
| run | nameplate:hostile-npc | C [conditional] | S [conditional] |
| run | player | C [conditional] | S [conditional] |
| run | target:hostile-npc | C [conditional] | S [conditional] |
| run | target:self | C [conditional] | S [conditional] |
| run | targettarget:self | C [conditional] | S [conditional] |
| swim | focus:self | C [conditional] | S [conditional] |
| swim | mouseover:hostile-npc | C [conditional] | S [conditional] |
| swim | mouseover:self | C [conditional] | S [conditional] |
| swim | nameplate:hostile-npc | C [conditional] | S [conditional] |
| swim | player | C [conditional] | S [conditional] |
| swim | target:hostile-npc | C [conditional] | S [conditional] |
| swim | target:self | C [conditional] | S [conditional] |
| swim | targettarget:self | C [conditional] | S [conditional] |

### UnitCastingInfo

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| name | focus:self | N* [conditional] | N* [conditional] |
| name | mouseover:hostile-npc | N [conditional] | N [conditional] |
| name | mouseover:self | N [conditional] | N [conditional] |
| name | nameplate:hostile-npc | N [conditional] | N [conditional] |
| name | player | N [conditional] | N [conditional] |
| name | target:hostile-npc | N [conditional] | N [conditional] |
| name | target:self | N [conditional] | C* [conditional] |
| name | targettarget:self | N [conditional] | N [conditional] |
| isTradeSkill | focus:self | C [never] | C [never] |
| isTradeSkill | target:self |  | C [never] |
| notInterruptible | focus:self | C [conditional] | C [conditional] |
| notInterruptible | target:self |  | C [conditional] |
| endTimeMS | focus:self | C [conditional] | C [conditional] |
| endTimeMS | target:self |  | C [conditional] |
| text | focus:self | C [conditional] | C [conditional] |
| text | target:self |  | C [conditional] |
| texture | focus:self | C [conditional] | C [conditional] |
| texture | target:self |  | C [conditional] |
| startTimeMS | focus:self | C [conditional] | C [conditional] |
| startTimeMS | target:self |  | C [conditional] |
| 11 | focus:self | C [never] | C [never] |
| 11 | target:self |  | C [never] |
| 10 | focus:self | C [never] | C [never] |
| 10 | target:self |  | C [never] |
| castID | focus:self | C [conditional] | C [conditional] |
| castID | target:self |  | C [conditional] |
| spellID | focus:self | C [conditional] | C [conditional] |
| spellID | target:self |  | C [conditional] |

### UnitIsUnit(u,player)

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [conditional] | C [conditional] |
| 1 | mouseover:hostile-npc | C [conditional] | C [conditional] |
| 1 | mouseover:self | C [conditional] | C [conditional] |
| 1 | nameplate:hostile-npc | C [conditional] | C [conditional] |
| 1 | player | C [conditional] | C [conditional] |
| 1 | target:hostile-npc | C [conditional] | C [conditional] |
| 1 | target:self | C [conditional] | C [conditional] |
| 1 | targettarget:self | C [conditional] | C [conditional] |

### UnitGetTotalAbsorbs

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | S [always] | S [always] |
| 1 | mouseover:hostile-npc | S [always] | S [always] |
| 1 | mouseover:self | S [always] | S [always] |
| 1 | nameplate:hostile-npc | S [always] | S [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | S [always] | S [always] |
| 1 | target:self | S [always] | S [always] |
| 1 | targettarget:self | S [always] | S [always] |

### GetRaidTargetIndex

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [always] | N [always] |
| 1 | mouseover:hostile-npc | N [always] | N* [always] |
| 1 | mouseover:self | N [always] | N [always] |
| 1 | nameplate:hostile-npc | N* [always] | N* [always] |
| 1 | player | N [always] | N [always] |
| 1 | target:hostile-npc | N [always] | N* [always] |
| 1 | target:self | N [always] | N [always] |
| 1 | targettarget:self | N [always] | N [always] |

### UnitPosition

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| y | focus:self | C [none] | C [none] |
| y | mouseover:hostile-npc | N [none] | N [none] |
| y | mouseover:self | C [none] | C [none] |
| y | nameplate:hostile-npc | N [none] | N [none] |
| y | player | C [none] | C [none] |
| y | target:hostile-npc | N [none] | N [none] |
| y | target:self | C [none] | C [none] |
| y | targettarget:self | C [none] | C [none] |
| x | focus:self | C [none] | C [none] |
| x | mouseover:hostile-npc | N [none] | N [none] |
| x | mouseover:self | C [none] | C [none] |
| x | nameplate:hostile-npc | N [none] | N [none] |
| x | player | C [none] | C [none] |
| x | target:hostile-npc | N [none] | N [none] |
| x | target:self | C [none] | C [none] |
| x | targettarget:self | C [none] | C [none] |
| mapID | focus:self | C [none] | C [none] |
| mapID | mouseover:hostile-npc | C [none] | C [none] |
| mapID | mouseover:self | C [none] | C [none] |
| mapID | nameplate:hostile-npc | C [none] | C [none] |
| mapID | player | C [none] | C [none] |
| mapID | target:hostile-npc | C [none] | C [none] |
| mapID | target:self | C [none] | C [none] |
| mapID | targettarget:self | C [none] | C [none] |
| z | focus:self | C [none] | C [none] |
| z | mouseover:hostile-npc | N [none] | N [none] |
| z | mouseover:self | C [none] | C [none] |
| z | nameplate:hostile-npc | N [none] | N [none] |
| z | player | C [none] | C [none] |
| z | target:hostile-npc | N [none] | N [none] |
| z | target:self | C [none] | C [none] |
| z | targettarget:self | C [none] | C [none] |

### UnitFullName

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| name | focus:self | C [conditional] | C [conditional] |
| name | mouseover:hostile-npc | C [conditional] | C [conditional] |
| name | mouseover:self | C [conditional] | C [conditional] |
| name | nameplate:hostile-npc | C [conditional] | C [conditional] |
| name | player | C [conditional] | C [conditional] |
| name | target:hostile-npc | C [conditional] | C [conditional] |
| name | target:self | C [conditional] | C [conditional] |
| name | targettarget:self | C [conditional] | C [conditional] |
| realm | focus:self | C [conditional] | C [conditional] |
| realm | mouseover:hostile-npc | N [conditional] | N [conditional] |
| realm | mouseover:self | C [conditional] | C [conditional] |
| realm | nameplate:hostile-npc | N [conditional] | N [conditional] |
| realm | player | C [conditional] | C [conditional] |
| realm | target:hostile-npc | N [conditional] | N [conditional] |
| realm | target:self | C [conditional] | C [conditional] |
| realm | targettarget:self | C [conditional] | C [conditional] |

### UnitGetIncomingHeals

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | S [always] | S [always] |
| 1 | mouseover:hostile-npc | N [always] | N [always] |
| 1 | mouseover:self | S [always] | S [always] |
| 1 | nameplate:hostile-npc | N [always] | N [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | N [always] | N [always] |
| 1 | target:self | S [always] | S [always] |
| 1 | targettarget:self | S [always] | S [always] |

### UnitPower

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | S [conditional] | S [conditional] |
| 1 | mouseover:hostile-npc | S [conditional] | S [conditional] |
| 1 | mouseover:self | S [conditional] | S [conditional] |
| 1 | nameplate:hostile-npc | S [conditional] | S [conditional] |
| 1 | player | S [conditional] | S [conditional] |
| 1 | target:hostile-npc | S [conditional] | S [conditional] |
| 1 | target:self | S [conditional] | S [conditional] |
| 1 | targettarget:self | S [conditional] | S [conditional] |

### UnitIsFriend

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitHealth

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | S [always] | S [always] |
| 1 | mouseover:hostile-npc | S [always] | S [always] |
| 1 | mouseover:self | S [always] | S [always] |
| 1 | nameplate:hostile-npc | S [always] | S [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | S [always] | S [always] |
| 1 | target:self | S [always] | S [always] |
| 1 | targettarget:self | S [always] | S [always] |

### UnitGetTotalHealAbsorbs

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | S [always] | S [always] |
| 1 | mouseover:hostile-npc | S [always] | S [always] |
| 1 | mouseover:self | S [always] | S [always] |
| 1 | nameplate:hostile-npc | S [always] | S [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | S [always] | S [always] |
| 1 | target:self | S [always] | S [always] |
| 1 | targettarget:self | S [always] | S [always] |

### UnitLevel

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### CheckInteractDistance

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitCanAttack

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitReaction

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitIsDeadOrGhost

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitName

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| name | focus:self | C [conditional] | C [conditional] |
| name | mouseover:hostile-npc | C [conditional] | C [conditional] |
| name | mouseover:self | C [conditional] | C [conditional] |
| name | nameplate:hostile-npc | C [conditional] | C [conditional] |
| name | player | C [conditional] | C [conditional] |
| name | target:hostile-npc | C [conditional] | C [conditional] |
| name | target:self | C [conditional] | C [conditional] |
| name | targettarget:self | C [conditional] | C [conditional] |
| realm | focus:self | C [conditional] | C [conditional] |
| realm | mouseover:hostile-npc | N [conditional] | N [conditional] |
| realm | mouseover:self | C [conditional] | C [conditional] |
| realm | nameplate:hostile-npc | N [conditional] | N [conditional] |
| realm | player | C [conditional] | C [conditional] |
| realm | target:hostile-npc | N [conditional] | N [conditional] |
| realm | target:self | C [conditional] | C [conditional] |
| realm | targettarget:self | C [conditional] | C [conditional] |

### UnitChannelInfo

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| name | focus:self | N [conditional] | N [conditional] |
| name | mouseover:hostile-npc | N [conditional] | N [conditional] |
| name | mouseover:self | N [conditional] | N [conditional] |
| name | nameplate:hostile-npc | N [conditional] | N [conditional] |
| name | player | N [conditional] | N [conditional] |
| name | target:hostile-npc | N [conditional] | N [conditional] |
| name | target:self | N [conditional] | N [conditional] |
| name | targettarget:self | N [conditional] | N [conditional] |

### C_Spell.IsSpellInRange

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [none] | N [none] |
| 1 | mouseover:hostile-npc | N [none] | N [none] |
| 1 | mouseover:self | N [none] | N [none] |
| 1 | nameplate:hostile-npc | N [none] | N [none] |
| 1 | player | N [none] | N [none] |
| 1 | target:hostile-npc | N [none] | N [none] |
| 1 | target:self | N [none] | N [none] |
| 1 | targettarget:self | N [none] | N [none] |

### UnitHealthMax

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [conditional] | C [conditional] |
| 1 | mouseover:hostile-npc | S [conditional] | S [conditional] |
| 1 | mouseover:self | C [conditional] | C [conditional] |
| 1 | nameplate:hostile-npc | S [conditional] | S [conditional] |
| 1 | player | C [conditional] | C [conditional] |
| 1 | target:hostile-npc | S [conditional] | S [conditional] |
| 1 | target:self | C [conditional] | C [conditional] |
| 1 | targettarget:self | C [conditional] | C [conditional] |

### UnitAffectingCombat

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitPowerMax

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [conditional] | C [conditional] |
| 1 | mouseover:hostile-npc | S [conditional] | S [conditional] |
| 1 | mouseover:self | C [conditional] | C [conditional] |
| 1 | nameplate:hostile-npc | S [conditional] | S [conditional] |
| 1 | player | C [conditional] | C [conditional] |
| 1 | target:hostile-npc | S [conditional] | S [conditional] |
| 1 | target:self | C [conditional] | C [conditional] |
| 1 | targettarget:self | C [conditional] | C [conditional] |

### UnitPowerType

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| powerType | focus:self | C [none] | C [none] |
| powerType | mouseover:hostile-npc | C [none] | C [none] |
| powerType | mouseover:self | C [none] | C [none] |
| powerType | nameplate:hostile-npc | C [none] | C [none] |
| powerType | player | C [none] | C [none] |
| powerType | target:hostile-npc | C [none] | C [none] |
| powerType | target:self | C [none] | C [none] |
| powerType | targettarget:self | C [none] | C [none] |
| 3 | focus:self | N [none] | N [none] |
| 3 | mouseover:hostile-npc | N [none] | N [none] |
| 3 | mouseover:self | N [none] | N [none] |
| 3 | nameplate:hostile-npc | N [none] | N [none] |
| 3 | player | N [none] | N [none] |
| 3 | target:hostile-npc | N [none] | N [none] |
| 3 | target:self | N [none] | N [none] |
| 3 | targettarget:self | N [none] | N [none] |
| powerToken | focus:self | C [none] | C [none] |
| powerToken | mouseover:hostile-npc | C [none] | C [none] |
| powerToken | mouseover:self | C [none] | C [none] |
| powerToken | nameplate:hostile-npc | C [none] | C [none] |
| powerToken | player | C [none] | C [none] |
| powerToken | target:hostile-npc | C [none] | C [none] |
| powerToken | target:self | C [none] | C [none] |
| powerToken | targettarget:self | C [none] | C [none] |
| 5 | focus:self | N [none] | N [none] |
| 5 | mouseover:hostile-npc | N [none] | N [none] |
| 5 | mouseover:self | N [none] | N [none] |
| 5 | nameplate:hostile-npc | N [none] | N [none] |
| 5 | player | N [none] | N [none] |
| 5 | target:hostile-npc | N [none] | N [none] |
| 5 | target:self | N [none] | N [none] |
| 5 | targettarget:self | N [none] | N [none] |
| 4 | focus:self | N [none] | N [none] |
| 4 | mouseover:hostile-npc | N [none] | N [none] |
| 4 | mouseover:self | N [none] | N [none] |
| 4 | nameplate:hostile-npc | N [none] | N [none] |
| 4 | player | N [none] | N [none] |
| 4 | target:hostile-npc | N [none] | N [none] |
| 4 | target:self | N [none] | N [none] |
| 4 | targettarget:self | N [none] | N [none] |

### ShouldUnitIdentityBeSecret

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitIsPlayer

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### UnitDetailedThreatSituation

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| scaledPct | mouseover:hostile-npc |  | S [conditional] |
| scaledPct | nameplate:hostile-npc |  | S [conditional] |
| scaledPct | target:hostile-npc |  | C [conditional] |
| status | mouseover:hostile-npc |  | S [conditional] |
| status | nameplate:hostile-npc |  | S [conditional] |
| status | target:hostile-npc |  | C [conditional] |
| isTanking | focus:self | N [conditional] | N [conditional] |
| isTanking | mouseover:hostile-npc | N [conditional] | S [conditional] |
| isTanking | mouseover:self | N [conditional] | N [conditional] |
| isTanking | nameplate:hostile-npc | N [conditional] | S [conditional] |
| isTanking | player | N [conditional] | N [conditional] |
| isTanking | target:hostile-npc | N [conditional] | C [conditional] |
| isTanking | target:self | N [conditional] | N [conditional] |
| isTanking | targettarget:self | N [conditional] | N [conditional] |
| rawPct | mouseover:hostile-npc |  | S [conditional] |
| rawPct | nameplate:hostile-npc |  | S [conditional] |
| rawPct | target:hostile-npc |  | C [conditional] |
| rawThreat | mouseover:hostile-npc |  | S [conditional] |
| rawThreat | nameplate:hostile-npc |  | S [conditional] |
| rawThreat | target:hostile-npc |  | C [conditional] |

### UnitHealthPercent

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | S [always] | S [always] |
| 1 | mouseover:hostile-npc | S [always] | S [always] |
| 1 | mouseover:self | S [always] | S [always] |
| 1 | nameplate:hostile-npc | S [always] | S [always] |
| 1 | player | S [always] | S [always] |
| 1 | target:hostile-npc | S [always] | S [always] |
| 1 | target:self | S [always] | S [always] |
| 1 | targettarget:self | S [always] | S [always] |

### CanCompareUnitTokens

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | mouseover:hostile-npc | C [none] | C [none] |
| 1 | mouseover:self | C [none] | C [none] |
| 1 | nameplate:hostile-npc | C [none] | C [none] |
| 1 | player | C [none] | C [none] |
| 1 | target:hostile-npc | C [none] | C [none] |
| 1 | target:self | C [none] | C [none] |
| 1 | targettarget:self | C [none] | C [none] |

### C_Map.GetPlayerMapPosition

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [none] | K [none] |
| 1 | mouseover:hostile-npc | N [none] | N [none] |
| 1 | mouseover:self | K [none] | K [none] |
| 1 | nameplate:hostile-npc | N [none] | N [none] |
| 1 | player | K [none] | K [none] |
| 1 | target:hostile-npc | N [none] | N [none] |
| 1 | target:self | K [none] | K [none] |
| 1 | targettarget:self | K [none] | K [none] |
| .RotateDirection | focus:self | C [none] | C [none] |
| .RotateDirection | mouseover:self | C [none] | C [none] |
| .RotateDirection | player | C [none] | C [none] |
| .RotateDirection | target:self | C [none] | C [none] |
| .RotateDirection | targettarget:self | C [none] | C [none] |
| .GetLength | focus:self | C [none] | C [none] |
| .GetLength | mouseover:self | C [none] | C [none] |
| .GetLength | player | C [none] | C [none] |
| .GetLength | target:self | C [none] | C [none] |
| .GetLength | targettarget:self | C [none] | C [none] |
| .Normalize | focus:self | C [none] | C [none] |
| .Normalize | mouseover:self | C [none] | C [none] |
| .Normalize | player | C [none] | C [none] |
| .Normalize | target:self | C [none] | C [none] |
| .Normalize | targettarget:self | C [none] | C [none] |
| .Dot | focus:self | C [none] | C [none] |
| .Dot | mouseover:self | C [none] | C [none] |
| .Dot | player | C [none] | C [none] |
| .Dot | target:self | C [none] | C [none] |
| .Dot | targettarget:self | C [none] | C [none] |
| .GetLengthSquared | focus:self | C [none] | C [none] |
| .GetLengthSquared | mouseover:self | C [none] | C [none] |
| .GetLengthSquared | player | C [none] | C [none] |
| .GetLengthSquared | target:self | C [none] | C [none] |
| .GetLengthSquared | targettarget:self | C [none] | C [none] |
| .GetXY | focus:self | C [none] | C [none] |
| .GetXY | mouseover:self | C [none] | C [none] |
| .GetXY | player | C [none] | C [none] |
| .GetXY | target:self | C [none] | C [none] |
| .GetXY | targettarget:self | C [none] | C [none] |
| .OnLoad | focus:self | C [none] | C [none] |
| .OnLoad | mouseover:self | C [none] | C [none] |
| .OnLoad | player | C [none] | C [none] |
| .OnLoad | target:self | C [none] | C [none] |
| .OnLoad | targettarget:self | C [none] | C [none] |
| .IsZero | focus:self | C [none] | C [none] |
| .IsZero | mouseover:self | C [none] | C [none] |
| .IsZero | player | C [none] | C [none] |
| .IsZero | target:self | C [none] | C [none] |
| .IsZero | targettarget:self | C [none] | C [none] |
| .DivideBy | focus:self | C [none] | C [none] |
| .DivideBy | mouseover:self | C [none] | C [none] |
| .DivideBy | player | C [none] | C [none] |
| .DivideBy | target:self | C [none] | C [none] |
| .DivideBy | targettarget:self | C [none] | C [none] |
| .x | focus:self | C [none] | C [none] |
| .x | mouseover:self | C [none] | C [none] |
| .x | player | C [none] | C [none] |
| .x | target:self | C [none] | C [none] |
| .x | targettarget:self | C [none] | C [none] |
| .y | focus:self | C [none] | C [none] |
| .y | mouseover:self | C [none] | C [none] |
| .y | player | C [none] | C [none] |
| .y | target:self | C [none] | C [none] |
| .y | targettarget:self | C [none] | C [none] |
| .Subtract | focus:self | C [none] | C [none] |
| .Subtract | mouseover:self | C [none] | C [none] |
| .Subtract | player | C [none] | C [none] |
| .Subtract | target:self | C [none] | C [none] |
| .Subtract | targettarget:self | C [none] | C [none] |
| .Clone | focus:self | C [none] | C [none] |
| .Clone | mouseover:self | C [none] | C [none] |
| .Clone | player | C [none] | C [none] |
| .Clone | target:self | C [none] | C [none] |
| .Clone | targettarget:self | C [none] | C [none] |
| .Cross | focus:self | C [none] | C [none] |
| .Cross | mouseover:self | C [none] | C [none] |
| .Cross | player | C [none] | C [none] |
| .Cross | target:self | C [none] | C [none] |
| .Cross | targettarget:self | C [none] | C [none] |
| .IsEqualTo | focus:self | C [none] | C [none] |
| .IsEqualTo | mouseover:self | C [none] | C [none] |
| .IsEqualTo | player | C [none] | C [none] |
| .IsEqualTo | target:self | C [none] | C [none] |
| .IsEqualTo | targettarget:self | C [none] | C [none] |
| .SetXY | focus:self | C [none] | C [none] |
| .SetXY | mouseover:self | C [none] | C [none] |
| .SetXY | player | C [none] | C [none] |
| .SetXY | target:self | C [none] | C [none] |
| .SetXY | targettarget:self | C [none] | C [none] |
| .ScaleBy | focus:self | C [none] | C [none] |
| .ScaleBy | mouseover:self | C [none] | C [none] |
| .ScaleBy | player | C [none] | C [none] |
| .ScaleBy | target:self | C [none] | C [none] |
| .ScaleBy | targettarget:self | C [none] | C [none] |
| .Add | focus:self | C [none] | C [none] |
| .Add | mouseover:self | C [none] | C [none] |
| .Add | player | C [none] | C [none] |
| .Add | target:self | C [none] | C [none] |
| .Add | targettarget:self | C [none] | C [none] |

### C_DamageMeter.GetCombatSessionFromType

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | global | K [conditional] | T [conditional] |
| .durationSeconds | global | C [conditional] | S [conditional] |
| .combatSources | global | K [conditional] | K [conditional] |
| .maxAmount | global | C [conditional] | S [conditional] |
| .totalAmount | global | C [conditional] | S [conditional] |

### C_DamageMeter.IsDamageMeterAvailable

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | global | C [none] | C [none] |
| 2 | global | C [none] | C [none] |

### UnitCastingDuration

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [always] | K [always] |
| 1 | target:self |  | K [always] |

### casting:GetSpellCastSecrecy

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [none] | C [none] |
| 1 | target:self |  | C [none] |

### IsSwimming

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] | C [none] |

### IsFlying

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] | C [none] |

### IsFalling

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] | C [none] |

### GetPlayerFacing

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] | C [none] |

### aura:GetAuraSlots[HARMFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [none] |  |
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |
| 1 | target:self | N [none] |  |

### aura:GetAuraDataByIndex[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [conditional] |  |
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | K [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |
| 1 | target:self | K [conditional] |  |
| .spellId | focus:self | C [conditional] |  |
| .spellId | player | C [conditional] |  |
| .spellId | target:self | C [conditional] |  |
| .isBossAura | focus:self | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .isBossAura | target:self | C [conditional] |  |
| .isStealable | focus:self | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .isStealable | target:self | C [conditional] |  |
| .hideOnPartyFrames | focus:self | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .hideOnPartyFrames | target:self | C [conditional] |  |
| .expirationTime | focus:self | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .expirationTime | target:self | C [conditional] |  |
| .isFromPlayerOrPlayerPet | focus:self | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | target:self | C [conditional] |  |
| .timeMod | focus:self | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .timeMod | target:self | C [conditional] |  |
| .points | focus:self | K [conditional] |  |
| .points | player | K [conditional] |  |
| .points | target:self | K [conditional] |  |
| .icon | focus:self | C [conditional] |  |
| .icon | player | C [conditional] |  |
| .icon | target:self | C [conditional] |  |
| .nameplateShowPersonal | focus:self | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .nameplateShowPersonal | target:self | C [conditional] |  |
| .duration | focus:self | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .duration | target:self | C [conditional] |  |
| .auraInstanceID | focus:self | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .auraInstanceID | target:self | C [conditional] |  |
| .dispelName | focus:self | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .dispelName | target:self | C [conditional] |  |
| .nameplateShowAll | focus:self | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .nameplateShowAll | target:self | C [conditional] |  |
| .isHelpful | focus:self | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .isHelpful | target:self | C [conditional] |  |
| .isRaid | focus:self | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .isRaid | target:self | C [conditional] |  |
| .canActivePlayerDispel | focus:self | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .canActivePlayerDispel | target:self | C [conditional] |  |
| .isTankRoleAura | focus:self | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isTankRoleAura | target:self | C [conditional] |  |
| .isHarmful | focus:self | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .isHarmful | target:self | C [conditional] |  |
| .canApplyAura | focus:self | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .canApplyAura | target:self | C [conditional] |  |
| .name | focus:self | C [conditional] |  |
| .name | player | C [conditional] |  |
| .name | target:self | C [conditional] |  |
| .isDPSRoleAura | focus:self | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .isDPSRoleAura | target:self | C [conditional] |  |
| .applications | focus:self | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .applications | target:self | C [conditional] |  |
| .isNameplateOnly | focus:self | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .isNameplateOnly | target:self | C [conditional] |  |
| .sourceUnit | focus:self | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | focus:self | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |
| .isHealerRoleAura | target:self | C [conditional] |  |

### aura:GetUnitAuras[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [none] |  |
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |
| 1 | target:self | K [none] |  |

### aura:GetAuraDataBySlot[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [conditional] |  |
| 1 | player | K [conditional] |  |
| 1 | target:self | K [conditional] |  |
| .spellId | focus:self | C [conditional] |  |
| .spellId | player | C [conditional] |  |
| .spellId | target:self | C [conditional] |  |
| .isBossAura | focus:self | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .isBossAura | target:self | C [conditional] |  |
| .isStealable | focus:self | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .isStealable | target:self | C [conditional] |  |
| .hideOnPartyFrames | focus:self | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .hideOnPartyFrames | target:self | C [conditional] |  |
| .expirationTime | focus:self | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .expirationTime | target:self | C [conditional] |  |
| .isFromPlayerOrPlayerPet | focus:self | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | target:self | C [conditional] |  |
| .timeMod | focus:self | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .timeMod | target:self | C [conditional] |  |
| .points | focus:self | K [conditional] |  |
| .points | player | K [conditional] |  |
| .points | target:self | K [conditional] |  |
| .icon | focus:self | C [conditional] |  |
| .icon | player | C [conditional] |  |
| .icon | target:self | C [conditional] |  |
| .nameplateShowPersonal | focus:self | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .nameplateShowPersonal | target:self | C [conditional] |  |
| .duration | focus:self | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .duration | target:self | C [conditional] |  |
| .auraInstanceID | focus:self | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .auraInstanceID | target:self | C [conditional] |  |
| .dispelName | focus:self | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .dispelName | target:self | C [conditional] |  |
| .nameplateShowAll | focus:self | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .nameplateShowAll | target:self | C [conditional] |  |
| .isHelpful | focus:self | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .isHelpful | target:self | C [conditional] |  |
| .isRaid | focus:self | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .isRaid | target:self | C [conditional] |  |
| .canActivePlayerDispel | focus:self | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .canActivePlayerDispel | target:self | C [conditional] |  |
| .isTankRoleAura | focus:self | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isTankRoleAura | target:self | C [conditional] |  |
| .isHarmful | focus:self | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .isHarmful | target:self | C [conditional] |  |
| .canApplyAura | focus:self | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .canApplyAura | target:self | C [conditional] |  |
| .name | focus:self | C [conditional] |  |
| .name | player | C [conditional] |  |
| .name | target:self | C [conditional] |  |
| .isDPSRoleAura | focus:self | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .isDPSRoleAura | target:self | C [conditional] |  |
| .applications | focus:self | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .applications | target:self | C [conditional] |  |
| .isNameplateOnly | focus:self | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .isNameplateOnly | target:self | C [conditional] |  |
| .sourceUnit | focus:self | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | focus:self | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |
| .isHealerRoleAura | target:self | C [conditional] |  |

### aura:GetAuraSlots[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [none] |  |
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |
| 1 | target:self | N [none] |  |
| 2 | focus:self | C [none] |  |
| 2 | player | C [none] |  |

### aura:GetAuraDataBySlot[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [conditional] |  |
| 1 | player | K [conditional] |  |
| .spellId | focus:self | C [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | focus:self | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | focus:self | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | focus:self | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | focus:self | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | focus:self | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | focus:self | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | focus:self | K [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | focus:self | C [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | focus:self | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | focus:self | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | focus:self | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | focus:self | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .nameplateShowAll | focus:self | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isHelpful | focus:self | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .isRaid | focus:self | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | focus:self | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | focus:self | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | focus:self | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | focus:self | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | focus:self | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | focus:self | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | focus:self | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | focus:self | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | focus:self | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | focus:self | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetUnitAuras[HARMFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [none] |  |
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |
| 1 | target:self | K [none] |  |

### aura:GetAuraDataByIndex[HARMFUL|RAID]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [conditional] |  |
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | N [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |
| 1 | target:self | N [conditional] |  |

### aura:GetUnitAuras[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [none] |  |
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |
| 1 | target:self | K [none] |  |

### aura:GetAuraApplicationDisplayCount[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [conditional] |  |
| 1 | player | C [conditional] |  |

### aura:GetAuraDataByAuraInstanceID[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [conditional] |  |
| 1 | player | K [conditional] |  |
| 1 | target:self | K [conditional] |  |
| .spellId | focus:self | C [conditional] |  |
| .spellId | player | C [conditional] |  |
| .spellId | target:self | C [conditional] |  |
| .isBossAura | focus:self | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .isBossAura | target:self | C [conditional] |  |
| .isStealable | focus:self | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .isStealable | target:self | C [conditional] |  |
| .hideOnPartyFrames | focus:self | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .hideOnPartyFrames | target:self | C [conditional] |  |
| .expirationTime | focus:self | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .expirationTime | target:self | C [conditional] |  |
| .isFromPlayerOrPlayerPet | focus:self | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | target:self | C [conditional] |  |
| .timeMod | focus:self | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .timeMod | target:self | C [conditional] |  |
| .points | focus:self | K [conditional] |  |
| .points | player | K [conditional] |  |
| .points | target:self | K [conditional] |  |
| .icon | focus:self | C [conditional] |  |
| .icon | player | C [conditional] |  |
| .icon | target:self | C [conditional] |  |
| .nameplateShowPersonal | focus:self | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .nameplateShowPersonal | target:self | C [conditional] |  |
| .duration | focus:self | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .duration | target:self | C [conditional] |  |
| .auraInstanceID | focus:self | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .auraInstanceID | target:self | C [conditional] |  |
| .dispelName | focus:self | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .dispelName | target:self | C [conditional] |  |
| .nameplateShowAll | focus:self | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .nameplateShowAll | target:self | C [conditional] |  |
| .isHelpful | focus:self | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .isHelpful | target:self | C [conditional] |  |
| .isRaid | focus:self | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .isRaid | target:self | C [conditional] |  |
| .canActivePlayerDispel | focus:self | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .canActivePlayerDispel | target:self | C [conditional] |  |
| .isTankRoleAura | focus:self | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isTankRoleAura | target:self | C [conditional] |  |
| .isHarmful | focus:self | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .isHarmful | target:self | C [conditional] |  |
| .canApplyAura | focus:self | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .canApplyAura | target:self | C [conditional] |  |
| .name | focus:self | C [conditional] |  |
| .name | player | C [conditional] |  |
| .name | target:self | C [conditional] |  |
| .isDPSRoleAura | focus:self | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .isDPSRoleAura | target:self | C [conditional] |  |
| .applications | focus:self | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .applications | target:self | C [conditional] |  |
| .isNameplateOnly | focus:self | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .isNameplateOnly | target:self | C [conditional] |  |
| .sourceUnit | focus:self | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | focus:self | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |
| .isHealerRoleAura | target:self | C [conditional] |  |

### aura:GetAuraApplicationDisplayCount[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | C [conditional] |  |
| 1 | player | C [conditional] |  |
| 1 | target:self | C [conditional] |  |

### aura:GetAuraDataByIndex[HARMFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [conditional] |  |
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | N [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |
| 1 | target:self | N [conditional] |  |

### aura:GetAuraDataByIndex[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N* [conditional] |  |
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | N* [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |
| 1 | target:self | N [conditional] |  |
| .spellId | focus:self | C [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | focus:self | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | focus:self | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | focus:self | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | focus:self | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | focus:self | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | focus:self | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | focus:self | K [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | focus:self | C [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | focus:self | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | focus:self | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | focus:self | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | focus:self | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .nameplateShowAll | focus:self | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isHelpful | focus:self | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .isRaid | focus:self | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | focus:self | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | focus:self | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | focus:self | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | focus:self | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | focus:self | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | focus:self | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | focus:self | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | focus:self | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | focus:self | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | focus:self | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetAuraDataByIndex[HARMFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [conditional] |  |
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | N [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |
| 1 | target:self | N [conditional] |  |

### aura:GetUnitAuras[HARMFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [none] |  |
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |
| 1 | target:self | K [none] |  |

### aura:GetAuraSlots[HARMFUL|RAID_PLAYER_DISPELLABLE]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [none] |  |
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |
| 1 | target:self | N [none] |  |

### aura:GetAuraSlots[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [none] |  |
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |
| 1 | target:self | N [none] |  |
| 2 | focus:self | C [none] |  |
| 2 | player | C [none] |  |
| 2 | target:self | C [none] |  |
| 3 | focus:self | C [none] |  |
| 3 | player | C [none] |  |
| 3 | target:self | C [none] |  |

### aura:GetAuraSlots[HARMFUL|RAID]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [none] |  |
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |
| 1 | target:self | N [none] |  |

### aura:GetAuraDuration[HELPFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:self | K [none] |  |

### aura:GetAuraDataByIndex[HARMFUL|RAID_PLAYER_DISPELLABLE]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [conditional] |  |
| 1 | nameplate:hostile-npc | N [conditional] |  |
| 1 | player | N [conditional] |  |
| 1 | target:hostile-npc | N [conditional] |  |
| 1 | target:self | N [conditional] |  |

### aura:GetAuraSlots[HARMFUL]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | N [none] |  |
| 1 | nameplate:hostile-npc | N [none] |  |
| 1 | player | N [none] |  |
| 1 | target:hostile-npc | N [none] |  |
| 1 | target:self | N [none] |  |

### aura:GetUnitAuras[HARMFUL|RAID]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [none] |  |
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |
| 1 | target:self | K [none] |  |

### aura:GetUnitAuras[HARMFUL|RAID_PLAYER_DISPELLABLE]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [none] |  |
| 1 | nameplate:hostile-npc | K [none] |  |
| 1 | player | K [none] |  |
| 1 | target:hostile-npc | K [none] |  |
| 1 | target:self | K [none] |  |

### aura:GetAuraDataByAuraInstanceID[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [conditional] |  |
| 1 | player | K [conditional] |  |
| .spellId | focus:self | C [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | focus:self | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .duration | focus:self | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .hideOnPartyFrames | focus:self | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | focus:self | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | focus:self | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | focus:self | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | focus:self | K [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | focus:self | C [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | focus:self | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .isStealable | focus:self | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .auraInstanceID | focus:self | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | focus:self | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .nameplateShowAll | focus:self | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isHelpful | focus:self | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
| .isRaid | focus:self | C [conditional] |  |
| .isRaid | player | C [conditional] |  |
| .canActivePlayerDispel | focus:self | C [conditional] |  |
| .canActivePlayerDispel | player | C [conditional] |  |
| .isTankRoleAura | focus:self | C [conditional] |  |
| .isTankRoleAura | player | C [conditional] |  |
| .isHarmful | focus:self | C [conditional] |  |
| .isHarmful | player | C [conditional] |  |
| .canApplyAura | focus:self | C [conditional] |  |
| .canApplyAura | player | C [conditional] |  |
| .name | focus:self | C [conditional] |  |
| .name | player | C [conditional] |  |
| .isDPSRoleAura | focus:self | C [conditional] |  |
| .isDPSRoleAura | player | C [conditional] |  |
| .applications | focus:self | C [conditional] |  |
| .applications | player | C [conditional] |  |
| .isNameplateOnly | focus:self | C [conditional] |  |
| .isNameplateOnly | player | C [conditional] |  |
| .sourceUnit | focus:self | C [conditional] |  |
| .sourceUnit | player | C [conditional] |  |
| .isHealerRoleAura | focus:self | C [conditional] |  |
| .isHealerRoleAura | player | C [conditional] |  |

### aura:GetAuraDuration[HELPFUL|PLAYER]

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | focus:self | K [none] |  |
| 1 | player | K [none] |  |

### aura:GetPlayerAuraBySpellID

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | K [conditional] |  |
| .spellId | player | C [conditional] |  |
| .isBossAura | player | C [conditional] |  |
| .isStealable | player | C [conditional] |  |
| .hideOnPartyFrames | player | C [conditional] |  |
| .expirationTime | player | C [conditional] |  |
| .isFromPlayerOrPlayerPet | player | C [conditional] |  |
| .timeMod | player | C [conditional] |  |
| .points | player | K [conditional] |  |
| .icon | player | C [conditional] |  |
| .nameplateShowPersonal | player | C [conditional] |  |
| .duration | player | C [conditional] |  |
| .auraInstanceID | player | C [conditional] |  |
| .dispelName | player | C [conditional] |  |
| .nameplateShowAll | player | C [conditional] |  |
| .isHelpful | player | C [conditional] |  |
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

### aura:ShouldSpellAuraBeSecret

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] |  |

### aura:GetSpellAuraSecrecy

| return/field | unit class | out of combat | in combat |
|---|---|---|---|
| 1 | player | C [none] |  |

## Cast / channel time left

Derived `endTimeMS - GetTime()*1000` vs the sanctioned duration object.

| ctx / unit class | endTimeMS | derived | error | duration object | HasSecretValues | GetRemainingDuration |
|---|---|---|---|---|---|---|
| combat|focus:self | C | ok |  | K | C | C |
| combat|target:self | C | ok |  | K | C | C |
| ooc|focus:self | C | ok |  | K | C | C |

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
| combat | focus:self | UNIT_AURA | 14 | 2:T | addedAuras:N* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N* |
| combat | focus:self | UNIT_HEALTH | 128 |  |  |
| combat | focus:self | UNIT_SPELLCAST_DELAYED | 5 | 2:C 3:C 4:C |  |
| combat | focus:self | UNIT_SPELLCAST_INTERRUPTED | 4 | 2:C 3:C 4:N 5:C |  |
| combat | focus:self | UNIT_SPELLCAST_START | 6 | 2:C 3:C 4:C |  |
| combat | focus:self | UNIT_SPELLCAST_STOP | 6 | 2:C 3:C 4:C |  |
| combat | focus:self | UNIT_SPELLCAST_SUCCEEDED | 6 | 2:C 3:C 4:N* |  |
| combat | focustarget:hostile-npc | UNIT_AURA | 3 | 2:T | addedAuras:S* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N |
| combat | focustarget:hostile-npc | UNIT_HEALTH | 15 |  |  |
| combat | focustarget:self | UNIT_HEALTH | 1 |  |  |
| combat | focustarget:self | UNIT_SPELLCAST_INTERRUPTED | 1 | 2:C 3:C 4:N 5:C |  |
| combat | focustarget:self | UNIT_SPELLCAST_START | 1 | 2:C 3:C 4:C |  |
| combat | focustarget:self | UNIT_SPELLCAST_STOP | 1 | 2:C 3:C 4:C |  |
| combat | nameplate:hostile-npc | UNIT_AURA | 4 | 2:T | addedAuras:N* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N |
| combat | nameplate:hostile-npc | UNIT_HEALTH | 22 |  |  |
| combat | player | UNIT_AURA | 25 | 2:T | addedAuras:S* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N* |
| combat | player | UNIT_HEALTH | 199 |  |  |
| combat | player | UNIT_SPELLCAST_DELAYED | 6 | 2:C 3:C 4:C |  |
| combat | player | UNIT_SPELLCAST_INTERRUPTED | 4 | 2:C 3:C 4:N 5:C |  |
| combat | player | UNIT_SPELLCAST_START | 7 | 2:C 3:C 4:C |  |
| combat | player | UNIT_SPELLCAST_STOP | 7 | 2:C 3:C 4:C |  |
| combat | player | UNIT_SPELLCAST_SUCCEEDED | 14 | 2:C 3:C 4:N* |  |
| combat | softenemy:hostile-npc | UNIT_AURA | 2 | 2:T | addedAuras:N* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N |
| combat | softenemy:hostile-npc | UNIT_HEALTH | 8 |  |  |
| combat | target:hostile-npc | UNIT_AURA | 3 | 2:T | addedAuras:S* isFullUpdate:S removedAuraInstanceIDs:N* updatedAuraInstanceIDs:N |
| combat | target:hostile-npc | UNIT_HEALTH | 16 |  |  |
| combat | target:self | UNIT_HEALTH | 1 |  |  |
| combat | target:self | UNIT_SPELLCAST_INTERRUPTED | 1 | 2:C 3:C 4:N 5:C |  |
| combat | target:self | UNIT_SPELLCAST_START | 1 | 2:C 3:C 4:C |  |
| combat | target:self | UNIT_SPELLCAST_STOP | 1 | 2:C 3:C 4:C |  |
| combat | targettarget:friendly-npc | UNIT_HEALTH | 3 |  |  |
| combat | targettarget:self | UNIT_AURA | 23 | 2:T | addedAuras:S* isFullUpdate:S removedAuraInstanceIDs:S* updatedAuraInstanceIDs:N* |
| combat | targettarget:self | UNIT_HEALTH | 194 |  |  |
| combat | targettarget:self | UNIT_SPELLCAST_DELAYED | 6 | 2:C 3:C 4:C |  |
| combat | targettarget:self | UNIT_SPELLCAST_INTERRUPTED | 4 | 2:C 3:C 4:N 5:C |  |
| combat | targettarget:self | UNIT_SPELLCAST_START | 7 | 2:C 3:C 4:C |  |
| combat | targettarget:self | UNIT_SPELLCAST_STOP | 7 | 2:C 3:C 4:C |  |
| combat | targettarget:self | UNIT_SPELLCAST_SUCCEEDED | 14 | 2:C 3:C 4:N* |  |
| ooc | focus:self | UNIT_AURA | 3 | 2:K | addedAuras:N* addedAuras[1].applications:C addedAuras[1].auraInstanceID:C addedAuras[1].canActivePlayerDispel:C addedAuras[1].canApplyAura:C addedAuras[1].duration:C addedAuras[1].expirationTime:C add |
| ooc | focus:self | UNIT_HEALTH | 38 |  |  |
| ooc | focus:self | UNIT_MAXHEALTH | 1 |  |  |
| ooc | focus:self | UNIT_SPELLCAST_FAILED | 3 | 2:C 3:C 4:N |  |
| ooc | focus:self | UNIT_SPELLCAST_INTERRUPTED | 6 | 2:C 3:C 4:N 5:C |  |
| ooc | focus:self | UNIT_SPELLCAST_START | 6 | 2:C 3:C 4:C |  |
| ooc | focus:self | UNIT_SPELLCAST_STOP | 6 | 2:C 3:C 4:C |  |
| ooc | focus:self | UNIT_SPELLCAST_SUCCEEDED | 2 | 2:C 3:C 4:N |  |
| ooc | player | UNIT_AURA | 3 | 2:K | addedAuras:N* addedAuras[1].applications:C addedAuras[1].auraInstanceID:C addedAuras[1].canActivePlayerDispel:C addedAuras[1].canApplyAura:C addedAuras[1].duration:C addedAuras[1].expirationTime:C add |
| ooc | player | UNIT_HEALTH | 55 |  |  |
| ooc | player | UNIT_MAXHEALTH | 1 |  |  |
| ooc | player | UNIT_SPELLCAST_FAILED | 3 | 2:C 3:C 4:N |  |
| ooc | player | UNIT_SPELLCAST_INTERRUPTED | 8 | 2:C 3:C 4:N 5:C |  |
| ooc | player | UNIT_SPELLCAST_START | 8 | 2:C 3:C 4:C |  |
| ooc | player | UNIT_SPELLCAST_STOP | 8 | 2:C 3:C 4:C |  |
| ooc | player | UNIT_SPELLCAST_SUCCEEDED | 2 | 2:C 3:C 4:N |  |

## Mismatches with the docs (0)

none
