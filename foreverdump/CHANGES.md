# ForeverDump: changes

v1 (`ForeverDump.lua`, 333 lines; one SavedVariable `ForeverDumpDB`) collected the APIs (`C_*` functions), events,
enums and CVars in one pass and showed them in a copy window via `/fdump` and `/foreverdump`. **All of that still
works:** plain `/fdump` runs the same quick dump into the same `ForeverDumpDB` fields.


## v2.2.29 (2026-10-10, aura presence: nothing dropped, time-sliced)

User: no "accurate but finds fewer" trade-offs - no candidate dropped, no enemy rank missed.
- **Time-sliced presence probe.** The 1 s ticker only flags; an OnUpdate frame runs the tick (which units: 2 calls per
  token) and drains a queue of per-unit jobs (name / GUID / class / level / tier plan / slots / detail / health context
  at the job start, then one presence check per item) for `AP.WALL_SHARE` 5 % of each frame's time (0.2-1.5 ms per
  frame, tick time included), measured per check (`debugprofilestop` every `AP.CHECK_EVERY` checks, EWMA `costMs`).
  No OnUpdate frame (tests) = same queue drained synchronously.
- **No cuts.** Rank grouping keeps every rank; `AP.Limit()` is a runaway backstop sized from the cost (wall share x
  tier-C period / units: 5952 at 0.012 ms, floor 2000, ceiling 20000), warning + counter when ever reached.
- **Smart frequency.** Tier H (learned / pair / knowledge / spellcache / prev-build) every visit; W (single-rank
  abilities, the `AP.PLAUSIBLE_RANKS` = 2 highest ranks learnable at the unit's level when class + level are clear and
  the rank levels known) every 3rd visit; C (other ranks, provisional library entries, class / level unknown: all but
  the most-seen rank) every 10th visit. An aura found present / derived on a unit is checked on every visit until
  absent (sticky). Rank learn levels: `C_Spell.GetSpellLevelLearned` (AllowedWhenTainted, 70245 inventory), filled in
  idle frame time, cached in `ForeverDumpDB.spellLevel[build]`; a group whose ranks all answer the same level counts as
  unknown. Rotating units per tick follow the budget (`AP.RotateCount`, 3..40; was 3).
- **Staleness reported:** `auraPresence.sched` (frames, checks, sumMs, maxMs, maxQueue, maxLag, backlogTicks,
  deferred, unitGone, maxGap per family, perTier, rotate) and `sched.worst[family][tier]` at stop
  (TIER_EVERY x longest visit gap + longest queue lag).
- **Bug found by the replay sim:** finished jobs were removed with `queue[qHead] = nil`; `#queue` on a table with holes
  returned an early border, the queue was reset and those units stayed "pending" forever (fixed: index only).
- **Restriction flips:** the Combat restriction (type 0) Activating / Active fires at PLAYER_REGEN_DISABLED before
  InCombatLockdown is true (run 22: 24/24 stamped ooc). `ns.CombatAtFlip` counts it as combat in AuraPresence and in
  Restrictions (`rec.inCombat = true`, `rec.combatBy = "flip"`, raw `rec.inCombatLockdown = false`, env tag combat).
- **Guide:** arenaN tokens are split by hostility (`arena:friendly-player` -> friendly; BGs use arenaN for friends
  too). Changed rows: guid/enemy-player pvp mixed -> secret, incheal/enemy-player secret -> nil.
- Replay measurement `tools/fdump/measure_sched.lua` (runs 19-22, simulated BG of 27 units, virtual clock at the
  measured 0.012 / 0.0057 ms per call): see real/2026-10-10-run22-bg/out/aurapresence/sched-compare.txt and
  staleness-v2229.tsv.
- Tests: `tests/v2229_sched.lua` (30), `tests/test_v2229_replay.py` (2); v2227_dynamic / v2228_coldstart adapted
  (limit -> backstop, rank cut -> tiers).

## v2.2.28 (2026-10-10, fixes from run 22: BG, FD 2.2.27, client 70338)

- **AuraPresence rotation bug:** the rotation counted presence CALLS, so with 0 candidates no unit ever counted and all
  89 rotation tokens were probed every tick (run 22: 21 existing units/tick, 1.67 ms/tick vs 1.06 ms in run 19 with 43
  spells). Now at most #FIXED + ROTATE units per tick.
- **Candidates (still dynamic only):** + `refLearned[build].auraDur` (OocFill learns every clear aura it enumerates out of
  combat, any unit/class: 51 IDs on 70338) and + `knowledge[build]` spells whose parsed description has an aura
  duration (collected every session, no /fdump static run needed: 11 own spells). Run 22 ran with 0 candidates because
  v2.2.27 read neither store. List rebuilt at least every 60 s (`AP.LIST_REFRESH`).
- **Derivation without an observed pair:** same-ID rule from knowledge (consumable/charge auras skipped). Offline check
  on run 22 (`tools/fdump/derivesim.py`): applied 36/48 casts, but only 7/34 ended at cast + duration -> D means
  "applied by my cast, may have ended early".
- **Offline:** `tools/fdump/totemscore.py` (GetTotemInfo icon N = empty slot / S = totem, slot from the
  PLAYER_TOTEM_UPDATE rows, no element table), `tools/fdump/derivesim.py`; master guide: a run with empty
  aura-presence codes no longer evicts older cells.
- **Cold start closed** (run 22 ran a whole BG with 0 candidates):
  - existing learners: `refLearned[build].auraDur` + `knowledge[build]` (above);
  - automatic per-build spellCache: on PLAYER_ENTERING_WORLD (+3 s) when this build + class has none, built over
    timer steps (`AP.AUTO_CHUNK` 20 spells / 0.05 s), out of combat only (combat pauses, resumes). Own spellbook reads
    are not restricted in a BG: Knowledge read 77/77 spells with clear descriptions in BG prep and BG combat (runs 19,
    22). `/fdump static run` is no longer needed for the aura list (it still rebuilds the cache);
  - cross-build carry-over: a new build seeds `auraLearned` / `auraPairs` from the newest earlier build, tagged
    `prov = "prev-build:<b>"` (candidate source `prev-build`) until a clear read / observed pair on the new build
    confirms them (`confirmed` epoch); `refLearned`, `knowledge` and the offline file fall back to the newest earlier
    build; `ForeverDumpDB.auraCarry` records what was carried;
  - growing generated LIBRARY `ForeverDump/Data/LearnedAuras.lua` (schema 2), GENERATED by
    `python3 tools/fdump.py learned-auras` (tools/fdump/learnedauras.py) from every stored capture that passes the
    inclusion gate, CL + SV merged: one entry per aura spell ID (n, median duration, name, `builds` that confirmed it,
    rank `base` = lowest ID of the same name, class), plus cast->aura pairs (n >= 2; the CL writes the aura row ~2 ms
    before its cast row, so pairing looks back 50 ms). 582 spells, 378 pair sources from 19 inputs. Shipped in every
    build, never hand-edited; deterministic, `tests/test_learnedauras.py` fails when stale. The addon loads it as learned
    data (source `offline`; `offline-prov` when the entry is not confirmed on the running build) and keeps learning live.
    Library pairs with n >= 3 are the derivation fallback before the same-ID rule (17364 Stormstrike -> 1238931
    Improved Stormstrike on self, n 567). Optional: `auraPresence.offline = false` or delete the file;
  - ranks: candidates are grouped per ability (name); at most `AP.RANKS_PER_NAME` = 2 IDs per group, the rank seen live
    on this build first, then the own-spellbook ranks; a library-only group keeps `AP.LIB_RANKS_PER_NAME` = 1 (the most
    seen). Dropped IDs are counted in `auraPresence.list.rankGrouped`. Runs 19-22 replayed with the library: 582 -> 405-408
    candidates (limit 357); without it 35/36/45/60 -> 33/35/45/60 (`tools/fdump/measure_ranks.lua`);
  - in-game pairing also accepts an own aura seen up to `AP.EARLY_WINDOW` 0.1 s before its UNIT_SPELLCAST_SUCCEEDED;
  - empty-list warning at capture start: FD message frame + `auraPresence.emptyAtStart` + `warnCount.empty`.
- Tests: `tests/v2228_run22.lua` (10), `tests/v2228_coldstart.lua` (39; acceptance: run 22's stored DB replayed as
  build 70338 and as fresh build 70400 -> 60 candidates at the first tick), `tests/test_run22_tools.py` (6),
  `tests/test_learnedauras.py` (3).

## v2.2.27 (2026-10-10, data-collection build: no static aura lists)

- **Aura-presence candidates are dynamic only.** Removed the curated 43-spell `AP.SPELLS` list and the 96-spell
  `Data/AuraSeed.lua` (and its generator `tools/fdump/auraseed.py`). Candidates now come only from, per client build:
  (a) auras read out of combat - `UNIT_AURA` payload `addedAuras` (player/target) and the `GetAuraDataByIndex` slot
  scan - learned into `ForeverDumpDB.auraLearned[build]` (v2.2.26 flat entries migrate under the build);
  (b) auras observed <= 0.6 s after the player's own clear cast -> `ForeverDumpDB.auraPairs[build][cast][aura]`
  (counted once even when payload and slot scan both see it); (c) aura-like spellbook spells (description states a
  duration) from `ForeverDumpDB.spellCache[build][class]`, rebuilt only by `/fdump static run` (Static finish()).
  Own-cast derivation (state D) uses the observed pairs + learned durations.
- **No fixed cap.** Limit = `AP.TICK_BUDGET_MS` (30 ms per 1 s tick = 3 % wall; dev budget 10 %) / (cost per call x 7
  units). Cost per call is measured in game (debugprofilestop EMA); initial 0.012 ms = worst upper bound from the
  run 19-21 perf windows (0.0057 bg / 0.0123 dungeon / 0.0093 world) -> 357 candidates before the first measurement,
  min 200, ceiling 5000. Over the limit: `auraPresence.limitHit` counter + one logged warning (`auraPresence.warnings`),
  candidates ordered on-me / own-cast pairs, then most recently seen, then most seen; spellbook-only last.
- **CombatProbe dispel spells** (10 hardcoded IDs in config) now come from the spellbook cache (description mentions
  dispel / remove / purge / cleanse / cure); a user-set `combatProbe.dispelSpells` still overrides.
- Tests: `tests/v2227_dynamic.lua` (26: Earthborer Acid 18070 learned from an OOC UNIT_AURA payload and from the slot
  scan without being listed; pair -> derived D in combat; limit warning + counter + priority; spellbook cache + dispel;
  per-build stores + migration; lint: no table literal with >= 3 ID-like numbers in AuraPresence.lua, no AuraSeed);
  v2225_env_aura / v2226_aura fixtures learn their spells explicitly. Runner 121/0 FAIL (local and TZ=UTC).
- Rescore runs 19-21: aurapresence scores identical; pvescript r20/r21 byte-identical (NY and UTC).
- Remaining hardcoded ID data (not collection lists; proposals): see docs/STATIC-LISTS.md.

## v2.2.26 (2026-10-10, data-collection build: aura probes, time fixes)

- **Time (shipped):** CombatLog.lua utcOffset comes from Core's TimeAnchor (no isdst / time(table): run-9 taint
  pattern gone); the AuraPresence anchor is ns.TimeAnchor() (tick-refined epoch: the run-20 1.000 s skew is gone);
  Drift.Decay uses civil-day arithmetic (Drift.DayNumber).
- **DST (offline):** refdata.lines keeps one zone per log (the first suffix); rows stamped after a DST change
  (11/1 02:00 EDT -4 -> EST -5) are shifted so log seconds stay continuous and match epoch_to_logsec. Client.log (no
  zone) infers the fall-back / spring-forward from its wall clock (clientlog.dst_step). combatlog / KTH logtruth
  already honoured each row's suffix. The time audit (docs/TIME-AUDIT.md) found no prior result changed.
- **Aura probes (AuraPresence.lua, capture level lab):**
  (a) a nil / secret GetUnitAuraBySpellID answer while aura access is restricted (combat, BG/arena, or the player's own
  GetAuraSlots not clear this tick) is tape state **U = unknown**, never A; the scorer reports unknown:present /
  unknown:absent / unknown:edge from the log and never scores it as absence;
  (b) tracked list = curated 43 + Data/AuraSeed.lua (96 auras mined from runs 19-21 by tools/fdump/auraseed.py:
  everything applied by / to me or my targets, own auras always kept: Earthborer Acid 18070, Improved Stormstrike
  1238931, Thrill of Adventure 1261483 ...) + auras learned out of combat (ForeverDumpDB.auraLearned, persists), cap 160;
  (c) out of combat: full AuraData per unit (stacks, duration, expiration, points/values, source, mine, instance id),
  change-only `detail` tape;
  (d) totems: GetTotemInfo per slot on PLAYER_TOTEM_UPDATE and each tick, codes per env tag + `totems` tape;
  (e) own clear UNIT_SPELLCAST_SUCCEEDED spellID -> expected aura(s) on target / self (AuraSeed.cast, durations learned
  out of combat first, else the mined median) -> `derived` tape, and tape state **D** where the live read is U;
  (f) ADDON_RESTRICTION_STATE_CHANGED type:state:combat counted per env tag (AuraPresence `restrict` and
  Restrictions `byEnv`, plus env / inCombat on every flip record);
  (4) health context: UnitHealth / UnitPower codes keyed by unit family, UnitIsPVP, UnitIsPVPFreeForAll, group, friend,
  self and the restriction vector (`hctx`).
- **Run 21 finding:** UnitHealth / UnitPower are secret for every unit out of combat, the player itself included
  (run 21 player 54/54 S with every restriction state 0; same in runs 6, 6b, 7, 15 since build 70291) - not a PvP or
  friendly-unit rule. The `hctx` probe records the PvP flag and restriction state with each read to confirm in game.
- Offline: pvescript counts only the player's own events (run 21: another shaman's Flame Shock was 107 of 123 rows);
  aurapresence `--json` adds `tapeVersion` and a `v2226` block (list, restricted share, detail, totems, derived,
  restrict, hctx).
- Tests: tests/v2226_aura.lua (30), DST cases in test_tz_matrix.py (+6) and time_lua.lua (+5), scorer U/D tests;
  test_v2225 now runs once per zone (it depended on the box zone).

## v2.2.25 (2026-10-10)

