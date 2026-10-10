# ForeverDump converter (`tools/fdump.py`)

Python 3.8+ with only the standard library. Lua 5.1 and busted are needed only to *run* the generated mocks and specs.

```
python3 tools/fdump.py info  ForeverDump.lua                 # build, WOW_PROJECT_ID, scriptsDisallowedForBeta, sections present
python3 tools/fdump.py all   ForeverDump.lua -o out/          # json + luals + luacheck + mocks + secrets + v2.2 reports + drift
python3 tools/fdump.py inference ForeverDump.lua --file WoWCombatLog.txt -o out/inference   # HSM scores + offline replay
python3 tools/fdump.py guide ForeverDump.lua --file WoWCombatLog.txt -o out/guide           # SECRETS-GUIDE.html
python3 tools/fdump.py analyze ForeverDump.lua --file WoWCombatLog.txt --taint taint.log --label run5 \
    --history run4=OLD/ForeverDump.lua::OLD/WoWCombatLog.txt -o out/analysis [--write-seed]   # v2.2.4 whole pipeline
```
A complete pass over one capture (all reports, analyze with history, guide) is scripted in
`real/2026-10-08-run5/convert.sh` (about 80 s).
`DUMP` can be the SavedVariables file `WTF\Account\<ACCOUNT>\SavedVariables\ForeverDump.lua`, a `dump.json` written
by `json`, or the folder that contains it.

**Static data (v2.2.7; v2.2.11 only on request):** the static dump lives in its own SavedVariable `ForeverDumpStaticDB`, which is
written only by `/fdump static run` and kept in the file until `/fdump static clear`. The loader splices it back into the legacy layout. If a capture has none (normal after
`/fdump static clear`), the API/namespace/event views fall back to `fixtures/forever-70245`. `Dump.static_source` says
which one was used: `sv`, `sv-legacy` or `reference:forever-70245`.

**Safe parsing:** `fdump/luasv.py` is a small recursive-descent parser for the SavedVariables data subset (tables,
strings, numbers, booleans, nil). It never executes Lua, so a tampered SV file can't run code. Anything else is a
`LuaParseError`.

