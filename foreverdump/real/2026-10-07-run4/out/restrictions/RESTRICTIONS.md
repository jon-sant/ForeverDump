# Addon restrictions (ADDON_RESTRICTION_STATE_CHANGED)

Source: v2.2. 4 flip(s).

States: 0 Inactive, 1 Activating (dispatch in progress; NOT enforced until the event dispatch completes), 2 Active.
Types: 0 Combat, 1 Encounter, 2 ChallengeMode, 3 PvPMatch, 4 Map, 5 Chat.

| type | flips | states | active intervals (s) | InCombatLockdown at Activating |
|---|---|---|---|---|
| Combat | 4 | Activating 2, Inactive 2 | n=2 total=92.2 min=29.023 max=63.168 | InCombatLockdown=False: 2 |

Context markers: PLAYER_IN_COMBAT_CHANGED 4, PLAYER_REGEN_DISABLED 2, PLAYER_REGEN_ENABLED 2

## What changes at a flip (probe at the event vs next frame)

- 1x Combat C_UnitAuras.GetAuraDataByIndex(player,1) #1: nil -> -
- 1x Combat C_UnitAuras.GetAuraDataByIndex(player,1) #call: - -> error
- 1x Combat C_UnitAuras.GetAuraDataByIndex(target,1) #1: nil -> -
- 1x Combat C_UnitAuras.GetAuraDataByIndex(target,1) #call: - -> error
- 1x Combat C_Secrets.ShouldAurasBeSecret #ret: False -> True
- 1x Combat C_Secrets.ShouldCooldownsBeSecret #ret: False -> True

## Flips

- 22:57:59 Combat -> Activating in none/Kalimdor
- 22:58:28 Combat -> Inactive in none/Kalimdor
- 22:58:53 Combat -> Activating in none/Kalimdor
- 22:59:56 Combat -> Inactive in none/Kalimdor
