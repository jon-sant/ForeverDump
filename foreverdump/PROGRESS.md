# ForeverDump v2.2.4 progress log (times ET)

- 02:10 Perf gate passed (aged/fresh 1.00-1.18, storm 0.29-0.39%, raid slice <= 0.115 ms of 0.12). Runner green.
- 02:30 Started the final v2.2.4 items: analyze --write-seed + TOKENS.md, Python tests, coverage/guide sections, docs,
  FINDINGS, full run-5 converter, guide, runner + perf gate, zip, scrubber.
- 02:42 `fdump analyze` now merges spell-timing + learned evidence (all captures, idempotent per capture id), writes
  TOKENS.md, *.proposed.json seeds, `--write-seed` adopts them. Run 3-5: known answers all OK, seeds unchanged (idempotent).
  `fdump tokens` also writes TOKENS.md + tokenscan.json.
- 02:55 New Python tests: tests/test_v224_tools.py (41 synthetic checks: timing merge/promotion/conflict/idempotent/known
  answers/Lua, learned from_log/from_sv/merge/anonymize, TOKENS.md, analyze leads) and tests/test_golden_run5.py (20 checks on
  the real run 5: miner rediscovers the Earth Shock interrupt link, known-answer GCD table, verify/misses/knowlint, seeds
  idempotent). Both added to the runner.
- 02:39 Python tests extended (test_v224_tools.py now 64 checks: + correlate/verify_live/misses/knowlint synthetic).
  coverage.py gained COVERAGE.md + guide JSON sections: cooldown/GCD tracker, cooldown model vs log fails, enemy cast bars,
  overheal, Ledger, live verdicts. Fixed a scoring bug: Ledger 'maybe-removed' doubts were counted as wrong claims (35);
  they are doubts, and the log confirms 35 of 50 removals. Next: guide sections, docs, FINDINGS.
- 02:45 Full converter pass on run 5 done (real/2026-10-08-run5/convert.sh, 1 min 19 s); guide has a new section 12
  "Cooldown/GCD tracker, learned data and the drift rule" (drift rule, tracker, known-answer table, verification, cd-line
  evidence). Found + fixed a privacy gap: miner keys carried target names from UNIT_SPELLCAST_SENT (incl. a player name) into
  ANALYSIS.md/analysis.json (not in the zip). Player names are now redacted to <player>; analysis.json keeps miner rows per capture.
- 02:48 Docs: CHANGES.md has the full v2.2.4 entry (addon / converter / tests / perf gate); ADDON-USAGE.md has a
  v2.2.4 section (attribution, Ledger, cooldown/GCD tracker, learned DB, drift rule, verify ring, scanner, tooltip
  hypothesis off). Next: README, tools/README, PERFORMANCE drift rule, FINDINGS, then tests + perf gate + zip.
- 02:48 README (v2.2.4 bundle; status: v2.2.3 ran in run 5, v2.2.4 not yet in game), tools/README (coverage /
  verify-live / correlate / analyze --write-seed / guide --analysis / new tests), PERFORMANCE.md rule 6 (drift-guarded
  budgets) done. Writing FINDINGS next.
- 02:51 FINDINGS written: real/2026-10-08-run5/out/FINDINGS.md (top findings, coverage matrix summary, other mage,
  C_DamageMeter, HSM before/after, cd-line evidence table, miner findings, dungeon/BG checklist). Next: package hook,
  regenerate guide, full test runner + perf gate, zip + leak check.
- 02:52 Guide regenerated (real/2026-10-08-run5/out/guide/SECRETS-GUIDE.html, 819 KB, 46 sources, 0 warnings).
  Package ships FINDINGS-run5.md. Running the full test runner + perf gate now.
- 02:57 Full test runner PASS twice (1 min 23 s / 1 min 41 s). Perf gate PASS on 4 runs: aged/fresh 0.92-1.01,
  aged 0.20-0.24%, storm 0.29-0.45%, 40-man slice max 0.086-0.096 ms (budget 0.12), bench 7-8 s. Also made the
  SPELL_UPDATE_COOLDOWN payload read explicit (if-guards instead of 'clear and v or nil'): the API checker no longer flags it.
  Building the zip.
- 02:58 DONE. ForeverDump-v2.2.4.zip built (157 files, 1,301,958 bytes): package.py leak check clean, plus an independent
  scan: only placeholder GUIDs, the real GUID tail is absent, 0 hits for 6 identity words and 179 log player Name-Realm forms.
  Ships SECRETS-GUIDE.html (run 5) and FINDINGS-run5.md.
- 10:23 v2.2.5 started: higher-order correlation (chains A→B→C, sequences/timing, identity joins, elimination). Offline-only;
  beam search depth ≤3, holdout on runs 3/4/5, ~2 min cap on run 5. No zip unless Lua changes.
- 10:25 Steering: offline correlate may run heavy (no 2-min cap); wider beams, depth 3–4 where cheap, more windows/shuffles,
  exhaustive where feasible; keep --quick + print elapsed. Perf-bench 2-min and in-game budget unchanged. Continuing HO miner.
- 10:32 v2.2.5 wiring done: fdump/analysis pass profile+higher; correlate_ho profiles full/quick; synthetic
  test_v225_ho 19 checks green; golden extended for HO interrupt chain; FINDINGS/CHANGES/tools README updated.
  Running `fdump correlate --quick` on runs 3/4/5 next (then full); no zip (no Lua changes).
- 10:34 correlate --quick on runs 3/4/5: 225 HO chains, mine=42.8s higher=0.6s total=43.5s. Full profile:
  720 HO chains, mine=44.4s higher=3.8s total=48.3s (promoted to out/correlate/). Golden run5: 27 checks
  (incl. ≥1 2-hop interrupt identity). test_v225_ho: 19. FINDINGS HO section filled with numbers. No zip.
- 10:35 v2.2.5 DONE (tools-only). correlate_ho + CLI/analysis wiring; --quick/full + elapsed; tests
  test_v225_ho (19) + golden run5 HO (27 total); FINDINGS/CHANGES/README/tools README/guide COVERAGE+HSM notes.
  Full correlate runs 3/4/5: 720 HO (578 chain / 122 seq / 18 identity / 2 elim), depths 1–4, ~48 s total.
  Run-5 interrupt identity 2-hop rediscovered (provisional). No Lua changes → no new zip.
10:35
- 10:35 v2.2.5 distinct-findings pass started (alias collapse, lift smoothing, minimality, holdout flags, echoes appendix).
- 10:45 Distinct-findings pass DONE. Alias collapse (targettarget→player), lift smoothing+CI, minimality,
  holdout flags, echoes appendix, ≤12 Distinct findings. Full correlate runs 3–5 ~17s. Confirmed (a)–(e);
  (a)/(d) already live → no Lua/zip. Tests test_v225_findings 33 + ho 19. FINDINGS updated.
- 14:28 v2.2.6 logging started (session_hdr, overflow, anchors, replay tape, verbosity, fdump replay).
- 14:29 Steering: one zip; default=release (<1%); FD_Logs capture elevates to test/diag (<=10%), restores release on OFF; /fdump level = override.

- 14:34 v2.2.6 logging continued (steering: one zip; default release; FD_Logs elevates then restores; /fdump level).
  Wired Commands/HSMUI StatusLine, Identity map, sec nibbles, Logs session verbosity, IdKey, offline `fdump replay`,
  test_v226_replay, dual perf gates. Next: full runner + zip.

- 14:34 v2.2.6 DONE. ForeverDump-v2.2.6.zip (164 files, ~1.3 MB): sealed replay tape,
  default release + FD_Logs elevate/restore, /fdump level, fdump replay, dual perf gates (capture ≤10%, release <1%;
  bench PERF OK: capture ~0.18-0.24%, release 0.016%, raid slice 0.085/0.12). test_v226_replay 12 OK; package leak clean.

- 14:39 Full runner PASS (~60s) incl. test_v226_replay + golden (30) + PERF OK. Zip rebuilt.

- 14:47 v2.2.6 follow-ups:
  1) Golden: restored strict DM type-5 + HO leads asserts. Softening was a bug (canonicalize treated arg0=N as
     unit tokens, dropping meter type 5) + leads() stopped emitting higher-order:* (only finding:*). Fixed
     canonicalize token gate; restored higher-order leads in analysis.leads().
  2) fdump replay now RE-EXECUTES Lib/HybridState.lua (hsm_replay.lua) from harness input events; exact-match
     decide stream (rule/kind/conf in order); CLEU anchor diff; synthetic addon tape via replay_tape_harness.lua;
     perturbed tape must fail (test_v226_replay_exec).
  3) SV growth estimates (pre-cap MB/min; max at caps): release solo/5/40 = 0.15/0.35/0.90; capture test =
     0.22/0.50/1.18; max SV ~2.7 MB release / ~3.8 MB test (rings+tape); tape byteBudget alone 0.5 / 8 MB.
  4) Capture shadow findings: HybridState shadow-dm-type7 + shadow-totem-heal (non-acting verdicts) when
     IsTest/capture; Verify onVerdict chains to ReplayLog. PERF OK capture ~0.19–0.21%, release 0.018%.

- 14:51 v2.2.6 damage-meter + world-state (continued):
  * HSM self-reconcile loop: fight.liveEst + fight.world[IdKey]; ReconcileDM multi-metric
    match/off/unexplained → verify + tape + HSM UI; per-unit sources from deep DM read.
  * WorldCapture.lua (capture-only): casts/auras/hp/power/threat/range/target-of across all
    tokens, five-state codes on tape kind ws (PRI 5). Release no-op.
  * Inference: UNIT_COMBAT/HEALTH broadened in capture; idKey wired into HybridState.
  * DamageMeter passes IdKey'd sources into ReconcileDM; coverage notes deep source counts.
  * tests/test_v226_reconcile.py green. FINDINGS: docs/FINDINGS-v226.md (accuracy pending
    re-capture; world-state tracked-vs-gaps table). Next: serialize bench, MB/min report,
    full runner + perf gates + zip.
  * ReplayLog.SerializeProxy at capture end (rows/keepers/ws/MB/min). test_v226_reconcile in runner.

- 14:57 v2.2.6 end-to-end finish:
  (A) caps+SerializeProxy+KEEP+ws thinning; (B/C) DM tape+deep read confirmed; (D) damagemeter_join in analyze,
  run-5 smoke 9 match/1 off/5 unexplained; (E) runner+perf wc40+zip next.
- 15:10 v2.2.6 DONE: runner PASS (incl. golden 30, hsm 160, reconcile 3), PERF OK (release 0.015-0.017%, capture
  0.25-0.32%, wc40 storm 0.12%, raid40 slice <=0.097 ms, storm 0.39-0.44%), SV serialize bench test 20.8 MB / ~1.5 s,
  run-5 meter join 9 match / 1 off / 5 unexplained. Zip rebuilt with leak check.
- 15:15 v2.2.6 perf gate fix: reverted +0.02 ms raid40 slack; gate is now median(N=5) of per-run maxSlice and p99 vs exact 0.12 ms budget (raw runs logged). Storm already median-of-3 (documented). Median held 0.095/0.084 — no Tokens.lua change, zip not rebuilt.

## 2026-10-08 run 6 (v2.2.6 first in-game capture) -> v2.2.7
- 18:38 Copied run 6 into real/2026-10-08-run6 (sv/, WoWCombatLog.txt, taint.log, screenshot.png). Client build is NEW: 70291.
- 18:38 Blocked actions: 47/47 ADDON_ACTION_BLOCKED "UNKNOWN()" = CheckInteractDistance in combat (41 Tokens.lua:296 range28
  field, 6 WorldCapture.lua:141 range10/28). All 18:30:47-18:31:16, inside combat (REGEN_DISABLED 18:30:47 / ENABLED 18:31:16).
  Chat lines were our own Errors.onBlock Print (taints ChatFrame1 buffer). Regression of the v2.2.2 fix (CombatProbe skip was
  not reused by the v2.2.6 scanners).
- 18:38 ObjectiveTracker: 5 nil-calls in [C] LayoutContents, each 40-60 ms after QUEST_LOG_UPDATE / CRITERIA_UPDATE+BAG_UPDATE_DELAYED
  (recorder CONSOLE_MESSAGE). No FD hook/write/taint on the tracker; runs 3-5 (same addons, build 70245) had 43 such events, 0 errors.
- 18:38 Other own errors: DamageMeter.lua:51 secret-boolean test (in combat), Drift.lua:156 `os` nil at capture ON.
- 18:47 Fixes in (v2.2.7): ns.CombatGuard/CombatLocked (Core) used by Tokens + WorldCapture (CheckInteractDistance never
  called while combat-locked, code "G" in ws); DamageMeter field() no truth test; Drift/Perf no bare `os`; Errors.onBlock
  deferred+throttled print with own call site; converter attributes UNKNOWN() blocks by site; first-ON full dump deferred
  (logs.fullDump = "on" restores); read-only UI signature (ObjectiveTracker LayoutContents identity) per dump section, at
  capture ON/OFF and on new errors. Tests: tests/test_v227_lint.py (7 rules; negative control on 2.2.6 code fails 4 rules
  at the exact run-6 lines) + tests/combat_guard.lua (15 checks).
- 18:55 Run 6b copied to real/2026-10-08-run6b (sv, WoWCombatLog, Client.log, taint.log). ObjectiveTracker nil-call RECURRED
  after the /reload: SV count 5 -> 8 (last 18:41:04), with no full dump in 6b. 6b-3: loot -> CRITERIA_UPDATE x2 at +131.898 s,
  LayoutContents error at +132.064 s. 6b-1 had CRITERIA_UPDATE x5 in capture with no error. Client.log 18:05:46-18:31:35:
  0 tracker errors before the first ON. taint.log: 0 ObjectiveTracker lines. So the one-time first-ON path is refuted as
  the cause; FD still shows no involvement.
- 18:55 Secret-value audit done across DamageMeter, WorldCapture, ReplayLog, Tokens, Identity, Inference and Lib/HybridState.
  New helpers in Core: ClearOf/Num/Str/Bool/Table, ClearWithCode, IsTrue, IsNil. ClassifyValue/IsSecret now check
  type(v) == "nil" instead of comparing. HybridState gets a boundary guard: every public input scrubs secrets and skips the
  call when a key argument is nil. New lint tests/test_v227_secret_lint.py: 6 rules, including a self-test. Negative
  control on 2.2.6: 118 flow + 29 idiom + 2 select-pcall violations, including DamageMeter.lua:51. New harness
  tests/secret_inject.lua: 11/11 pass (secret bool/number/string injected into every field, plus a line hook and an SV
  leak scan). The harness found and drove fixes for: HybridState "table index is nil" on scrubbed keys, and field()
  indexing secret tables.
- 18:55 Steering 18:50: static dump once per client signature -> ForeverDumpStaticDB (Static.lua). The login check runs it
  automatically when idle. ON never queues it. Added /fdump static clear|status|run|check; /fdump all forces it. Docs and
  Strings are no longer SavedVariables; they are runtime aliases. Migration and read fallbacks are in place, and tools
  splice it back, with fixtures/forever-70245 as the reference when it is absent. Smoke OK.
- 19:08 v2.2.7: tests/learned.lua stub ns now has the Core clearing helpers. dump.py normalizes the names-only reference
  namespaces (the guide crashed on the HSM SV without static data). CHANGES.md v2.2.7, ADDON-USAGE (static dump commands),
  and the tools README (static fallback) are written. Run 6b convert OK (287 leads); run 6 convert re-running; full runner re-running.
