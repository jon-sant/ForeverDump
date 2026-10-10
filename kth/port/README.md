# K.T.H. Forever 1.0.0-kth-forever.6 (healer verdict = healing output, class-group meter rules)

K.T.H. (Kill The Healer) by Scone, built on H.H.T.D. by John Wellesz, ported to WoW Forever 1.60.1 (toc 16001).
**All Rights Reserved. This is a private port for personal use. Do not redistribute it.**

## Install
1. Close WoW Forever.
2. In `World of Warcraft/_forever_/Interface/AddOns/`, delete the old `KTH` folder (the baseline build).
3. Copy `AddOns/KTH` there.
4. Optional: copy `AddOns/KTH_ForeverDiag` (the same probe as in the baseline). It writes only to its own frame and
   SavedVariables. Keep it for one more BG if you want a second measurement with the port. Otherwise leave it out.
5. Start the client.

## In game
- `/kthg`: settings window (K.T.H.'s own panel). `/hhtd` opens the H.H.T.D. options window. On Forever, nothing is
  printed to chat.
- K.T.H. messages appear in its own small frame, top-left (`KTH_ForeverMessageFrame`). `/kthlog` shows or hides it.
- Healer markers (forever.5, your rule): a player is marked only when most of what they do is healing (60% or more
  of their output) or their healing is far above everyone else's (6x the group's median). Mana and class no longer mark
  anyone: feral, balance and resto druids all show mana. Class only rules out classes that cannot heal.
- Where the evidence comes from: the damage meter (healing done vs damage done), read each time you leave combat;
  and casts of a player that heal a teammate in the same moment. Enemy names are secret in the meter, so in a BG an
  enemy is matched by class through the scoreboard: exact when they are the only enemy of that class. With several of
  one class (forever.6): all are marked when the class as a whole is mostly healing (63% or more of that class's
  combined output, with a heal row for each of them); none are marked when every one of them did real damage and no
  heal row could be a healer's; in between, a player of that class whose own casts healed a teammate (and never hit an
  enemy) is marked while fewer than 3 enemies are marked as healers (no logged BG had more than 3 enemy healers).
- A mark stays until there is clear contrary evidence (healing under 35% of output), so the icon does not flicker.
  No mark until there is enough evidence: expect enemy healers to appear after the first fights, not on first sight.
- Mouse-over an enemy healer: K.T.H.'s alarm sound and "is a healer" message; click it: the target-lock sound
  (forever.3 fix: enemy GUIDs are secret on Forever, the unit is now found by its full name).
- `/kthsound` plays K.T.H.'s five alert sounds 2 s apart and shows whether the client played each one
  (`willPlay`) in K.T.H.'s frame. Please run it once and send the result: the sound IDs are unverified on Forever.
- Arena, world, dungeons and raids: the same healing-output rule. The scoreboard join is used only in BGs, so enemy
  meter rows cannot be matched outside BGs; friendly meter rows (names readable) and cast evidence still work. Heal
  evidence runs in arenas and the open world, and in dungeons and raids when K.T.H.'s PvE option is on. Arena and
  world readability has not been captured yet, so expect few enemy marks there.
- K.T.H. logs each enemy plate's verdict changes to its SavedVariables (`ForeverPlateLog`). Send
  `WTF/Account/<acct>/SavedVariables/KTH.lua` after a BG or an arena match.
- `/hhtdp` posts K.T.H.'s healer placard to BG chat. This is K.T.H.'s original feature and only runs when you type it.

## What to expect (replays of 3 captured BGs with the real scoreboard and real damage-meter reads: runs 16, 17, 18)
- Enemy marks: 5 of 5 right (forever.3: 8 of 10), 0 DPS druids marked (forever.3: both), 0 icon on/off flicker
  (forever.3: 23 on non-healers). The resto druid in run 16 is found.
- Found: 5 of 9 enemy healers (forever.3: 8 of 9, but by class). Not found: run 18's three priests (the meter shows
  two of them healing far above the group, but enemy names are secret, so which two is unknown) and run 17's holy
  paladin (one of three enemy paladins).
- When: enemy healers were identified 4 to 11 minutes in; the icon showed the next time their plate was on screen
  (6 to 12.5 minutes). In these recordings the damage-meter data starts late (the
  recorder kept only its last 21 reads), so live it can be earlier.
