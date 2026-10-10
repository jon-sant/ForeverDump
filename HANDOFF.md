# HANDOFF: ForeverDump + WoW Forever addon work (authoritative)

Written 2026-10-10 (ET) at the move from the Grok Bot box to a GitHub repo + Grok Build.
Owner: Richerynte. Game: **World of Warcraft "Forever"** (classic-era ruleset on the modern client, the "secret values"
API, product `wow_classic_beta`, client 1.60.1, current build **70338**). Character: a shaman (enhancement), mostly BGs.
If anything here disagrees with an older doc in the tree, **this file wins**; older docs are history.

Contents: 1 rules · 2 current state · 3 findings · 4 runs/captures · 5 open work · 6 lessons · 7 where things are ·
8 how to work (commands) · 9 what was excluded.

---------------------------------------------------------------------------------------------------------------------

## 1. Standing rules and preferences (follow all of them)

### Data and privacy
- **RAW DATA, NEVER SCRUB OR HASH.** Privacy scrubbing/hashing was **reversed on 2026-10-09** (ForeverDump v2.2.20/
  v2.2.21+). Captures, fixtures, reports and the repo keep real names, GUIDs, realms and values verbatim.
  History: v2.2.x before 2.2.21 stored salted `IdKey`s (`kind:%08x` = hash32(salt|id)); `tools/fdump.py unhash`
  recovered them into `real/<run>/sv_raw/` (originals untouched). Do not reintroduce any IdKey / redaction path.
  (Some tool help text, e.g. `correlate` "player names redacted" or `master-guide` "no player names", predates the
  reversal; it is legacy wording, not a rule. Do not add new redaction.)
- **100 %-raw inclusion rule (HARD RULE 2026-10-09 21:30 ET):** a historical run is used for scoring / master guide /
  fixtures / replay only if it had no hashing or 100 % of its IdKeys were restored. Below 100 % the run is
  **EXCLUDED** (files stay on disk). Manifest: `foreverdump/tools/fdump/data/unhash-inclusion.json`; gate:
  `tests/test_unhash_inclusion.py`. Excluded: run8 (83.9 %), run9 (93.9 %), run14 (98.2 %), run15 (87.1 %, also
  log-only). The combat logs of those runs are the client's own file (never hashed by ForeverDump) and are still
  in the repo for log-only backtests; mark any use of them as such.
- Only real data in shipped tests/replays (KTH forever.4 rule): no placeholder names; synthetic fixtures must be
  labelled SYNTHETIC.

