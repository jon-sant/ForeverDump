## Co-occurrence miner (tools/fdump/correlate.py)

Captures: run3, run4, run5. 1-hop windows 50/150/300/750 ms; higher-order adds 1.5 s and depth <= 4 (profile full). Lift vs shuffled-time null; provisional = one fight; holdout on the other captures.

### Rules not already encoded in the HSM (new leads)

| capture | kind | A | B | window ms | support | precision | recall | lift | lag s | flags | holdout |
|---|---|---|---|---|---|---|---|---|---|---|---|
| run3 | live->truth | `UNIT_HEAL_PREDICTION|player` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 25/32 | 0.781 | 1.0 | 35.8 | -0.022 | provisional | run4:held(0.625); run5:held(0.895) |
| run3 | live->truth | `UNIT_HEAL_PREDICTION|targettarget` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 21/23 | 0.913 | 0.84 | 41.9 | -0.022 | provisional | run4:held(1.0); run5:held(0.97) |
| run3 | live->truth | `UNIT_HEAL_PREDICTION|player` | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 50 | 24/32 | 0.75 | 0.96 | 34.4 | -0.023 | provisional | run4:held(0.583); run5:held(0.877) |
| run3 | live->truth | `UNIT_HEAL_PREDICTION|targettarget` | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 50 | 20/23 | 0.87 | 0.8 | 39.9 | -0.023 | provisional | run4:held(0.933); run5:held(0.939) |
| run3 | live->live | `UNIT_SPELLCAST_SUCCEEDED|player` | `BAG_UPDATE_COOLDOWN` | 50 | 8/8 | 1.0 | 0.727 | 104.3 | 0.0 | provisional | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `UNIT_SPELLCAST_SUCCEEDED|targettarget` | `BAG_UPDATE_COOLDOWN` | 50 | 8/8 | 1.0 | 0.727 | 104.3 | 0.0 | provisional | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|player` | `UNIT_SPELLCAST_SUCCEEDED|player` | 50 | 7/8 | 0.875 | 0.875 | 125.5 | 0.0 | provisional | run4:held(0.875); run5:held(0.84) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|player` | `UNIT_SPELLCAST_SUCCEEDED|targettarget` | 50 | 7/8 | 0.875 | 0.875 | 125.5 | 0.0 | provisional | run4:held(0.812); run5:held(0.48) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|player` | `BAG_UPDATE_COOLDOWN` | 50 | 7/8 | 0.875 | 0.636 | 91.2 | 0.0 | provisional | run4:held(0.875); run5:held(0.84) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|targettarget` | `UNIT_SPELLCAST_SUCCEEDED|player` | 50 | 7/8 | 0.875 | 0.875 | 125.5 | 0.0 | provisional | run4:held(1.0); run5:held(0.857) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|targettarget` | `UNIT_SPELLCAST_SUCCEEDED|targettarget` | 50 | 7/8 | 0.875 | 0.875 | 125.5 | 0.0 | provisional | run4:held(1.0); run5:held(0.857) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|targettarget` | `BAG_UPDATE_COOLDOWN` | 50 | 7/8 | 0.875 | 0.636 | 91.2 | 0.0 | provisional | run4:held(1.0); run5:held(0.857) |
| run3 | live->live | `PLAYER_TARGET_CHANGED` | `ACTION_RANGE_CHECK_UPDATE|arg0=1` | 50 | 6/7 | 0.857 | 0.857 | 140.5 | 0.0 |  | run4:held(1.0); run5:held(0.667) |
| run3 | live->live | `PLAYER_TARGET_CHANGED` | `ACTION_RANGE_CHECK_UPDATE|arg0=4` | 50 | 6/7 | 0.857 | 1.0 | 163.9 | 0.0 |  | run4:held(1.0); run5:held(0.667) |
| run3 | live->live | `UNIT_SPELLCAST_SUCCEEDED|player` | `UNIT_HAPPINESS|targettarget` | 50 | 8/8 | 1.0 | 0.258 | 37.0 | 0.0 | provisional | run4:held(0.812); run5:held(0.56) |
| run3 | live->live | `UNIT_SPELLCAST_SUCCEEDED|targettarget` | `UNIT_HAPPINESS|targettarget` | 50 | 8/8 | 1.0 | 0.258 | 37.0 | 0.0 | provisional | run4:held(1.0); run5:held(0.857) |
| run3 | live->live | `UNIT_HAPPINESS|targettarget` | `BAG_UPDATE_COOLDOWN` | 50 | 9/31 | 0.29 | 0.818 | 30.3 | 0.0 | provisional | run4:held(0.424); run5:held(0.395) |
| run3 | live->truth | `SPELL_ACTIVATION_OVERLAY_HIDE` | `SPELL_AURA_APPLIED|player>player` | 50 | 8/34 | 0.235 | 1.0 | 33.7 | -0.021 | provisional | run4:failed(0.0); run5:held(0.242) |
| run3 | live->live | `UNIT_SPELLCAST_SUCCEEDED|player` | `UNIT_HAPPINESS|player` | 50 | 8/8 | 1.0 | 0.235 | 33.7 | 0.0 | provisional | run4:held(1.0); run5:held(0.92) |
| run3 | live->live | `UNIT_SPELLCAST_SUCCEEDED|targettarget` | `UNIT_HAPPINESS|player` | 50 | 8/8 | 1.0 | 0.235 | 33.7 | 0.0 | provisional | run4:held(1.0); run5:held(0.857) |
| run3 | live->live | `UNIT_HAPPINESS|player` | `BAG_UPDATE_COOLDOWN` | 50 | 9/34 | 0.265 | 0.818 | 27.6 | 0.0 | provisional | run4:held(0.386); run5:held(0.325) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg3=133` | `UNIT_SPELLCAST_SENT|player` | 300 | 16/19 | 0.842 | 1.0 | 20.1 | 0.054 | provisional | run4:held(0.938); run5:held(0.864) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg3=133` | `UNIT_SPELLCAST_SENT|targettarget` | 300 | 16/19 | 0.842 | 1.0 | 20.1 | 0.054 | provisional | run4:held(0.75); run5:held(0.492) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|player` | `UNIT_HAPPINESS|targettarget` | 50 | 7/8 | 0.875 | 0.226 | 32.4 | 0.0 | provisional | run4:held(0.812); run5:held(0.56) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|targettarget` | `UNIT_HAPPINESS|targettarget` | 50 | 7/8 | 0.875 | 0.226 | 32.4 | 0.0 | provisional | run4:held(1.0); run5:held(0.857) |
| run3 | live->live | `BAG_UPDATE_COOLDOWN` | `SPELL_UPDATE_COOLDOWN` | 300 | 11/11 | 1.0 | 0.9 | 15.6 | 0.0 | provisional | run4:held(1.0); run5:held(1.0) |
| run3 | live->truth | `SPELL_UPDATE_COOLDOWN|arg0=370` | `SPELL_CAST_SUCCESS|me>npc|spell=370` | 300 | 6/6 | 1.0 | 1.0 | 63.7 | 0.056 | provisional,id-match | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg0=370` | `UNIT_SPELLCAST_SENT|player|arg1=Savannah Huntress` | 300 | 6/6 | 1.0 | 1.0 | 63.7 | 0.078 | provisional | run4:failed(0.0); run5:failed(0.0) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg0=370` | `UNIT_SPELLCAST_SENT|targettarget|arg1=Savannah Huntress` | 300 | 6/6 | 1.0 | 1.0 | 63.7 | 0.078 | provisional | run4:failed(0.0); run5:failed(0.0) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg0=370` | `UNIT_SPELLCAST_SUCCEEDED|player|arg2=370` | 300 | 6/6 | 1.0 | 1.0 | 63.7 | 0.078 | provisional,id-match | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg0=370` | `UNIT_SPELLCAST_SUCCEEDED|targettarget|arg2=370` | 300 | 6/6 | 1.0 | 1.0 | 63.7 | 0.078 | provisional,id-match | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg3=133` | `UNIT_SPELLCAST_SUCCEEDED|player` | 300 | 15/19 | 0.789 | 1.0 | 18.9 | 0.0 | provisional | run4:held(0.875); run5:held(0.797) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg3=133` | `UNIT_SPELLCAST_SUCCEEDED|targettarget` | 300 | 15/19 | 0.789 | 1.0 | 18.9 | 0.0 | provisional | run4:held(0.75); run5:held(0.458) |
| run3 | live->live | `SPELL_UPDATE_COOLDOWN|arg3=133` | `BAG_UPDATE_COOLDOWN` | 300 | 17/19 | 0.895 | 0.909 | 15.6 | 0.0 | provisional | run4:held(0.875); run5:held(0.847) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|player` | `UNIT_HAPPINESS|player` | 50 | 7/8 | 0.875 | 0.206 | 29.5 | 0.0 | provisional | run4:held(0.938); run5:held(0.84) |
| run3 | live->live | `UNIT_SPELLCAST_SENT|targettarget` | `UNIT_HAPPINESS|player` | 50 | 7/8 | 0.875 | 0.206 | 29.5 | 0.0 | provisional | run4:held(1.0); run5:held(0.857) |
| run3 | live->truth | `BAG_UPDATE_COOLDOWN` | `SPELL_CAST_SUCCESS|me>none` | 50 | 4/11 | 0.364 | 1.0 | 104.3 | -0.021 | provisional | run4:held(0.5); run5:held(0.278) |
| run3 | live->truth | `BAG_UPDATE_COOLDOWN` | `SPELL_SUMMON|me>mine` | 50 | 4/11 | 0.364 | 1.0 | 104.3 | -0.021 | provisional | run4:held(0.3); run5:failed(0.167) |
| run3 | truth->truth | `SPELL_CAST_SUCCESS|me>none` | `SPELL_SUMMON|me>mine` | 50 | 4/4 | 1.0 | 1.0 | 573.5 | 0.0 | provisional | run4:held(0.6); run5:held(0.6) |
| run3 | truth->truth | `SPELL_SUMMON|me>mine` | `SPELL_CAST_SUCCESS|me>none` | 50 | 4/4 | 1.0 | 1.0 | 573.5 | 0.0 | provisional | run4:held(0.833); run5:failed(0.333) |

### Rediscovered (already known)

| capture | kind | A | B | window ms | support | precision | recall | lift | lag s | flags | holdout |
|---|---|---|---|---|---|---|---|---|---|---|---|
| run3 | truth->truth | `SWING_DAMAGE|npc>me` | `SWING_DAMAGE_LANDED|npc>me` | 50 | 48/49 | 0.98 | 0.98 | 45.9 | 0.0 | provisional,log structure | run4:held(1.0); run5:held(1.0) |
| run3 | truth->truth | `SWING_DAMAGE_LANDED|npc>me` | `SWING_DAMAGE|npc>me` | 50 | 46/49 | 0.939 | 0.939 | 44.0 | 0.0 | provisional,log structure | run4:held(0.933); run5:held(1.0) |
| run3 | truth->truth | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 24/25 | 0.96 | 0.96 | 88.1 | 0.0 | provisional,id-match,same spell | run4:held(0.933); run5:held(0.847) |
| run3 | live->live | `GLOBAL_MOUSE_DOWN` | `GLOBAL_REGION_MOUSE_DOWN` | 50 | 23/23 | 1.0 | 1.0 | 49.9 | 0.0 | ui echo | run4:held(1.0); run5:held(1.0) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=7` | `SWING_DAMAGE|npc>me` | 50 | 49/49 | 1.0 | 1.0 | 23.4 | -0.023 | provisional,damage meter | run4:held(0.652); run5:held(0.846) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=7` | `SWING_DAMAGE_LANDED|npc>me` | 50 | 49/49 | 1.0 | 1.0 | 23.4 | -0.023 | provisional,damage meter | run4:held(0.652); run5:held(0.846) |
| run3 | live->live | `UNIT_COMBAT|player|arg1=HEAL` | `UNIT_HEAL_PREDICTION|player` | 50 | 31/31 | 1.0 | 0.969 | 35.8 | 0.0 | unit combat | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `UNIT_POWER_UPDATE|targettarget|arg1=MANA` | `UNIT_HAPPINESS|targettarget` | 50 | 31/32 | 0.969 | 1.0 | 35.8 | 0.0 | provisional,health side effect | run4:held(0.943); run5:held(0.977) |
| run3 | live->live | `UNIT_COMBAT|targettarget|arg1=HEAL` | `UNIT_HEAL_PREDICTION|targettarget` | 50 | 22/22 | 1.0 | 0.957 | 49.9 | 0.0 | provisional,unit combat | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `UNIT_POWER_UPDATE|player|arg1=MANA` | `UNIT_HAPPINESS|player` | 50 | 34/36 | 0.944 | 1.0 | 31.9 | 0.0 | health side effect | run4:held(0.936); run5:held(0.976) |
| run3 | live->live | `UNIT_COMBAT|player|arg1=WOUND` | `UNIT_COMBAT|targettarget|arg1=WOUND` | 50 | 48/49 | 0.98 | 0.941 | 22.0 | 0.0 | provisional,token alias | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `GLOBAL_REGION_MOUSE_UP` | `GLOBAL_MOUSE_UP` | 50 | 22/23 | 0.957 | 0.957 | 47.7 | 0.0 | ui echo | run4:held(0.96); run5:held(0.974) |
| run3 | live->live | `UNIT_HAPPINESS|player` | `UNIT_HAPPINESS|targettarget` | 50 | 31/34 | 0.912 | 1.0 | 33.7 | 0.0 | provisional,token alias | run4:held(0.75); run5:held(0.537) |
| run3 | live->live | `UNIT_COMBAT|player|arg3=6` | `UNIT_HEAL_PREDICTION|player` | 50 | 29/29 | 1.0 | 0.906 | 35.8 | 0.0 | unit combat | run4:held(1.0); run5:absent |
| run3 | live->live | `UNIT_COMBAT|player|arg1=HEAL` | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | 50 | 28/31 | 0.903 | 1.0 | 37.0 | 0.0 | unit combat | run4:held(0.696); run5:held(0.623) |
| run3 | live->live | `UNIT_COMBAT|player|arg1=HEAL` | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` | 50 | 28/31 | 0.903 | 1.0 | 37.0 | 0.0 | unit combat | run4:held(0.696); run5:held(0.623) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 25/28 | 0.893 | 1.0 | 41.0 | -0.022 | provisional,damage meter | run4:held(0.938); run5:held(0.97) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 25/28 | 0.893 | 1.0 | 41.0 | -0.022 | provisional,damage meter | run4:held(0.938); run5:held(0.97) |
| run3 | live->live | `UNIT_POWER_UPDATE|player|arg1=MANA` | `UNIT_POWER_UPDATE|targettarget|arg1=MANA` | 50 | 32/36 | 0.889 | 1.0 | 31.9 | 0.0 | provisional,token alias | run4:held(0.745); run5:held(0.537) |
| run3 | live->live | `UNIT_POWER_UPDATE|targettarget|arg1=MANA` | `UNIT_HAPPINESS|player` | 50 | 31/32 | 0.969 | 0.912 | 32.7 | 0.0 | provisional,health side effect | run4:held(0.943); run5:held(0.977) |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | `UNIT_HEAL_PREDICTION|player` | 50 | 28/28 | 1.0 | 0.875 | 35.8 | 0.0 | damage meter | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` | `UNIT_HEAL_PREDICTION|player` | 50 | 28/28 | 1.0 | 0.875 | 35.8 | 0.0 | damage meter | run4:held(1.0); run5:held(1.0) |
| run3 | live->live | `ACTIONBAR_UPDATE_COOLDOWN` | `SPELL_UPDATE_COOLDOWN` | 50 | 20/21 | 0.952 | 1.0 | 54.6 | 0.0 | provisional,ui echo | run4:held(0.925); run5:held(0.971) |
| run3 | live->live | `UNIT_COMBAT|targettarget|arg3=6` | `UNIT_HEAL_PREDICTION|targettarget` | 50 | 20/20 | 1.0 | 0.87 | 49.9 | 0.0 | provisional,unit combat | run4:held(1.0); run5:absent |
| run3 | live->live | `UNIT_POWER_UPDATE|player|arg1=MANA` | `UNIT_HAPPINESS|targettarget` | 50 | 31/36 | 0.861 | 1.0 | 31.9 | 0.0 | provisional,health side effect | run4:held(0.702); run5:held(0.524) |
| run3 | live->live | `UNIT_COMBAT|player|arg2=` | `UNIT_COMBAT|targettarget|arg2=` | 50 | 75/85 | 0.882 | 0.962 | 13.1 | 0.0 | provisional,token alias | run4:held(0.826); run5:held(0.776) |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg1=0` | `UNIT_HEALTH|targettarget` | 50 | 68/76 | 0.895 | 0.944 | 14.3 | 0.0 | provisional,damage meter | run4:held(0.787); run5:held(0.593) |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg1=14` | `UNIT_HEALTH|targettarget` | 50 | 68/76 | 0.895 | 0.944 | 14.3 | 0.0 | provisional,damage meter | run4:absent; run5:absent |
| run3 | live->live | `ACTIONBAR_UPDATE_COOLDOWN` | `SPELL_UPDATE_COOLDOWN|arg3=133` | 50 | 19/21 | 0.905 | 1.0 | 54.6 | 0.0 | provisional,ui echo | run4:held(0.8); run5:held(0.868) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 50 | 24/28 | 0.857 | 0.96 | 39.3 | -0.023 | provisional,damage meter | run4:held(0.875); run5:held(0.939) |
| run3 | live->truth | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` | `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 50 | 24/28 | 0.857 | 0.96 | 39.3 | -0.023 | provisional,damage meter | run4:held(0.875); run5:held(0.939) |
| run3 | live->truth | `UNIT_COMBAT|player|arg1=HEAL` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 25/31 | 0.806 | 1.0 | 37.0 | -0.022 | provisional,unit combat | run4:held(0.652); run5:held(0.962) |
| run3 | live->truth | `UNIT_COMBAT|targettarget|arg1=HEAL` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 21/22 | 0.955 | 0.84 | 43.8 | -0.022 | provisional,unit combat | run4:held(1.0); run5:held(1.0) |
| run3 | live->truth | `UNIT_COMBAT|targettarget|arg3=6` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 20/20 | 1.0 | 0.8 | 45.9 | -0.023 | provisional,unit combat | run4:held(1.0); run5:absent |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg1=0` | `UNIT_HEALTH|player` | 50 | 74/76 | 0.974 | 0.822 | 12.4 | 0.0 | damage meter | run4:held(0.83); run5:held(0.648) |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg1=14` | `UNIT_HEALTH|player` | 50 | 74/76 | 0.974 | 0.822 | 12.4 | 0.0 | damage meter | run4:absent; run5:absent |
| run3 | live->truth | `UNIT_COMBAT|player|arg3=6` | `SPELL_PERIODIC_HEAL|mine>me|spell=6371` | 50 | 24/29 | 0.828 | 0.96 | 38.0 | -0.022 | provisional,unit combat | run4:held(0.667); run5:absent |
| run3 | live->live | `UNIT_COMBAT|targettarget|arg1=HEAL` | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | 50 | 22/22 | 1.0 | 0.786 | 41.0 | 0.0 | provisional,unit combat | run4:held(1.0); run5:held(0.875) |
| run3 | live->live | `UNIT_COMBAT|targettarget|arg1=HEAL` | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` | 50 | 22/22 | 1.0 | 0.786 | 41.0 | 0.0 | provisional,unit combat | run4:held(1.0); run5:held(0.875) |
| run3 | live->live | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` | `UNIT_HEAL_PREDICTION|targettarget` | 50 | 22/28 | 0.786 | 0.957 | 39.2 | 0.0 | provisional,damage meter | run4:held(0.938); run5:held(0.848) |

### Rare targets (B seen fewer than min-support times; best A per B by id match, then null probability) - provisional by nature

| capture | kind | A | B | rank | id match | p(null) | precision | lag s | holdout |
|---|---|---|---|---|---|---|---|---|---|
| run3 | live->live | `UPDATE_MACROS` | `ACTIONBAR_SLOT_CHANGED` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `ACTION_RANGE_CHECK_UPDATE|arg0=10` | `ACTIONBAR_SLOT_CHANGED|arg0=10` | 1 | False | 1.2e-05 | 0.667 | 0.0 | run3:failed; run5:failed |
| run4 | live->live | `ACTION_RANGE_CHECK_UPDATE|arg0=11` | `ACTIONBAR_SLOT_CHANGED|arg0=11` | 1 | False | 3.5e-05 | 0.4 | 0.0 | run3:failed; run5:held |
| run4 | live->live | `ACTION_RANGE_CHECK_UPDATE|arg0=10` | `ACTIONBAR_SLOT_CHANGED|arg0=183` | 1 | False | 1.2e-05 | 0.667 | 0.0 | run3:failed; run5:failed |
| run3 | live->live | `UPDATE_MACROS` | `ACTIONBAR_SLOT_CHANGED|arg0=60` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `UPDATE_MACROS` | `ACTIONBAR_SLOT_CHANGED|arg0=60` | 1 | False | 0.001177 | 1.0 | 0.0 | run3:held; run5:held |
| run5 | live->live | `UPDATE_MACROS` | `ACTIONBAR_SLOT_CHANGED|arg0=60` | 1 | False | 0.000697 | 1.0 | 0.0 | run3:held; run4:held |
| run4 | live->live | `ACTIONBAR_SLOT_CHANGED|arg0=66` | `UPDATE_SHAPESHIFT_FORM` | 1 | False | 1.2e-05 | 1.0 | 0.0 | run3:absent; run5:held |
| run5 | live->truth | `ACTIONBAR_SLOT_CHANGED|arg0=66` | `SPELL_AURA_APPLIED|me>me|spell=905` | 1 | False | 0.00209 | 1.0 | 0.002 | run3:absent; run4:failed |
| run5 | live->live | `ACTION_RANGE_CHECK_UPDATE|arg0=66` | `ACTIONBAR_SLOT_CHANGED|arg0=66` | 1 | False | 0.000697 | 1.0 | 0.0 | run3:absent; run4:held |
| run5 | live->truth | `ACTIONBAR_SLOT_CHANGED|arg0=66` | `SPELL_CAST_SUCCESS|me>none|spell=905` | 2 | False | 0.00209 | 1.0 | 0.004 | run3:absent; run4:failed |
| run5 | live->truth | `ACTIONBAR_SLOT_CHANGED|arg0=66` | `SPELL_AURA_REMOVED|me>me` | 3 | False | 0.002787 | 1.0 | 0.001 | run3:absent; run4:held |
| run3 | live->live | `ADDON_RESTRICTION_STATE_CHANGED` | `ACTIONBAR_UPDATE_USABLE` | 1 | False | 3e-06 | 1.0 | 0.0 | run4:held; run5:held |
| run3 | live->live | `MODIFIER_STATE_CHANGED|arg0=LALT` | `ACTION_RANGE_CHECK_UPDATE|arg0=26` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:absent; run5:held |
| run5 | live->live | `MODIFIER_STATE_CHANGED|arg1=1` | `ACTION_RANGE_CHECK_UPDATE|arg0=26` | 1 | False | 0.000697 | 1.0 | 0.0 | run3:failed; run4:failed |
| run3 | live->live | `MODIFIER_STATE_CHANGED|arg0=LALT` | `ACTION_RANGE_CHECK_UPDATE|arg0=5` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:absent; run5:held |
| run4 | live->truth | `ACTION_RANGE_CHECK_UPDATE|arg0=63` | `SPELL_CAST_START|npc>none` | 1 | False | 0.009415 | 1.0 | 0.026 | run3:absent; run5:absent |
| run4 | live->live | `UNIT_COMBAT|player|arg3=20` | `ACTION_RANGE_CHECK_UPDATE|arg0=63` | 1 | False | 0.005884 | 0.2 | 0.0 | run3:absent; run5:absent |
| run4 | live->truth | `ACTION_RANGE_CHECK_UPDATE|arg0=63` | `SPELL_CAST_START|npc>none|spell=7951` | 2 | False | 0.009415 | 1.0 | 0.026 | run3:absent; run5:absent |
| run5 | live->truth | `ACTION_RANGE_CHECK_UPDATE|arg0=66` | `SPELL_AURA_APPLIED|me>me|spell=905` | 1 | False | 0.00209 | 1.0 | 0.002 | run3:absent; run4:failed |
| run5 | live->live | `ACTION_RANGE_CHECK_UPDATE|arg0=66` | `UNIT_PORTRAIT_UPDATE|player` | 1 | False | 0.001282 | 1.0 | 0.02 | run3:absent; run4:held |
| run5 | live->truth | `ACTION_RANGE_CHECK_UPDATE|arg0=66` | `SPELL_CAST_SUCCESS|me>none|spell=905` | 2 | False | 0.00209 | 1.0 | 0.004 | run3:absent; run4:failed |
| run5 | live->truth | `ACTION_RANGE_CHECK_UPDATE|arg0=66` | `SPELL_AURA_REMOVED|me>me` | 3 | False | 0.002787 | 1.0 | 0.001 | run3:absent; run4:failed |
| run3 | live->live | `MODIFIER_STATE_CHANGED|arg0=LALT` | `ACTION_RANGE_CHECK_UPDATE|arg0=68` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:absent; run5:held |
| run5 | live->live | `MODIFIER_STATE_CHANGED|arg1=1` | `ACTION_RANGE_CHECK_UPDATE|arg0=68` | 1 | False | 0.000697 | 1.0 | 0.0 | run3:failed; run4:failed |
| run4 | live->live | `UNIT_COMBAT|player|arg3=21` | `ACTION_RANGE_CHECK_UPDATE|arg0=9` | 1 | False | 0.004707 | 0.25 | 0.0 | run3:absent; run5:absent |
| run3 | live->live | `ADDON_RESTRICTION_STATE_CHANGED` | `ACTION_USABLE_CHANGED` | 1 | False | 3e-06 | 1.0 | 0.0 | run4:held; run5:held |
| run3 | live->live | `ADDON_RESTRICTION_STATE_CHANGED` | `UNIT_THREAT_SITUATION_UPDATE|player` | 1 | False | 1.9e-05 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `ADDON_RESTRICTION_STATE_CHANGED` | `ACTION_USABLE_CHANGED` | 1 | False | 1.2e-05 | 1.0 | 0.0 | run3:held; run5:held |
| run3 | live->live | `ADDON_RESTRICTION_STATE_CHANGED|arg0=0` | `UNIT_THREAT_SITUATION_UPDATE|player` | 1 | False | 1.9e-05 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `ADDON_RESTRICTION_STATE_CHANGED|arg0=0` | `ACTION_USABLE_CHANGED` | 1 | False | 1.2e-05 | 1.0 | 0.0 | run3:held; run5:held |
| run3 | live->live | `ADDON_RESTRICTION_STATE_CHANGED|arg1=0` | `PLAYER_IN_COMBAT_CHANGED` | 1 | False | 0.001744 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->live | `PLAYER_LEAVE_COMBAT` | `ADDON_RESTRICTION_STATE_CHANGED|arg1=0` | 1 | False | 0.001177 | 1.0 | 0.042 | run3:failed; run5:failed |
| run3 | live->truth | `ADDON_RESTRICTION_STATE_CHANGED|arg1=1` | `SPELL_AURA_APPLIED|player>player|spell=71` | 1 | False | 0.001744 | 1.0 | -0.021 | run4:failed; run5:failed |
| run3 | live->live | `PLAYER_REGEN_DISABLED` | `ADDON_RESTRICTION_STATE_CHANGED|arg1=1` | 1 | False | 0.000872 | 1.0 | 0.0 | run4:held; run5:held |
| run4 | live->truth | `ADDON_RESTRICTION_STATE_CHANGED|arg1=1` | `SPELL_CAST_START|npc>none` | 1 | False | 0.009415 | 1.0 | 0.005 | run3:failed; run5:failed |
| run4 | live->live | `PLAYER_REGEN_DISABLED` | `ADDON_RESTRICTION_STATE_CHANGED|arg1=1` | 1 | False | 0.001177 | 1.0 | 0.0 | run3:held; run5:held |
| run3 | live->truth | `ADDON_RESTRICTION_STATE_CHANGED|arg1=1` | `SWING_DAMAGE|me>npc` | 2 | False | 0.001744 | 1.0 | -0.021 | run4:failed; run5:failed |
| run4 | live->truth | `ADDON_RESTRICTION_STATE_CHANGED|arg1=1` | `SPELL_CAST_START|npc>none|spell=7951` | 2 | False | 0.009415 | 1.0 | 0.005 | run3:failed; run5:failed |
| run3 | live->truth | `ADDON_RESTRICTION_STATE_CHANGED|arg1=1` | `SWING_DAMAGE_LANDED|me>npc` | 3 | False | 0.001744 | 1.0 | -0.021 | run4:failed; run5:failed |

### Durations (shared clear id chains)

| capture | from | to | npc | n | median s | min | max | consistent |
|---|---|---|---|---|---|---|---|---|
| run3 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_DELAYED | player | 2 | 0.221 | 0.221 | 0.221 | True |
| run3 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | player | 2 | 1.718 | 1.718 | 1.718 | True |
| run3 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | player | 2 | 1.718 | 1.718 | 1.718 | True |
| run3 | UNIT_SPELLCAST_DELAYED | UNIT_SPELLCAST_SUCCEEDED | player | 2 | 1.497 | 1.497 | 1.497 | True |
| run3 | UNIT_SPELLCAST_DELAYED | UNIT_SPELLCAST_STOP | player | 2 | 1.497 | 1.497 | 1.497 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | None | 16 | 2.477 | 2.434 | 2.515 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | None | 16 | 2.477 | 2.434 | 2.515 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | 4007 | 8 | 2.477 | 2.434 | 2.515 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | 4007 | 8 | 2.477 | 2.434 | 2.515 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | player | 4 | 1.510 | 1.499 | 1.521 | True |
| run4 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | player | 4 | 1.510 | 1.499 | 1.521 | True |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | 4119 | 3 | 3.500 | 3.437 | 3.542 | True |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | player | 8 | 1.459 | 1.417 | 1.583 | False |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | player | 8 | 1.459 | 1.417 | 1.583 | False |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | None | 8 | 2.458 | 1.417 | 3.563 | False |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_SUCCEEDED | None | 6 | 3.469 | 1.417 | 3.563 | False |
| run5 | UNIT_SPELLCAST_START | UNIT_SPELLCAST_STOP | 4119 | 4 | 3.469 | 1.458 | 3.542 | False |

## Higher-order leads (v2.2.5)

Chains A->B->C (depth <= 4), sequences/timing, identity joins (multi-token same-frame), and elimination (my casts + meter totals subtracted from what is seen). Each row is plain-words reasoning plus a **proposed** live HSM rule (review only -- not auto-enabled). Holdout = re-score on the other captures; provisional = one fight.

| # | capture | pattern | depth | hops | support | prec | lift | flags | holdout |
|---|---|---|---|---|---|---|---|---|---|
| 1 | run3 | chain | 2 | `UNIT_COMBAT|player|arg3=6` -> `UNIT_HEAL_PREDICTION|player` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 23/29 | 0.793 | 9999 | provisional,chain | run4:held; run5:absent |
| 2 | run3 | chain | 2 | `UNIT_COMBAT|targettarget|arg1=HEAL` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/22 | 0.909 | 9999 | provisional,chain | run4:held; run5:held |
| 3 | run3 | chain | 3 | `UNIT_COMBAT|targettarget|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/22 | 0.909 | 9999 | provisional,chain | run4:held; run5:held |
| 4 | run3 | chain | 3 | `UNIT_COMBAT|targettarget|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/22 | 0.909 | 9999 | provisional,chain | run4:held; run5:held |
| 5 | run3 | chain | 3 | `UNIT_COMBAT|targettarget|arg1=HEAL` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/22 | 0.909 | 9999 | provisional,chain | run4:held; run5:held |
| 6 | run3 | chain | 4 | `UNIT_COMBAT|targettarget|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/22 | 0.909 | 9999 | provisional,chain | run4:held; run5:held |
| 7 | run3 | chain | 4 | `UNIT_COMBAT|targettarget|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/22 | 0.909 | 9999 | provisional,chain | run4:held; run5:held |
| 8 | run3 | chain | 2 | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/28 | 0.714 | 9999 | provisional,chain | run4:held; run5:held |
| 9 | run3 | chain | 2 | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/28 | 0.714 | 9999 | provisional,chain | run4:held; run5:held |
| 10 | run3 | chain | 3 | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/28 | 0.714 | 9999 | provisional,chain | run4:held; run5:held |
| 11 | run3 | chain | 3 | `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/28 | 0.714 | 9999 | provisional,chain | run4:held; run5:held |
| 12 | run3 | chain | 2 | `UNIT_COMBAT|player|arg1=HEAL` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/31 | 0.645 | 9999 | provisional,chain | run4:held; run5:held |
| 13 | run3 | chain | 3 | `UNIT_COMBAT|player|arg1=HEAL` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/31 | 0.645 | 9999 | provisional,chain | run4:held; run5:held |
| 14 | run3 | chain | 3 | `UNIT_COMBAT|player|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/31 | 0.645 | 9999 | provisional,chain | run4:held; run5:held |
| 15 | run3 | chain | 3 | `UNIT_COMBAT|player|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/31 | 0.645 | 9999 | provisional,chain | run4:held; run5:held |
| 16 | run3 | chain | 3 | `UNIT_COMBAT|player|arg1=HEAL` -> `UNIT_HEALTH|targettarget` -> `UNIT_COMBAT|targettarget|arg1=HEAL` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/31 | 0.645 | 9999 | provisional,chain | run4:held; run5:held |
| 17 | run3 | chain | 4 | `UNIT_COMBAT|player|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=2` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/31 | 0.645 | 9999 | provisional,chain | run4:held; run5:held |
| 18 | run3 | chain | 4 | `UNIT_COMBAT|player|arg1=HEAL` -> `DAMAGE_METER_COMBAT_SESSION_UPDATED|arg0=3` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/31 | 0.645 | 9999 | provisional,chain | run4:held; run5:held |
| 19 | run3 | chain | 2 | `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 20/32 | 0.625 | 9999 | provisional,chain | run4:held; run5:held |
| 20 | run3 | chain | 2 | `UNIT_COMBAT|targettarget|arg3=6` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 19/20 | 0.95 | 9999 | provisional,chain | run4:held; run5:absent |
| 21 | run3 | chain | 2 | `UNIT_COMBAT|targettarget|arg3=6` -> `UNIT_HEAL_PREDICTION|player` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 19/20 | 0.95 | 9999 | provisional,chain | run4:held; run5:absent |
| 22 | run3 | chain | 3 | `UNIT_COMBAT|targettarget|arg3=6` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 19/20 | 0.95 | 9999 | provisional,chain | run4:held; run5:absent |
| 23 | run3 | chain | 2 | `UNIT_COMBAT|player|arg3=6` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 19/29 | 0.655 | 9999 | provisional,chain | run4:held; run5:absent |
| 24 | run3 | chain | 3 | `UNIT_COMBAT|player|arg3=6` -> `UNIT_HEAL_PREDICTION|player` -> `UNIT_HEAL_PREDICTION|targettarget` -> `SPELL_PERIODIC_HEAL|mine>mine|spell=6371` | 19/29 | 0.655 | 9999 | provisional,chain | run4:held; run5:absent |
| 25 | run3 | sequence | 1 | `SPELL_UPDATE_COOLDOWN|arg0=370` -> `UNIT_SPELLCAST_SUCCEEDED|player|arg2=370` | 6/6 | 1.0 | 9999 | provisional,sequence | run4:held; run5:held |
| 26 | run3 | sequence | 1 | `SPELL_UPDATE_COOLDOWN|arg0=370` -> `UNIT_SPELLCAST_SUCCEEDED|targettarget|arg2=370` | 6/6 | 1.0 | 9999 | provisional,sequence | run4:held; run5:held |
| 27 | run3 | sequence | 1 | `SPELL_UPDATE_COOLDOWN|arg0=370` -> `UNIT_SPELLCAST_SENT|player|arg1=Savannah Huntress` | 6/6 | 1.0 | 9999 | provisional,sequence | run4:absent; run5:absent |
| 28 | run3 | sequence | 1 | `SPELL_UPDATE_COOLDOWN|arg0=370` -> `UNIT_SPELLCAST_SENT|targettarget|arg1=Savannah Huntress` | 6/6 | 1.0 | 9999 | provisional,sequence | run4:absent; run5:absent |
| 29 | run3 | chain | 2 | `SPELL_UPDATE_COOLDOWN|arg0=370` -> `UNIT_SPELLCAST_SUCCEEDED|player|arg2=370` -> `SPELL_CAST_SUCCESS|me>npc|spell=370` | 6/6 | 1.0 | 9999 | provisional,chain | run4:held; run5:held |
| 30 | run3 | chain | 2 | `SPELL_UPDATE_COOLDOWN|arg0=370` -> `UNIT_SPELLCAST_SUCCEEDED|targettarget|arg2=370` -> `SPELL_CAST_SUCCESS|me>npc|spell=370` | 6/6 | 1.0 | 9999 | provisional,chain | run4:held; run5:held |

### Reasoning and proposed rules

**1. [run3 / chain]** UNIT_COMBAT / player / arg3=6 links via UNIT_HEAL_PREDICTION / player to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.793, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg3=6, look for UNIT_HEAL_PREDICTION / player within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**2. [run3 / chain]** UNIT_COMBAT / targettarget / arg1=HEAL links via UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.909, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / targettarget / arg1=HEAL, look for UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**3. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**4. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**5. [run3 / chain]** UNIT_COMBAT / targettarget / arg1=HEAL links via UNIT_HEAL_PREDICTION / player -> UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.909, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / targettarget / arg1=HEAL, look for UNIT_HEAL_PREDICTION / player / UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**6. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**7. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**8. [run3 / chain]** DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2 links via UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.714, lift 9999 vs shuffled-time null)

> proposed: Chain: on DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2, look for UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**9. [run3 / chain]** DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=3 links via UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.714, lift 9999 vs shuffled-time null)

> proposed: Chain: on DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=3, look for UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**10. [run3 / chain]** DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2 links via UNIT_HEAL_PREDICTION / player -> UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.714, lift 9999 vs shuffled-time null)

> proposed: Chain: on DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=2, look for UNIT_HEAL_PREDICTION / player / UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**11. [run3 / chain]** DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=3 links via UNIT_HEAL_PREDICTION / player -> UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.714, lift 9999 vs shuffled-time null)

> proposed: Chain: on DAMAGE_METER_COMBAT_SESSION_UPDATED / arg0=3, look for UNIT_HEAL_PREDICTION / player / UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**12. [run3 / chain]** UNIT_COMBAT / player / arg1=HEAL links via UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.645, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg1=HEAL, look for UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**13. [run3 / chain]** UNIT_COMBAT / player / arg1=HEAL links via UNIT_HEAL_PREDICTION / player -> UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.645, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg1=HEAL, look for UNIT_HEAL_PREDICTION / player / UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**14. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**15. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**16. [run3 / chain]** UNIT_COMBAT / player / arg1=HEAL links via UNIT_HEALTH / targettarget -> UNIT_COMBAT / targettarget / arg1=HEAL to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.645, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg1=HEAL, look for UNIT_HEALTH / targettarget / UNIT_COMBAT / targettarget / arg1=HEAL within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**17. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**18. [run3 / chain]** DamageMeter update fires in the same frame as my UNIT_COMBAT hits; hits without a meter tick (and without my cast) are someone else's -- subtract to recover others-on-target

> proposed: MeterFrameJoin: DAMAGE_METER_COMBAT_SESSION_UPDATED in-frame with UNIT_COMBAT|target marks the hit as mine-or-group; absence + no own cast -> other (elimination).

**19. [run3 / chain]** UNIT_HEAL_PREDICTION / player links via UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.625, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_HEAL_PREDICTION / player, look for UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**20. [run3 / chain]** UNIT_COMBAT / targettarget / arg3=6 links via UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.95, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / targettarget / arg3=6, look for UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**21. [run3 / chain]** UNIT_COMBAT / targettarget / arg3=6 links via UNIT_HEAL_PREDICTION / player to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.95, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / targettarget / arg3=6, look for UNIT_HEAL_PREDICTION / player within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**22. [run3 / chain]** UNIT_COMBAT / targettarget / arg3=6 links via UNIT_HEAL_PREDICTION / player -> UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.95, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / targettarget / arg3=6, look for UNIT_HEAL_PREDICTION / player / UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**23. [run3 / chain]** UNIT_COMBAT / player / arg3=6 links via UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.655, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg3=6, look for UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**24. [run3 / chain]** UNIT_COMBAT / player / arg3=6 links via UNIT_HEAL_PREDICTION / player -> UNIT_HEAL_PREDICTION / targettarget to ground truth SPELL_PERIODIC_HEAL / mine>mine / spell=6371 (end-to-end precision 0.655, lift 9999 vs shuffled-time null)

> proposed: Chain: on UNIT_COMBAT / player / arg3=6, look for UNIT_HEAL_PREDICTION / player / UNIT_HEAL_PREDICTION / targettarget within the hop windows, then treat SPELL_PERIODIC_HEAL / mine>mine / spell=6371 as the meaning (proposed only -- enable after holdout review).

**25. [run3 / sequence]** ordered timing: SPELL_UPDATE_COOLDOWN / arg0=370 then UNIT_SPELLCAST_SUCCEEDED / player / arg2=370 within 300 ms (learned lag median 0.078 s)

> proposed: Sequence: watch SPELL_UPDATE_COOLDOWN / arg0=370; expect UNIT_SPELLCAST_SUCCEEDED / player / arg2=370 within 300 ms (or treat absence as the opposite signal).

**26. [run3 / sequence]** ordered timing: SPELL_UPDATE_COOLDOWN / arg0=370 then UNIT_SPELLCAST_SUCCEEDED / targettarget / arg2=370 within 300 ms (learned lag median 0.078 s)

> proposed: Sequence: watch SPELL_UPDATE_COOLDOWN / arg0=370; expect UNIT_SPELLCAST_SUCCEEDED / targettarget / arg2=370 within 300 ms (or treat absence as the opposite signal).

**27. [run3 / sequence]** ordered timing: SPELL_UPDATE_COOLDOWN / arg0=370 then UNIT_SPELLCAST_SENT / player / arg1=Savannah Huntress within 300 ms (learned lag median 0.078 s)

> proposed: Sequence: watch SPELL_UPDATE_COOLDOWN / arg0=370; expect UNIT_SPELLCAST_SENT / player / arg1=Savannah Huntress within 300 ms (or treat absence as the opposite signal).

**28. [run3 / sequence]** ordered timing: SPELL_UPDATE_COOLDOWN / arg0=370 then UNIT_SPELLCAST_SENT / targettarget / arg1=Savannah Huntress within 300 ms (learned lag median 0.078 s)

> proposed: Sequence: watch SPELL_UPDATE_COOLDOWN / arg0=370; expect UNIT_SPELLCAST_SENT / targettarget / arg1=Savannah Huntress within 300 ms (or treat absence as the opposite signal).

**29. [run3 / chain]** SPELL_UPDATE_COOLDOWN / arg0=370 links via UNIT_SPELLCAST_SUCCEEDED / player / arg2=370 to ground truth SPELL_CAST_SUCCESS / me>npc / spell=370 (end-to-end precision 1.0, lift 9999 vs shuffled-time null)

> proposed: Chain: on SPELL_UPDATE_COOLDOWN / arg0=370, look for UNIT_SPELLCAST_SUCCEEDED / player / arg2=370 within the hop windows, then treat SPELL_CAST_SUCCESS / me>npc / spell=370 as the meaning (proposed only -- enable after holdout review).

**30. [run3 / chain]** SPELL_UPDATE_COOLDOWN / arg0=370 links via UNIT_SPELLCAST_SUCCEEDED / targettarget / arg2=370 to ground truth SPELL_CAST_SUCCESS / me>npc / spell=370 (end-to-end precision 1.0, lift 9999 vs shuffled-time null)

> proposed: Chain: on SPELL_UPDATE_COOLDOWN / arg0=370, look for UNIT_SPELLCAST_SUCCEEDED / targettarget / arg2=370 within the hop windows, then treat SPELL_CAST_SUCCESS / me>npc / spell=370 as the meaning (proposed only -- enable after holdout review).


_Elapsed: mine 44.447s, higher-order 3.773s, total 48.273s (profile full)._

