# ForeverDump real-data pass: progress (updated by the executor)

- [x] Real data unpacked (sv/, WoWCombatLog.txt, taint.log); converter ran: info, json/luals/luacheck/mocks (`all`), combatlog, taint, errors, ketho, check(idTip)
- [x] Converter fixes: invalid UTF-8 in SV -> JSON crash; combat log ENVIRONMENTAL_* advanced-block order, v22 ST/AOE scope marker, isOffHand padding; error attribution; Ketho compare (C API vs C API, events, ui-source filter); cl-compare Forever mode
- [x] Addon 2.1: FD_Logs = capture everything (+ resume after reload, OFF synchronous + /reload, /stopmacro [combat]); logout saves sessions; UTF-8-safe truncation; error attribution; compact SV (full option)
- [x] Secrets map: addon `Secrets.lua` (per API/event/field observation counts out/in combat/encounter, `secrets` state section, probe stores state); converter `fdump.py secrets` -> out/secrets/{secrets.json,SECRETS.md}; LuaLS stubs annotated; mocks return secret sentinels (wow.secretMode); apicheck `secret-op` rule (fdump/secretflow.py)
  - real dump headline: 79 distinct flags; 5121 documented functions (19 always-secret, 201 conditional, 5 partial); returns 29 always / 295 conditional; SecretArguments AllowedWhenUntainted 3025 / AllowedWhenTainted 123 / NotAllowed 36; events 7 always / 85 conditional / 2 partial; payload fields 15 always / 388 conditional / 829 NeverSecret; 0 runtime observations (v2.0 run saved no probe/recorder data; v2.1 FD_Logs run needed)
- [x] BugGrabber/BugSack coexistence: callbacks (BugGrabber_BugGrabbed via setupCallbacks/RegisterCallback), poll mode via GetDB(), chain otherwise; FD_Logs OFF + `/fdump errors bg` copy BugGrabber session errors -> ForeverDumpLogDB.bugGrabber; tests/buggrabber.lua (3 paths)
- [x] Secrets VERIFIER: live issecretvalue/canaccessvalue tally per event/API position with context buckets (ooc|combat|enc / instanceType / self|other), throttled getter sweep (108 candidates in mock), live contradictions (persisted, stamped), /fdump secrets live panel; converter `verify` -> verify.json + VERIFY.md (CONFIRMED / CONTRADICTED / UNOBSERVED / UNDOCUMENTED-SECRET + coverage); mocks/stubs/apicheck prefer verified data, stubs mark [verified]/[unverified]/[CONTRADICTED]
- [x] Common timebase: session IDs + anchors (GetTime/time()/GetServerTime/utcOffset, refined at a time() tick) on recorder/CL/capture sessions, probes, errors, blocked, contradictions
- [x] `xref` timeline (timeline.jsonl + TIMELINE.md, per-line source/secret status/match quality) + tests/test_xref.py (synthetic file log)
- [x] Migration toolkit (`migrate`, `migrate-db`): 109 curated + 373 Blizzard_Deprecated shim entries; tested on idTip 10.5.1 and SimpleItemLevel v19 (Nov 2022) - see below
- [x] Real-data runs: out/verify (0 observations: v2.0 data, all UNOBSERVED), out/xref (1029 file lines, 5 combat segments, 8 addon records; no addon/file matches possible without v2.1 logs)
- [x] Anonymized fixture pack fixtures/forever-70245 (`fdump.py fixtures`, leak scan 0 hits; 299 player GUIDs / 297 names / 7 pets mapped) + tests/spec/forever_fixture_spec.lua (3 busted tests)
- [x] Docs (ADDON-USAGE v2.1: FD_Logs, verifier, persistence/timebase, BugSack note; tools README: secrets/verify/xref/migrate/migrate-db/fixtures), CHANGES v2.1, ForeverDump-v2.zip rebuilt (82 files, 422 KB, no real/ref/data/.cache/tests/out)
- [x] Full suite green: luac 19/19 addon files + 8 test/tool Lua files; luacheck 0/0 in 27 files (addon alone 0/0 in 19); SMOKE OK; CONVERTER OK; busted example 7/0, replay+fixture 9/0; fallback runner 7 passed; BUGGRABBER OK; XREF OK; MIGRATE OK
- [x] Final report delivered to the parent (19:45 EDT)

## Migration toolkit update (19:40 EDT)
- [x] `migrate` runs: idTip 10.5.1 (May 2023, pre-secrets) -> out/migrate-idtip-10.5.1/MIGRATION.md
  APIs: removed 3 (C_TradeSkillUI.GetRecipeReagentItemLink, SpellBook_GetSpellBookSlot, GetGlyphSocketInfo), signature-changed 6
  (GetMouseFocus, GetSpellBookItemInfo, GetSpellInfo, UnitAura/UnitBuff/UnitDebuff), renamed 1 (GetItemGem), now-secret 1 (UnitGUID), ok 21;
  TOC: Interface 100100 error + 3 legacy Interface-* keys; 3 secret-flow findings on UnitGUID (lines 252-254).
- [x] control: our ported idTip (build/idTip) -> 0 TOC/taint/flow findings, only now-secret notes (no false removed/renamed).
- [x] deliberate fixture tests/legacy_addon covers every status (real dump): removed, replacement-missing, renamed, signature-changed,
  deprecated-shim, protected, now-secret, ok; events restricted/renamed/removed; 7 taint patterns; TOC errors. tests/test_migrate.py (mock SV).
- [x] SimpleItemLevel v19 (Nov 2022): out/migrate-simpleitemlevel-v19 -> removed 2 (GetVoidItemInfo, GetVoidItemHyperlinkString), signature-changed 1 (IsAddOnLoaded), renamed 5 (GetAddOnMetadata, GetDetailedItemLevelInfo, GetItemInfo, GetItemInfoInstant, GetItemQualityColor), TOC Interface 100000 error

