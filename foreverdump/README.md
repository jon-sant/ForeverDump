# ForeverDump v2.2.6 bundle

- `SECRETS-GUIDE.html`: the Forever secret-values guide (single file; open in a browser). Built from the run-5 capture
  (shaman, 2026-10-08) with `tools/fdump.py guide --analysis`; includes "Combat-event coverage, attribution and the damage
  meter" and the new section 12 "Cooldown/GCD tracker, learned data and the drift rule".
- `FINDINGS-run5.md`: what run 5 showed (coverage matrix, the other player on my target, C_DamageMeter, HSM before/after,
  the tooltip cooldown hypothesis evidence, what the correlation miner found) and the dungeon/battleground capture checklist
  for the next run.
- `ForeverDump/`: the addon. Copy it to `World of Warcraft\_classic_beta_\Interface\AddOns\`. See `ADDON-USAGE.md`.
- `ADDON-USAGE.md`: install, slash commands and run order, the FD_Logs macro, where SavedVariables land, privacy.
- `INSTRUCTIONS-console.md`: console, CVar and log instructions. `SELF-HOSTING.md`: self-hosting and community sources.
- `tools/`: converter (`tools/README.md`), guide generator (`tools/guide/`), packaging (`tools/package.py`) and `tools/refresh/` (refresh scripts).
- `tests/`: mock client, addon smoke test, converter tests, sample addon, deliberate legacy addon (`tests/legacy_addon`) and **synthetic** log fixtures.
- `fixtures/forever-70245/`: a **raw** real Forever capture (v2.2.21: nothing anonymized) (API surface, environment, documented secrets map, combat/taint log). See its README.
- `fixtures/baselines/70245/`: the stored baseline signature (run 2), used by `fdump.py drift` / `all`, and `containers.json` (run-3 container schema, used by `fdump.py containers`).
- `CHANGES.md`: what changed from v1 through v2.2.6 (sealed replay tape, dual verbosity release/test, `fdump replay`).
- `PERFORMANCE.md`: the standing performance rule:
  - under 1% framerate impact
  - no idle OnUpdate
  - O(1) per event
  - dirty-only throttled redraws
  - heavy work out of combat or offline
  - every perf test run finishes within 2 minutes

  It also describes how the test runner enforces the rule.

**Not included (too large):** `data/` (≈215 MB extracted client data) and every `.cache/` folder (≈900 MB, e.g.
`tools/refresh/.cache`), plus `ref/` (reference API docs used by the smoke test) and `tests/out/` (generated). Re-create
them with `tools/refresh/refresh_all.sh` (see SELF-HOSTING.md).

Status: v2.1 ran in-game on Forever 70245 (runs 1-2), v2.2.1 in run 3, v2.2.2 in run 4 and v2.2.3 in run 5 (shaman,
2026-10-08; `real/2026-10-08-run5/out/FINDINGS.md`, shipped as `FINDINGS-run5.md`). **v2.2.5** adds offline
higher-order correlation (`correlate_ho`). **v2.2.6** ships one zip: default **release** (<1%); FD_Logs elevates to **test**/diag (≤10%) then restores; `/fdump level` override; sealed replay tape + `fdump replay`. v2.2.4 was built from run 5 and has
**not run in game yet**. Its live parts are scored only by replaying the run-5 live events through the same library,
offline against the combat log:
- live attribution, Ledger and the cooldown/GCD tracker
- the verification ring
- the group-aware token scanner (no data yet: run 5 predates it)
- the learned DB and the drift guard

It passes the mock client, the perf gate and the run-5 golden test.
