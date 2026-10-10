# Client.log summary

644 entries, 2026-10-07T19:48:53.945 .. 2026-10-07T19:58:11.313

Kinds: lua_error 411, other 168, limited_lua_resources 46, cvar_validation 12, screen 4, lua_warning 3

## Lua errors (411) by call site

| count | first | last | message | top frame | first Lua frame | in capture | outside |
|---|---|---|---|---|---|---|---|
| 308 | 19:52:50 | 19:58:11 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_SharedXMLBase/GlobalCallbackRegistry.lua:11` | 308 | 0 |
| 34 | 19:54:24 | 19:58:10 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_GamepadActionBars/MainActionBarFrame.lua:256` | 34 | 0 |
| 24 | 19:54:57 | 19:57:51 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_SharedXML/SharedTooltipTemplates.lua:275` | 24 | 0 |
| 18 | 19:52:51 | 19:54:09 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_Game/Mainline/EventImplementation.lua:126` | 18 | 0 |
| 10 | 19:54:18 | 19:58:04 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_SharedXML/SharedTooltipTemplates.lua:279` | 10 | 0 |
| 5 | 19:52:48 | 19:57:52 | attempt to call a nil value | `[C]: in function 'LayoutContents'` | `Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua:147` | 5 | 0 |
| 3 | 19:52:48 | 19:55:37 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua:1503` | 3 | 0 |
| 2 | 19:54:42 | 19:54:57 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_ActionBar/Shared/ActionButton.lua:566` | 2 | 0 |
| 1 | 19:54:12 | 19:54:12 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:908` | 1 | 0 |
| 1 | 19:55:17 | 19:55:17 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_BuffFrame/BuffFrame.lua:1146` | 1 | 0 |
| 1 | 19:55:47 | 19:55:47 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua:398` | 1 | 0 |
| 1 | 19:55:47 | 19:55:47 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua:406` | 1 | 0 |
| 1 | 19:57:31 | 19:57:31 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_ProfessionsBook/Blizzard_ProfessionsBook.lua:77` | 1 | 0 |
| 1 | 19:57:37 | 19:57:37 | attempt to call a nil value | `[C]: in function 'TriggerEvent'` | `Blizzard_PlayerSpells/SpellBook/Blizzard_SpellBookFrame.lua:91` | 1 | 0 |
| 1 | 19:57:40 | 19:57:40 | ...e/AddOns/Blizzard_MoneyFrame/Mainline/MoneyFrame.lua:340: attempt to perform arithmetic | `[C]: ?` | `Blizzard_MoneyFrame/Mainline/MoneyFrame.lua:340` | 1 | 0 |

'attempt to call a nil value' raised directly by a C function frame (hooksecurefunc trampoline class): TriggerEvent x405, LayoutContents x5

## LUA warnings

- 19:51:11 Unable to create frame type: MapScene
- 19:51:11 Unknown frame type: VectorGraphics
- 19:51:11 Unable to create frame type: ModelFFX

## Screen switches (login / reload)

- 19:49:02 Screen invalid. Changing from="none" to="login"
- 19:49:02 Switching to screen="AccountLogin" (from "none")
- 19:49:09 Screen invalid. Changing from="login" to="charselect"
- 19:49:09 Switching to screen="CharacterSelect" (from "login")

## LimitedLuaResources

- Addon capacity for AnimGroup changed to 2000
- Addon capacity for Animation changed to 5000
- Addon capacity for Font changed to 300
- Addon capacity for FontString changed to 5000
- Addon capacity for Frame changed to 10000
- Addon capacity for Texture changed to 40000
- Addon capacity for Timer changed to 500
- Enabled = false
- Global capacity for AnimGroup changed to 20000
- Global capacity for Animation changed to 50000
- Global capacity for Font changed to 3000
- Global capacity for FontString changed to 50000
- Global capacity for Frame changed to 100000
- Global capacity for Texture changed to 400000
- Global capacity for Timer changed to 500
- Reset Timer

Capture windows (from the dump): 19:52:48-19:58:43