## v2.2 (21:30 EDT)
- [x] Bug B fix (no hooks; regress b-v21 reproduces 7 errors, b-v22 0), verifier v2.2 (run 2: 0 CONTRADICTED / 0 UNDOC vs 7 / 5 in v2.1; 481 CONFIRMED, 4 INCONCLUSIVE), restrictions tracker, controls/ops, lab
- [x] Combat probe set + detectability, unit token survey (26 families), spell knowledge, inference engine, Lib/HybridState.lua, HSM window (/fdump hsm, auto with FD_Logs), baseline + in-game drift alert
- [x] Converter: ops, lab, combat (guide combat/1), tokens, knowledge, inference (+ hsm/1 JSON + offline replay), drift, baseline, guide; drift inside `all`
- [x] Lua/Python FNV docs hash parity (fixed a 2^53 precision bug in the Lua multiply)
- [x] Run-2 outputs: real/2026-10-07-run2/out/{ops,lab,combat,tokens,knowledge,drift,inference,guide} (v2.1 SV: probe reports empty by design); baseline fixtures/baselines/70245
- [x] Barrens replay (owner Uglaz, Player-4618-00EB40D8; "Pally-Palzy" not in the log): clear recall 100%; secret 11.1%; secret-pretrained 55.6% with aura 5/5, cooldown 4/4, amount 3/4 (one crit)
- [x] Guide integrated (tools/guide, fdump.py guide), SECRETS-GUIDE.html regenerated from run 2 (0 warnings, html5lib 0 errors), at zip root; samples not shipped
- [x] Tests: luacheck 0/0 (39 files), SMOKE, hsm 51/0, CONVERTER, busted 7+9, BUGGRABBER, XREF, MIGRATE, REGRESS, V22 367 checks (5 /run snippets <= 255)
- [x] ForeverDump-v2.2.zip (114 files, 974 KB)

## v2.2.1 (21:55 EDT)
- [x] Addon writes player identity (UnitName/UnitFullName/GetUnitName(player,true)/realm/normalized realm/GUID/class/level/race, secrecy codes, anySecret) to ForeverDumpDB.meta.identity on every capture start
- [x] Converter picks the log owner from the SV identity (GUID, then name), then optional tools/fdump/characters.json, then 0x511; --player/--forever-player accept GUID / "First Last" / first name / Name-Realm
- [x] Anonymizer scrubs first + last names and GUIDs from the SV identity + characters.json; leak scan includes them
- [x] Tests: hsm 54/0, IDENTITY 37 checks, full suite green; ForeverDump-v2.2.1.zip (117 files, 984 KB)

- [x] Run 3 (v2.2.1 in-game, shaman Uglaz Doomaxe): all reports in `real/2026-10-07-run3/out/` (FINDINGS.md). The identity block was
  clear (no secret field; UnitName returns first/last). The 36 blocked "UNKNOWN()" = CheckInteractDistance on friendly units in combat.
  Taint: 36 expected / 3 contained / 3 probe-blocked / 1 blizzard-frame (ChatFrame1 print) / 0 unexpected. In-combat aura APIs error for
  addon code (no count, no fields), and the UNIT_AURA payload is T (nil vs secret only).
- [x] Addon 2.2.2: probe attribution + learned/static combat skip; own print sink; Containers module (recursive schema per context ×
  unit class, SV + baseline diff); HSM totems as summons (PLAYER_TOTEM_UPDATE/GetTotemInfo), dispels, history; HSM window labels/values;
  parser fixes; identity last name. Converter: `containers`, taint classes, summon/dispel offline scoring, cooldown window, replay gap
  cap, knowledge seeding; guide "Partial secrets and containers". Tests: hsm 77, V222 26, busted containers 6, full suite green.

## v2.2.3 (run 4, 23:45 EDT)
- [x] Run 4 (v2.2.2 in game): frame-rate drop traced to `ns.Meta()` → `pairs(_G)` (52,517 globals, ~17 ms) on hot paths. The HSM redraw
  hit it once per text line at 5 Hz, and the lines grew with casts; it also ran per UNIT_AURA (containers db) and per lockdown probe
  read. In game the application frame time rose 20.7 → 59.3 ms over the 86 s capture and ForeverDump memory grew +23.8 MB.
- [x] Fixes: cached project info / `ns.Build()`; amortised bounded push; Appliers cache; per-frame context cache; counts() skip; O(1)
  ObserveEvent exit; unit/aura cleanup; dirty-only 10 Hz HSM redraw with no idle OnUpdate; HSM layout rows; live knowledge feed +
  observed/timing verification.
- [x] Perf.lua self-perf monitor (ForeverDumpLogDB.perf) + `/fdump perf`; converter `perf` (PERF.md) and `perfcheck`; taint classes
  benign-chat / own-frame contained.
- [x] PERFORMANCE.md standing rule + 2-minute cap; perf_bench (25/50/100 + aged, --cap 100) and perfcheck in the default runner
  (pipefail); migrate Performance section; mocks perf_guard + perf_spec.
- [x] Bench: v2.2.2 per frame 1.5/2.6/5.2/9.5 ms after 1/2/4/8 casts (57-64% impact; 3.0-3.6 ms/event); v2.2.3 0.004-0.009 ms/frame,
  0.026-0.047 ms/event, flat to 2,110 casts, 0.04-0.08%, 0 idle OnUpdates.
- [x] Tests: hsm 92, V223 26, perfcheck 0/0, PERF OK, full suite green (61 s).
