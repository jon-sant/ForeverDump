# Captures (all raw) - foreverdump/real/

Every run directory holds the user's files verbatim: `sv/ForeverDump.lua` (SavedVariables as uploaded; packed SVPack format from v2.2.11),
`sv_raw/` (pre-v2.2.21 runs: IdKeys restored by `fdump.py unhash`), `WoWCombatLog.txt` (if cut to the capture window the uncut file is
`WoWCombatLog.original.txt`), `taint.log`/`Client.log`/`WoWChatLog.txt`/screenshots when sent, `raw/` or `sv.zip` = the uploaded zip, `out/` = analysis outputs.
Inclusion = the 100 %-raw rule (`tools/fdump/data/unhash-inclusion.json`). Times ET. Builds are 1.60.1.<build>.

| run | dir | type | addon | build | inclusion | combat log | dir size | files |
|---|---|---|---|---|---|---|---|---|
| run1 | `2026-10-07` | open world | 2.0.0 | 70245 | INCLUDED (no hashing) | 0.2 MB | 77 MB | PROGRESS.md, WoWCombatLog.txt, out, sv, sv_raw, taint.log |
| run2 | `2026-10-07-run2` | open world | 2.1.0 | 70245 | INCLUDED (no hashing) | 0.2 MB | 54 MB | Client.log, WoWCombatLog.txt, out, panel1.png, panel2.png, sv, sv_raw, taint.log |
| run3 | `2026-10-07-run3` | open world | 2.2.1 | 70245 | INCLUDED (no hashing) | 0.5 MB | 81 MB | WoWCombatLog.txt, out, sv, sv_raw, taint.log |
| run4 | `2026-10-07-run4` | open world | 2.2.2 | 70245 | INCLUDED (no hashing) | 0.6 MB | 72 MB | WoWCombatLog.txt, hsm-screenshot.png, out, sv, sv_raw, taint.log |
| run5 | `2026-10-08-run5` | open world | 2.2.3 | 70245 | INCLUDED (no hashing) | 0.8 MB | 83 MB | WoWCombatLog.txt, convert.sh, out, sv, sv_raw, taint.log |
| run6 | `2026-10-08-run6` | open world | 2.2.6 | 70291 | INCLUDED (100% restored) | 0.3 MB | 32 MB | WoWCombatLog.txt, convert.sh, out, screenshot.png, sv, sv_raw, taint.log |
| run6b | `2026-10-08-run6b` | open world | 2.2.6 | 70291 | INCLUDED (100% restored) | 1.3 MB | 34 MB | Client.log, WoWCombatLog.txt, convert.sh, out, sv, sv_raw, taint.log |
| run7 | `2026-10-08-run7` | open world | 2.2.7 | 70291 | INCLUDED (100% restored) | 1.3 MB | 32 MB | WoWChatLog.txt, WoWCombatLog.txt, out, sv, sv_raw, taint.log |
| run8 | `2026-10-08-run8-bg` | BG | 2.2.7 | 70291 | **EXCLUDED** (resolvedPct 83.9 < 100) | 1.8 MB | 98 MB | WoWChatLog.txt, WoWCombatLog.txt, errors-show.png, out, sv, sv_raw, taint.log |
| run9 | `2026-10-08-run9-bg` | BG | 2.2.10 | 70291 | **EXCLUDED** (resolvedPct 93.9 < 100) | 12.9 MB | 172 MB | WoWCombatLog.txt, out, sv, sv.zip, sv_raw, taint.log |
| run10 | `2026-10-09-run10-bg` | BG | 2.2.11 | 70291 | INCLUDED (100% restored) | 25.0 MB | 180 MB | WoWCombatLog.txt, out, sv, sv.zip, sv_raw |
| run11 | `2026-10-09-run11-bg` | BG | 2.2.11 | 70291 | INCLUDED (100% restored) | 7.3 MB | 114 MB | WoWCombatLog.txt, out, screens, sv, sv.zip, sv_raw |
| run12 | `2026-10-09-run12-bg` | BG | 2.2.14 | 70291 | INCLUDED (100% restored) | 3.1 MB | 40 MB | WoWCombatLog.txt, out, sv, sv.zip, sv_raw |
| run13 | `2026-10-09-run13-bg` | BG | 2.2.15 | 70291 | INCLUDED (100% restored) | 8.7 MB | 84 MB | WoWCombatLog.txt, out, sv, sv.zip, sv_raw |
| run14 | `2026-10-09-run14-bg` | BG | 2.2.16 | ? (packed SV) | **EXCLUDED** (resolvedPct 98.2 < 100) | 3.7 MB | 57 MB | WoWCombatLog.txt, out, sv, sv.zip, sv_raw |
| run15 | `2026-10-09-run15-bg` | BG | log-only (capture was off; SV is from an earlier session) | ? | **EXCLUDED** (resolvedPct 87.1 < 100) | 6.7 MB | 77 MB | WoWCombatLog.txt, out, sv, sv.zip, sv_raw |
| run16 | `2026-10-09-run16-bg` | BG | 2.2.21 | 70334 | INCLUDED (no hashing) | 7.8 MB | 45 MB | WoWCombatLog.txt, out, sv, sv_raw |
| run17 | `2026-10-10-run17-bg` | BG | 2.2.21 | 70334 | INCLUDED (no hashing) | 12.3 MB | 55 MB | WoWCombatLog.txt, kth, out, sv, sv_raw |
| run18 | `2026-10-10-run18-bg` | BG | 2.2.23 | 70334 | INCLUDED (no hashing) | 9.8 MB | 71 MB | WoWCombatLog.txt, kth, out, sv, sv_raw |
| run19 | `2026-10-10-run19-bg` | BG | 2.2.25 | 70338 | INCLUDED (no hashing) | 8.0 MB | 41 MB | WoWCombatLog.txt, kth, out, sv, sv_raw |
| run20 | `2026-10-10-run20-dungeon` | dungeon (Ragefire Chasm) | 2.2.25 | 70338 | INCLUDED (no hashing) | 0.2 MB | 27 MB | WoWCombatLog.original.txt, WoWCombatLog.txt, out, sv |
| run21 | `2026-10-10-run21-world` | open world (Thousand Needles) | 2.2.25 | 70338 | INCLUDED (no hashing) | 1.1 MB | 15 MB | WoWCombatLog.original.txt, WoWCombatLog.txt, out, sv |
| run22 | `2026-10-10-run22-bg` | BG | 2.2.27 | 70338 | INCLUDED (no hashing) | 6.6 MB | 101 MB | RAW-NOTE.md, WoWCombatLog.original.txt, WoWCombatLog.txt, out, raw, sv |

Excluded runs stay for log-only backtests (the combat log is written by the client, not ForeverDump) and for history;
never use their SVs in scoring, the master guide, fixtures or replays.

User uploads: `captures/user-uploads/` (154 files named by sha256, as received) with `captures/UPLOADS-INDEX.tsv`:
EXACT = byte-identical copy exists at that path; ZIP = members found in the listed dirs (unmatched members are counted);
UNMATCHED = only here (screenshots, early guide HTML exports, notes) - nothing was dropped.
