# Run 16 findings (v2.2.21 capture → v2.2.22 fix)

- Fresh cap-20261009225225-51, 0 hashed IdKeys, INCLUDED.
- Scoreboard census exact vs log; GUID-joined class 15/15 correct, 0 false.
- bfJoin still 0 (scoreboard keys ≠ plate keys).
- Name-key collision Johnny: cache:raidN SHAMAN vs ENERGY → fixed in v2.2.22 (Allow revokes non-ASSIGNING class).
- Secret compare path closed (ForceTaint_Strong).
- Prefill enemy class 0/236 live; offline episode class 95.8%.
- Perf lab 2.11%; meter max 7.97 ms.
