# Run 4 findings: ForeverDump v2.2.2 in game (shaman, Forever 1.60.1.70245, 2026-10-07 22:58-23:00 EDT)

Inputs:
- `sv/ForeverDump.lua` (addonVersion 2.2.2)
- `WoWCombatLog.txt` (run 4 covers 22:58:43-22:59:56 EDT)
- `taint.log` (75 entries)
- `hsm-screenshot.png`

Capture `cap-20261007225843-1` lasted 87 s and had two combats. It recorded 604 combat-log events, 1,831 recorder events and
254 unit events.

## 1. The frame-rate drop ("as I cast more abilities the framerate drops")

**Root cause:** `ns.Meta()` → `ns.ProjectInfo()` ran `pairs(_G)` over every global on each call. The run-4 SV lists 52,517
globals, and one walk takes about 17 ms in Lua 5.1 on the box (`/tmp/pi.lua` micro-bench: 16.9 ms per call). It was not
an exponential delay or polling; it was a 17 ms global walk sitting in per-event and per-redraw paths, and the number of
times it ran per second grew with the number of casts:

| caller | how often in v2.2.2 |
|---|---|
| HSM window text: every spell name → `Knowledge.DB()` → `K.Build()` → `ns.Meta()` | once per text line (up to 8 predictions plus cooldown, aura and contradiction lines, plus the cd label) at 5 Hz. More casts meant more lines and more walks per second. |
| Containers `db()` | every UNIT_AURA |
| `ns.PathBlocked` | every combat-probe read in lockdown |
| `Knowledge.Learn`, `Errors` | per learned spell / per error |

Smaller O(n) costs added to it:
- `table.remove(list, 1)` on every push once the list was full
- `Appliers` rebuilt and sorted on every aura event
- HSM text re-walking all inference inputs
- 6 pcalls of context per probe call
- failing `GetAuraSlots` pcalls on every combat UNIT_AURA
- unbounded per-GUID unit state and unknown-duration auras

**In-game evidence** (profile snapshots at capture:on 22:58:43 vs capture:off 23:00:09 EDT; see `perf/PERF.md`):

- Application `RecentAverageTime` rose **20.7 → 59.3 ms per frame (×2.9)**, from about 48 fps to about 17 fps. The client
  recorded 2,464 frames in 86 s (about 35 ms on average).
- ForeverDump memory grew **46.2 → 70.6 MB (+23.8 MB)** in 86 s. The garbage came from the walk and from string rebuilding.
  No other addon changed: Questie stayed at 18.3 MB with flat timings.
- ForeverDump's own C_AddOnProfiler counters moved only +12 frames over 1 ms, +12 over 10 ms and +1 over 50 ms, with a
  session average of 0.032 → 0.034 ms. On this client the per-addon counters clearly undercount OnUpdate and timer time: the
  pre-capture `/fdump all` job ran about 3 s at a 12 ms budget but registered only 28 frames over 10 ms. The application frame
  time is the signal to trust, and v2.2.3 now measures itself (section 3).

**Benchmark (tests/perf_bench.lua, mock client, real-delay timers, OnUpdate only for shown frames, 60 fps):**

v2.2.2, timeboxed (`--marks 1,2,4,8,16 --win 1 --cap 75`, then `--cap 90` for 25/50/100):

| casts | ms/event | ms/frame | frame impact |
|---|---|---|---|
| 1 | 3.13 | 1.50 | 11.1% |
| 2 | 3.31 | 2.55 | 17.5% |
| 4 | 3.64 | 5.15 | 33.3% |
| 8 | 3.32 | 9.52 | 59.3% |
| 16 | 2.74 | 9.27 | 57.4% |
| 25 | 3.35 | 10.23 | 63.6% |
| 50 | 3.01 | 9.13 | 56.8% |
| 100 | 3.15 | 9.62 | 59.8% |

- The per-frame cost grows linearly with casts until the "last 8 predictions" list is full: 1.5 → 9.5 ms over 8 casts. That is
  the in-game symptom.
- The run hit the 90 s cap after 170 casts. The HSM frame's OnUpdate never went idle.

v2.2.3 (`--assert`, about 2 s wall time):

| casts | ms/event | ms/frame | frame impact |
|---|---|---|---|
| 1 | 0.054 | 0.0062 | 0.073% |
| 8 | 0.032 | 0.0040 | 0.046% |
| 25 | 0.043 | 0.0050 | 0.059% |
| 50 | 0.032 | 0.0043 | 0.047% |
| 100 | 0.026 | 0.0036 | 0.039% |
| aged (2,110 casts) | 0.047 | 0.0087 | 0.083% |

