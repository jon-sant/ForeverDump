# Evolution 7 — Arctic parallel posts+comments, 4-4-5-4-4 format lock

## Changes
- Poller: `poller_evo7.py`
- Parallel Arctic Shift every **12–15s**: posts/search + comments/search for `wow`, `classicwow`, `wowclassic`, `australian` (+ megathread + pullpush)
- Key format locked: **4-4-5-4-4** via `format_key`; 21-char continuous hyphenated on emit
- Age gate: `created_utc` age **< 10m**; stamp age on every alert
- Alerts: `codes-live-e7.txt` — `CODE | age: Xm | source: URL | first_seen: ISO`
- Dedup by normalized continuous code; skip `CVK5-F4DM-NBGJB-FF6H-LWQW`
- Free only (no paid X API)

## Race (arctic posts-by-sub vs comments search vs other free)
- Log: `evolution-7-race.jsonl` (3 rounds, parallel wall ≈2653.2ms)
- **Hunt winner (fresh tip preferred):** `arctic_comments_wow` median **253.6ms**, tip≈0.53m (ok 3/3)
- **Speed winner among tip&lt;15m:** `arctic_comments_wow` median **253.6ms**, tip≈0.53m
- **Posts-by-subreddit winner:** `arctic_posts_wow` median 266.4ms, tip≈0.59m
- **Comments search winner:** `arctic_comments_wow` median 253.6ms, tip≈0.53m
- **Other free winner:** none (all failed / 429)

### Notes
- `arctic_comments_megathread` is often fastest (~50–250ms) but tip_age ≈ **11h** — useless for fresh keys.
- PullPush returned **429** every round — not usable from this box.
- Subreddit comments/posts tips are **sub-minute to a few minutes** — real hunt path.

### Ranked (successful only; hunt-order)
| Endpoint | median_ms | tip_age_min | ok_rounds |
|----------|-----------|-------------|-----------|
| `arctic_comments_wow` | 253.6 | 0.53 | 3 |
| `arctic_comments_classicwow` | 259.3 | 0.54 | 3 |
| `arctic_posts_wow` | 266.4 | 0.59 | 3 |
| `arctic_posts_classicwow` | 255.3 | 0.73 | 3 |
| `arctic_comments_australian` | 271.9 | 1.51 | 3 |
| `arctic_comments_wowclassic` | 271.3 | 1.88 | 3 |
| `arctic_posts_ids_known` | 264.3 | 16.09 | 3 |
| `arctic_posts_australian` | 255.2 | 21.41 | 3 |
| `arctic_posts_wowclassic` | 262.7 | 35.71 | 3 |
| `arctic_comments_megathread` | 246.6 | 684.28 | 3 |

## Poll run (5 cycles @ 13s)
- Alive: **9/10** endpoints/cycle (PullPush 429)
- Parallel wall: ~2.6–2.7s
- **Fresh alerts (age &lt; 10m): 0** — none invented
- Known skipped: `CVK5-F4DM-NBGJB-FF6H-LWQW`

## Next hypothesis (Evolution 8)
Cut notice latency with a dual-cadence streaming poller: hot-path only the freshest Arctic **comments/search-by-sub** endpoints (wow/classicwow/wowclassic/australian) every **6–8s** using an `after=` unix watermark + per-id cursor, emitting alerts **as each future completes** (no full-barrier wait); demote posts/search and megathread to a **20–30s** backstop; drop PullPush until 429 clears. Target: notice within ~one Arctic tip lag (~0–2m) + one hot interval, not wall_ms of the slowest peer.

