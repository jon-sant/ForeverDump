# ForeverDump v2.2.14: addon usage

ForeverDump records what the WoW Forever client (1.60.x, Interface 16001, game type `camelot`) actually
exposes to addons, and saves it to SavedVariables so the box-side converter (`tools/fdump.py`) can turn it into
JSON, LuaLS stubs, a luacheck std, busted mocks and replay fixtures.

> v2.1 ran in-game on Forever 70245 (two runs on 2026-10-07). The v2.2 additions (probes, HSM) are tested in the mock
> client built from the real Forever API documentation; they have not run in-game yet.

## Install
Each release is one zip, `ForeverDump-v<version>.zip`. It holds the addon folder `ForeverDump/` plus the converter,
tests, docs and fixtures (only the `ForeverDump` folder goes into the game).
1. Quit the game (or at least log out to the character screen; the client only reads addon files at start-up).
2. **Delete** the old `World of Warcraft\_classic_beta_\Interface\AddOns\ForeverDump` folder.
   (`_classic_beta_` is the Forever client; `_retail_` and `_classic_` are different clients.)
3. Open the zip and copy its `ForeverDump` folder (the one that contains `ForeverDump.toc`) into
   `World of Warcraft\_classic_beta_\Interface\AddOns\`. You must end up with `...\AddOns\ForeverDump\ForeverDump.toc`
   (not `...\AddOns\ForeverDump-v<version>\ForeverDump\...` and not `...\AddOns\ForeverDump\ForeverDump\...`).
4. Start the game; on the character screen enable **ForeverDump** in the AddOns list (tick "Load out of date AddOns"
   if it says "out of date").
5. **Check the version in game.** Every ForeverDump line starts with `ForeverDump <version>`; `/fdump version` and the
   first line of `/fdump status` print it; the HSM window title and the FD_Logs ON/OFF lines show it too. After an
   update, the first login also shows "version changed: SavedVariables were last written by X, now running Y". If
   you still see the old version, the game is loading another copy: repeat steps 1 to 3.

Output: since v2.2.14 ForeverDump never writes into the chat window (any addon line there breaks Blizzard's
battleground chat filter for the rest of the session). Its lines appear in its own message area near the top of the
screen and fade after 20 s; `/fdump msgs [n]` shows the last n again.

## Run order (out of combat; the addon refuses heavy dumps in combat)
| Step | Command | What it does |
|---|---|---|
| 1 | `/fdump status` | Prints the build, `WOW_PROJECT_ID` (Forever = 18, `WOW_PROJECT_CAMELOT`), every `WOW_PROJECT_*` constant, `C_AddOns.GetScriptsDisallowedForBeta()`, and what has been collected so far |
| 2 | `/fdump static run` | **v2.2.11: the ONLY way static client data is collected** (docs, api, globals, strings, widgets, templates, frames, addons, cvars, protected, extras), into its own SavedVariable `ForeverDumpStaticDB`. Nothing runs it automatically: not login, not a new client build, not `/fdump all`, not FD_Logs. `force` is an alias. It **stays in the saved file until `/fdump static clear`** |
| 3 | `/fdump getters` *(optional)* | Calls the documented zero-argument `Get*`/`Is*` functions that have no restriction flags, and records their returns and secrecy |
| 4 | `/fdump widgets risky` *(optional)* | Also creates the rarer widget types (Browser and similar) |
| 5 | `/fdump probe`, `/fdump probe combat` *(optional)* | Samples tooltips and getters now, or arms a sample for the next combat (secret detection) |
| 6 | `/fdump record start` … `/fdump record stop` | Event recorder: registers each documented event **individually** and skips restricted or SecureOnly events plus a denylist. The skipped events and reasons are saved |
| 7 | `/fdump cl start` … fight … `/fdump cl stop` | Combat recorder (UNIT_COMBAT, UNIT_SPELLCAST_*, PLAYER_SWING, COMBAT_TEXT_UPDATE + `C_CombatText.GetCurrentEventInfo`, ENCOUNTER_*, PLAYER_REGEN_*). It takes a `C_DamageMeter` snapshot after each combat |
| 8 | `/fdump logs macro`, then click **FD_Logs** | **The easy path: steps 2 to 7 and 9 in one click** (see below). Click again to stop, save and `/reload` |
| 9 | `/fdump errors show`, `/fdump errors bg`, `/fdump profile` | Shows the captured Lua errors and ADDON_ACTION_BLOCKED/FORBIDDEN events; copies BugGrabber's session errors; takes a per-addon CPU/memory snapshot |
| 10 | `/reload` (or log out) | **Required** when you did NOT stop with the FD_Logs click (the OFF click already reloads). The client only writes SavedVariables on reload, logout or exit |

### Static dump (v2.2.11: only on request)
- **Only `/fdump static run`** (or its alias `force`) collects the static client data. There is no automatic run any more:
  not at login, not for a new client build, not from `/fdump all`, not from FD_Logs.
- The data goes to **`ForeverDumpStaticDB`**. `ForeverDumpDB` keeps a ~1 KB marker (`static = {key, build, apiHash, done, ...}`).
- **It persists:** WoW rewrites SavedVariables on every /reload and logout, and the static tables stay in
  `ForeverDump.lua` (with every capture) until you type **`/fdump static clear`** (the marker stays). FD_Logs ON never clears it.
- `/fdump static status` shows what is held and repeats that rule. `/fdump static check` compares the held data with this
  client's signature (`GetBuildInfo` + a hash of the `C_*` namespaces/function counts + the Enum count) and only
  reports: `done`, `cleared`, `stale (... /fdump static run to collect)` or `none`.
- Size: a typical capture was 14–15 MB with the static data. After `/fdump static clear` it is **2.7–3.8 MB**.
- Offline tools read `ForeverDumpStaticDB`. When it is missing, they fall back to the repo's reference (`fixtures/forever-70245`).

Other commands: `/fdump show <status|apis|events|enums|cvars|all|errors|section>` opens a copy window (capped size).
`/fdump clear <section|docs|strings|static|record|cl|errors|probe|all>` deletes collected data, and `/fdump set <key> <value>` changes
an option (for example `set logs.chat false` or `set cl.maxEvents 50000`). Plain `/fdump` still does the v1 quick dump.

### v2.2.6 verbosity (one build)

Default is **release** (cheap tape: cast-sync anchors every N own SUCCEEDED, decide/verdict, no sec/api/map extras; gate **<2%** CPU; the user raised it from 1% on 2026-10-08).
Click **FD_Logs** and the addon elevates to **lab** (v2.2.15 default = diag + shadow rules + lab probes; perf is reported, not gated, with a 250 ms runaway backstop; `/fdump level capturelevel diag` or `test` for the lighter levels): denser tape, sec nibbles, API samples, map deltas; diag gate **≤10%** (lab: reported only). Stopping the capture restores the previous level (usually release).
v2.2.10: diag keeps **everything** a full 20–30 min 40-man battleground produces (no data caps). Its limits are safety
ceilings at about 10x a 30 min BG (tape 2,000,000 rows, combat 1,000,000, recorder 2,000,000 with at most 1000 events/s
per event type, signals/verify 250,000). If one is ever reached, an orange `ceiling reached` line prints once per ring and
the capture header records `ceilingHit`. Repeated identical `DAMAGE_METER_*` updates are stored as one run row
(count + exact ms deltas), and the converter restores every update on load. Expect a large SavedVariables file at diag
(about 80 MB for a 30 min BG; saving it at the OFF reload takes a few seconds). release and test keep their small sizes.
Manual override between captures: `/fdump level status|release|test|diag|lab`. Status also appears on the HSM title (`log:test (capture)`).

### The FD_Logs macro (one click captures everything)
`/fdump logs macro` creates one account macro, **FD_Logs**. Drag it from `/macro` (General tab) to an action bar.

- **Click 1 = ON. v2.2.11: every capture starts clean.** ON first wipes ALL previous capture data: the replay tape and
  its sessions, HSM inference/signals/history, the event recorder and combat recorder sessions, damage meter evidence,
  world capture, perf, restrictions, controls/lab/probes, tokens, containers, identity, errors/blocked log, counters, the
  verify rings, secrets observations, token scan, raw identities and the probe/profile sections. It **keeps** the
  learned store (learned spells/NPCs, knowledge, timing, drift history, per-build baselines), your settings and macro,
  and `ForeverDumpStaticDB`. One chat line says what was wiped. OFF never wipes, and a capture that resumes after a
  `/reload` is not wiped. Copy `ForeverDump.lua` off before the next ON if you still need the previous capture.
  Then ON turns on the client logs (combat log file, advancedCombatLogging, scriptErrors, taintLog, chat log),
  and starts the event recorder, the combat recorder, error capture, the secrets verifier and its getter sweep. It also
  takes a probe and profiler snapshot. ON never runs the static dump (v2.2.11: only `/fdump static run` does). The first combat of each
  recording session gets an automatic in-combat probe. **v2.2:** it also starts the restrictions tracker, the workarounds lab,
  the combat probe set, the unit token survey, spell knowledge and the inference engine, and opens the **HSM window**.
- **Click 2 = OFF.** Stops everything, takes the closing probe and profiler snapshot, copies BugGrabber's session errors
  (if BugGrabber is installed), stops the probe modules, records the baseline signature, closes the HSM window, and saves the
  sessions. Then the macro's last line `/reload` writes SavedVariables to disk.
- **Ending a capture (v2.2.9, do it in this order):**
  1. Type `/fdump errors show` and **take a screenshot BEFORE you click OFF.** The window is the only place where the error
     list appears next to what you just saw on screen.
  2. **Click FD_Logs (OFF).** The OFF click's last macro line is `/reload`, and that reload writes SavedVariables. **Don't
     type a separate `/reload`.** (Exceptions: with `logs.autoReload false`, or after typing `/fdump logs off` instead of
     clicking, you do need to `/reload` yourself. In combat the click does nothing, so click again after combat.)
  3. Send `WTF\...\SavedVariables\ForeverDump.lua` (zip it if it is large; **copy it off before the next FD_Logs ON**, which
     wipes the previous capture), the `Logs` folder files
     (`WoWCombatLog*.txt`, `taint.log`, `WoWChatLog.txt`) and the screenshot.
- **It survives `/reload` and relog.** If the UI reloads while capture is ON, recording resumes after login, and a chat line
  confirms it. Each resume adds a new segment with its own time anchor.
- **In combat** the macro stops at `/stopmacro [combat]`, so nothing changes. Click again after combat.
- The macro body is `/fdump logs`, `/stopmacro [combat]`, the `/combatlog` and/or `/chatlog` toggles the next state needs,
  and `/reload` (on the OFF click only). It is under 255 characters. The addon rewrites it after each click, out of combat,
  checking against `C_ChatInfo.IsLoggingCombat()`/`IsLoggingChat()`. **v2.2.9:** typing `/combatlog` or `/chatlog` by hand also
  refreshes the macro. If a click would still flip a log the wrong way (it was already in the target state), the
  click prints a red line telling you to type `/combatlog` once (run 8 lost its BG combat log this way). It does **not** call `LoggingCombat`/`LoggingChat`
  (they may be protected on Forever). Blizzard's own slash handlers do the toggling when **you** click.
- OFF restores advancedCombatLogging and scriptErrors to their values before ON, and sets taintLog to 0.
- No `/run` or `/script`, so it works even when `GetScriptsDisallowedForBeta()` is true. These docs don't rely on `/run`.
- Macros can't be created or edited in combat; the addon waits until after combat. If all 120 General macro slots
  are full, it says so.
- Options: `/fdump set logs.autoReload false` (the OFF click doesn't reload; type `/reload` yourself), `logs.chat false`
  (no chat log), `logs.sweep false`, `logs.fullDump false`, and so on. See `/fdump set` and Core.lua `ns.defaults`.

**What one FD_Logs click does NOT capture:** the legacy combat log event stream inside the addon (COMBAT_LOG_EVENT is
restricted on Forever, so the unrestricted source is the `Logs\WoWCombatLog-*.txt` file). It also misses events the
recorder skips (restricted/SecureOnly or denylisted, listed with reasons in the dump), raw values of secret payloads
(only their secrecy is counted), and anything that happens after the OFF click. SavedVariables are written only on
`/reload`, logout or exit, so a client crash loses the unsaved part.

### Secrets verifier (`/fdump secrets`)
While capture is ON, every event the recorders see is checked live with `issecretvalue` (and `canaccessvalue` if present)
per argument position. The getter sweep calls documented, conditionally secret, unrestricted getters with harmless
arguments (`player`, `target`) every 5 s, 25 calls per tick. Results go into **bounded counters only** (never raw values):
secret/clear counts per API, event or struct field position, split by context: out of combat / in combat / in an encounter,
instance type, and unit self / other. When an observation disagrees with the documentation (documented secret but seen
clear, or the reverse), it is logged as a live contradiction.

| Command | What it does |
|---|---|
| `/fdump secrets` | Opens or closes a small live panel (recent events with secret vs clear counts, contradictions) and stores a state snapshot |
| `/fdump secrets state` | Prints the secret-related state (C_Secrets, restriction states, combat-log restriction, related CVars) |
| `/fdump secrets sweep on\|off\|now\|status` | Controls the getter sweep outside FD_Logs |

Limits: `/fdump set secrets.maxKeys 4000`, `secrets.maxCtx 16`, `secrets.maxLive 200`, `secrets.sweepInterval 5`,
`secrets.sweepPerTick 25`. On the box, `python3 tools/fdump.py verify ForeverDump.lua` turns this into VERIFY.md.

### What persists, and the common timebase
Everything is written to SavedVariables: verifier tallies and the contradiction log, sweep results, the event recorder
log, combat recorder sessions, errors (plus copied BugGrabber errors), blocked actions and probes. Each capture
session gets a session ID and a time anchor: `GetTime()`, `time()`, `GetServerTime()` and the UTC offset, captured once at
session start and refined when `time()` ticks over. Every record carries `sid`, `t` (GetTime), `epoch` and `server`.
`tools/fdump.py xref` uses this to line up the addon logs with the `WoWCombatLog` file (local wall time + UTC offset).

### v2.2 probes inside every FD_Logs capture
All of these run from clean event/timer callbacks of ForeverDump's own frames (no hooks into Blizzard functions, no CLEU).
They store codes, booleans, counts and error texts only, never a secret value or anything derived from one.

| Module | Command (outside FD_Logs) | When it runs during a capture | Saved in |
|---|---|---|---|
| Restrictions tracker | `/fdump restrictions [probe]` | every `ADDON_RESTRICTION_STATE_CHANGED` flip (+ next frame) | `ForeverDumpLogDB.restrictions` |
| Controls / ops matrix | `/fdump secrets controls` | ON, combat, OFF | `ForeverDumpLogDB.controls` (v2.2.11: ops run only on clear values; a secret operand is recorded as S + skipped, never operated on) |
| Workarounds lab | `/fdump lab` | ON + combat | `ForeverDumpLogDB.lab` |
| Lab probes (v2.2.15) | capture level lab | FD_Logs capture | `ForeverDumpLogDB.labProbes` |
| Aura probes (v2.2.26) | capture level lab | FD_Logs capture | `ForeverDumpLogDB.auraPresence` (tape U/D states, detail, totems, derived, restrict, hctx); v2.2.27: candidates dynamic only - `ForeverDumpDB.auraLearned[build]`, `auraPairs[build]`, `spellCache[build][class]` (rebuilt by `/fdump static run`); `auraPresence.list` / `limitHit` / `warnings`; v2.2.28: + `refLearned`/`knowledge` stores, automatic spellCache at login, cross-build carry-over (`prev-build`), optional generated library `Data/LearnedAuras.lua` (schema 2, `python3 tools/fdump.py learned-auras`; sources `offline`/`offline-prov`), `emptyAtStart`; v2.2.29: time-sliced (OnUpdate, 5 % of frame time), nothing dropped, tiers H/W/C, `sched` (+ `sched.worst` staleness), `ForeverDumpDB.spellLevel[build]` |
| Combat probe set | `/fdump combat` | ON, combat start (+1 s), restriction flips, target/focus change, encounter start; ≥3 s apart, ≤80 runs | `ForeverDumpLogDB.combatProbe` |
| Unit token survey | `/fdump tokens` | once per context (out of combat, in combat, restricted) | `ForeverDumpLogDB.tokens` |
| Spell knowledge | `/fdump knowledge` | ON (out of combat) and 2 s into the first combat, 8 spells per tick | `ForeverDumpDB.knowledge[build]` |
| Inference + HSM | `/fdump hsm start\|stop` | the whole capture (UNIT_SPELLCAST_*, UNIT_AURA, counts, restriction state) | `ForeverDumpLogDB.inference` |
| Baseline signature | `/fdump baseline` | OFF | `ForeverDumpLogDB.baseline`, `ForeverDumpDB.baselines` |

Options: `/fdump set combatProbe.enabled false`, `combatProbe.maxRunsPerCapture 80`, `tokens.enabled false`,
`knowledge.maxSpells 150`, `hsm.enabled false`, `hsm.autoShow false`, `hsm.updateInterval 0.25`, `perf.enabled false`
(self-perf monitor), `perf.sampleInterval 5`.

**Detectability answers** (combat probe). For player, target, focus, party and nameplates, in each context, the probe answers
yes / partial / no with evidence: *casting or channelling? which spell? any buff/debuff? MY buff/debuff? what is it?
stacks/duration (secret, or available as a duration object)? dispellable?*

**Drift alert.** After a client patch, the first capture on the new build prints one chat line such as
`drift: build 70245 -> 70301, 3 API position(s) newly secret; run fdump.py drift ...`. Details come from
`tools/fdump.py drift` on the box.

### The HSM window (`/fdump hsm`)
The hybrid state machine predicts what the secret values probably are from what is readable (your own casts, aura instance
IDs, counts, event timing, spell knowledge cached out of combat), and shows its predictions next to the engine's own display
of the real values.

- `/fdump hsm` toggles the window. `/fdump hsm show|hide`, `start|stop` (run the engine without FD_Logs). The [HSM] button on the
  `/fdump secrets` panel also toggles it. FD_Logs ON opens it and OFF closes it (`/fdump set hsm.autoShow false` to keep it closed).
- v2.2.8: if the engine cannot start at capture ON you get one red chat line **ENGINE DOWN** (or a yellow **engine
  degraded** when only a helper such as the cooldown seed failed); the HSM window shows the same row. Please report it with
  the SavedVariables: the capture still records raw events, and the replay tape header (`hdr.stats`) says what failed.
- Drag the title bar to move it and the bottom-right grip to resize it; the text area scrolls. Escape closes it. Position and size
  are saved.
- **Top:** restriction states per type (green inactive, yellow activating, red active) and the always-on checks (combat log,
  addon chat).
- **Bars:** your cast and the target's cast. The yellow bar is the HSM prediction; the white bar under it is driven by the
  engine from a duration object (`SetTimerDuration`). Below them is the cooldown of your last spell (predicted bar vs a Cooldown
  frame fed by `SetCooldownFromDurationObject`) and player/target health bars. Widgets marked
  **"secret (engine-displayed)"** show values the addon cannot read; the engine draws them.
- **Text:** auras per unit (source observed / inferred + rule / cached, stacks, remaining time, confidence), cooldown
  predictions, the last 8 predictions with their outcome, contradictions, and counters (predictions, live contradictions,
  secrets seen).
- Colours: **green** observed, **yellow** inferred, **grey** unknown, **red** contradiction.
- Redraws happen only when something changed: a cast, an aura event, health, the target or a cooldown. The bars update at
  most 10 times a second and the text at most every 0.5 s (v2.2.4; was 0.25 s). Countdowns tick once a second.
- When nothing is pending, the window has no OnUpdate at all. When hidden, it also has no event registrations (v2.2.3).
- Layout: eight fixed rows (casts, cooldown, real cooldown, HP), each with a label on the left and a value on the right. The
  text body sits below the rows.
- Only plain frames (no secure templates, no protected actions, no Blizzard hooks), so it cannot taint Blizzard UI.

### Optional: BugSack / BugGrabber (on-screen errors while playing)
ForeverDump records Lua errors either way. If you also want to *see* errors while playing, install **BugGrabber** and
**BugSack** (CurseForge / Wago, by Funkeh; use versions that list your client). ForeverDump detects BugGrabber.
If BugGrabber is loaded, it owns the error handler, and ForeverDump subscribes to its `BugGrabber_BugGrabbed` callback.
If BugGrabber isn't loaded, ForeverDump chains the previous handler as before. On the FD_Logs OFF click, or with
`/fdump errors bg`, BugGrabber's current-session errors are copied into `ForeverDumpLogDB.bugGrabber`. Nothing is
required: both addons are optional (`## OptionalDeps`).

