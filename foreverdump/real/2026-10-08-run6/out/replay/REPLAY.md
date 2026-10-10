# ForeverDump sealed replay tape

Sessions: **1**; records: **1814**; privacy hits: **0**; decide conflicts: **0**; vacuous (no decide records with combat on tape): **1**.

## Session 1 (test → test)
- addon 2.2.6 schema 3; group solo/1; bytes≈92028; overwritten=0 overflow=0
- kinds: dm=121, hdr=1, sec=253, ws=1439
- decide determinism: VACUOUS (combat on tape, 0 decide records: the live HSM did not run) (0 groups, 0 conflicts)

## Notes
- Default in-game level is **release** (<1% CPU). FD_Logs elevates to **test** (or configured captureLevel) ≤10%, then restores.
- `/fdump level` overrides between captures. One zip ships both modes.
