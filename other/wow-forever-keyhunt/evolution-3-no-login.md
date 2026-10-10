# Evolution 3 — no X/Twitter login

Timestamp: 2026-09-18 21:22:07 ET

## Goal
Find **new** WoW Forever beta codes with **verifiable age < 10 minutes**, without X login / paid X API.

## What worked
1. **Arctic Shift comments/posts API** (`arctic-shift.photon-reddit.com`) — best free source with `created_utc` for age gating.
   - Thread `r/australian` `1wik331`: works via `link_id=1wik331&sort=desc` but **went quiet ~11h** (only askers, no new dumps).
   - **r/wow new posts** scan caught the only <10m code this window.
2. **Aggressive parallel curl** (16–20 workers) across Arctic thread + subs + HTML mirrors each cycle.
3. **Dedup** via `seen-codes.txt` / known Windows+Reddit lists; claim-keyword filter on replies.
4. **OzBargain node 975129** — readable via WebFetch earlier; comments are banter, **no codes** (megathread redirect). Search/CF often 403.

## What failed / weak
- `reddit.com` / `old.reddit.com` JSON/HTML: login walls / 403 / non-comment shells.
- Most **redlib/libreddit** mirrors: 429, bot-checks, DNS dead, TLS EOF.
- `reddit.sentinel-team.org/posts/1wik331/`: **404**.
- PullPush: **429** agent rate limit.
- Arctic `body=` / posts `query=` params: **400** in this session (param surface changed / restricted).
- Icy Veins / Wowhead: news only, **no pasted keys** in comments dump.
- Nitter / X without login: not used per instructions; prior HTML was JS shell noise (UUID false positives).

## Fresh find this evolution
- `CVK5F4DMNBGJBFF6HLWQW` — r/wow self-post ~9m at confirm — https://www.reddit.com/r/wow/comments/1wk89wa/

## Poll interval recommendation
- **Primary:** poll Arctic `posts/search?subreddit=wow|classicwow|australian` + `comments/search?link_id=1wik331` every **20–30s** in parallel (backoff to 45–60s on 429).
- **Secondary HTML mirrors:** every **2–3 min** (high 429 rate).
- **OzBargain:** every **2–5 min** on deal + any discovered megathread node.
- Do **not** report codes older than **10m**; treat claimed/reply-claimed as TAKEN.
- AU daytime (evening ET previous day / morning AEST) historically denser — megathread currently stale overnight.

## Parallelism note
Raising workers above ~20 on Arctic triggers 429; prefer **many distinct endpoints** (subs/posts/thread) over hammering one URL.