| Subcommand | Output |
|---|---|
| `json DUMP -o DIR` | `dump.json`, `meta.json`, `v1.json`, `sections/*.json`, `docs.json`, `strings.json`, `record/session_N.json`, `combatlog/session_N.json`, `errors.json` |
| `luals DUMP -o DIR` | LuaLS `---@meta` stubs: `Namespaces/C_*.lua`, `Globals.lua`, `Structures.lua`, `Enums.lua` (runtime values), `Constants.lua`, `Events.lua` (`ForeverEvent` alias with payloads), `Widgets.lua` (typed `RegisterEvent`, `CreateFrame` overloads), `Frames.lua`, `GlobalStrings.lua`, `.luarc.json.example`. Documented but missing functions are `---@deprecated` |
| `luacheck DUMP -o .luacheckrc [--std NAME]` | Self-contained config with `stds.forever` (read globals, namespace and Enum fields) and `std = "lua51+forever"` |
| `mocks DUMP -o DIR` | `wowmock.lua` (mock client from the dump: namespaces, Enum, widgets, secret values that error when touched, restricted-event tracking `wow.forbidden`), `forever_data.lua`, `replay.lua`, `fixtures/session_N.lua` (recorder), `fixtures/combatlog_N.lua`, `fixtures/probe.lua`, `spec/example_spec.lua`, `perf_guard.lua` + `spec/perf_spec.lua` (the PERFORMANCE.md rule as a test: flat per-event cost at 25/50/100 checkpoints, no idle OnUpdate, 2-minute cap), `run_spec.lua` (mini runner if busted is missing) |
| `check DUMP ADDON_DIR [--json F] [--strict]` | API checker: missing APIs, namespaces, Enums, widget types and methods, unknown events; notes for restricted or secret flags; exits 1 on errors |
| `diff OLD NEW [-o F.md] [--json F]` | Build-to-build diff: functions, signatures, events and payloads, enums, tables, constants, CVars (defaults), widgets, templates, global strings |
| `combatlog Logs/WoWCombatLog-*.txt -o F.lua\|F.json [--year Y] [--utc-offset H] [--shape cleu\|raw] [--limit N] [--subevents A,B] [--forever-player GUID]` | Replay fixtures from the client's combat log file. Handles advanced logging (v22: 19-field advanced block, extra raw amount), `COMBAT_LOG_VERSION` header, timezone in the timestamp. `--forever-player` also synthesizes Forever events (UNIT_COMBAT, UNIT_SPELLCAST_*, PLAYER_SWING, marked `synthetic`) |
| `cl-compare FIXTURE DUMP [--session N]` | Cross-checks a file fixture against a legacy `/fdump cl cleu-force` capture (arity and field differences) |
| `taint Logs/taint.log [-o F.json]` | Groups taint.log entries (blocked actions, tainted globals or executions, forbidden calls) by kind and addon, and classifies each line: `expected` (a ForeverDump probe touching a secret inside pcall: Controls ops matrix, Lab ops, CombatProbe/Containers/Tokens probes), `contained` (ForeverDump reading its own tables, e.g. Lab AddPoint, Core utcOffset), `probe-blocked` (a protected call made by a probe), `benign-chat` (v2.2.3: `ChatFrameN:UpdateFading` reading the timestamp of one of our chat lines; no secret, no blocked action), `blizzard-frame` (a Blizzard frame read a value we tainted) or `unexpected`. Blizzard mixin code running on our own hidden ScrollingMessageFrame (ops-matrix print sink) counts as `contained` |
| `errors DUMP [--json F]` | Lua errors (stack, locals) and ADDON_ACTION_BLOCKED/FORBIDDEN captured by the addon. 2.2.2 entries show `resolved` = the probe path that was running (`CombatProbe:CheckInteractDistance(party1)`); the learned `blockedPaths` are listed. 2.2.1 `UNKNOWN()` entries carry the run-3 analysis note |
| `containers DUMP [-o DIR] [--baseline F] [--write-baseline]` | Container schema (`CONTAINERS.md`, `containers.json`, `containers-schema.json`): every probed return walked recursively, with each field's state (absent/nil/secret/container/clear), the container flags (issecrettable, canaccesstable, hasanysecretvalues, HasSecretValues()), length/clear count and keys, per context × unit class. Includes the aura field matrix (ooc vs combat; player, self via other tokens, target NPC, party/raid, pet; unobserved cells labelled), aura counts, partial (mixed) containers and the diff against `fixtures/baselines/<build>/containers.json`. Pre-2.2.2 SVs are reconstructed from the combat-probe cells and UNIT_AURA events. Part of `all` and `guide` |
| `secrets DUMP -o DIR` | Secrets map: `secrets.json` + `SECRETS.md`. Every documented secrecy flag (SecretArguments, SecretReturns, SecretWhen*/SecretIn*, ConditionalSecret, NeverSecret, SecretReturnsForAspect, ...), per function/event/struct field classes (always / conditional / never / partial / observed), aspects, secret-related APIs, state and CVars, plus the addon's runtime observations |
| `verify DUMP -o DIR` | Reconciles docs with the verifier tallies: `verify.json` + `VERIFY.md`, each API/event/field position CONFIRMED / **CONTRADICTED** / UNOBSERVED / UNDOCUMENTED-SECRET with sample counts, contexts (`ooc\|combat\|enc / instanceType / self\|other`) and coverage %. LuaLS stubs, mocks and the `secret-op` check use the verified class when there is one and mark the rest `[unverified]` |
| `xref DUMP [--file WoWCombatLog.txt] [--player GUID] [--window-ms 750] [--year Y] -o DIR` | One ordered timeline from the addon event log, combat recorder sessions, errors/blocked, verifier contradictions and the file combat log: `timeline.jsonl` (each line: source, secret status, match quality) + `TIMELINE.md` (an excerpt per combat). Match qualities: `exact`, `time+amount`, `time+spell`, `time-only:secret-amount`, `time-only:amount-differs`, `unmatched` (e.g. UNIT_COMBAT to SWING_DAMAGE within N ms) |
| `migrate DUMP ADDON_DIR -o DIR` | **Legacy migration report** (`MIGRATION.md` + `migration.json`): every call site with status `ok` / `removed` / `renamed` / `signature-changed` / `now-secret` / `protected` / `deprecated-shim` / `replacement-missing`, the replacement, return-shape notes, examples and secrecy; events (`restricted-event`, `renamed-event`, `removed-event`); TOC Interface issues; taint-prone patterns (global overwrites, UIDropDownMenu, RegisterAllEvents, SetBackdrop, string PlaySound, unguarded secure attributes/layout); secret-value flow findings. Understands `local X = X` upvalue caching |
| `migrate-db BRANCH=Interface/AddOns ...` | Rebuilds `fdump/data/migration_shims.json` from the Blizzard_Deprecated* addons of one or more source trees (`forever=... live=...`). The curated table is `fdump/data/migration_curated.json` |
| `fixtures DUMP [--file LOG] [--taint LOG] [--max-lines N] -o DIR` | Raw fixture pack (api surface, environment, documented secrets map, combat/taint logs copied verbatim + replay fixture); v2.2.21: nothing is anonymized |
| `restrictions DUMP -o DIR` | Restriction flips per type with Activating→Active latency, context markers and flip-probe deltas: `restrictions.json` + `RESTRICTIONS.md` |
| `clientlog Logs/Client.log [DUMP] -o DIR` | Lua errors by call site (C-trampoline nil-calls flagged), warnings, inside/outside capture windows: `CLIENTLOG.md` |
| `perf DUMP -o DIR` | ForeverDump self-performance: `PERF.md` + `perf.json` from `ForeverDumpLogDB.perf` (v2.2.3 monitor: per-handler calls, total/mean/max ms, 15 s windows, heap/fps/C_AddOnProfiler samples, table sizes). Flags impact >= 1% of wall time, handlers whose cost **per call** grows with session length (last third > 2x first third) and tables still growing at the end. For older SVs it falls back to the FD_Logs profile snapshots (capture:on vs capture:off: application frame time, per-addon memory and counters). Part of `all` |
| `perfcheck ADDON_DIR [-o F.md] [--json F] [--strict]` | Static performance lint (PERFORMANCE.md rule): OnUpdate that runs every frame or never goes idle, `pairs(_G)` outside annotated cached/dump-only code, handlers reaching a `_G` walk or an expensive client API, `table.sort` / `table.remove(t, 1)` in handlers, string building in unthrottled OnUpdate, `RegisterAllEvents`, uncancelled tickers. Exits 1 on errors (and warnings with `--strict`). Suppress a justified case with `-- perf-ok: <reason>`. `migrate` includes it as a "Performance" section |
| `size DUMP` | SavedVariables size per section |
| `ops DUMP -o DIR` | "What you can do with a secret": `OPS.md` from the controls records |
| `lab DUMP -o DIR` | Workarounds lab: `LAB.md` (+ "Porting patterns for secret values") and `lab.json` (guide `--lab`) |
| `combat DUMP -o DIR [--inventory TSV]` | Combat probe set: `COMBAT-SECRETS.md` (item × unit class × context with documented class and mismatches, detectability tables, time left, ops per category, event payloads, absent APIs), `combat-matrix.json`, and `combat.json` (schema `foreverdump.combat/1`, guide `--combat`; detectability → `det.*`, token survey → `observations`) |
| `tokens DUMP -o DIR` | Unit token survey: `UNIT-TOKENS.md` (one glance per family: token works? identity secret when? values secret when?) + `tokens.json` |
| `knowledge DUMP -o DIR` | Spell knowledge per build: `KNOWLEDGE.md` + `knowledge.json` |
| `inference DUMP [--file WoWCombatLog.txt] [--player GUID\|NAME] -o DIR` | Scores the addon's inferences and HSM predictions against the file log (via the common timebase), and replays the log offline through `ForeverDump/Lib/HybridState.lua` in three modes: `clear` (everything readable), `secret` (only what Forever exposes in combat; knowledge learned online), `secret-pretrained` (same, with spell knowledge given up front as if cached out of combat). Writes `INFERENCE.md` (per rule × context: inputs readable, accuracy %, recall), `HSM.md` (aura presence %, duration error, amount-in-range %, cooldown timing error, failure cases: crit, miss/resist, refresh, pandemic, haste, removed early), `inference.json`, and `hsm.json` (schema `foreverdump.hsm/1`, guide `--hsm`; replay rows are prefixed `replay:`). The player defaults to the log owner (unit flags 0x511) |
| `drift OLD NEW -o DIR` | Build-to-build drift between two baselines, SVs or folders: `DRIFT.md` (summary table first: newly secret/clear, APIs/events added/removed, signatures, restriction timing, frame types, ops, lab, combat, tokens) + `drift.json`. `all` runs it automatically against the newest `fixtures/baselines/<build>/baseline.json` |
| `baseline DUMP [-o fixtures/baselines]` | Stores the baseline signature (docs hash, secrecy per position/context, present APIs, signatures, restriction timing, frame types, plus the addon's ops/lab/combat/tokens/knowledge parts) |
| `guide DUMP [--file WoWCombatLog.txt] -o DIR [--html F] [--analysis analysis.json]` | `--analysis` (default `<out>/../analysis/analysis.json` when present) adds section 12: drift rule, cooldown/GCD tracker, known-answer table, verification loop, tooltip cd-line evidence. Builds `containers.json`, `lab.json`, `combat.json`, `hsm.json`, `tokens.json`, `inference.json`, `verify.json` from the SV and runs `tools/guide/build_guide.py` → `SECRETS-GUIDE.html`. The generator has no `--tokens`/`--inference` flags, so tokens are folded into `--combat` observations and inference rules into `--hsm` rules (passed directly if a newer generator supports them) |
| `master-guide [--check] [--root DIR]` | v2.2.10 cumulative master secrets guide over **every** capture under `real/`: `docs/SECRETS-GUIDE.html` (colour-coded, for people), `docs/SECRETS-GUIDE.md` (same content, for AI) and `docs/secrets-guide-state.json` (state snapshot). Rows = value (health/healthMax/power, casts + spellID + castBarID, aura delivery/payload/details/counts, GUID/name, UNIT_COMBAT, UNIT_DIED, threat, range, cooldowns, damage meter, HSM attributions) × unit family (player, target, focus, party/raid, enemy players, NPCs, pets, nameplates); columns = readability ooc / PvE combat / PvP-BG, HSM status (live, cached, correlated-proven, provisional, estimated, unsolved, not measured), valid in combat, method, evidence (run + counts), next step. Inputs: each run's SV via `fdump/svinspect.py` (recorder ring per session, token matrix, probe cells, aura containers; codes/counts only, cached in `real/<run>/out/master/sv-inspect.json`), `out/analysis/analysis.json` rule accuracy, and curated FINDINGS claims that only count while their quoted sentence is still in that run's FINDINGS.md. "Changed since last run" diffs against the state rebuilt without the newest run. Run it after converting every new capture; `--check` (and `tests/test_master_guide.py` in the runner) fails when the guide is stale or older than the run data. No player names or raw GUIDs (the build refuses to write them) |
| `coverage DUMP --file WoWCombatLog.txt -o DIR` | v2.2.4 combat-event coverage: the log (truth, offline) vs what the addon read live, per category × source × context; HSM replay before/after scored against the log (accuracy, falseSelf); UNIT_COMBAT timing models; per-fight log vs C_DamageMeter; the other player on my target; meter field classification; cooldown/GCD tracker vs the log, cooldown model vs log fails, enemy cast bars, overheal, Ledger (claims vs "maybe-removed" doubts), live verdicts. `COVERAGE.md`, `coverage.json`, `coverage-guide.json` (guide `--coverage`) |
| `verify-live DUMP --file WoWCombatLog.txt -o DIR` | v2.2.4 verify ring (or the replay's verdicts for older SVs) joined with the log: confirmed / refuted / missed per verdict kind, unexpected readability flips, and a knowledge patch of facts observed in reality (`VERIFY.md`, `verify.json`, `knowledge-patch.json`, `KnowledgePatch.lua`) |
| `correlate DUMP --file LOG [--with LABEL=SV::LOG ...] [--min-support N] [--quick] [--no-higher] -o DIR` | v2.2.4/v2.2.5 co-occurrence miner + higher-order chains (A→B→C, identity, elimination, sequences). 1-hop at 50/150/300/750 ms; HO adds 1.5 s windows, depth ≤4 (full) / ≤3 (quick), holdout, proposed HSM rules (review only). Prints elapsed. Player names redacted. `CORRELATE.md` + `correlate.json` |
| `analyze DUMP --file LOG [--taint F] [--history LABEL=SV::LOG ...] [--label L] [--write-seed] [--write-patch F] -o DIR` | v2.2.4 whole offline pipeline: coverage + HSM replay, knowledge lint (incl. the tooltip extra-line cooldown evidence), verify join, miss explainer (every missed log event with a reason class and a fix hint), miner, rule-accuracy trending over the history captures, secrecy flips vs the baseline, taint classes, spell-timing seed merge with the known-answer table (totems 1.0 s, Lightning Shield 1.5 s), learned-DB merge, token matrix. Writes `ANALYSIS.md` (ranked leads: severity, evidence, timestamps, fix), `analysis.json` (guide `--analysis`), `VERIFY.md`, `TOKENS.md`, `knowledge-patch.json`, `spell-timing.proposed.json`, `learned-seed.proposed.json`. `--write-seed` adopts the merged seeds into `ForeverDump/Data/spell-timing.lua` + `learned-seed.lua` (+ JSON mirrors): idempotent per evidence id, conflicts stay flagged and are never overwritten (drift rule) |
| `ketho DUMP [--ref DIR] [--branch forever]` | Optional: compares against Ketho/BlizzardInterfaceResources GlobalAPI/CVars (downloads from GitHub unless `--ref` is given) |

## Replay (busted)
```lua
local wow = dofile("out/mocks/wowmock.lua"); package.loaded.wowmock = wow
local Replay = dofile("out/mocks/replay.lua")
wow.install()                                         -- globals from the dump
local s = Replay.load("out/mocks/fixtures/combatlog_1.lua")
local stats = Replay.run(s, { frame = myFrame })     -- Forever events; captured C_CombatText getter returns are stubbed
Replay.run(fileFixture, { frame = f, cleu = false }) -- only Forever/synthetic events
Replay.run(fileFixture, { frame = f, forever = false }) -- only legacy CLEU (CombatLogGetCurrentEventInfo stubbed)
```
`<secret>` values come back as secret objects. Arithmetic, comparison or concatenation on them raises an error,
just as on the client, and `wow.secretTouches` counts any such touch. `issecretvalue()` works on them.

## Migration workflow (old addon -> Forever)
```
python3 tools/fdump.py migrate ForeverDump.lua path/to/OldAddon -o out/migrate-OldAddon
python3 tools/fdump.py check   ForeverDump.lua path/to/OldAddon           # after porting: missing APIs / secret ops
```
The mapping DB has 109 curated entries (old global -> C_ replacement with return-shape notes and an example) and 373
entries parsed from the Blizzard_Deprecated* shims (forever + live branches). Shims load only while the CVar
`loadDeprecationFallbacks` is 1, so `deprecated-shim` means "works today, may vanish". Present/missing comes from your dump.
`replacement-missing` means the shim maps to an API that this client doesn't have (e.g. `CombatLogGetNumEntries` ->
`C_CombatLog.GetEntryCount`).

## Which player? (no flags needed)
ForeverDump >= 2.2.1 writes the player's identity (name "First Last", realm, GUID, class, level, each with a secrecy code) to
the SV meta at every capture. `inference`, `guide`, `xref`, `cl-compare` and `combatlog --forever-player auto` use it to pick the
combat log owner by GUID, then by name (the log writes only `First-Realm-Region`). Without a matching SV they use the optional
`tools/fdump/characters.json` (display name, combat-log name, realm, GUID; override the path with `FDUMP_CHARACTERS`), then the
most frequent source with unit flags 0x511. `--player` / `--forever-player` accept a GUID, "First Last", a first name or
Name-Realm. v2.2.21: nothing is scrubbed anywhere (fixtures, packages, guides); identities are stored raw.

## Guide (`tools/guide/`)
`build_guide.py` + `guide_data.py` (curated text with confidence markup) build the single-file `SECRETS-GUIDE.html`; input
schemas are in `tools/guide/README.md`. `fdump.py guide` is the normal entry point. The synthetic `samples/` of the guide
worker are deliberately not included; never build a shipped guide from made-up data. `hsm-panel-mock.html` is a static
mock of the in-game HSM window for documentation.

## Caveats
- The combat log parser (v22) was checked against one real Forever 70245 log (1029 lines, advanced logging).
  `tests/fixtures/` is synthetic; `fixtures/forever-70245/` is the raw real capture.
- `migrate` is lexical (no full Lua parser): dynamic calls (`_G[name]`, method tables) are not resolved, and secret-flow
  findings follow simple local assignments. Treat the report as a checklist, then run the addon in the mocks.
- Forever events synthesized from a file log are approximations; the real client may fire them differently.
- Offline HSM scoring: summons are judged by SPELL_SUMMON (presence; lifetime only if the log has an end event; Forever 70245 logs no UNIT_DESTROYED for totems), dispels by SPELL_DISPEL/_FAILED/STOLEN. A cooldown is judged only when a recast falls within predicted end + max(10 s, cd), otherwise it counts as `noRecastInWindow`. Replay ignores recast gaps over 180 s (session breaks).
- The HSM replay knows only the log owner's casts/auras; on Forever `UNIT_AURA` exists only for unit tokens, so replay numbers
  are an upper bound for other units. A cooldown learned from recast gaps is an upper bound; the addon's knowledge
  (`GetSpellBaseCooldown`) is the real source.
- `ketho` and the self-hosting refresh scripts in `tools/refresh/` (separate docs: `SELF-HOSTING.md`) need network
  access. The refresh scripts' `.cache/` and the extracted `data/` folder are **not in the zip** (≈1 GB); re-create
  them with `tools/refresh/refresh_all.sh`.

## Performance requirements
The rule in `PERFORMANCE.md` applies to the addon, to generated code and to ported addons:

- no measurable framerate impact (under 1%)
- no idle OnUpdate
- O(1) cost per event
- redraws only when something changed, throttled and only while visible
- heavy work out of combat or offline

How the tools carry it:

- `perfcheck` (static) and `tests/perf_bench.lua` (runtime) are part of the default test runner, so a build fails when the
  rule is broken.
- `migrate` writes a Performance section into MIGRATION.md.
- `mocks` ships `perf_guard.lua` and `spec/perf_spec.lua` for the ported code.
- Every perf test run must finish within **2 minutes** of wall time. perf_bench uses checkpoints at 25/50/75/100 casts plus
  five aged windows and a SPELL_UPDATE_COOLDOWN storm, and a hard `--cap` (100 s) that aborts and prints the trend measured so
  far. v2.2.4 gate asserts: aged/fresh ratio <= 1.5, storm <= 0.5%, scanner slice max <= budget (PERFORMANCE.md "Perf gate").

```
lua5.1 tests/perf_bench.lua ForeverDump --assert [--keys] [--json F]   # ~2 s; per-event/per-frame cost, impact %, idle OnUpdates
lua5.1 tests/perf_bench.lua OLD/ForeverDump --marks 1,2,4,8,16 --win 1 --cap 75   # timeboxed comparison of an older build
```

## Tests
`bash tests/run_converter_tests.sh` (v2.2.11: through `tests/runner.py`, parallel, ~1 min; `--serial` for one at a time; the serial list is `tests/run_converter_tests_serial.sh`) runs luac, luacheck, the addon smoke test in the mock client (driven by the real
Forever API docs; set `FORE_DOCS` to an `Interface/AddOns` tree with `Blizzard_APIDocumentationGenerated`), and
the converter end-to-end checks, including busted (example spec, replay spec, raw fixture spec), the
BugGrabber coexistence test (`tests/buggrabber.lua`), `tests/test_xref.py` and `tests/test_migrate.py` (deliberate legacy
addon `tests/legacy_addon/` plus the raw fixture pack), `tests/regress.lua` (bug B before/after, restrictions, classifier,
forced sweep, macro lengths), `tests/hsm.lua` (HSM library, probes, tokens, knowledge, inference, HSM window, baseline) and
`tests/test_v22.py` (guide JSON schemas, reports, drift, Barrens replay, guide build, Lua/Python hash parity, /run length
audit), `tests/test_v222.py`, `tests/test_v223.py` (perf lint, PERF.md, migrate/mocks perf checks, taint reclassification),
v2.2.4: `tests/knowledge_parse.lua`, `tests/timing.lua`, `tests/learned.lua`, `tests/test_v224.py`, `tests/test_v224_tools.py`
(timing / learned / tokenscan / analyze leads / correlate / verify_live / misses / knowlint, synthetic) and
`tests/test_v225_ho.py` (synthetic higher-order), `tests/test_golden_run5.py` (real run 5: the miner rediscovers the Earth Shock interrupt link, ≥1 2-hop interrupt chain, the known-answer GCD table
holds; skipped when `real/` is absent), and the performance gate: `fdump.py perfcheck ForeverDump --strict` and `tests/perf_bench.lua ForeverDump --assert` (2-minute cap).
The runner uses `set -o pipefail`, so any failing step fails the run. The docs tree (`ref/`) is not in the zip.

## v2.2.6 sealed replay

```bash
python3 tools/fdump.py replay path/to/ForeverDump.lua -o out/replay --file Logs/WoWCombatLog.txt
```

Reads `ForeverDumpLogDB.replay` (session_hdr + tape). Writes `REPLAY.md` + `replay.json`: decide determinism, privacy scan, optional CLEU cast-sync anchor join. In game: default **release**; FD_Logs elevates to **test**/diag then restores; `/fdump level` overrides.

**Packed SavedVariables (v2.2.11):** the addon packs large SavedVariables at logout (`ForeverDump/SVPack.lua`) so the file
stays under Lua 5.1's 262,143-constant limit. `luasv.parse_savedvariables` decodes packed vars transparently
(`tools/fdump/svpack.py`; `unpack=False` returns the packed form), so every tool reads old and new files the same way.
`python3 tools/fdump/svconst.py FILE [depth]` counts a file's distinct Lua constants (exact vs `luac5.1 -l`) per subtree.