- Friendly healers: 7 of 8 found, 12 of 12 claims right.
- Mouse-over alert: plays for every marked enemy you hover (72 of 72).
- No "blocked from an action only available to the Blizzard UI" popup: the port never registers COMBAT_LOG_EVENT_UNFILTERED.

See `FOREVER-PORT.md` for every change and its evidence, `KTH-REVIEW.md` for the comparison with our own tools,
`tests/` for the harness, and `original/KTH` for the untouched original.

## forever.7
- Spec shortcut: when a healer spec is readable (arena opponent spec, HEALER group role, post-match scoreboard spec) or an enemy casts Swiftmend / Holy Shock where the spell ID is readable, the player is marked at once. Missing spec or spells never counts against anyone.
- In battlegrounds Forever hides enemy spell IDs and specs during the match, so marks still come from the out-of-combat meter (typically several minutes after a healer starts healing).
- `/kthdebug on|off|clear`: records meter reads and mark/revoke decisions to SavedVariables (HHTD.db.global.ForeverDebug, last 5 sessions) for later analysis. Local only.

## forever.8
- Instant healer flags use your list: Penance, Power Infusion (Discipline priest), Prayer of Mending (Holy priest), Light's Vigil (Holy paladin), Wild Growth (Restoration druid), Riptide (Restoration shaman). Swiftmend and Holy Shock no longer flag instantly.
- They only fire where the game shows the enemy's spell ID. Forever hides it in battlegrounds, so BG marks still come from the meter.

## forever.9
- Nameplate markers are H.H.T.D.'s healer icons: a cream cross for friendly healers, a red cross for enemy healers, and a ring in the class colour. If the class is unknown, the plain cross is shown. Choose `/kth icon friend|enemy hhtd|hhtdmin|cross|skull|...`. Installs that still had the old default "cross" switch to hhtd once.

## forever.10
- Fix: after a match, Forever's scoreboard reports the class name ("Priest") as the spec, and that used to remove every healer marker. A spec now counts only when it is a real spec name.
- HoT healers count (your rule). The test truth now includes HoT ticks (heal share >= 30% and >= 5 heals on others, ticks included). The damage meter the addon reads already included HoT healing.
- Several enemies of one class: the damage meter rows can prove that at least N of them are healers. When enough of the others are proven DPS (damage with no healing seen, a DPS spec), the remaining one(s) are marked. This is how Moun (run 19) is found.
- Druids: when the meter proves at least one of several enemy druids is not healing, the druid that spends the most time in bear/cat form is not marked by the class rule. This only breaks ties and never removes an existing mark.
- A mark from cast evidence alone now needs two more heals than hits (the feral 梦之旅程 in run 19 had 2 heals and 1 hit).

## forever.11
- `/kthg` General tab, "Healer Detection": **Healer threshold** = how much of a player's own output must be healing before they are marked (default 60%, as before). The class-group rules keep their small margins above it. Changes apply at the next evidence update (leaving combat).
- "Per class/spec overrides" (collapsed, tick to show): Priest / Paladin / Druid / Shaman (spec unknown) and Discipline, Holy priest, Holy paladin, Restoration druid, Restoration shaman. Each defaults to "Use global". A spec entry is used only when the spec is known. In battlegrounds the enemy spec is unknown during the match, so the class entries are what apply there. When a healer spec is known, the spec alone already marks the player.
- "Enable Debug Logging" is now the single switch for all K.T.H. diagnostics (meter/verdict timeline, nameplate log, DebugLog output). `/kthdebug` flips the same switch (`/kthdebug on|off|status|clear`). It stays on if it was on before (the forever.10 default). Detection does not depend on it.

## forever.12
- No cap on the number of healers any more (forever.6 allowed at most 3 enemy healers through one of its rules).
- `/kthg` General tab, next to the healer threshold (defaults = the old built-in values):
  - **Remove-mark threshold** (35%): a mark goes only when healing falls below this share. Always at least 5 points below the healer threshold.
  - **Minimum healing for a damage-meter row** (1000).
  - **Heals needed for a mark without the meter** (2): heals minus hits on enemies, and at least that many heals (one more when the class is unknown).
  - **Find healers by ruling out proven DPS** (on) and **Druids: skip the bear/cat druid** (on).
  - "Reset detection settings" resets this section only.
- Reset tab, "Reset All to Defaults": now resets everything at once, including all detection settings and the debug switch (back to on). Before, the icons only reset after /reload.
