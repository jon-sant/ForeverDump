# Evolution 3 — cut notice latency further

## Current bottleneck (Evo2 findings)
- Fastest curl JSON: **Arctic Shift** ~150–460ms, but **index tip is ~11h behind** live Reddit (no comments after 2026-09-18 14:04 UTC).
- reddit.com / old.reddit / redlib / pullpush: botwall, 403, or 429 for agents.
- Sentinel: one historical snapshot only (live post 404).
- OzBargain code megathread: 403.
- **X/Twitter must be browser** — curl HTML is not a usable live notice channel.

## Evo3 plan (lowest notice latency)
1. **Browser-only X watcher** (Playwright/CDP, logged-in session optional):
   - Open `https://x.com/search?q=MyMaccas%20OR%20%22WoW%20Forever%22%20(code%20OR%20key)&f=live`
   - Poll DOM every **2–3s**; extract 21-char + hyphenated keys; push to `codes-live.txt` with `age_min` from tweet timestamp.
2. **Parallel Reddit mirrors in browser** (same session that passes Anubis/bot checks):
   - old.reddit thread `1wik331` sorted by new; redlib instance that works in real Chrome.
   - Interval **3–5s**; abort duplicate in-flight fetches.
3. **Arctic Shift keep-alive** at **15–20s** (avoid 429) as passive backstop once index catches up.
4. **Freshness gate stays**: only emit if `age_min <= 5` (tighten from Evo2’s 30) — aged dumps are presumed taken.
5. **Optional webhook**: on fresh hit, desktop notify / Telegram so human redeems in seconds.

## Target
Sub-10s notice from public post → `codes-live.txt` via browser X + Reddit; curl APIs remain metrics/backstop only.
