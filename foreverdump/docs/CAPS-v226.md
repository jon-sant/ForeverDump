# v2.2.6 capture caps (SV model)

Binding at capture/test for a 25-min 40-man BG: **tapeCap** (68 000 rows), not byteBudget.
KEEP (pri ≤ 2): decide / verdict / anchor / hdr — includes shadow + dm-reconcile.
Thinned first: ws (5) → sec/api (5–6) → map/dm (4) → sig (3). Overflow counted in `session.dropped` / `overflow`.

| Level | tapeCap | byteBudget | record | combat | signals | verify | Est. max SV* |
|---|---|---|---|---|---|---|---|
| release | 800 | 512 KB | 4 000 | 10 000 | 3 000 | 600 | ~2.7 MB |
| test | 68 000 | 10 240 KB | 38 000 | 85 000 | 6 000 | 12 000 | ≤ ~30 MB |
| diag | 80 000 | 12 288 KB | 45 000 | 100 000 | 8 000 | 16 000 | ~35 MB |

\* Model: tape×80 B + combat×55 B + record×45 B + verify×48 B + ~4 MB other (deep DM fights, learned, tokens). WorldCapture `ws` sits inside tapeCap and drops first under pressure. Lazy ring growth (no prealloc).

`ReplayLog.SerializeProxy` at capture end reports rows/keepers/ws/dm, estBytes, mbPerMin, **serializeMs**.

## Measured (box lua5.1, tests/sv_serialize_bench.lua) — rings filled to cap

| Level | Ring-fill SV | Serialize time (box) | + other SV (est.) | Total |
|---|---|---|---|---|
| release | 1.63 MB | ~100 ms | ~1 MB | ~2.7 MB |
| test | 20.77 MB | ~1.47 s | ~4–6 MB | ~25–27 MB (< ~30 MB) |
| diag | 24.67 MB | ~1.73 s | ~4–6 MB | ~29–31 MB |

The client's C serializer at logout is expected to be faster than this Lua text proxy; the in-game `SerializeProxy.serializeMs` is a row walk, not the full write.

## Minutes retained (model; ws rate measured by the perf_bench wc40 storm, others estimated)

| Level | Group | KEEP rows/min | KEEP retained | High-rate rows/min | High-rate retained |
|---|---|---|---|---|---|
| release | solo / 5 / 40 | 78 / 112 / 153 | 10 / 7 / 5 min | 40 / 60 / 80 | ~0 (crowded out by keepers) |
| test | solo / 5 / 40 | 95 / 130 / 175 | whole session (>6 h) | 610 / 1450 / 4580 | ~108 / 45 / 14 min |
| diag | solo / 5 / 40 | 95 / 130 / 175 | whole session | 610 / 1450 / 4580 | ~127 / 53 / 17 min |

At test/40BG: decide/verdict/anchor/shadow/reconcile kept for the whole 25 min; ws/sec/api thin to the last ~14 min with counted overflow.

## Perf gate robustness (no slack)

- **Raid40 scanner slice:** budget exactly `0.12` ms. Bench runs the 30 s / 40-man scenario **N=5** times, logs every raw `maxSlice` and in-run `p99`, and gates on the **median** of those. A single-run spike from host-clock jitter does not fail the build; a median over budget is a real scanner overrun.
- **SPELL_UPDATE_COOLDOWN storm:** already gates on the **median of 3** 10 s windows (≤0.5%). Raw window impacts are logged; one window may read above 0.5% (e.g. 0.62%) while the median stays under the gate.