- **All environments (standing directive):** `ns.Env` / `ns.EnvTag` tag reads as env (world-solo, party, dungeon,
  raid, arena, bg) x combat x phase. Derive reads/casts, CombatProbe runs (`envCtx`) and the new probe are env-tagged.
- **Env-aware circuit breaker `ns.AuraGate`:** the "Auras cannot be accessed" error holds an API x unit family for 30 s
  in THAT env tag only, then re-samples. Replaces the Inference GetAuraSlots breaker (keyed by ctx only, so a BG error
  held counts off in world/dungeon combat); also gates the OocFill / Identity / Derive aura scans.
- **Exact full-name join (primary):** UnitName realm == Forever surname (45/45, runs 16-18). A scoreboard row whose
  "First Surname" was seen on a token assigns directly (`exact` / `exact-unique`); a first name listed twice gets
  per-player `First-Surname` keys. First name + faction stays the fallback. (v2.2.24 did not include this.)
- **Aura-presence probe (`AuraPresence.lua`, lab level):** `GetUnitAuraBySpellID` for 43 curated healer / dps /
  own-spell IDs on player, target, focus, mouseover, nameplateN, arenaN, partyN, raidN; GetAuraSlots
  'HELPFUL|PLAYER', AuraIsBigDefensive, GetAuraCasterGUID; codes per env tag; change-only tape scored offline by
  `tools/fdump/aurapresence.py`.
- **BG-only audit:** CombatProbe probes arena1-5 and runs the aura probe on arena/raid tokens; the guide maps probe
  contexts by recorded environment (legacy heuristic for old runs); the capture-off reminder also fires in
  dungeons/raids (autoBG stays pvp/arena). HSM-STATUS section 15.
- **Tests:** `tests/v2225_exact.lua`, `tests/v2225_env_aura.lua`, `tests/test_v2225.py`.

## v2.2.24 (2026-10-10)

- **Team membership from the scoreboard (run 18):** a friendly raid member mind-controlled by an enemy priest (log
  flags 0x1148 = hostile controlled pet) was marked enemy for good by plate hostility. `ClassEvidence:MarkFriend` —
  a UNIQUE first-name scoreboard row on my faction (faction clear in every phase) clears a prior enemy mark and vetoes
  later `MarkEnemy` calls (`summary.enemyCleared` / `enemyVetoed`). crossFac first names are not touched (shared key).
