# K.T.H. Forever: port notes and diff list (1.0.0-kth-forever.5)

This is a private port of **K.T.H. (Kill The Healer) 1.0.0-kth** to **WoW Forever 1.60.1** (build 70334, toc 16001,
WOW_PROJECT_ID 18). Credits: K.T.H. by Scone, built on H.H.T.D. by John Wellesz. **All Rights Reserved**: the port is for
private use only. Do not redistribute it.

The code, structure, design and four-condition healer logic are K.T.H.'s own. Every change is tagged `[Forever]` in
the source. The full patch against the untouched original is in `FOREVER-PORT.diff` (`original/KTH` holds the original).
Evidence comes from the user's baseline battleground run (original K.T.H. with only the TOC changed, plus the
KTH_ForeverDiag probe) on 2026-10-09 between 23:51 and 00:13 ET. It is backed by the ForeverDump captures of runs
10 to 16.

## What the baseline diag measured (per-value reads, C = clear, S = secret, N = nil; counts per phase)
See `docs/diag-tables.md` for the full per-field × per-phase tables. Summary:
- **Branch**: `MN=false`, `WOWC=true`, project 18, toc 16001, `canaccessvalue` present, `CombatLogGetCurrentEventInfo`
  absent, `C_CombatLogInternal` absent. K.T.H. printed nothing (kthPrints = 0), and 0 Lua errors were logged.
- **Blocked action**: one `ADDON_ACTION_FORBIDDEN`, `AceEvent30Frame:RegisterEvent()`, at 23:51:53 ET. That was the
  second K.T.H. load (a login or reload inside the BG). The cause is `Core.lua:1035`
  `self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` on the non-MN branch. It is the only event K.T.H. registers on
  that branch that Forever restricts. ForeverDump's EVENT_DENYLIST documents the same popup for CLEU. The Forever mock
  reproduces it: baseline gives 1 restricted registration (CLEU), the port gives 0. The diag's blocked list is reset on
  each load, so the first load at 23:51:29 probably raised the same block.
- **C_PvP.GetScoreInfo**: the table itself is clear in every phase (prep 150/150, ooc 2849, combat 1050, post 60).
  `name` ("First Surname"), `classToken`, `className` and `faction` are clear in every phase. `talentSpec`,
  `roleAssigned`, `guid`, `healingDone`, `damageDone`, `killingBlows`, `deaths`, `honor*` and `rating` are secret in
  prep, ooc and combat, and clear post-match. `race` and `bgRating` are nil.
- **GetBattlefieldScore** layout from raw rows: 1 name, 6 faction (0/1), 7 race, 8 localized class, 9 classToken.
  These are clear in every phase. 2-5, 10-13 and 15-17 are secret in-match and clear post-match. 14 is nil.
  The layout is retail-like.
- **Enemy nameplates** (750 reads, ooc + combat): UnitName clear and **first-name-only** (13 names, none with a space
  or realm). UnitClass is secret (all 3 returns, 750/750). UnitGUID and UnitHealthMax are secret. UnitPowerType,
  UnitCanAttack and UnitIsFriend are clear. **No friendly nameplates** were seen.
- **spellIDs** (UNIT_SPELLCAST_SUCCEEDED): nameplate 20/20 secret, arena 12/12, party 194/194, target 7/7. raid is
  secret except when the raid token is the player. The player's own spellIDs are clear.

