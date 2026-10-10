# Workarounds lab - sanctioned paths for secret values

Boundary diagnostics only (no side-channel extraction). Every API/method was checked against the 70245 docs first.

| approach | group | out of combat | in combat | notes |
|---|---|---|---|---|
| StatusBar:SetMinMaxValues(0, UnitHealthMax) + SetValue(UnitHealth) | widget | ok, output secret | ok, output secret |  |
| FontString:SetText(secret) then GetText / GetStringWidth | widget | ok, output secret | ok | setErr: FontString:SetText(): Font not set
Lua Taint: ForeverDump |
| FontString:SetFormattedText('%d', secret) then GetText | widget | ok | ok | setErr: FontString:SetFormattedText(): Font not set |
| Cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(61304)) | widget | ok | ok | setErr: bad argument #2 to '?' (Usage: self:SetCooldownFromDurationObject(duration [, cl |
| Texture:SetAlpha(curve(UnitHealthPercent)) then GetAlpha (boundary: is the readback secret) | widget | ok, output secret | ok, output secret |  |
| UnitHealthPercent('player') (no curve) | engine | ok, output secret | ok, output secret |  |
| UnitHealthPercent('player', true, numberCurve) | engine | ok, output secret | ok, output secret |  |
| LuaCurveObject:Evaluate(clear x) / Evaluate(secret x) | engine | ok | ok | secretInputErr: bad argument #2 to '?' (Usage: local y = self:Evaluate(x). Secret values are onl |
| C_CurveUtil.CreateColorCurve + UnitHealthPercent(player, true, colorCurve) | engine | ok, output secret | ok, output secret |  |
| C_Spell.GetSpellCooldownDuration(1752): GetRemainingDuration / IsZero / HasSecretValues | engine | ok | ok |  |
| UnitIsUnit('player','player') / C_Secrets.CanCompareUnitTokens('player','target') | engine | ok | ok |  |
| UnitHealthMax(player) | neighbour | ok, output clear | ok, output clear |  |
| UnitPowerMax(player) | neighbour | ok, output clear | ok, output clear |  |
| UnitIsDeadOrGhost(player) | neighbour | ok, output clear | ok, output clear |  |
| UnitAffectingCombat(player) | neighbour | ok, output clear | ok, output clear |  |
| UnitThreatSituation(player,target) | neighbour | ok, output clear | ok, output clear |  |
| UnitDetailedThreatSituation(player,target) | neighbour | ok, output clear | ok, output clear |  |
| GetSpellBaseCooldown(1752) | neighbour | absent | absent | absent: GetSpellBaseCooldown (undocumented in 70245) |
| C_DamageMeter.IsDamageMeterAvailable() | neighbour | ok, output clear | ok, output clear |  |
| C_DamageMeter.GetSessionDurationSeconds(1) | neighbour | ok, output clear | ok, output clear |  |
| C_DamageMeter.GetCombatSessionFromType(0,0) | neighbour | ok, output clear | ok, output secret |  |
| C_Spell.GetSpellCooldown(1752) NeverSecret fields (isEnabled/isActive/isOnGCD) | neighbour | ok, output clear | ok, output secret |  |
| s = tostring(UnitHealth('player')); string ops on s | boundary | ok | ok |  |

## Porting patterns for secret values

Generated from the lab results above plus the research report (secrets-research.md).

| need | pattern | evidence (lab) |
|---|---|---|
| Health / power bars | StatusBar:SetMinMaxValues(0, UnitHealthMax) + SetValue(UnitHealth(unit)) - the engine draws it; never compare or do math in Lua. | combat: ok, output secret; ooc: ok, output secret |
| Numbers as text | FontString:SetText(secret) / SetFormattedText - display is allowed; GetText() returns a secret, so do not read it back. | combat: ok; ooc: ok, output secret |
| Percent / colour | UnitHealthPercent(unit, true, curve) or a colour curve -> pass the (secret) result straight to SetAlpha/SetVertexColor. | combat: ok, output secret; ooc: ok, output secret |
| Cooldowns | Cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(id)); NeverSecret fields (isEnabled/isActive/isOnGCD) for logic. | combat: ok; ooc: ok |
| Timers / cast bars | Duration objects: StatusBar:SetTimerDuration(duration) for bars; duration methods return secrets under restriction. | combat: ok; ooc: ok |
| Unit comparisons | Check C_Secrets.CanCompareUnitTokens first; UnitIsUnit may return a secret boolean under restriction. | combat: ok; ooc: ok |
| Logic that needs numbers | Use the clear neighbours (UnitHealthMax, UnitIsDeadOrGhost, UnitAffectingCombat, event arrival) and cache values while readable. | neighbour items |
