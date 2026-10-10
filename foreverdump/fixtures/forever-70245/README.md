# Raw fixture pack: WoW Forever 1.60.1 build 70245 (TOC 16001, WOW_PROJECT_CAMELOT = 18)

Made from one real capture (2026-10-07) with
`python3 tools/fdump.py fixtures DUMP --file WoWCombatLog.txt --taint taint.log --max-lines 1029 -o fixtures/forever-70245`.
v2.2.21 (user decision 2026-10-09): the pack is RAW - nothing is anonymized or scrubbed.

| file | content |
|---|---|
| environment.json | the SV meta (build, TOC, project, identity, ...) and every changed CVar, as read |
| api-surface.json | names only: 5046 present global functions, namespaces and their functions, 1797 events |
| secrets-documented.json | documentation-derived secrets map (flags, aspects, secrecy-relevant functions/events/widget methods/structs); runtime sections stripped |
| WoWCombatLog.txt | the first 1029 lines of the advanced combat log (Orgrimmar), verbatim |
| combatlog_file.lua | the same log parsed into a replay fixture (`replay.lua`, 1023 CLEU events) |
| taint.log | the taint log (7 ADDON_ACTION_BLOCKED lines from a public addon), verbatim |
| pack.json | build and file list (raw = true) |

Real player GUIDs, names, realms and pets are kept exactly as logged.

Used by `tests/spec/forever_fixture_spec.lua` (busted).
