# K.T.H. review: secret handling compared with ours (ForeverDump / HSM tooling), and what carried over to Forever

## How K.T.H. 1.0.0-kth handles secrets (retail 12.0 Midnight)
1. **Scoreboard first.** `C_PvP.GetScoreInfo` → talentSpec → `CLASS_SPEC_TO_ROLE` (from
   GetSpecializationInfoForClassID). roleAssigned is the fallback. It builds an independent healer list (by name, by
   GUID, by class:spec) that bypasses the H.H.T.D. registry/reaper.
2. **Nameplates by class + power.** Enemy names and GUIDs are secret on retail, but UnitClass and UnitPowerType are
   not. Priest/Druid/Monk on mana counts as a healer. Paladin/Shaman/Evoker are ambiguous and need a SPELL
   confirmation (a clear healer-only spellID on that plate) or CLASS+SCORE (the enemy team has a healer of that class).
3. **Guards.** `canaccessvalue` on every read, pcall around each API, and pcall around every plate check.
4. **Output.** Diagnostics go only to DebugLog. Only the login banner and slash replies use HHTD:Print.
5. **Combat log.** It registers COMBAT_LOG_EVENT_INTERNAL_UNFILTERED via C_CombatLogInternal when present. Otherwise
   it uses UNIT_SPELLCAST_* only.

## Compared with our approach
| topic | K.T.H. | ours (ForeverDump probes, replay harness) | verdict |
|---|---|---|---|
| per-value readability | `canaccessvalue` checks inline, with no record of what was secret | KTH_ForeverDiag records a per-field code for every read, per BG phase, including fields inside readable tables | ours is better for deciding what to build. K.T.H.'s is fine at runtime |
| truth tests | some `x and canaccessvalue(x)` (truth test first) | `canaccessvalue`/type first, then the truth test (Forever errors on a secret boolean test) | ours is safer. Ported as D4 |
| scoreboard | trusts talentSpec | measured: secret in-match on Forever, clear post-match | the K.T.H. idea is right, but Forever withholds the field until the end |
| class on plates | UnitClass | measured secret on Forever enemy plates → scoreboard roster join on first name + side, with a duplicate guard | the join is our technique (D5) |
| spell confirmation | clear healer-only spellIDs | spellIDs secret → frame-join heal evidence (cast + same-frame UNIT_COMBAT HEAL on a teammate) | ours; works for teammates, but almost no enemy casts are delivered on Forever |
| chat hygiene | DebugLog + HHTD:Print banner | nothing in Blizzard chat at all (own frame) | ours is stricter. Ported as D3 |
| restricted events | does not register CLEU on 12.0 (MN branch) | ForeverDump denylist: CLEU / COMBAT_LOG_EVENT | same idea. K.T.H. only failed on Forever because its MN switch is toc-based (D2) |
| testing | none shipped | Forever mock + replay of 5 captured BGs against combat-log truth | ours |

## What K.T.H. taught us
- An **independent healer list** that bypasses the registry and reaper is a good pattern for nameplate marking. We kept it.
- **CLASS+SCORE** (mark every plate of a class when the scoreboard shows a healer of that class) is a useful low-precision
  fallback. On Forever it only fires post-match, because talentSpec is secret until then.
- K.T.H.'s **power check** still pays off on Forever: replays give 6/7 enemy healers marked on first sight. The
  cost is 50% precision, since DPS priests and caster DPS druids are also on mana there.

## Forever versus retail, as measured (baseline BG, 2026-10-09)
- Same as retail: GetScoreInfo table readable; name, classToken and faction clear; GUIDs secret; spellIDs secret;
  GetBattlefieldScore layout.
- Different: enemy plate **UnitClass secret**. Enemy plate **UnitName clear, first name only** (the scoreboard has
  "First Surname"). **No CLEU getter** at all, and registering CLEU is forbidden. MN detection by toc fails
  (toc 16001). Classic power types.

## Open points
- Enemy healers of a class with several players on the enemy team: forever.5 missed 4 of 9 (run 18's 3 priests, run 17's paladin Gorrotar). forever.6 adds class-group meter rules and marks 9/9 with 0 false marks on runs 16-18. Gorrotar rests on one heal link plus a 'possible' class read (thin evidence; see FOREVER-PORT.md, forever.6).
- Friendly nameplates were off in every capture, so friendly plate marks are untested.
- AddToBlizOptions on Forever is untested in game (the baseline skipped it). It is expected to work: the Settings UI is
  present.

