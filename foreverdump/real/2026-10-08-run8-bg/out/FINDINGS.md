# Run 8 (battleground, v2.2.7, diag): FINDINGS

Capture `cap-20261008194049-33`, 19:40:49 to 20:02:33 ET (1304 s, one random battleground, capture level diag).
It ended with an FD_Logs OFF click, which reloaded and saved. The SV has no second ON/OFF pair. The tools now skip a short
trailing ON/OFF (< 30 s, no combat) and report it as info, so an accidental toggle at the end can't replace the real capture.
Other players are redacted throughout: no names and no GUIDs, only aggregates and IdKeys.

## Health verdict: ForeverDump healthy. Two FD bugs fixed in v2.2.9

- **No Lua error came from ForeverDump.** lastSession ownErrors = 0. The OFF health line said `ownErrors=3354, ok=false`
  because of an FD misattribution (**B1**, below), not because FD errors happened.
- **The error handler doesn't amplify errors.**
  - Chain mode, no BugGrabber: the handler runs `pcall(capture)` once, then calls the previous handler once.
  - It doesn't re-raise, retry or replay.
  - Its pcall'd capture reads no secrets, so it adds no taint.
  - The 0 FD lines in taint.log come from Errors.lua.
- **The popup burst was not caused by the FD_Logs click.**
  - The last third-party errors were at 20:02:22–24 ET, when PVP_MATCH_COMPLETE fired and the restriction lifted
    (types 3/5 → 0, 20:02:23). That was about 10 s before the OFF click (20:02:33).
  - OFF only prints counts. Then it sets taintLog 1 → 0, runs /chatlog and /reload.
  - The burst amplifier is Blizzard's error popup itself. Every ScriptErrorsFrame update ran tainted by QuestLevelPatch
    (3588 taint lines), so the popup's edit box (InputBoxTemplates ScrollingEdit_OnUpdate) touched secrets. That produced
    more "attempt to compare" errors (6+4 ×, 19:47:41–19:48:43).
  - It coincided with the click because the user clicked at the end of the match, when the scoreboard and tracker
    re-layout fire.
- **Error sources:** all third-party or Blizzard, all logged out of combat during the capture.

  | source | count | window (ET) |
  |---|---|---|
  | TweaksForever Tooltips.lua:201 | 2661 | 19:42:38–20:02:12 |
  | TweaksForever Tooltips.lua:313 | 526 | 19:42:38–20:02:12 |
  | ObjectiveTracker LayoutContents nil call | 115 | 19:41:07–20:02:24 |
  | Questie | 42 | 19:40:19–20:02:22 |
  | ScriptErrorsFrame compare (popup tainted) | 10 | 19:47:41–19:48:43 |

- **uiIntegrity: FD didn't touch the tracker.**
  - The signature `BonusW QuestW WorldQuestW Achievement= Scenario= CampaignQuestW` is identical at login, before and
    after ON, at OFF, and in every error's uiSig.
  - The tracker nil-call comes from Blizzard's tracker running in a tainted path (QuestLevelPatch/Questie).
- **Engine alive.**
  - HSM decide records 9477; 8 dm-reconcile inferences.
  - 13 fights exported (from 19:58:57; earlier ones rolled off).
  - The world-capture slices ran; guard skips show as `G` codes.
  - v2.2.7 doesn't persist hdr.stats or guard counters, so there are no totals. v2.2.8+ does.
- **Blocked actions:**
  - 0 ADDON_ACTION_BLOCKED.
  - 83 "blocked/warning" rows: 81 ADDON_RESTRICTION_STATE_CHANGED (combat in/out) and 2 LUA_WARNING.
- **Taint (7954 lines):** TweaksForever 3793, QuestLevelPatch 3588, Questie 24. FD lines:
  - 100 expected deliberate pcall probes (Controls TryTimeLeft 58, Controls 154–156, Lab 241–246);
  - 8 contained;
  - 53 benign chat-fading reads of our own chat lines. 2 of them (`messageInfo`) were misfiled "blizzard-frame" (tool
    fix + test). The ANALYSIS.md for this run predates that fix and still shows them.
- **Clean baseline from now on:** the user has disabled every addon except ForeverDump. The third-party errors and taint
  above shouldn't appear in run 9; if any error or taint remains, it is FD's or Blizzard's.

## FD bugs (fixed in v2.2.9, each with a permanent regression check)