## Diff list
| # | Change | Status | Evidence |
|---|---|---|---|
| D1 | TOC `## Interface: 16001`, title suffix "Forever", version `1.0.0-kth-forever.5`, 3 new files | measured | the client only loads toc 16001 (baseline loaded) |
| D2 | `HHTD_C.MN = true` on Forever (Midnight path) | measured | diag MN=false, then classic branch, then CLEU RegisterEvent and ADDON_ACTION_FORBIDDEN popup; no CLEU getter on Forever. The MN branch registers no CLEU (C_CombatLogInternal absent, so only UNIT_SPELLCAST_*) |
| D3 | All K.T.H. `Print`/`Printf` (core + modules, incl. SafePrint banner) go to K.T.H.'s own frame `KTH_ForeverMessageFrame` (`/kthlog`); `/hhtd` opens the options window instead of AceConfigCmd chat output | user rule (no Blizzard chat writes) | code path: the MN branch prints the login banner and slash replies through HHTD:Print, which goes to DEFAULT_CHAT_FRAME. Mock: 0 Blizzard chat lines, all output on the own frame |
| D4 | Order `canaccessvalue(x)` before any truth test of scoreboard fields (talentSpec, roleAssigned, faction, guid), the spellcast spellID/guid/name and canAttack | measured secrecy; the change itself is semantics-preserving | diag: these fields are secret in-match and nameplate spellIDs are secret. No behaviour change when values are clear |
| D5 | Class for an enemy plate from the scoreboard roster (first name + side, duplicate first names never joined); `MN_HealersByName` keyed by the first word when unique | measured | enemy UnitClass S 750/750; plate names first-name-only; GetScoreInfo name/classToken/faction clear in every phase |
| D6 | Scoreboard Method 3: healingDone ≥ damageDone (>0) means healer | measured (post-match only) | healingDone/damageDone clear only post-match (60/60). The WOWC spec→role table is empty and roleAssigned is secret in-match |
| D7 | Heal evidence (cast + same-frame UNIT_COMBAT HEAL on a teammate) confirms a specific player and stands in for the SPELL check; it registers through K.T.H.'s RegisterHealer | measured need, scored | spellIDs secret (nameplate 20/20). Replay: friendly 6/9 healers, 50% precision; enemy 0/8 (enemy casts are almost never delivered: 3 to 9 per BG) |
| D8 | Treat PRIEST/DRUID as ambiguous (DPS also on mana) | measured, **superseded by D9 (forever.5)** | DPS priests and caster DPS druids are MANA-only in runs 10-16. But applying it drops enemy plate recall from 6/7 to 0/7. K.T.H.'s original rule is kept |
| D5b | (forever.3) Exact join: the plate's `UnitName` 2nd return ("realm") is the scoreboard surname, so the key is `name.." "..realm` + side; the first-name join with its duplicate guard is only the fallback when no realm is returned. Evidence records are keyed the same way | measured | ForeverDump runs 17+18: name-realm == scoreboard "First Surname" 59/59 (runs 16-18 by the FD executor: 45/45); realm clear (C) on nameplate/mouseover/target/raid hostile-player. Run 16 had two "Johnny" (Snowden/Morningwind) that the first-name join could not use. `bgdiag3/realm_surname_check.txt` |
| D9 | (forever.5, user decision) Healer verdict = healing output, not class + mana. On Forever an enemy (and friendly) plate is marked only when that player's observed output is mostly healing (≥ 60%) or their healing is ≥ 6× the group median; class is only a can-heal prerequisite. CLASS+PWR, CLASS+SCORE and the single-spell SPELL mark are not used on Forever (a clear healer-only spellID is one heal action). Sources: frame-joined heal/damage links (D7) and C_DamageMeter Current-session HealingDone vs DamageDone, read on PLAYER_REGEN_ENABLED. Hysteresis: on at 60%, off only below 35% with ≥ 6 links or ≥ 2000 meter output; a decisive meter vote outranks link counts | user decision + measured + tuned on real runs 16-18 | user: "heal and feral druids both have mana. having mana does not make one a healer ... balance druids have mana too". Meter readability measured in FD runs 16-18 (table below). Replay: plate precision 5/5, 0 DPS druids marked, 0 icon on→off flips (forever.3: 8/10, 2/2 DPS druids marked, 23 flips on non-healers) |
| D10 | (forever.6, user: keep forever.3's recall with forever.5's precision) Enemy classes with several players: class-group meter verdicts. **all**: n heal rows, Σheal ≥ 1000·n, class share ≥ 63%. **none**: n damage rows ≥ 2000 and no heal row could reach 60%. **possible** + own heal link with no damage link → mark while fewer than 3 enemies are claimed. A possible read never clears an all/none vote | measured + backtested on real runs 16-18 | forever.6 section: 9/9 precision, 9/9 recall, 0 flips (forever.3 8/10, 8/9; forever.5 5/5, 5/9) |
| D11 | (forever.7) Spec shortcut (arena opponent spec, HEALER group role, scoreboard talentSpec, healer-only spell cast) marks immediately and is authoritative; healer-only spell list {Swiftmend 18562, Holy Shock 1311605}, positive-only; /kthdebug meter/verdict log; level in the plate log | FD runs 1-18 logs (zero DPS casters), FD readability by phase | forever.7 section: real BG replays unchanged (9/9, 9/9, 0 flips); synthetic R11-R13 |
| D12 | (forever.8, user decision) The healer-only instant-flag list is replaced by the user's list: Penance and Power Infusion (Discipline), Prayer of Mending (Holy priest), Light's Vigil (Holy paladin), Wild Growth (Restoration druid), Riptide (Restoration shaman). 62 IDs. Swiftmend and Holy Shock are removed | FD DB2 = wago.tools 1.60.1.70245; Wowhead Forever; combat logs runs 1-18 | forever.8 section; R11 42/42; real replays unchanged |
| D13 | (forever.9, user) The Midnight nameplate path draws H.H.T.D.'s own healer sprites. NamePlateHooker.lua exports its existing Marker_Textures/ICONS_COORDS (1 line), and MidnightNameplates.ApplyIndicatorStyle uses them: SetTexture(Marker_Textures[default/minimal]) + SetTexCoord(ICONS_COORDS[isFriend][class or false]). New presets hhtd (default) and hhtdmin; raid markers stay selectable; the old default "cross" moves to hhtd once | NamePlateHooker.lua ICONS_COORDS = upstream H.H.T.D. 2.4.27 (identical; sprites byte-identical) | R14; real replays unchanged; 0 fallback marks on runs 16-18 |
| D13b | (forever.9b) KTH_Options.lua's own ICON_PRESETS copy (the /kthg dropdowns: friend, enemy, per-class overrides) gains hhtd and hhtdmin; its fallback defaults are hhtd, the same as MidnightNameplates | user bug report: GUI could not select the HHTD icons | R15: 8/8 selects offer them; selection round-trips into live settings and draws the class cell |
| D14 | (forever.10, run 19 fix) Post-match scoreboard talentSpec on Forever is the CLASS name ("Priest"); `specKindFromName` returns HEALER/DPS only for known spec names, otherwise nil (no unmark). `E.DPS_SPEC_NAME` per class | measured (run 19 post-match: every healer unmarked by "scoreboard spec <Class>") | R16 (15 cases; fails on forever.9) |
| D15 | (forever.10, user decisions 2026-10-10) (a) **kmin**: per enemy class, the minimum number of healers over every pairing of the anonymous meter heal/damage rows (a row counts with heal ≥ 1000 and share ≥ kSharePct 65%), sticky max over the match; positive evidence only, never a cap. The forever.6 one-player rule needs kmin ≥ 1. (b) **elimination**: if kmin ≥ 1 and at most kmin players of the class are left after removing proven DPS (readable DPS spec, damage links with no heal link, a decisive link vote against, form exclusion), they are marked. (c) **druid form tie-break** (SAFE, never a veto): when a read proves a non-healing druid (n − kmax ≥ 1), the druid(s) with the most RAGE+ENERGY plate samples (≥ 5 samples, ≥ 10 points above the next) are not marked by the druid class rule; no revoke, no vote against, links / own meter row / spec still decide; friendly druids unaffected. (d) **linkNet 2**: a links-only mark needs heal links − damage links ≥ 2 | user decisions + real runs 16-19 | run 19 (no longer held out): plate precision 2/2 (forever.9b 2/3), enemy claims 3/3 (2/3), 梦之旅程 never marked, Moun claimed at t+487 by elimination; runs 16-18 unchanged (9/9, 9/9, 0 flips, R10 ceilings equal); R17, R18 |
| D16 | (forever.11, user) Healer threshold is a setting: /kthg General "Healer threshold" (KTH_NameplateSettings.healerSharePct, 40-90%, default = the built-in 60%) plus a collapsed "Per class/spec overrides" section (Priest / Paladin / Druid / Shaman with spec unknown, Discipline + Holy priest, Holy paladin, Restoration druid, Restoration shaman; each "Use global"). One concept moves: the healing share of a player's own output that makes a healer: healPct (cast links) and dmSharePct (meter row) = S; grpSharePct = S + 3 and kSharePct = S + 5 keep their forever.6/10 margins. Not exposed: the 35% off thresholds (hysteresis), amounts, counts, the 6x-median rule. Precedence: class+spec (spec known) -> class -> global -> built-in. The 0.30 heal share of the test truth (tools/export_replay.py) labels the logs for scoring; it is not an in-game threshold | user request | R19 (90 checks); R20: defaults / explicit 60% identical to forever.10 on runs 16-19 |
| D17 | (forever.11, user) One debug switch: the /kthg General "Enable Debug Logging" checkbox (KTH_NameplateSettings.debugEnabled) = /kthdebug (no argument flips it; on/off/status/clear). It gates the meter/verdict timeline (ForeverDebug), the F6 plate log + arena readability capture (ForeverPlateLog), DebugLog output (scan summaries, deep dumps) and MN_Diag counters. Default = the forever.10 timeline state (on unless /kthdebug off had been used). No decision rule reads it | user request | R20: debug on and off give detection identical to forever.10 on runs 16-19; off captures 0 rows. Perf: tests/results/PERF-forever.11.md |
| D18 | (forever.12, user: no artificial cap; the addon is used in open world, arena, BG and groups) The forever.6 teamMax (3) cap on the weak class rule and E.teamClaims are deleted | user decision | runs 16-19 identical to forever.11 (the cap never bound); R22 |
| D19 | (forever.12, user) /kthg General, next to the healer threshold: Remove-mark threshold (offPct + dmOffPct, 35%; clamped >= 5 and <= the lowest healer threshold in use - 5), Minimum healing for a damage-meter row (dmMin 1000), Heals needed for a mark without the meter (N: linkNet = N, healMin = N, unknownHealMin = N + 1; default 2/2/3; heals - hits >= N implies heals >= N, so healMin = N is the consistent value), Find healers by ruling out proven DPS (elim, on), Druids: skip the bear/cat druid (formTie, on). Saved in KTH_NameplateSettings; read at use time through the proxy E.cfg (nil = E.CFG) | user request | R21 (88 checks); R22: defaults and explicit defaults == forever.11 on runs 16-19, elim off loses Moun, tie-break off claims 梦之旅程 |
| D20 | (forever.12, bug fix) Reset tab "Reset All to Defaults" set KTH_NameplateSettings = nil only: the nameplate code kept the old table until /reload and the debug switch kept its state. Now one shared reset (HHTD.MNP_ResetSettings, also /kth reset): fresh defaults used live at once, every forever.11/12 General setting back to built-in, debug back to its default (on) | found while verifying the reset path | R21 (fails on the forever.11 reset) |
| F1 | (forever.3) `AceGUIWidget-CheckBox.lua`: `local SetDesaturation = SetDesaturation or <Texture:SetDesaturated shim>` | measured | user error `CheckBox.lua:130: attempt to call a nil value` from /kthg; `SetDesaturation` absent from ForeverDump's static global list (10970 names), `Texture:SetDesaturated` present. All other AceGUI widgets + AceConfigDialog scanned (tests/api_scan_test.py, mock strictness): no other missing function that is not already guarded |
| F3 | (forever.3) Mouse-over / target alerts: `HHTD:TestUnit` resolves an enemy whose GUID is secret by its exact name (D5b) to K.T.H.'s registry record, or, when the nameplate rule marks it, to a record for that unit; then K.T.H.'s own flow continues (HHTD_HEALER_MOUSE_OVER / HHTD_TARGET_LOCKED, Announcer sounds). UnitIsDead/UnitIsUnit truth tests made secret-safe. Announcer: class colour from clear UnitClass, else roster class, else red (UnitClass secret would error in GetClassHexColor); UnitSex secret-safe | measured | ForeverDump runs 16-18: mouseover/target hostile-player UnitGUID = S, UnitClass = S, UnitName (both returns), UnitCanAttack, UnitIsDeadOrGhost, UnitIsPlayer = C. forever.2 replays (runs 16-18): 0/224 healer hovers alerted (the user's report); forever.3: 224/224 |
| F4 | (forever.3) `/kthsound`: plays K.T.H.'s 5 alert sounds 2 s apart and writes each `willPlay` to K.T.H.'s frame | diagnostic, no behaviour change | PlaySound/PlaySoundFile exist on Forever (static list); the kit IDs 8959/8174/8960 and file IDs 567458/567482 are not in the static data: **unmeasured**, this measures them |
| F5 | (forever.3) New BG/arena: clear `MN_HealersByName/ByGUID/ByClassSpec` | code-proven | K.T.H. never clears them; with D6 the previous BG's post-match healers would mark every enemy of their classes (CLASS+SCORE) in the next BG |
| F6 | (forever.3) Plate verdict log: in an active zone, every 2 s, each enemy plate's verdict when it changes `{t, who, v, pwr, cls, icon, tok}` into `HHTD_SavedVariables.global.ForeverPlateLog` (last 800); in arenas also one readability record per arenaN token | diagnostic, no behaviour change | the forever.2 diag had no per-plate verdict, so the in-game flicker could only be analysed by replay |
| F7 | (forever.3) Zones: roster join (D5/D5b) and D6 only in battlegrounds; heal evidence (D7) active in BG, arena, open world, and party/raid/scenario when K.T.H.'s own `Pve` option is on; roster/evidence reset when kind+instance id changes. Elsewhere K.T.H.'s original paths run unchanged (UnitClass when clear) | user directive + measured scope | the only measured scoreboard is the BG one; arena `faction` is the team index on retail and no arena/world capture exists, so arena/world enemy UnitClass readability is **unmeasured** (both models tested, R7) |
| T | `HHTD.MN_CheckUnitIsHealer = CheckUnitIsHealer`, `HHTD.MN_PlateIconShown` | test/diag hooks, no behaviour | used by tests/replay_score.lua and F6 |

### forever.3 variants scored and dropped
- **F2 druid form veto** (once a druid's plate shows RAGE/ENERGY, stop CLASS+PWR marks unless heal evidence). In
  forever.3 it was dropped because it lost run 13's enemy resto druid Korsica. **forever.4 re-check on real data only
  (runs 16-18):** run 13 is now out of all scores (board-less). On runs 16-18 the veto keeps the same first marks
  (precision 8/10, recall 8/9, resto druid Invictusap still marked). It cuts the feral-druid flicker in run 18 from
  Joff 25 / Tatusera 19 verdict flips to 1 / 1 (healer-verdict hovers 154 to 106).
  `tests/results/variants/forever4-real/*.druidVeto.json`. The run-13 case is still real in its combat log, but it
  can no longer be replayed with real data. **Not applied: the addon code is unchanged in forever.4. This needs the
  user's decision.** → **Resolved in forever.5 by the user's decision: D9 (healing output) replaces class + mana, so no form rule is needed.**
- **D8 re-check on real data (runs 16-18):** still refuted, enemy plate recall 0/9.

### Intermittent nameplate icon: root cause (forever.3)
- Icon machinery is not the cause: with K.T.H.'s real 1 s ticker running in the replay, icon state equals the verdict in
  all 7 runs (plate log healerNoIcon 0, iconNoHealer 0, R5). Plate recycling, parenting, the duplicate guard and secret
  bail-outs do not hide icons (no CHECK/TICKER errors; index ≤ 10).
- The verdict itself flips: run 18 (the forever.2 BG): Joff Wild (feral druid) 25 flips and Tatusera Reloca (feral druid)
  19 flips, MANA in caster form (marked) vs RAGE/ENERGY in forms (unmarked). That is K.T.H.'s own CLASS+PWR rule for
  druids. The three enemy priest healers (Ank, Karen, Randess) stay marked while their plate exists (Ank's 2 flips are a
  replay attribution artefact: a RAGE update on a priest). Paladin Torvian is never marked (ambiguous class, no
  confirmation in-match). Icons also only exist while the plate exists (range/visibility).
- So: "sometimes shows" = feral druids flickering by design, plus plates coming and going. Kept as K.T.H. designed it
  (F2 refuted). The F6 log measures it in game next time.

### Earlier draft diffs, now dropped (refuted, or Forever behaves like retail, so original code kept)
- GetBattlefieldScore "classic layout" (faction 6 / rank 7 / class 9-10): **refuted**. The layout is retail-like, and the
  fallback is unreachable because the GetScoreInfo table is clear. K.T.H. reads faction at position 7 (race) there; that
  is an original K.T.H. bug, identical on retail, and was left alone.
- GetScoreInfo "secret table" guard: **refuted**. The table is clear in all phases (the old claim was a ForeverDump
  probe flaw).
- UnitHealthMax('player') guard in UpdateHealThresholds: **refuted**. The 50 s timer ran through the whole BG with
  0 errors.
- MAX_CLASSES loop bound: **refuted**. Loading had 0 errors.
- AddToBlizOptions pcall: **not needed**. Forever ships the Settings UI (SettingsInbound in ForeverDump globals).
  The original code is kept, but this path is untested in-game because K.T.H. skips it when MN=false.
- TestUnit GUID/name fallback and Announcer UnitClass guards: dropped. Retail Midnight BG GUIDs are secret too, so this
  is retail behaviour and the original is kept.
- `MN_MyTeam` via GetBattlefieldArenaFaction: dropped. faction (0/1) is clear, and K.T.H.'s PLAYER_FACTION rule matches
  it (player Horde = faction 0 in the diag).
- RaidWarningFrame / UIErrorsFrame rerouting: dropped. These are not chat frames, and the original is kept.
  `/hhtdp` (ChatPlacard → SendChatMessage) stays as in the original. It only runs when you type it, or when the
  opt-in "ChatWarning" option is on (default off).

## forever.5: healing-output verdict (D9)

**User decision** (replaces the druid-form question): "heal and feral druids both have mana. having mana does not make
one a healer. furthermore balance druids have mana too and are not a healer. it's total healing done being
significantly higher than the average or when considering all actions the majority % of actions are healing output
vs dps output."

**What can be read, per source (measured; nothing below is assumed):**

| source | where | friendly | enemy | used |
|---|---|---|---|---|
| D7 frame join: cast + same-frame UNIT_COMBAT HEAL on a teammate / WOUND on an opponent | all zones (F7) | many links | very few (enemy casts reach the client 3-9 times per BG) | yes, action counts |
| C_DamageMeter `GetCombatSessionFromType(Current, HealingDone / DamageDone)` rows | everywhere the meter runs | `name` ("First Surname"), `sourceGUID`, `classFilename`, `totalAmount` clear out of combat | `name`/`sourceGUID` **secret**, `classFilename`, `specIconID` (class icon), `sourceDisplayType` (0/2) and `totalAmount` clear out of combat | yes, amounts; enemy rows joined to the BG scoreboard by class |
| same rows in combat | | `totalAmount`, `name`, `sourceGUID` secret (27/27) | secret | no (read on PLAYER_REGEN_ENABLED, as FD did) |
| scoreboard `healingDone`/`damageDone` | BG | clear post-match only (60/60) | clear post-match only | not for in-match marks (D6 stays post-match) |
| clear spellIDs (healer-only list) | open world / PvE where clear; nameplate spellIDs secret in BGs (20/20) | | | yes, one heal action each |
| target-of-target at heal-cast time | | not captured by any probe so far | | **not implemented** (unmeasured) |
| arena `arenaN` + C_PvP arena info | arena | not captured yet (F6 logs it) | | no new arena logic |

FD field counts (run 18 SV, `field:DamageMeterCombatSource.*`, ooc/combat reads): `totalAmount` 28 clear / 27 secret,
`name` and `sourceGUID` ooc 28 reads of which 13 secret (the enemy rows), combat 27/27 secret, `classFilename` and
`specIconID` always clear. Enemy rows: `sourceDisplayType` 2 (with the enemy `factionGroup`) or 0; friendly rows 1.
Matching the rows to the combat log over the session window (`tools/dm_match.py`): amounts are exact (e.g. run 18
enemy paladin 1377 = Torvian 1377 in the log), and type 0/2 rows are enemies (runs 16-18: 630 type 0/2 rows matched an enemy,
8 a friendly, 4 both; the rest fell outside the approximate session window).

**Rule and thresholds (tuned on real runs 16-18, `tools/dm_rules.py`, truth = combat log):**
- meter, one player (friendly by name; enemy when the class is unique on the enemy scoreboard): healer when heal ≥ 1000
  and (heal share of heal+damage ≥ 60% or heal ≥ 6× the median healing row of the session). Grid: share 0.55-0.75 and
  6×-10× median all give 8 of 9 such players with 0 false; 5× also 0 false; 4× gives 3 false (run 17 friendly DPS
  paladin/druids with heavy self-healing at 4.3-4.9×, share 0.43-0.49). 6× chosen for margin. The one miss is run 16's
  friendly druid Furbreezze (log heals on others 31%, meter share 26-28%): a hybrid, not a healer by the user's
  definition. Note: the meter's HealingDone includes self-healing, which is why the share threshold is 60, not 50.
- meter, several enemies of one class (names secret, rows cannot be told apart): every one of the n players is marked
  only when n rows are ≥ 1000 and ≥ 6× median; class-level "not a healer" when all n did ≥ 2000 damage and none healed
  ≥ 1000. Runs 16-17 (2 priests, both healers): marked; run 18 (3 priests, rows show 2 far above the group and 1 low):
  no mark, as the 2 cannot be told from the 3rd.
- actions (D7 links): healer at ≥ 60% heal links with ≥ 2 links (3 when the class is unknown).
- hysteresis / minimum evidence: unknown (no mark) until a rule fires; a mark is withdrawn only on contrary evidence
  (meter share < 35% with ≥ 2000 output, or < 35% heal links with ≥ 6 links). A decisive meter vote outranks link
  counts (run 17: two friendly DPS with 2-6 coincidental heal links and meter heal share 9-18% were claimed by links
  alone; with the meter first, 0 false claims).

**Scores (real data only: runs 16-18, real scoreboards, real meter snapshots, combat-log truth; `tools/score5.py`,
`tests/results/SCORES-forever.5.md`):**

| variant | plate precision | plate recall (enemy healers seen) | plate recall, user definition (heal share ≥ 50%) | plate TTI median s | icon on→off flips healers / non-healers | DPS druids marked | resto druids missed | claim precision | claim recall F / E |
|---|---|---|---|---|---|---|---|---|---|
| original K.T.H. | 0/0 | 0/9 | 0/8 | — | 0 / 0 | 0/2 | 1/1 | 0/0 | 0/8 / 0/9 |
| forever.3 (class + mana) | 8/10 | 8/9 | 7/8 | 0 | 2 / 23 | 2/2 | 0/1 | 7/10 | 7/8 / 0/9 |
| forever.5 without meter | 0/0 | 0/9 | 0/8 | — | 0 / 0 | 0/2 | 1/1 | 7/10 | 7/8 / 0/9 |
| **forever.5** | **5/5** | **5/9** | **5/8** | 205 | **0 / 0** | **0/2** | **0/1** | **12/12** | 7/8 / 5/9 |

Run 13 (board-less, out of the scores) as a sanity case from the combat log without names: its only enemy druid in the
log, Korsica, heals others for 48% of her output (a hybrid by the 50% definition, a healer by the 30% one). The run's
meter rows for the enemy DRUID class reach heal 1931 / damage 490 (share 80%) at 805 s, so D9 would mark her then **if**
the scoreboard showed one enemy druid; run 13 has no real scoreboard, so that join is unverified. The board-less replay
(D7 only) marks nobody.

**Limits (honest):**
- Enemy healing is hard to see in a BG: D7 enemy links are almost nil (forever.5 without meter: 0 of 9 enemy healers).
  Enemy identification comes from the meter, out of combat only, joined by class.
- By phase (enemy healers seen on plates, first marked, match time): 0-2 min 0, 2-5 min 0, 5-10 min 3, 10 min+ 2,
  never 4 (forever.3: 0 / 3 / 5 / 0, never 1, but 2 DPS druids marked and 23 flips). Claims (no plate needed): run 17
  priests at 230 s, run 16 resto druid at 391 s, run 16 priests at 657 s.
- These times are **upper bounds from the data, not the addon**: ForeverDump kept only the last 21 meter snapshots per
  run, so the first one available is at 381 s (run 16), 230 s (run 17) and 593 s (run 18). Earlier regen events had
  readable meters in the live client, but there is no data for them, and none was invented.
- Never marked: run 18's three enemy priests (the meter shows 2 of the 3 far above the group; which 2 is secret), run
  17's enemy holy paladin Gorrotar (1 of 3 enemy paladins; log share 59%). Randess (run 18) heals others for 39% only:
  not a healer by the 50% definition.
- Outside BGs enemy meter rows cannot be joined (no scoreboard); friendly meter rows still work by name.
- Arena and target-of-target readability is not captured; not used.

## forever.6: class-group meter rules (D10)
User: forever.3 found 8/9 enemy healers (8/10 precision) and forever.5 found 5/9 (5/5). "Keep the good, eliminate the bad."

### Forensics (runs 16-18; tools/forensics6.py, tools/forensics6_meter.py)
| run | player | class | log heal share | first plate (s from capture start) | plate power | links heal/dmg | forever.3 | forever.5 | forever.6 | why forever.6 marks or vetoes |
|---|---|---|---|---|---|---|---|---|---|---|
| 16 | Bleep | PRIEST | 0.82 | 484 | MANA | 0/0 | 484 CLASS+PWR | 749 | 749 | priest group heal [4925, 940] / dmg [292, 109], share 0.94 at 523 s → all |
| 16 | Frobby | PRIEST | 0.82 | 235 | MANA (+RAGE 10, plate noise) | 0/0 | 235 | 732 | 530 | same group |
| 16 | Invictusap | DRUID | 0.98 | 379 | MANA | 0/0 | 379 | 584 | 584 | only enemy druid: own row heal 2944 / dmg 208 |
| 17 | Gorrotar | PALADIN | 0.59 | 105 | MANA | 1/0 | missed | missed | 1106 | paladin group always "possible" (share 0.29-0.59, never all/none); his own cast healed a teammate, none hit an enemy; 2 enemies claimed (< 3) |
| 17 | Aerie | PRIEST | 0.99 | 359 | MANA | 0/0 | 359 | 359 | 359 | priest group share 0.96 at 230 s → all |
| 17 | Brocky | PRIEST | 0.85 | 459 | MANA | 1/0 | 459 | 459 | 459 | same group |
| 18 | Ank | PRIEST | 0.86 | 273 | MANA (+RAGE 7) | 0/1 | 273 | missed | 1052 | priest group heal [3060, 1309, 246] / dmg [833, 309], share 0.80 at 696 s → all (3 heal rows) |
| 18 | Karen | PRIEST | 0.82 | 143 | MANA | 0/0 | 143 | missed | 1036 | same group |
| 18 | Randess | PRIEST | 0.39 | 380 | MANA | 0/0 | 380 | missed | 715 | same group (a hybrid: log30 healer; not a healer under the 50% definition) |
| 18 | Joff (DPS) | DRUID | 0.12 | 226 | RAGE 849, MANA 517, ENERGY 183 | 1/0 | **false mark** 227 | – | – | druid group heal [543, 329] / dmg [3668, 2965] at 593 s → none (veto, kept by hysteresis; later "possible" reads never clear it) |
| 18 | Tatusera (DPS) | DRUID | 0.05 | 289 | MANA 259, ENERGY 152, RAGE 106 | 0/0 | **false mark** 289 | – | – | same veto |
| 18 | Torvian (ret) | PALADIN | 0.12 | 142 | MANA | 0/0 | – | – | – | only enemy paladin: own row never ≥ 60% healing in the kept snapshots |
| 17 | Ganon (friendly) | SHAMAN | 0.18 | – | MANA | 6/1 | **false claim** | – | – | friendly meter row by name: share 0.18 → no |
| 17 | Romsly (friendly) | DRUID | 0.09 | – | MANA/RAGE/ENERGY | 5/6 | **false claim** | – | – | friendly meter row: 0.09 |
| 17 | Vale (friendly) | DRUID | 0.09 | – | MANA/RAGE/ENERGY | 2/0 | **false claim** | – | – | friendly meter row: 0.09 |

Signals examined and **not** used, with the measured reasons:
- specIconID: one value per class (625999 druid ... 626008 warrior) in every snapshot. It is a class icon and never
  identifies a spec.
- Plate power type as proof of a form: priests show RAGE on their plates (Frobby 10, Aerie 6, Ank 7) and paladins
  show ENERGY (Tristan 16). That is plate/token noise, so "ENERGY/RAGE seen" is not proof of feral. Elimination by
  form power would also fire in none of runs 16-18 (no class group with a known number of healers smaller than its
  candidates). It is left out, because it has no evidence behind it.
- Class + mana as a mark: it is what forever.3 did, and it gave Joff and Tatusera. In runs 10-13, DPS priests were on
  MANA (D8). Class is a can-heal filter only.
- Team healer-count prior. Measured log30 healers per team, runs 10-18: enemy 2, 0, 2, 1, 3, 3, 3; friendly 2, 2, 1,
  0, 4, 1, 3 (max 4, not "2-3 at most"). It is used only as a cap on the weak (link) rule: fewer than 3 claimed
  enemies. It does not bind in runs 16-18 (variant f6e without the cap scores the same).
- Post-match scoreboard healing: not readable until the match ends, so it is no use for live marks. Meter amounts
  equal the log amounts, so the truth already reflects it.

### Rules (ForeverEvidence.lua, E.CFG grpSharePct = 63, weakLinkMin = 1, teamMax = 3)
For an enemy class with n ≥ 2 players (rows anonymous), at each out-of-combat meter read:
- **all**: at least n heal rows, summed heal ≥ 1000·n, and class heal share ≥ 63%. Margins: all-healer groups
  ≥ 0.664, every other group ≤ 0.592 (run 17 paladins at 495 s). The forever.5 rule (every row ≥ 6× median) stays as
  an OR.
- **none**: at least n damage rows, each ≥ 2000, and no heal row ≥ 1000 that could reach 60% even paired with the
  smallest damage row.
- **possible**: some heal row could reach 60%. Then a player of that class with ≥ 1 heal link and 0 damage links is
  marked, while fewer than 3 enemies are claimed.
- Hysteresis: an all/none class vote is kept until the opposite decisive vote. A "possible" read never clears it.
  This matters: the Current session resets, e.g. the run 18 druids read "possible" at 1170 s after "none" at 593 s.
  Single-player classes and friendly rows keep the forever.5 per-row rule.

### Backtest (tests/results/SCORES-forever.6.md)
| variant | precision | recall | flips | DPS druids marked | claims |
|---|---|---|---|---|---|
| original | 0/0 | 0/9 | 0 | 0/2 | 0/0 |
| forever.3 | 8/10 | 8/9 | 23 on non-healers | 2/2 | 7/10 |
| forever.5 | 5/5 | 5/9 | 0 | 0/2 | 12/12 |
| f6 group share 60 / 63 / 70, no link rule | 8/8 | 8/9 (Gorrotar missed) | 0 | 0/2 | 15/15 |
| f6 link rule needs 2 links | 8/8 | 8/9 (Gorrotar has 1) | 0 | 0/2 | 15/15 |
| f6 without team cap | 9/9 | 9/9 | 0 | 0/2 | 16/16 |
| **forever.6 (63, 1 link, cap 3)** | **9/9** | **9/9** | **0** | **0/2** | **16/16** |

Under the user's 50% definition, recall is 8/8. Randess (0.39) would count as a non-healer mark there, giving 8/9
precision. Run 13 (nameless sanity check) is unchanged: 0 marks, 0 errors.

### Limits, honestly
- **Time to identify**: no enemy healer is marked before 5 minutes (4 in 5-10 min, 5 after 10 min). forever.3 had 3
  marked by 5 min, but on class alone. The meter is readable only out of combat. FD kept just the last 21 snapshots:
  the first kept one is at 381 / 230 / 593 s. tools/earlysim6.py rebuilds earlier reads from the log. Under its
  OPTIMISTIC assumptions, priest groups would read "all" at 164 / 133 / 339 s. It also shows a risk: the single-row
  rule would have marked Torvian (ret paladin, self-heals in a 62 s window) at 279 s. Real early reads need the probe
  below before any threshold change.
- **Gorrotar rests on thin evidence**: 1 heal link plus a "possible" class read, late (1106 s). In these data the only
  other enemy with heal links ≥ 1 and damage links 0 in a can-heal class is Joff. Joff is vetoed only because his
  class read "none" before the link could count.
- 9 healers and 3 BGs are a small sample. The thresholds were chosen on these runs, with no held-out BG.

### Probe needed (FD/KTH)
Keep **every** C_DamageMeter Current-session snapshot for the whole BG (not a ring of 21), each with its
PLAYER_REGEN_ENABLED time and durationSeconds, plus the session start. This replaces the early-read simulation with
real data. It is the only way to measure true time to identify, and to check the single-row rule against self-healing
DPS on short sessions.

## forever.8: the user's healer-only spell list (D12)

The user decided the list from their own knowledge of the game. Each spell names one spec, and one cast marks the caster. The list is positive-only: absence never counts against anyone.
Discipline priest: Penance, Power Infusion | Holy priest: Prayer of Mending | Holy paladin: Light's Vigil |
Restoration druid: Wild Growth | Restoration shaman: Riptide. Swiftmend and Holy Shock are removed as instant flags. They stay
ordinary heal evidence through the retail lookup (Swiftmend 18562). Holy Shock's Forever IDs were never in that lookup.

### IDs and their sources (tools/healer_spells8.py, tools/healer_spells8.json)
Every SpellName row with the exact name in the captured DB2 (build 1.60.1.70245) was compared with wago.tools SpellName for the
same build. They are identical for all six names. Wowhead's Forever pages confirm the abilities as talents with ranks (Penance needs level 30, the others level 40).
Excluded rows: the SoD rune-learning spells ("Gain the X ability"), and Riptide 22419, an NPC "Disarmed" spell that has the same name.

| spec | spell | online ID(s) (source) | FD DB2 1.60.1.70245 IDs | equal to wago.tools? | IDs in KTH list | excluded | log-seen IDs (runs 1-18) | FD static/SV seen | match |
|---|---|---|---|---|---|---|---|---|---|
| Discipline priest | Penance | https://www.wowhead.com/forever/spell=402174 (R1), =1316995 (R4); https://wago.tools/db2/SpellName?build=1.60.1.70245 | 21: 402174 402261 402277 402284 402289 402844 1240720 1240721 1240723 1240724 1240727 1240730 1240732 1240733 1240734 1240736 1316991 1316992 1316993 1316994 1316995 | yes | 20 | 402844 (rune-learning "Gain the Penance ability") | 402284 (SPELL_CAST_SUCCESS 100, SPELL_DAMAGE 85, SPELL_MISSED 8, SPELL_ABSORBED 4), 402289 (SPELL_HEAL 734, SPELL_CAST_SUCCESS 742) | refdata.json: 402284, 402289 | yes: log IDs are in the DB2/online set |
| Discipline priest | Power Infusion | https://www.wowhead.com/forever/spell=10060; wago.tools SpellName 1.60.1.70245 | 1: 10060 | yes | 1 | - | none | none (all SV number hits were sequence/timestamp values) | cannot verify in logs: never cast in our captures (DB2 = wago = Wowhead only) |
| Holy priest | Prayer of Mending | https://www.wowhead.com/forever/spell=401859 (R1), =1240827 (R3); wago.tools SpellName 1.60.1.70245 | 15: 41637 401859 401863 401877 401880 401882 402832 1240826 1240827 1240848 1240849 1240918 1240919 1313379 1313381 | yes | 14 | 402832 (rune-learning) | none | none (all SV number hits were sequence/timestamp values) | cannot verify in logs: never cast in our captures (DB2 = wago = Wowhead only) |
| Holy paladin | Light's Vigil | https://www.wowhead.com/forever/spell=1310911 (R1), =1311599; wago.tools SpellName 1.60.1.70245; warcraft.wiki.gg/wiki/Light%27s_Vigil | 17: 1310909 1310910 1310911 1310912 1310914 1311590 1311591 1311592 1311593 1311594 1311595 1311596 1311597 1311598 1311599 1311601 1311806 | yes | 17 | - | none | none (all SV number hits were sequence/timestamp values) | cannot verify in logs: never cast in our captures (DB2 = wago = Wowhead only) |
| Restoration druid | Wild Growth | https://www.wowhead.com/forever/spell=408120 (R1), =1238215 (R3); wago.tools SpellName 1.60.1.70245 | 4: 408120 409810 1238214 1238215 | yes | 3 | 409810 (rune-learning) | none | none (all SV number hits were sequence/timestamp values) | cannot verify in logs: never cast in our captures (DB2 = wago = Wowhead only) |
| Restoration shaman | Riptide | https://www.wowhead.com/forever/spell=408521 (R1), =1239243 (R3); wago.tools SpellName 1.60.1.70245 | 9: 22419 405168 405194 405321 405324 408521 409954 1239242 1239243 | yes | 7 | 409954 (rune-learning), 22419 ("Disarmed", NPC spell, same name) | none | none (all SV number hits were sequence/timestamp values) | cannot verify in logs: never cast in our captures (DB2 = wago = Wowhead only) |

| spell | healer casters / casts (runs 1-18) | DPS casters / casts | unknown casters / casts | conflicts |
|---|---|---|---|---|
| Penance | 17 / 778 | 1 / 19 | 7 / 45 | Severn -run15-bg share 0.107, 19 casts |
| Power Infusion | 0 / 0 | 0 / 0 | 0 / 0 | none |
| Prayer of Mending | 0 / 0 | 0 / 0 | 0 / 0 | none |
| Light's Vigil | 0 / 0 | 0 / 0 | 0 / 0 | none |
| Wild Growth | 0 / 0 | 0 / 0 | 0 / 0 | none |
| Riptide | 0 / 0 | 0 / 0 | 0 / 0 | none |
| Swiftmend (removed) | 10 / 130 | 0 / 0 | 1 / 6 | none |
| Holy Shock (removed) | 5 / 55 | 2 / 22 | 0 / 0 | Ayorick -run12-bg share 0.061, 11 casts; Ayorick -run13-bg share 0.061, 11 casts |


### Backtest: COMBAT-LOG SIMULATION (only valid if enemy spell IDs were readable) vs live BG reality
tools/sim8.py measures, for each player, the time from their first heal on another player (direct or periodic) to their first SPELL_CAST_SUCCESS with a listed ID.

| run | player | class | log heal share | label | first listed cast | ID | flag - first heal s |
|---|---|---|---|---|---|---|---|
| 10-08-run8-bg | Wheat | PRIEST | 0.0 | unknown | Penance | 402289 | None |
| 10-08-run9-bg | Wheat | PRIEST | 0.0 | unknown | Penance | 402289 | None |
| 10-09-run10-bg | Barry | PRIEST | 0.785 | healer | Penance | 402284 | -12 |
| 10-09-run10-bg | Darthnik | PRIEST | 0.878 | healer | Penance | 402289 | -1 |
| 10-09-run10-bg | Stiggy | PRIEST | 0.683 | healer | Penance | 402289 | 9 |
| 10-09-run10-bg | Wheat | PRIEST | 0.0 | unknown | Penance | 402289 | None |
| 10-09-run11-bg | Aeddi | PRIEST | 0.864 | healer | Penance | 402289 | -95 |
| 10-09-run11-bg | Arphe | PRIEST | 0.565 | healer | Penance | 402289 | 0 |
| 10-09-run11-bg | Pretty | PRIEST | 0.0 | unknown | Penance | 402284 | None |
| 10-09-run14-bg | Anger | PRIEST | 0.851 | healer | Penance | 402289 | 14 |
| 10-09-run14-bg | Swig | PRIEST | 0.762 | healer | Penance | 402284 | -8 |
| 10-09-run15-bg | Albus | PRIEST | 0.65 | healer | Penance | 402289 | 0 |
| 10-09-run15-bg | Clinic | PRIEST | 0.959 | healer | Penance | 402289 | -1 |
| 10-09-run15-bg | Jalond | PRIEST | 1.0 | unknown | Penance | 402289 | 0 |
| 10-09-run15-bg | Milkshake | PRIEST | 1.0 | unknown | Penance | 402289 | -271 |
| 10-09-run15-bg | Severn | PRIEST | 0.107 | DPS | Penance | 402284 | -256 |
| 10-09-run15-bg | Shartkillero | PRIEST | 0.0 | unknown | Penance | 402289 | None |
| 10-09-run16-bg | Bleep | PRIEST | 0.816 | healer | Penance | 402284 | 117 |
| 10-09-run16-bg | Frobby | PRIEST | 0.82 | healer | Penance | 402284 | 9 |
| 10-09-run16-bg | Rabbit | PRIEST | 0.942 | healer | Penance | 402289 | 3 |
| 10-10-run17-bg | Aerie | PRIEST | 0.989 | healer | Penance | 402289 | -1 |
| 10-10-run17-bg | Brocky | PRIEST | 0.852 | healer | Penance | 402289 | -1 |
| 10-10-run18-bg | Ank | PRIEST | 0.86 | healer | Penance | 402289 | 0 |
| 10-10-run18-bg | Hyllina | PRIEST | 0.844 | healer | Penance | 402289 | 6 |
| 10-10-run18-bg | Karen | PRIEST | 0.822 | healer | Penance | 402289 | -1 |


The 9 BG healers on the real replays: Penance would flag Frobby +9 s, Aerie −1 s, Brocky −1 s, Ank 0 s, Karen −1 s and Bleep +117 s.
Invictusap (druid, Swiftmend only), Gorrotar (paladin) and Randess (priest, no Penance) cast nothing on the list.
**Live BG reality:** every non-self spellID is secret (FD runs 6-18). Live marks are unchanged from forever.7: 9/9 precision, 9/9 recall, 0 flips,
median 433 s after first heal (tests/results/SCORES-forever.8.md).

### Known disagreements (reported, not dropped; the user's list is authoritative)
- **Severn (run 15, PRIEST): log heal share 0.107, 19 Penance casts (402284 damage and 402289 heal).** Our log label says DPS, so Penance
  would flag him (in the sim, at his first Penance, 256 s before his first heal on another player). The user's reading: most likely a
  Discipline priest dealing damage. The label is a heal-share threshold, not a spec.
- Priests with too little output to judge and no heals on others also cast Penance: Wheat (runs 8, 9, 10), Pretty (run 11) and Shartkillero (run 15).
  They would be flagged.
- Holy Shock (removed): the DPS paladin Ayorick (runs 12 and 13, share 0.061) cast it 22 times. forever.7's healer_spells.py did not see this
  because it only looked at heal-effect IDs. The ID forever.7 listed, 1311605, is the heal effect; the logged cast ID is 1311606.
- Power Infusion: Wowhead's Forever page lists it as a talent with no tree. In retail it is also a Shadow priest cooldown
  (Blizzard_CooldownBroadcaster TrackedCooldowns.lua). Its tree in Forever is unverified, and it was never cast in our captures.
- Which ID live UNIT_SPELLCAST_SUCCEEDED reports for Penance is unmeasured. The log records 402284/402289 for the cast; the tooltip spell is
  402174. All rank and effect IDs are listed.

## forever.7: spec shortcut, healer-only spells, debug log (D11)

User request (09:45-09:50): flag healers within ~30 s of their first heal; combine class/spec, meter and the in-combat cast stream; staged
provisional/confirmed with demotion; no regression. Steering: a healer-spec-only spell list (one cast = flag), positive-only; a spec
shortcut (inspect, roles, scoreboard spec, arena specs) that is authoritative when readable; absence never counts against.

### What is readable live for enemies (ForeverDump runs 16-18, BG; runs 6/7 world/dungeon; runs 8/13 BG)

| signal | prep / gates | in combat | out of combat | post-match | used by forever.7 |
|---|---|---|---|---|---|
| plate UnitName (name, realm = surname) | clear | clear | clear | - | join key "First Surname" |
| plate UnitClass, UnitGUID | secret | secret | secret | - | no (GUID binding impossible for enemies) |
| plate UnitLevel | clear | clear | clear | - | logged in the plate log (context only) |
| UNIT_SPELLCAST_* spellID, any non-self token (nameplate, target, focus, arena, party/raid) | secret | secret | secret | - | healer-only spell path only fires where readable (not in BGs) |
| plate SUCCEEDED events | - | 11-25 per BG (capture complete) | - | - | - |
| UnitCastingInfo on plates (name, texture, spellID) | - | secret 31/31 | - | - | no |
| UNIT_COMBAT on plates (amount) | - | clear, ~700-850 per BG | - | - | heal/damage links (forever.6) |
| UNIT_AURA, UNIT_HEAL_PREDICTION | - | fire, payload secret | - | - | no |
| damage meter (Current session) | - | secret | clear | clear | verdicts (forever.5/6) |
| scoreboard name/class/faction | clear | clear | clear | clear | class groups |
| scoreboard talentSpec | secret | secret | secret | clear | spec layer (post-match only, so no in-match gain) |
| UnitGroupRolesAssigned / GetInspectSpecialization (others) | unmeasured | unmeasured | unmeasured | - | implemented defensively: HEALER role positive-only, DAMAGER never counted |
| GetArenaOpponentSpec | no arena capture | - | - | - | implemented; authoritative when it returns a healer spec ID |

### Healer-only spell list (positive-only fast path)

Derived from every WoWCombatLog in runs 1-18 (tools/healer_spells.py, tools/healer_spells.json). Healer = healing share ≥ 0.5 on the
meter-equivalent log totals; DPS = share < 0.30 with ≥ 2000 output. Kept only if 0 DPS casters (zero tolerance).

| spellID | name | healer casters / casts | DPS casters | unknown casters | verdict |
|---|---|---|---|---|---|
| 18562 | Swiftmend | 10 / 260 | 0 | 1 (Kwee, share 0.53, low output) | KEPT |
| 1311605 | Holy Shock | 5 / 25 | 0 | 0 | KEPT |
| 402289 | Penance | 17 / 1386 | 1 (Severn, run 15, share 0.107, 4 casts) | 6 | DROPPED |
| Riptide, Earth Shield, Lifebloom, Wild Growth, … | - | never observed | - | - | not listed |

Talent/rune gating is an assumption: no Talent/SkillLineAbility DB2 tables were captured.

Time to flag in the BG replays: none. Spell IDs from enemies are secret on every token, so the path cannot fire in the
battlegrounds we have. What it would give if spell IDs were readable (from first heal on another player in the log):
Invictusap +43 s (Swiftmend). With Penance (dropped): Frobby +3, Aerie −1, Brocky −1, Ank 0, Karen −1, Bleep +293 s. It would also
have marked the DPS priest Severn, so Penance stays out unless the user accepts that risk.

### Spec shortcut

Healer specs: Discipline/Holy priest, Holy paladin, Restoration druid, Restoration shaman (IDs 256, 257, 65, 105, 264).
Sources: arena opponent specs, group roles (HEALER only), scoreboard talentSpec, a healer-only spell cast (kept for the match).
A readable healer spec marks immediately and overrides the heuristics. A readable non-healer spec ID revokes. Missing spec, a DAMAGER role or
an unknown ID never counts against anyone. Binding is to "First Surname"; enemy GUIDs are secret.

### Staged provisional tier: not added

The only in-combat evidence per enemy is the UNIT_COMBAT heal/damage link. The real healers' first heal links come late (Brocky 480 s,
Gorrotar 1105 s; the others had none before their meter claim). A provisional mark on one link would have marked the non-healer Joff
from 360 to 593 s, and the non-healers Chinaeastern and Rei (run 16) also have 1/0 links. That breaks the "0 false marks" rule
with no speed gain, so it is not shipped.

### /kthdebug

`/kthdebug on|off|clear`. It keeps every meter read (all rows, both types) and every mark/revoke verdict for the last 5 sessions in
`HHTD.db.global.ForeverDebug` (400 + 400 per session). The ForeverDump ring kept only 21 of 24-28 meter reads per BG and lost the early ones. With
this log, the next BGs give a full-timeline backtest from KTH itself.

## Replay scores (tests/results/SCORES.md, forever.4: real data only)
Variants: orig = original K.T.H. (Midnight path), port2 = forever.2, port3 = forever.3/forever.4 (same addon code).
Truth: heal on others ≥ 30% of (damage + heal on others) and ≥ 5 direct heals on others (combat log).

**Data (forever.4 cleanup, user rule: no fabricated or inconsistent data in test files).** Older exports gave every
roster row the placeholder surname "Synth". `tools/realnames.py` now recovers real "First Surname" names from each
run's own ForeverDump SV: guid-linked damage-meter/identity records (G), FD scoreboard records and plate name-realm (S),
and a scoreboard row matched on first name + class when two players share a first name (S2).
- Run 16: re-exported with real names, 31/31 (G 15, S 15, S2 1: the enemy rogue "Johnny Snowden", while the friendly
  shaman "Johnny Morningwind" is guid-linked). The scoreboard class agrees with the log-voted class 31/31. Events are
  byte-identical to the previous export.
- Runs 17, 18: already real (KTH diag board). The resolver reproduces them 30/30 and 29/29. Run 18's "Shadow Synth"
  is a real player (GUID Player-4619-00720C89 in the combat log, damage meter and plate UnitName).
- Runs 10-13: no real full name in their SVs (0/33, 0/30, 0/29, 0/29). Re-exported board-less: no full names, no
  classes, first names as logged only, no scoreboard in the harness. Every score depends on the scoreboard, so they
  are **dropped from all scores and from R4/R5**. The files stay as cleaned real data.
- R8 (`tests/replay_provenance_test.py`) fails if a replay has the placeholder pattern, a partial board, or any name
  the run's SV does not back. It fails on the old run-16 export. Synthetic unit fixtures live only in
  `tests/regress/` and carry `synthetic = true` (R2).

| variant | run | plate marks | plate TP | enemy healers seen on plates | evidence claims | claim TP | truth healers | mouse-over alerts / healer-verdict hovers (not target) | verdict flips healer/non-healer | plate log healerNoIcon/iconNoHealer |
|---|---|---|---|---|---|---|---|---|---|---|
| orig | run16 | 0 | 0 | 3 | 0 | 0 | 7 | 0/0 | 0/0 | 0/0 |
| orig | run17 | 0 | 0 | 3 | 0 | 0 | 4 | 0/0 | 0/0 | 0/0 |
| orig | run18 | 0 | 0 | 3 | 0 | 0 | 6 | 0/0 | 0/0 | 0/0 |
| port2 | run16 | 3 | 3 | 3 | 3 | 3 | 7 | 0/60 | 1/0 | 0/0 |
| port2 | run17 | 2 | 2 | 3 | 4 | 1 | 4 | 0/44 | 0/0 | 0/0 |
| port2 | run18 | 5 | 3 | 3 | 3 | 3 | 6 | 0/120 | 2/44 | 0/0 |
| port3 | run16 | 3 | 3 | 3 | 3 | 3 | 7 | 60/60 | 1/0 | 0/0 |
| port3 | run17 | 2 | 2 | 3 | 4 | 1 | 4 | 44/44 | 0/0 | 0/0 |
| port3 | run18 | 5 | 3 | 3 | 3 | 3 | 6 | 120/120 | 2/44 | 0/0 |

| variant | plate precision | plate recall (enemy healers seen) | plate TTI median s | claim precision | claim recall all | claim recall F | claim recall E | claim TTI median s | mouse-over alert rate |
|---|---|---|---|---|---|---|---|---|---|
| orig | 0/0 | 0/9 = 0% | None | 0/0 | 0/17 = 0% | 0/8 = 0% | 0/9 = 0% | None | 0/0 |
| port2 | 8/10 = 80% | 8/9 = 89% | 0.0 | 7/10 = 70% | 7/17 = 41% | 7/8 = 88% | 0/9 = 0% | 324.2 | 0/224 = 0% |
| port3 | 8/10 = 80% | 8/9 = 89% | 0.0 | 7/10 = 70% | 7/17 = 41% | 7/8 = 88% | 0/9 = 0% | 324.2 | 224/224 = 100% |

