# Addon restrictions (ADDON_RESTRICTION_STATE_CHANGED)

Source: v2.2. 6 flip(s).

States: 0 Inactive, 1 Activating (dispatch in progress; NOT enforced until the event dispatch completes), 2 Active.
Types: 0 Combat, 1 Encounter, 2 ChallengeMode, 3 PvPMatch, 4 Map, 5 Chat.

| type | flips | states | active intervals (s) | InCombatLockdown at Activating |
|---|---|---|---|---|
| Combat | 6 | Activating 3, Inactive 3 | n=3 total=80.2 min=14.356 max=37.354 | InCombatLockdown=False: 3 |

Context markers: PLAYER_IN_COMBAT_CHANGED 6, PLAYER_REGEN_DISABLED 3, PLAYER_REGEN_ENABLED 3

## What changes at a flip (probe at the event vs next frame)

- 3x Combat C_UnitAuras.GetAuraDataByIndex(player,1) #1: nil -> -
- 3x Combat C_UnitAuras.GetAuraDataByIndex(player,1) #call: - -> error
- 3x Combat C_UnitAuras.GetAuraDataByIndex(target,1) #1: nil -> -
- 3x Combat C_UnitAuras.GetAuraDataByIndex(target,1) #call: - -> error
- 3x Combat C_Secrets.ShouldAurasBeSecret #ret: False -> True
- 3x Combat C_Secrets.ShouldCooldownsBeSecret #ret: False -> True
- 1x Combat UnitThreatSituation #1: nil -> clear

## Flips

- 00:02:03 Combat -> Activating in none/Kalimdor
- 00:02:31 Combat -> Inactive in none/Kalimdor
- 00:02:42 Combat -> Activating in none/Kalimdor
- 00:03:20 Combat -> Inactive in none/Kalimdor
- 00:03:31 Combat -> Activating in none/Kalimdor
- 00:03:45 Combat -> Inactive in none/Kalimdor
