# Evolution 9 — Dual-cadence streaming poller (evo7 winner path)

## Basis
Evo7 race hunt winner: **`arctic_comments_wow`** median **253.6ms**, tip≈0.53m.
Hypothesis from evo7: cut notice latency with hot-path comments-by-sub every 6–8s,
emit as each future completes, demote posts to 20–30s backstop.

## Changes
- Poller: `poller_evo9.py`
- **HOT every 7s**: Arctic `comments/search?subreddit={wow,classicwow,australian}&sort=desc`
  in parallel (`ThreadPoolExecutor` + `as_completed`)
- **Cursor**: Arctic supports `after=` / `before=` as Date (unix OK); `after_id`/`cursor` → HTTP 400.
  Per-feed `after=` watermark + client-side id set so later polls only pull newer comments.
- **Emit per-future**: alerts written as soon as each feed returns (no full-barrier wait)
- **COLD every 30s**: `posts/search?subreddit=…&sort=desc` for same three subs
- Key format: `format_key` → **4-4-5-4-4**; age **&lt; 10m**
- Skip: `CVK5-F4DM-NBGJB-FF6H-LWQW` and any `*XXXX*`
- Alerts: `codes-live-e9.txt` — `CODE | age: Xm | source: URL | first_seen: ISO`
- Metrics: `evolution-9-metrics.jsonl`
- State: `state/e9_state.json` (seen codes, after_by, seen_ids)
- `if __name__ == '__main__'` guard; `--smoke N` for short runs
- Free only (Arctic Shift; no PullPush / paid X)

## Smoke (3 hot + 1 cold)
- Alive: **3/3** every cycle
- HOT wall: ~672–1042ms; tip ages ~0.4–1.8m
- After watermark effect: cycle1 n≈50/50/8 → cycle2–3 n≈1–10 (newer-only)
- **Fresh alerts (age &lt; 10m): 0** — none invented

## Continuous
- Started via `nohup python3 -u poller_evo9.py >> poller_evo9.log 2>&1 &`
- Log: `poller_evo9.log`

## Next hypothesis
If still zero fresh tips, add body keyword filter (`body=key` / `beta` / `code`) on low-volume
subs only (Arctic keyword search unsupported on very active subs like r/wow), and/or
watch known megathread `link_id` on a medium cadence with `after=` to catch drop comments
without re-scanning the full stale tree.
