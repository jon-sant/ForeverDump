# Drift report

old: build 70245 (1.60.1, toc 16001, addon 2.1.0) `ForeverDump.lua`
new: build 70245 (1.60.1, toc 16001, addon 2.2.3) `ForeverDump.lua`

## Summary

| change | count |
|---|---|
| build bump | no |
| interface change | no |
| API docs hash changed | no |
| newly secret | **14** |
| newly clear | **6** |
| APIs added | 0 |
| APIs removed | **6** |
| events added | 0 |
| events removed | 0 |
| signature changes | 0 |
| restriction timing changes | **2** |
| frame types added | 0 |
| frame types removed | 0 |
| frame types changed (creatable state) | **5** |
| operations matrix changes | 0 |
| lab changes | 0 |

Coverage (old, new): secrecy yes/yes, ops no/yes, lab no/yes, combat no/yes, tokens no/yes, knowledge no/yes, restrictions no/yes

## Details

### Newly secret (14)

- `api:C_Spell.GetSpellCooldown#1 (combat): C -> S`
- `api:C_Spell.GetSpellCooldownDuration#1 (combat): C -> S`
- `api:UnitCastingDuration#1 (combat): C -> S`
- `api:UnitCastingInfo#1 (combat): C -> S`
- `event:UNIT_AURA#2 (combat): C -> S`
- `event:UNIT_SPELLCAST_INTERRUPTED#2 (combat): C -> S`
- `event:UNIT_SPELLCAST_INTERRUPTED#3 (combat): C -> S`
- `event:UNIT_SPELLCAST_INTERRUPTED#4 (combat): C -> S`
- `event:UNIT_SPELLCAST_START#2 (combat): C -> M`
- `event:UNIT_SPELLCAST_START#3 (combat): C -> M`
- `event:UNIT_SPELLCAST_STOP#2 (combat): C -> M`
- `event:UNIT_SPELLCAST_STOP#3 (combat): C -> M`
- `event:UNIT_SPELLCAST_SUCCEEDED#2 (combat): C -> M`
- `event:UNIT_SPELLCAST_SUCCEEDED#3 (combat): C -> M`

### Newly clear (6)

- `api:GetUnitEmpowerHoldAtMaxTime#1 (ooc): M -> C`
- `api:GetUnitEmpowerMinHoldTime#1 (ooc): M -> C`
- `api:UnitHealthMax#1 (ooc): M -> C`
- `api:UnitPowerMax#1 (ooc): M -> C`
- `api:UnitStagger#1 (ooc): M -> C`
- `api:UnitStagger#1 (combat): M -> C`

### APIs added (0)

none

### APIs removed (6)

- `MacroEditButton_OnClick`
- `MacroFrameCancelButton_OnClick`
- `MacroFrameSaveButton_OnClick`
- `MacroFrame_SaveMacro`
- `MacroFrame_Show`
- `MacroNewButton_OnClick`

### Events added (0)

none

### Events removed (0)

none

### Signature changes (0)

none

### Documented functions/events added (0)

none

### Documented functions/events removed (0)

none

### Restriction timing (2)

- `new flip kind Combat:Activating`
- `new flip kind Combat:Inactive`

### Frame types added (0)

none

### Frame types removed (0)

none

### Frame types changed (5)

- `Blob: failed -> notCreatable`
- `MapScene: failed -> notCreatable`
- `ModelFFX: failed -> notCreatable`
- `PingPinFrame: failed -> notCreatable`
- `VectorGraphics: failed -> notCreatable`

### Operations matrix (0)

none

### Lab (0)

none