## forever.3 addendum (field test of forever.2 + ForeverDump run 18)
- **/kthg error** (`CheckBox.lua:130`): the global `SetDesaturation()` does not exist on Forever. AceGUI's CheckBox now
  falls back to `Texture:SetDesaturated` (F1). The mock now drops every global function that is not in ForeverDump's
  static list, and aligns widget methods with the Forever widget list. `tests/api_scan_test.py` fails on any unreviewed
  global. No other AceGUI widget or AceConfigDialog call was missing without a guard.
- **Mouse-over/target alerts never fired**: K.T.H. looks the unit up by GUID, and enemy mouseover/target GUIDs are
  secret on Forever (runs 16-18). Fixed by the exact-name resolver (F3). Replays (real-board runs 16-18): 0/224 alerts (forever.2), 224/224
  (forever.3).
- **Plate realm = surname** (D5b): `UnitName` returns ("Ank", "Far") for scoreboard "Ank Far", 59/59 in runs 17+18.
  The roster join is now exact, so duplicate first names are no longer dropped.
- **Intermittent icon**: the icon equals the verdict at all times (replay with the real ticker). The flicker comes from
  K.T.H.'s druid rule: feral druids are marked in caster form and unmarked in forms. That is by design and kept. A
  form veto was tested and refuted.
- **Non-BG zones** (F7): scoreboard logic only in BGs. Arena and world rely on K.T.H.'s own checks plus heal evidence.
  Arena/world readability is not captured yet. The plate log and arena probe (F6) collect it.
- **Data (forever.4)**: the placeholder surnames are gone. Run 16 was re-exported with real names (31/31 backed by its
  SV). Runs 10-13 are board-less and out of all scores. Scores use runs 16-18 only: plate precision 8/10, recall 8/9,
  mouse-over alerts 224/224 (forever.2: 0/224).

## forever.5 addendum (user decision: healer = healing output)
- K.T.H.'s class + power rule (and the scoreboard class cache) marks by class; on Forever DPS druids and priests show
  MANA, so it marked run 18's feral druids and flickered with their forms. forever.5 marks by measured output instead:
  C_DamageMeter HealingDone vs DamageDone (out of combat; enemy rows have secret names but clear class and amount) and
  frame-joined heal/damage links. Rule: heal share ≥ 60% or heal ≥ 6× group median, with hysteresis (off < 35%).
- Real runs 16-18: plate precision 5/5 (forever.3 8/10), recall 5/9 (8/9), DPS druids marked 0/2 (2/2), icon on→off
  flips 0 (23), friendly claims 12/12 right. The trade: fewer and later enemy marks, but no class guesses.

## forever.6 addendum (user: keep forever.3's recall, keep forever.5's precision)
- Forensics (tests/results/SCORES-forever.6.md): forever.3's 8 marks were all CLASS+PWR, and 2 of them were DPS druids
  (Joff, Tatusera). Its miss was Gorrotar (a paladin, in a class with 2 DPS paladins). forever.5 missed the 3 run-18
  priests: 3 anonymous priest rows, not all 6x the median. It also missed Gorrotar.
- forever.6 reads the enemy class group as a whole: a summed class heal share of >= 63% (with one heal row per player)
  marks the whole class. On runs 16-18 every all-healer group measured >= 0.664 and every other group <= 0.592.
  "None" needs every player of the class to have done >= 2000 damage, and no heal row can reach 60% even when paired
  with the smallest damage row. When the read is "possible", one heal link and no damage link marks that player, while
  fewer than 3 enemies are claimed.
- Score: precision 9/9, recall 9/9, 0 on/off flips, 0 DPS druids marked, 16/16 claims. Marks come later than
  forever.3's: none before 5 minutes, because the meter is read out of combat only and FD kept 21 snapshots.

## forever.7 addendum (user: flag within ~30 s of first heal)
- Retail K.T.H. flags on healer-only spell casts. On Forever every non-self spellID is secret (all tokens, all phases), so that path is dead in BGs. forever.7 keeps it as a positive-only path (Swiftmend, Holy Shock; Penance dropped because a DPS priest cast it).
- The spec shortcut is authoritative when readable. Measured: scoreboard spec only post-match. Arena/roles/inspect are unmeasured on Forever.
- The latency floor is the meter (clear only out of combat). Median mark − first heal = 433 s, unchanged from forever.6. Sub-30 s needs a readable in-combat signal that does not exist in the captures.

## forever.8 addendum (user's healer-only list)
- The list is replaced by the user's six spells (62 Forever IDs; FD DB2 = wago.tools 1.60.1.70245). Only Penance appears in our logs. Severn (run 15) is a known disagreement with the heal-share label.
- forever.7's Holy Shock entry used the heal-effect ID (1311605), not the cast ID (1311606), and a DPS paladin cast Holy Shock. Its removal is correct on the data too.
