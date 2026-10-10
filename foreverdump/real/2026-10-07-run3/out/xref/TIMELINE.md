# ForeverDump xref timeline

Player GUID: `Player-4618-00EB40D8`; UTC offset -14400.0 s. Sources: addon-anchor 4, addon-blocked 36, addon-cl 2430, addon-context 25, addon-contradiction 3, addon-event 6289, addon-probe 3, addon-restriction 12, file-cl 1868

Match quality (addon -> file): exact 72, time+amount 258, time-only:amount-differs 124, unmatched 888

## Combat 1 (addon PLAYER_REGEN): 2026-10-07T21:57:14.792-04:00 .. 2026-10-07T21:57:50.987-04:00, 1262 lines

matches: exact 9, time+amount 29, time-only:amount-differs 14, unmatched 128

| time | source | event | details | secret | match |
|---|---|---|---|---|---|
| 21:57:14.792 | addon-event | UNIT_SPELLCAST_FAILED | player Cast-2-0-0-0-8052-0000000021 8052 <nil> | clear |  |
| 21:57:14.792 | addon-event | UNIT_SPELLCAST_FAILED | focus Cast-2-0-0-0-8052-0000000021 8052 <nil> | clear |  |
| 21:57:14.792 | addon-event | CURRENT_SPELL_CAST_CHANGED | false | clear |  |
| 21:57:14.792 | addon-event | UNIT_SPELLCAST_FAILED | player Cast-2-0-0-0-8052-0000000022 8052 <nil> | clear |  |
| 21:57:14.792 | addon-event | CURRENT_SPELL_CAST_CHANGED | false | clear |  |
| 21:57:14.792 | addon-event | ACTIONBAR_UPDATE_STATE |  | clear |  |
| 21:57:14.792 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 21:57:14.792 | addon-event | UI_ERROR_MESSAGE | 402 Out of range. | clear |  |
| 21:57:14.792 | addon-cl | UNIT_SPELLCAST_FAILED | player Cast-2-0-0-0-8052-0000000021 8052 <nil> | clear |  |
| 21:57:14.792 | addon-cl | UNIT_SPELLCAST_FAILED | focus Cast-2-0-0-0-8052-0000000021 8052 <nil> | clear |  |
| 21:57:14.792 | addon-cl | UNIT_SPELLCAST_FAILED | player Cast-2-0-0-0-8052-0000000022 8052 <nil> | clear |  |
| 21:57:14.792 | addon-cl | UNIT_SPELLCAST_FAILED | focus Cast-2-0-0-0-8052-0000000022 8052 <nil> | clear |  |
| 21:57:15.000 | addon-contradiction | event:UNIT_AURA | 1 conditional clear-while-predicate-true combat/none/other 49 | clear |  |
| 21:57:15.121 | addon-event | ACTION_RANGE_CHECK_UPDATE | 4 true true | clear |  |
| 21:57:15.121 | addon-event | ACTION_RANGE_CHECK_UPDATE | 3 true true | clear |  |
| 21:57:15.121 | addon-event | ACTION_RANGE_CHECK_UPDATE | 2 true true | clear |  |
| 21:57:15.121 | addon-event | NAME_PLATE_UNIT_ADDED | nameplate2 | clear |  |
| 21:57:15.537 | addon-event | CURRENT_SPELL_CAST_CHANGED | false | clear |  |
| 21:57:15.537 | addon-event | GLOBAL_REGION_MOUSE_UP | <nil> LeftButton | clear |  |
| 21:57:15.537 | addon-event | PLAYER_STOPPED_MOVING |  | clear |  |
| 21:57:15.537 | addon-event | PLAYER_STOPPED_LOOKING |  | clear |  |
| 21:57:15.537 | addon-event | GLOBAL_MOUSE_UP | LeftButton | clear |  |
| 21:57:15.537 | addon-event | ACTIONBAR_UPDATE_COOLDOWN |  | clear |  |
| 21:57:15.537 | addon-event | ACTIONBAR_UPDATE_STATE |  | clear |  |
| 21:57:15.537 | addon-event | SPELL_UPDATE_COOLDOWN | 8052 <nil> 19 133 <nil> | clear |  |
| 21:57:15.683 | addon-event | GLOBAL_REGION_MOUSE_UP | <nil> RightButton | clear |  |
| 21:57:15.683 | addon-event | PLAYER_STOPPED_TURNING |  | clear |  |
| 21:57:15.683 | addon-event | GLOBAL_MOUSE_UP | RightButton | clear |  |
| 21:57:15.683 | addon-event | UNIT_SPELLCAST_SENT | player Savannah Huntress Cast-3-6782-1-545-8052-000046F87D 8052 | clear |  |
| 21:57:15.683 | addon-event | UNIT_SPELLCAST_SENT | focus Savannah Huntress Cast-3-6782-1-545-8052-000046F87D 8052 | clear |  |
| 21:57:15.683 | addon-event | CURRENT_SPELL_CAST_CHANGED | false | clear |  |
| 21:57:15.683 | addon-event | UNIT_SPELLCAST_SUCCEEDED | player Cast-3-6782-1-545-8052-000046F87D 8052 <nil> | clear | exact (+11 ms) SPELL_CAST_SUCCESS Uglaz-ClassicBetaPvE-->Savannah Huntress None |
| 21:57:15.683 | addon-event | UNIT_SPELLCAST_SUCCEEDED | focus Cast-3-6782-1-545-8052-000046F87D 8052 <nil> | clear |  |
| 21:57:15.683 | addon-event | CURRENT_SPELL_CAST_CHANGED | false | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_UPDATE | player MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_UPDATE | focus MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_FREQUENT | player MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_FREQUENT | focus MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_COMBAT | nameplate1 WOUND  38 4 | clear | exact (+12 ms) SPELL_DAMAGE Uglaz-ClassicBetaPvE-->Savannah Huntress 38 |
| 21:57:15.683 | addon-event | UNIT_COMBAT | target WOUND  38 4 | clear | unmatched |
| 21:57:15.683 | addon-event | UNIT_COMBAT | focustarget WOUND  38 4 | clear | unmatched |
| 21:57:15.683 | addon-event | UNIT_COMBAT | softenemy WOUND  38 4 | clear | unmatched |
| 21:57:15.683 | addon-event | UNIT_TARGET | nameplate1 | clear |  |
| 21:57:15.683 | addon-event | UNIT_TARGET | target | clear |  |
| 21:57:15.683 | addon-event | UNIT_TARGET | focustarget | clear |  |
| 21:57:15.683 | addon-event | UNIT_TARGET | softenemy | clear |  |
| 21:57:15.683 | addon-event | UNIT_FLAGS | nameplate1 | clear |  |
| 21:57:15.683 | addon-event | UNIT_FLAGS | target | clear |  |
| 21:57:15.683 | addon-event | UNIT_FLAGS | focustarget | clear |  |
| 21:57:15.683 | addon-event | UNIT_FLAGS | softenemy | clear |  |
| 21:57:15.683 | addon-event | PLAYER_REGEN_DISABLED |  | clear |  |
| 21:57:15.683 | addon-event | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 21:57:15.683 | addon-event | PLAYER_IN_COMBAT_CHANGED | true | clear |  |
| 21:57:15.683 | addon-event | UNIT_FLAGS | player | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_UPDATE | player MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_UPDATE | targettarget MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_UPDATE | focus MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_FREQUENT | player MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_FREQUENT | targettarget MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_POWER_FREQUENT | focus MANA | clear |  |
| 21:57:15.683 | addon-event | UNIT_HAPPINESS | player | clear |  |
| 21:57:15.683 | addon-event | UNIT_HAPPINESS | targettarget | clear |  |
| 21:57:15.683 | addon-event | UNIT_HAPPINESS | focus | clear |  |
| 21:57:15.683 | addon-event | ACTION_USABLE_CHANGED | [{"usable": false, "noMana": false, "slo | clear |  |
| 21:57:15.683 | addon-event | UNIT_AURA | nameplate1 {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:57:15.683 | addon-event | UNIT_AURA | target {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:57:15.683 | addon-event | UNIT_AURA | focustarget {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:57:15.683 | addon-event | UNIT_AURA | softenemy {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:57:15.683 | addon-event | ACTIONBAR_UPDATE_COOLDOWN |  | clear |  |
| 21:57:15.683 | addon-event | ACTIONBAR_UPDATE_STATE |  | clear |  |
| 21:57:15.683 | addon-event | ACTIONBAR_UPDATE_USABLE |  | clear |  |
| 21:57:15.683 | addon-event | BAG_UPDATE_COOLDOWN |  | clear |  |
| 21:57:15.683 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 10 | clear |  |
| 21:57:15.683 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 10 | clear |  |
| 21:57:15.683 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 21:57:15.683 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 0 | clear |  |
| 21:57:15.683 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 10 | clear |  |
| 21:57:15.683 | addon-event | DAMAGE_METER_CURRENT_SESSION_UPDATED |  | clear |  |
| 21:57:15.683 | addon-event | SPELL_UPDATE_COOLDOWN | 8052 <nil> 19 133 <nil> | clear |  |
| 21:57:15.683 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| ... 1182 more lines in timeline.jsonl | | | | | |

## Combat 2 (addon PLAYER_REGEN): 2026-10-07T21:58:09.215-04:00 .. 2026-10-07T21:58:17.111-04:00, 346 lines

matches: exact 2, time+amount 2, time-only:amount-differs 5, unmatched 25

| time | source | event | details | secret | match |
|---|---|---|---|---|---|
| 21:58:09.215 | file-cl | SPELL_AURA_REMOVED_DOSE | Dotore-ClassicBetaPvE- -> Dotore-ClassicBetaPvE-  | unrestricted |  |
| 21:58:09.782 | addon-event | ACTION_RANGE_CHECK_UPDATE | 4 true true | clear |  |
| 21:58:09.782 | addon-event | ACTION_RANGE_CHECK_UPDATE | 3 true true | clear |  |
| 21:58:09.782 | addon-event | ACTION_RANGE_CHECK_UPDATE | 2 true true | clear |  |
| 21:58:09.944 | addon-event | CURRENT_SPELL_CAST_CHANGED | false | clear |  |
| 21:58:09.944 | addon-event | ACTIONBAR_UPDATE_COOLDOWN |  | clear |  |
| 21:58:09.944 | addon-event | ACTIONBAR_UPDATE_STATE |  | clear |  |
| 21:58:09.944 | addon-event | SPELL_UPDATE_COOLDOWN | 8052 <nil> 19 133 <nil> | clear |  |
| 21:58:10.084 | addon-event | UNIT_SPELLCAST_SENT | player Savannah Huntress Cast-3-6782-1-545-8052-000846F8B3 8052 | clear |  |
| 21:58:10.084 | addon-event | UNIT_SPELLCAST_SENT | focus Savannah Huntress Cast-3-6782-1-545-8052-000846F8B3 8052 | clear |  |
| 21:58:10.084 | addon-event | CURRENT_SPELL_CAST_CHANGED | false | clear |  |
| 21:58:10.084 | addon-event | UNIT_SPELLCAST_SUCCEEDED | player Cast-3-6782-1-545-8052-000846F8B3 8052 <nil> | clear | exact (+11 ms) SPELL_CAST_SUCCESS Uglaz-ClassicBetaPvE-->Savannah Huntress None |
| 21:58:10.084 | addon-event | UNIT_SPELLCAST_SUCCEEDED | focus Cast-3-6782-1-545-8052-000846F8B3 8052 <nil> | clear |  |
| 21:58:10.084 | addon-event | CURRENT_SPELL_CAST_CHANGED | false | clear |  |
| 21:58:10.084 | addon-event | UNIT_POWER_UPDATE | player MANA | clear |  |
| 21:58:10.084 | addon-event | UNIT_POWER_UPDATE | focus MANA | clear |  |
| 21:58:10.084 | addon-event | UNIT_POWER_FREQUENT | player MANA | clear |  |
| 21:58:10.084 | addon-event | UNIT_POWER_FREQUENT | focus MANA | clear |  |
| 21:58:10.084 | addon-event | PLAYER_REGEN_DISABLED |  | clear |  |
| 21:58:10.084 | addon-event | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 21:58:10.084 | addon-event | PLAYER_IN_COMBAT_CHANGED | true | clear |  |
| 21:58:10.084 | addon-event | UNIT_FLAGS | player | clear |  |
| 21:58:10.084 | addon-event | UNIT_FLAGS | focus | clear |  |
| 21:58:10.084 | addon-event | UNIT_POWER_UPDATE | player MANA | clear |  |
| 21:58:10.084 | addon-event | UNIT_POWER_UPDATE | focus MANA | clear |  |
| 21:58:10.084 | addon-event | UNIT_POWER_FREQUENT | player MANA | clear |  |
| 21:58:10.084 | addon-event | UNIT_POWER_FREQUENT | focus MANA | clear |  |
| 21:58:10.084 | addon-event | UNIT_HAPPINESS | player | clear |  |
| 21:58:10.084 | addon-event | UNIT_HAPPINESS | focus | clear |  |
| 21:58:10.084 | addon-event | UNIT_COMBAT | nameplate1 WOUND  38 4 | clear | exact (+17 ms) SPELL_DAMAGE Uglaz-ClassicBetaPvE-->Savannah Huntress 38 |
| 21:58:10.084 | addon-event | UNIT_COMBAT | target WOUND  38 4 | clear | unmatched |
| 21:58:10.084 | addon-event | UNIT_COMBAT | focustarget WOUND  38 4 | clear | unmatched |
| 21:58:10.084 | addon-event | UNIT_TARGET | nameplate1 | clear |  |
| 21:58:10.084 | addon-event | UNIT_TARGET | target | clear |  |
| 21:58:10.084 | addon-event | UNIT_TARGET | focustarget | clear |  |
| 21:58:10.084 | addon-event | UNIT_FLAGS | nameplate1 | clear |  |
| 21:58:10.084 | addon-event | UNIT_FLAGS | target | clear |  |
| 21:58:10.084 | addon-event | UNIT_FLAGS | focustarget | clear |  |
| 21:58:10.084 | addon-event | ACTION_USABLE_CHANGED | [{"usable": false, "noMana": false, "slo | clear |  |
| 21:58:10.084 | addon-event | UNIT_AURA | nameplate1 {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:58:10.084 | addon-event | UNIT_AURA | target {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:58:10.084 | addon-event | UNIT_AURA | focustarget {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:58:10.084 | addon-event | ACTIONBAR_UPDATE_COOLDOWN |  | clear |  |
| 21:58:10.084 | addon-event | ACTIONBAR_UPDATE_STATE |  | clear |  |
| 21:58:10.084 | addon-event | ACTIONBAR_UPDATE_USABLE |  | clear |  |
| 21:58:10.084 | addon-event | BAG_UPDATE_COOLDOWN |  | clear |  |
| 21:58:10.084 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 11 | clear |  |
| 21:58:10.084 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 11 | clear |  |
| 21:58:10.084 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 21:58:10.084 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 0 | clear |  |
| 21:58:10.084 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 11 | clear |  |
| 21:58:10.084 | addon-event | DAMAGE_METER_CURRENT_SESSION_UPDATED |  | clear |  |
| 21:58:10.084 | addon-event | SPELL_UPDATE_COOLDOWN | 8052 <nil> 19 133 <nil> | clear |  |
| 21:58:10.084 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 21:58:10.084 | addon-event | UNIT_HEALTH | nameplate1 | clear |  |
| 21:58:10.084 | addon-event | UNIT_HEALTH | target | clear |  |
| 21:58:10.084 | addon-event | UNIT_HEALTH | focustarget | clear |  |
| 21:58:10.084 | addon-event | UNIT_THREAT_LIST_UPDATE | nameplate1 | clear |  |
| 21:58:10.084 | addon-event | UNIT_THREAT_LIST_UPDATE | target | clear |  |
| 21:58:10.084 | addon-event | UNIT_THREAT_LIST_UPDATE | focustarget | clear |  |
| 21:58:10.084 | addon-event | UNIT_THREAT_SITUATION_UPDATE | player | clear |  |
| 21:58:10.084 | addon-event | UNIT_THREAT_SITUATION_UPDATE | targettarget | clear |  |
| 21:58:10.084 | addon-event | UNIT_THREAT_SITUATION_UPDATE | focus | clear |  |
| 21:58:10.084 | addon-cl | UNIT_SPELLCAST_SENT | player Savannah Huntress Cast-3-6782-1-545-8052-000846F8B3 8052 | clear |  |
| 21:58:10.084 | addon-cl | UNIT_SPELLCAST_SENT | focus Savannah Huntress Cast-3-6782-1-545-8052-000846F8B3 8052 | clear |  |
| 21:58:10.084 | addon-cl | UNIT_SPELLCAST_SUCCEEDED | player Cast-3-6782-1-545-8052-000846F8B3 8052 <nil> | clear | unmatched |
| 21:58:10.084 | addon-cl | UNIT_SPELLCAST_SUCCEEDED | focus Cast-3-6782-1-545-8052-000846F8B3 8052 <nil> | clear |  |
| 21:58:10.084 | addon-cl | PLAYER_REGEN_DISABLED |  | clear |  |
| 21:58:10.084 | addon-cl | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 21:58:10.084 | addon-cl | UNIT_COMBAT | nameplate1 WOUND  38 4 | clear | unmatched |
| 21:58:10.084 | addon-cl | UNIT_COMBAT | target WOUND  38 4 | clear | unmatched |
| 21:58:10.084 | addon-cl | UNIT_COMBAT | focustarget WOUND  38 4 | clear | unmatched |
| 21:58:10.084 | addon-cl | UNIT_AURA | nameplate1 {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:58:10.084 | addon-cl | UNIT_AURA | target {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:58:10.084 | addon-cl | UNIT_AURA | focustarget {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 21:58:10.084 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 11 | clear |  |
| 21:58:10.084 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 11 | clear |  |
| 21:58:10.084 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 21:58:10.084 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 0 | clear |  |
| 21:58:10.084 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 11 | clear |  |
| ... 266 more lines in timeline.jsonl | | | | | |

## Combat 3 (addon PLAYER_REGEN): 2026-10-07T21:58:21.404-04:00 .. 2026-10-07T22:00:29.280-04:00, 2693 lines

matches: exact 11, time+amount 114, time-only:amount-differs 23, unmatched 414

| time | source | event | details | secret | match |
|---|---|---|---|---|---|
| 21:58:21.404 | addon-event | SPELL_ACTIVATION_OVERLAY_HIDE | <nil> | clear |  |
| 21:58:21.404 | addon-event | SPELL_ACTIVATION_OVERLAY_HIDE | <nil> | clear |  |
| 21:58:21.404 | addon-event | SPELL_ACTIVATION_OVERLAY_HIDE | <nil> | clear |  |
| 21:58:21.404 | addon-event | SPELL_ACTIVATION_OVERLAY_HIDE | <nil> | clear |  |
| 21:58:21.415 | file-cl | SPELL_AURA_APPLIED | Feather-ClassicBetaPvE2- -> Moonblight-ClassicBetaPvE2-  | unrestricted |  |
| 21:58:21.788 | addon-event | ACTION_RANGE_CHECK_UPDATE | 1 true true | clear |  |
| 21:58:22.277 | addon-event | UNIT_TARGET | nameplate1 | clear |  |
| 21:58:22.277 | addon-event | UNIT_TARGET | target | clear |  |
| 21:58:22.277 | addon-event | UNIT_TARGET | focustarget | clear |  |
| 21:58:22.277 | addon-event | UNIT_FLAGS | nameplate1 | clear |  |
| 21:58:22.277 | addon-event | UNIT_FLAGS | target | clear |  |
| 21:58:22.277 | addon-event | UNIT_FLAGS | focustarget | clear |  |
| 21:58:22.277 | addon-event | PLAYER_REGEN_DISABLED |  | clear |  |
| 21:58:22.277 | addon-event | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 21:58:22.277 | addon-event | PLAYER_IN_COMBAT_CHANGED | true | clear |  |
| 21:58:22.277 | addon-event | UNIT_FLAGS | player | clear |  |
| 21:58:22.277 | addon-event | UNIT_FLAGS | targettarget | clear |  |
| 21:58:22.277 | addon-event | ACTION_USABLE_CHANGED | [{"usable": false, "noMana": false, "slo | clear |  |
| 21:58:22.277 | addon-event | ACTIONBAR_UPDATE_USABLE |  | clear |  |
| 21:58:22.277 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 7 12 | clear |  |
| 21:58:22.277 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 7 0 | clear |  |
| 21:58:22.277 | addon-event | DAMAGE_METER_CURRENT_SESSION_UPDATED |  | clear |  |
| 21:58:22.277 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 21:58:22.277 | addon-event | UNIT_HEALTH | player | clear |  |
| 21:58:22.277 | addon-event | UNIT_HEALTH | targettarget | clear |  |
| 21:58:22.277 | addon-event | UNIT_HEALTH | focus | clear |  |
| 21:58:22.277 | addon-event | UNIT_THREAT_LIST_UPDATE | nameplate1 | clear |  |
| 21:58:22.277 | addon-event | UNIT_THREAT_LIST_UPDATE | target | clear |  |
| 21:58:22.277 | addon-event | UNIT_THREAT_LIST_UPDATE | focustarget | clear |  |
| 21:58:22.277 | addon-event | UNIT_THREAT_SITUATION_UPDATE | player | clear |  |
| 21:58:22.277 | addon-event | UNIT_THREAT_SITUATION_UPDATE | targettarget | clear |  |
| 21:58:22.277 | addon-event | UNIT_THREAT_SITUATION_UPDATE | focus | clear |  |
| 21:58:22.277 | addon-cl | PLAYER_REGEN_DISABLED |  | clear |  |
| 21:58:22.277 | addon-cl | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 21:58:22.277 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 7 12 | clear |  |
| 21:58:22.277 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 7 0 | clear |  |
| 21:58:22.277 | addon-cl | DAMAGE_METER_CURRENT_SESSION_UPDATED |  | clear |  |
| 21:58:22.277 | addon-cl | UNIT_HEALTH | player | clear |  |
| 21:58:22.277 | addon-cl | UNIT_HEALTH | targettarget | clear |  |
| 21:58:22.277 | addon-cl | UNIT_HEALTH | focus | clear |  |
| 21:58:22.277 | addon-restriction | RESTRICTION Combat:Activating | 0 PLAYER_REGEN_DISABLED secret after flip: UnitHealth,UnitHealth | clear |  |
| 21:58:22.277 | addon-context | PLAYER_REGEN_DISABLED | null null | clear |  |
| 21:58:22.277 | addon-context | PLAYER_IN_COMBAT_CHANGED | null null | clear |  |
| 21:58:22.286 | file-cl | SWING_DAMAGE | Savannah Highmane -> Uglaz-ClassicBetaPvE- 9 | unrestricted | <- UNIT_COMBAT |
| 21:58:22.292 | file-cl | SWING_DAMAGE_LANDED | Savannah Highmane -> Uglaz-ClassicBetaPvE- 9 | unrestricted | <- UNIT_COMBAT |
| 21:58:22.423 | addon-event | PLAYER_SWING | 3.300000190734863 0 | clear |  |
| 21:58:22.423 | addon-event | PET_BAR_UPDATE_USABLE |  | clear |  |
| 21:58:22.423 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 12 | clear |  |
| 21:58:22.423 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 12 | clear |  |
| 21:58:22.423 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 21:58:22.423 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 21:58:22.423 | addon-event | UNIT_HEALTH | nameplate1 | clear |  |
| 21:58:22.423 | addon-event | UNIT_HEALTH | target | clear |  |
| 21:58:22.423 | addon-cl | PLAYER_SWING | 3.300000190734863 0 | clear |  |
| 21:58:22.423 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 12 | clear |  |
| 21:58:22.423 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 12 | clear |  |
| 21:58:22.423 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 21:58:22.423 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 0 | clear |  |
| 21:58:22.423 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 12 | clear |  |
| 21:58:22.423 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 0 | clear |  |
| 21:58:22.423 | addon-cl | UNIT_HEALTH | nameplate1 | clear |  |
| 21:58:22.423 | addon-cl | UNIT_HEALTH | target | clear |  |
| 21:58:22.423 | addon-cl | UNIT_HEALTH | focustarget | clear |  |
| 21:58:22.432 | file-cl | SWING_DAMAGE | Uglaz-ClassicBetaPvE- -> Savannah Highmane 137 | unrestricted | <- UNIT_COMBAT |
| 21:58:22.432 | file-cl | SWING_DAMAGE_LANDED | Uglaz-ClassicBetaPvE- -> Savannah Highmane 137 | unrestricted | <- UNIT_COMBAT |
| 21:58:22.620 | addon-event | UPDATE_INVENTORY_DURABILITY |  | clear |  |
| 21:58:22.662 | addon-event | UNIT_COMBAT | player WOUND  9 1 | clear | time+amount (-370 ms) SWING_DAMAGE_LANDED Savannah Highmane->Uglaz-ClassicBetaPvE- 9 |
| 21:58:22.662 | addon-event | UNIT_COMBAT | targettarget WOUND  9 1 | clear | time-only:amount-differs (-230 ms) SWING_DAMAGE Uglaz-ClassicBetaPvE-->Savannah Highmane 137 |
| 21:58:22.662 | addon-event | UNIT_COMBAT | focus WOUND  9 1 | clear | time-only:amount-differs (-230 ms) SWING_DAMAGE_LANDED Uglaz-ClassicBetaPvE-->Savannah Highmane 137 |
| 21:58:22.662 | addon-cl | UNIT_COMBAT | player WOUND  9 1 | clear | time+amount (-376 ms) SWING_DAMAGE Savannah Highmane->Uglaz-ClassicBetaPvE- 9 |
| 21:58:22.662 | addon-cl | UNIT_COMBAT | targettarget WOUND  9 1 | clear | unmatched |
| 21:58:22.662 | addon-cl | UNIT_COMBAT | focus WOUND  9 1 | clear | unmatched |
| 21:58:22.798 | addon-event | NAME_PLATE_UNIT_REMOVED | nameplate4 | clear |  |
| 21:58:22.881 | addon-event | UNIT_COMBAT | nameplate1 WOUND  137 1 | clear | unmatched |
| 21:58:22.881 | addon-event | UNIT_COMBAT | target WOUND  137 1 | clear | unmatched |
| 21:58:22.881 | addon-event | UNIT_COMBAT | focustarget WOUND  137 1 | clear | unmatched |
| 21:58:22.881 | addon-cl | UNIT_COMBAT | nameplate1 WOUND  137 1 | clear | unmatched |
| 21:58:22.881 | addon-cl | UNIT_COMBAT | target WOUND  137 1 | clear | unmatched |
| 21:58:22.881 | addon-cl | UNIT_COMBAT | focustarget WOUND  137 1 | clear | unmatched |
| 21:58:22.933 | addon-event | GLOBAL_REGION_MOUSE_UP | <nil> RightButton | clear |  |
| ... 2613 more lines in timeline.jsonl | | | | | |

## Combat 4 (addon PLAYER_REGEN): 2026-10-07T22:01:12.606-04:00 .. 2026-10-07T22:01:15.441-04:00, 155 lines

matches: unmatched 4

| time | source | event | details | secret | match |
|---|---|---|---|---|---|
| 22:01:12.606 | addon-event | SPELL_ACTIVATION_OVERLAY_HIDE | <nil> | clear |  |
| 22:01:12.710 | addon-event | CURSOR_CHANGED | true 0 0 0 | clear |  |
| 22:01:12.710 | addon-event | WORLD_CURSOR_TOOLTIP_UPDATE | 0 | clear |  |
| 22:01:12.918 | addon-event | CURSOR_CHANGED | true 0 0 0 | clear |  |
| 22:01:12.918 | addon-event | WORLD_CURSOR_TOOLTIP_UPDATE | 1 | clear |  |
| 22:01:12.918 | addon-event | UPDATE_MOUSEOVER_UNIT |  | clear |  |
| 22:01:13.000 | addon-blocked | ADDON_ACTION_BLOCKED | ForeverDump UNKNOWN() | clear |  |
| 22:01:13.000 | addon-blocked | ADDON_ACTION_BLOCKED | ForeverDump UNKNOWN() | clear |  |
| 22:01:13.106 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 22:01:13.106 | addon-event | UNIT_HEALTH | player | clear |  |
| 22:01:13.106 | addon-event | UNIT_HEALTH | focus | clear |  |
| 22:01:13.106 | addon-cl | UNIT_HEALTH | player | clear |  |
| 22:01:13.106 | addon-cl | UNIT_HEALTH | focus | clear |  |
| 22:01:13.115 | file-cl | SPELL_AURA_APPLIED_DOSE | Moopheus-ClassicBetaPvE2- -> Moopheus-ClassicBetaPvE2-  | unrestricted |  |
| 22:01:13.314 | addon-event | CURSOR_CHANGED | true 0 0 0 | clear |  |
| 22:01:13.335 | addon-event | GLOBAL_MOUSE_DOWN | RightButton | clear |  |
| 22:01:13.335 | addon-event | GLOBAL_REGION_MOUSE_DOWN | <nil> RightButton | clear |  |
| 22:01:13.418 | addon-event | WORLD_CURSOR_TOOLTIP_UPDATE | 0 | clear |  |
| 22:01:13.418 | addon-event | PLAYER_STARTED_TURNING |  | clear |  |
| 22:01:13.418 | addon-event | CURSOR_CHANGED | true 0 0 0 | clear |  |
| 22:01:13.460 | addon-event | GLOBAL_REGION_MOUSE_UP | <nil> RightButton | clear |  |
| 22:01:13.460 | addon-event | PLAYER_TARGET_CHANGED |  | clear |  |
| 22:01:13.460 | addon-event | PLAYER_STOPPED_TURNING |  | clear |  |
| 22:01:13.460 | addon-event | GLOBAL_MOUSE_UP | RightButton | clear |  |
| 22:01:13.460 | addon-event | ACTION_RANGE_CHECK_UPDATE | 1 true true | clear |  |
| 22:01:13.460 | addon-event | ACTION_RANGE_CHECK_UPDATE | 4 true true | clear |  |
| 22:01:13.460 | addon-event | ACTION_RANGE_CHECK_UPDATE | 64 true true | clear |  |
| 22:01:13.460 | addon-event | ACTION_RANGE_CHECK_UPDATE | 3 true true | clear |  |
| 22:01:13.460 | addon-event | ACTION_RANGE_CHECK_UPDATE | 2 true true | clear |  |
| 22:01:13.460 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 22:01:13.460 | addon-cl | PLAYER_TARGET_CHANGED |  | clear |  |
| 22:01:13.481 | addon-event | CURSOR_CHANGED | true 0 0 0 | clear |  |
| 22:01:13.481 | addon-event | WORLD_CURSOR_TOOLTIP_UPDATE | 1 | clear |  |
| 22:01:13.481 | addon-event | UPDATE_MOUSEOVER_UNIT |  | clear |  |
| 22:01:13.502 | addon-event | PLAYER_STOPPED_MOVING |  | clear |  |
| 22:01:13.564 | addon-event | PLAYER_SWING | 3.300000190734863 0 | clear |  |
| 22:01:13.564 | addon-event | PLAYER_ENTER_COMBAT |  | clear |  |
| 22:01:13.564 | addon-event | WORLD_CURSOR_TOOLTIP_UPDATE | 1 | clear |  |
| 22:01:13.564 | addon-event | CRITERIA_UPDATE |  | clear |  |
| 22:01:13.564 | addon-event | CRITERIA_UPDATE |  | clear |  |
| 22:01:13.564 | addon-event | PARTY_KILL | Player-4618-00EB40D8 Creature-0-6782-1-545-3415-000046D435 | clear |  |
| 22:01:13.564 | addon-event | CRITERIA_UPDATE |  | clear |  |
| 22:01:13.564 | addon-event | CRITERIA_UPDATE |  | clear |  |
| 22:01:13.564 | addon-event | UNIT_TARGET | nameplate1 | clear |  |
| 22:01:13.564 | addon-event | UNIT_TARGET | target | clear |  |
| 22:01:13.564 | addon-event | UNIT_TARGET | focustarget | clear |  |
| 22:01:13.564 | addon-event | UNIT_DIED | Creature-0-6782-1-545-3415-000046D435 | clear |  |
| 22:01:13.564 | addon-event | PLAYER_TARGET_DIED |  | clear |  |
| 22:01:13.564 | addon-event | PLAYER_TARGET_CHANGED |  | clear |  |
| 22:01:13.564 | addon-event | UNIT_FLAGS | nameplate1 | clear |  |
| 22:01:13.564 | addon-event | UNIT_TARGET | player | clear |  |
| 22:01:13.564 | addon-event | UNIT_TARGET | focus | clear |  |
| 22:01:13.564 | addon-event | PLAYER_REGEN_DISABLED |  | clear |  |
| 22:01:13.564 | addon-event | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 22:01:13.564 | addon-event | PLAYER_IN_COMBAT_CHANGED | true | clear |  |
| 22:01:13.564 | addon-event | UNIT_FLAGS | player | clear |  |
| 22:01:13.564 | addon-event | UNIT_FLAGS | focus | clear |  |
| 22:01:13.564 | addon-event | ACTION_USABLE_CHANGED | [{"usable": false, "noMana": false, "slo | clear |  |
| 22:01:13.564 | addon-event | UNIT_AURA | player {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 22:01:13.564 | addon-event | UNIT_AURA | focus {"addedAuras": "<secrettable>", "isFullU | clear |  |
| 22:01:13.564 | addon-event | ACTIONBAR_UPDATE_COOLDOWN |  | clear |  |
| 22:01:13.564 | addon-event | ACTIONBAR_UPDATE_USABLE |  | clear |  |
| 22:01:13.564 | addon-event | BAG_UPDATE_COOLDOWN |  | clear |  |
| 22:01:13.564 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 13 | clear |  |
| 22:01:13.564 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 13 | clear |  |
| 22:01:13.564 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 22:01:13.564 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 0 | clear |  |
| 22:01:13.564 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 13 | clear |  |
| 22:01:13.564 | addon-event | DAMAGE_METER_CURRENT_SESSION_UPDATED |  | clear |  |
| 22:01:13.564 | addon-event | SPELL_UPDATE_COOLDOWN | 16257 <nil> <nil> <nil> <nil> | clear |  |
| 22:01:13.564 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 22:01:13.564 | addon-event | UNIT_HEALTH | nameplate1 | clear |  |
| 22:01:13.564 | addon-event | UNIT_HEALTH | player | clear |  |
| 22:01:13.564 | addon-event | UNIT_HEALTH | focus | clear |  |
| 22:01:13.564 | addon-event | UNIT_THREAT_LIST_UPDATE | nameplate1 | clear |  |
| 22:01:13.564 | addon-event | UNIT_THREAT_SITUATION_UPDATE | player | clear |  |
| 22:01:13.564 | addon-event | UNIT_THREAT_SITUATION_UPDATE | focus | clear |  |
| 22:01:13.564 | addon-event | CURSOR_CHANGED | true 0 0 0 | clear |  |
| 22:01:13.564 | addon-cl | PLAYER_SWING | 3.300000190734863 0 | clear |  |
| 22:01:13.564 | addon-cl | UNIT_DIED | Creature-0-6782-1-545-3415-000046D435 | clear |  |
| ... 75 more lines in timeline.jsonl | | | | | |

## Combat 5 (addon PLAYER_REGEN): 2026-10-07T22:01:16.961-04:00 .. 2026-10-07T22:02:02.170-04:00, 1117 lines

matches: exact 1, time+amount 56, time-only:amount-differs 27, unmatched 102

| time | source | event | details | secret | match |
|---|---|---|---|---|---|
| 22:01:16.961 | addon-event | CURSOR_CHANGED | true 0 0 0 | clear |  |
| 22:01:17.000 | addon-blocked | ADDON_ACTION_BLOCKED | ForeverDump UNKNOWN() | clear |  |
| 22:01:17.000 | addon-blocked | ADDON_ACTION_BLOCKED | ForeverDump UNKNOWN() | clear |  |
| 22:01:17.000 | addon-blocked | ADDON_ACTION_BLOCKED | ForeverDump UNKNOWN() | clear |  |
| 22:01:17.024 | addon-event | GLOBAL_MOUSE_DOWN | RightButton | clear |  |
| 22:01:17.024 | addon-event | GLOBAL_REGION_MOUSE_DOWN | <nil> RightButton | clear |  |
| 22:01:17.066 | addon-event | PLAYER_STOPPED_MOVING |  | clear |  |
| 22:01:17.128 | addon-event | GLOBAL_REGION_MOUSE_UP | <nil> RightButton | clear |  |
| 22:01:17.128 | addon-event | PLAYER_TARGET_CHANGED |  | clear |  |
| 22:01:17.128 | addon-event | GLOBAL_MOUSE_UP | RightButton | clear |  |
| 22:01:17.128 | addon-event | ACTION_RANGE_CHECK_UPDATE | 1 true true | clear |  |
| 22:01:17.128 | addon-event | ACTION_RANGE_CHECK_UPDATE | 4 true true | clear |  |
| 22:01:17.128 | addon-event | ACTION_RANGE_CHECK_UPDATE | 64 true true | clear |  |
| 22:01:17.128 | addon-event | ACTION_RANGE_CHECK_UPDATE | 3 true true | clear |  |
| 22:01:17.128 | addon-event | ACTION_RANGE_CHECK_UPDATE | 2 true true | clear |  |
| 22:01:17.128 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 22:01:17.128 | addon-cl | PLAYER_TARGET_CHANGED |  | clear |  |
| 22:01:17.191 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 22:01:17.191 | addon-event | UNIT_HEALTH | player | clear |  |
| 22:01:17.191 | addon-event | UNIT_HEALTH | focus | clear |  |
| 22:01:17.191 | addon-cl | UNIT_HEALTH | player | clear |  |
| 22:01:17.191 | addon-cl | UNIT_HEALTH | focus | clear |  |
| 22:01:17.200 | file-cl | SPELL_AURA_APPLIED_DOSE | Gorestomp-ClassicBetaPvE- -> Gorestomp-ClassicBetaPvE-  | unrestricted |  |
| 22:01:17.295 | addon-event | PLAYER_SWING | 2.750000238418579 0 | clear |  |
| 22:01:17.295 | addon-event | PLAYER_ENTER_COMBAT |  | clear |  |
| 22:01:17.295 | addon-event | UNIT_TARGET | player | clear |  |
| 22:01:17.295 | addon-event | UNIT_TARGET | focus | clear |  |
| 22:01:17.295 | addon-event | PLAYER_REGEN_DISABLED |  | clear |  |
| 22:01:17.295 | addon-event | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 22:01:17.295 | addon-event | PLAYER_IN_COMBAT_CHANGED | true | clear |  |
| 22:01:17.295 | addon-event | UNIT_FLAGS | player | clear |  |
| 22:01:17.295 | addon-event | UNIT_FLAGS | focus | clear |  |
| 22:01:17.295 | addon-event | WORLD_CURSOR_TOOLTIP_UPDATE | 1 | clear |  |
| 22:01:17.295 | addon-event | UNIT_TARGET | nameplate2 | clear |  |
| 22:01:17.295 | addon-event | UNIT_TARGET | target | clear |  |
| 22:01:17.295 | addon-event | UNIT_TARGET | focustarget | clear |  |
| 22:01:17.295 | addon-event | UNIT_FLAGS | nameplate2 | clear |  |
| 22:01:17.295 | addon-event | UNIT_FLAGS | target | clear |  |
| 22:01:17.295 | addon-event | UNIT_FLAGS | focustarget | clear |  |
| 22:01:17.295 | addon-event | PET_BAR_UPDATE_USABLE |  | clear |  |
| 22:01:17.295 | addon-event | ACTION_USABLE_CHANGED | [{"usable": false, "noMana": false, "slo | clear |  |
| 22:01:17.295 | addon-event | UNIT_AURA | player {"updatedAuraInstanceIDs": "<secrettable | clear |  |
| 22:01:17.295 | addon-event | UNIT_AURA | targettarget {"updatedAuraInstanceIDs": "<secrettable | clear |  |
| 22:01:17.295 | addon-event | UNIT_AURA | focus {"updatedAuraInstanceIDs": "<secrettable | clear |  |
| 22:01:17.295 | addon-event | ACTIONBAR_UPDATE_USABLE |  | clear |  |
| 22:01:17.295 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 13 | clear |  |
| 22:01:17.295 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 13 | clear |  |
| 22:01:17.295 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 22:01:17.295 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 0 | clear |  |
| 22:01:17.295 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 13 | clear |  |
| 22:01:17.295 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 22:01:17.295 | addon-event | UNIT_HEALTH | nameplate2 | clear |  |
| 22:01:17.295 | addon-event | UNIT_HEALTH | target | clear |  |
| 22:01:17.295 | addon-event | UNIT_HEALTH | focustarget | clear |  |
| 22:01:17.295 | addon-event | UNIT_THREAT_LIST_UPDATE | nameplate2 | clear |  |
| 22:01:17.295 | addon-event | UNIT_THREAT_LIST_UPDATE | target | clear |  |
| 22:01:17.295 | addon-event | UNIT_THREAT_LIST_UPDATE | focustarget | clear |  |
| 22:01:17.295 | addon-event | UNIT_THREAT_SITUATION_UPDATE | player | clear |  |
| 22:01:17.295 | addon-event | UNIT_THREAT_SITUATION_UPDATE | targettarget | clear |  |
| 22:01:17.295 | addon-event | UNIT_THREAT_SITUATION_UPDATE | focus | clear |  |
| 22:01:17.295 | addon-event | CURSOR_CHANGED | true 0 0 0 | clear |  |
| 22:01:17.295 | addon-event | WORLD_CURSOR_TOOLTIP_UPDATE | 0 | clear |  |
| 22:01:17.295 | addon-cl | PLAYER_SWING | 2.750000238418579 0 | clear |  |
| 22:01:17.295 | addon-cl | PLAYER_REGEN_DISABLED |  | clear |  |
| 22:01:17.295 | addon-cl | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 22:01:17.295 | addon-cl | UNIT_AURA | player {"updatedAuraInstanceIDs": "<secrettable | clear |  |
| 22:01:17.295 | addon-cl | UNIT_AURA | targettarget {"updatedAuraInstanceIDs": "<secrettable | clear |  |
| 22:01:17.295 | addon-cl | UNIT_AURA | focus {"updatedAuraInstanceIDs": "<secrettable | clear |  |
| 22:01:17.295 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 13 | clear |  |
| 22:01:17.295 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 13 | clear |  |
| 22:01:17.295 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 22:01:17.295 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 0 | clear |  |
| 22:01:17.295 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 13 | clear |  |
| 22:01:17.295 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 0 | clear |  |
| 22:01:17.295 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 7 13 | clear |  |
| 22:01:17.295 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 7 0 | clear |  |
| 22:01:17.295 | addon-cl | UNIT_HEALTH | nameplate2 | clear |  |
| 22:01:17.295 | addon-cl | UNIT_HEALTH | target | clear |  |
| 22:01:17.295 | addon-cl | UNIT_HEALTH | focustarget | clear |  |
| 22:01:17.295 | addon-cl | UNIT_HEALTH | player | clear |  |
| ... 1037 more lines in timeline.jsonl | | | | | |

## Combat 6 (addon PLAYER_REGEN): 2026-10-07T22:02:31.000-04:00 .. 2026-10-07T22:04:02.478-04:00, 2459 lines

matches: exact 41, time+amount 57, time-only:amount-differs 55, unmatched 197

| time | source | event | details | secret | match |
|---|---|---|---|---|---|
| 22:02:31.000 | addon-blocked | ADDON_ACTION_BLOCKED | ForeverDump UNKNOWN() | clear |  |
| 22:02:31.000 | addon-blocked | ADDON_ACTION_BLOCKED | ForeverDump UNKNOWN() | clear |  |
| 22:02:31.054 | addon-event | ACTION_RANGE_CHECK_UPDATE | 1 true true | clear |  |
| 22:02:31.700 | file-cl | SPELL_AURA_APPLIED | Tye-ClassicBetaPvE- -> Tye-ClassicBetaPvE-  | unrestricted |  |
| 22:02:31.700 | file-cl | SPELL_AURA_APPLIED | Kasper-ClassicBetaPvE- -> Tye-ClassicBetaPvE-  | unrestricted |  |
| 22:02:31.700 | file-cl | SWING_DAMAGE | Uglaz-ClassicBetaPvE- -> Savannah Huntress 259 | unrestricted | <- UNIT_COMBAT |
| 22:02:31.700 | file-cl | SWING_MISSED | Savannah Huntress -> Uglaz-ClassicBetaPvE-  | unrestricted | <- UNIT_COMBAT |
| 22:02:31.700 | file-cl | SWING_DAMAGE_LANDED | Uglaz-ClassicBetaPvE- -> Savannah Huntress 259 | unrestricted | <- UNIT_COMBAT |
| 22:02:31.707 | file-cl | SPELL_AURA_APPLIED | Uglaz-ClassicBetaPvE- -> Uglaz-ClassicBetaPvE-  | unrestricted |  |
| 22:02:31.721 | addon-event | SPELL_ACTIVATION_OVERLAY_HIDE | <nil> | clear |  |
| 22:02:31.721 | addon-event | SPELL_ACTIVATION_OVERLAY_HIDE | <nil> | clear |  |
| 22:02:31.721 | addon-event | PLAYER_SWING | 3.300000190734863 0 | clear |  |
| 22:02:31.721 | addon-event | UNIT_TARGET | nameplate1 | clear |  |
| 22:02:31.721 | addon-event | UNIT_TARGET | target | clear |  |
| 22:02:31.721 | addon-event | UNIT_FLAGS | nameplate1 | clear |  |
| 22:02:31.721 | addon-event | UNIT_FLAGS | target | clear |  |
| 22:02:31.721 | addon-event | PLAYER_REGEN_DISABLED |  | clear |  |
| 22:02:31.721 | addon-event | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 22:02:31.721 | addon-event | PLAYER_IN_COMBAT_CHANGED | true | clear |  |
| 22:02:31.721 | addon-event | UNIT_FLAGS | player | clear |  |
| 22:02:31.721 | addon-event | UNIT_FLAGS | targettarget | clear |  |
| 22:02:31.721 | addon-event | ACTION_USABLE_CHANGED | [{"usable": false, "noMana": false, "slo | clear |  |
| 22:02:31.721 | addon-event | UNIT_AURA | player {"isFullUpdate": "<secret>", "addedAuras | clear |  |
| 22:02:31.721 | addon-event | UNIT_AURA | targettarget {"isFullUpdate": "<secret>", "addedAuras | clear |  |
| 22:02:31.721 | addon-event | ACTIONBAR_UPDATE_COOLDOWN |  | clear |  |
| 22:02:31.721 | addon-event | ACTIONBAR_UPDATE_USABLE |  | clear |  |
| 22:02:31.721 | addon-event | BAG_UPDATE_COOLDOWN |  | clear |  |
| 22:02:31.721 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 14 | clear |  |
| 22:02:31.721 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 14 | clear |  |
| 22:02:31.721 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 22:02:31.721 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 0 | clear |  |
| 22:02:31.721 | addon-event | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 14 | clear |  |
| 22:02:31.721 | addon-event | DAMAGE_METER_CURRENT_SESSION_UPDATED |  | clear |  |
| 22:02:31.721 | addon-event | SPELL_UPDATE_COOLDOWN | 16257 <nil> <nil> <nil> <nil> | clear |  |
| 22:02:31.721 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 22:02:31.721 | addon-event | UNIT_HEALTH | nameplate1 | clear |  |
| 22:02:31.721 | addon-event | UNIT_HEALTH | target | clear |  |
| 22:02:31.721 | addon-event | UNIT_THREAT_LIST_UPDATE | nameplate1 | clear |  |
| 22:02:31.721 | addon-event | UNIT_THREAT_LIST_UPDATE | target | clear |  |
| 22:02:31.721 | addon-event | UNIT_THREAT_SITUATION_UPDATE | player | clear |  |
| 22:02:31.721 | addon-event | UNIT_THREAT_SITUATION_UPDATE | targettarget | clear |  |
| 22:02:31.721 | addon-cl | PLAYER_SWING | 3.300000190734863 0 | clear |  |
| 22:02:31.721 | addon-cl | PLAYER_REGEN_DISABLED |  | clear |  |
| 22:02:31.721 | addon-cl | ADDON_RESTRICTION_STATE_CHANGED | 0 1 | clear |  |
| 22:02:31.721 | addon-cl | UNIT_AURA | player {"isFullUpdate": "<secret>", "addedAuras | clear |  |
| 22:02:31.721 | addon-cl | UNIT_AURA | targettarget {"isFullUpdate": "<secret>", "addedAuras | clear |  |
| 22:02:31.721 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 14 | clear |  |
| 22:02:31.721 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 14 | clear |  |
| 22:02:31.721 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 0 0 | clear |  |
| 22:02:31.721 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 1 0 | clear |  |
| 22:02:31.721 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 14 | clear |  |
| 22:02:31.721 | addon-cl | DAMAGE_METER_COMBAT_SESSION_UPDATED | 10 0 | clear |  |
| 22:02:31.721 | addon-cl | DAMAGE_METER_CURRENT_SESSION_UPDATED |  | clear |  |
| 22:02:31.721 | addon-cl | UNIT_HEALTH | nameplate1 | clear |  |
| 22:02:31.721 | addon-cl | UNIT_HEALTH | target | clear |  |
| 22:02:31.721 | addon-restriction | RESTRICTION Combat:Activating | 0 PLAYER_REGEN_DISABLED secret after flip: GetRaidTargetIndex(ta | clear |  |
| 22:02:31.721 | addon-context | PLAYER_REGEN_DISABLED | null null | clear |  |
| 22:02:31.721 | addon-context | PLAYER_IN_COMBAT_CHANGED | null null | clear |  |
| 22:02:31.828 | addon-event | ADDON_ACTION_BLOCKED | ForeverDump UNKNOWN() | clear |  |
| 22:02:31.828 | addon-event | ADDON_ACTION_BLOCKED | ForeverDump UNKNOWN() | clear |  |
| 22:02:32.000 | addon-probe | probe:inCombat | capture:combat | clear |  |
| 22:02:32.078 | addon-event | PET_BAR_UPDATE_USABLE |  | clear |  |
| 22:02:32.078 | addon-event | COMBAT_RATING_UPDATE |  | clear |  |
| 22:02:32.078 | addon-event | UNIT_ATTACK_SPEED | player | clear |  |
| 22:02:32.078 | addon-event | UNIT_ATTACK_SPEED | targettarget | clear |  |
| 22:02:32.078 | addon-event | UNIT_ATTACK_SPEED | player | clear |  |
| 22:02:32.078 | addon-event | UNIT_ATTACK_SPEED | targettarget | clear |  |
| 22:02:32.078 | addon-event | SPELL_UPDATE_USABLE |  | clear |  |
| 22:02:32.098 | addon-event | NAME_PLATE_UNIT_REMOVED | nameplate2 | clear |  |
| 22:02:32.140 | addon-event | UNIT_COMBAT | player MISS  0 1 | clear | time-only:amount-differs (-440 ms) SWING_MISSED Savannah Huntress->Uglaz-ClassicBetaPvE- None |
| 22:02:32.140 | addon-event | UNIT_COMBAT | targettarget MISS  0 1 | clear | time-only:amount-differs (-440 ms) SWING_DAMAGE Uglaz-ClassicBetaPvE-->Savannah Huntress 259 |
| 22:02:32.140 | addon-cl | UNIT_COMBAT | player MISS  0 1 | clear | unmatched |
| 22:02:32.140 | addon-cl | UNIT_COMBAT | targettarget MISS  0 1 | clear | time-only:amount-differs (-440 ms) SWING_DAMAGE_LANDED Uglaz-ClassicBetaPvE-->Savannah Huntress 259 |
| 22:02:32.182 | addon-event | GLOBAL_REGION_MOUSE_UP | <nil> RightButton | clear |  |
| 22:02:32.182 | addon-event | PLAYER_STOPPED_MOVING |  | clear |  |
| 22:02:32.182 | addon-event | PLAYER_STOPPED_TURNING |  | clear |  |
| 22:02:32.182 | addon-event | GLOBAL_MOUSE_UP | RightButton | clear |  |
| 22:02:32.182 | addon-event | PLAYER_STARTED_MOVING |  | clear |  |
| 22:02:32.182 | addon-event | UNIT_COMBAT | nameplate1 WOUND CRITICAL 259 1 | clear | unmatched |
| 22:02:32.182 | addon-event | UNIT_COMBAT | target WOUND CRITICAL 259 1 | clear | unmatched |
| ... 2379 more lines in timeline.jsonl | | | | | |

