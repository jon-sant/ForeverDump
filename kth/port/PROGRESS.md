09:31 forever.6: forensics done; group-share rule A (k==n, share>=63%) 0 FP on runs16-18; team healer counts measured 0-4
09:31 forever.6: candidate model backtest 9/9 precision, 9/9 recall, 0 flips (runs16-18)
09:33 forever.6: variants backtested (grp60/63/70, weak2, nocap); optimistic early-read sim written (flags Torvian n=1 risk)
09:33 forever.6: R10 named real-data cases added (pass on f6, 4 FAIL on f5 as expected); run13 sanity unchanged
09:34 forever.6: docs (D10, forever.6 section, README, review, tests README), SCORES/REGRESS-forever.6 written
09:35 forever.6: committed 6176018, packaged KillTheHealer-Forever-1.0.0-kth-forever.6.zip sha256 920002a0…42f1, smoke ok
09:45 forever.7: start (inventory FD SVs runs 16-18 for live in-combat readability)
09:47 forever.7: FD inventory: enemy plate UNIT_SPELLCAST spellID secret 100% (runs16-18); labProbes.dmSnaps found (2316/3111/3047), checking content
09:47 forever.7: FD has all PLAYER_REGEN_ENABLED times (28/24/27) but its meter ring kept 21 -> early KTH reads lost in replay; validating log reconstruction of meter rows
09:48 forever.7: spellID secret for every non-self token in all captures (runs 6,7 world/dungeon; 8,13,16-18 BG); log meter reconstruction NOT exact (0-1 of 35-41 snapshot types) -> no substitute; FD per-source meter = 21/BG only
09:48 forever.7: UnitLevel clear on hostile plates (FD codes only, values not captured); deriving healer-only spell list
09:49 forever.7: healer-only list verified on runs 1-18 logs: KEEP Swiftmend 18562, Holy Shock 1311605; DROP Penance 402289 (DPS Severn cast it)
09:50 forever.7: spec-only fast path + /kthdebug meter/verdict log implemented, regress ok; measuring spec sources (talentSpec, arena specs, roles, inspect) in FD
09:50 forever.7: spec sources measured: scoreboard talentSpec secret prep/gates/combat/ooc, clear post-match only (runs 18 + KTH diags); arena spec / roles / inspect: no capture of other units (unmeasured); specIconID class-only
09:51 forever.7: spec layer (arena spec IDs, group role HEALER, post-match scoreboard talentSpec, healer-only spell sets spec) + plate level logging; regress rerun
09:51 forever.7: heal-link timing recorded; computing per-healer first-heal->mark latency
09:52 forever.7: latency table: median mark-first heal 433 s (274-1006); bounded by meter readability (first kept snapshot 381/230/593) + plate sightings; heal links give no speed (healers' first links at 480/1105 s) and a false provisional (Joff 360-593 s)
09:52 forever.7: synthetic R11 (healer-only spell), R12 (low-level healer), R13 (arena spec, group role) pass; port7 = port6 on real BG replays
09:53 forever.7: regress 0 FAIL incl. time-to-mark ceilings; writing docs
09:53 forever.7: docs + toc 1.0.0-kth-forever.7
09:54 forever.7: packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.7.zip sha256 ec21e8b2…5926 (commit 87de3db); smoke ok
09:59 forever.8: start (user's healer-only list: Penance, Power Infusion, Prayer of Mending, Light's Vigil, Wild Growth, Riptide)
10:00 forever.8: IDs resolved: FD DB2 SpellName (1.60.1.70245) == wago.tools 1.60.1.70245 for all 6 names; Wowhead Forever pages confirm talent ranks; logs show only Penance 402284/402289
10:02 forever.8: list swapped to user's 6 spells (62 IDs); R11 42/42 ok, regress 0 FAIL; port8 = port7 on runs 16-18 (9/9, 9/9, 0 flips); combat-log sim written (tools/sim8.py)
10:02 forever.8: docs (FOREVER-PORT D12 + section, README, REVIEW, tests/README), toc 1.0.0-kth-forever.8, regress rerun
10:02 forever.8: packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.8.zip sha256 8453a831…f777 (commit 4c35b07); smoke ok
10:24 forever.9: start (HHTD sprite icons on Forever plates)
10:26 forever.9: HHTD sprites bound into Midnight path (NPH tables reused), R14 ok, regress 0 FAIL, scores unchanged
10:26 forever.9: packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.9.zip; smoke ok
10:43 research: nameplate range on Forever (FD CVar dumps, HHTD 2.4.27 source, online sources); no build
10:43 run19: arrived, raw stored /workspace/foreverdump/real/2026-10-10-run19-bg; scoring forever.9 live
10:45 run19 live: enemy healers Danukeru 10s, 汇源 37s; FALSE mark 梦之旅程 (feral DRUID, RAGE) via class-group rule; post-match 'scoreboard spec <ClassName>' unmarks all (bug)
10:47 run19 held-out replay: forever.6-9 identical: enemy plate recall 2/2, precision 2/3 (feral 梦之旅程 FP), TTI med 16.6 s; forever.3 2/5; forever.5 1/2. Truth edge: Moun (Renew HoT priest, share .74) & Grassy (late resto) miss hoN>=5 rule
10:48 run19: experimental druid form-veto (RAGE+ENERGY share) backtest 16-19: >=40% -> 11/11 precision, 0 flips, no 16-18 change; 50/60 still flip (mark before veto). NOT shipped (tuned on run19)
10:51 forever.9b: /kthg GUI offers hhtd/hhtdmin (Options presets + defaults), R15 ok, regress 0 FAIL
10:51 forever.9b: packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.9b.zip; smoke ok
10:52 run19: FIX (port, not packaged): specKindFromName -> nil for class-name/unknown talentSpec (live 10:40:27 unmarked all healers on final board); R16 ok (fails on forever.9), R17 run19 held-out added; regress 0 FAIL; SCORES-run19.md
10:53 forever.10: start (truth incl. HoT, druid form tie-break, meter min-count + elimination, R16/R17) on top of 9b
10:54 forever.10: truth v2 (HoT ticks count: share>=.30 & >=5 heal events incl ticks) -> only changes: run19 Moun (E) and Grassy (F) become healers; runs 16-18 unchanged
10:55 forever.10: kmin/elim/form/linkNet implemented (CFG switches); 16-18 unchanged in all variants; run19: elim claims Moun, linkNet=2 stops 梦之旅程 link mark; investigating a 汇源 revoke
10:58 forever.10: kSharePct=65 margin for kmin (run18 Joff 60.05%), tie-break no longer shrinks the all-rule group; 16-18 9/9+9/9 0 flips R10 ceilings equal; run19 2/2 plate precision, claims 6/6, Moun claimed (plate last up t+91, proof t+488); R17 rewritten (not held out), R18 added; full regress 0 FAIL
10:59 forever.10: docs (D14/D15, README, tests/README), SCORES-forever.10.md; packaging next
11:00 forever.10: packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.10.zip sha256 13090b8e…df75 (395 files, on top of 9b: only ForeverEvidence.lua + KTH.toc differ in AddOns/KTH); smoke ok (0 errors, 0 chat, same 30 guarded globals as 9b); packaged replays == source; regress 0 FAIL
11:14 forever.11: start (on top of forever.10): threshold GUI + overrides, debug checkbox wiring, perf measurement
11:17 forever.11: threshold setting + overrides wired (E.thresholds), debug switch unified (checkbox = /kthdebug, gates timeline/plate log/DebugLog); replays: defaults, explicit 60%, all overrides 60%, debug on and debug off all identical to forever.10 on runs 16-19 (marks, flips, recs, mouse-over); debug off captures 0 rows
11:17 forever.11: R19 (90 checks: defaults, GUI->verdict, precedence, debug switch) + R20 (16 replays == forever.10) added; full regress running
11:18 forever.11: perf harness (KTH_PERF) in replay_score.lua; run19 total K.T.H. CPU ~155 ms over a 17-min match (debug off)
11:18 forever.11: perf done (tests/results/PERF-forever.11.md): worst second 0.18% (debug off) / 0.22% (on) of a 60 fps frame budget; worst single frame burst 0.39 / 0.45 ms; largest call meter read 0.62 / 0.73 ms. No optimization needed
11:19 forever.11: docs (D16/D17, README, tests/README), SCORES/REGRESS/PERF-forever.11; full regress 0 FAIL (109 ok); packaging
11:19 forever.11: packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.11.zip sha256 058d624e…dd94 (429 files; 5 KTH files changed vs forever.10); smoke ok (0 errors, 0 chat), R19 ok from the package, packaged replays == forever.10
11:28 forever.12: start (on top of forever.11): remove teamMax, 5 more General-tab settings, reset-all fix
11:30 forever.12: teamMax deleted (runs 16-19 identical to forever.11: the cap never bound); 5 settings via E.cfg proxy + GUI; Reset tab fixed (shared MNP_ResetSettings: live table, all 11/12 settings, debug default); R21 (88 checks) + R22 added; full regress running
11:31 forever.12: docs D18-D20, README, SCORES/REGRESS/PERF-forever.12 (perf unchanged: 0.18% worst second); full regress 0 FAIL (120 ok); packaging
11:31 forever.12: packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.12.zip sha256 74d2001a…3b54 (478 files; 4 KTH files changed vs forever.11); smoke ok (0 errors, 0 chat), R19+R21 ok from the package, packaged replays == forever.11
