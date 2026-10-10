# Addon restrictions (ADDON_RESTRICTION_STATE_CHANGED)

Source: v2.2. 12 flip(s).

States: 0 Inactive, 1 Activating (dispatch in progress; NOT enforced until the event dispatch completes), 2 Active.
Types: 0 Combat, 1 Encounter, 2 ChallengeMode, 3 PvPMatch, 4 Map, 5 Chat.

| type | flips | states | active intervals (s) | InCombatLockdown at Activating |
|---|---|---|---|---|
| Combat | 12 | Activating 6, Inactive 6 | n=6 total=302.2 min=1.606 max=126.003 | InCombatLockdown=False: 6 |

Context markers: PLAYER_ENTERING_WORLD 1, PLAYER_IN_COMBAT_CHANGED 12, PLAYER_REGEN_DISABLED 6, PLAYER_REGEN_ENABLED 6

## What changes at a flip (probe at the event vs next frame)

- 6x Combat C_UnitAuras.GetAuraDataByIndex(player,1) #1: nil -> -
- 6x Combat C_UnitAuras.GetAuraDataByIndex(player,1) #call: - -> error
- 6x Combat C_UnitAuras.GetAuraDataByIndex(target,1) #1: nil -> -
- 6x Combat C_UnitAuras.GetAuraDataByIndex(target,1) #call: - -> error
- 6x Combat C_Secrets.ShouldAurasBeSecret #ret: False -> True
- 6x Combat C_Secrets.ShouldCooldownsBeSecret #ret: False -> True
- 2x Combat UnitThreatSituation #1: nil -> clear

## Flips

- 21:57:15 Combat -> Activating in none/Kalimdor
- 21:57:50 Combat -> Inactive in none/Kalimdor
- 21:58:10 Combat -> Activating in none/Kalimdor
- 21:58:16 Combat -> Inactive in none/Kalimdor
- 21:58:22 Combat -> Activating in none/Kalimdor
- 22:00:28 Combat -> Inactive in none/Kalimdor
- 22:01:13 Combat -> Activating in none/Kalimdor
- 22:01:15 Combat -> Inactive in none/Kalimdor
- 22:01:17 Combat -> Activating in none/Kalimdor
- 22:02:01 Combat -> Inactive in none/Kalimdor
- 22:02:31 Combat -> Activating in none/Kalimdor
- 22:04:01 Combat -> Inactive in none/Kalimdor