- After 700 s idle: **0 OnUpdates**.
- Per-handler costs are flat (`--keys`).
- The frame impact dropped from about 60% to about 0.05%: roughly ×77 less per event and ×1,000-2,700 less per frame.

**Fixes (v2.2.3):**
- The project info is cached for the session (`ns.ScanProjectInfo` runs once), and the hot paths use the cached `ns.Build()`.
- Amortised O(1) bounded push; Appliers cached per knowledge version; counters instead of re-walks; context cached per frame.
- `counts()` is skipped after an all-error result; Containers `ObserveEvent` exits in O(1); stale units and auras are dropped.
- The HSM window is driven by its own unit events, registered only while shown. A dirty flag drives a 10 Hz OnUpdate that is
  installed on demand and removed when idle. Text is rebuilt only when `hs.version` changes (every 0.25 s at most), and
  countdowns tick at 1 Hz.
- Rules are now permanent in `PERFORMANCE.md`. The default runner enforces them with `perf_bench --assert` (2-minute cap) and
  `fdump.py perfcheck --strict`.

## 2. HSM window layout (screenshot)

- **Overlap:** the free-floating "player HP, secret (engine-displayed): 1059" line (y -132) collided with the "real cooldown
  (secret, engine-displayed)" label (y -128). v2.2.3 uses eight fixed 14 px rows, each with a label column, a bar and a
  right-aligned value. The real cooldown has its own row with the icon swipe, and the text body starts below row 8. tests/hsm.lua
  checks that rows are at least 14 px apart and the body is below them.
- **Empty cast bars:** nothing was casting, and with no knowledge there was no predicted cast time. Idle bars now say "idle",
  "not casting", "no unit" or "none".

## 3. Why Lightning Shield, Flame Shock (on a creature) and Ghost Wolf stayed "unverified"

All 16 run-4 predictions had `known=false`: `Inference.knowledgeSpells` was 0 and the appliers list was empty. Knowledge for
70245 *was* collected in this session (76 spells), but the knowledge pass runs asynchronously after `Inference.Start`, and
`NewHSM` copied knowledge only once, at start. The HSM therefore never learned aura durations, cooldowns or targets.

| spell | what happened | what v2.2.3 does |
|---|---|---|
| Lightning Shield (905, helpful, 10 min aura) | Attributed to the hostile target (no "helpful" knowledge). In combat the UNIT_AURA `addedAuras` payload was wholly secret, so the spellId could not be matched. | Knowledge reaches the HSM live (`Knowledge.onCollected` plus a lazy lookup on the first cast), so it is attributed to the player. Timing verification: the player's secret `addedAuras` arrived 4 ms after the cast (27.546 → 27.550 s). |
| Flame Shock (8052, creature) | The payload on the target was secret in combat. | Timing verification: the target's aura event came 4 ms after the cast (13.496 → 13.500 s). |
| Ghost Wolf (until cancelled) | No parsed aura duration; `verify` required `p.aura`. | An observed aura with a clear spellId verifies a prediction without aura knowledge, and until-cancelled auras are learned. |

The same missing knowledge explains why 12 of the 16 predictions were attributed to the hostile creature, even though they
are self, helpful or summon spells: Lightning Shield, the totems 8160/8155/8177/6364, Blood Fury 20572, the cures 526/2870,
and others. The v2.2.2 attribution rule needs `helpful`/`summon` knowledge. With the live knowledge feed they go to the
player.

Timing verification (`HybridState:verifyTiming`) uses only the fact that the payload is secret rather than nil, plus event
timing. It sets outcome "aura event seen (secret payload, timing)", rule `secret-timing`, confidence medium. No secret value
is read.

## 4. Standard analysis

- **Identity:** all 14 fields have code C (`anySecret=false`); Orc Shaman, level 30. UnitName returns (first, last).
- **Taint (75 entries):**
  - **0 ADDON_ACTION_BLOCKED, 0 probe-blocked, 0 unexpected.**
  - 58 expected (operations matrix / lab boundary probes on secrets inside pcall): compare 24, arithmetic 20, index 10,
    string 2, length 2, from Controls.lua:154-227 via CombatProbe TryTimeLeft and the ops matrix.
  - 7 contained:
    - Lab AddPoint ×2
    - Core.lua:485 utcOffset ×1
    - SecureTypes.lua:279 "reading field value" ×4. This is Blizzard mixin code (CircularBuffer.PushFront) running on **our
      own hidden ScrollingMessageFrame**, called from Controls.lua:195 opsFor. It is not ChatFrame1. v2.2.3 classifies it as
      contained.
  - 10 benign-chat: `ChatFrame1:UpdateFading` reading `oldestFadingLineTimestamp`. Our chat lines (ns.Print from the slash
    command path) were added from tainted execution, and the fading code later reads that timestamp. No secret is involved and
    no action is blocked; any addon that prints to chat produces this. This is the new class `benign-chat`. **0 Blizzard-frame
    entries remain.**
