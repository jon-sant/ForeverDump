23:21 start: KTH review+port task
23:21 KTH 1.0.0-kth (CF file 7908947, 2026-04-11, sha256 0af2610b...) downloaded via CF API -> kth/original. LICENSE: All Rights Reserved (KTH + HHTD headers). Ace3 libs BSD; LibNameplateRegistry by Wellesz.
23:25 KTH read: enemy path relies on UnitClass on plates (secret in Forever BG), talentSpec scoreboard (secret live in Forever, clear only 90/2877 ooc rows run16), mana-only priest/druid rule (invalid in Classic-era Forever: all priests mana). Now inspecting capture event rows for replay.
23:27 truth built (logtruth.py): healer = heals-on-others >=30% of output & >=5 direct heals. INSIGHT: scoreboard names are 'First Surname' while UnitName/log give 'First' -> ForeverDump bfJoin none:base 100% (run16); two 'Johnny' in run16 = first-name collision. run12/13 logs overlap (same BG).
23:28 token->identity resolver built (UNIT_COMBAT amount join, clock offset 0.33s run16; raid tokens 95-99% stable). Same-frame join: 125/423 raid casts have a HEAL on another token at dt=0. API check: C_NamePlate.GetNamePlateForUnit, C_Spell.GetSpellName, C_Timer.NewTicker, C_PvP.GetScoreInfo documented for Forever; TOC 16001 (1.60.1.70334, WOW_PROJECT_CAMELOT=18). Writing the clean-room addon now.
23:31 addon written: Core/{Init,Safe,Engine,Driver}.lua, Data/HealSpells.lua (mined from runs 1-8,14,15; holdout untouched), UI/UI.lua, TOC 16001. Insight: raid/nameplate cast spellIDs are secret in captures (only player/targettarget clear), so detection must rest on frame-join (cast + UNIT_COMBAT HEAL on another same-side token in the same GetTime frame); scoreboard pos 9 classToken is clear -> class known for everyone via first-name+faction join.
23:32 STEERING: user wants a real port of KTH's own code (not clean-room). Switching: copy original tree, apply minimal Forever diffs, keep a DIFF list. Clean-room engine pieces (frame-join, scoreboard join) will be reused as the substitutes inside KTH's structure.
23:36 reading KTH Core/MidnightNameplates done. Forever facts: HHTD_C.MN false on toc 16001 (would fall to classic CLEU path that has no getter on Forever) -> must enable MN path; CLEU getter absent (no CombatLogGetCurrentEventInfo / C_CombatLogInternal); real Forever error 'boolean test on a secret boolean' -> truth tests on possibly-secret values must be type()/canaccessvalue-gated.
23:37 VERIFIED vs captures+ForeverDump Derive v2.2.20 notes: Forever GetBattlefieldScore is classic layout (faction=6, rank=7, race=8, LOCALIZED class=9, classToken=10 secret). Original KTH reads faction at 7 (=rank on Forever) and classToken at 9 (=localized) -> both wrong on Forever; fixed via localized->token map.
23:38 port: Core/MidnightNameplates/utils/Announcer/KTH_Options/TOC patched; new ForeverSafe/ForeverChat/ForeverEvidence. Exports done: windowed truth healers run10=4 run11=2 run12=3 run13=1 run16=7 (17 total; capture windows remove the run9/run12 log overlap).
23:39 STEERING 2: user doubts the Forever diffs; building UNMODIFIED baseline (only TOC Interface->16001) + separate diag addon KTH_ForeverDiag first.
23:41 baseline zip built: 633bc5abbffa8e47aabc308da5c80885e5f489056c95f67bf9743cd5e51e7ce3. Mock smoke: MN=false at toc 16001 (unmodified KTH takes classic branch), 0 Blizzard chat lines at load; diag per-field codes inside flagged score tables verified.
00:15 baseline BG diag received (237KB) + HHTD SV; analysing.
00:16 DIAG RESULT: GetScoreInfo table CLEAR all phases; name/classToken/className/faction clear always; talentSpec/roleAssigned/guid/healing/damage SECRET prep+ooc+combat, clear post. GBS layout measured retail-like (1 name,6 faction,7 race,8 class,9 classToken CLEAR). Enemy plate UnitClass S 750/750 (ooc+combat), UnitName first-name-only clear, PowerType clear, GUID/HealthMax secret. Nameplate spellIDs S 20/20. Blocked = KTH Core.lua:1035 RegisterEvent(COMBAT_LOG_EVENT_UNFILTERED) on non-MN branch (FD EVENT_DENYLIST documents same popup). errors=0, kthPrints=0. -> refuted diffs: GBS layout/rank, GetScoreInfo secret-table, MAX_CLASSES bound, AddToBlizOptions pcall, UnitHealthMax guard, MyTeam.
00:22 port rebuilt from original (old diff saved old_port.diff); diffs D1-D7 applied, D8 measured-but-not-applied; mock fixed (xpcall args, IsLoggedIn, HHTD metadata) -> mock reproduces baseline CLEU forbidden, port 0. Replay: orig 0/7, port plate 6/12 prec 6/7 recall TTI 0s; claims F 6/9 @50% prec, E 0/8.
00:23 packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.2.zip; docs FOREVER-PORT.md, KTH-REVIEW.md, README written.
01:01 forever.2 field report: /kthg AceGUI CheckBox:130 nil call; plate icon intermittent; mouseover no detect/sound. New SVs in bgdiag2.
2026-10-10 01:06:54 forever.3: steering received - verifying UnitName realm==surname claim (runs 16-18) before switching the join
2026-10-10 01:08:51 forever.3: D5b exact name+realm join, F3 mouseover/target resolver + Announcer guards patched; checking sound ids
2026-10-10 01:10:39 forever.3: replay harness: surname realm model, primary-power filter, mouseover hover regression; port alerts on 100% of verdict-true hovers
2026-10-10 01:11:12 forever.3: druid form-veto variant scored and REFUTED (loses run13 enemy resto druid Korsica); reverted
2026-10-10 01:12:05 forever.3: replay with real tickers + plate log: icon == verdict in all 7 runs (0 mismatches); flicker = verdict flips (feral druids by K.T.H. CLASS+PWR)
2026-10-10 01:13:17 forever.3: regressions R1-R6 pass on forever.3; R1-R5 fail on forever.2 (as reported in game); toc bumped
2026-10-10 01:14:40 forever.3: F7 zone gating (roster/D6 BG-only, evidence in arena/world/Pve instances); running non-BG mock scenarios
2026-10-10 01:15:35 forever.3: R7 non-BG zone regressions pass (arena/world/party x class secret/clear, Pve off); arena readability probe added to plate log
2026-10-10 01:16:45 forever.3: docs updated (FOREVER-PORT.md F1-F7/D5b, README, KTH-REVIEW addendum), diff regenerated; packaging
2026-10-10 01:17:02 forever.3: packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.3.zip sha256 6e08d38d681ae0cb46487ca8aa5296ce6df9d3fc030c133a759efb130e1d6f4a; package smoke ok
2026-10-10 01:27:56 forever.3 audit: 'Shadow Synth' verified real (GUID Player-4619-00720C89 in combat log + C_DamageMeter + plate UnitName); no synthetic data in shipped addons; harness placeholder check made per-run (scores unchanged)
2026-10-10 01:28:22 forever.4: placeholder-surname cleanup started (runs 10-16: search FD SV for real full names)
2026-10-10 01:29:18 forever.4: real names recovered: run16 31/31 (G15 S15 S2 1, scoreboard class 31/31), runs 17/18 reproduce boards 30/30 29/29; runs 10-13 0 real names -> board-less
2026-10-10 01:30:04 forever.4: re-exported runs 10-16 (events byte-identical); run16 real board, runs 10-13 board-less
2026-10-10 01:31:25 forever.4: rescored on real-board runs 16-18 only; R8 provenance test added (fails on old placeholder run16); regress ok
2026-10-10 01:32:08 forever.4: D8/F2 re-checked on real runs 16-18 (D8 refuted again; F2 no longer refuted - flagged, not applied); docs committed
2026-10-10 01:32:20 forever.4: packaged (placeholder-derived results excluded)
2026-10-10 08:57:23 forever.5: start (healer verdict = healing share / above-average healing, replaces class+mana)
2026-10-10 09:00:06 forever.5: measured C_DamageMeter rows (FD SV): enemy rows name/guid secret, class+specIcon clear, amounts clear OOC / secret in combat; snapshots extracted to kth/dm
2026-10-10 09:02:53 forever.5: tuned on runs 16-18 DM rows: dmMin 1000, share>=60% or >=6x median heal (0 FP; 5x also 0 FP, 4x 3 FP); dup-class rule all-n-qualify; exported tests/replay/<run>.dm.lua (16-18)
2026-10-10 09:06:12 forever.5: verdict engine + meter reader in; fixtures R9 (DPS druids on MANA never marked, control marked) + R9b real; regress all ok
2026-10-10 09:07:19 forever.5: docs (FOREVER-PORT D9 + section, README, REVIEW, tests/README), toc 1.0.0-kth-forever.5; regress all ok
2026-10-10 09:07:58 forever.5: packaged /workspace/KillTheHealer-Forever-1.0.0-kth-forever.5.zip
2026-10-10 09:29:41 forever.6: start (forensics on 9 enemy healers + forever.3 false marks; specIconID, elimination, team prior)
