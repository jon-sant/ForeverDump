# K.T.H. on WoW Forever: unmodified baseline + diagnostics

Purpose: find out how the **unmodified** K.T.H. behaves on WoW Forever before any port changes go in.

## Contents
- `KTH/`: the original K.T.H. 1.0.0-kth, byte for byte. The **only** change is `KTH.toc` line 1:
  `## Interface: 120000, 120001` became `## Interface: 16001`, so the client loads it.
- `KTH_ForeverDiag/`: a separate, read-only probe addon. It writes **only** to its own frame (`KTHForeverDiagFrame`)
  and to its own SavedVariables (`KTHForeverDiagDB`). It never writes to Blizzard chat.

## Install
Copy both folders to `World of Warcraft/_forever_/Interface/AddOns/`. Use the Forever client's own AddOns folder.
Restart the client fully (not just /reload).

## Test
1. Log in. The probe frame (bottom centre, draggable) shows `toc= ... MN= ... MidnightNameplates= ...`.
   That line tells you which branch K.T.H. took.
2. Queue for a battleground. Stay in it from the gates-closed prep phase until the end, and let the scoreboard
   appear after the match.
3. During the match, type `/kthfd` now and then for a summary. Other commands: `/kthfd scan` (one probe right now),
   `/kthfd errors` (last Lua errors), `/kthfd hide`, `/kthfd show`.
4. Log out or `/reload`, then send `WTF/Account/<acct>/SavedVariables/KTHForeverDiagDB.lua`.

## What the probe records (raw; nothing hashed or scrubbed)
- **sessions**: toc, build, project id, K.T.H. loaded, `Constants.MN` and `Constants.WOWC`, whether
  MidnightNameplates ran, whether the CLEU getters exist, K.T.H. `MN_Diag` counters and registry sizes.
- **units**: readability of UnitName, UnitGUID, UnitClass (both returns), UnitPowerType, UnitIsFriend,
  UnitCanAttack and UnitHealthMax on every enemy and friendly player nameplate. Codes: C clear, S secret,
  T secret table, N nil, E error. Up to 300 raw samples.
- **score**: readability of GetNumBattlefieldScores and of every GetBattlefieldScore position, plus each
  C_PvP.GetScoreInfo field (name, guid, classToken, className, talentSpec, roleAssigned, faction, race, killing
  blows, honorable kills, deaths, honor gained, damage done, healing done, rating, bgRating).
  Fields are read **inside tables flagged secret as well**. The key suffix `@T` / `@C` / `@S` gives the table's
  own flag. Up to 400 raw rows of each.
- **spells**: whether UNIT_SPELLCAST_SUCCEEDED spellIDs are readable, per unit family.
- **errors**: every Lua error (the probe chains to the existing handler and never swallows anything), flagged
  when it comes from K.T.H.
- **blocked**: ADDON_ACTION_BLOCKED and ADDON_ACTION_FORBIDDEN events.
- **kthPrints**: every K.T.H. `HHTD:Print` call. These go to Blizzard chat in the unmodified addon; see below.

Every read is tagged `phase|pN`. N is the scoreboard player count. The phase is one of:
- `world`
- `prep` (gates closed, from C_PvP.GetActiveMatchState)
- `ooc` (gates open, out of combat)
- `combat`
- `post` (GetBattlefieldWinner set, or match state PostRound/Complete)

Raw `matchState` and `winner` are stored with each sample. While you are in a BG, the probe calls
RequestBattlefieldScoreData every 10 s (the same call K.T.H.'s Midnight path makes), so the scoreboard gets
probed even when K.T.H. itself never asks for it.

## WARNING: the unmodified K.T.H. writes to Blizzard chat
The rule is never to AddMessage/print into Blizzard chat frames, because doing so taints ChatFrame1 and breaks
BattlegroundChatFilters. The unmodified addon breaks that rule in these places:
- `HHTD:Print` (AceConsole Print, which goes to DEFAULT_CHAT_FRAME) answers every slash command (`/hhtdg`,
  `/hhtddiag`, `/hhtdv`, `/hhtdreset`, `/hhtdauto`, `/kth ...`, `/kthdebug`, `/kthdiag`) and fires on
  disable/diagnostic messages.
- The NamePlateHooker / CustomMarks modules print too. On Forever they are **enabled**, because K.T.H. takes the
  non-Midnight branch at toc 16001.
- `/hhtd` (AceConfigCmd) prints its option list into the selected chat frame.
- `HHTD:Error` writes to UIErrorsFrame and chat.
- Announcer "healer under attack" writes to RaidWarningFrame (HUDWarning is on by default). Its chat lines are
  off by default.
- MidnightNameplates prints a login banner, but only on the Midnight branch.

Only the slash commands produce chat output on demand. To keep the BG chat-filter test clean, **don't type K.T.H.'s
own slash commands** during the test; use `/kthfd`. The probe still counts any K.T.H. print in `kthPrints`.

## License
K.T.H. is "All Rights Reserved" (John Wellesz, H.H.T.D.; Scone, K.T.H.). This package is for private testing
only. Do not redistribute it.