### Runtime design rules (addon)
- **No combat log at runtime.** The addon never registers/reads `COMBAT_LOG_EVENT_UNFILTERED` (forbidden on Forever
  and triggers Blizzard's popup). The combat log file (`WoWCombatLog.txt`) is **offline ground truth only**.
- **Derive secrets through alternate APIs.** Never stop at "unsolvable" (user correction 2026-10-09 17:55 ET): look
  for side channels, higher-order inference, timing, other tokens, out-of-combat caches (e.g. the GetTotemInfo icon
  side channel, scoreboard joins, frame-joins).
- **Correlate at every roadblock.** When something looks impossible or ambiguous, run the correlation miner
  (`fdump.py correlate` / `analyze`, higher-order chains) across all included runs before concluding.
- **Never operate on a secret value** (no arithmetic/compare/truth test/format). Classify first
  (`issecretvalue`/`canaccessvalue`/`type()`), `pcall` index reads; lint `tests/test_v227_secret_lint.py` enforces.
- **No static ID lists / learned library instead.** Aura candidates come only from learned data: OOC reads,
  own-cast->aura pairs, the per-build spellbook cache, `refLearned[build].auraDur`, `knowledge[build]`, carry-over from
  the previous build (provisional), and the generated library `ForeverDump/Data/LearnedAuras.lua` (built from every
  stored combat log by `fdump.py learned-auras`, never hand-edited, test fails when stale). Remaining seed tables are
  listed with proposals in `foreverdump/docs/STATIC-LISTS.md`. Ranks: one entry per ability, all ranks checked.
- **Cache reference data per client build** (static dump `ForeverDumpStaticDB`, spellCache, spellLevel, learned
  stores are keyed by build; a new build starts from carry-over, never from nothing; empty list at capture start = warning).
- **No "accurate but fewer" trade-offs** (v2.2.29): never drop candidates/ranks/units to hit a budget; time-slice instead.
- **Performance:** release level (no capture) **≤ 2 %** of wall time (user decision 2026-10-08; was 1 %); capture
  (FD_Logs -> diag/test) **≤ 10 %** dev budget; `lab` level is measured and reported, not gated (250 ms runaway
  backstop). No idle OnUpdate, O(1) per event, dirty-only throttled redraws, heavy work OOC/offline, budgets are
  drift-guarded data. Every perf test finishes within 2 minutes. Diag collection is not artificially capped (backstops
  only). Full rule: `foreverdump/PERFORMANCE.md`.
- **Never write into Blizzard chat frames** (v2.2.14: any addon line there breaks Blizzard's chat in BGs). Own frame only.
- **`/run` macros must stay under 255 characters** (macro length audit in `tests/test_v22.py`/`regress.lua`).
- **One zip per release**, default verbosity release; FD_Logs elevates then restores; `/fdump level` override.
- **Static dump only on request** (`/fdump static run`, v2.2.11); FD_Logs ON wipes previous capture data but keeps
  learned + static.
- **Multi-environment:** everything must work and be measured in open world, dungeons and BGs (and arena where
  possible); never assume a context's behaviour from another (measure restriction state directly).
- Addon install path: `World of Warcraft\_classic_beta_\Interface\AddOns\` (Forever runs from `_classic_beta_`).
  TOC Interface 16001.

### Engineering process rules
- **Never loosen checks; no regressions.** A failing test is fixed at the cause, never by relaxing the assertion,
  raising a threshold, skipping, or deleting the test. New behaviour gets a test. Rescore old runs after changes and
  require identical or better results.
- Run the **whole runner** before packaging, and again under a foreign TZ (`TZ=UTC`), 0 FAIL. Quote the runner's own
  count line. Run runners sequentially, not two at once (load-induced flake in test_v2211_svpack).
- Time handling: every conversion is tested across 7 zones (UTC-10 .. UTC+14) and DST; reports in ET with a label.
- Package with `tools/package.py`; fresh-unzip check of the zip (toc files syntax OK + relevant tests on the unzipped addon).
- Analyze every new capture fully: errors, versions, perf, new probes, then rescore + master guide regenerate.
- Healer rule (KTH, forever.5): healer verdict = healing output (heals on others ≥ 30 % of output and ≥ 5 direct
  heals in the truth; live verdict from healing-output evidence), not class/power heuristics.

### Communication preferences (user)
- Status update about every **5 minutes** during long work; append a timestamped line with a **lesson** to
  `foreverdump/PROGRESS.md` (and `kth/PROGRESS.md` for KTH).
- Lead with the answer; plain language; evidence with counts; admit and correct mistakes explicitly.
- Ask before assuming scope changes; the user steers often ("STEERING" lines in PROGRESS.md are decisions).

---------------------------------------------------------------------------------------------------------------------

## 2. Current state (2026-10-10 ~15:30 ET)

| item | state |
|---|---|
| ForeverDump | **v2.2.29** packaged (`foreverdump/ForeverDump-v2.2.29.zip`, 292 files, sha256 2648b4ee…34e4), **not yet run in game** |
| last in-game build | v2.2.27 (run 22, BG) on client 1.60.1.**70338** |
| test runner | 126 tests, 0 FAIL at packaging; **re-verified on this handoff**: fresh unzip of core+captures with `/workspace` hidden (bwrap tmpfs): `RUNNER OK: 126 test(s), 0 failed` (local TZ and `TZ=UTC`), luacheck 0 warnings / 0 errors in 107 files, `master-guide --check` OK, KTH R1-R8 ok, run-22 sample analysis (`info`, `errors`, `perf`, `totemscore`) reproduces REPORT.md numbers (empty 5076/5076, totem S 2480) |
| secrets guide | `foreverdump/docs/SECRETS-GUIDE.{html,md}` + `secrets-guide-state.json`, regenerated over 19 included runs (run22 newest) |
| HSM (Hybrid State Machine) | `foreverdump/docs/HSM-STATUS.md` (rules, accuracy per rule, inclusion table §10) |
| Learned library | `ForeverDump/Data/LearnedAuras.lua`: 582 auras (per-build confirmations 70245/70291/70334/70338), 378 cast->aura pairs, from 19 usable logs |
| KTH (Kill the Healer Forever port) | parked at **forever.12** (`kth/`, releases in `kth/releases/`), regress R1-R8 green |
| idTip Forever patch | `idtip-wowforever/` (small fork of silverwind/idTip, done) |

v2.2.29 key design: aura-presence probe is a per-unit job queue drained in OnUpdate under 5 % frame share
(0.2-1.5 ms/frame), tiers H (every visit) / W (every 3rd) / C (every 10th), sticky-present, rank plausibility via
`C_Spell.GetSpellLevelLearned` collected live, budget-adaptive unit rotation, backstop limit only. Simulated
(`tools/fdump/measure_sched.lua`, runs 19-22): 582/582 candidates, 100 % coverage, worst frame 0.98 ms, 2.85 % wall,
longest gap 17.9 s. These are simulation numbers; the next BG measures real per-check cost.

## 3. Key findings (measured; details in docs/SECRETS-GUIDE.md, docs/FINDINGS-v226.md, real/*/out/)
- **Auras are hidden in all measured combat**: BG (runs 19, 22), dungeon (run 20, Ragefire), open world (run 21,
  Thousand Needles: 10,965/10,965 in-combat checks empty for player and target). Out of combat fully readable
  (run 21: 220/221 agree with the log). In combat an empty answer = **unknown**, never absent.
- Restriction state must be measured, not inferred from location (dungeon OOC had a Map restriction flag yet auras were clear).
  The Combat restriction (type 0) flips at PLAYER_REGEN_DISABLED before InCombatLockdown is true.
- **Health/power (UnitHealth/UnitPower) are secret everywhere** for every unit, including the player OOC and
  non-existent tokens, on builds 70291/70334/70338. Not PvP/restriction driven. Lesson: test `player` and a fake token
  before blaming a unit type.
- **Totem side channel**: GetTotemInfo icon is N for an empty slot and S for a live totem in BGs: empty 5076/5076,
  live 89-93 %, 0 false positives (`tools/fdump/totemscore.py`).
- Own casts: own spell IDs stay clear in combat; damage/heal amounts and miss/immune types readable;
  **enemy/nameplate spell IDs are secret**; interrupts fire but the interrupted spell is secret.
- Own spellbook + descriptions are readable in BG prep and combat (cold-start spell cache can build there).
- Derivation from own casts: start right 36/48, end within 1.5 s only 7/34 (charges, dispels) -> derived = estimate (D).
- Scoreboard: GetScoreInfo/GetBattlefieldScore readable (name/class/faction clear; talentSpec/role/guid/healing
  secret until post). Names on the board are "First Surname"; UnitName gives "First" + realm = surname ->
  exact join by name+realm (KTH D5b). arenaN tokens are used for friends too in BGs (split by hostility).
- Combat log writes the aura row ~2 ms **before** its cast row (pairing must look back).
- Grounding Totem eats are invisible even in the combat log.

## 4. Runs / captures (all raw, all in `foreverdump/real/`)
See `docs/RUNS.md` for the full table (dir, type, addon version, build, inclusion, files). Summary: runs 1-22 incl.
6b; 1-7 open world (70245/70291), 8-19 and 22 BGs, 20 dungeon (Ragefire Chasm), 21 open world (Thousand Needles).
Excluded from analysis (hashed, <100 % restored): 8, 9, 14, 15. Every user upload (154 files) is also kept verbatim in
`captures/user-uploads/` with `captures/UPLOADS-INDEX.tsv` mapping each to where it lives in `real/`.

## 5. Open work (priority order)
1. **Next in-game capture on v2.2.29** (BG preferred, plus OOC pass first): verify real per-check cost (`auraPresence.sched`
   costMs/maxMs/maxGap/worst), staleness per tier/family vs the sim, whether `GetSpellLevelLearned` answers for other
   classes' spells, cold-start (no `/fdump static run`) has candidates from tick 1, the empty-list warning, totem
   per-slot tracking, health-context records (PvP flag), errors 0, perf ≤ 10 % capture. Then rescore runs 19-22+ and
   regenerate the master guide + LearnedAuras library.
2. `docs/STATIC-LISTS.md` proposals: replace RefData spells/summons/classLevelHP, learned-seed, spell-timing seed,
   SelfLinkSeed, KnowledgePatch (70245-only), probe item/spell/quest args, DV.PREP_AURAS, timing.py TOTEMS with learned data.
3. DST label gap: after the Nov 1 fall-back, report clock labels keep "EDT" for the rest of a capture spanning it
   (times correct). Fix the label.
4. Derived (D) auras end early (charges/dispels): model charge consumption from own events; keep labelled estimates.
5. Health/power secret everywhere: find alternate channels (UNIT_COMBAT amounts, meter, nameplate bars) - correlate.
6. KTH: parked at forever.12; resume only on user request (see `kth/PROGRESS.md`, `kth/FOREVER-PORT.diff`).
7. `master-guide --check` reports STALE once right after the SV-inspect caches are invalidated by changed SV mtimes
   (e.g. a git clone without `restore_mtimes.py`); the next check is OK and regenerating gives byte-identical docs.
   Find why the cache-rebuild pass differs from the cached pass (do not weaken the check).
8. Library efficiency: growth per capture is automatic; keep rank/tier scheme honest as the library grows (backstop warning).
User procedure for a capture: `foreverdump/ADDON-USAGE.md` (install, `/fdump static run` once per build optional,
FD_Logs macro start/stop, `/fdump errors show` before stop, send `WTF/.../SavedVariables/ForeverDump.lua` + `Logs/WoWCombatLog.txt`).

## 6. Lessons learned (selected; full timestamped list in foreverdump/PROGRESS.md and kth/PROGRESS.md)
- Run the whole runner under a foreign TZ; fixture-level TZ tests missed a zone-dependent test.
- A rescore without the player GUID silently yields 0 events and looks like a regression; always pass it.
- Grep for existing learners before adding a new store (v2.2.27 ignored two stores that had the data).
- Dynamic lists have a cold-start hole; close it with carry-over + automatic caches + warnings, not seed lists.
- Old tests silently depended on removed lists / newly shipped data files: isolate data per test.
- With frequency tiers, unit rotation dominates staleness; budget the rotation too.
- `#t` on a table with holes returns an early border: never `t[i] = nil` inside an array queue.
- Per-handler perf windows already in the SVs answer budget questions without new probes.
- Measure restriction state; check `player` and a fake token before attributing a secret to a unit type.
- luacheck flags `not (x > 0)` NaN guards; write `x ~= x or x <= 0`.
- Two runners in parallel cause flakes; run sequentially. Quote the runner's own count line.
- (handoff) Hardcoded `/workspace/...` paths were in 42 KTH/FD tool and test files; now resolved via `WOWDEV_ROOT` or
  the nearest parent holding `foreverdump/` (see AGENTS.md). Generated files must not embed absolute paths when a
  provenance test compares bytes (KTH R8: `.dm.lua` headers are now root-relative).
- (handoff) git clone resets mtimes; the master-guide staleness check and the SV-inspect cache use mtimes ->
  `handoff-tools/restore_mtimes.py` right after cloning.

## 7. Where things are (repo map)
```
README.md  HANDOFF.md (this)  AGENTS.md / GROK.md (agent instructions)  MEMORY.md (agent memory export)
docs/RUNS.md  docs/REFERENCES.md (Blizzard UI source + data origins)  docs/INVENTORY.md (what came from where)
foreverdump/            the ForeverDump project (addon ForeverDump/, tools/, tests/, docs/, data/, ref/, fixtures/,
                        real/ = all captures, ForeverDump-v*.zip = every shipped build, PROGRESS.md, CHANGES.md, ...)
kth/                    Kill the Healer Forever port (original/, baseline/, port/, tests/, tools/, releases/*.zip)
foreverdump-research/   early secrets research: API secrecy inventory (70245), guide prototype, upstream source snapshots
idtip-wowforever/       idTip Forever patch (+ forever-addon-kit)
captures/user-uploads/  every file the user uploaded (sha256 names) + captures/UPLOADS-INDEX.tsv
workspace-root/         older top-level copies of HSM-STATUS / SECRETS-GUIDE (Oct 9 20:40) kept for history
_git-bundles/           git history of nested repos (INDEX.tsv: path, remote, branch, HEAD); restore with handoff-tools/restore_git_bundles.sh
other/wow-forever-keyhunt/  unrelated-but-WoW: Forever beta-key giveaway poller research (Sept); not needed for the addon
handoff-tools/          setup.sh, verify_manifest.py, make_manifest.py, restore_git_bundles.sh, fetch_reference.sh, git_push.sh
MANIFEST.tsv            every file: part, size, sha256
```

## 8. How to work - see AGENTS.md (setup, test runner, lint, build/package, analyze a run, guide, library).

## 9. Excluded from the handoff (and why)
- `foreverdump/.cache/svcache/` (2.3 GB): pickled SV-unpack cache, regenerated automatically (`FD_SVCACHE=0` disables).
- `foreverdump/tests/out/` (326 MB): generated by the runner. Kept: `tests/out/runner/timing.json` (per-test times the runner uses for longest-first ordering).
- `.cache/wowlua/{bin,path,lua-5.1.5}`: built by `tests/build_wowlua.sh` from the shipped, sha256-pinned `lua-5.1.5.tar.gz`.
- `__pycache__`, `.venv` (research guide venv: only html5lib/six/webencodings, see requirements).
- Nested `.git` directories: replaced by `_git-bundles/*.bundle` (full history) so the outer repo can hold the files.
- Optional parts (not for git, see README): `foreverdump/tools/refresh/.cache` (912 MB CDN/CASC work cache for
  `extract_*_cdn.sh`, regenerable, has files >100 MB) and the keyhunt metric logs (>100 MB each).