- **B1: every stored error stack began with ForeverDump frames.**
  - Cause: `debugstack` inside the handler adds the Errors.lua lines, `[C] pcall` and the `[C]: ?` dispatch frame.
  - Effect: `/fdump errors show` showed FD in every stack, and Health counted all BG errors as own. It also classified
    the tracker nil-call as `nilCallInCFunction {pcall}`.
  - Fix:
    - `Errors.StripOwn` cuts exactly that prefix and is idempotent.
    - `Errors.IsOwn`: an FD file in the message, or an FD frame below the prefix.
    - Used in capture, Health, the OFF summary and self-protection.
  - Check: `tests/run8_regress.lua stack` 12/0. The v2.2.8 control fails with 145 "own".
- **B2: the FD_Logs ON click switched the combat log OFF, so there is no battleground combat log.**
  - Cause: `/combatlog` and `/chatlog` are toggles.
    - The macro body was written at login (~19:38:04) while the combat log was off.
    - The user then typed `/combatlog` by hand (19:38:35).
    - The ON click's `/combatlog` line toggled it back off.
  - Effect: WoWCombatLog.txt ends at 19:40:49, the ON click. In the SV: `client.combat=false`, `mismatch=true`.
  - Fix:
    - The client's log on/off system message refreshes the macro.
    - A click that would still flip a log the wrong way prints a red warning naming the one command to type.
    - The verify line names the cause.
  - Check: `tests/run8_regress.lua macro` 9/0. The v2.2.8 control switches the log off.

## Analysis-tool bugs found on this run (fixed and tested in tests/test_v229_run8.py)

1. correlate crashed on mixed int/string payload keys.
2. dm-reconcile had two faults:
   - it repeated the last live fight (1540/1252) for every BG fight;
   - it printed `log=0` where no log file existed. It now joins by time and prints `log=None` for uncovered fights.
3. PvP damage to hostile players wasn't counted as mine.
4. Engine leads from earlier captures ranked high. They are now info.
5. A trailing short capture could hide the main capture. It is now skipped and reported.
6. Taint chat-fading `messageInfo` was misfiled as blizzard-frame. It is now benign-chat.

## End-of-capture toggle and the FD_Logs macro

- **OFF reloads.** It's verified in Logs.lua MacroBody: OFF appends `/reload` when `logs.autoReload`, which is on by
  default. The reload writes the SV.
- **New ADDON-USAGE.md procedure:**
  1. `/fdump errors show` + screenshot BEFORE clicking OFF;
  2. click FD_Logs OFF (it reloads and saves; no separate /reload);
  3. send the files.

  The ON message prints the same reminder.
- **Is it a clear toggle?** Mostly. The click prints `ON`/`OFF`, and the HSM title shows `log:diag (capture)`.
  - The weak spot is the client log toggles inside the macro (B2). v2.2.9 now refreshes the macro on hand toggles and
    warns before a wrong flip.
  - Proposal (not built): swap the macro icon (green/red) whenever its body is rewritten, so the bar shows the state
    before the click.

## Size

- SV 36.12 MB. Breakdown:

  | store | MB |
  |---|---|
  | LogDB | 14.90 (replay 10.13, inference 1.83, restrictions 0.67, damageMeter 0.62) |
  | CombatLogDB | 13.37 |
  | RecordDB | 5.59 |
  | DB | 2.26 |

- This capture: combat 13.16 + record 5.34 + replay 9.59 = **28.1 MB in 21.7 min ≈ 1.29 MB/min.** It hit the diag ring
  caps:
  - the tape filled after about 10.5 min (78,778 priority drops), so ws/sec/dm samples stop at about 19:51;
  - the record ring overwrote 40,618 rows (kept from 19:51:13);
  - combat holds 95,275 of 100,000.
- DAMAGE_METER_COMBAT_SESSION_UPDATED alone is 56,032 events (59% of the combat ring).
- The diag serialize bench (24.67 MB) underestimates real BG fill (about 28 MB). The 26 MB gate stays and is now also
  applied to diag.

## Battleground world state

**World capture (v2.2.7 ws, 6269 samples; only the first ~10.5 min, then the tape was full).**
- `exists`, `health` and `healthMax` are lost (`L`) in all samples. That's the v2.2.7 p-packing bug, fixed in v2.2.8.
- For other players' tokens (raidN, partyN, arenaN, nameplateN, target chains):
  - `power` and `inRange` are secret when present;
  - `range28` is clear out of combat and guard-skipped (`G`) in combat;
  - `dead` is clear;
  - `threat` and `casting` are nil;
  - buff/debuff counts error (`E`) under restriction.
