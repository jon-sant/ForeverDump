# Drift report

old: build 70245 (1.60.1, toc 16001, addon 2.1.0) `ForeverDump.lua`
new: build 70245 (1.60.1, toc 16001, addon 2.2.1) `ForeverDump.lua`

## Summary

| change | count |
|---|---|
| build bump | no |
| interface change | no |
| API docs hash changed | no |
| newly secret | **4** |
| newly clear | **8** |
| APIs added | 0 |
| APIs removed | **12** |
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

### Newly secret (4)

- `api:C_Spell.GetSpellCooldown#1 (combat): C -> S`
- `api:C_Spell.GetSpellCooldownDuration#1 (combat): C -> S`
- `api:GetRaidTargetIndex#1 (combat): C -> S`
- `event:UNIT_AURA#2 (combat): C -> S`

### Newly clear (8)

- `api:UnitDetailedThreatSituation#1 (combat): M -> C`
- `api:UnitDetailedThreatSituation#2 (combat): M -> C`
- `api:UnitDetailedThreatSituation#3 (combat): M -> C`
- `api:UnitDetailedThreatSituation#4 (combat): M -> C`
- `api:UnitDetailedThreatSituation#5 (combat): M -> C`
- `api:UnitPowerMax#1 (ooc): M -> C`
- `api:UnitStagger#1 (ooc): M -> C`
- `api:UnitThreatSituation#1 (combat): M -> C`

### APIs added (0)

none

### APIs removed (12)

- `MacroEditButton_OnClick`
- `MacroFrameCancelButton_OnClick`
- `MacroFrameSaveButton_OnClick`
- `MacroFrame_SaveMacro`
- `MacroFrame_Show`
- `MacroNewButton_OnClick`
- `PlayerChoiceGetTextureKitInfo`
- `PlayerChoiceToggle_GetActiveToggle`
- `PlayerChoiceToggle_ShouldShow`
- `PlayerChoice_SetupWidgets`
- `PlayerChoice_WidgetInit`
- `PlayerChoice_WidgetsLayout`

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