- **Errors:** 0 Lua errors. The 4 "blocked/forbidden/warning" records are ADDON_RESTRICTION_STATE_CHANGED flips, not blocked
  actions.
- **Restrictions:** 4 Combat flips (Activating ×2, Inactive ×2); the active intervals were 29.0 s and 63.2 s.
  InCombatLockdown was still false at Activating, as in run 3. At the flip, `GetAuraDataByIndex` goes from nil to an error, and
  `ShouldAurasBeSecret` / `ShouldCooldownsBeSecret` go from false to true.
- **Verify:**
  - 353 confirmed, 4 contradicted, 1 undocumented-secret, 65 inconclusive.
  - The 4 contradictions are the unit argument (#1) of UNIT_AURA and UNIT_SPELLCAST_START/STOP/SUCCEEDED. It stays clear while
    `ShouldAurasBeSecret` / `ShouldUnitSpellCastBeSecret` are true, because the conditional tag applies to the payload, not to
    the unit token.
  - Undocumented secret: `C_Spell.GetSpellCooldownDuration` #1 is secret in combat (8/24) with no doc tag.
- **Drift vs the run-2 baseline:**
  - 11 newly secret: combat-context positions observed for the first time, namely GetSpellCooldown(+Duration),
    UnitCastingInfo/Duration, UNIT_AURA #2 and UNIT_SPELLCAST_* #2/#3.
  - 11 newly clear: mixed → clear with more samples.
  - 12 "removed" APIs: load-on-demand Blizzard UI Lua functions (MacroFrame_*, PlayerChoice_*) that were not loaded at capture
    time. This is not a client change.
  - 2 new restriction flip kinds.
- **Containers:** first addon-sourced schema (2 contexts, 3 unit classes, 6 partial-secret containers).
  - In combat `GetAuraDataByIndex` errors (E) for player, target and self-via-other-token.
  - In combat the UNIT_AURA payload is T: `addedAuras`, `removedAuraInstanceIDs`, `updatedAuraInstanceIDs` **and
    `isFullUpdate`** are secret.
  - Out of combat every aura field is clear.
  - The diff vs the stored baseline (1 change, 256 new, 1,993 gone) compares the run-3 legacy-reconstructed schema with
    run 4's addon schema, so the large numbers are a schema-source change, not a client change. Storing run 4 as the new
    baseline (`fdump containers --write-baseline fixtures/baselines`) would make future diffs meaningful. It was not written.
- **Combat secrets / detectability:** 75 items, 2 contexts.
  - Your own casts are fully readable in combat (`playerCast.spellID` / `castGUID` 13/13).
  - For target and nameplate casts: whether something is being cast: yes; which spell: no (spellID/name/texture/notInterruptible
    are S). Unit-cast castGUID is secret (46/46).
  - Totems in combat: only the slot is clear; duration, name and start are secret (6/6).
- **HSM scoring (file log, player auto-picked from the SV identity):**
  - Live: 16 predictions, all unverified (see section 3).
  - Offline replay with the v2.2.3 library, secret-pretrained (knowledge up front, as v2.2.3 now supplies live): aura 14/14
    (100%), summons 13/13, cooldown 9/9 judged (17 with no recast in the window), amount 8/11 (crit ×3).
  - Secret mode without pretraining: aura 10/10; cooldown 0/3 judged (recast before the predicted end).
- **Combat probe:** 5 runs (3 in combat). The only skip was CheckInteractDistance (non-hostile rule). Containers ran 2 times.
  Inference counters: 68 casts, 17 aura events, 48 unreadable, 0 contradictions.

## 5. Outputs in this folder

`all.log`, `perf/PERF.md`, `taint/taint.{txt,json}`, `errors.{txt,json}`, `verify/`, `drift/` (from `all`), `containers/`,
`combat/`, `restrictions/`, `inference/` (INFERENCE.md, HSM.md), `guide/SECRETS-GUIDE.html`, `info.txt`.
