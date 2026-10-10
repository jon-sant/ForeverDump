# MEMORY.md - agent memory export (ForeverDump / WoW Forever work)

Section A is reconstructed from the project record (PROGRESS.md steering lines, CHANGES.md "User:" lines,
PERFORMANCE.md, HSM-STATUS.md, KTH PROGRESS.md) and the conversation up to 2026-10-10. Section B is the raw export of
the assistant's stored memory facts. If the two disagree, the newer dated fact wins. Unrelated facts (real-estate work)
are left out on purpose.

## A. Facts and preferences (dated, ET)
- (2026-10-07) Project: ForeverDump, a WoW Forever addon + offline toolchain to map the "secret values" API (what is
  readable when, in which context) and build a live HSM (Hybrid State Machine, `ForeverDump/Lib/HybridState.lua` + `Inference.lua`) of combat state without the combat log.
- (2026-10-07) Addon folder: `World of Warcraft\_classic_beta_\Interface\AddOns\ForeverDump`. TOC Interface 16001.
- (2026-10-07) The user plays a shaman (enhancement: Stormstrike, Flame/Earth/Frost Shock, Lightning Shield,
  Windfury, totems incl. Grounding), mostly battlegrounds; also open world and dungeons.
- (2026-10-08) Performance: release ≤ 2 % wall time (was 1 %); FD_Logs capture (diag/test) ≤ 10 %; lab measured only.
- (2026-10-08) One zip per release; default release verbosity; FD_Logs elevates then restores; `/fdump level` override.
- (2026-10-08) Don't artificially limit diag data collection (128 GB RAM, PCIe5 NVMe); ceilings are runaway backstops only.
- (2026-10-08) Static dump only on explicit `/fdump static run`; FD_Logs ON wipes previous capture data (keeps learned + static).
- (2026-10-08) Tests must be fast (runner parallel, ~10x faster than serial); every perf test < 2 minutes.
- (2026-10-08) The user disables every other addon during captures; the procedure runs `/fdump errors show` before stopping.
- (2026-10-08) Offline correlation may run heavy (no 2-minute cap): wider beams, depth 3-4, more windows/shuffles.
- (2026-10-09) Never stop at "unsolvable": derive through alternate APIs and higher-order inference.
- (2026-10-09) Correlate at every roadblock (run the miner before concluding something can't be known).
- (2026-10-09) Privacy scrubbing/hashing REVERSED (v2.2.20/2.2.21): store everything raw; no hashing, no redaction,
  no placeholders. Old IdKeys were unhashed into `sv_raw/`.
- (2026-10-09 21:30) HARD RULE: only 100 %-restored (or never-hashed) runs stay in analysis; others excluded (8, 9, 14, 15).
- (2026-10-09) KTH: user wants a real port of KTH's own code (minimal Forever diffs, DIFF list), not a clean-room
  rewrite; build an unmodified baseline + diag addon first to prove each diff.
- (2026-10-10) KTH real data only (no placeholder names); healer verdict = healing output. KTH parked at forever.12.
- (2026-10-10) No combat log at runtime (CLEU forbidden on Forever); the combat log file is offline truth only.
- (2026-10-10) Never loosen checks; no regressions; run the whole runner (and under TZ=UTC) before packaging.
- (2026-10-10) Time zones: all conversions tested in 7 zones + DST; the user's client and box are Eastern.
- (2026-10-10) No static/hard-coded ID lists: learned per build, growing library generated from captures and shipped.
- (2026-10-10) Spell ranks inflate IDs: one entry per ability, all ranks checked efficiently (tiers), none dropped.
- (2026-10-10) No "accurate but finds fewer" trade-offs.
- (2026-10-10) Multi-environment: test in open world, dungeon, BG; don't generalize a finding beyond what was measured
  (user corrected "all combat" until open world was measured).
- (2026-10-10) Status update about every 5 minutes; PROGRESS.md line with a lesson each time.
- (2026-10-10) The user moves the work to a GitHub repo + Grok Build; wants everything (code, data, captures, memory, rules).

## B. Raw memory export (Grok Bot agent memory, exported 2026-10-10 15:45 ET)

These are memory facts exported verbatim from the assistant's durable memory, scoped to ForeverDump, Kill the Healer and WoW Forever. The memory tool truncates long facts, so some end mid-sentence ("…"). Where facts conflict, the newest date wins. In particular, all hashing, IdKey, scrubbing and leak-check facts dated before 2026-10-09 are SUPERSEDED: data is stored raw.

### Standing rules and preferences (profile)
- (2026-10-07) ForeverDump (user's WoW Forever data-dump addon) v2.1 and its converter/migrate/verify/xref toolchain live in /workspace/foreverdump. Forever is client 1.60.1 build 70245, TOC 16001, WOW_PROJECT_ID 18, and CLEU is forbidden to addons. The user wants one-click FD_Logs capture and 5-minute status updates during long builds, and next plans to migrate an older pre-secrets addon.
- (2026-10-08) Standing mindset for WoW Forever secrets work: when a value is secret or blocked, don't stop at "unavailable". Combine readable signals by correlation, such as event timing, my own readable casts, castBarIDs, cached values, elimination and known spell data, to infer the hidden state. Example: a secret interrupt event that coincides with my own Earth Shock cast means the interrupt was mine. Richerynte explicitly wants this approach every time a roadblock appears.
- (2026-10-08) Richerynte wants addon logic to use intelligent inference and logical reasoning from readable values and event timing to work out state hidden by WoW Forever secrets.
- (2026-10-08) Richerynte's core goal for WoW Forever addons is real-time state, whether values are secret in combat, secret out of combat, or not secret at all. The hybrid state machine is the real-time solution. Offline/post-run analysis exists only to discover and prove correlations, which must then be built into live, real-time detection logic in the engine. Nothing at runtime should depend on the combat log.
- (2026-10-08) Richerynte wants every logical flaw found in ForeverDump parsing or inference turned into a permanent regression check (e.g. a lockout read as an aura duration, a summon lifetime read as an aura). Any new correlation signal needs strong, repeatable evidence before the HSM uses it.
- (2026-10-08) Richerynte wants the WoW Forever runtime state engine to continuously verify its own predictions in game (actual vs. predicted), log confirmations, failures and unexpected findings, and pass them on for post-run analysis with the combat log to improve engine accuracy and data breadth over time.
- (2026-10-09) Richerynte's standing principle for WoW Forever secrets: never call a value "unsolvable" just because its API is secret. Derive it through alternate APIs and higher-order inference (e.g. enemy class from spell-book spell IDs, cast fingerprints, damage school, auras, scoreboard). Each secret's guide row gets a derivation path.
- (2026-10-09) Richerynte's standing strategy for WoW Forever is to mine reference data once (e.g. spellbook → spell → class, schools, cast times, applied auras, totems, pets, power types), cache it per game build, and reuse it to derive secret values by alternate paths.
- (2026-10-09) As of 2026-10-09, Richerynte wants each ForeverDump build to pack in many probes and candidate rules at once (shadow/provisional, scored per rule), so fewer builds need testing. Perf impact during FD_Logs capture is acceptable and gets measured and reported, not capped; the non-capturing release default stays ≤2%.
- (2026-10-09) Richerynte expects load and detection simulations to be driven by their real captures, with addon-seen data and secret-value data replayed and the combat log used as the answer key. This measures correlation and detection success, not just performance.
- (2026-10-09) Richerynte is fine with heavy compute in offline post-analysis for deep dives, such as the correlation finder, with no runtime cap there. The 2-minute cap applies only to perf benchmarks, and the in-game release framerate budget (2%) still applies.
- (2026-10-09) As of 2026-10-08 21:31 ET, Richerynte raised the WoW Forever addon release frame-time budget to 2% (was 1%); the FD_Logs debug/diag capture ceiling stays about 10%. The cooldown storm perf gate is 2%.
- (2026-10-09) Richerynte wants one deployable WoW Forever addon build. It runs at release level (up to 2% frame time) by default. The FD_Logs debug macro/capture raises the ceiling to about 10% for tracing, data gathering and live evaluation of prior findings, then drops back when the capture stops.
- (2026-10-09) As of 2026-10-08, Richerynte wants ForeverDump's static dump to be manual only (`/fdump static run`), with no auto-write. They also want FD_Logs ON to wipe all prior capture data first, but keep the learned knowledge store and static data.
- (2026-10-09) Richerynte doesn't care how long ForeverDump capture files take to save, because complete data matters more. Simulations and tests must run accelerated (seconds to minutes) and never make them wait in real time.
- (2026-10-09) Richerynte wants a maintained master secrets guide: docs/SECRETS-GUIDE.html for them plus a paired SECRETS-GUIDE.md for the AI. It is cumulative across runs, and each row has state-machine columns: HSM status (live/cached/correlated/estimated/unsolved), valid in combat, method, evidence and next step. It is regenerated on every run.
- (2026-10-09) Richerynte considers attributing an event to their own cast because it happened in the same frame too dangerous to assume, since BGs have many friendly and enemy players with duplicate classes and spells. Attribution rules must require that the user's cast targeted the unit that changed and that the spell fits (learned spell-to-aura links). Ambiguous or busy frames must stay "unknown" unless timing, amount or meter evidence confirms them. Rules are scored on false claims.
- (2026-10-09) Richerynte wants each status update during long work to also include insights on what we learned, not just progress.
- (2026-10-09) Scheduled status-ping routines never fired in the Grok Bot setup (three attempts on 2026-10-08).
- (2026-10-10) As of 2026-10-09 (v2.2.20 onward), Richerynte reversed the old privacy rule. ForeverDump data is not sensitive: never scrub, hash, obfuscate or change raw data (GUIDs, names, anything). Store it raw in the SV and keep it raw in zips and fixtures. Drop the IdKey salted-hash-only, scrubber and leak/name-scan requirements. Hashing is OK only as an extra internal join key alongside the raw value, never in its place.
- (2026-10-10) Richerynte's hard rule (2026-10-09): a historical ForeverDump run may be used for tests, backtests or analysis only if 100% of its data is raw/restored. Any run with even one unresolved hashed key is dropped entirely; never mix partial or inconsistent data into test files.
- (2026-10-10) For quick, isolated questions (e.g. whether a secret-value operation works), Richerynte prefers a one-line `/run` command (under 255 characters) to test in game rather than waiting for a new ForeverDump build or lab probe.
- (2026-10-10) Richerynte plays WoW Forever across open-world solo, party, dungeon, raid, arena and BG, not just BGs. ForeverDump and the addons must keep approaches that help in any of these, tag all data by environment and combat state, and adapt collection logic to what each environment allows.
- (2026-10-10) Richerynte rejects regressions in any build and dislikes "accurate but finds fewer" trade-offs. A new build must keep every prior win and remove the bad: find the cases the old rule caught and the new one missed, add criteria to solve them, and backtest before shipping.
- (2026-10-10) Richerynte's standing rule: never loosen tests or checks to make them pass.
- (2026-10-10) Richerynte: in dev/diag mode ForeverDump captures may use up to 10% frame time; don't flag 2-10% as over budget or optimize it.
- (2026-10-10) Richerynte wants ForeverDump/WoW Forever addons to keep a self-growing library of abilities and auras that is derived from captures and updated in both the addon and the source with each build. It must handle multiple spell ranks efficiently, with no hand-maintained static lists.
- (2026-10-10) Richerynte's standing rule: during any long work, the assistant itself (not a timer or routine) sends an update every ~5 minutes covering what it's doing, lessons learned so far, and anything taking too long.
- (2026-10-10) As of 2026-10-10 11:35 ET Richerynte parked Kill the Healer at forever.12; focus is 100% on ForeverDump going forward.
- (2026-10-10) Richerynte's WoW Forever client addon folder is `World of Warcraft\_classic_beta_\Interface\AddOns\` (not `_forever_`). Logs are in `_classic_beta_\Logs\`.
- (2026-10-10) Richerynte's healer-detection rule (for Kill the Healer Forever and ForeverDump): mana or class never makes a unit a healer, since resto, feral and balance druids all have mana. A unit is a healer when its total healing done is significantly above average, or when most of its observed actions are healing output rather than damage output.
- (2026-10-10) KTH healer detection must be layered: spec when readable (Disc/Holy priest, Holy paladin, Resto druid, Resto shaman) or a healer-spec-only spell cast (Penance or Power Infusion, Prayer of Mending, Light's Vigil, Wild Growth, Riptide) flags a healer immediately; absence never counts against (low levels lack talents); live heal-cast share, meter group rule and class filter run underneath. Never cap the number of healers. Prefers HHTD healer icons; choice of icon styles must stay in slash and GUI.

### WoW Forever findings
- (2026-10-07) Forever's client folder is `_classic_beta_`.
- (2026-10-08) Run-3 findings (build 70245, ForeverDump v2.2.2, 2026-10-07): UnitName("player") returns first and last name ("Uglaz","Doomaxe"), not name and realm. CheckInteractDistance on friendly units is protected in combat and caused ADDON_ACTION_BLOCKED UNKNOWN(). In combat, addon calls to C_UnitAuras GetAuraDataByIndex/GetAuraSlots/GetUnitAuras raise "Auras cannot be accessed when secret while tainted"; UNIT_AURA updateInfo lists are nil or fully secret.
- (2026-10-09) Taint finding (Oct 9): any addon line printed to the default chat window taints the chat frame's internal line counter permanently. Blizzard's BattlegroundChatFilters later errors with "attempted to iterate a table that cannot be accessed while tainted" before BG gates open. Migrated addons must not print to chat; ForeverDump has a regression test that fails if a chat print is added.
- (2026-10-09) Other-unit readability (Oct 8 BG run): combat state and absorbs readable for every unit type; cast spell details mostly secret; power and range secret; current and max health secret for every unit while restrictions on; health-change events and per-hit/heal amounts readable.
- (2026-10-09) Run 13 BG: nothing becomes readable between fights in a BG. Health, power and absorbs stay secret and aura reads are refused for the whole match. C_DamageMeter per-spell breakdown readable only out of combat. Heal amounts in combat events stay readable for every unit, enabling per-unit HPS and health estimation.
- (2026-10-10) Scoreboard: `GetScoreInfo` returns a readable table in every BG phase. Name, class and faction readable throughout; talent spec, role, GUID and healing done hidden until match end (post-match spec field shows the class name). `GetBattlefieldScore` uses retail column order; class code readable (an earlier "field 7 = rank" claim was a ForeverDump off-by-one bug fixed in v2.2.23).
- (2026-10-10) Enemy nameplates in BGs hide class (all 750 reads), show first name, readable power type. `UnitName` second return is the surname, enabling exact "First Surname" joins between plates and scoreboard.
- (2026-10-10) During a BG the damage meter lists only the user's own team with readable GUIDs; enemy rows have secret name/GUID but clear class + specIcon (one icon per class, so no spec). Amounts clear OOC, secret in combat. Post-match the meter lists enemies with class.
- (2026-10-10) Enemy cast spell IDs and castGUIDs are secret on every unit except the player (806 casts, run 19); castBarID clear but random per cast.
- (2026-10-10) Aura data (GetUnitAuraBySpellID presence, UNIT_AURA payload) is readable out of combat and returns nil/secret in combat in BG (run 19/22), dungeon (run 20) and open world (run 21). In combat nil means unknown, not absent.
- (2026-10-10) Health and power are secret everywhere for every unit, including the player out of combat, on builds 70291/70334/70338 (runs 9, 15, 21, 22): not PvP- or restriction-driven.
- (2026-10-10) GetTotemInfo in BG: all fields secret except icon, which is nil for an empty slot and secret for a live totem: empty slot correct 5076/5076, live totem detected ~93%, 0 false positives (run 22).
- (2026-10-10) Player nameplates capped by `nameplatePlayerMaxDistance` (40 yd, secure CVar, addons cannot set). Setting higher has no effect; plates disappear at 40 yd (user-verified). No positions in BG (UnitPosition/C_Map nil). SetRaidTarget restricted.
- (2026-10-10) Client builds seen: 70245, 70291, 70334, 70338 (runs 19+).

### Project history (log)
- 2026-10-07: ForeverDump v2 built (14 modules, combat log/Lua error/taint/profiling capture, single FD_Logs toggle macro via `/fdump macros`) with offline converter tools.
- 2026-10-08: v2.2.4 added a persistent learned-spell/NPC store, group-aware unit-token scanning and an offline correlation finder (up to third-order chains, timing and elimination), feeding a real-time state machine that never depends on the combat log at runtime.
- 2026-10-08: v2.2.7 secret-value crash fixes. BG error burst came from TweaksForever (~3,200 secret-arithmetic tooltip errors), Questie and Blizzard ObjectiveTracker, not ForeverDump.
- 2026-10-08: v2.2.9 fixed error stacks miscounted as ForeverDump's and the FD_Logs macro's combat-log toggle conflict; diag default. Procedure: run `/fdump errors show` before clicking FD_Logs OFF; OFF does /reload and saves.
- 2026-10-08: v2.2.10 uncapped diag captures, lossless damage-meter storage (95,275 events).
- 2026-10-08: v2.2.11 SVPack packing (Lua constant-table overflow on run 9's 48 MB file), manual static dump, FD_Logs ON wipes prior capture, isdst taint fix.
- 2026-10-09: v2.2.14 never writes to Blizzard chat (own message frame, `/fdump msgs`).
- 2026-10-09: v2.2.15 new live aura/heal-on-target rules (aura on me 37–45% → 87–97%; heal on target 0 → 100% on four BGs).
- 2026-10-09: v2.2.16–17 strict attribution (target, spell fit, crowded = unknown): false "mine" claims 66 → 31 across runs 9–14; dispel counted once per cast. HSM-STATUS.md sign-off.
- 2026-10-09: v2.2.18 class evidence engine, derivation path for all 201 guide rows, RefData mined from combat logs (build 70291).
- 2026-10-09: v2.2.19 out-of-combat fill: sweeps target/targettarget/focus/focustarget/mouseover/party/raid/boss/arena/nameplates plus their targets and pets.
- 2026-10-09: v2.2.20–21 all data raw (anonymizer and scrub tools removed); identity-merge bug fixed. Pre-v2.2.21 SV keys were salted FNV hashes (salt = floor(now*1000) % 2147483647 + sessionCounter*9973); salts brute-forced from the user's known GUID to restore runs; runs with any unresolved key excluded.
- 2026-10-09: v2.2.22 replaced the whole-table-skip probe pattern in 17 places with per-field readability; the 15% scoreboard claim retracted.
- 2026-10-10: v2.2.23 scoreboard column fix; v2.2.24 mind-controlled teammate fix; v2.2.25 environment tags and aura-presence probe; v2.2.26 DST/time fixes, aura unknown state, totem probe; v2.2.27 no static aura lists; v2.2.28 cold-start fix + generated LearnedAuras library; v2.2.29 frame-spread aura probe, 100% candidate coverage.
- 2026-10-10: Time audit: 21 sites, 6 bugs fixed; reruns in 7 zones byte-identical (no published result changed). TZ matrix tests in runner.
- 2026-10-10: Kill the Healer Forever port builds 2–12 (parked at 12): Midnight path (Classic branch registers forbidden CLEU), exact full-name joins, HHTD icons, healer rules (class-group meter rule, minimum-healer pairing, elimination, druid form tie-break), configurable thresholds, debug toggle, no healer cap. Backtest runs 16–19: 9/9 healers on 16–18, 0 false marks.