- **Offline truth:** `refdata` no longer marks a player hostile on ANY hostile flag; pet-type (0x1000) flags don't vote
  and the side is the majority (only run 18 / the MC'd player changes).
- **Run 18 (first v2.2.23 capture):** live first+faction join 15/15 enemies, 0 wrong class; enemy class prefill
  234/235 (run 17: 0/214). The last two REMEASURE rows (aura-payload, aura-count) are measured. Aura API errors in a BG
  are the client's secret-aura rule for any addon, not FD taint. HSM-STATUS section 14.
- **Tests:** `tests/v2224_friend.lua`.

## v2.2.23 (2026-10-10)

- **GetBattlefieldScore layout fix (run 17 / KTH_ForeverDiag):** Forever returns no `rank`: 1 name, 2-5 KB/HK/deaths/
  honor, 6 faction, 7 race, 8 className (localized), 9 classToken, 10 damage, 11 healing, 12-17 stats (14 nil).
  `DV.GBS_FIELDS` renamed to that layout; race now read from pos 7 (v2.2.20-22 read pos 8 = localized className ->
  wrong race prefill, crossFac race disambiguation rejected); class read from pos 9 classToken, else pos 8 localized
  (v2.2.20-22 read pos 10 damage first and was right only by fallback). The v2.2.20 "classToken secret" claim is
  retracted: it was pos 10 (damage).
- **Run 17 re-measure:** 8 of the 10 REMEASURE derivation rows are now MEASURED (`derivation.MEASURED`); aura-payload
  removed-ID lists and aura-count T counters still need a v2.2.22+ capture (`derivation.STILL_REMEASURE`). See
  HSM-STATUS section 13 (field x phase table, changed claims, scores, re-sim).
- **Tools:** `tools/fdump/runscore.py` (run truth from scoreboard + log, live per-unit scoring, v2.2.22 join sim),
  `tools/fdump/resim_v2223.py` (enemy class at first event under the corrected model, included runs).
  Run 17 included in `unhash-inclusion.json` (0 hashed). Run 17 replay stream + truth exported for the KTH harness.
- **Tests:** `tests/test_v2223.py`; GBS mocks in `derive_v2218.lua` / `audit_t_v2222.lua` use the Forever layout
  (+ post-match row with a clear damage number, + secret-classToken localized fallback).

## v2.2.22 (2026-10-09)

- **Score-bf join (KTH / run 16):** Forever scoreboard names are `First Surname` while UnitName/combat log are `First`. Join on the first-name token; require unique first+faction (else pending until plate hostility / never assign if still ambiguous). `bfJoin` now meets plate keys for unique names; duplicate first names (two `Johnny`) stay unassigned until `ScoreFlush`.
- **ClassEvidence:** `Allow`/`Power` revokes a settled class when an eliminator rules it out and the prior `via` is not an ASSIGNING source (`cache:*`). Fixes run-16 base-name collision (`name:Johnny` kept SHAMAN from `cache:raidN` after ENERGY power).
- **Run 16:** first v2.2.21 BG capture signed off; secret-identity compare path closed (ForceTaint_Strong). See HSM-STATUS §11.
- **Unhash inclusion:** only 100%-raw / pre-IdKey runs stay in analysis (run16 included).
- **Data-collection build: T-container audit.** A container with SOME secret fields ("T") is no longer skipped,
  dropped whole or coded "secret": every field is read with `pcall(index)` and classified (C/S/N/E); only clear fields
  are used. Fixed in Derive (GetScoreInfo, GetBattlefieldScore, aura reads), DamageMeter `field()` (issecrettable
  structs were never indexed), Core `ns.Clean` / Recorder (T tables were `SECRET_TABLE`), Core probe results, Secrets
  `CODE_SECRET`, Inference / LabProbes / OocFill aura lists, Knowledge / Learned spell info; tools: master_guide
  (T -> mixed), guidejson (T -> `C*` + per-field codes), probes mismatch. New `ns.IsSecretValue`, `DV.FieldsOf`.
  Full list: HSM-STATUS section 12.
- **Scoreboard phase tags:** every scoreboard read is tagged `prep` / `gates` / `combat` / `post` with the player
  count (`derive.scorePhase`, `GetScoreInfo@<phase>`, `GetBattlefieldScore@<phase>`).
- **Retracted:** "GetScoreInfo is a clear table on 15 % of rows" (T rows were never read). Dependent derivation rows
  re-marked NEEDS RE-MEASURE (`tools/fdump/derivation.py REMEASURE`).
- **Tests:** `tests/audit_t_v2222.lua`, `tests/test_v2222_audit.py`; score-bf sim `tools/fdump/bfjoin_sim.py`.

## Unhash inclusion (post-v2.2.21 repair)

Historical salted IdKeys are recovered into `real/<run>/sv_raw/`. **HARD RULE:** only runs with 100% restore (or no hashing) stay in offline scoring / master guide / fixtures / replay. Manifest: `tools/fdump/data/unhash-inclusion.json`. Gate: `tests/test_unhash_inclusion.py`. Excluded: run8, run9, run14, run15. Details: HSM-STATUS section 10.

## v2.2.21 (2026-10-09, raw identity: user decision "we should not be scrubbing any data")

- **Raw identities everywhere.** Nothing is hashed, scrubbed or anonymized any more. `ReplayLog.IdKey(kind, v)` returns
  `kind:<raw value>` (GUID, or the name exactly as read, realm included); the per-capture salt is gone (header
  `identity = "raw"`). The NPC kind still groups Creature/Vehicle GUIDs as the public `npc:<id>` join key, and the raw
  GUID is stored next to it (tape `ws.g` / `ws.tg`, `map.g`, plus the exact token `map.tk`).
- Capture paths that wrote only a key now also write the raw value:
  - damage-meter rows: `guid`, `name`, detail `unitName`, spell `creatureName`, session `name`;
  - class engine: `derive.units[key].names` / `.guids` (meter, scoreboard, plate reads);
  - ooc-fill cache: facts `name` (full name with realm), `guid` and `guild`;
  - lab probes: `died.<type>.guids`; Verify keeps every key;
  - HSM export and panel: raw GUIDs (`ScrubKey` / `ScrubExport` are identity functions now).
  Realm-stripped `name:<base>` keys stay as a derived join helper only.
- Defaults: `record.redactChat` and `probe.redactPlayers` are off. Identity CVars (account, realm, character, GUID,
  battletag, ...) are stored raw. Only credential CVars (password / auth token / login ticket) stay redacted.
- Secret safety is unchanged. Values are classified first; a secret is recorded as secret and never stored or compared.
- **Toolchain:**
  - `tools/package.py` has no scrubber; every zip entry is checked byte-identical to its source file.
  - `tools/fdump/anonymize.py` is removed (replaced by `fixturepack.py`, which copies verbatim).
  - `fixtures/forever-70245` was regenerated raw from the same capture (same 1029 lines / 1023 CLEU events).
  - The master-guide privacy gate, correlate `<player>` redaction and the learned-seed GUID strip are gone.
  - `replay` counts raw identities (`rawIdentities`) instead of "privacy hits".
- **Raw joins offline:** `tools/fdump/rawjoin.py` joins every raw GUID in an SV 1:1 to the combat log. Sources: damage-meter
  snapshots (measured M signal), `inference.signals`, and from v2.2.21 captures the live class engine / cache per unit
  (true false-assignment counts). Results for runs 9-15 are in HSM-STATUS section 9.
- **Tests:**
  - leak / name-scan gates are converted: `tests/raw_identity.lua` (was guid_scrub), oocfill_v2219, derive_v2218,
    test_master_guide, test_v226_replay, the fixture spec and test_migrate all assert raw values;
  - new `tests/raw_roundtrip.lua` + `tests/test_v2221.py`: capture -> SVPack -> loader -> json / replay / analyze ->
    rawjoin, byte-identical;
  - fixed a correlate crash on a capture without timed events.

## v2.2.20 (2026-10-09, run 15 sign-off: v2.2.19 live in a BG)

- **Run 15** (Darkspear Islands 19:28-19:40 ET, client build 70334): decode identical; 6 selfErrors (below); perf at
  lab 0.96 % own time (OocFill 0.18 %). Every v2.2.19 / v2.2.18 test item is answered in HSM-STATUS section 8.
- **Fix (selfErrors):** Derive read UnitChannelInfo's spellID as `channel and r[8] or r[10]`; r[8] is the secret
  notInterruptible, so the BG raised "boolean test on a secret". spellID is r[9] for channels. Derive.lua joined the
  secret lint (S2 now also catches `and r[N] or`) and the secret-injection test.
- **Class engine:** the meter composition made 10 enemy SHAMAN assignments in run 15, at least 6 of them false (it is
  a lower bound of the team). It is now provisional only and cumulative. Reading sources override elimination-made
  classes, and contested units never settle by elimination.
- **New assigning rule `score-bf`:** GetBattlefieldScore name, faction and localized class are clear on 100 % of rows
  (classToken secret). It assigns enemy class per name key from BG prep, flags enemies by faction, and feeds the
  same-class census (the meter saw 3 of 4 enemy shamans). `derive.score bfJoin` checks the key join live.
- **Identity:** UnitCache never merges two GUID identities (run 15 collapsed every friendly read into one);
  `oocfill.identCheck` diagnostic. Meter name keys are realm-stripped like plate / scoreboard keys.
- **Learned spellClass** from DamageDone / HealingDone only (DamageTaken polluted 25/107 votes).
- tt-attacker events carry the single candidate's cached power type (offline identity check).
- **Log-only scoring** (`classderive.log_windows`, `oocfill_score --log-only`), validated on runs 13-14.
- **RefData** regenerated (16 logs incl. full run 15): 963 spells (540 class, +53, 0 flips); cast time = p10 of
  START->SUCCESS (median when p10 < half of it).
- A capture stop with nothing gathered no longer writes empty `oocfill` / `derive` stubs (or overwrites pre-reload data).
- BG entry with capture OFF: one reminder in ForeverDump's own frame (`logs.bgReminder`, default on); opt-in
  `logs.autoBG` (default off) starts the capture 3 s after entering a BG/arena.
- Master guide lists log-only runs. Tests: `tests/bgentry_v2220.lua` (16), `tests/test_v2220.py`, derive_v2218 (+11).

## v2.2.19 (2026-10-09, proactive out-of-combat fill + full unit-token sweep)

- **OocFill.lua** (lab capture, `ForeverDumpLogDB.oocfill`). Every context where values read clear triggers a sliced,
  throttled sweep of every existing unit token: out of combat, BG prep, post-combat, dead/graveyard, pvp-ooc. The sweep
  is event-driven: regen, roster, plates, target/focus/mouseover, UNIT_TARGET, arena/boss, pets, death/rez, plus a 2 s tick.
  - Clear facts are cached per identity: class, race, level, faction, sex, max health, power type and max power,
    player/hostile, guild key, pet owner key, arena spec and the aura signature.
  - The cache feeds the class engine, the HSM ledger (Identity.Observe / aura scans) and the per-build learned data
    (aura durations, aura spell -> source-class votes).
  - Meter roster and scoreboard classes are written into the cache too.
- **Lib/UnitCache.lua** (pure): one entry per merged identity. Each fact carries source, time, context, count and a TTL.
  - Later clear reads verify a fact. A static contradiction (class/race/sex/faction) makes the fact unknown; a dynamic
    change (level, max health/power) is counted as drift.
  - The GUID key and the name key from one clear read are linked, so in combat a GUID-secret token resolves through
    the name key.
- **Full unit-token sweep** with per family x field x context readability. Tokens: player, pet(target),
  target(target), focus(target), mouseover(target), partyN(target), partypetN, raidN(target), raidpetN, bossN(target),
  arenaN(target), nameplateN(target). Limits come from the client (group counts, MAX_* globals, arena counts,
  C_NamePlate.GetNamePlates).
- **Target chains -> shadow rules** (counted, never claimed): tt-attacker (hostiles targeting me when I am hit) and
  tt-same-class (same-class friendlies targeting a unit whose auras changed). Timestamps are kept for the offline log join.
- **Offline:** `tools/fdump/oocfill_score.py` scores pre-fill coverage per (unit, fight) episode on runs 9-14. Enemy class
  was cached at the first event in 86.6-95.5% of episodes; class time to identify drops from a 6.6-9.4 s median to 0 s.
  See HSM-STATUS section 7.
- **Guide:** "ooc cache" derivation paths, plus new target-chains and prefill families.
- **Tests:** `tests/oocfill_v2219.lua` (27) and `tests/test_v2219.py`. OocFill was added to the secret lint and to
  secret injection.

## v2.2.18 (2026-10-09, derive secrets: class engine, reference data, derivation inventory, live probes)

- **Standing principle (user 2026-10-09 17:54): never stop at "secret, unsolvable".** Every guide row and every former
  HSM "unsolvable by design" row now has a derivation path: an alternate API or a higher-order inference chain, its
  readable inputs, an offline estimate on runs 9-14 and a live probe. Source of truth: `tools/fdump/derivation.py`. It
  is rendered as a "derivation path" column on every SECRETS-GUIDE row plus a "Derivation paths" table, and in
  HSM-STATUS sections 3 and 6.
- **Class engine** (`Lib/ClassEvidence.lua`, pure): per-unit candidate sets fed by power type, meter class
  composition, meter name-key joins out of combat, clear spellIds and summons (RefData), the scoreboard, plate colour
  and arena specs. It assigns only on proof (an empty set falls back to unknown) and counts contradictions. Offline
  P+K: 0 false assignments on runs 9-14.
- **Enemy census from the meter**: displayType 2 rows carry a clear classFilename. `Inference.SetMeterEnemyCensus`
  raises the same-class enemy count (120 s validity). Enemy shaman count = log on runs 10-14.
- **Reference data** (`Data/RefData.lua`, generated by `tools/fdump/refdata.py` from 15 combat logs, build 70291):
  - 640 spells (class code, cast time, aura duration, school, cooldown);
  - summons -> owner class;
  - class power types;
  - class x level max health;
  - in the JSON: NPC max HP per level, amount bands, cast-time fingerprints, spell names.
  
  Runtime learning goes to `ForeverDumpDB.refLearned[build]`: meter spell -> class votes and own cast times. It
  flags build and spell drift. `refdata.py --learned` folds SV learning back into the seeds.
- **Derive.lua** (lab capture module, `ForeverDumpLogDB.derive`): a readability matrix of 59 unit APIs, 7 pair APIs,
  aura fields and global probes (GetTotemInfo 1-4, arena/score counts) per unit family, hostile/other and context.
  It also covers cast planned times, plate bar colour, meter roster counters, the scoreboard (RequestBattlefieldScoreData
  out of combat) and the class engine summary per name key. No raw names or GUIDs are stored.
- `DamageMeter.Roster` / `SourceSpells` (name key, codes, displayType, class per source).
- Tests: `tests/derive_v2218.lua` (28 checks) and `tests/test_v2218.py` (miner, fingerprints, learned merge,
  derivation exhaustiveness).

## v2.2.17 (2026-10-09, run 14 sign-off bug fix: dispel double count)

- **Bug (run 14, 5 live contradictions "self-attribution-exceeds-dm-dispels": live 18-20 vs meter 8-9).**
  `HybridState:OnDamageMeter(6)` added one "mine" dispel for EVERY type-6 meter update in the same frame as my
  dispel-capable cast. The meter fires several type-6 updates per dispel (and one for each group member's dispel),
  so one Purge was counted about twice. Each own cast now counts at most once (`own.dispelCounted`). Combat-log truth
  for run 14: 18 Purge casts, 15 dispels. Regression test in `tests/attr_v2216.lua` (it fails on the v2.2.16 lib).
- No other runtime change.

## v2.2.16 (2026-10-09, final state-engine build: attribution safety, false-self gate, collect-first lab)

- **Attribution safety (user request 2026-10-09 15:38).** Every rule that claims "mine" now goes through one gate
  (`HybridState:gate`): (1) **target match** - my cast's effective target is the unit that changed (self buffs,
  summons and learned self links count as "me"); (2) **spell plausibility** - the learned link fits (a heal with no
  aura never claims an aura, a heal never claims damage, a self buff never claims an aura on another unit);
  (3) **ambiguity guard** - with same-class actors around (live census) or several events on the unit in one frame, the
  claim is U unless corroborated (same-frame timing for a learned self link, amount inside my learned band, the
  interrupt lockout signature). Each claim carries its evidence (`ev`: `tm,pl` / `pl:no` / `tm:no` / `amb:same-class,
  cor:band` ...); per-rule gate counters are exported (`inference.attr.stats`) and logged per fight in the lab sweep.
- **Run 13 14:58:38 ET fixed + permanent fixture** (`tests/attr_v2216.lua`, 23 checks; the legacy path reproduces the
  bug): my Lesser Healing Wave at a FRIENDLY target claimed another player's aura on it 63 ms later; my 1238640 self
  buff was guessed "at the friendly target". Fixed by plausibility (pl:no) and the learned self link (effective target me).
- **Hidden "mine" rule found: `secret-timing`** verified a unit-less prediction on ANY unit's aura within 0.35 s. It is
  now target-matched (unit-less = me only) and ambiguity-guarded.
- **Self links**: live-learned per spell (casts, same-frame aura on me), seeded from `Data/SelfLinkSeed.lua` (runs
  9-13 live-observable signals, spell IDs and counts only) and accumulated per account (`ForeverDumpDB.hsmSelfLink`).
- **Live census**: same-class group members (clear `UnitClass` of raidN/partyN) and same-class enemy players on
  plates/arena (60 s), counts only (signal `census`).
- **False-self gate in replay scoring** (`candscore.gate_run/verdict/rule_metrics`): a rule may not raise false-self
  claims on any run and may not lose accuracy beyond noise (max(2 pt, 100/n)). Runs 9-13 before (v2.2.15) -> after:
  false-self claims **56 -> 27**, 0 gate failures; own-cast-frame 28 -> 4 false (precision 87.3 -> 97.8 %),
  aura-on-target 6 -> 0, interrupts 5 -> 0, damage 1 -> 0. Tables: `docs/HSM-STATUS.md`.
- **Gate decisions**: aura-on-me target mismatch -> other (replay: 12 of 13 right). The cadence ambiguity guard cut
  cadence false-self 23 -> 11 but lost accuracy beyond noise (run 10 heal-on-me 69.5 -> 36.4 %): **not promoted**, runs as
  shadow `c-cad-guard`; live heal cadence unchanged.
- **Run 13 dm-damage contradictions (+224/+627/+586) root-caused**: v2.2.15 `cast-frame`/`swing-frame` had no target
  match while live feeds raidN/nameplateN UNIT_COMBAT, so raid members' and other plates' WOUNDs in my cast frame were
  credited to me. Fixed (target match; a group member's WOUND is never mine; melee needs the hit on my target).
  New probe: claimed damage per token family per fight (`fight.dmg.tok`).
- **"You are dead"**: a cast failure while dead is no cooldown evidence (live `fail-dead` U; the analyzer scores
  "You are dead" failures as "precondition", not as refutations; other reasons are unchanged - never loosened).
- **Analyzer**: the per-fight meter join uses the meter SESSION window (a BG record sums every log fight inside
  `[te - dur, te]`, straddlers flagged partial); VERIFY counts shadow P verdicts; `mine:<rule>` accuracy entries with
  false-self and precision.
- **Collect first (lab)**: no arbitrary caps - HSM inferences/predictions/fights/candidate rings, DM snapshots, sweeps,
  live contradictions are uncapped at lab (run 13's fights ring kept only the last 13, which blocked the dm-damage hunt).
  The only limit is the Perf runaway backstop. Release/diag caps unchanged.
- **LabProbes `UNIT_DIED` fix (run 13 finding)**: 1.60.1 `UNIT_DIED` carries a GUID; deaths are counted by GUID type
  only, never keyed by GUID.
- **New shadow candidate `c-hp-net`**: per-unit net HP from readable UNIT_COMBAT amounts + cached max health, scored live
  (V within 5 % of max) against clear UnitHealth and re-anchored.
- **Peak attribution probe**: own `PeakTime` read at load (before/after SV unpack, InitDB), login, capture begin and after
  each capture module (`perf.sessions[n].peakMarks`, PERF report "set between X and Y").
- **Sweep** records instance type, census and per-rule gate counters; it runs after every combat at lab, open world
  and PvE included.

## v2.2.15 (2026-10-09, live engine: capture level lab, parallel shadow rules, two promoted rules, lab probes)

- **User decision (2026-10-09 13:42): capture level `lab`.** FD_Logs now elevates to `lab` by default (= diag + parallel
  candidate rules in shadow mode + lab probes). At lab, perf is **measured and reported, not gated**. The 250 ms
  backstop is a **report** (user decision 2026-10-09: collect first, optimize later): 3 handler calls of >= 250 ms
  within 60 s print a red warning in ForeverDump's own frame and are recorded in the SV (`perf.sessions[n].backstop`);
  lab keeps collecting. Every capture also records the max call (`maxCall`) and each call >= 50 ms (`spikes`, with the
  heap delta of the call: < 64 KB allocated = attributed to an incremental-GC step, else to the handler's own work). Release level (not capturing) keeps its <= 2 % budget and every existing gate; the
  diag gates are unchanged and still run at diag. A saved `captureLevel = "diag"` migrates to `lab` once (configVersion 23);
  `/fdump level capturelevel diag` goes back.
- **Ranked leads** (runs 9-12, 6/6b): `docs/LEADS-v2215.md`.
- **Promoted rules** (beat the old rule on every run with scorable events; falseSelf not up):
  - `aura-me-elim`: a secret aura add on me with no own cast in the 0.35 s window is someone else's (was: unattributed).
    Replay aura-on-me 40.3 / 45.3 / 37.3 / 38.8 % -> 97.2 / 87.4 / 88.8 / 91.0 % (runs 9-12), falseSelf unchanged.
  - `heal-tgt-frame`: a heal on another unit is mine iff my cast at that unit succeeded in the same frame, else other
    (was: unattributed). Replay heal-on-target 0 -> 100 % on runs 9 / 10 / 11 (n 15 / 21 / 16). Attribution only; the
    meter-healing reconcile still counts heals on me.
  - Every other category's replay score is identical to v2.2.14.
- **Shadow candidate rules** (lab only, each with its own ID, a `cand:<id>` prediction verdict per decision and a
  live check): c-aura-me-elim / -tight / -self, c-heal-tgt-frame / -wide / -totem, c-cad-tight / -phase / -amount /
  -phase-amount, c-heal-me-wide, c-int-wide. Live checks: `cand-heal:<id>` (candidate heal total vs the meter per
  session), `cand-aura:<id>` and `aura-me-sweep` (claims vs the post-combat aura sweep). Per-family cost in
  `ForeverDumpLogDB.inference.cand.cost`. Offline: `tools/fdump/candscore.py`, also in the analysis (`candidates`).
- **Lab probes** (`LabProbes.lua`, lab only, every handler under Perf `Lab.*`): per-token aura add/remove counts (also
  secret payloads, presence only) and cast-to-aura latency histograms; heal/absorb detail per token (UNIT_COMBAT
  HEAL/ABSORB, UNIT_HEAL_PREDICTION, UNIT_ABSORB_AMOUNT_CHANGED, UNIT_HEAL_ABSORB_AMOUNT_CHANGED, getter codes,
  prediction->HEAL, absorb-change->ABSORB, UNIT_COMBAT->UNIT_HEALTH, UNIT_DIED->meter type 9 latencies); my per-spell
  meter breakdown at session updates (<= 1/s per type, also in combat; clear values only); a post-combat un-secret
  sweep (+0 ... +10 s, first-clear offset per getter) that also verifies aura-on-me claims live; a 0.5 s in-combat
  readability sampler over extra tokens (targettarget, focustarget, mouseover, soft targets, boss1, arena1-3, ...).
- **GCD due-time sampling** (run 12: gcd 2 V / 17 C, all late observation): the sampler now brackets the predicted GCD
  end (samples at end - 0.05 s and end + 0.05 s). The V test is unchanged; a late first "off" sample whose bracket
  contains the predicted end is U (unmeasured) instead of C; C stays for a predicted end outside the bracket. GCD
  lengths are learned only from tight brackets.
- **In-combat probe spread over frames** (run 12: one 35.75 ms frame 1 s after the first pull): `Probe.RunStaged` runs
  ~33 small steps, one per frame, each under Perf (`Probe.step`); tested max step <= 10 ms (mock).
- **dm-unit-me (run 12, live 94 vs meter 0)**: caused by a summon-cadence false claim (another player's 94 heal at
  13:19:48), not timing. The cadence variants run in shadow; none beats the live rule on all runs yet.
- **DAMAGE_METER handler** (most frequent allocating handler in the BG replay): the structure read and the lab
  per-spell snapshots are coalesced into one deferred job per frame (dirty-only), event keys cached. Its own work is
  < 5 ms in the mock; the remaining 170-230 ms worst calls in the 30 min BG replay are Lua 5.1 GC atomic steps over the
  large capture heap (they vanish with GC stopped). Not optimized further now (user decision 2026-10-09: collect first,
  optimize later).
- Tests: `tests/lab_v2215.lua` (50 checks), `bg_replay_lab` and `perf_bench_lab` (report only + backstop).

## v2.2.14 (2026-10-09, nothing ever goes into Blizzard chat; the running version is visible everywhere)

- **Run 11 (BG, 09:27 ET) ran v2.2.11**: the install had not updated (the SavedVariables say `addonVersion 2.2.11`,
  and the logout pack failed with the old `SVPack.lua:108` division by zero). Its BattlegroundChatFilters error (count
  1099) is the 2.2.11 behaviour, but re-verifying the real source showed that v2.2.12/13 did **not** close the path either.
- **BattlegroundChatFilters taint, real mechanism** (Blizzard source 1.60.1.70245 + the 10/8 taint log):
  `ScrollingMessageFrameMixin:AddMessage -> historyBuffer:PushFront -> headIndex:Increment()`, i.e.
  `SetValue(GetValue() + 1)`. Only `GetValue` goes through `securecallfunction`; `SetValue` writes the SecureNumber
  field `value` in the caller's context. So one addon `AddMessage`/`print` into ChatFrame1 leaves `value` written by
  ForeverDump (taint log: 4x "Execution tainted by ForeverDump while reading field value - SecureTypes.lua:279 ...
  CircularBuffer.lua:49 PushFront"). Every later secure `AddMessage` reads it tainted and writes it back tainted, so
  the taint lasts for the whole session. The BG filter's OnUpdate calls `DEFAULT_CHAT_FRAME:AddMessage` between its
  two loops over `ADDED_PLAYERS` (secret names, so the table is restricted) and the second loop errors on every frame.
  v2.2.12/13 only held lines while in an instance or in combat and then flushed them, or printed `/fdump` output, into
  chat in the open world. That still tainted the session.
- **Fix:** `ns.Print` never writes into a Blizzard chat frame. Lines go to ForeverDump's own message frame (top of the
  screen, 20 s fade, 200 lines) and a 300-line in-memory history; `/fdump msgs [n]` shows them again. The flush to
  chat is gone (`ns.FlushChatQueue` is a no-op). The opt-in `secrets.opsPrint = "chat"` print test now uses our own
  hidden frame.
- **Other chat touch points audited:** no `hooksecurefunc`, no message filters, no `ChatTypeInfo`/`ERR_*`/
  `ADDED_PLAYERS` access, no Blizzard frame `RegisterEvent`. The `CHAT_MSG_SYSTEM` listener is on our own event
  frame. `C_ChatInfo` calls are C API reads.
- **Version visibility:** every line is prefixed `ForeverDump <version>`. The version also shows in the HSM title, the
  FD_Logs ON/OFF lines, the first line of `/fdump status`, and the new `/fdump version`. On login, if the
  SavedVariables were last written by another version, ForeverDump says so once ("version changed: ... last written
  by X, now running Y"); the change is kept in `ForeverDumpDB.versionHistory`.
- **Install steps** (ADDON-USAGE) rewritten: delete the old folder, copy the zip's `ForeverDump` folder into
  `Interface\AddOns`, then check the version in game. Releases stay one full zip `ForeverDump-v<version>.zip` (an
  addon-only + -dev split was tried in the first 2.2.14 build and reverted).
- **Tests:** `tests/bg_chat_taint.lua` is rewritten on the real PushFront/SecureNumber model. In the control, a single
  open-world line an hour earlier still breaks the BG filter. It then runs a whole session (world + BG) and requires
  zero addon lines into Blizzard chat; a static check bans chat-frame, filter, ChatTypeInfo and print references. Put
  a chat print back and it fails 4 checks. The new `tests/version_visibility.lua` (10 checks) covers the rest.

## v2.2.13 (2026-10-09, SavedVariables packing works in the real client: no division by zero)

- **Run 10 root cause:** the game client's Lua raises "Division by zero" on `x / 0` and `x % 0` (stock Lua 5.1 returns
  inf/nan). `SVPack.lua:108` checked for -0 with `1 / v`, so the first `0` in any big variable raised. Every pack failed
  (`svpack.failed = 5`), the variables were written unpacked (331,087 constants, the limit is 262,143) and the file would
  not load. v2.2.11 and v2.2.12 both have this bug.
- **Pack and unpack have no division at all.**
  - -0 is detected from its text form.
  - NaN is written as `(1e999-1e999)`, a subtraction, but only after the client has shown at runtime that it gives
    NaN. If it doesn't, NaN is skipped and counted.
  - ±inf is written as `±1e999` (unchanged).
- **Fallbacks:**
  - (1) A pack pass that raises is retried with a per-value `pcall`. A value that can't be written is skipped and
    counted.
  - (2) A variable that still fails stays plain if the file still fits. Otherwise it is replaced by a small
    `{packFailed=...}` stub (uncountable variables first, then the largest) so the file always loads.
- **Loud warnings:**
  - `P.SelfTest()` packs and rebuilds edge values with the client's own functions at FD_Logs OFF (before the reload
    that writes the file) and warns in chat if it fails.
  - The next login prints any pack problems from the last logout (`P.LoginReport`).
- **Division audit:**
  - `tests/test_div_lint.py` checks every DIV/MOD instruction in `luac -l` output.
  - A constant divisor must be non-zero. A variable divisor must be a reviewed site with a reason.
  - 101 sites total. Zero-possible divisors are now guarded:
    - ReplayLog stats `mbPerMin` (no t0 meant dur = 0);
    - `tapeCap`, `anchorEveryN` and the Verify ring cap (config could be 0);
    - Timing `minSamples`, the Drift mean, the HybridState heal period and the damage-range ratio.
- **`fdump analyze` is faster.**
  - The correlation miner's B→A nearest distances don't depend on the window, so they are now computed once per key
    pair and counted with bisect, instead of once per window (4 windows).
  - The run 5 miner output is byte-identical to before (only the elapsed fields differ), and the miner stage takes
    4.0 s instead of 5.4 s.
- **Tests match the client:**
  - `tests/build_wowlua.sh` builds the official lua-5.1.5 (sha256-pinned) with DIV and MOD raising on zero.
  - The runner (and the serial list) put it first on PATH as `lua5.1` for every job. There is no stock fallback.
  - `tests/svpack_div0.lua` covers round-trips with 0, -0, ±inf and NaN, both fallbacks and the login report.
  - It also proves the shipped v2.2.12 SVPack (`tests/fixtures/svpack_v2212`) fails with the in-game
    "SVPack.lua:108: Division by zero".

## v2.2.12 (2026-10-09, in-BG chat taint fixed; damage-meter rules judged on like-for-like data)

- **In-BG error, count 1433 and rising: "attempted to iterate a table that cannot be accessed while tainted (execution
  tainted by 'ForeverDump')", Locals BattlegroundChatFilters.** Blizzard_ChatFrame/Mainline/BattlegroundChatFilters.lua
  prints "N players have joined the battle" with `DEFAULT_CHAT_FRAME:AddMessage` and then iterates its player-name table
  (secret names in a BG make it a restricted table). AddMessage reads the chat frame's Lua fading state
  (`oldestFadingLineTimestamp`, run 3), and when an addon line wrote it, the rest of that OnUpdate runs tainted. The
  iteration fails before the interval reset, so it fails again on every frame. **Fix:** `ns.Print` never writes into a
  Blizzard chat frame inside an instance (pvp/arena/party/raid/scenario) or in combat. Those lines go to our own
  `ForeverDumpMessageFrame` (top of the screen, fades after 8 s) and are held. They are flushed into chat once you are
  back in the open world and out of combat. The opt-in `secrets.opsPrint = "chat"` sink is skipped there too.
  `tests/bg_chat_taint.lua` models the Blizzard filter: v2.2.11 puts 12 lines into ChatFrame1 inside a BG and the
  model errors on 5 of 5 updates; v2.2.12 puts 0 lines there and has 0 errors. A static check confirms that only the
  `ns.Print` sink writes Blizzard chat, with no hooks or filters.
- **No raw GUIDs on the HSM panel or in the exported HSM tables.** "Last predictions", contradictions and the
  target-cast line show the salted IdKey (`player:<hash>`, `npc:<id>`). `inference.predictions/inferences/
  contradictions/fights/casts/cd` are written with IdKeys. The raw keys stay in memory for matching only
  (`tests/guid_scrub.lua`).
- **Run 9 damage-meter rules collapsed (dm-unit-me 72/72 C, dm-unit-other 910/910 C). Root causes:**
  1. The meter record is the cumulative C_DamageMeter session (38-159 s in the BG). The live side was one fight
     (1-18 s). Meter totals equal the combat log over [stop - duration, stop] exactly. ReconcileDM now sums every kept
     fight inside the session window, soft records included. When the window reaches past the capture or the kept
     fights, or cuts through a fight, the verdict is U, never C.
  2. In a group, `DAMAGE_METER_COMBAT_SESSION_UPDATED` fires for every member's hit. The "dm-frame" rule (a meter tick
     in the same frame means the hit is mine) made live "mine" 7-30x the log (group size 14/15). dm-frame is now
     solo-only (`SetGroupSize` from the clear `GetNumGroupMembers`, on GROUP_ROSTER_UPDATE).
  3. The per-unit check compared different quantities and absences. `world[u].dmg/heal` is what I did TO u, while the
     meter's DamageDone/HealingDone is what u did. Other units are now compared on damage taken only. A unit never
     observed live (81 of 132) is U instead of a 0 that reads as "off". A live value under the meter is a partial view
     (U). C only when live exceeds the meter. My own unit stays strict both ways.
  4. Capture-mode UNIT_COMBAT counted one hit once per token showing the unit (target + nameplateN + raidN, including
     my own raidN). Same-frame, same-payload copies from another token are dropped.
  `tests/dm_session_bg.lua` uses run 9's real fights (counts only, `tests/fixtures/run9_dm_bg.lua`). It passes on
  v2.2.12 and fails on v2.2.11.
- **cd-ready 75/90 C explained.** 46 of the 90 were duplicates: the shocks share category 19, so one sample gave three
  verdicts. Readiness was only sampled when an event happened to arrive (0.3-2 s late). The fix:
  - One verdict per shared-category sample.
  - C only when proven: ready before the predicted end - 0.25 s, or a sample still cooling after the predicted
    end + 0.25 s.
  - V within tolerance. Otherwise U (sample latency).
  - A C_Timer re-read at the predicted end (plus a probe at end + tolerance), so latency stops masking accuracy and
    stops inflating the learned cooldown length.
- Offline: the coverage replay feeds the capture's group size (tape header) to the engine. `bg_replay.lua --group N`.

## v2.2.11 (2026-10-08, SavedVariables always load; static dump only on request; every capture starts clean)

- **Run 9 (30 min BG, diag): `Error loading ...SavedVariables/ForeverDump.lua: constant table overflow`.** WoW loads the
  file as ONE Lua 5.1 chunk, and every distinct string/number literal goes into that chunk's single constant table,
  capped at 262,143. Run 9 had 321,237 (LogDB.replay 142k, StaticDB 114k, CombatLogDB 40k, RecordDB 20k, DB 17k), so
  the whole file failed to load. The data was never lost (offline tools parse it; the copy is on the box).
- **Fix: `ForeverDump/SVPack.lua` (lossless, no caps).** At PLAYER_LOGOUT, after every other logout handler, each
  SavedVariable over 4,000 literals is written into Lua-source chunk strings (at most 50,000 literals / ~1 MB each, so
  each chunk loads as its own function with its own constant table) plus a small graft plan. At ADDON_LOADED the
  chunks are rebuilt (`loadstring` with an empty environment: data only) before `InitDB`, so no module ever sees the
  packed form. A chunk that fails to rebuild keeps the whole blob in `<var>.packedRescue` (saved again, decoded
  offline): nothing is thrown away. Secret values are never formatted (dropped and counted). Numbers are written
  shortest-round-trip (`%d` only inside 32 bits for the Windows client). The pack report is in `ForeverDumpDB.svpack`,
  the rebuild timing in `ForeverDumpDB.svunpack`.
  - Run 9 real SV: 321,237 constants -> **321**, 75.5 MB -> 48.0 MB, 156 chunks; pack 6.2 s, unpack 1.0 s (stock Lua);
    the unpacked tables equal the original exactly (Lua deep compare and the converter's parse, strict types).
  - 30 min BG replay (run 8 data) at 2x: 39.2 MB, 280 constants; at 10x: 102 MB, 629 constants, logout+pack 19.5 s;
    the same 10x save without packing has 456,713 constants and does not load.
  - OFF guard: if a save could still exceed the limit (only with `/fdump set svpack false`), the OFF click warns once.
  - Offline: `luasv.parse_savedvariables` decodes packed vars transparently (`tools/fdump/svpack.py`), so every tool
    reads both formats. New `tools/fdump/svconst.py` counts a file's distinct constants per subtree (exact vs `luac -l`).
  - Regression (`tests/test_v2211_svpack.py`, permanent, in the runner): counter == luac; SVPack edge suite
    (`tests/svpack.lua`: NaN/inf/-0, 2^31+ ints, odd/keyword/boolean keys, holes, forced splitting, 400k literals plus
    the control that the same data written plainly overflows, rescue, OFF guard); BG replay 2x/10x through
    PLAYER_LOGOUT must load in stock Lua 5.1 with <= 10 % of the limit and exact unpack; no-pack control; real run 9
    round trip (when on the box); plain and packed smoke SV parse identically. `tests/bg_replay.lua` gained
    `--logout`, `--no-svpack`, and `--scale N` (N-1 shifted copies).
- **Taint (run 9 taint.log, first line): `Execution tainted by ForeverDump while reading field isdst` at
  Core.lua utcOffset.** Ours: the offset wrote `l.isdst = false` into the table `date()` returned and then called
  `time(l)`. Now plain arithmetic on the two `date()` tables (nothing written, no `time(table)`); same value
  (`tests/utcoffset.lua` in 7 zones incl. +5:30, +13:45, -3:30, +14, -11).
- **Static dump only on request (user decision).** No automatic run any more: not after login, not for a new client
  build, not from `/fdump all` or `ns.RunAll`, not from FD_Logs. The only trigger is `/fdump static run` (`force` =
  alias); `ST.Start` refuses any other caller. `status`/`check` only report (`check`: done / cleared / stale / none).
  `ForeverDumpStaticDB` stays its own SavedVariable and persists in the file until `/fdump static clear`; `status`
  says so. Regression: `tests/static_once.lua` (rewritten for the new contract) + `tests/test_v2211_static.py` (only the
  slash branch calls Start; Static.lua hooks no event; Check never starts; /fdump all and RunAll skip static sections).
- **Every capture starts clean (user decision).** FD_Logs ON (out of combat; ON in combat is refused as before) first
  wipes all previous capture data: all of `ForeverDumpLogDB` (replay tape/sessions, inference/signals/history, damage
  meter, world capture, perf, restrictions, controls/lab/probes, tokens, containers, identity, baseline signature,
  errors/blocked/handler events, counters), the recorder and combat recorder sessions, and in `ForeverDumpDB` the
  verify rings, `secretsObs`/`secretsLive`, `tokenscan`, raw `identities` and the probe/profile sections. Kept: the
  learned store (`learned`, `knowledge`, `timing`, `drift`, `baselines`), config/macro/markers and
  `ForeverDumpStaticDB`. One chat line says what was wiped. OFF never wipes; a capture resumed after `/reload` is not
  wiped. Cost: dropping a few table references. Regression: `tests/capture_wipe.lua` (31 checks). The smoke test now
  asserts the typed ON wipe and keeps the main capture for the converter fixture.
- **Taint-blocked secret operations (run 9 taint.log: 97 secret_blocked, all ours, all deliberate pcall'd probes).**
  89x arithmetic in `Controls.TryTimeLeft` (endTimeMS - GetTime()*1000 for "cast time left"), 6x arithmetic/compare in
  the ops matrix (`OpsFor`) plus its print sink (SecureTypes "value" on our hidden message frame), 2x `len()` (and
  index/compare) in the Lab "secret-string" boundary item. All three now classify first (`ns.ClearNum` /
  `ClassifyValue`) and never operate on a secret: TryTimeLeft returns ok=nil + "skipped" for a non-clear endTimeMS;
  OpsFor records state S + `skipped` with no op and no print; the Lab item records `healthState` S + `skipped`. Clear
  operands still run every op. What each op does to a secret stays documented from runs <= 9 in the master guide.
  Permanent checks: `tests/taint_run9.lua` (runtime with the mock secret + static source order), and the mock client
  (`tests/wowenv.lua`) and `tests/secret_inject.lua` no longer exempt Controls.lua/Lab.lua (any touch fails smoke /
  injection). Not changed: the 84 `oldestFadingLineTimestamp` lines (ChatFrame1 fading reads a timestamp written by
  our ns.Print chat line; benign, any addon that prints does it).
- **Config defaults no longer pad saved lists.** `mergeDefaults` merged a default list into the saved one, so a saved
  2-entry `record.callbackEvents` came back with default entries [3..5]; it now keeps a saved list whole (the ON wipe
  re-runs InitDB, which exposed it: regress "2 callbacks" read 5).
- **BugGrabber after the ON wipe:** errors BugGrabber stored before ON are marked seen, so a poll-mode import at
  OFF/logout does not put them back into the fresh capture's main log (`ForeverDumpLogDB.bugGrabber` still copies
  BugGrabber's whole session).
- **xref:** a combat-log line can be matched once per addon stream (event recorder and combat recorder record the
  same game event independently; one stole the other's match).
- **Tests ~8.7x faster, nothing loosened.** `tests/run_converter_tests.sh` now runs `tests/runner.py`: the same 62
  commands (parity checked by `tests/test_runner_parity.py` against `tests/run_converter_tests_serial.sh`) on 8
  workers in dependency phases, long independent replays in the background. Serial before: 588.6 s wall (svpack test
  crashed at 320 s in that baseline; standalone 507 s); parallel after: ~68-72 s. svpack (a) generates 2x/10x the run 9
  constant density directly (`tests/svpack_real.lua --synth`) instead of a 30 min addon replay, parts run in parallel
  processes, parsed real SVs and constant counts are cached on disk by file sha1 + parser code sha1
  (`tools/fdump/svcache.py`, `.cache/`, never packaged; `FD_SVCACHE=0` disables); the 10x deep compare builds paths
  only on mismatch (was 70 s). secret_inject's 7 modes run as 4 jobs (`FD_INJECT_MODES`), dmrle's two round trips as
  2 jobs with their RLE/no-RLE replays side by side.
- Docs: ADDON-USAGE.md (static, ON wipe, "copy the SV before the next ON", SavedVariables size), INSTRUCTIONS-console.md,
  tools/README.md.

## v2.2.10 (2026-10-08, diag without artificial data caps; lossless DAMAGE_METER_* compaction; real-data BG load test)

The user's rule: don't artificially limit diag data collection (128 GB RAM, PCIe5 NVMe).

- **diag ceilings instead of caps.** Tape 2,000,000 rows, combat ring 1,000,000, recorder 2,000,000 (throttle 1000
  events/s per event type, was 5/s, which dropped 144,677 of run 8's 230,295 recorder events), signals and verify
  250,000, byte budget 4 GB. That is about 10x a 30 min 40-man BG. Reaching a ceiling prints one orange warning per
  ring and sets `ceilingHit` in the capture header. release and test sizes are unchanged.
- **Lossless DAMAGE_METER_* run rows** (`ns.RLE`). Identical DM updates (same event, combat/encounter
  flags, secret markers and every scalar arg) fold into one row: `rc` count, `q` first sequence number, `dt` exact ms
  deltas, `dq` sequence deltas. Used in the combat ring, recorder (folded before the throttle) and replay tape dm rows.
  The converter expands them when it loads the SV (`tools/fdump/dmrle.py` in `Dump`), so every tool sees the raw
  stream. Run 8 replay: combat 95,275 rows stored as 39,401, recorder 125,584 as 69,710, tape dm 56,042 restored
  exactly. Regression: `tests/test_v2210_dmrle.py` (synthetic always; run 8 when present).
- **Gates.** diag is no longer size-gated: `sv_serialize_bench.lua diag` reports a 30 min BG fill (40.1 MB bench fill,
  serialize 3.3 s). test keeps 26 MB, and release gets a 4 MB gate. diag is gated on in-game cost by
  `tests/bg_replay_gate.py`: a real 30 min BG replay with the perf bench's unchanged limits (≤10% capture impact,
  last/first ≤1.5) and nothing lost.
- **Perf budgets (user decisions, 2026-10-08).** The release-level frame-time budget is now 2% (was 1%): the
  release-mode post-capture gate is < 2%. The SPELL_UPDATE_COOLDOWN storm limit is 2% (was 0.5%) at capture and
  release level. The capture (diag/test) ceiling stays at 10%, and the other limits are unchanged. Diag now records every
  storm event (the old 5/s throttle had dropped most of them). Speed fixes keep the stored rows identical and bring the
  storm back to v2.2.9 levels anyway: 0.447-0.480% vs v2.2.9 0.463-0.499%.
  - The recorder reuses the live observer's value codes and builds presized rows.
  - ObserveLive no longer makes a redundant canaccessvalue probe on clear values, and memoizes its doc key.
  - ReplayLog cfg() is memoized.
  - OnCriticalEvent no longer allocates per call.
- **Real-data load replay** (`tools/fdump/bgreplay.py` export + `tests/bg_replay.lua`): fires a captured event stream
  back through the whole addon in the mock client, accelerated, tiled and optionally densified. It measures frame cost,
  memory checkpoints, ring fill and one SV save. Numbers are in PERFORMANCE.md. Exported streams stay in tests/out (raw,
  never packaged).
- **Rule hit/miss through the replay** (`tools/fdump/replayscore.py`): attribution, deaths, interrupts and meter join
  against the combat log, counts only. RLE on/off give identical scores. Rules that read live APIs (target GUID,
  C_DamageMeter values, token health) don't reproduce in the mock yet (see the report).

## v2.2.9 (2026-10-08, hotfix after run 8 (battleground): error attribution, FD_Logs combat-log toggle, diag default)

Run 8 (one 22-minute battleground at diag, v2.2.7; real/2026-10-08-run8-bg/out/FINDINGS.md). No Lua error came from
ForeverDump. ForeverDump's error handler doesn't amplify or re-raise errors and doesn't add taint (one pcall'd capture,
then the previous handler is called once). Two ForeverDump bugs made the run look worse than it was, and they cost it
its combat log:

- **Error attribution (FD bug).** `debugstack` runs inside our handler, so every stored stack began with
  `ForeverDump/Errors.lua` frames, the `[C] pcall` around capture and the client's `[C]: ?` dispatch frame. `/fdump
  errors show` therefore showed ForeverDump in every stack. The OFF health line then counted all 3354 BG errors
  (TweaksForever/Questie/ObjectiveTracker) as "own errors" and classified the tracker nil-call as "inside [C] pcall".
  New `Errors.StripOwn` removes exactly that prefix before the stack is stored, so origins name the real call site. New
  `Errors.IsOwn` counts an error as ForeverDump's only when the message names a ForeverDump file or a ForeverDump frame
  sits below the prefix. Health, the OFF summary and the self-protection limit use it. Regression:
  `tests/run8_regress.lua stack` (the v2.2.8 control counts 145 "own" errors).
- **FD_Logs switched the combat log OFF at ON (FD bug).** The macro body (`/combatlog` and `/chatlog` are toggles) was
  written at login while the combat log was off. You then typed `/combatlog` by hand, and the ON click toggled it back
  off, so WoWCombatLog.txt ends at the ON click (19:40:49) and there is no BG combat log. Now a hand-typed
  `/combatlog`/`/chatlog` (the client's system message) refreshes the macro. A click that would still flip a log the
  wrong way prints a red line before the toggle runs, and the verify line names the cause. One deferred refresh at a time, so the click's own `/chatlog` message doesn't queue
  a second one (smoke: "only the (optional) macro refresh is deferred"). Regression:
  `tests/run8_regress.lua macro` (the v2.2.8 control switches the log off).
- **diag is the default capture level.** FD_Logs ON raises to diag (release stays the default otherwise). The perf
  bench asserts that it measures the capture gates at diag, and the SV serialize gate now also runs at diag with the
  unchanged 26 MB limit (diag fill 24.67 MB). All perf limits are unchanged.
- **Docs: ending a capture.** First `/fdump errors show` and a screenshot, then click FD_Logs OFF (it reloads, which
  saves; no separate `/reload`), then send the files. ON prints the same reminder.
- **Converter/analysis (run 8):**
  - correlate no longer crashes on payloads with mixed integer/string keys.
  - dm-reconcile pairs live fights by time. Before, 25 BG fights all showed the last fight's 1540/1252, because the
    export keeps only the last fights.
  - A fight the combat log file doesn't cover reports `log=None`, never `log=0`.
  - Damage to hostile players counts as mine (PvP).
  - Engine leads from earlier captures in the same SV become info.
  - A short trailing capture (an accidental ON/OFF click at the end) is skipped and reported instead of being
    analysed as "the" capture.
  - ChatFrame fading reads of our own chat lines (`messageInfo`) are benign-chat, not blizzard-frame.
  - Tests: `tests/test_v229_run8.py`.

## v2.2.8 (2026-10-08, hotfix: capture-data bugs, engine health, counters at OFF)

Small, low-risk hotfix after the runs 6/6b/7 analysis (real/2026-10-08-run6/out/FINDINGS.md). No behaviour change for
attribution rules; no new probes.

- **WorldCapture pack (data bug).** `ws` records carry two exact 32-bit words (`p` = fields 1-8, `q` = fields 9-16).
  2.2.6/2.2.7 packed 16 codes in one Lua double and lost exists/health/healthMax (run 7: 92/92 records `p`-only).
  `tools/fdump/worldcap.py` decodes both formats (legacy lost nibbles = `L`). Test: tests/worldcap_pack.lua.
- **NPC IdKey (data bug).** `ReplayLog.IdKey` took the GUID's instance id, so every NPC was `npc:1` and per-unit world
  rows merged. Now the npc id (Creature/Vehicle, `npc:N`). Test: tests/worldcap_pack.lua.
- **Engine starts even when a helper fails.** `I.NewHSM` isolates Knowledge / KnowledgePatch / Timing / Learned (each in
  pcall): a failure costs that seed only (state `degraded`), recorded as selfError `hsm:<name>`. A failed
  `HybridState.New` or `I.Start` is `down` (no half-started engine). Runs 6/6b lost the whole engine to one helper.
- **Visible engine warning.** One chat line per capture (`ENGINE DOWN` red / `engine degraded` yellow, naming the
  failed helper) and the same row at the top of the HSM window.
- **Counters at OFF.** The replay tape header gets `hdr.stats`: `hsm` (up/degraded/down/off), `hsmFailed`, `hsmRunning`,
  HSM counters (numbers only), `guard.tokenScan` / `guard.worldCapture` (CheckInteractDistance skips in combat),
  world-capture samples/slices/dropped, and this capture's selfError count. Run 7 could not show any of this.
- **Converter.** `analyze` engine-health reads `hsm:*` selfErrors and the tape header (`engine down` high,
  `engine degraded` medium).
- Tests: tests/hsm_health.lua (degraded 11, down 10, guard 9 checks; all with `os` = nil) wired into the runner;
  tests/test_v227_findings.py +1 (tape-header health). Plus the post-ship fixes below (coverage fallbacks, meter join by
  time, VACUOUS determinism, real-client slice budget flags).

## v2.2.7 (2026-10-08, run 6/6b error fixes, secret-value audit, static dump once per build)

### Error root causes fixed (runs 6 and 6b)
- **ADDON_ACTION_BLOCKED** (run 6: 47; run 6b SV, cumulative: 198 attributed to FD): `CheckInteractDistance` is protected
  in combat. It was called from `Tokens.lua:296` (token range probe) and `WorldCapture.lua:141` (range snapshot).
  New `ns.CombatGuard`/`ns.CombatLocked`: the probe is skipped in combat (range = guarded code `G`=6) and runs again
  out of combat. No hooks and no protected calls in combat.
- **DamageMeter.lua:51 "attempt to perform boolean test on a secret value"** (run 6 18:30:48, run 6b 18:40:15): the
  `ok and v or nil` idiom tested a secret return value. `field()`/`api()` now return `ok, v` explicitly and classify
  before any truth test.
- **Drift.lua:156 `os` is nil** (FD self-error at each capture start): use the game's `time()` global (`os.time` only if present).
- **ObjectiveTracker `LayoutContents` nil call**: there's no evidence FD is involved. It recurred in 6b after /reload with no
  full dump. It's triggered by CRITERIA_UPDATE/quest progress, and its `[C]` frame is a third-party secure hook.
  FD installs no hooks. New `ns.UISig` instrumentation (`ForeverDumpLogDB.uiIntegrity`) records whether the tracker modules'
  `LayoutContents` still matches their mixin before/after every FD section and capture.

### Secret-value audit (DamageMeter, WorldCapture, ReplayLog, Tokens, Identity, HybridState, Inference)
- Core helpers: `ns.ClearOf(v, want)`, `ClearNum`, `ClearStr`, `ClearBool`, `ClearTable`, `ClearWithCode`,
  `ns.IsTrue` (type check + classify + `rawequal`), and `ns.IsNil` (`type(v) == "nil"`). `ClassifyValue`/`IsSecret` start with a
  `type()` check, so they never truth-test their input.
- No `x and y or z`, `if v then`, `not v` or `==` on an API-returned value before it has been cleared. Event handler
  arguments (`rawUnit`, `rawA1`, ...) are cleared on entry.
- HybridState boundary guard: every On/Record/CD/GCD/Set/Learn entry point scrubs secret scalars to nil, copies tables
  without their secret fields (depth 3), and skips calls whose required key is nil (counter `secretDropped`).

### Static dump: once per client build (no longer at FD_Logs ON)
- New `Static.lua` and its own SavedVariable **`ForeverDumpStaticDB`** (docs, api, globals, strings, widgets, templates,
  frames, addons, cvars, protected, extras, plus the v1 apis/events/enums/cvars).
- Build signature = `GetBuildInfo` + a djb hash of the sorted `C_*` namespaces with their function counts + the Enum count. At
  login (out of combat, after `static.loginDelay`=15 s), FD runs the full dump once **only if the signature changed**:
  chunked, deferred until idle, paused in combat and during captures, with no user action. Completion is marked per build.
- `ForeverDumpDB` (capture data) only holds the ~1 KB marker `static = {key, build, version, toc, apiHash, ...}`.
- `FD_Logs ON` no longer queues any dump.
- Commands: `/fdump all` = manual force (it also upgrades a waiting auto run), `/fdump static [status|run|force|check]`,
  `/fdump static clear` (wipe after ingest; the marker stays, so it won't dump again for that build).
- Size (real run 6): SV total 14.31 MB, of which static is 11.61 MB. A typical capture after `/fdump static clear` is 2.70 MB
  (run 6b: 15.45 MB → 3.83 MB).
- Converter: reads `ForeverDumpStaticDB` (and the legacy layout). When static data is missing it falls back to
  `fixtures/forever-70245` (`Dump.static_source`).

### Tests
- `tests/test_v227_secret_lint.py`: a permanent static lint (taint flow from API/handler returns to truth/compare/index
  sinks, no `and IDENT or`, no inline `select(2, pcall())`, the Core contract, and HybridState BOUNDARY coverage) plus a self-test.
  Against v2.2.6 it fails (it catches DamageMeter.lua:51).
- `tests/secret_inject.lua`: injects secret booleans, numbers and strings into every field (7 modes × 2 passes). It checks for
  escaped errors, uses a line hook to find secrets reaching truth or compare sites, checks for SV leaks, and checks the meter `S` codes.
- `tests/static_once.lua`: one dump per signature, deferral in combat and during capture, the force/clear commands, and the marker-only capture SV.
- `tests/test_v227_lint.py` + `tests/combat_guard.lua`: no protected API without `ns.CombatGuard`; combat guard behaviour.
- The perf gates are unchanged (storm ≤0.5%, raid40 N=5 median ≤0.12 ms).

### Post-ship fixes (after ForeverDump-v2.2.7.zip; shipped in v2.2.8)

- **WorldCapture pack precision (data bug).** The 16 five-state codes were packed into one 64-bit value in a Lua double
  (53-bit mantissa); whenever a high field was set the low nibbles (exists, health, part of healthMax) were rounded away.
  Now two exact 32-bit words (`p` = fields 1-8, `q` = fields 9-16). `tools/fdump/worldcap.py` decodes both and marks
  legacy lost nibbles as `L` (never a wrong code). Test: tests/worldcap_pack.lua (5000 random round-trips).
- **ReplayLog.IdKey npc (data bug).** The Creature pattern captured the instance id, so every NPC was `npc:1`. Now the
  npc id field (Creature/Vehicle and `npc:N`). Test: tests/worldcap_pack.lua (4094/3573, distinct NPCs distinct keys).
- **Engine health in analyze.** New high leads "capture module failed" (selfErrors where=capture:*) and "live HSM did not
  run" (combat recorded, no HSM export, no decide records). Test: tests/hsm_alive.lua (whole capture with `os` = nil)
  and tests/test_v227_findings.py.
- **coverage fallbacks when the HSM did not run.** Target timeline rebuilt from my offensive log events
  (`targetSource=log-inferred`) and own casts rebuilt from raw UNIT_SPELLCAST_* (`castSource=raw-events`); both are
  bannered in COVERAGE.md. Run 6 interrupt replay 0/1 → 1/1.
- **damagemeter_join picked the meter fight by index.** The SV keeps earlier captures' meter fights, so run 6b fight 1
  was joined with run 6's meter (false per-unit "off"). Now by time (epoch in [start-2, stop+15], deep snapshot first,
  None when nothing matches). Test: tests/test_v227_findings.py.
- **replay determinism.** "OK (0 groups)" with combat on the tape is now VACUOUS and fails the summary (it hid the dead
  HSM in 6/6b). Test: tests/test_v227_findings.py.
- **perf.** A real capture whose mean WorldCapture/TokenScan slice exceeds the bench budget (0.10/0.12 ms) is flagged
  (6/6b: 0.126-0.130 ms unflagged). Test: tests/test_v227_findings.py.

## v2.2.6 (2026-10-08, sealed replay tape + dual verbosity)

- Damage-meter **self-reconcile** (liveEst ↔ post-combat meter ↔ offline CLEU): multi-metric match/off/unexplained
  verdicts + per-unit IdKey sources; HSM UI status. Capture-only **WorldCapture** logs casts/auras/hp/power/threat/range/target-of
  (five-state codes, tape `ws`). See `docs/FINDINGS-v226.md`.

**One zip / one build.** Default verbosity is **release** (<1% CPU). FD_Logs ON elevates to **test** (or configured `captureLevel` diag, ≤10%) for tracing, data gathering and live evaluation of prior findings; FD_Logs OFF restores the prior level. `/fdump level [status|release|test|diag|capturelevel …]` is a manual override between captures. Perf gates measured in the same build: release <1%, capture ≤10%.

### Addon
- **ReplayLog.lua**: session_hdr (verbosity, seeds hashes, group/map/combatLog, ring caps, TimeAnchor), sealed tape ring (hdr/decide/verdict/anchor/map/sec/api) with byte budgets + priority drops, cast-sync anchors on own SUCCEEDED (every N in release; all in test), salted FNV `IdKey` (no raw GUIDs/names), overflow notes for verify/recorder/combat rings.
- Capture module wires BeginCapture/EndCapture into FD_Logs; elevate/restore levels.
- Inference: OnInfer/OnVerdict → decide/verdict; OnOwnSucceeded anchors; test-only OnApiSample on CDPayload change.
- Identity: test-only OnMapDelta (token family + IdKey).
- Recorder/CombatLog: test-only critical-event sec nibbles (N/S/T/K/C packed); NoteOverflow on ring wrap.
- Verify: dynamic VerifyCap from ReplayLog level.
- Commands: `/fdump level`; status prints verbosity. HSMUI shows `log:release|test (capture)`.
- Core: `config.replay` defaults; VERSION 2.2.6 / SCHEMA 3; toc loads ReplayLog after Verify.

### Converter
- `fdump replay DUMP [-o out/replay] [--file WoWCombatLog]`: reconstruct tape, decide determinism, privacy scan, optional CLEU cast-sync join → REPLAY.md + replay.json.

### Tests / perf
- `tests/test_v226_replay.py` (12): tape order, determinism, privacy, CLEU join, Lua API surface, toc/commands/config.
- `perf_bench.lua`: capture-mode gate ≤10%; post-`logs off` release window <1%.
- PERFORMANCE.md: dual-level rule.
### Follow-ups (same day)
- Golden asserts restored (canonicalize token-gate bug fixed; `higher-order:` leads re-emitted).
- `fdump replay` re-executes `Lib/HybridState.lua` offline; exact-match decide determinism + CLEU anchor diff;
  `tests/replay_tape_harness.lua` + `test_v226_replay_exec.py` (incl. perturbed-tape failure).
- Capture-mode shadow verdicts: `shadow-dm-type7`, `shadow-totem-heal` (evaluate prior findings live, non-acting).

### Damage meter + world state (same day, end-to-end)
- **Caps:** tapeCap binds 25-min 40BG capture under ~30 MB SV; KEEP decide/verdict/anchor/shadow/reconcile; `ws`/sec/api thin first with counted overflow. Lazy rings. `SerializeProxy` reports MB/min + serializeMs. See `docs/CAPS-v226.md`.
- **In combat:** every `DAMAGE_METER_*` on tape (type, sessionID, codes); structure classify ~2/s/type (codes/lengths only).
- **Post-combat (capture deep):** every `Enum.DamageMeterType`, all sources/spells/details IdKey'd, DamageTaken + EnemyDamageTaken, Deaths, interrupts, dispels, session history → `ReconcileDM` multi-metric + per-unit.
- **WorldCapture.lua** (capture-only): casts/auras/hp/power/threat/range/target-of across all tokens → tape `ws`.
- **Offline:** `damagemeter_join` three-way live↔meter↔log in `fdump analyze`; facts → miner findings / correlate markdown. Run-5 smoke: 3 fights, 9 match / 1 off / 5 unexplained.
- **Tests / perf:** `test_v226_reconcile.py`; perf_bench `wc40` world-capture storm (≤10% capture ceiling); `sv_serialize_bench.lua` (test ring fill ≤26 MB). Raid40 scanner slice gate is strict at budgetMs (0.12): median of N=5 per-run maxSlice and p99 (every raw run logged). Storm gate already uses median of 3 windows (raw windows logged; a single window may exceed 0.5% while the median holds).


## v2.2.5 (2026-10-08, offline higher-order correlation)

**Converter / tools (no addon Lua changes; no new zip)**
- `correlate_findings.py`: distinct-findings layer — token-alias collapse (`targettarget`→`player` when strong; same-frame payload dedup), add-½ smoothed lift + CI (no 9999), chain minimality, holdout status (`cross-run` / `held-1` / `provisional` / `failed`), echo appendix, ≤12-row Distinct findings table.
- `correlate_ho.py` / `correlate.py`: profiles full|quick; identity/elim preserved after lift smoothing; `--quick` / `--no-higher`; elapsed printed.
- Confirmed offline: (a) SPELL_UPDATE_COOLDOWN clear spellID already in CooldownTracker CDPayload; (b) totem-heal live signal (review-only; on-me heals already attributed); (c) DM type 7 ↔ enemy melee; (d) meter frame-join already live; (e) interrupt identity provisional on run 5.
- Tests: `test_v225_ho.py`, `test_v225_findings.py` (alias/lift/minimality/flags/echoes + expected ids on real correlate.json).

## v2.2.4 (2026-10-08, run 5: live attribution, cooldown/GCD tracker, learned data, drift guard, offline analysis)

Run 5 was the first capture with an ungrouped player (a mage) hitting my target, an interrupt (Earth Shock) and three fights
with a post-combat C_DamageMeter read. Findings: `real/2026-10-08-run5/FINDINGS.md`.

**Standing design rule (drift):** every learned or static value is a starting point. Values are keyed by build, re-verified
live, decayed when not re-confirmed and drift-flagged with a changelog entry; `fdump analyze` proposes the seed update and
nothing is hard-coded without an override path (ADDON-USAGE.md "Drift", guide section 12).

### Addon

- **Live source attribution (HybridState MINOR 3).** `UNIT_COMBAT` is clear on 1.60.1 in combat (action, amount, school) for
  player and target. Rules attribute each hit from clear timing only: my cast frame, the swing lag (melee combat text lags the
  swing by about 0.46 s), the `DAMAGE_METER_COMBAT_SESSION_UPDATED` frame, interrupt cast + meter, and elimination. Run 5:
  damage on my target, damage taken, heals, misses and the interrupt all 100% correct against the log (before: 0%), and no
  other-player damage credited to me. The secret-timing window is 0.35 s (was 2.4 s).
- **Ledger (MINOR 4).** "Collect while available, retain, resolve later": token→GUID, aura instances and cast GUIDs cached while
  clear, LRU-capped, with live / cached-fresh / cached-stale / maybe-removed confidence. Identity.lua feeds it. Enemy
  cast-duration model per NPC id (interrupt window in the HSM window).
- **Cooldown / GCD tracker (MINOR 5).** Per-spell ready / gcd / cooling state fused from my clear casts, isActive / isOnGCD
  flips, categories, `UNIT_SPELLCAST_FAILED` and clear API reads. O(due + budget) per event (see the perf gate below).
- **Timing.lua + Data/spell-timing.lua.** Per-spell GCD/cooldown table, seeded offline and learned live per build (running
  min/max/sum/count, LRU). Known answers: totems 1.0 s, Lightning Shield 1.5 s.
- **Learned.lua + Data/learned-seed.lua.** Persistent learned spell / NPC / class DB per build: spell ids, cast times, NPC kits.
  Player names and GUIDs stay in memory and are never saved.
- **Drift.lua.** Drift guard: seeds lose to consistent live disagreement; every override is logged with old, new, evidence and
  build in a changelog that `fdump analyze` turns into a seed proposal.
- **Verify.lua.** Live verification ring: verdicts V / C / U for cooldowns, cast ends, damage ranges, interrupts and meter
  totals; readability flips against the baseline are kept in an "unexpected" LRU.
- **Group-aware token scanner (Tokens.lua `T.Scan`).** Budgeted round-robin discovery over party / raid / nameplate / boss /
  arena tokens in combat: secrecy codes per token family and context only, alias/duplicate detection, 0.12 ms per 0.1 s slice
  with a per-field deadline.
- **Knowledge.lua.** The parser classifies every duration phrase by clause, with a permanent semantic lint. Tooltip header
  cross-check against the APIs, every power cost (multi-cost spells), 20 tooltip lines, spell→aura map learned by correlation.
  `cdLineProbe` records the tooltip line count/types for the extra-line cooldown hypothesis. `hsm.tooltipCooldownSignal` stays
  **off** (not proven).
- **DamageMeter.lua.** C_DamageMeter as evidence: event counts per type, HSM timing, one field classification per combat and
  after combat. Post-combat reconciliation in the HSM ("others on my target = live total − meter mine").
- **HSM window.** Rows for attribution / meter, a Ledger section, GCD (tracker) bar, cooldown lines (max 8 + "+N more"),
  interrupt window; dirty-only line-pool redraws at most every 0.5 s.
- Data/KnowledgePatch.lua: facts observed in earlier real captures (generated by `fdump verify-live` / `analyze`).

### Converter (tools/fdump)

- `coverage`: combat-log (truth, offline) vs live matrix per category × source × context; HSM before/after replay scoring;
  timing models; per-fight log vs C_DamageMeter; the other player on my target; meter field classification. New sections:
  cooldown/GCD tracker vs the log, cooldown model vs log fails, enemy cast bars, overheal, Ledger, live verdicts.
- `knowledge` (knowlint): reparse with the current parser, lint, header-vs-API checks, log cross-check, tooltip extra-line
  cooldown evidence table.
- `verify-live`: verify ring joined with the log (VERIFY.md) → knowledge patch.
- `analyze`: the whole pipeline with history captures → ANALYSIS.md (ranked leads with severity / evidence / timestamps),
  analysis.json, VERIFY.md, TOKENS.md, knowledge patch, `spell-timing.proposed.json`, `learned-seed.proposed.json`.
  `--write-seed` adopts the merged seeds (idempotent per evidence id; conflicts stay flagged, never overwritten).
- New modules: `timing.py`, `learned.py`, `tokenscan.py` (TOKENS.md generator: matrix, cost, alias, change alerts),
  `misses.py` (every missed log event with a reason class and a fix hint), `correlate.py` (co-occurrence miner live↔log with
  holdout across captures and rare-pair p-values), `analysis.py`.
- Privacy: miner keys redact player names (`<player>`; UNIT_SPELLCAST_SENT target names are kept only for known NPCs).
- Guide: new section 12, "Cooldown/GCD tracker, learned data and the drift rule" (`guide --analysis analysis.json`).
- Ledger scoring fix: "maybe-removed" entries are doubts, not claims. They were counted as 35 wrong claims; the log
  confirms 35 of the 50 doubted removals.

### Tests

- `tests/test_v224_tools.py` (synthetic, 64 checks): timing merge / promotion / conflicts / idempotence / known answers / Lua
  writer, learned from_log / from_sv / merge / anonymisation, TOKENS.md, analyze leads, correlate (planted link found, noise
  rejected, rare pairs), verify_live judging, misses grouping and hints, knowlint data checks.
- `tests/test_golden_run5.py` (real run 5, 20 checks; skipped without the capture): the miner rediscovers the Earth Shock
  interrupt link, the known-answer GCD table holds, no refuted verdict, cooldown verdicts 100%, no rule-gap misses, the
  cd-line hypothesis stays not proven, seeds idempotent.
- Lua: `knowledge_parse.lua`, `timing.lua`, `learned.lua`, `hsm.lua` (160), perf bench with gate asserts.

### Perf gate

- **Perf gate passed** (PERFORMANCE.md, "Perf gate"):
  - aged/fresh frame-time impact 1.00-1.18 (gate <= 1.5; aged 0.19-0.25%);
  - SPELL_UPDATE_COOLDOWN storm 0.29-0.39% (gate <= 0.5%);
  - 40-man scanner max slice 0.093-0.115 ms (budget 0.12 ms).
- **Bench artifact found.** Most of the "aged session is slower" growth was glibc fastbin consolidation on the first
  >= 1 KB malloc after a large free. Lua instruction counts were flat. `tests/perf_bench.lua` re-executes itself with
  fastbins off (`FD_BENCH_ALLOC=native` to compare). The earlier "Lua string-hash collision" explanation for the HSM body
  was wrong; the line-pool rendering stays.
- **CooldownTracker per-event cost is now O(due + budget)** instead of O(cooling spells):
  - dense active array, lazy min-heap of predicted ready times and a due set;
  - round-robin re-reads at most once per second per far spell;
  - `HS:CDCheckList()` with a reused buffer;
  - the UI "latest cooldown" pointer is maintained by the tracker, and at most 8 cooldown lines are rendered.
  - Storm handler: 4,142 → 1,654 Lua instructions per event.
- **Allocation-free hot paths:**
  - `Secrets.ObserveLive` scratch tables and memoised key/context strings;
  - O(1) recent-list repeats;
  - numeric alias keys in `Tokens.Scan.OnCast`;
  - token-map entry reuse, cached families and profiler clock;
  - SPELL_UPDATE_COOLDOWN payload codes classified once.
- **Scanner budget enforced inside the loop.** The deadline is checked after every field read; a cut-off token resumes at
  the next field in the next slice. The `tokenscan.bailMs` margin is 0.04 ms, and `cost.overBudget` is recorded per
  capture. The scanner frame is timed by the self-perf monitor.
- **Bench and tests:**
  - 25-cast windows (4 fresh, 5 aged) with median gates; storm median of 3 windows.
  - New asserts: aged/fresh ratio <= 1.5, storm <= 0.5%, slice max <= budget.
  - `tests/learned.lua`: per-field deadline and resume, plus CDCheckList (due set, once-per-second round-robin,
    swap-remove, latest re-pick, heap rebuild).
  - Runner now runs knowledge_parse / timing / learned and test_v224.
- Fixes: `fdump all`/`guide` no longer try to serialise the in-memory coverage context (`_ctx`). `probes.dominant` accepts
  count-valued fields (`powerCost.n`).

## v2.2.3 (2026-10-07, run 4: frame-rate drop, self-perf monitor, live HSM verification)

- **Frame-rate root cause.** The run-4 report was "as I cast more abilities the framerate drops".
  - `ns.Meta()` → `ns.ProjectInfo()` walked all of `_G` (52,517 globals, about 17 ms per walk) on every call.
  - It was called from hot paths. The HSM window redraw called it once per text line at 5 Hz (spell names → `Knowledge.DB()`
    → `K.Build()` → `ns.Meta()`), and the line count grew with the predictions. Every `UNIT_AURA` called it through the
    container DB, and so did every combat-probe read in lockdown (`PathBlocked`), `Knowledge.Learn` and `Errors`.
  - In game the application frame time went from 20.7 to 59.3 ms during the 86 s capture.
  - Fix: the project info is now cached for the session. The walk moved to `ns.ScanProjectInfo()`, and the hot paths use the
    new cached `ns.Build()`.
- **O(n) work removed from per-event paths:**
  - `HybridState.push` trims in amortised O(1); it no longer calls `table.remove(list, 1)` on every insert once full.
  - `Appliers` is cached per knowledge version.
  - The HSM text uses counters instead of re-walking every inference input.
  - `CombatProbe`/`Containers` contexts are cached per frame (they made 6 pcalls per call).
  - `GetAuraSlots` is skipped after it errors in a context.
  - Containers `ObserveEvent` exits early in O(1).
  - Stale unknown-duration auras (300 s) and empty per-GUID unit state are dropped.
- **HSM window: dirty-only, throttled redraws.**
  - The window registers its own `UNIT_SPELLCAST_*`, `UNIT_HEALTH`, `PLAYER_TARGET_CHANGED` and `SPELL_UPDATE_COOLDOWN`
    events, only while it is shown.
  - Changes mark it dirty. The OnUpdate is installed on demand, runs at 10 Hz and removes itself when idle, so there is no idle
    OnUpdate.
  - Text is rebuilt only when `hs.version` changes (at most every `hsm.updateInterval`=0.25 s), and countdowns tick at 1 Hz.
  - Spell names are cached.
- **HSM layout.** Eight fixed 14 px rows with a label column:
  1. player cast predicted
  2. player cast engine
  3. target cast predicted
  4. target cast engine
  5. cooldown predicted
  6. real cooldown (its own row with icon swipe and value)
  7. player HP
  8. target HP

  The text body starts below row 8. This fixes the "player HP, secret (engine-displayed)" line overlapping "real cooldown".
  Idle bars say "idle", "not casting", "no unit" or "none" instead of staying empty.
- **Why run 4's predictions stayed "unverified".**
  - All 16 predictions had no spell knowledge. The knowledge pass finishes asynchronously after `Inference.Start`, and the HSM
    copied knowledge only once, at start.
  - In combat the UNIT_AURA payload is a wholly secret list, so no spellId could be matched.
  - Fixes:
    - knowledge is fed live (`Knowledge.onCollected` plus a lazy lookup on the first cast)
    - an observed aura with a clear spellId verifies a prediction even without aura knowledge (Ghost Wolf)
    - new timing verification: a secret `addedAuras` on the predicted unit right after the cast verifies the prediction as
      "aura event seen (secret payload, timing)", with rule `secret-timing` at medium confidence. In run 4 this would have
      verified Flame Shock (+4 ms) and Lightning Shield (+4 ms).
    - until-cancelled auras are learned.

  No values are read from secrets; only the secret-vs-nil fact and event timing are used.
- **Self-perf monitor (new `Perf.lua`, always on in FD_Logs).** Writes per-handler calls, total/max ms and 15 s windows, plus
  5 s samples (heap, fps, C_AddOnProfiler application/overall/own, table sizes) to `ForeverDumpLogDB.perf`. Numbers only, keeps
  4 sessions. `/fdump perf` prints the top handlers and the % of wall time.
- **PERFORMANCE.md (standing rule):**
  - <1% framerate impact
  - no idle OnUpdate
  - O(1) per event
  - dirty-only throttled redraws
  - heavy work out of combat or offline
  - every perf test run finishes within 2 minutes

  Enforcement:
  - `tests/perf_bench.lua` (25/50/100-cast checkpoints plus an aged 2,110-cast session, `--cap` 100 s) and
    `fdump.py perfcheck --strict` are part of the default runner, which now uses `pipefail`.
  - `migrate` reports a Performance section.
  - Generated mocks ship `perf_guard.lua` and `spec/perf_spec.lua`.
- **Benchmark (mock client, box Lua 5.1).**

  | build | ms per event | ms per frame | frame impact |
  |---|---|---|---|
  | v2.2.2 | 3.0-3.6 | 1.5 / 2.6 / 5.2 / 9.5 after 1 / 2 / 4 / 8 casts (grows with casts) | 57-64% |
  | v2.2.3 | 0.026-0.047 | 0.004-0.009, flat through 2,110 casts | 0.04-0.08% |

  v2.2.3 leaves 0 idle OnUpdates.
- **Converter:**
  - `fdump perf` writes PERF.md and perf.json. It flags impact ≥1%, per-call cost growing with session length and unbounded
    sizes, and falls back to the profile snapshots for older SVs. It is part of `all`.
  - New `fdump perfcheck` command.
  - taint: Blizzard mixin code on our own hidden ScrollingMessageFrame is now `contained`. `ChatFrameN:UpdateFading`
    reading `oldestFadingLineTimestamp` after one of our chat lines is now `benign-chat` (no secret, no blocked action).

## v2.2.2 (2026-10-07, run 3: blocked-action attribution, containers, HSM summons)
- **Blocked actions:** the 36 run-3 `ADDON_ACTION_BLOCKED "UNKNOWN()"` came from `CheckInteractDistance`, which is protected in combat for
  friendly units (CombatProbe.lua:163 via :412). Every probe call is now marked (`ns.ProbeMark`/`ProbeDone`), and Errors.lua records
  `resolved = "Module:path(unit)"` plus our own stack frames. Blocked paths are learned in `ForeverDumpDB.blockedPaths[build]` and skipped in
  combat. `CheckInteractDistance` is skipped up front for non-hostile units, and docs-tagged Protected/HasRestrictions/RequiresNonCombat
  rows are skipped in lockdown.
- **No more secrets in ChatFrame1:** the ops-matrix print test writes to our own hidden ScrollingMessageFrame (`secrets.opsPrint="chat"`
  restores the old behaviour). This removes the `ChatFrame1:UpdateFading` taint.
- **Containers module (new, permanent):** walks every probed return recursively (depth 3) and records each field's state
  (absent/nil/secret/container/clear), the container flags (issecrettable, canaccesstable, hasanysecretvalues, HasSecretValues()),
  length/clear count and key lists. Coverage is per context (ooc, combat, restriction states) and per unit class (player, target NPC,
  party/raid, pet). Probes: aura by index (4 filters), GetAuraSlots, GetUnitAuras, count by iteration, aura duration, cast info, health,
  power, name, GUID, spell cooldown/charges/info, GetTotemInfo, and the UNIT_AURA payload. Runs automatically in every FD_Logs capture
  (ooc, combat start/end, restriction flips, encounters); in combat only non-protected reads. Stored as `ForeverDumpLogDB.containers`,
  classifications only, never values.
- **HSM:** totems are summon predictions on the player, verified live through `PLAYER_TOTEM_UPDATE` + `GetTotemInfo`. Purge/cleanse
  spells are dispel predictions. Self, helpful and summon spells with a hostile target are attributed to the player. Up to 4 sessions are
  kept (`inference.history`, `hsm.keepSessions`).
- **HSM window:** fixed 190 px label column (no more bars over the labels), a value text on each bar, wider default window, and the HP bar
  resets when the unit is gone.
- **Knowledge parser:** "health" is no longer a heal. Totem durations are summon durations, not aura durations. Dispel and weapon-imbue
  text is recognised.
- **Identity:** on Forever `UnitName("player")` returns (first, last), so the last name is taken from that second value.
- **Converter:** `fdump containers` (CONTAINERS.md, containers.json, schema diff vs `fixtures/baselines/<build>/containers.json`,
  `--write-baseline`; also part of `all`). Legacy SVs are reconstructed from combat-probe cells and UNIT_AURA events. `taint` classifies
  every line as expected / contained / probe-blocked / blizzard-frame / unexpected. `errors` shows the resolved source and the learned
  blocked paths. Offline inference scores summons (SPELL_SUMMON, plus lifetime when an end event exists) and dispels (SPELL_DISPEL*).
  A cooldown is only judged when a recast falls in its window. Replay ignores gaps >180 s and is seeded from SV knowledge.
  Multi-session history is scored.
- **Guide:** new "Partial secrets and containers" section (aura field matrix per context and unit class, UNIT_AURA payload, counts,
  partial containers, diff).
- **Tests:** hsm.lua v2.2.2 block (77 checks), busted `tests/spec/containers_spec.lua` (mocked mixed tables), `tests/test_v222.py`.

## v2.2.1 (2026-10-07, player identity)
- **Addon:** every capture start (FD_Logs ON and resume after `/reload`) writes the player identity to the SV meta
  (`ForeverDumpDB.meta.identity`, also `ForeverDumpLogDB.identity` and `ForeverDumpDB.identities[guid]`): `UnitName`,
  `UnitFullName`, `GetUnitName("player", true)`, `GetRealmName`, `GetNormalizedRealmName`, `UnitGUID`, `UnitClass`, `UnitLevel`,
  `UnitRace`, plus first/last name split (Forever characters are "First Last"; the combat log shows only `First-Realm-Region`).
  Every value is classified first. A secret value is never stored: it is recorded as code `S`, `secret[field] = true` and
  `anySecret = true`, which also tests empirically whether the player's identity is ever secret.
- **Converter:** `--player` (inference, guide, xref, cl-compare) and `combatlog --forever-player` accept a GUID, "First Last",
  a first name or Name-Realm, and need no flag at all. The log owner is chosen from the SV's identity by GUID, then by name,
  then from the optional `tools/fdump/characters.json` (for logs without a matching SV; ships Uglaz Doomaxe and Pally-Palzy),
  then by the old unit-flags 0x511 auto-detect. Older SVs fall back to the recorder sessions' playerGUID. `combatlog
  --forever-player auto [--sv ForeverDump.lua]`.
- **Anonymizer (`fixtures`):** takes the names and GUID from the SV identity (plus characters.json) automatically and scrubs
  first **and** last names anywhere in a line (`PlayerN` / `SurnameN`, word boundaries), in addition to the combat-log
  name/GUID rules. The leak scan checks those names and GUIDs too.
- Tests: `tests/hsm.lua` identity checks (54 total, including a secret UnitName that is flagged and not stored);
  `tests/test_identity.py` (name forms, SV GUID/name selection, characters.json fallback, anonymizer, fixtures end to end, run 2).

## v2.2.0 (2026-10-07/08, after the second real run)
**Fixes from run 2**
- **Bug B (Blizzard UI errors while FD_Logs was ON).** v2.1 post-hooked `EventRegistry.TriggerEvent` with
  `hooksecurefunc`. On Forever 70245 the hook trampoline breaks secure-dispatched `TriggerEvent` calls: Client.log had 405
  `attempt to call a nil value` errors raised by `[C]: in function 'TriggerEvent'` (GlobalCallbackRegistry,
  MainActionBarFrame, tooltips, ...), all inside the capture window. v2.2 installs **no hooks at all**. EventRegistry callbacks
  are opt-in (`record.callbacks`) through `EventRegistry:RegisterCallback`. `tests/regress.lua b-v21` reproduces the bug
  with the v2.1 code and `b-v22` proves zero errors. `/fdump health` checks for hooks and foreign wraps.
- The MoneyFrame "arithmetic on a secret value" taint in run 2 came from **TweaksForever** (`UI/Spellbook.lua:402`), not
  ForeverDump.

**Addon**
- **Verifier v2.2.** Five-state classifier: nil / secret / container with secrets / container clear / clear. Duration objects
  use `:HasSecretValues()`. SecretWhen* is expanded per field, and same-frame `C_Secrets.Should*BeSecret` predicates decide
  contradictions. Against the run-2 data the verifier now reports 0 CONTRADICTED and 0 UNDOCUMENTED-SECRET (v2.1 said 7 and 5,
  all classifier artefacts), plus 4 INCONCLUSIVE and 481 CONFIRMED.
- **Restrictions tracker** (`/fdump restrictions`). `C_RestrictedActions` state per type (Combat, Encounter,
  ChallengeMode, PvPMatch, Map, Chat), each flip stamped on the common timebase, a flip probe set at the event and on the
  next frame, and the always-on checks (combat log, addon chat).
- **Controls and ops matrix** (`/fdump secrets controls`) record what addon code can do with a secret (arithmetic,
  compare, tostring, concat, # ...): booleans and error texts only. The forced-restriction CVar sweep is opt-in and always
  restores the original values.
- **Workarounds lab** (`/fdump lab`). Sanctioned secret-value paths (StatusBar/FontString sinks, curves, duration
  objects), checked at the boundary, never extracted.
- **Every FD_Logs capture runs the probes automatically** through `ns.captureModules` (start at ON, stop at OFF, pcall-isolated):
  - **Combat probe set** (`CombatProbe.lua`, `/fdump combat`). Health, power, casting, movement, identity, threat, range,
    markers and auras (6 filters, slots, by-instance, duration objects, dispel colour) per unit class
    (target/focus/party/nameplate/player, hostile/friendly, NPC/player) and context (ooc/combat/restricted/encounter). Includes
    event payload codes, cast time left (derived vs duration object), the ops matrix per category, and the
    **detectability answers**: casting? which spell? any aura? MY aura? what aura? stacks/duration? dispellable?
    Each answer is yes/partial/no with evidence. Bounded and throttled; triggered by ON, combat start, restriction flips,
    and target/focus changes.
  - **Unit token survey** (`Tokens.lua`, `/fdump tokens`). Once per context per capture: 26 token families (player ... nameplate1-40,
    soft targets, compound chains) × UnitExists/GUID/Name/IsUnit/CanAttack/IsPlayer/Health/HealthMax/CanCompareUnitTokens/
    ShouldUnitIdentityBeSecret, split by resolved vs not.
  - **Spell knowledge** (`Knowledge.lua`, `/fdump knowledge`). The player's spellbook (≤150 spells, chunked): GetSpellInfo,
    description, base cooldown, power cost, charges, the secrecy functions, and tooltip lines with per-line codes. Durations
    and damage/heal ranges are parsed from clear text only. Stored per build, classified out of combat and in combat.
    Class/spec are recorded too.
  - **Inference engine + hybrid state machine** (`Inference.lua`, the reusable library `Lib/HybridState.lua`). Pure logic over
    values the API reports as non-secret plus event timing; no CLEU, no pixels, no parsing of secret text. Rules:
    cast-pair, observed, single-applier, cast-correlation (incl. retro correlation within the window), iid-map, count-delta,
    predicted-expiry. Each inference carries a rule and a confidence. Predictions cover aura + duration, damage/heal range
    and cooldown end for the player's casts, with live verification and contradictions. Rule-input readability is logged
    per context.
  - **HSM window** (`HSMUI.lua`, `/fdump hsm`). Movable, resizable and scrollable; Escape closes it; position saved; plain
    frames only (no secure templates, no Blizzard hooks). Shows restriction states, cast state (yellow predicted bar vs the
    engine bar through `SetTimerDuration`), per-unit auras (source, stacks, remaining, confidence), cooldown prediction vs
    `SetCooldownFromDurationObject`, the last predictions with outcomes, and counters. Secrets are shown only through engine
    passthrough widgets labelled "secret (engine-displayed)". Green observed, yellow inferred, grey unknown, red
    contradiction. Throttled to 0.2 s. FD_Logs ON opens it (`hsm.autoShow`) and OFF closes it. There is also an [HSM] button
    on the secrets panel.
  - **Baseline signature** (`Baseline.lua`, `/fdump baseline`). Docs hash (FNV-1a, identical in Lua and Python), secrecy per
    API position and context, ops, restriction timing, lab, combat, tokens, knowledge and frame types. Stored per build
    (keeps 6). After a build change a one-line **drift alert** prints in chat.
- Macro audit: every generated macro body and every `/run` snippet in the docs is ≤255 characters (`tests/regress.lua macro`,
  `tests/test_v22.py`).

**Converter**
- New: `restrictions`, `clientlog`, `size`, `ops` (OPS.md), `lab` (LAB.md + "Porting patterns for secret values"), `combat`
  (COMBAT-SECRETS.md + combat.json for the guide), `tokens` (UNIT-TOKENS.md), `knowledge` (KNOWLEDGE.md), `inference`
  (INFERENCE.md + HSM.md + hsm.json; scores the addon's inferences/predictions against the file combat log and replays the log
  through `Lib/HybridState.lua` offline in clear / secret / secret-pretrained modes), `drift OLD NEW` (DRIFT.md), `baseline`
  (fixtures/baselines/<build>/baseline.json; run 2 is the first), `guide` (regenerates SECRETS-GUIDE.html).
- `verify` uses the inventory TSV as ground truth (v2.2 classifier rules). `all` also writes ops/lab/combat/tokens/knowledge and runs
  **drift automatically** against the newest stored baseline.
- `xref --player` accepts a character name. `inference` defaults to the log owner (unit flags 0x511).
- **SECRETS-GUIDE.html** (generator in `tools/guide/`) is built from the converted SV and shipped at the zip root.
- Tests: `tests/regress.lua` (bug B before/after, restrictions, classifier, forced sweep, macros), `tests/hsm.lua` (51 checks:
  library, combat probe, tokens, knowledge, inference, HSM window, baseline, no secrets in SV, zero accidental secret touches),
  and `tests/test_v22.py` (guide JSON schemas, reports, drift, Barrens replay, guide build, Lua/Python hash parity, /run audit).

## v2.1.0 (2026-10-07, after the first real Forever 70245 run)
**Addon**
- **FD_Logs = capture everything.** One click starts all client logs plus the event recorder, combat recorder, error
  capture, secrets verifier and getter sweep, and probe and profiler snapshots. It queues `/fdump all` if the build has no
  full dump yet, and takes an automatic in-combat probe at the first combat. The second click stops everything, copies
  BugGrabber errors and runs `/reload` (synchronous OFF, so SavedVariables are written). `/stopmacro [combat]` guard.
  Capture resumes after `/reload`/relog. Running sessions are saved at logout.
- **Compact SavedVariables by default** (about half the size); `/fdump all full` or `set dump.full true` for the v2.0
  full dump. UTF-8-safe truncation (the v2.0 SV contained cut multi-byte characters).
- **Secrets verifier** (`Secrets.lua`, section `secrets`). Live `issecretvalue`/`canaccessvalue` tallies per event, API
  and struct field position, with context buckets (ooc/combat/encounter, instance type, self/other). Throttled sweep of
  documented conditionally secret getters. Live contradictions against the documentation. `/fdump secrets` live
  panel, `state` and `sweep` subcommands. Bounded counters only (`secrets.maxKeys/maxCtx/maxLive`).
- **Common timebase.** Session IDs and anchors (GetTime, time(), GetServerTime, UTC offset; refined at a time() tick) on
  capture, recorder and combat sessions. `sid/t/epoch/server` on probes, errors, blocked actions and contradictions.
  Everything persists to SavedVariables.
- **BugGrabber/BugSack coexistence.** Uses BugGrabber callbacks (`BugGrabber_BugGrabbed`) when it is loaded, polls `GetDB()`
  as a fallback, and chains the previous handler otherwise. `/fdump errors bg` and FD_Logs OFF copy BugGrabber session
  errors. `## OptionalDeps: !BugGrabber, BugSack`.
- Error attribution to the addon that raised it; CLEU is still never registered by default.

**Converter**
- `secrets` (secrets map: every documented flag; SECRETS.md), `verify` (CONFIRMED / CONTRADICTED / UNOBSERVED /
  UNDOCUMENTED-SECRET, coverage), `xref` (merged timeline with match quality), `migrate` + `migrate-db` (legacy addon
  migration report; 109 curated + 373 Blizzard_Deprecated shim mappings), `fixtures` (anonymized fixture pack).
- `check` gained the `secret-op` rule (arithmetic, comparison, length or boolean tests on documented/observed secret values,
  with guard detection). LuaLS stubs carry secrecy annotations marked `[verified]`/`[unverified]`/`[CONTRADICTED]`.
  Mocks return secret sentinels per documented/verified secrecy (`wow.secretMode`, per-field struct secrets, secret
  event payloads).
- Fixes from the real run: invalid UTF-8 in SV broke JSON export; combat log v22 ENVIRONMENTAL_* advanced-block order,
  ST/AOE scope marker, isOffHand padding; Ketho comparison scoping; `cl-compare` Forever mode.
- Tests: BugGrabber paths (`tests/buggrabber.lua`), verifier with deliberate contradictions (smoke), `tests/test_xref.py`
  (synthetic file log), `tests/test_migrate.py` (deliberate legacy addon), `tests/spec/forever_fixture_spec.lua`
  (anonymized real capture).

## v2.0.0

New in v2 compared to v1:
- **Structure:** 19 Lua files; `.toc` Interface 16001, Version 2.0.0; 6 SavedVariables (DB, DocsDB, StringsDB,
  RecordDB, LogDB, CombatLogDB) so large data stays separate; `schemaVersion` plus a meta header (build, locale,
  `WOW_PROJECT_ID` and **every** `WOW_PROJECT_*` constant, with Forever = 18 / CAMELOT, never assumed mainline;
  `C_AddOns.GetScriptsDisallowedForBeta()`).
- **Sections** (`/fdump all` or one at a time): full APIDocumentation walk with documented/present cross-check;
  C_ namespaces; global tables, functions (secure/insecure), constants and Enum; all global strings; widget API
  (methods per type, inheritance; `risky` option); XML templates; named frames; addons; CVars and console commands;
  protected info (issecurevariable plus doc restriction and secret flags); extras (bindings, slash commands, settings,
  fonts, SOUNDKIT, maps, classes, spells, talents, currencies); opt-in getters; profiling snapshot.
- **Recorders:** event recorder registers documented events individually (no RegisterAllEvents) and saves the
  skipped restricted/SecureOnly events with reasons. The Forever-safe combat recorder (`/fdump cl`) records
  UNIT_COMBAT, UNIT_SPELLCAST_*, PLAYER_SWING with swing range, COMBAT_TEXT_UPDATE with the C_CombatText getter,
  encounter and regen context with restriction states, and post-combat C_DamageMeter snapshots. Legacy CLEU is
  opt-in only (`cl cleu-force`, guarded). Probe (tooltips and getters, now or next combat).
- **Diagnostics:** chained Lua error handler (stack and locals); ADDON_ACTION_BLOCKED/FORBIDDEN, MACRO_ACTION_*,
  LUA_WARNING and ADDON_RESTRICTION_STATE_CHANGED log.
- **FD_Logs:** `/fdump logs` and the single account macro FD_Logs toggle the combat log, chat log,
  advancedCombatLogging, scriptErrors and taintLog together, with state in SavedVariables and a clear chat line.
- **Safety and UX:** refuses heavy work in combat; frame-sliced chunking with `/fdump cancel`; secret-value detection
  everywhere (`<secret>`); per-section toggles, clear and set; capped copy window; status view; /reload reminder.
- **Box-side converter** (`tools/`): SV to JSON, LuaLS stubs, luacheck std, busted mocks and replay, API checker,
  diff, combat log file parser, taint.log parser, error report, Ketho comparison.