- 19:16 Perf: the one-off static dump ran in the bench release window (24.5%). The bench now sets static.auto=false, the same exclusion logs.fullDump=false gave before; scheduling stays gated by static_once. Storm was 0.46–0.69% because of the guard (pcall + vararg recursion). It is now an arity-specialised wrapper (Lib.ARITY, lint-checked): storm 0.458–0.461%. Heal reconcile is now effective (gross − overheal est.); 6b 456 = 400 + 56 over, with a test. Steering 19:10: ship first.
- 19:15 SHIPPED ForeverDump-v2.2.7.zip (178 files, 1385 KB; leak check clean). Full runner RUNNER_EXIT:0. Findings follow-up pending.
- 19:32 Follow-up: ROOT CAUSE of 0/11: the live HSM never ran in run 6 or 6b. Timing.Attach→Drift.Decay→os raised inside I.NewHSM at every capture start (selfErrors where=capture:spell knowledge + HSM inference, 3 sids), so there were no signals, no decide/verdict, no export. New tests/hsm_alive.lua (no-os full capture; 8 checks; v2.2.6 fails 7). analyze gets a high engine-health lead. Bugs found: WorldCapture 64-bit pack lost exists/health (now exact p/q words + tests/worldcap_pack.lua); R.IdKey npc took the instance id (every NPC = npc:1), fixed with a test.
- 19:28 Follow-up (2): offline replay had no own casts (they came only from HSM signals, absent when the HSM was down), so run 6's interrupt scored 0/1 → coverage now rebuilds casts from raw UNIT_SPELLCAST_* (castSource=raw-events): interrupt 1/1, reconcile interrupts match. damagemeter_join picked the meter fight by INDEX: 6b fight 1 got run 6's numbers (1327/243/290/1 'off') → now by epoch; 6b per-unit row matches 439/400/494. tests/test_v227_findings.py (9 checks) wired into the runner. Full runner RUNNER_EXIT:0 (storm 0.45%, raid40 max 0.088 ms, wc40 0.073 ms, aged/fresh 1.15, SV 20.77 MB). Log review: meter per-spell totals + live amounts give a unique spell per hit for 6b (11/11). ws: 98.8% of samples are absent tokens (84% of the tape). Writing FINDINGS.md.
- 19:41 Run 7 (19:35 steering) copied to real/2026-10-08-run7 (sv, WoWCombatLog = the 6b log + 104 lines ending 18:41:15, so no run-7 combat; WoWChatLog; taint.log). Health: 2.2.7 ran; one 3.8 s idle capture (19:32:36); 0 new errors/selfErrors/blocks; taint 22 = 18 expected + 4 contained; HSM exported counters (alive); static landed in ForeverDumpStaticDB 10.91 MB (same SV file, written 19:27:10 auto); ForeverDumpDB 1.15 MB (was 7.88); no ObjectiveTracker error, uiIntegrity signature unchanged; guardSkips not persisted (ooc anyway). ws records still p-only (B2 shipped). Replay "0 groups" is now VACUOUS (failure) and real-client slice means over budget are perf flags; both have tests. Runner RUNNER_EXIT:0 (one earlier run hit aged/fresh 1.69 under box load 5.7; isolated reruns 1.17–1.19). FINDINGS.md written (run6/out).

## 19:57 v2.2.8 hotfix shipped
- Zip: ForeverDump-v2.2.8.zip (183 files, 1402 KB); package leak check clean, plus an independent scan: 0 hits for character names and GUID tails (characters.json, plus the run6/run7 SV player GUIDs).
- First runner: PERF FAILED on storm 0.505% (limit 0.5). A v2.2.7 vs v2.2.8 A/B, 3 runs each, showed no regression (0.469–0.473 vs 0.455–0.513): it was noise. Gates were not changed (perf_bench.lua is identical to v2.2.7).
- Second runner: the secret lint (S1/S2) flagged new pcall-result uses in Inference/ReplayLog. Fixed by assigning internal results inside the pcall'd closure; only the error string leaves pcall. No `and x or` remains. The lint is unchanged.
- Final runner /tmp/fd_runner228e.log: RUNNER_EXIT:0. Storm 0.467% (≤0.5), raid40 maxSlice 0.094 ms (≤0.12), wc40 0.079 ms (≤0.1), aged/fresh 1.18 (≤1.5), SV 20.77 MB serialize OK.

## 20:11 Run 8 (BG) in progress
- Files are in real/2026-10-08-run8-bg/: sv/ForeverDump.lua (36.1 MB, v2.2.7), WoWCombatLog.txt (ends 19:40:49, so there is NO BG combat log), taint.log (19:40:50–20:02:24), WoWChatLog.txt (ends 19:32), errors-show.png.
- One capture, 19:40:49–20:02:33 ET (1304 s, diag). The last click was OFF and its macro /reload saved the SV. No second ON/OFF pair is in the SV.
- FD bugs found:
  - B1: every stored error stack starts with our own handler frames. Health then counted all 3354 errors as "own" and listed the nil-call as inside "[C] pcall". Fixed with Errors.StripOwn/IsOwn.
  - B2: the FD_Logs macro had a stale /combatlog toggle that switched the user's hand-enabled combat log OFF at ON. Fix: warn before toggling, and refresh the macro on the log-toggle system message.
  - B3: analyze crashed on mixed int/str keys (correlate.py, correlate_findings.py). Fixed.
- No error originates in FD code. FD taint is limited to 100 deliberate pcall-contained probe lines (Controls/Lab).
- Steering 20:10: the user disabled every addon except FD; the end-of-capture docs need the errors-show-before-OFF procedure.

## 20:20 Run 8 status
- Fixes in source (v2.2.9 candidate):
  - B1 Errors.StripOwn/IsOwn: Health, OFF summary, origins and nil-call class now use the real frames.
  - B2 FD_Logs stale /combatlog: red warning plus a macro refresh on CHAT_MSG_SYSTEM; the wowenv mock now fires that system message like the client.
  - B3 analyze mixed-key crash.
  - Diag is now the default capture level (Core/ReplayLog/Logs); the perf bench asserts it measures at diag; SV serialize is gated at diag with the same 26 MB limit (diag bench 24.67 MB).
- New regression tests:
  - tests/run8_regress.lua: stack 12/0, macro 9/0. Against the v2.2.8 control: stack 145 "own" errors, and the ON click switched the combat log OFF (both fail as expected).
  - tests/test_v229_run8.py: 5 OK.
- Perf at diag: storm 0.443%, aged/fresh 1.08, wc40 0.0723 ms, PERF OK.
- Docs: ADDON-USAGE end-of-capture procedure. Verified that the OFF click reloads (macro body ends with /reload; run 8 lastSession.reloading=true).
- BG data:
  - The tape filled at about 10.5 min (80000 rows); ws/sec/dm were then dropped (78778 overflow) and only keepers continued.
  - v2.2.7 ws exists/health/healthMax are lost (L) in every sample.
  - Power and inRange are secret for other players; range28 is clear out of combat and guard-skipped in combat; dead is clear; threat and casting are nil.
- The full analyze is still running.

## 20:13 Run 8 status (heading corrected; it was mis-stamped 20:31)
- First analyze done (493 leads). It showed three analysis bugs, now fixed with tests in tests/test_v229_run8.py (10 OK):
  - (a) The dm join paired live fights by index and fell back to the LAST dm-reconcile row, so 25 BG fights all showed live=1540 / taken=1252. Now paired by time, with no neighbour fallback.
  - (b) Fights outside the combat-log file showed log=0. They now get logCovered=False and None. PvP damage to players now counts as mine.
  - (c) Engine leads from earlier captures in the same SV (the fixed Drift/os errors) are now info, not high. A short trailing capture (accidental ON/OFF) is skipped by main_session and reported.
- Analyze is re-running with the fixes.

## 20:17 Run 8 status (heading corrected; it was mis-stamped 20:38)
- BG live data (combat recorder, 95,275 events):
  - UNIT_COMBAT, UNIT_HEALTH, UNIT_AURA and UNIT_ABSORB are clear for every token family (group, nameplate, arena, target chain).
  - Spell args of other players' casts are secret: 74–100% of their cast events.
  - UNIT_DIED: 124 secret, 61 clear Player GUIDs.
  - DAMAGE_METER_COMBAT_SESSION_UPDATED is 56,032 events (59% of the combat ring).
- Taint: FD has 100 expected probe lines, 8 contained, 51 benign chat, and 2 "blizzard-frame" lines. The 2 are ChatFrame UpdateFading messageInfo, the same chat-print family as the benign 51. The classifier now treats them as benign, with a test.
- Analyze re-run is still going.

