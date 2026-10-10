# Workarounds lab - sanctioned paths for secret values

Boundary diagnostics only (no side-channel extraction). Every API/method was checked against the 70245 docs first.

_no lab records in this dump (v2.2 FD_Logs runs the lab automatically, in and out of combat)_

## Porting patterns for secret values

Generated from the lab results above plus the research report (secrets-research.md).

| need | pattern | evidence (lab) |
|---|---|---|
| Health / power bars | StatusBar:SetMinMaxValues(0, UnitHealthMax) + SetValue(UnitHealth(unit)) - the engine draws it; never compare or do math in Lua. | not measured yet |
| Numbers as text | FontString:SetText(secret) / SetFormattedText - display is allowed; GetText() returns a secret, so do not read it back. | not measured yet |
| Percent / colour | UnitHealthPercent(unit, true, curve) or a colour curve -> pass the (secret) result straight to SetAlpha/SetVertexColor. | not measured yet |
| Cooldowns | Cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(id)); NeverSecret fields (isEnabled/isActive/isOnGCD) for logic. | not measured yet |
| Timers / cast bars | Duration objects: StatusBar:SetTimerDuration(duration) for bars; duration methods return secrets under restriction. | not measured yet |
| Unit comparisons | Check C_Secrets.CanCompareUnitTokens first; UnitIsUnit may return a secret boolean under restriction. | not measured yet |
| Logic that needs numbers | Use the clear neighbours (UnitHealthMax, UnitIsDeadOrGhost, UnitAffectingCombat, event arrival) and cache values while readable. | neighbour items |
