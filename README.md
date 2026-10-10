# ForeverDump + WoW Forever addon work - complete handoff

Everything from the Grok Bot box needed to continue the ForeverDump project (and the related KTH port and idTip
patch) in Grok Build: addon sources, Python/Lua tooling, the full test suite with perf gates, docs, every historical
capture (runs 1-22, BG/dungeon/open world combat logs + SavedVariables), reference data (Blizzard UI source, API docs,
DB2), every shipped build, git histories, the agent's rules and memory.

Start here:
1. **HANDOFF.md** - rules, current state, findings, open work, lessons (authoritative).
2. **AGENTS.md** (= GROK.md) - setup, tests, lint, build, analysis commands for Grok Build.
3. **MEMORY.md** - standing preferences and dated facts.
4. docs/RUNS.md (captures), docs/REFERENCES.md (Blizzard source origins), docs/INVENTORY.md (what came from where).

## Parts (zips under /workspace/handoff on the box)
| zip | contents | git? |
|---|---|---|
| `foreverdump-handoff-part1-core.zip` | code, addons, tools, tests, docs, reference data, fixtures, builds, memory, bundles | yes |
| `foreverdump-handoff-part2-captures.zip` | `foreverdump/real/` (all runs) + `captures/` (all user uploads) | yes (plain git or LFS) |
| `foreverdump-handoff-part3-cdncache-optional.zip` | `foreverdump/tools/refresh/.cache` CDN/CASC work cache (regenerable) | no (.gitignore; files > 100 MB) |
| `foreverdump-handoff-part4-keyhunt-optional.zip` | `other/wow-forever-keyhunt` (unrelated beta-key poller research) | partly (4 metric logs > 100 MB are ignored) |
Unzip all parts into the same folder; they share the root `foreverdump-handoff/`. Then:
```
cd foreverdump-handoff
python3 handoff-tools/verify_manifest.py        # sha256 of every file of the parts present
bash handoff-tools/setup.sh                      # tools, mtimes, WoW-like lua5.1, h32
cd foreverdump && bash tests/run_converter_tests.sh
```
Push to GitHub: `handoff-tools/git_push.sh <remote-url>` (batched pushes; `--lfs` optional). Largest file committed
without LFS: 75.8 MB (run 9 SV); GitHub rejects > 100 MB, warns > 50 MB.