## 20:21 Run 8 status
- Analyze re-run done (EXIT:0, 518 leads). dm-join now pairs fights by time and reports log=None for BG fights (there's no combat log file). Earlier-capture leads are info.
- Version bumped to 2.2.9 (toc, Core, test). Added the CHANGES.md v2.2.9 section. PERFORMANCE/ADDON-USAGE/replay text now say diag is the default.
- Next: FINDINGS.md, full runner, package and leak scan.

## 20:22 Run 8 status
- FINDINGS.md written and leak-scanned: 0 of the 16 player GUIDs in the SV, no names.
- First v2.2.9 runner: smoke check "only the macro refresh is deferred" FAILED. The new CHAT_MSG_SYSTEM refresh queued a second timer behind the click's own /chatlog line. Fixed in code by sharing one refresh-pending flag between the click and the system message; the check is unchanged. Smoke OK, run8 regress 12/0 + 9/0.
- Full runner re-running.

## 20:34 v2.2.9 built
- Full runner RUNNER_EXIT:0. PERF OK at capture level diag: storm 0.488%, aged/fresh 1.15, raid40 0.216%, wc40 0.080 ms. SV serialize: test 20.77 MB, diag 24.67 MB (≤26). All limits unchanged.
- perf_bench JSON now records captureLevel (test-only change; perf re-run OK: storm 0.466%, ratio 1.12).
- ForeverDump-v2.2.9.zip packaged: scrubber leak check clean, plus an independent scan (character names, characters.json GUID tail, 16 run8 player GUIDs) with 0 hits. FINDINGS.md: 0 hits.
- Confirmation runner (after the perf_bench JSON tweak) in progress.

## 20:44 Done
- Confirmation runner RUNNER_EXIT:0. PERF OK (diag): storm 0.470%, aged/fresh 0.87, aged 0.321%, raid40 0.204%, wc40 0.074 ms.
- Deliverables: real/2026-10-08-run8-bg/out/FINDINGS.md, ForeverDump-v2.2.9.zip (sha256 1f7383d8…).

## 20:46 Aura readability matrix (new task)
- Sources found:
  - CombatProbe cells (aura:* API x 6 filters, per field codes, per ctx x unit class; runs 5/6/6b/7/8, 5 distinct captures).
  - CombatProbe UNIT_AURA payload codes.
  - Combat recorder UNIT_AURA rows (delivery + updateInfo codes; 10,455 in the BG).
  - WorldCapture buffN/debuffN.
- First observations:
  - BG combat: every C_UnitAuras call errors "Auras cannot be accessed when secret while tainted", even for the player.
  - BG UNIT_AURA payloads: isFullUpdate secret, added/removed lists are secret tables.
- Writing tools/fdump/aura_matrix.py next, then docs/AURA-MATRIX.md.

## 20:52 v2.2.10 in progress (priority over the master guide)
- Diag ceilings:
  - tape 2,000,000 rows, combat 1,000,000, record 2,000,000, signals 250,000, verify 250,000, byte budget 4 GB.
  - Recorder throttle 1000 events/s per event type.
  - About 10x a 30 min BG; a one-time warning line fires if any ceiling is hit.
  - release and test caps unchanged.
- Lossless DAMAGE_METER_* run-length rows:
  - ns.RLE in Core; used in the combat ring, recorder (folded before the throttle) and replay tape dm rows.
  - The converter expands them on load (tools/fdump/dmrle.py, hooked into Dump).
- Next:
  - bg_replay harness: replay REAL run 6/6b/8 streams through the addon, accelerated and tiled to 30 min; memory + frame cost + rule hit/miss vs combat logs.
  - round-trip test.
  - Master guide resumes afterwards (evidence sources mapped; design noted).

## 21:00 v2.2.10: DM compaction proven lossless
- The tape dm mismatch was not a data loss. The harness JSON dump printed numbers with %.6g, so d=1000249 came out as 1.00025e+06. It now prints exact integers and %.17g.
- Round-trip on run 8 replayed through the whole addon, RLE on vs off:
  - combat 39,401 stored rows expand to 95,275, exact;
  - record 69,710 expand to 125,584, exact;
  - tape dm 56,042 = 56,042, same order.
- New permanent test tests/test_v2210_dmrle.py (synthetic stream always; run 8 when present; ~90 s). Added to the runner.
- Harness fix: leave combat before FD_Logs OFF (a stream can end mid-fight).
- Next: run 6/6b hit/miss scoring vs combat logs, the gates, the version bump, the runner, the zip.

## 21:02 v2.2.10: rule hit/miss through the real-data replay
- New tools/fdump/replayscore.py scores per rule against the combat log: attribution, deaths, interrupts, meter join. Counts only.
- Run 6/6b streams were replayed accelerated through the addon (RLE on and off) and scored next to the live captures.
- RLE on = RLE off on every rule, so the compaction does not change detection.
- Replay vs live: only stream-driven rules reproduce (damage-taken 11/11 and 17/17, heal-on-me). Rules that read live APIs (target GUID, C_DamageMeter values, token health for deaths) cannot reproduce: the mock returns no or fake values. A playback mock that serves the recorded reads is the next step.

## 21:04 v2.2.10: gates, version bump, docs
- sv_serialize_bench: diag is report-only (40.1 MB / 3.3 s for a 30 min BG fill); test keeps 26 MB; new release gate of 4 MB (fill 1.63 MB).
- New diag perf gate tests/bg_replay_gate.py: real run 8 tiled to 30 min (else synthetic). Limits unchanged: <=10%, last/first <=1.5, nothing lost. Result 0.675%, ratio 1.07, OK.
- test_v229 DiagDefault updated to the new user-ordered policy.
- Version 2.2.10; CHANGES/PERFORMANCE/ADDON-USAGE/Core updated. Full runner next.

## 21:28 v2.2.10: storm perf gate regression found and fixed (gate not touched)
- The first runner failed the SPELL_UPDATE_COOLDOWN storm gate: 0.527% vs <=0.5%. Interleaved A/B: v2.2.9 0.455-0.479%, v2.2.10 0.504-0.616%.
- Cause: the diag recorder now keeps every storm event (1000/s throttle vs 5/s). Caps/ceilings are not a factor (tested with the old caps).
- Fixes, all producing identical stored rows:
  - the recorder reuses the live observer's ClassifyValue codes (no second and third classification) through a presized row/args constructor;
  - ObserveLive skips a redundant canaccessvalue pcall for "C" values and memoizes its doc key;
  - ReplayLog cfg() is memoized (it ran on every event);
  - OnCriticalEvent no longer allocates its code table per call and takes the codes buffer without copying.
- Lua instruction count is now below v2.2.9 on the storm path. Storm: 0.447-0.480% over 6 runs (v2.2.9 0.463-0.499%).

## 21:41 v2.2.10: user budget decisions applied
- Release budget is now 2% (was 1%) and the storm limit 2% (was 0.5%) at capture and release level. Both set by the user on 2026-10-08; the capture ceiling stays at 10%.
- perf_bench, PERFORMANCE.md, CHANGES.md, ADDON-USAGE.md, the Core/ReplayLog comments and the perf.py flag are updated.
- Runner caught a secret-lint idiom (`and states or`) in OnDmUpdate; rewritten as an explicit if. Re-running the full runner.

## 21:57 v2.2.10 shipped
- Full runner RUNNER_EXIT:0.
- ForeverDump-v2.2.10.zip (192 files, 1,470,128 bytes, sha256 d78dad80…).
- Leak checks: package scrubber clean; the independent scan found 0 of 466 real player GUID tails (runs 6/6b/8); no tests/out or real/ in the zip.
- Master guide is deferred; the parent will dispatch it separately.
## 22:01 master guide: started; surveying sources
## 22:02 master guide: sources surveyed (per-run guide JSON runs 2-5, analysis/coverage JSON 6/6b/8, FINDINGS 6/7/8); designing generator
## 22:03 master guide: tools/fdump/svinspect.py written (SV secret-state inspection, codes/counts only, cached per run); filling caches
## 22:04 master guide: SV inspection caches built for all 9 runs (ring per session, token matrix, probe cells, aura containers); writing generator
## 22:06 master guide: tools/fdump/master_guide.py first full generation (173 rows); reviewing rows for correctness
## 22:06 master guide: 'fdump.py master-guide [--check]' wired; 193 rows generated; svinspect now tracks arg presence; reviewing output
## 22:07 master guide: tests/test_master_guide.py (8 checks incl. negative stale controls) wired into tests/run_converter_tests.sh; tools/README row added; running full runner
## 22:11 master guide DONE: full runner RUNNER_EXIT:0 (incl. master guide 8/8); 193 rows, live 72 / cached 6 / correlated-proven 6 / provisional 11 / estimated 1 / unsolved 81 / not measured 16
## 22:37 v2.2.11: run 9 files copied to real/2026-10-08-run9-bg (box only); diagnosing 'constant table overflow'
## 22:39 v2.2.11 step1: cause CONFIRMED - stock lua5.1 loadfile(run9 SV) -> 'constant table overflow'; new tools/fdump/svconst.py counts 321,235 unique constants (122.5% of 262,143): LogDB.replay.sessions 142k, StaticDB 114k, CombatLogDB 40k, RecordDB 20k, DB 17k; validating counter vs luac
## 22:40 v2.2.11 step1 DONE: svconst validated EXACT vs luac5.1 -l on run 8 SV (137,778 = 137,778); run 9 SV parses offline fine with fdump info (18.9 s) -> data fully recoverable; designing lossless pack format
## 22:41 v2.2.11 design: pack each SV global at PLAYER_LOGOUT (after all logout handlers) into Lua-source chunks (<=50k literals, ~1 MB each) + small graft plan; unpack at ADDON_LOADED via loadstring+empty env (C-speed, transparent to all modules); failure keeps the packed blob in a rescue var; offline converter decodes
## 22:41 v2.2.11: writing ForeverDump/SVPack.lua (pack/unpack/estimate) + offline decoder
## 22:43 v2.2.11: SVPack wired (ADDON_LOADED unpack before InitDB, PLAYER_LOGOUT pack after all handlers, OFF guard); isdst taint fixed (utcOffset now pure arithmetic, nothing written into date() tables); building tests
## 22:43 v2.2.11: tests/svpack.lua unit/edge suite passing (incl. control: same 400k-literal data written plainly overflows; packed loads)
## 22:45 v2.2.11 (b) REAL run 9 round trip OK: packed file loads in stock Lua 5.1 as one chunk; constants 321,235 -> 321; 150 chunks; exact deep-equal after unpack; pack 6.3 s, unpack 1.1 s, file 75.5 -> 48.0 MB; python cross-check running
## 22:46 v2.2.11 (b) python cross-check OK: luasv decode of the packed file == parse of the original (strict types incl int/float), parse 18.6 s vs 18.1 s; now (a) BG replay 2x/10x
## 22:47 v2.2.11: tests/test_v2211_svpack.py written (counter==luac, unit suite, (a) BG 2x/10x + no-pack control, (b) real run 9, (c) both formats); first run
## 22:50 v2.2.11: steering received - removing automatic static dump (explicit /fdump static run only); svpack test driver now running in background
## 22:50 v2.2.11 static: auto-run removed (no PLAYER_LOGIN hook, Check() report-only, /fdump all + RunAll skip static, ST.Start refuses any caller but the slash command); status text says data persists until /fdump static clear
## 22:51 v2.2.11: steering 2 received - FD_Logs ON wipes previous capture data (keeps learned + static); static tests rewritten, running
## 22:52 v2.2.11 wipe: Logs.WipeCaptureData() on the ON branch only (not resume, not OFF); keeps learned/knowledge/timing/drift/baselines + static; running smoke
## 22:56 v2.2.11: smoke OK + converter OK with wipe-on-ON + static-only-by-slash (smoke updated: asserts typed ON wipe; fixture keeps main capture); writing capture_wipe.lua + static lint
## 22:57 v2.2.11: tests/capture_wipe.lua 31/31 (ON wipes, OFF/resume/in-combat don't, learned+static kept, new data lands live) + tests/test_v2211_static.py OK (only slash starts static)
## 22:57 v2.2.11 docs: ADDON-USAGE updated (static only by slash + persists until clear; ON wipes/keeps list; copy SV before next ON; SV packing section)
## 22:57 v2.2.11: tests/utcoffset.lua OK in 7 zones (NY, UTC, +5:30, +13:45, -3:30, +14, -11); wired. svpack driver still running (10x replay)
## 22:59 v2.2.11: svpack driver results: counter exact, unit 34/34, (c) both formats OK, (a) 2x 39.2 MB 280 constants / 10x 102 MB 629 constants exact unpack, control 10x unpacked = 456,713 constants (174%, fails to load), (b) run 9 321,237 -> 321 exact; 4 FAILs were a broken loadfile helper in the test (fixed); regenerating master guide
## 22:59 v2.2.11: CHANGES.md entry written; next full runner after master guide regen
## 22:59 step 4: run 9 analysis started (analyze + errors + taint + size) in background; SV moved to real/2026-10-08-run9-bg/sv/
## 23:00 steering 3: tests must run ~10x faster - measuring per-test wall times first
## 23:00 tests/runner.py written (same 57 commands, per-test timing, phases); measuring BEFORE = serial baseline (note: run 9 analyze+replayscore running alongside on 2 of 8 cores)
## 23:01 BEFORE baseline running serially from a snapshot (/tmp/fdbefore, FD_SVCACHE=0); meanwhile fixing failures it surfaced (luacheck 4 warnings, hsm 1, buggrabber, regress)
## 23:03 fixed 4 failures surfaced by runner: mergeDefaults padded saved lists with defaults (real bug, re-hit by ON-wipe InitDB); BugGrabber pre-ON errors no longer re-imported into fresh capture; hsm history test rewritten for ON-wipe contract (restart-inside-capture keeps history, new ON wipes); 4 luacheck warnings
## 23:04 runner failures all fixed (test_v222 history now read from hsm side-capture SV tests/out/hsm_history_sv.lua; toc version check 2.2.11). Now speed work.
## 23:09 steering: fix run 9 taint-blocked secret ops (Controls.lua:227 x89, :154 x6, Lab.lua:241 x2) with ClearNum/Classify pattern + permanent lint/harness checks; run 9 had 0 unique Lua errors
## 23:18 svpack test rewritten: synthetic density SVs (2x/10x run 9 constants, generated directly), per-part processes, svcache; cold 127s, see warm next; svconst learns 0/0 (luac-checked)
## 23:30 svpack test: synthetic 2x/10x density, per-part processes, svcache LAST restored on hit, compare path built lazily (10x compare was 70 s superlinear); taint fixes done in code (Controls TryTimeLeft/opsFor + Lab secret-string classify-first; wowenv + secret_inject exemptions for Controls/Lab removed; smoke asserts skip). xref: per-stream matching fix. Next: secret lint for Controls/Lab, dmrle speed, runner parallel
## 23:33 taint_run9.lua added (10 checks, runtime+static, in runner phase 1); dmrle split into 2 runner jobs + on/off replays in parallel (run8 63 s, long pole = no-RLE replay 47 s). Running full parallel runner.
## 23:39 runner: background phase 0 (dmrle), secret_inject split 4 ways (mode pairs keep cumulative checks), taint fixes' hsm check updated; rerunning
## 23:40 parallel runner wall 67.7 s (baseline serial 588.6 s; sum of test times 291 s); only master guide stale (regen pending)
## 23:40 run_converter_tests.sh -> runner.py (parallel) + parity check; serial list kept as run_converter_tests_serial.sh. Now master-guide regen with run 9
## 23:40 master guide regenerated with run 9 (193 rows; live 72->73, correlated-proven 6->4, unsolved 81->83, not measured 16->15; 13 changes). run 9: 0 Lua errors, 87 'blocked' rows are all ADDON_RESTRICTION_STATE_CHANGED (max 8/min at 22:27), replayscore per rule in out/replayscore.json. Full runner next.
## 23:42 CHANGES/ADDON-USAGE updated (taint fixes, mergeDefaults, BugGrabber, xref, test speed); full runner again
## 23:43 FULL RUNNER OK: 62 tests, RUNNER_EXIT:0, wall 62.1 s (before 588.6 s serial). Packaging.
## 23:44 PACKAGED ForeverDump-v2.2.11.zip (211 files, 1,553,642 B, sha256 3648675ba3a26f60303abac302dcb2922c8fefbca878dedefc0fcf0968a31064); scrubber leak check clean; fresh unzip scan: 0 hits for names / full GUID / GUID tail (only the 4-digit realm server id matches, generic digits); .cache/real/tests/out not packaged. Done.
## 23:44 START dm-join investigation. First insight: dm-unit-me/other 'C' are the addon's own live verdicts (ForeverDumpDB.verify ring), not combat-log refutations (confirmed/refuted = 0) -> look at Verify.lua dm-unit logic first
## 23:45 insight: run 8 was ALSO 100% off (8/8 me, 90/90 other) -> not new in run 9, systematic in BG. Meter per-player totals grow across consecutive reconciles (taken 1977->2656->2711, then reset 573->666->905->1243): BG meter session is cumulative across several live fights, live side is per-fight window
## 23:46 ROOT CAUSE evidence (run 9 vs combat log): meter totals == log summed over [stop - meter.duration, stop] EXACTLY (2935/2711/683; 151/573/0; 229/666/0; 1190/905/0) -> meter is right but its BG session spans 38-159 s while the live fight is 6-18 s; live taken/heal == log fight window exactly; live 'damage mine' is 3-30x the log (1664 vs 77, 2427 vs 74) -> second bug: BG damage over-attribution to me
## 23:47 cd-ready insight: 46 of 90 verdicts are triplicates (Shocks 8052/8056/8046 share category 19: one ready sample -> 3 verdicts). Of 23 distinct C in the BG window: 14 have NO cooldown sample between predicted end and the 'ready' sample (sampling latency 0.28-1.98 s, unverifiable), 2 truly late (seen cooling after predicted end), 7 early (ready before predicted).
## 23:48 insight: the BG meter 'current session' = union of several consecutive live fights (incl. soft ones): log summed over those live fights == log over the meter window (229/230, 1190/1191, 1690/1691). So live must be summed over the meter session, not the last fight. Live taken sums track the meter (666/666, 852/905); live damage-mine is 7-20x over (4504 vs 229) = separate BG attribution bug
## 23:49 cd-ready mechanism: readiness is only sampled when an event arrives (CDCheckList on SPELL_UPDATE_COOLDOWN etc.); no sample at the predicted ready time -> 'ready' seen 0.3-2 s late in quiet BG moments. dm-frame insight: in a 14-15 player BG group DAMAGE_METER_COMBAT_SESSION_UPDATED fires for every groupmate's hit (BG tape hdr groupSize 14/15), so 'meter tick in the same frame = mine' over-attributes (live mine 7-20x the log)
## 23:50 cd-ready fix in: verdict = C only when proven (ready before pe-0.25 s, or a still-cooling sample after pe+0.25 s), V within tol, else U(sample-latency); one verdict per shared category (shocks cat 19 tripled every sample: 46/90); new due-time C_Timer re-read at predicted end (+probe at end+tol) so latency stops masking accuracy
## 23:51 dm fixes in: ReconcileDM compares the meter session window (sum of recent fights incl. soft; U when coverage incomplete), per-unit missing/under-observed others -> U (C only when live exceeds meter; me strict both ways); dm-frame gated to solo via GetNumGroupMembers (SetGroupSize). Identity: meter id player:hash == worldIdKey(raw Player- GUID) -> hashing is consistent; 'guid:' keys are hashed tokens whose GUID was secret, so the 81/132 missing units are absence, not a hash mismatch
## 23:55 re-score setup: exported run 9 main capture (125,584 rows) and replayed it through the old (pre-2.2.12) and new addon with --group 15 (new bg_replay option); both 21 s, impact 0.66/0.68 %, no overflow. Note the replay meter is the mock, so dm-* verdicts get re-scored separately from the real recorded meter records
## 23:56 PAUSED meter work (changes kept, runner was EXIT 0 with them). URGENT: in-BG taint 'attempted to iterate a table that cannot be accessed while tainted (execution tainted by ForeverDump)' x1433 from BattlegroundChatFilters.xml:3 on each 'N players have joined the battle' message. Investigating what we write that Blizzard iterates
## 23:57 taint root cause (from Blizzard source Blizzard_ChatFrame/Mainline/BattlegroundChatFilters.lua): its OnUpdate prints 'N players have joined the battle' via DEFAULT_CHAT_FRAME:AddMessage and THEN iterates ADDED_PLAYERS (keys = BG player names, secret in 12.x -> restricted table). AddMessage reads ChatFrame1's Lua fading state (oldestFadingLineTimestamp, run 3 finding) last written by an addon line -> execution becomes tainted by ForeverDump -> iteration errors; the error aborts before the timer reset, so it repeats every frame (count 1433+). Any ns.Print into ChatFrame1 inside a BG (ON/OFF lines, Errors deferred line, ceiling warnings, slash replies) can be that writer. Fix: no addon line into Blizzard chat frames inside instances/combat; own message frame + flush in the open world
## 23:58 taint fix verified in a model of Blizzard's BattlegroundChatFilters (tests/bg_chat_taint.lua): v2.2.11 addon -> 12 of its lines land in ChatFrame1 inside the BG and the model raises the iterate error 5/5 updates; v2.2.12 -> 0 lines in Blizzard chat while in an instance/combat (held: 12, shown on own ForeverDumpMessageFrame, flushed on return to the open world), 0 errors. Static check: only Core's sink writes Blizzard chat, no hooks/filters. Next: HSM panel raw GUIDs
## 23:59 GUID scrub: HSM panel + SV export now show/write the salted IdKey (player:<hash>, npc:<id>); raw keys stay in memory for matching. tests/guid_scrub.lua: v2.2.11 fails 3/7 (raw GUID in Export, panel text, SV), v2.2.12 7/7. inference.player.guid (own-character anchor for the offline scorer, box-only) intentionally unchanged
## 00:01 meter insight 2: per-unit compare was comparing different quantities - world[u].dmg/heal/interrupts are what I did TO u, meter DamageDone/HealingDone are what u DID; only 'damage taken by u' is the same on both sides -> others compared on taken only. Insight 3: capture mode counts one hit once per token showing the unit (target+nameplateN+raidN, incl. my own raidN in a BG) -> live per-unit taken 1.36-1.42x meter; Inference now drops same-frame same-payload copies from another token. Run 9 as recorded: all 5 meter sessions cut through a soft record with my activity inside the window (or reach past the kept fights) -> U, not C
## 00:02 tests/dm_session_bg.lua (run 9 BG fixture, counts only, 19 checks) passes on 2.2.12, fails on 2.2.11; running full runner
## 00:04 offline scorer: coverage replay now feeds the capture's group size (tape hdr groupSize 14/15) to the engine (k=group), so the re-score applies the solo-only dm-frame rule; re-scoring run 9 now
## 00:04 cd-ready re-judged on run 9's verify ring with the 2.2.12 rules: old 75C/15V (90) -> 44 distinct observations (46 were shared-category duplicates): 5V, 12C (10 early, 2 proven late), 27U (sample latency, no proof). Insight: the 10 'early' are real prediction errors and are partly CAUSED by latency - the learned cooldown length is measured to the first ready sample, so late samples inflate the learned length and the next prediction ends too late; the due-time sampler fixes both. Offline attribution re-score (group size fed): damage-on-target 9.4% -> 100% (53), heal-on-me 30.9% -> 87.6% (97)
## 00:11 packaging v2.2.12 now (taint fix first); run 9 analyze restarted in background for the guide regen afterwards
## 00:13 runner: 64/65 ok; bg_replay_gate aged/fresh 1.53 (limit 1.5) under contention from the background run 9 analyze; standalone x2: ratios 1.16/1.15, PERF OK. Rerunning the full runner (gate unchanged)
## 00:15 PACKAGED ForeverDump-v2.2.12.zip (215 files, 1,573,494 B, sha256 75197413fc1c6f4261c6f7f982115b006a942cfec81720e8a594508c80216c19); runner RUNNER_EXIT:0 (65 tests, 71.7 s wall with the background analyze running); package.py leak check clean; fresh-unzip scan: 0 hits for the character names or the player GUID/tail; only synthetic test GUIDs (Player-1234-0ABCDEF0, 4618-0000F00D/00AAAAAA/00BBBBBB, 4619-0ABCDEF1), the generic realm label and the realm server id. Next: guide regen once the run 9 analyze finishes
## 00:22 run 10 BG received; copying to real/2026-10-09-run10-bg (box only). Checking run 9 analyze status first
## 00:23 RUN 10 CRITICAL: SV written by 2.2.11 is NOT packed - ForeverDumpDB.svpack: every var 'failed: SVPack.lua:108: Division by zero' -> 331,087 constants (126% of 262,143) -> this SV will NOT load (constant table overflow) at next login. The real client raises on x/0 (the mock/stock Lua 5.1 returns inf/nan). Investigating line 108
## 00:24 SVPack fix: no division anywhere in the packer (-0 by formatted sign; NaN skipped+counted as stats.nan since WoW cannot load any NaN literal without arithmetic; inf as 1e999 via the lexer). Next: build a WoW-like lua5.1 that raises on x/0 and x%0 so tests catch this class
## 00:25 v2.2.13 SVPack: no division in pack/unpack; fallback pass (per-scalar pcall) then last-resort stub so the file always loads; P.SelfTest at FD_Logs OFF warns loudly; login report of last pack problems. Built a WoW-like lua5.1 (official 5.1.5 source, sha256-pinned, lvm DIV/MOD raise on zero, tests/build_wowlua.sh): SelfTest passes on 2.2.13, fails on 2.2.11 and the shipped 2.2.12. Next: audit every / and % in the addon
## 00:28 v2.2.13 audit: tests/test_div_lint.py covers 101 DIV/MOD sites (44 variable-divisor, all reviewed); guarded 8 zero-possible divisors (ReplayLog mbPerMin dur=0 was live); fallback 2 stubs a failed var only if the file would overflow. Runner+serial list now run every lua5.1 job under the WoW-like build. Full runner next (no heavy job running; run 9 analyze finished: 724 leads)
## 00:33 master guide regenerated with run 9's finished analysis (correlated-proven 4->7, provisional 11->8; others unchanged). Run 10 has no out/ yet (analyze after packaging). Full runner for v2.2.13 now (nothing heavy running)
## 00:36 v2.2.13 PACKAGED: ForeverDump-v2.2.13.zip sha256 a7b2d627f5a66199dd7f2c5eab67b57e1e3f2ea4b649e2833e0e05fd7c0e6038, 219 files, 1,590,658 B, copied to /workspace/. Runner EXIT 0 (68 tests, 65.5 s, all lua5.1 jobs on the WoW-like build). Packager leak check clean; fresh-unzip scan vs characters.json + all 1,021 Player GUIDs / 885 player names in real/ combat logs: 0 GUID hits, 0 own-character names (only dictionary-word collisions such as zero/time/last and the synthetic placeholder 'Healy'). Next: run 10 analysis
## 00:45 run 10 per-rule (offline rerun of the real capture, group 15 fed, 2.2.11 HSM -> 2.2.13 HSM): damage-on-target 33.3->83.3 (n=6), heal-on-me 64.4->69.5 (n=118), aura-on-me 45.3 (n=159), miss-on-target 100, damage-taken 100, heal-on-target 0 (n=21, no attribution at all), interrupt 33.3 (n=3). Insight: in groups the remaining heal-on-me misses are my own heals that fall to elimination (21) once dm-frame is solo-only; run 9 identical method reproduces 9.4->100 / 30.9->87.6. SV: 2.2.11, unpacked, 5 vars failed SVPack.lua:108 Division by zero; error ring empty (0 Lua errors), 72 restriction-state notices; BattlegroundChatFilters error not in the SV (ours only records our own errors)
## 00:50 fdump analyze speed-up: correlate.mine hot loop (py-spy: _min_dt inside the per-window loop) now computes the per-pair B->A distances once and bisects per window; run 5 miner output byte-identical, mine 5.4->4.0 s. The run 10 analyze (started on the old code) is still running
## 01:00 run 10 analyze done (old code, 20m15s, 907 leads: high 176 / medium 495 / low 171 / info 65). Master guide regenerated with runs 9+10 (11 runs): live 73, cached 6, correlated-proven 7 (+3: hit-mine/target, /npc, /nameplate promoted by run 9's re-scored 100% damage-on-target), provisional 8 (-3), estimated 1, unsolved 83, not measured 15; run 10 changes: guid/target and name/target combat mixed->secret, threat/npc pvp nil->secret. HTML+MD copied to /workspace/
## 01:04 analyze speed-up proven on run 10: 20m15s -> 10m12s, analysis.json identical except timing fields (907 leads both). Final full runner now (no heavy job running)
## 01:08 FINAL v2.2.13 repackaged (adds the analyze speed-up + guide with runs 9/10): sha256 6f4b1dbab8dc9e5785ac9dd08072e0a42a0b1d47c269a6cbcecc9d75e23a5f98, 219 files, copied to /workspace/ with SECRETS-GUIDE.html/.md. Runner EXIT 0 (68 tests, 74.3 s, WoW-like lua). Leak check clean; fresh-unzip scan: 0 real GUIDs, 0 own-character names. Runner now finds the stock lua5.1 even when the shim is already on PATH
## 09:57 run 11 ingested to real/2026-10-09-run11-bg (SV 37.9 MB, combat log 7.3 MB, 2 screenshots); analyze started (faster miner). Key fact: SV addonVersion 2.2.11 -> the user ran the old build; working on version visibility + chat-filter re-verification
- 10:02 ET run11: SV is v2.2.11 (install didn't update) so run 11's BG chat-filter error says nothing about 2.2.12+ fixes. Real-source read: the BG filter's OnUpdate errors in loop 2 (`next, ADDED_PLAYERS`), after the AddMessage to DEFAULT_CHAT_FRAME, so taint enters via ChatTypeInfo/globals/AddMessage internals. Auditing every chat touch point now.
- 10:05 ET KEY FINDING: v2.2.12/13 did NOT fully fix the BG chat-filter error. Real source: PushFront -> headIndex:Increment() = SetValue(GetValue()+1); SetValue writes SecureNumber.value in the caller's context. One addon AddMessage on ChatFrame1 (even in the open world, even hours earlier) leaves it tainted, and every later secure AddMessage re-taints it, so the BG filter's loop 2 errors. Matches taint log 10/8 ("reading field value" SecureTypes.lua:279 <- PushFront). v2.2.13 still flushed held lines and printed /fdump output to chat in the open world. Fix (v2.2.14): no line ever goes to Blizzard chat; own message frame + /fdump msgs. New test models the real path (control: one line an hour earlier still breaks it) and catches a re-introduced chat print.
- 10:09 ET run 11 ingested: analyze 6m07s (high 110 / medium 189 / low 107 / info 63). NOTE the client build is 70291 (runs 9/10: 70245), and the SV is 2.2.11. Per-rule (2.2.11 HSM -> 2.2.13 rules): damage-on-target 15.6->100 (n=32), heal-on-me 47.2->90.6 (n=53), miss-on-target 33.3->100 (n=3), aura-on-target 100 (n=21), damage-taken 100 (n=111), aura-on-me 37.3 (n=134), heal-on-target 0 (n=16), no interrupts. cd-ready re-judged 12 C -> 3 C / 5 U (4 dups dropped). Guide regenerated (12 runs): unsolved 83->84, not measured 15->14 (aura-mine/friendly now measured: nil in pvp); aura-details/player pvp mixed->clear; threat/npc pvp secret->mixed; absorbs/enemy-player pvp secret->mixed. Version visibility done (prefix on every line, panel title, ON/OFF, /fdump status+version, login notice, addon-only zip + dev zip). Full runner next.
## 10:13 ET SHIPPED v2.2.14: ForeverDump-v2.2.14.zip (addon only, 46 files, 271,715 B, sha256 5c8cc837...b348) + ForeverDump-v2.2.14-dev.zip (220 files, 1,516,002 B, sha256 dbef65c3...b84e), copied to /workspace/ with SECRETS-GUIDE.html/.md. Runner EXIT 0 (69 tests, 75.8 s). package.py leak check clean on both; fresh-unzip scan: 0 real GUIDs (1061 known incl. run 11), name-scan word set identical to v2.2.13 (dictionary-word substrings only, nothing new). Change: no line ever goes to Blizzard chat (real-source SecureNumber head-index taint persists all session), version on every line/panel/status + login change notice, split zips, new install steps.
## 10:19 ET zip split reverted (user decision): package.py writes one full ForeverDump-v<ver>.zip again (leak check kept); ADDON-USAGE install = copy the ForeverDump folder into Interface/AddOns + version check; CHANGES updated. Runner EXIT 0 (69 tests). v2.2.14 repackaged (docs changed).
- 13:28 ET run 12 copied to real/2026-10-09-run12-bg (first BG on v2.2.14; user saw 0 errors, no BG chat-filter error).
- 13:30 ET run 12: packed SV decodes IDENTICAL via converter vs the addon's own Lua UnpackAll (all 5 vars; 1.55M literals in 40 chunks, pack 2.55 s at logout). Data complete: 539 s capture (13:17:03-13:26:02), recorder 50,237 ev 0 dropped, tape 39,321 0 overwritten; rates match run 11 (small SV = short BG). versionHistory 2.2.11->2.2.14 at 13:12:20. 0 Lua errors, 22 restriction toggles only. Profiler peak 35.75 ms = window 13:19:28-33, coincides with the one-shot in-combat Probe.Run (C_Timer +1 s after first PLAYER_REGEN_DISABLED, not Perf-wrapped); every wrapped handler max <= 8.3 ms.
- 13:36 ET run 12 analyzed (4m25s; high 43 / med 138 / low 85 / info 65). Live 2.2.14 verdicts: cd-ready 17V/5C/0U (run 11 live 0V/12C), due-time sampler HSM.CDDue 50 runs 6.9 ms max 0.32 ms; dm-unit-other 11V/0C/97U (run 11 0/192C); dm-unit-me 0V/2C/7U (the 2 C = live heal 94 vs meter 0 at 13:19:58); gcd 2V/17C (observation latency, same pattern runs 10/11). Per-rule (2.2.11 replay -> live 2.2.14): heal-on-me 27.8->94.4 (n=18), damage-on-target 0->100 (n=8), aura-on-me 38.8 (n=67), damage-taken 100 (n=79), interrupt 100 (n=1). Perf: own 1.12% of wall (budget diag 10%), profiler peak 35.75 ms (runs 9-11: 694/1273/269 ms), 1 frame >5 ms. Guide 13 runs: live 73->72, unsolved 84->88, not measured 14->11. No bug -> no release.
- 13:40 ET v2.2.15 started (live engine improvements). Milestones: M1 rank leads -> M2 fixes (GCD sampling, Probe.Run spread) -> M3 probes -> M4 promote rules w/ replay scores -> M5 gates+package.
- 13:42 ET steering: new 'lab' capture level (perf measured+reported, not gated; 250 ms runaway backstop); release stays <=2%. Many shadow candidate rules with per-rule IDs + predicted-vs-actual logging; all probes. Lead ranking so far: the miner's cross-run consistent leads are mostly cast-failure/UI-error and UNIT_COMBAT->UNIT_HEALTH sequences (p 0.7-0.94 in 4 BG runs); attribution leads come from replay error breakdown (running now).
- 13:46 v2.2.15: aura-on-me misses are mostly 'none' claims on OTHER players' auras (run9 41, run10 60, run11 60, run12 29) -> candidate aura-me-elim; run12 dm-unit-me C = summon-cadence false claim (94 @13:19:48, truth another player), not timing. GCD: sampler now brackets predicted end (-0.05/+0.05 s); late first-off sample = U not C; learning only from tight brackets.
- 13:49 candidate replay runs 9-12: c-aura-me-elim aura-on-me 40.3->97.2 / 45.3->87.4 / 37.3->88.8 / 38.8->91.0 % with falseSelf unchanged (promote); c-heal-tgt-frame heal-on-target 0->100 % on runs 9/10/11 (n 15/21/16; run12 no scorable) (promote); cadence variants mixed (c-cad-amount run9 87.6->94.8 but run10 69.5->25.4) -> stay shadow.
- 13:51 promoted rules verified on full replay: aura-on-me 40.3/45.3/37.3/38.8 -> 97.2/87.4/88.8/91.0 %, heal-on-target 0/0/0 -> 100/100/100 % (runs 9/10/11), every other category identical. LabProbes.lua added (aura latency hist, heal/absorb detail, mid-combat DM per-spell snaps, post-combat un-secret sweep that verifies aura-on-me claims live via expirationTime-duration + isFromPlayerOrPlayerPet).
- 13:54 lab perf (mock, run-8 BG replay 1800 s): lab 0.722 % vs diag 0.638 % impact; lab probes 576 ms total (0.03 %); shadow rules heal-target 12.9 ms/323, aura-me 9.6 ms/251, heal-me 6.0 ms/92 (max 0.51 ms); perf_bench lab 0.30-0.39 %, storm 0.50 %; worst single call 155.8 ms is the pre-existing DamageMeter handler (133.8 ms at diag in mock) - below the 250 ms backstop.
- 14:06 gates: fixed 8 runner failures from the change (staged probe needs ~35 frames in smoke; hsm GCD test now uses a due-time bracket sample; 2 div-lint reviewed entries; 2 'and x or' idioms; ticker :Cancel; LabProbes SV key moved to labProbes - ForeverDumpLogDB.lab is the workarounds lab's). Re-running full runner.
- 14:17 state: runner run 3 in progress; bg_replay_lab worst single call 254.76 ms (DamageMeter.DAMAGE_METER_COMBAT_SESSION_UPDATED; 133.8 ms at diag in mock) -> fixing root cause now: spread DM heavy work + lab per-spell snaps across frames (coalesced, dirty-only); backstop stays 250 ms.
- 14:22 DM spike root-cause evidence: with GC stopped the worst call drops 200->60 ms (TokenScan.Slice) and DM is not in the top; at test level (tape 68k rows) worst 74 ms vs ~200 ms at lab/diag (tape 216k, recorder 85k): the spikes are incremental-GC steps (heap delta +0..8 KB per spike) landing in the most frequent allocating handler (DAMAGE_METER updates). Applied: DM structure reads + lab per-spell snaps coalesced into one deferred C_Timer job per frame (dirty-only), cached event keys.
- 14:28 runner 4: only luacheck (shadowed local in the new --spikes diagnostic; fixed). bg_replay_lab with the strict single-call check restored passes; DM handler own work < 5 ms without GC; the remaining 170-200 ms worst calls are GC atomic steps in the mock (rows appended during one cycle re-traversed at once). Next: final runner, package.
- 14:30 user decision: collect first, optimize later. Backstop at lab = report (own-frame warning + SV backstop/maxCall/spikes with GC attribution), lab keeps collecting; bg_replay_lab reports only (worst 190 ms, 1 spike, GC-attributed). Coalescing kept (tests pass). Final runner next.
- 14:33 RUNNER OK: 72 tests, 0 failed (EXIT 0). Packaging v2.2.15.
- 14:33 PACKAGED ForeverDump-v2.2.15.zip (224 files, 1,540,853 B, sha256 8d1a9f39727c313b6f9f3c67bde263f0b2d9f0325c97dfb30c1765ef834cff0e); leak check clean; fresh-unzip scan 0 real GUIDs, name hits = v2.2.13 set + 'hots' (the HoTs abbreviation in unchanged guide files, matches a run-12 BG player's name); no real/ or .cache; copied to /workspace/ with the guide and LEADS doc.
- 15:06 run 13 (v2.2.15 lab BG) received: SV 23.7 MB packed (2.1x run 12's 11.4 MB), combat log 8.7 MB starting 13:17 (also covers run 12's window); copied to real/2026-10-09-run13-bg/. Starting decode check + analysis.
- 15:07 run13 decode: converter vs in-Lua SVPack.UnpackAll IDENTICAL on all 5 vars (3.0M literals, 0 secretsDropped, 0 skipped); pack cost in-game 5.3 s total across logout (RecordDB 2.3 s, LogDB 2.1 s); addonVersion 2.2.15 (from 2.2.14 at 1791571280).
- 15:08 run13 capture: verbosity lab (priorLevel release, elevated), 1110.6 s capture 14:46:31–15:05 ET, tape 78,837 rows overflow 0/dropped 0/overwritten 0, worldCapture dropped 0, selfErrors 0 → complete. Perf: own 1.31% (run 12 diag 1.12%), Lab.* only 0.066%; worst wrapped call 14.19 ms (Probe.step, run 12 peak 35.75 ms) → no spikes ≥50 ms, backstop never tripped (cur.backstop/spikes nil).
- 15:09 run13 probes: post-combat sweep (25 sweeps × 8 offsets 0–10 s) cleared NOTHING — UnitHealth/Power/absorbs stay S and GetAuraDataByIndex errors 'Auras cannot be accessed when secret while tainted' for all 200 reads; in a BG the restriction never lifts between fights, so the sweep-based aura-me verification (aura-me-sweep/cand-aura) produced 0 verdicts. Found a probe bug: UNIT_DIED passes a GUID, so labProbes.heal is keyed by ~20 mangled Player GUIDs (SV-only, on box).
- 15:09 run13 live verdicts: gcd 48 V / 12 C (run 12: 2 V / 17 C), so the v2.2.15 GCD bracket fix works in-game. cd-ready 38/6/1, cooldown 176 V/140 U. dm-unit-me still 3 C/19 U. Live cand claims: aura-me 170, heal-target 558, heal-me 43, interrupt 4. cand-heal DM checks are mostly U (19–21 of 22 fights unreadable); heal-tgt-frame 1 V / 2 C. DM per-spell snapshots are readable (K) only out of combat (187 with spells) and T in combat (318). The 600-snap cap dropped 1254 snaps, so coverage stops at t=460 s of 1110 s.
- 15:10 fixed in tree (no release yet): LabProbes UNIT_DIED now counts by GUID type (died.Player/Creature) instead of keying labProbes.heal by GUID. dmSnaps cap 600 → LP.MAX_SNAPS 6000 (run 13 had 1854). lab_v2215 now 51/51 with a new GUID-key regression check.
- 15:10 rule scores, runs 9–13: c-aura-me-tight again gives the same accuracy with fewer false claims on run 13 (87.4%, false-self 2→1, missed-self 12→13, n 111). Its false-self count was lower in 5 of 5 runs, but accuracy dipped 0.6 pt on run 10, so it fails the promote bar. c-cad-phase/tight reach 97.7% on run 13 (+2.4) but lost on runs 9/11/12, so they stay inconsistent. c-heal-tgt-wide adds a false self-claim on run 13 (96.6%); the live heal-tgt-frame scores 100% (n 29).
- 15:15 run13 analyze finished (4m43s, 529 leads). The VERIFY join gives cooldown 97.8% accuracy (225 confirmed / 5 refuted, all 5 'You are dead': V verdicts on casts that failed because I was dead, an analyzer truth-mapping quirk, not a CD error), damage-range 100% (n 49), interrupt-attribution 100% (n 4). Analyzer gap: the VERIFY table shows n=0 for the cand:* P verdicts (it does not count P).
- 15:15 run13 probe histograms: 99.6% of aura adds/removes carry secret payloads on every token (3,557/3,570 on raidN). Player aura adds land ≤25 ms after my own cast 40% of the time (the aura-me-elim cue); party/raid only 6%. UNIT_COMBAT→UNIT_HEALTH is ≤25 ms 75–95% across tokens. My UNIT_HEAL_PREDICTION→HEAL is mostly 1–2 s (34/42 = the cast time). UNIT_COMBAT HEAL amounts stay clear on every token (raidN 556 heals, 42.7k), ABSORB 0. Incoming-heal reads are N (nil) on hostile tokens, S on friendly. Runs 9–12 re-analysis running (2 parallel).
- 15:16 DM reconcile: the analyzer's three-way join is still per-fight, but in a BG the meter session is cumulative (fight 6 meter 1452 = fight 5's 1164 + fight 6's log 288). So the ~25 medium 'dm-reconcile off' leads are analyzer artifacts; the live engine already compares session windows (v2.2.12). The 3 live dm-damage C's (live over meter by +224/+586/+627, 14:54:36, 14:56:44 and 14:56:56 ET) coincide with the 3 dm-unit-me C's; still open.
- 15:19 waiting on runs 9/10 re-analysis (current lib), then 11/12; meanwhile confirmed replay determinism: replay candidate claim counts on run 13 equal the live SV candStats exactly (aura-me 170, heal-me 43, interrupt 4).
- 15:22 runs 9/10 re-analysis at 7.5 CPU-min each (slower than run 13's 4m43; bigger combat logs); perf numbers for the report: run13 lab own 1.31% vs run12 diag 1.12% (+0.19 pt; Lab.* 0.066%, DamageMeter.struct 0.11%, cand rules 56 ms total = 0.005%), worst call 14.19 ms vs 35.75 ms.
- 15:27 re-analysis with the current lib changes the guide inputs: run 9 aura-on-me 40.3→97.2 (n 72) and heal-on-target 0→100 (n 15); run 10 aura-on-me 45.3→87.4 (n 159) and heal-on-target 0→100 (n 21). All other accuracy metrics are byte-identical, so the promotions changed nothing else. Runs 11/12 in progress.
- 15:31 still waiting on runs 11/12 re-analysis; the guide gets regenerated after that.
- 15:32 guide regenerated (14 runs, 193 rows: live 73, proven 5, provisional 14, unsolved 83). aura-mine/target and aura-mine/npc fell from correlated-proven to provisional because run 13 aura-on-target is 80% (n 20). Cause: own-cast-frame claimed 'mine' when another raid shaman's Stormstrike debuff landed on my target in the same frame as my own Lesser Healing Wave on a friendly unit (14:58:38). New lead: require the own cast's target == the aura unit (as heal-tgt-frame does).
- 15:34 runner EXIT 0 (72 tests) with the in-tree LabProbes fixes. Guide copied to /workspace/. Not packaged; whether to release v2.2.16 for the UNIT_DIED/snap-cap fixes is the user's call. In-tree bg_replay_lab still shows a 168 ms GC-attributed single call in the mock (report only), versus the in-game worst of 14.19 ms.
- 15:38 v2.2.16 (final HSM build) started: auditing every 'mine' attribution rule in Lib/HybridState.lua against the target-match / spell-plausibility / ambiguity-guard requirements.
- 15:39 root cause of the 14:58:38 false claim found: my target was a FRIENDLY raider; my LHW (8008) hit it, and 63–210 ms later another player's aura landed on it. own-cast-frame accepted LHW (target matched), but 8008 has no learned spell→aura link. Then 1238640 (a self-buff, inferred target = my friendly target because knowledge lacked 'self') re-claimed the 290.382 aura. Fix = spell plausibility (learned aura link) + correct self-buff target.
- 15:39 snapshot of the v2.2.15 tree kept at /tmp/ForeverDump-v2215-tree for before/after scoring. Design: one attribution gate in the HSM (target match → spell plausibility → ambiguity guard + corroboration); every 'mine' claim passes through it, and a fail gives elimination/other (implausible) or U (ambiguous).
- 15:42 first gated replay, runs 9–13: false self-claims went to 0 in EVERY category (aura-on-me 1/6/10/3/2 → 0; heal-on-me 7/10/5/1/0 → 0). aura-on-target accuracy rose (run 13 80 → 95%), as did damage (run 10 83 → 100%) and interrupt (run 10 33 → 67%). But aura-on-me and heal-on-me lost coverage to U: 1238640 (unknown self-buff, 105 events) and Stormstrike's self-proc (76) lack a learned link, and summon-cadence heals have no corroborator. Next: a live-learned cast→aura-on-me link (timing statistics) and summon-phase corroboration.
- 15:43 learned cast→aura-on-me link (live timing statistics, no log): hit rates split cleanly. Self buffs/procs: 1238640 1.00 (n 104), Grounding 1.00, Stormstrike 0.72, 905 0.89. Everything else 0.00–0.04 (background ≈3%). Seeded from earlier captures' live signals, aura-on-me is back to 95.8/84.9/86.6/89.6/86.5 (≤2.5 pt off before) with false self-claims 1/6/10/3/2 → 0/1/0/2/1. Out-of-sample run 13 (seed from runs 9–12) gives the identical 86.5%.
15:46 ET — v2.2.16: secret-timing was a hidden 'mine' rule with NO target match (prediction without a unit verified on ANY unit's aura in 0.35 s); now target-matched + ambiguity-guarded; 14:58:38 fixture (tests/attr_v2216.lua, 11 checks) bites in legacy mode, passes guarded
15:47 ET — census live (clear UnitClass of raid/party + enemy plates/arena, counts-only 'census' signal); unknown-spell+target-match+no-competitor allowed: runs 9-13 replay identical either way (BG always ambiguous), solo/PvE keeps claims; effTarget via self link fixes aura-on-target run12 50->100, run13 95->100
15:48 ET — 'You are dead' quirk: live HSM now passes UnitIsDeadOrGhost to OnCastFailed -> fail-dead/U (no cdConfirm); analyzer scores precondition reasons (dead/stunned/range…) as 'precondition', not cooldown evidence; secret-timing & SetCensus/SeedSelfLink behind the secret boundary (ARITY fixed)
15:49 ET — analyzer DM join now by meter SESSION window (coverage.session_join): a BG record sums all log fights inside [te-dur,te], straddlers flagged partial; damagemeter_join compares once per session (last fight) vs summed log+live; VERIFY table counts P
15:50 ET — ROOT CAUSE run-13 dm-damage C's (+224/+627/+586): v2.2.15 cast-frame/swing-frame had NO target match and live feeds raidN/nameplateN UNIT_COMBAT; WOUNDs on raid members + other plates inside my cast frame (≈172-286 raid, 446-1516 plates per window) were credited to me. Fixed: gate target match, friendly-wound guard, swing needs ucIsTarget; per-token mine-damage probe (fight.dmg.tok)
15:51 ET — collect-first: lab removes HSM ring caps (inferences/predictions/fights/candAura → none; run 13's fights ring kept only the last 13, which blocked the dm-damage hunt), dmSnaps/sweeps uncapped, d.live uncapped; 182.7 ms peak probe = Perf.Mark at load:begin/svunpack/initdb, login, capture:begin and after each capture module
15:53 ET — new shadow c-hp-net (per-unit net HP from readable UNIT_COMBAT + cached max; live V/C vs clear UnitHealth, re-anchors) + sweep now records instance type, census and per-rule gate counters per fight (open world/PvE sweeps distinguishable)
15:54 ET — GATE APPLIED: aura-me target-mismatch -> other (12/13 right) turns aura-on-me run10/11 losses into gains (87.4->88.1, 88.8->92.5); cadence ambiguity guard FAILED the gate (run10 heal-on-me 69.5->36.4) -> demoted to shadow c-cad-guard, live cadence unchanged; final: 0 gate failures, false-self 56 -> 27 over runs 9-13 (own-cast-frame 28->4, aura-on-target 6->0, interrupt 5->0, damage 1->0)
15:54 ET — v2.2.16 bumped; CHANGES entry; tests/attr_v2216.lua (23) + tests/test_v2216.py (7) registered; starting full runner (no other heavy jobs meanwhile)
15:56 ET — runner pass 1: luacheck long lines, one unreviewed division (c-hp-net err/max, guarded max>0 → reviewed), one and/or idiom → all fixed; waiting for phase 2 before a clean re-run
15:56 ET — dead-quirk scope narrowed to 'You are dead' only (range/stun stay refutations: never loosen; test_v224_tools agrees); clean runner re-run
15:58 ET — RUNNER OK 74/74 EXIT 0 (release/diag gates unchanged; BG replay diag impact 0.651%; lab worst call reported only)
15:59 ET — docs/HSM-STATUS.md drafted (gate definition, before/after tables, inventory live/provisional/shadow/unsolvable, next-BG checklist); re-analyzing runs 9-13 with the v2.2.16 analyzer for the guide
16:06 ET — PACKAGED ForeverDump-v2.2.16.zip (230 files, 1,648,372 B, sha256 97a74847459f59a7e55e0b33b90d773117a47784421a1e08a7b028ba6e0c2901); package.py leak check clean; fresh-unzip scan: 0 of 1175 real Player GUIDs, 0 character names, log-name word set identical to v2.2.15 (dictionary words only); no real/ or .cache; zip + HSM-STATUS.md copied to /workspace/. Guide re-analysis continues
16:33 ET — runs 9-13 re-analyzed with the v2.2.16 analyzer (attr accuracy matches the replay harness; VERIFY counts P; DM join by session); master guide regenerated (193 rows, 14 runs: live 73, cached 6, correlated-proven 7, provisional 12, estimated 1, unsolved 83, not measured 11) and copied to /workspace/ (the zip carries the pre-regen guide)
17:26 ET — run 14 (v2.2.16 sign-off BG, Darkspear Islands 17:15-17:24) staged in real/2026-10-09-run14-bg (SV 16.7 MB, log 3.5 MB, no taint.log); starting decode + analyze
17:26 ET — run 14 first look: fight.dmg.tok = target only (2075; friendly-wound guard rejected 1316 raid WOUNDs, swing target-mismatch 852) ✓; peakMarks: load/login peak 0, capture:begin 0.733, end 13.0 ms (= max call Probe.step 12.98) → run 13's 182.7 ms was set BEFORE capture start, not by capture work; NEW BUG: 5 live 'dm-dispels' C's (live 18-20 vs meter 8-9 ≈ 2x): dispel-cast+dm counts every DM type-6 update in my dispel frame (the meter fires duplicate updates) — no per-cast dedupe; c-hp-net: 0 live verdicts (target health secret in BG)
17:28 ET — run 14: c-hp-net offline vs log HP (all Player dests, all hits assumed visible): V 2291 / C 281 = 89.1% V, median err 1.2% max, p90 5.3% (ceiling; live 0 verdicts since target HP/GUID secret in BG). Dispel double-count FIXED in lib (own.dispelCounted, once per cast); log truth 18 Purge casts / 15 dispels vs live 18-20 by 17:20 when meter said 8-9; test bites on v2.2.16 lib. Bumped 2.2.17, CHANGES entry. Analyze still running; runner waits for it.
17:33 ET — run 14: decode converter vs in-Lua UnpackAll IDENTICAL on all 5 vars (2.15M literals; pack 3.7 s at logout); tape 73,529 rows (24,581 RLE-folded), overflow/dropped/overwritten 0, 0 errors → complete. Perf (lab, reported only): own 1.32% over 576 s, worst call 12.98 ms Probe.step, 0 frames >50 ms, memory +119 MB (lab uncapped). Census: live friendly same-class 2 for the whole BG = log (2 persistent shamans; a 3rd cast twice at 17:21:53-58); enemy same-class live 0 vs log 3, because nameplate class is SECRET in restricted|pvp|raid (tokenscan) → unsolvable, low impact (friendly ≥1 already flagged ambiguity). Replay v2.2.17 = live per rule exactly (heal-cadence 66/67, own-cast-frame 16/17, summon-cadence 3/5); false-self runs 9-14 66→31, 0 gate failures. c-cad-guard run 14: blocked 3, only 1 false (fs 3→2, acc 83.3→81.0) → stays shadow; tested a cadence amount-veto (×0.5–2 of my recent ticks): fs 31→24 but run 10 accuracy 69.5→29.7 → rejected; no corroborator separates chained HST ticks.
17:37 ET — HSM-STATUS §5 sign-off written: 5 items (census friendly done / enemy unsolvable since plate class is secret; cadence stays provisional; dmg.tok target-only; 182.7 ms peak was pre-capture; c-hp-net shadow with an 89.1 % offline ceiling), run 14 per-rule table, recommendation READY for the old-addon migration with 3 conditions. Full runner for v2.2.17 is in phase 2 (perf gates), so no heavy jobs now; packaging is next.
17:40 ET — PACKAGED ForeverDump-v2.2.17.zip (230 files, 1,651,736 B, sha256 412faefd1465cf49e951d9a4dc6d515a589e2b590c0d5a2e4980a19224ae0d79): runner 74/74 EXIT 0 (the first pass failed only on the stale master guide, then the guide was regenerated); package.py leak check clean; fresh-unzip scan 0 of 1217 real Player GUIDs (run 14 included), name word set identical to v2.2.16 (dictionary words + shipped placeholder fixtures); no real/ or .cache. Guide regenerated: 15 runs, 193 rows, live 73→74, provisional 12→13, unsolved 83→81 (pet guid/name unsolved→live; aura-mine/friendly live→provisional, no pvp reading in run 14). Zip, HSM-STATUS.md and the guide are copied to /workspace/.
17:55 ET — NEW TASK (user correction): never stop at 'unsolvable'. Derive through alternate APIs and higher-order inference. Starting with class derivation: inventorying which unit-event payloads the captures hold (tape, recorder, probes) to measure readable spellId and other class signals per unit token.
17:56 ET — class signals found readable in BG (run 14 tape): (a) UNIT_POWER_FREQUENT powerType CLEAR on nameplates/target (RAGE 599, MANA 446, ENERGY 112, COMBO_POINTS 10 on plates) → warrior/druid, rogue/druid, caster split; (b) hostile UnitName CLEAR (C 60 target, C 6 plate) while GUID/class are secret → name hash = stable enemy identity key; (c) DAMAGE_METER sources carry class CLEAR: EnemyDamageTaken lists one row per enemy with class (no id), so enemy class COMPOSITION is readable → the enemy census is solvable; (d) UNIT_COMBAT amount and school clear on plates; (e) others' cast spellIds secret, but START/STOP timing is clear → cast-time fingerprints. Scope per steering: all secrets plus mined reference tables.
17:59 ET — DAMAGE METER CRACKS THE ENEMY CENSUS: in BG the meter lists BOTH teams. Enemy rows have no id (GUID secret) but the class (classFilename) is always CLEAR. Per-capture enemy class composition vs the log: run 11 15/16, run 12 13/15, run 13 13/15, run 14 13/15, run 10 16/19. Enemy shaman count meter = log on runs 10-14 (0/0, 1/1, 3/3, 0/0, 3/3). Source name and GUID are secret in combat but clear out of combat (14 of 16 ooc reads) → name key + class map; hostile UnitName is clear on plates in combat → per-unit enemy class by name-key join. Reference miner tools/fdump/refdata.py: 849 spells (591 class-tagged via 9-class name seed + propagation), 28 summons, class power types. Class truth from the log.
18:02 ET — class derivation offline (runs 9-14, log truth, 15-19 enemies per run in the capture window). (P) power type + (K) meter composition: 0 false assignments on all 6 runs, coverage 7-26%, candidates 9 → 2.5-5 per unit. (C) cast-time fingerprints, conservative buckets: 0-60% accuracy because pushback in BGs stretches START→SUCCESS → NOT used for elimination; probing UnitCastingInfo planned end-start instead. (M) meter name join out of combat: 100% coverage of in-window enemies, median time-to-identify 48-217 s (first out-of-combat moment); accuracy hinges on enemy row names being clear out of combat → v2.2.18 probe. Next: runtime ClassEvidence lib + meter nameKey + enemy census from the meter + probes.
18:04 ET — runtime pieces written: Lib/ClassEvidence.lua (per-identity candidate set; assigning sources direct/meter/score/spell/color, eliminating sources power/comp/summon; contradictions fall back to unknown, never guess); Data/RefData.lua (640 spells: class code, cast time, aura duration, school, cooldown; 28 summons; class power types; build 70291); DamageMeter.Roster/SourceSpells + salted nameKey per meter row; Derive.lua lab module (readability matrix 57 unit getters + 7 pair getters + aura APIs × 19 token families × combat/ooc, meter roster readability, scoreboard and arena-spec probes, cast-info probes, plate class-colour probe, out-of-combat spellId → class learning per build into ForeverDumpDB.refLearned); HSM enemy census now takes the meter's same-class count. Next: tests, then the derivation inventory.
18:05 ET — tests: tests/derive_v2218.lua (24 checks: power and composition elimination, the druid shapeshift case, contradiction → unknown, RefData spell assign, meter name-key join, enemy composition from displayType 2 only, census feed, scoreboard assign with realm strip, no raw names stored) and tests/test_v2218.py (miner on a synthetic log: seed + propagation, 2-caster and multi-class spells left untagged, summon owner, cast time, privacy; poisoned fingerprints). Both pass and are in the runner. Next: the derivation inventory for every guide row.
18:05 ET — derivation inventory under way: computing offline estimates for aura identity on others (aura-duration uniqueness), the same-class tie-break (other shamans' cast timing near auras on me), and enemy max health by class/level (mined), so the guide's derivation column carries numbers.
18:06 ET — derive offline estimates: aura identity on others from duration alone is unique for 1.0% of 27.6k applications, 5.3% with the caster's class, so identity needs the caster cast-frame join. Same-class tie-break by HST tick phase against each friendly shaman's cast times: other shamans' ticks exclude me 35/35, my ticks keep me 204/215 (94.9%). RefData now mines classLevelHP (106 class×level cells: enemy max-health base). Derive learns own cast times per build and flags build/spell drift (tests 28/28).
18:07 ET — derivation inventory written (tools/fdump/derivation.py): 31 guide value families plus 9 extra families (census, same-class, aura source, others' spellIds, per-enemy meter, race/level, pet owner, scoreboard, spec), each with path, readable inputs, offline estimate and probe key. Wiring it into the guide (derivation column + section) next. Also added the refdata --learned merge (votes, conflicts, cast-time drift; newer build wins) and global probes (GetTotemInfo 1-4, arena/score counts).
18:08 ET — derivation column is live in the guide (HTML+MD): all 201 rows now carry a path (83 direct, 37 derived, 58 derivable, 23 bound, 0 'unsolvable'), plus a 40-line derivation-paths table covering 31 value families and 9 HSM families. New UnitClass guide row: the hostile nameplate class is secret S52 in pvp, which the class engine covers. A test enforces a path for every guide row. Next: HSM-STATUS section 6, then the version bump and release.
18:08 ET — HSM-STATUS: section 3 rewritten as 'former unsolvable', each row with its path and offline estimate; section 6 added (class engine per-run table, RefData and learning/drift, the non-direct inventory, next-BG tests). Release v2.2.18 next.
18:11 ET — release checks: runner found 2 real lint issues in the new code. (1) Derive probed CheckInteractDistance without the combat guard (it is combat-protected; it was removed from Derive, and WorldCapture already probes it guarded). (2) 9 luacheck warnings, fixed. Full runner rerun now.
18:13 ET — v2.2.18 shipped: ForeverDump-v2.2.18.zip (239 files), sha256 cdae7811…3ed9. Runner 76/76 OK; leak check clean; fresh-unzip scan: 0 GUID hits; 9 new word hits vs v2.2.17, all spell/item names in refdata (Ghostly Strike, Rain of Fire, Camp Chair, Highland Venom…), no player names. Copied the zip, HSM-STATUS and SECRETS-GUIDE html/md to /workspace.
18:40 ET — v2.2.19 start: out-of-combat pre-fill cache plus a full unit-token sweep. Surveying Identity.lua, the HSM world units and Derive.READ_TOKENS so this extends them instead of duplicating.
18:42 ET — the existing pieces already do part of this. Identity.lua feeds the HSM ledger (token→GUID→class/level/maxHP in memory) and scans player/target auras out of combat; Derive owns the class engine plus the meter and scoreboard sweeps. v2.2.19 adds Lib/UnitCache.lua (per-key facts with source, time, context and TTL; static-fact contradiction → unknown; dynamic drift counted; GUID-key↔name-key alias merge), with OocFill.lua on top as the sweep driver.
18:43 ET — OocFill.lua + Lib/UnitCache.lua written. Tokens are enumerated from the client (GetNumGroupMembers/GetNumSubgroupMembers, MAX_BOSS_FRAMES, arena counts, C_NamePlate.GetNamePlates), with their *target and *pet variants. One unit seen via target/plate/raid merges onto one key (GUID key, name-key alias), so in combat a GUID-secret plate still resolves via the name. Cached class pre-assigns the class engine; ooc aura scans feed learned aura durations and spell→source-class votes; meter and scoreboard classes go into the cache. Shadow rules: tt-attacker, tt-same-class. tests/oocfill_v2219.lua 27/27; secret, protected-API and div lints pass with OocFill added to the secret lint.
18:44 ET — secret injection (4 modes) now drives OocFill too (ReadToken on every family, in and out of combat, edges, events, Step, aura scan): 11/11 per mode, no secret touched. Offline scoring next. Insight: the v2.2.18 engine already keeps knowledge across fights within a session, so the honest pre-fill gain is measured per fight episode against a reset-per-fight baseline, with the scoreboard as the upper bound.
18:45 ET — offline pre-fill on runs 9-14, per (enemy, fight) episode: class cached at the enemy's first event in 86.6-95.5% of episodes (75.8-83.6% weighted by the 14/16 ooc name readability); identity seen before in 86.6-95.7%. Friendlies 100% (raid tokens). NPC max health from RefData 79-98%. Enemy max health from class×level has a median error of 12-26% (gear spread, so exact clear reads are needed). Class time-to-identify median goes from 6.6-9.4 s (reset per fight) to 0 s cached; means 9.5-13.4 s → 0.3-4.1 s.
18:47 ET — full runner 78/78 OK (oocfill_v2219, test_v2219, secret lint/injection with OocFill). Packaging.
18:47 ET — v2.2.19 shipped: ForeverDump-v2.2.19.zip (244 files), sha256 2b7a6f9d…65fd. Leak check clean; fresh-unzip scan has 0 GUID hits and no new name hits vs v2.2.18. Zip, HSM-STATUS (section 7) and SECRETS-GUIDE html/md copied to /workspace.
19:43 ET — run 15 received: identifying the two attachments (a 4.2 MB txt and a 1.4 MB zip) and laying them out as real/2026-10-09-run15-bg like run 14.
19:45 ET — run 15 identification: the txt is a WoWCombatLog (19:28:36-19:38:46 ET, Darkspear Islands, advanced logging, build 1.60.1). The zip holds ForeverDump.lua (16.7 MB, written 19:16 ET), addonVersion 2.2.19 (installed at 19:09:08 ET per versionHistory). BUT capture never ran under v2.2.19: logs.on=false, last toggle 17:24:52 (run 14), and the only capture in the SV is run 14's (cap-20261009171516-34). oocfill/derive hold only empty stop stubs (0 units), no refLearned. The SV predates the BG by 12 min, so the live test lists cannot be answered from this SV. Decode check of the v2.2.19-written pack: Lua UnpackAll = Python converter on all 5 vars (identical digests). 0 errors, no new blocks since run 14.
19:46 ET — run 15 offline (log-only; my combat windows rebuilt from the log; vs the tape on runs 13/14 they overlap 72-74% with end times 1.4-4 s apart). Class engine: P+K 1/1 correct (6.2% coverage, 0 false), M join covers 16/16 with a median TTI of 41.4 s. Enemy comp: 4 shamans, 3 priests, 3 warriors, 2 hunters, 2 rogues, 1 paladin, 1 druid. RefData rebuilt from 16 logs: 863 spells (+14), 503 class-tagged (+16, 0 class flips), 30 summons, 36 NPCs, 125 class×level cells. Run 15 moved 3 median cast times by 0.5-3 s (pushback), so cast time is now the 10th percentile of START→SUCCESS.
19:47 ET — run 15 = log-only (capture was off); v2.2.20: BG-entry reminder (own frame) + opt-in logs.autoBG, Stop-without-Start no longer writes stub tables
19:48 ET — tests added (bgentry_v2220 11/11, test_v2220 3/3); derivation estimates now runs 9-15; writing HSM-STATUS §8
19:49 ET — castTime p10 with median fallback (712 Fel Dom bimodal); RefData regenerated; HSM-STATUS §8 + CHANGES written; next: master guide
19:49 ET — master guide: run 15 listed as log-only (no state change, 201 rows, 14 changes = run 14's); starting full runner for v2.2.20
19:55 ET — real run 15 SV arrived (cap-20261009192835-45, v2.2.19 live); runner aborted; re-doing run 15 analysis on the real capture
19:57 ET — run 15 real SV: decode identical (Record/Log/CombatLog exact; DB = DB+Static merge), 6 selfErrors = Derive channel spellID used r[8] (secret notInterruptible) -> fixed r[9]; lint S2 now catches and r[N] or; Derive.lua joins SECRET_MODULES
19:58 ET — oocfill.read (BG): enemy plates name/level/powerType/faction clear 100%, class/guid/race/sex/hpMax secret 100% in every context; arenaN class 91-100% clear (2 tokens); live prefill enemy class 0/99 vs offline 88% -> investigating meter->cache join
19:59 ET — KEY: live class engine 'comp' rule made >=6 false enemy assignments (10 enemies -> SHAMAN, truth 4; 3 of them have rage/energy power) -> root-causing
20:00 ET — NEW READABLE: GetBattlefieldScore name(1)/faction(6)/race(8)/localized class(9) clear on 100% of rows (2432 ooc, 446 combat; both teams) while classToken(10) is secret -> enemy class by name key for all enemies; arenaN class clear but never reached the engine (key kind mismatch?)
20:02 ET — oocfill identity: every friendly read (raidN 4992, raidNtarget 888, ...) landed on ONE cache key (class -> unknown, 1158 drift); mock can't reproduce; fix = Link never merges two GUID-rooted keys + conflict counter
20:03 ET — client build is now 70334 (RefData shipped 70291 -> drift flag set live); learned spellClass polluted by DamageTaken sources (25/107 disagree w/ RefData) -> learn from DamageDone/HealingDone only; perf lab 0.96% own (OocFill 0.18%, step max 4.6 ms)
20:04 ET — v2.2.20 rules: comp -> provisional only (cumulative), reading sources override elimination classes, contested units never settle by elimination; NEW assigning rule score-bf (GetBattlefieldScore name+localized class+faction); tests 33/33
20:05 ET — offline (real tape) run 15: P+K 1/1 0 false 6.2%, M 100% TTI 40 s, prefill class 88.2% — but live prefill enemy class 0/99 because enemy meter names are secret in BG (0/5594 rows): M join refuted live; score-bf replaces it
20:05 ET — derive.read (hostile players, BG): clear = name, level, faction, powerType, UnitDistanceSquared 100%, UnitIsUnit 92-98%, reaction/selection colour; secret = class/GUID/race/sex/health/power/PVPName. Plate bar colour clear but matched no class colour (0/327). Auras error in every BG context
20:07 ET — RefData regenerated with the full run-15 log: 963 spells (540 class, +53 tagged, 0 flips), 21 cast-time moves; DM name keys now realm-stripped (meter/score/plate keys never met live); score join diagnostic bfJoin added
20:08 ET — HSM-STATUS §8 rewritten for the real run-15 capture (13 items answered with numbers, rule table, next-BG list)
20:13 ET — CHANGES v2.2.20 written; fdump analyze on run 15 still running (~10 min) to bring run 15 into the master guide
20:18 ET — run 15 analyzed into the master guide (16 runs; changed since run 14: enemy healthMax pvp mixed->secret, incheal/aura-mine nil shifts); starting full runner
20:20 ET — runner #1: 4 fails = my shell's stale LUA_PATH (luacheck/busted/converter) + secret lint on the bfJoin realm flag; fixed, re-running full runner
20:21 ET — runner 80/80 EXIT 0 (perf release OK, lab reported); v2.2.20 zip 246 files sha 0e07a96d…; 0 GUID hits; name word-set grew 59→130 only because the full run-15 log doubled the known-name set (1045→2347): all new hits are spell/item/code words, none from characters.json
20:27 ET — v2.2.21 start: user reversed privacy rule (store raw GUIDs/names, no scrubbing); mapping IdKey/anonymize call sites
20:30 ET — addon now stores raw: IdKey=kind:<raw> (npc:<id> kept as group key + raw GUID g), DM rows guid/name/unitName, Derive units[key].names/guids, OocFill name/guid/guild facts, ScrubKey identity, chat/probe redaction off; package.py byte-identical check replaces scrubber
20:33 ET — toolchain raw: package byte-identical, fixtures regenerated RAW from run 1 (same 1029 lines/1023 CLEU), anonymize.py removed, guide privacy gate/correlate redaction/learned strip off; leak tests converted to raw round-trip asserts. New rawjoin.py: SV raw GUIDs (CL meter snapshots: name+GUID+class; inference.signals) join 1:1 to the log
20:34 ET — round-trip test (raw_roundtrip.lua + test_v2221.py): GUIDs + 'Name-Realm' byte-identical through capture→SVPack→loader→json/replay→analyze→rawjoin; fixed correlate crash on span-less SV. rawjoin runs 9-15: CL meter snapshots list 0 enemies on 9-14 (friendly only), run 15 15/16 enemies but only in the capture-stop snapshot
20:36 ET — lint/luacheck clean after renaming raw* locals (lint treats raw* as unclassified API values); derive/oocfill/inject suites green. Next: docs + guide regen + full runner
20:36 ET — raw-join insight: in-BG meter snapshots list ONLY my team with clear GUIDs on runs 9-15 (enemy GUIDs secret), so measured M = 0% live (was simulated 100%); run 15's post-BG stop snapshot lists 15/16 enemies, 100% class-correct. Docs: CHANGES v2.2.21, HSM-STATUS §9
20:37 ET — guide regenerated (201 rows, class entry now cites measured M); test_identity/test_master_guide converted to raw; starting full runner
20:39 ET — runner #1: 3 fails (smoke asserted CVar/name/GUID/chat redaction, v224 asserted learned anonymize, fixture spec asserted Player-0000 placeholders) → converted to raw asserts; raw fixture replays identically (377 aura applied / 19 swings / 2 deaths). Re-running
20:40 ET — runner 81/81 EXIT 0 (release 0.022%, lab 0.47% reported); v2.2.21 zip 249 files, all byte-identical to source, sha 6232e163…; layout same dirs (fixture files renamed raw, +raw tests/rawjoin/fixturepack, −anonymize/guid_scrub); copied to /workspace
20:47 ET — unhash start: recover per-capture salts of pre-2.2.21 IdKeys by brute force (known GUIDs from logs), then rebuild raw maps
20:49 ET — salt formula confirmed: floor(GetTime()*1000)%2147483647 + sessionCounter*9973; GetTime() = hdr.t0; run15 salt=1216956013 (c=47) → 109 matches incl. own GUID Player-4618-00EB40D8. Hash32 C+Python parity with Lua 2000/2000. Building fdump unhash
20:52 ET — unhash tool ready (C h32 + Python parity); running on all real/ captures → sv_raw/
20:57 ET — run15 now 80.6% (150/186) after harvesting raw GUIDs/names already in the SV; remaining mostly guild:* and a few orphan guids; multi-salt merge + chat guild harvest next; processing all runs
21:12 ET — unhash stalled: all-runs job died after run6 (only 15 hashed keys, 1 player hex — min_hits=3 too strict); run15 done 80.6%. Lowering threshold for sparse SVs, parallelizing remaining runs 6–14
21:19 ET — unhash parallel batches finished; summarizing
21:19 ET — batch2 timed out at 180s (salt search hashed every name×candidate); fast path now GUID-only for salt find. run12/13/14 done ~72-79%; waiting run10/11, then retry 6-9
21:20 ET — done so far: run11 66.7%, run12 78%, run13 71.7%, run14 78.9%, run15 80.6%; pre-IdKey runs 1-5 clean; retrying timed-out 6/6b/7/8/9/10 with GUID-only salt search
21:27 ET — retry batch finished
21:28 ET — root cause: min_hits counted session:* keys (run6 had 1 player match but min_hits=2); deep rewrite of 50MB SVs timed out run8-10 after salt was found. Fixed both; re-running 6-10
21:30 ET — HARD RULE: only 100%-restored runs stay in analysis; finishing 6-10 then resolving leftovers (guild/session/multi-salt) or EXCLUDE
21:32 ET — rainbow/guess probe on run15; classify job still walking runs
21:35 ET — retry2 done
21:36 ET — targeted fill (tokens+SV strings only vs unresolved hexes); retesting run15

21:39 ET — finishing salt recovery for runs 7-10; probing session/guild IdKey call sites
21:42 ET — run6 session: names are Blizzard meter session labels (only 1/14 match combat NPCs); finishing salts for 7-10 next
21:47 ET — unhash fix: stop bloating amap with all_ids (that hung patch on 15-73MB SVs); re-running 7-10
21:49 ET — salts 6-10 done: 6/6b/7/10 at 100%; 8=83.9% 9=93.9%; refreshing 11-15
21:53 ET — 11/12/13 at 100%; 14=98.2% (1 guid); 15=87.1% (guilds); probing leftovers
21:56 ET — inclusion manifest written (12 included / 4 excluded); test_unhash_inclusion OK; regenerating master-guide on included set
21:58 ET — master-guide regenerated (12 runs); offline scores in out/unhash-score/; updating HSM-STATUS §10 with numbers
21:59 ET — DONE: 12 included / 4 excluded; master-guide+scores+HSM §10+test gate live
23:13 ET — run16 arrived: identifying zip contents, checking version/freshness
23:13 ET — run16 FRESH: v2.2.21 cap-20261009225225-51 (22:52 ET), 0 hashed IdKeys; laying out real/2026-10-09-run16-bg
23:14 ET — inclusion rebuild showed 11-13 manifests stale (66-78%); re-unhashing to restore 100%
23:14 ET — run16 convert pipeline starting (errors/perf/analyze/inference)
23:16 ET — run16: 0 hashed; perf 2.11% lab (reported); extracting next-BG metrics 1-8
23:20 ET — building run16 truth + per-unit class false-assign; scanning secret-compare markers
23:21 ET — run16: census exact match; 1 false (Johnny SHAMAN<-raidN vs ROGUE); live rawjoin 34/34 correct; digging tt-attacker + spellClass + Johnny
23:23 ET — v2.2.22 fix: Allow/Power revokes non-ASSIGNING class when eliminator contradicts (Johnny name-key collision)
23:23 ET — derive_v2218 41/41; running analyze + master-guide + packaging v2.2.22
23:29 ET — packaging ForeverDump-v2.2.22; running inclusion + derive + unhash tests
23:29 ET — ForeverDump-v2.2.22.zip sha256 b1dada8f…; launching full runner
23:31 ET — score-bf join: Forever "First Surname" vs UnitName "First"; fixing before v2.2.22 ship; runner had 4 fails
23:32 ET — implementing score-bf firstName+faction join with ambiguity guard
23:36 ET — derive_v2218 44/44; offline-scoring bfJoin firstName+faction on runs 16,10-13
23:44 ET — T-container audit: 17 sites fixed (addon+tools), 15% GetScoreInfo claim retracted, REMEASURE rows, regression tests; bfJoin sim runs 16,10-13 (0 false)
23:48 ET — runner GREEN 84/84; ForeverDump-v2.2.22.zip rebuilt (score-bf + T-audit) sha256 0ee083b03ab8…
00:15 ET — run17 arrived: identifying SV zip + combat log, checking v2.2.22 freshness
00:16 ET — run17 is FRESH (cap 23:52 ET, saved 00:13) and 0 hashed IdKeys, BUT addonVersion=2.2.21 (no v2.2.22 probes: no scorePhase/@phase keys) on client build 70334; re-measure limited to already-per-field sources
00:16 ET — KTH diag (build 70334, 30p) GetScoreInfo: name/className/classToken/faction CLEAR in prep/ooc/combat/post; guid/talentSpec/stats SECRET until post; race N. KTH FORBIDDEN on AceEvent RegisterEvent at 23:51:53, 0 FD errors
00:17 ET — FOUND: Forever GetBattlefieldScore layout = name,KB,HK,deaths,honor,faction,RACE(7),CLASSNAME(8),CLASSTOKEN(9),damage(10),healing(11)...; FD read race from pos8 and 'classToken' from pos10 (=damage, secret) -> classToken is CLEAR 100%, earlier 'classToken secret' claim wrong; class assigns worked only via fallback
00:17 ET — run17 live (v2.2.21): 15/15 enemy score units correct but keyed 'First Surname' -> 14 enemy plate units classless; v2.2.22 rule sim on run17 board: 15/15 enemies assigned, 14 meet plates, 0 false (GUID-checked)
00:20 ET — GBS positions fixed (race=pos7, class=pos9 token / pos8 localized); v2.2.20-22 class right by accident, race wrong (= className) -> raceMismatch skips + polluted race prefill; runner 84/84
00:20 ET — census: scoreComp == truth enemy comp exactly (15); meterComp misses 1 rogue. learned spellClass(70334): 134 truth-checkable, 125 agree, 10 disagree (2 'pure' wrong: 11790, 1248759) -> purity gate insufficient alone
00:21 ET — run17 added to inclusion manifest (0 hashed, included). Key correction for re-sim: oocfill_score's cached-meter path assumed enemy meter names clear ooc (14/16, from EXCLUDED run 14); run17 measures CombatSource.name S for all 15 enemies in BG ooc+combat (0/15406 rows) -> that path is 0
00:21 ET — re-sim (included BG runs 10-13,16,17; 141 enemies, 2071 episodes): first+faction join 100% join, 0 dupFac, class at first event 100% vs P-only 0-8% (TTI median 8-12.5 s -> 0); world runs 1-7 have no scoreboard (skipped)
00:22 ET — derivation.py: 8/10 REMEASURE rows now MEASURED (run17), aura-payload + aura-count still need v2.2.22+ capture; tests/test_v2223.py added
00:22 ET — run17 replay exported to /workspace/kth/tests/replay (30 roster w/ REAL board names, 4 healers, 52k resolved ev); stream loads in lua5.1
00:23 ET — HSM-STATUS §13 (run17 sign-off, re-measure table, changed claims, scores, re-sim) written
00:23 ET — guide regenerated (201 rows, newest run17; 2 NEEDS RE-MEASURE left); v2.2.23 bumped + CHANGES; running full runner
00:24 ET — runner GREEN 85/85; shipped ForeverDump-v2.2.23.zip sha256 cd2f1f7ac255fd9c9befe716b013817c997ea6c537fa572323299ce0c5977abd (no real/ or .cache). Next capture must actually run 2.2.23 (run17 was 2.2.21) for live bfJoin + @phase + aura T counters
01:02 ET — run18 arrived; identifying files
01:02 ET — run18: SV addonVersion 2.2.23 OK, 0 hashed (raw), capture 00:37:29 ET; combat log is run17's log continued (prefix identical) -> cut at 00:37:09 ZONE_CHANGE into WoWCombatLog.txt
01:02 ET — run18 FD: 0 Lua errors, 56 events all ADDON_RESTRICTION_STATE_CHANGED (no FORBIDDEN/blocked for FD); perf 2.03% wall (was 2.47%), top OocFill.step 0.71 ms x6397 = 4.6 s, Recorder 6.8 s; FD mem +351 MB
01:04 ET — run18 live class engine: 0 wrong class (45 units; GUID-level 30/30 ok); all 15 enemies assigned via score under name:<First> (v2.2.22 join works live). 1 flag error: friendly Clam marked enemy (combat log shows Clam as hostile 0x1148 = mind-controlled) -> sticky MarkEnemy
01:04 ET — run18 prefill LIVE: enemyPlayer class 234/235 (99.6%; run17 0/214), level 235/235, hpMax 0; census scoreComp == truth (15), meterComp 9/15; tt-attacker none x275
01:05 ET — aura 'taint' root cause: NOT FD-specific. Client 12.1-style rule: aura enumeration APIs raise 'Auras cannot be accessed when secret while tainted by <addon>' for ANY insecure (addon) caller while auras are secret (combat/PvP/BG); same error reported for Questie, WarpDeplete, Ace3, ForeverChronicle on Forever. FD errors are all inside its own pcalls (0 Lua errors, no Blizzard UI path tainted). No FD code to 'untaint'; fix = stop enumerating while secret (sampled circuit breaker)
01:05 ET — v2.2.24 fix implemented: ClassEvidence MarkFriend (unique friendly scoreboard row clears/vetoes enemy mark; run18 Clam MC case) + tests/v2224_friend.lua (7 checks). Also found: enemy UnitName realm == scoreboard surname 45/45 plates (runs 16-18) -> exact full-name join available
01:06 ET — log-truth bug: refdata marked a player hostile on ANY hostile flag -> MC'd friend Clam counted enemy; fixed (pet-type flags don't vote, majority side); only run18/Clam changes. Re-sim run18: 15 enemies, 100% join, class at first event 100% vs P-only ~1%
01:06 ET — run18 replay exported to /workspace/kth/tests/replay (29 roster, real names, 6 healers incl. friendly MC'd Clam Slap DRUID), loads in lua5.1
01:06 ET — HSM-STATUS §14 written; derivation aura rows reworded (client rule, not FD taint)
01:08 ET — runner GREEN 86/86; guide regenerated (15 runs, 0 NEEDS RE-MEASURE); shipped ForeverDump-v2.2.24.zip sha256 dabc9fa32a697735c4b87e97385f62ed883355014b170347653d8cfff9e8f5cf
01:13 ET — v2.2.25 start: Q1 answer = v2.2.24 does NOT contain the full-name join (proposal only). Reading API inventory for aura presence APIs
01:14 ET — signatures: AuraIsBigDefensive(spellID)->bool, GetAuraCasterGUID(unit, auraInstanceID), GetUnitAuraBySpellID(unit, spellID)->AuraData (baseline 70245). Mining healer-signature auras from included logs
01:14 ET — curated ~45 aura IDs from included logs (counts above); starting BG-only audit grep
01:15 ET — Core ns.Env/EnvTag + AuraGate (env-keyed breaker, 30 s hold, 1 sample) added; Derive reads env-tagged (ooc@bg/gates), aura enumeration gated; exact full-name join added as primary (seenFull from UnitName realm), first+faction fallback
01:17 ET — AuraPresence.lua written (45 curated IDs, GetUnitAuraBySpellID per env tag, GetAuraSlots H|P, AuraIsBigDefensive, GetAuraCasterGUID, change-only tape); audit fix: Inference GetAuraSlots breaker was keyed ooc/combat only (keyed by ctx only, no env; a BG error could hold counts off in world combat until a restriction event) -> AuraGate env-keyed; OocFill/Identity scans gated; CombatProbe env stamp + arenaN tokens; dungeon/raid capture reminder
01:19 ET — exact join refined: a first name listed twice on the scoreboard now keys tokens by 'First-Surname' (own engine unit per player; was: both shared name:First); tests/v2225_exact.lua 12/12; guide probe_ctx now env-aware (ctx@env counters in svinspect), legacy heuristic kept for old runs; offline scorer tools/fdump/aurapresence.py written
01:20 ET — tests: v2225_exact 12/12, v2225_env_aura 28/28, test_v2225 6/6; version bumped 2.2.25; curated-ID occurrence runs 10-18 counted (16188 NS and 15473 Shadowform 0 hits; Water Shield 408510 18, Maelstrom 408505 34); next: docs, guide, runner, package
01:23 ET — runner 89/89 OK after 2 lint fixes (unused locals, unreviewed MOD in rotation -> plain wrap); guide regenerated (15 runs); packaging
01:23 ET — SHIPPED v2.2.25 (data-collection): ForeverDump-v2.2.25.zip sha256 a47a9b4d20f4f36201938c67bf69290acb5c89988043c90d50e24a1c02c51b54, 268 files, no real/ or .cache; runner 89/89. Next capture answers: GetUnitAuraBySpellID presence N vs S/E per env (auraPresence.codes) + aurapresence.py score
10:43 ET — run19 arrived (Darkspear Islands, CL 10:24:14-10:40:28 ET); raw stored real/2026-10-10-run19-bg (CL, FD SV, KTH HHTD SV + diag), identifying
10:45 ET — run19: FD v2.2.25 on client 70338 (new build), 0 Lua errors, 34 restriction events only; perf 2.40% wall (budget 2%); KTH live = forever.7/8 (not .9: icons unmigrated), /kthdebug timeline present (16 reads)
10:49 ET — run19 aura presence (v2.2.25): GetUnitAuraBySpellID returns NIL (not secret, no error) for every unit incl. player in prep/gates/combat (~200k calls, 0 P); post-match K=80 with all fields clear; own Lightning Shield present per log yet nil -> nil != absent in BG. aurapresence.py JSON key crash fixed
10:50 ET — guide: fixed master_guide probe-cell eviction (v2.2.25 env-mapped pvp cells evicted older 'combat' cells; BG-only legacy runs now map combat->pvp); regenerated: 16 runs, 12 changes since run18
10:52 ET — run19 FD done: castGUID+spellID secret on every non-self token (806 UNIT_SPELLCAST_SUCCEEDED, 0 clear), castBarID clear but per-cast opaque; nameplateMaxDistance default 45, user set 100/500/1000 in BG (CVAR_UPDATE ok, no range change); runner 89/89 + 2 new guide tests
11:00 forever.10 (KTH): no FD code change in this step; FD guide/runner state from run 19 unchanged (89/89)
11:46 run20 (RFC dungeon, PvE): start; KTH parked
11:47 run20: raw stored (CL cut at 11:38:13 COMBAT_LOG_VERSION, original kept verbatim as WoWCombatLog.original.txt); FD 2.2.25 + build 70338 verified; 0 hashed; no static data in SV
11:47 run20 key result so far: GetUnitAuraBySpellID in dungeon OOC = K (clear AuraData, all 8 fields C, 68 hits), in dungeon combat = N for every unit incl. player (10.7k+11.7k calls) -> same as BG combat; UNIT_AURA payload clear OOC, secret (isFullUpdate S, addedAuras secrettable) in combat
11:49 run20: pvescript.py (CL truth x recorder x replay decides x presence tape) written; clock offset fitted 1.000s (38 own casts); aurapresence scored: OOC 52/52 agree, combat 3/3 false-absence (A while present)
11:50 run20: fixed converter bug - aurapresence/pvescript mapped epoch->log time in the BOX zone; now use the log's own '-4' zone (refdata.log_utc_offset) + auto clock offset; tests/test_pvescript.py (6, green in 7 TZs) registered
11:52 run20: master_guide bug fixed - 'restricted' ctx in a dungeon was filed as PvE combat (probe) / pvp (containers); new 'inst' column (PvE instance OOC); run19 ProbeCtxEviction tests were dead (after __main__) - moved + 2 new; guide regenerated 17 runs, 75 changes
11:54 run20: guide now ooc|inst|combat|icombat|pvp columns (instance runs no longer overwrite open-world PvE cells: 0 status regressions) + new aura-presence row (GetUnitAuraBySpellID) from svinspect/5; 204 rows
11:56 run20: perf 0.83% wall (368 s); errors 0; 14 'blocked' rows are ADDON_RESTRICTION_STATE_CHANGED logs (no ADDON_ACTION_BLOCKED); static dump in SV is 70291 (lastClientBuild 70338) -> no 70338 reference refresh possible
12:00 time audit: fixed parse sites (kth logtruth.parse_ts, clientlog epoch+year rollover, refdata/classderive ordinal day, report clocks in client zone via timefmt); Lua source (not shipped): CombatLog utcOffset->Core, AuraPresence anchor->TimeAnchor, Drift civil-day math; now running TZ impact reruns
12:07 time audit: TZ reruns (NY/UTC/Kolkata/Chatham/LA/Kiritimati) - aurapresence r19/r20, pvescript r20, resim_v2223, oocfill_score, rawjoin, KTH export_replay r10-19 + replay_score r16-19: byte-identical across TZs and to prior NY outputs (no prior result changed); old-code emulation under UTC breaks KTH token resolution (run10 72318 -> 10196 resolved, nHealers 0)
12:10 time audit done: 21 sites, 6 bugs fixed (logtruth.parse_ts, refdata month rollover, aurapresence/pvescript box zone, clientlog zone+year, display clocks, test_v2225 fixture) + 3 Lua source fixes (not shipped); tests/test_tz_matrix.py + time_lua.lua x7 TZs in runner; runner 111/0 FAIL; docs/TIME-AUDIT.md
12:10 run20: outputs refreshed with audited code (pve/events.json+EVENTS.md, aurapresence.json); final report + next-probe proposals delivered; no FD build shipped
12:12 run21 OPEN-WORLD ANSWER: auras are NOT readable in open-world combat either. GetUnitAuraBySpellID: combat N 10965/10965 (player 5676, target 5289; 0 K) vs ooc K 110 (all 8 AuraData fields C); scored vs log: ooc 220/221 agree (+6 edge), combat 4/4 false absence; UNIT_AURA payload combat K{ST} 88/88 (isFullUpdate S, lists <secrettable>) vs ooc K{CK} 39/39; aura probes in combat = 'aura APIs error' (GetAuraSlots secret while tainted) 23/23. ADDON_RESTRICTION type 0 toggles 1/0 with each of the 4 fights. Same as dungeon (run20) and BG (run19).
12:14 run21: raw stored (CL cut at 12:05:50 ZONE_CHANGE Thousand Needles, original kept), FD 2.2.25, 0 hashed -> included; pvescript bug fixed (truth counted other players' Flame Shock/Stormstrike/interrupts/totems: run21 Flame Shock 123->16 rows, run20 unchanged) + test; guide regenerated 18 runs (aura-presence combat column now open world nil); perf 0.75% wall 228 s; errors 0; runner green
12:17 v2.2.26 start. (1) DST fixed offline: refdata.lines keeps the file's first zone (rows in another suffix shifted by the difference); clientlog infers fall-back/spring-forward from the wall clock; tests +6 DST cases (python) +5 (Lua: Core utcOffset across both switches). Investigation run21 health: UnitHealth/UnitPower are S for EVERY unit OOC incl. player itself (54/54) and non-existent tokens, with all restriction states 0 -> not PvP/friendly specific. Lesson: check 'player' and a non-existent token before attributing a secret to unit type.
12:18 v2.2.26 Lua: AuraPresence probes a-f + health context written (U unknown while restricted; list curated 43 + AuraSeed 96 mined from runs 19-21 + learned OOC, cap 160; OOC AuraData detail tape; totems per slot; own-cast derivation D; restriction flips per env); tests/v2226_aura.lua 25/25. Lesson: 'restricted' must be measured (player GetAuraSlots clear?) not inferred from env - dungeon OOC has Map restriction yet auras are clear.
12:22 v2.2.26: scorer U/D + v2226 extras (runs 19-21 rescored: identical, v1 tapes); CHANGES/TIME-AUDIT/ADDON-USAGE updated; guide regenerated; runner 0 FAIL (also whole runner under TZ=UTC 0 FAIL). Lesson: run the WHOLE runner under a foreign TZ - it found test_v2225 depending on the box zone, which the converter matrix missed.
12:23 PACKAGED ForeverDump-v2.2.26.zip (280 files = 2.2.25's 268 + 12 new, byte-identical, sha256 28b2cb21...d7bd); fresh-unzip v2226_aura 30/30. Lesson: keep the probe semantics honest at the source (U, not A) instead of correcting offline.
12:35 v2.2.27 start: remove curated 43 + AuraSeed 96 lists; candidates = learned OOC (UNIT_AURA payload + slots, per build) + observed own-cast->aura pairs + per-build spellbook cache from /fdump static run; budget-sized limit.
12:37 PROGRESS v2.2.27: lists removed, dynamic candidates + measured limit in; v2227_dynamic 25/0. Lesson: the existing tests silently depended on the curated list (BigDefensive 20216, target 774) - dynamic lists need explicit learn steps in fixtures.
12:38 PROGRESS: limit sized from real perf (AuraPresence.tick in runs 19-21: 0.0057-0.0123 ms/call upper bound) -> 30 ms/tick -> 357 candidates worst case before measurement. Lesson: per-handler perf windows already in the SVs answer budget questions without a new probe.
12:38 PROGRESS: grep of addon+tools for ID lists: converted CombatProbe dispelSpells (10 IDs) -> spellbook cache; rest are mined inference seeds (proposals). Lesson: descriptions ('Lasts 10 min', 'removing') give a cheap per-build aura/dispel flag without any ID table.
12:42 PROGRESS v2.2.27: runner 121/0 FAIL local + TZ=UTC; rescore r19-21 aurapresence scores identical (only empty v2226/tapeVersion keys added since stored outputs), pvescript r20/r21 byte-identical NY+UTC. Lesson: rescoring needs the player GUID arg - an empty --mine silently yields 0 events, looks like a regression.
12:43 PACKAGED ForeverDump-v2.2.27.zip (280 files: -AuraSeed.lua -auraseed.py +v2227_dynamic.lua +docs/STATIC-LISTS.md), sha256 e80b4a72...947ced; fresh-unzip aura tests green. Lesson: a dynamic list starts empty on a new build - the first OOC minutes (and /fdump static run) are what populate it, so captures should begin with a short OOC buff/target pass.
13:58 run22: start (BG, FD 2.2.27 expected) - unpack raw
13:59 PROGRESS run22: FD 2.2.27 / client 70338 confirmed (meta). Aura presence ran with 0 candidates the whole session: auraLearned/auraPairs/spellCache[70338] all empty, no /fdump static run (static marker nil), BG-only session -> every tick restricted (GetAuraSlots secret-taint error in prep/gates/combat) -> nothing learnable. Lesson: dynamic-only list has a cold-start hole: a fresh build that goes straight into a BG measures nothing.
14:00 PROGRESS run22: bug 1 (fixed) AP rotation counted presence calls not units -> with 0 candidates all 89 tokens probed per tick (21 units/tick measured, 1.67 ms/tick vs 1.06 run19). Gap 2: v2.2.27 ignored two dynamic per-build stores already in the SV: refLearned[70338].auraDur (51 auras learned OOC by OocFill) and knowledge[70338] (11 own spells with parsed auraDuration) -> would have given candidates in this BG. Lesson: grep for existing learners before adding a new store.
14:01 PROGRESS run22: GetTotemInfo in BG: every field S except icon, which is N for an empty slot and S for a live totem -> per-slot totem presence side channel; vs CL summons (34): empty->N 5076/5076 samples, totem->S 2741/3079 (89%), 0 false positives. Health: UnitHealth/UnitPower S in every ctx/unit incl. player OOC on 70291/70334/70338 (runs 9,15,21,22) -> not PvP/restriction-driven. Derivation sim (same-ID rule, knowledge durations) vs CL: applied 36/48, end within 1.5 s only 7/34 (Stormstrike charges, Frost Shock early, LS charges). Lesson: duration-only derivation over-claims presence in PvP.
14:02 PROGRESS run22: fixes in (rotation; candidates from refLearned.auraDur + knowledge; same-ID knowledge derivation, consumables skipped; list refresh 60 s) + tests v2228_run22 (10) and test_run22_tools (derivesim, totemscore: slots found from PLAYER_TOTEM_UPDATE rows 6/8/6/14, no element table). Lesson: the event rows' slot argument gives the totem->slot map for free.
14:04 PROGRESS run22: guide regenerated (19 runs). Fixed guide bug: a run with EMPTY aura-presence codes (0 candidates) evicted older cells (pvp clear -> '-'); test added. Remaining 6 changes are newest-run-wins flips: class/guid on arenaN tokens alternate C/S across BG runs (C runs 8-12,14,15,19; S 13,16-18,22) and hctx shows arenaN can be FRIENDLY in a BG (friend=1 34 rows) -> family mapping, not a build change. Lesson: newest-wins per cell needs a hostility split before a flip means anything.
14:07 PACKAGED ForeverDump-v2.2.28.zip (284 files = 2.2.27 + derivesim.py, totemscore.py, v2228_run22.lua, test_run22_tools.py), sha256 da08a884...d380f; runner 122/0 FAIL local + TZ=UTC (correction: the v2.2.27 report said 121, the runner printed 120). run22 report: real/2026-10-10-run22-bg/out/REPORT.md. Lesson: always quote the runner's own count line.
14:07 PROGRESS cold-start: own spellbook + descriptions are NOT restricted in BG: Knowledge passes at capture:on in BG prep (13:39:25) and at BG combat (13:41:47) read 77/77 spells, description C 77/77 (1 N ooc), tooltip K. So an automatic spellCache build is possible in prep.
14:08 PROGRESS cold-start: carry-over (auraLearned/auraPairs seeded prov 'prev-build:<b>', refLearned/knowledge/offline fall back to newest earlier build), auto chunked spellCache on PLAYER_ENTERING_WORLD (20 spells / 0.05 s, OOC only), empty-list warning at Start in. Lesson: keep provisional data visible as its own source tag so scoring can separate it.
14:10 PROGRESS cold-start: offline Data/LearnedAuras.lua generated (70245:119, 70291:439, 70334:352, 70338:331 auras from 19 logs; deterministic; staleness test). Acceptance v2228_coldstart 31/31: run 22 replay as-is -> 60 candidates at first tick (knowledge 11 + ooclearn 49); as fresh build 70400 w/o offline -> 60 at first tick, +35 spellcache after the auto build (80 spells, 4 timer steps). Lesson: older tests silently picked up the new shipped data file (mock build 70245 is in it) - isolate data sources per test.
14:10 PROGRESS: steer received - library (schema 2: one entry per spell with builds confirmed, CL+SV merged, cast->aura pairs, rank base by name) + rank grouping in the addon + before/after counts on runs 19-22. Runner interrupted mid-run (no result taken).
14:13 PROGRESS library schema 2 wired: addon reads LA.spells (offline / offline-prov by per-entry builds), library pairs n>=3 as derivation fallback (17364->1238931 self n=567), rank groups (<=2 IDs own/live, 1 library-only); runs 19-22 with library: 582 -> 405-408 candidates (limit 357). LESSONS: the CL writes the aura row ~2 ms BEFORE its cast row (pairing must look back; fixed in both generator and addon, 292->378 pair sources); grouping alone (2/ability) cut only 12% - the library holds every rank anyone used, so library-only groups need 1 rank.
14:19 PROGRESS v2.2.28 packaged (290 files, sha 6ce09322...a5aa, fresh-unzip toc syntax OK, coldstart 39/39 against the unzipped addon); runner OK 124/0 local and TZ=UTC. LESSONS: two runners in parallel made test_v2211_svpack fail (load/memory), run them sequentially; same-instant mock clocks now pair auras with the next cast (EARLY_WINDOW) - older tests advance the clock.
14:21 PROGRESS v2.2.29 start: design = per-unit job queue drained in OnUpdate under a wall-share budget (5% of frame time, 0.2-1.5 ms/frame), tiers H 1 s / W 3 s / C 10 s by source + rank plausibility (C_Spell.GetSpellLevelLearned, AllowedWhenTainted per the 70245 API inventory) vs UnitLevel/UnitClass; limit -> runaway backstop sized from cost. LESSON: no per-build rank learn levels are stored anywhere yet (knowledge has none) - must be collected live; only cost evidence is 0.0057-0.0123 ms/call (runs 19-21 tick windows).
14:23 PROGRESS v2.2.29 core in: Check/Enqueue/Drain (OnUpdate, wall-share budget), tiers H/W/C via AP.Plan(class, level) with GetSpellLevelLearned cache, sticky-present per unit, budget-adaptive rotation, backstop limit, chunked BigDefensive, combat-flip tagging (AP + Restrictions). Old tests adapted (limit -> backstop; rank cut -> tiers). LESSON: with a frequency scheme the rotating units, not the candidates, dominate staleness (3 units/tick with 25 BG units = 9 s per visit x tier C 10 = 90 s) -> rotation must follow the budget too.
14:29 PROGRESS v2.2.29 replay sim (tools/fdump/measure_sched.lua, virtual clock 0.012 / 0.0057 ms per call, BG 27 units, 120 s): v2.2.29 582/582 candidates, 100 % (unit,id) coverage, frame max 0.98 ms, wall 2.85 %; v2.2.28 357/582, 61.3 %, frame max 22.3 ms. LESSONS: the sim found a real bug (queue[qHead]=nil left holes -> #queue reset lost jobs -> units stuck 'pending'); the mock answers GetSpellLevelLearned=1 for everything - a level that never varies must count as unknown; the 1 s tick itself was the hitch (2 ms) until it moved into OnUpdate and its unit work into the job start.
14:32 PROGRESS v2.2.29: OnUpdate now installed by the tick and self-removing when idle (perf lint onupdate-every-frame), div-lint guards + reviewed entries, arenaN split by hostility in the guide (guid/enemy-player pvp mixed->secret, incheal/enemy-player secret->nil), CHANGES/ADDON-USAGE/STATIC-LISTS. LESSONS: FD's own perf lint caught an always-on OnUpdate - wake-on-tick + self-remove costs nothing idle; the arenaN C/S flips came from friendly arena tokens folded into enemy-player.
14:37 PROGRESS v2.2.29 packaged (292 files, sha 2648b4ee...34e4; fresh unzip: toc 53 files syntax OK, v2229_sched 30/30 on the unzipped addon). Runner 126/0 local and TZ=UTC. LESSON: luacheck flags 'not (x > 0)' NaN guards - write 'x ~= x or x <= 0' to keep the intent explicit.
15:15 HANDOFF start: inventory /workspace (foreverdump 5.4G incl .cache/svcache 2.3G pickles + tools/refresh/.cache 912M CDN work; kth 131M; research 122M; idtip 3.8M; keyhunt 1.4G = beta-key giveaway poller, unrelated to addon), attachments 343M. Lesson: 2/3 of the 5.4G is regenerable cache - inventory before sizing.
15:17 HANDOFF: hardcoded /workspace paths fixed in 42 code files (kth tools/tests, tz tools, test_tz_matrix, research guide) -> WOWDEV_ROOT env or nearest parent holding foreverdump/; KTH regress R1-R8 still ok. Nested .git dirs (16) found incl. local-only history (kth/port 16 commits, ui-source extract, idtip fork) -> will ship as git bundles. Lesson: grep for absolute paths in tests too - KTH harness loaded FD's mock by absolute path.
15:19 HANDOFF: staged /workspace/handoff/stage/foreverdump-handoff (foreverdump minus svcache/tests-out/wowlua build, kth+releases, research, idtip, keyhunt->other/, 154 user uploads, 17 git bundles). Root ForeverDump zips are byte-dupes of foreverdump/; KTH release zips + older root HSM/SECRETS docs were NOT in any project dir -> copied. Lesson: hash-compare root strays before calling them duplicates.
15:20 HANDOFF: HANDOFF.md, AGENTS.md/GROK.md, handoff-tools (manifest/verify/mtimes/setup/bundles/fetch_reference/git_push), .gitignore/.gitattributes (* -text) written. Lesson: git clone resets mtimes and master-guide --check is mtime-based -> MANIFEST keeps mtimes + restore_mtimes.py.
15:21 HANDOFF: docs written (README, HANDOFF, AGENTS/GROK, MEMORY, docs/RUNS|REFERENCES|INVENTORY, captures/UPLOADS-INDEX.tsv); building MANIFEST + 4 part zips. Lesson: no zip/rsync on the box - python zipfile with symlink entries + stored mode for compressed files.
15:24 HANDOFF: zips built (core 270 MB, captures 412 MB, cdncache 670 MB opt, keyhunt 109 MB opt); fresh unzip core+captures verify_manifest ok=19680 missing=0 mismatch=0; running setup + full runner in bwrap with /workspace hidden (tmpfs).
15:30 HANDOFF: fresh copy (/workspace hidden via bwrap): runner OK 126/0 FAIL; luacheck 0/0; master-guide --check fresh. KTH R8 FAILED in the fresh copy: export_dm.py wrote the absolute SV path into the .dm.lua header and R8 compares byte-for-byte -> header now root-relative, 4 meter files regenerated (bodies identical), R8 ok on box. Lesson: generated files must not embed absolute paths when a provenance test compares bytes.
15:37 HANDOFF: fresh-copy results: runner OK 126/0 (local + TZ=UTC), luacheck 0/0, KTH R1-R8 ok, run22 totemscore reproduces REPORT (5076/2480). Found: master-guide --check STALE once after SV mtimes change (cache rebuild pass), OK on 2nd check -> open work item, restore_mtimes after clone. Rebuilding core zip + manifest. Lesson: simulate git-clone mtimes, not just unzip, before calling a repo portable.
15:39 HANDOFF DONE: /workspace/handoff/{part1-core 270 MB, part2-captures 412 MB, part3-cdncache-optional 670 MB, part4-keyhunt-optional 109 MB}.zip + MANIFEST.tsv (30,553 files) + ZIPS.sha256; all 4 parts unzip+verify ok=30553 mismatch 0. Lesson: os.walk lists symlinked dirs under dirnames - manifests must add them explicitly or they silently vanish.
