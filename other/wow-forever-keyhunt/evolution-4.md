# Evolution 4 — Age-gated parallel AU megathread hunt

## User feedback addressed
- Stop wasting time on old single-use codes that already have views.
- **Always attach AGE** to every emitted code.
- Prefer freshness over dump volume.

## What changed
New poller: `poller_evo4.py` (+ `evo4-config.json`).

| Knob | Default | Meaning |
|------|---------|---------|
| `max_age_min` | **10** | Only alert if `now - source_post_time < 10m`. Older = treated as taken / ignored. |
| `interval_sec` | ~40 | Poll cadence (30–60s band). |
| Fetch model | **parallel** | All mirrors fetched concurrently via thread pool (not serial). |
| X / Twitter | **none** | No paid X API. |

### Per-code state (`state/codes_db.json`)
For every observed code we store:
- `first_seen` — ISO UTC when we first observed it
- `source_post_time` / `source_post_time_iso` — comment timestamp when available
- `age_at_report` — minutes at alert time (only if alerted)
- `source_url`, `source_id`, `alerted`, `ignored_as_old`

### Alert format (hits only)
```
CODE | age: Xm | source: URL | first_seen: ISO
```
Codes with unknown age **cannot** alert (prevents recycling undated HTML scrapes).

## Sources (no-login, parallel each cycle)
1. **Arctic Shift** (`link_id=t3_1wik331`) — primary JSON comments feed
2. Arctic Shift alt (`link_id=1wik331`)
3. PullPush comments API (often 429 for agents)
4. old.reddit JSON (usually login/HTML wall)
5. old.reddit short JSON (same)
6. redlib.privacyredirect HTML
7. libreddit.projectsegfau HTML
8. Icy Veins MyMaccas article HTML
9. Blizzard WoW news HTML
10. OzBargain front HTML

## Measured run (2026-09-19 ~01:20–01:23 UTC)
6 metric rows (1 smoke + 5 continuous cycles @ 40s). Log: `raw/e4/run_cycles.log`. Metrics: `evolution-4-metrics.jsonl`.

| Metric | Value |
|--------|-------|
| Sources alive / cycle | **7 / 10** (stable) |
| Parallel `wall_ms` | 2678–4075 (≈ slowest mirror, not sum) |
| Arctic `tip_age_min` | **675–679** (~11.3h behind live) |
| Fresh alerts (age &lt; 10m) | **0** — none invented |
| Last successful poll | 2026-09-19T01:23:19Z |

**Alive:** arctic_shift, arctic_shift_alt, redlib_privacyredirect, libreddit_projectsegfau, icyveins_maccas, blizzard_wow_news, ozbargain_front.

**Dead / unusable:** pullpush (429), oldreddit_json + oldreddit_short_json (login HTML wall).

**Conclusion:** No codes younger than 10 minutes exist on reachable indexes right now. Old single-use dumps are tracked in `state/codes_db.json` as `ignored_as_old` and are **not** re-emitted.

## How to run
```bash
python3 poller_evo4.py --cycles 5 --interval 40 --max-age-min 10
python3 poller_evo4.py --continuous --interval 40 --max-age-min 10
```

## Next (evo5 candidates)
- Browser-session Reddit/X watchers for sub-minute tip once index lag matters.
- Keep Arctic as parallel backstop at ≥30–40s to avoid 429.