- bossN, pet, npc, vehicle and softinteract are always `E` or empty in a BG.
- IdKeys: 142 player, 15 guid, 0 npc. The v2.2.7 npc IdKey bug doesn't affect this run.

**Token matrix (pvp/raid, restricted and in combat).**
- Health, healthMax and power are **secret** for every unit.
- guid is clear for direct tokens (partyN, focus, arenaN) and secret on `...target` chains.
- name, level, reaction, canAttack, isPlayer, dead and combat are clear.

**Live events by token family (combat recorder, 95,275 events).**

| event | secret args |
|---|---|
| UNIT_COMBAT / UNIT_HEALTH / UNIT_AURA / UNIT_ABSORB_AMOUNT_CHANGED | 0% for every family (group, nameplate, arena, target chain, soft targets, pets) |
| others' UNIT_SPELLCAST_START / STOP / CHANNEL_START | 96–100% (spell args 2/3) |
| others' UNIT_SPELLCAST_SUCCEEDED | 65–100% |
| others' UNIT_SPELLCAST_INTERRUPTED | 90–100% |
| my own casts | 0% |
| UNIT_DIED (185) | 124 with a secret GUID (100% secret arg), 61 with a clear player GUID; PLAYER_DEAD 5 |

- Event delivery (who, when, an amount for UNIT_COMBAT) is readable live.
- What a unit's health is, and which spell another player cast, is not.

**Live vs log.** Not possible this run: there is no BG combat log (B2). The join reports these as unexplained, not as
mismatches. Run 9 should have a combat log.

**DM reconcile (live vs C_DamageMeter, fights 29–38 in the BG).**
- 26 cells match, 24 are off, 140 are unexplained (the fights before the BG have no live or meter data).
- Interrupts match 34/34. Dispels match 20/34.
- Damage and taken are off by large amounts both ways. Healing is live 0 vs meter 25–1154.
- Adjacent fights share live (5255) or meter (2124, 1945) values. Fight-boundary pairing between HSM fights and meter
  sessions still looks off-by-one in BG churn.
- **Open item:** the dm-join in BGs isn't trustworthy yet. This is analysis quality, not an FD runtime fault. Re-check
  against run 9's combat log before changing live rules.

**Correlation pass (1st/2nd order, all provisional).**
- `PLAYER_REGEN_DISABLED` → `ADDON_RESTRICTION_STATE_CHANGED` (state on) at 59/59. Leaving combat: restriction off →
  `PLAYER_REGEN_ENABLED` 59/61.
- `UNIT_DIED` → DM session update (type 9 = deaths) at 0.58 precision, lift 57. Deaths are inferable live through the
  meter even when the GUID is secret.
- DM type 8 update → `UNIT_COMBAT player HEAL` → `UNIT_HEAL_PREDICTION player` (2nd order chain). Incoming heals are
  visible.
- `UNIT_ABSORB_AMOUNT_CHANGED raidN` → `UNIT_COMBAT raidN ABSORB` (0.59–0.73).
- `UNIT_SPELLCAST_SUCCEEDED raidN` → `STOP raidN` 305/306: cast ends are trackable even with secret spell IDs.
- HONOR_GAINED → currency 1792 / post-match reward. `BATTLEGROUND_POINTS_UPDATE` → `UPDATE_UI_WIDGET` 338/338.
- VERIFY:
  - interrupts dm 34/34 V;
  - gcd and cd-ready mostly C: drift on 8008/8177/17364 under PvP haste/latency, proposals only;
  - no new rule is auto-enabled.
- **Only in the log, not live** (from earlier runs; not measurable here): others' spell IDs for casts, health values,
  and GUIDs of secret deaths.

## Privacy

- The SV stores 16 distinct raw player GUIDs of other players (inference signals/unit, DM sourceGUID, event args).
- It stays local and none of it is in any output.
- **Proposal:** hash other players' GUIDs to IdKeys at write time.

## Proposals (not built; for the next version)

1. Coalesce `DAMAGE_METER_COMBAT_SESSION_UPDATED` (latest per session/type per 250 ms). It's 59% of the combat ring.
2. Tape rate shaping, so ws/sec samples span a whole 20–25 min BG instead of the first 10.5 min.
3. IdKey for other players' GUIDs at write time.
4. A macro icon that shows the state.
5. Re-check the BG dm-join boundary pairing with run 9's combat log.