### Combat log restriction on Forever
`COMBAT_LOG_EVENT(_UNFILTERED)` is restricted. Registering it fires ADDON_ACTION_FORBIDDEN and a popup offering to
disable the addon (pcall doesn't prevent this), and `CombatLogGetCurrentEventInfo` is gone. ForeverDump never registers it.
`/fdump cl cleu-force` is an explicit opt-in that refuses unless the getter exists **and**
`C_CombatLog.IsCombatLogRestricted()` returns false. Use the file log (FD_Logs) together with
`tools/fdump.py combatlog` instead.

### v2.2.2: blocked-action attribution, container schema, options
- **Blocked actions:** every probe call is marked first. ADDON_ACTION_BLOCKED/FORBIDDEN fires synchronously inside the blocked call, so
  `/fdump errors show` names the culprit (for example `CombatProbe:CheckInteractDistance(party1)`). The path is learned in
  `ForeverDumpDB.blockedPaths[build]` and skipped in combat from then on. `CheckInteractDistance` is never called in combat on
  non-hostile units (protected since 2023-11-16).
- **Secret print test:** the operations matrix prints a secret into ForeverDump's own hidden ScrollingMessageFrame, never into
  ChatFrame1 (which tainted `ChatFrame1:UpdateFading`). `/fdump set secrets.opsPrint chat` restores the old behaviour; `false` skips it.
- **Container schema** (`containers.*`, on by default): every FD_Logs capture walks the probed returns recursively and stores the
  classification only, never values. Covered returns: auras by index, GetAuraSlots, GetUnitAuras, cast info, health, power, name,
  GUID, spell cooldown/charges/info, totems, and the UNIT_AURA payload. Coverage is per context and unit class, saved in
  `ForeverDumpLogDB.containers`. Runs: out of combat at capture start, 1.5 s into combat, after combat, on restriction flips and on
  ENCOUNTER_START (once per context per capture, at most `containers.maxRunsPerCapture`=8). In combat only non-protected reads run.
  Options: `containers.enabled`, `containers.events` (UNIT_AURA payload samples, `containers.eventSamples`=25),
  `containers.spells` (knowledge spells probed, 4).
- **HSM history:** the previous inference session moves to `inference.history` (keeps `hsm.keepSessions`=4) instead of being wiped.

### v2.2.3: performance, self-perf monitor, live verification
- **Frame rate:** v2.2.2 slowed the game more the longer you cast, because hot paths walked every global (about 17 ms each
  time). v2.2.3 caches that walk and keeps every per-event path O(1). The HSM window redraws only when something changed. The
  rules are in `PERFORMANCE.md`.
- **Self-perf monitor:** every FD_Logs capture records ForeverDump's own cost in `ForeverDumpLogDB.perf`:
  - per handler: calls, total ms, max ms and 15 s windows
  - every 5 s: heap, fps, C_AddOnProfiler and table sizes

  `/fdump perf` shows the top handlers and the share of wall time; the target is under 2% (release budget since 2026-10-08). `tools/fdump.py perf` writes
  PERF.md. Numbers only. Turn it off with `/fdump set perf.enabled false`.
- **HSM verification in combat:** in combat the UNIT_AURA payload is wholly secret. If a secret `addedAuras` arrives on the
  predicted unit right after your cast, the prediction counts as "aura event seen (secret payload, timing)" (medium
  confidence). Spell knowledge collected after the capture starts now reaches the live HSM.

### v2.2.4: live attribution, cooldown/GCD tracker, learned data, drift guard
Nothing new to click: everything below runs inside an FD_Logs capture (or `/fdump hsm start`) and is on by default unless
noted. Every option is `/fdump set <path> <value>`.

- **Who hit my target.** The HSM attributes each `UNIT_COMBAT` hit on you and your target (clear on 1.60.1) to *me* or
  *someone else* from clear timing only: my cast frame, the melee swing lag (about 0.46 s), the damage-meter update frame, and
  elimination. After combat it reconciles with C_DamageMeter: "others on my target = live total − meter mine". No CLEU, no side
  channels. Option: `hsm.combatSignals`.
- **Ledger.** Values seen while clear (target token→GUID, aura instances, cast GUIDs) are kept and reused when the same thing
  turns secret. The HSM window shows each one as live (green), cached fresh (yellow), cached stale (grey) or *maybe removed*
  (red: a doubt, never a claim). Option: `identity.*`.
- **Cooldown / GCD tracker.** Per spell: ready, on GCD, or cooling, with time left. It uses your own casts, isActive/isOnGCD
  flips, shared categories (the shocks share one), failed casts and clear API reads. The GCD per spell comes from
  `Data/spell-timing.lua` and is re-learned live (totems 1.0 s, Lightning Shield 1.5 s). The window shows at most 8 cooldown
  lines plus "+N more tracked". Options: `timing.*`.
- **Learned DB.** Spell ids, cast times, GCDs and NPC kits (npc id → spells, cast durations), learned from clear signals and
  stored per build in `ForeverDumpDB.learned`. Player names and GUIDs are never saved. Options: `learned.*`.
- **Drift guard (standing design rule).** Every learned or static value is a starting point. It is keyed by build, re-checked
  live, and loses weight when not re-confirmed. When live evidence keeps disagreeing, the value is flagged: the observed value
  is used at runtime, the seed file stays untouched, and a changelog entry (old → new, evidence, build) is written to
  `ForeverDumpDB.drift`. On the box, `tools/fdump.py analyze` turns the changelog into a proposed seed update, and
  `--write-seed` adopts it. A client patch is detected automatically, and every seed value counts as unverified until it is
  seen again. Options: `drift.*`.
- **Verification ring.** Live verdicts (verified / contradicted / unverifiable) for cooldowns, cast ends, damage ranges,
  interrupts and meter totals in `ForeverDumpDB.verify`. The box joins them with the combat log (`fdump analyze` → VERIFY.md).
- **Group-aware token scanner.** In combat a budgeted scanner (0.12 ms every 0.1 s, never OnUpdate) walks party, raid,
  nameplate, boss and arena tokens and records only *which* fields are secret per token family. Run it in a dungeon or
  battleground to fill the token matrix (FINDINGS.md has the checklist). Options: `tokenscan.*`.
- **Tooltip cooldown hypothesis: off.** `hsm.tooltipCooldownSignal` stays `false` until the evidence table proves it (line
  counts only, never tooltip text). Run 5 did not prove it.
- Cost: under 2% of frame time in the perf gate (release budget, user decision 2026-10-08) (PERFORMANCE.md). Aged sessions are no slower than fresh ones.

## Where the files land
- SavedVariables: `World of Warcraft\_classic_beta_\WTF\Account\<ACCOUNT>\SavedVariables\ForeverDump.lua`
  (ForeverDumpDB, …DocsDB, …StringsDB, …RecordDB, …LogDB, …CombatLogDB). Since v2.1 it writes a **compact** dump by default
  (about half the size); `/fdump set dump.full true` restores the v2.0 full dump (addon-created tables, all named regions, global string values)
- Logs (after FD_Logs ON): `World of Warcraft\_classic_beta_\Logs\WoWCombatLog-*.txt`, `WoWChatLog.txt`, `taint.log`
- Copy them to the box and run `python3 tools/fdump.py all ForeverDump.lua -o out/` (see `tools/README.md`), then
  `fdump.py inference ForeverDump.lua --file WoWCombatLog.txt` and `fdump.py guide ... --file ...` for the HSM scores and
  the guide.

## Privacy
Since v2.2.1 the SV meta holds your character's identity (name, realm, GUID, class, level, race) so the converter can find
you in the combat log; `tools/fdump.py fixtures` removes it (and your first and last name anywhere) from shareable packs.
`<ACCOUNT>` in the WTF path is your account name, and the chat log and combat log contain other players' names and
messages. Don't post those files publicly or share account-identifying or credential-bearing data. The recorder has
`set cl.redactPlayers true` for player GUIDs and names in legacy captures. Review files before sharing them.

## SavedVariables size (v2.2.11)
WoW loads `ForeverDump.lua` as one Lua chunk, and Lua 5.1 allows at most 262,143 distinct constants in it. A big diag
capture used to exceed that (run 9: 321,235) and the client showed `Error loading ...ForeverDump.lua: constant table
overflow`. Since v2.2.11, at logout/reload ForeverDump packs each large SavedVariable into a few hundred long strings
(lossless; run 9: 321,235 constants -> 321, 75.5 MB -> 48 MB, about 6 s more at logout) and rebuilds the tables at login
before anything reads them. There is still no cap on what is captured. If a save could still exceed the limit (only
possible with `/fdump set svpack false`), the OFF click prints one red warning. The offline tools read both the old and
the packed format.
