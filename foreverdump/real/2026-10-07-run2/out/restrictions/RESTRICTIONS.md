# Addon restrictions (ADDON_RESTRICTION_STATE_CHANGED)

Source: v2.1 (blocked log: type/state/stamp only, no context or probes). 18 flip(s).

States: 0 Inactive, 1 Activating (dispatch in progress; NOT enforced until the event dispatch completes), 2 Active.
Types: 0 Combat, 1 Encounter, 2 ChallengeMode, 3 PvPMatch, 4 Map, 5 Chat.

| type | flips | states | active intervals (s) | InCombatLockdown at Activating |
|---|---|---|---|---|
| Combat | 18 | Activating 9, Inactive 9 | n=9 total=105.1 min=0.917 max=79.946 | InCombatLockdown=False: 9 |

No flip probes in this data (v2.1 logged flips only). v2.2 re-runs a small probe set at each flip and on the next frame while FD_Logs is ON.

## Flips

- 19:55:35 Combat -> Activating
- 19:56:55 Combat -> Inactive
- 19:57:06 Combat -> Activating
- 19:57:09 Combat -> Inactive
- 19:57:19 Combat -> Activating
- 19:57:19 Combat -> Inactive
- 19:57:54 Combat -> Activating
- 19:57:57 Combat -> Inactive
- 19:58:00 Combat -> Activating
- 19:58:01 Combat -> Inactive
- 19:58:03 Combat -> Activating
- 19:58:06 Combat -> Inactive
- 19:58:10 Combat -> Activating
- 19:58:11 Combat -> Inactive
- 19:58:13 Combat -> Activating
- 19:58:18 Combat -> Inactive
- 19:58:21 Combat -> Activating
- 19:58:26 Combat -> Inactive
