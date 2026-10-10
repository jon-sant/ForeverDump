# Evolution 12 — Creative source hunt (WoW Forever beta keys)

**Probe time:** 2026-09-18 21:48 ET  
**User region bias:** USA (not AU-city Arctic focus)  
**Skip:** `CVK5-F4DM-NBGJB-FF6H-LWQW`  
**Format:** 4-4-5-4-4 (ex. `F8MC-855P-BJGTJ-TQP6-4BX6`)  
**Success bar:** ≥5 NEW pollable endpoints beyond Arctic Reddit set — **met (48 non-Arctic HTTP 200 endpoints documented)**

---

## Fresh keys NOW (age <10m)

**None found.** Strict scan (hyphenated 4-4-5-4-4 + isolated 21-char Battle.net-ish charset with ≥3 digits) across all probed bodies returned **zero** live unused keys.

---

## Highest-value NEW poll surfaces (beyond Arctic)

| # | Source | Poll URL / API | Login? | Latency | Ages? | Fresh keys? |
|---|--------|----------------|--------|---------|-------|-------------|
| 1 | **4chan /vg/ catalog** | `https://a.4cdn.org/vg/catalog.json` | No | ~80ms | `last_modified` | No — but live `/wowfg/` |
| 2 | **4chan /wowfg/ thread** | `https://a.4cdn.org/vg/thread/581529693.json` | No | ~100–200ms | per-post `time` | No pastes; Maccas *asks* in sibling threads |
| 3 | **OzBargain forum RSS** | `https://www.ozbargain.com.au/forum/new/feed` | No | ~500ms | feed dates | No (HTML nodes often 403; RSS open) |
| 4 | **HotUKDeals RSS** | `https://www.hotukdeals.com/rss/hot` | No | ~400ms | pubDate | No Forever key deal |
| 5 | **Slickdeals search (USA)** | `https://slickdeals.net/newsearch.php?q=warcraft+forever&searcharea=deals&searchin=first` | No | ~1.5s | HTML stamps | No |
| 6 | **Blizzard Discourse JSON** | `.../t/.../2352596.json` + `.../c/beta-feedback/33.json` | No | ~300ms | `created_at` | Discussion only |
| 7 | **GamerPower API** | `https://www.gamerpower.com/api/giveaways` | No | ~60ms | published_date | 101 giveaways, 0 Forever |
| 8 | **Frugal Feeds article** | MyMaccas Forever how-to URL | No | ~500ms | article | No codes in body/comments |
| 9 | **Telegram public preview** | `https://t.me/s/FreeGames` (+ wowkeys stubs) | No | ~500ms | preview dt | No |
| 10 | **HN Algolia** | `https://hn.algolia.com/api/v1/search?query=Warcraft%20Forever%20beta` | No | ~400ms | created_at_i | Unrelated hits |
| 11 | **Lemmy / Mastodon search** | lemmy.world + mastodon.social APIs | No | ~300ms | published | Empty |
| 12 | **Bahamut TW WoW board** | `https://forum.gamer.com.tw/B.php?bsn=60030` | No | ~400ms | board times | No EN key dump |
| 13 | **Alienware Arena giveaways** | `https://na.alienwarearena.com/ucf/Giveaway` | No | ~800ms | listing | No Forever |
| 14 | **Icy Veins Maccas news** | icy-veins Forever Maccas article | No | ~300ms | article | Guide only |
| 15 | **Press-Start AU promo** | press-start Forever Maccas article | No | ~500ms | article | Guide only |

Full machine-readable list: `sources-evo12.json` (`poll_urls_http_200`, `top_poll_priority`).

---

## Creative category notes

### 4chan (best new free JSON firehose)
- Free JSON API: catalog + thread — **no login, timestamps, pollable**.
- Active `/wowfg/` World of Warcraft Forever General threads (probe: `581529693` live; also `581518238`, `581505236` at bump).
- Older sibling thread chatter: “Is the maccas deal still a thing?”, “beta key for cheap?”, Bluestacks+MyMaccas tip — **demand without public unused pastes**.
- False-positive risk: naive 21-char regex matches English after stripping spaces; use strict charset + digit mix.

### Deal sites (USA + UK + AU RSS)
- **Slickdeals** (USA) search 200 — no Forever beta key deal.
- **HotUKDeals** RSS/search 200 — “Forever” ≠ WoW Forever (Forever Skies, Tetris Forever noise).
- **OzBargain** HTML search often 403; **forum/new/feed RSS = 200** and remains the AU Maccas signal path when Cloudflare blocks nodes.

### Fediverse / HN / Lobsters
- Mastodon + Lemmy public search APIs = 200 but empty for Forever keys.
- Bluesky `searchPosts` = **403** here; `getAuthorFeed` for blizzard actor returned empty body.
- HN Algolia = 200, noise irrelevant; Lobsters newest RSS = 200, no WoW.

### Partner / freebie APIs
- GamerPower giveaways + beta filter: live, fast, **no WoW Forever**.
- GrabFreeGames, Indiegala freebies, Fanatical free, Alienware Arena: 200, no Forever beta keys.
- FreeLoot homepage ~114b stub.

### Paste / GitHub
- Rentry / ControlC / Pastelink / JustPaste / dpaste / hastebin / termbin homes 200 — **no public Forever dump index**.
- `rentry.co/api/raw/wowforever` empty.
- Pastebin search 403; GitHub gist search 429; GitHub code HTML search 200 with no real keys.
- Ghostbin 403.

### Telegram
- `t.me/s/FreeGames` fat preview 200 — generic Steam freebies.
- `t.me/s/wowkeys`, `FreeSteamKeys`, `gamekeys`, `cdkeys` — thin/stub pages, no Forever codes.

### Asia forums
- Bahamut (TW) WoW board 200 — no English MyMaccas dumps.
- Inven (KR) 200 thin — no EN keys.
- NGA CN mixed 200/403 — not useful for English Battle.net codes.

### Discord / Guilded / University archives
- Invite metadata API 200 (`discord.com/api/v9/invites/...`) — **metadata only**, no messages.
- Guilded discover 200 — no key channel without auth.
- University Discord public archives / guild recruiting “key bribes” — **not free-pollable** without Discord auth/scrapers.

### Blizzard / news comment sections
- Official Forever beta Discourse `.json` 200 — no code pastes (people don't dump unused CE/MyMaccas codes there this probe).
- Frugal Feeds / Press-Start / Icy Veins / Blizzard Watch / PC Gamer / Gamespot / Polygon / Kotaku / RPS — articles or search 200; **promo text only**, no redeemable keys in comments captured.

### IRC / streaming chat logs
- Libera irclog index + irccloud.com 200 — need known channel; none verified for Forever key spam.
- Streaming Logviewer-style sites: not found as durable free Forever key feeds.

### Craigslist / OfferUp
- SF Bay free search: intermittent 200/403; **scam-prone**. Note only: no real 4-4-5-4-4 format observed. Do not race CL “free beta key” sellers.

### Reddit mirrors (not Arctic)
- `old.reddit.com/.../new.json` returned HTTP 200 but **Cloudflare HTML**, not JSON — unusable.
- `www.reddit.com/*.json` 403/429.
- Pullpush 429; Redarc index only.
- **Arctic remains the only reliable Reddit poller** for this box.

---

## Poller integration tips

1. **Rotate 4chan:** poll catalog → extract `/wowfg/` nos → poll thread JSON every 15–30s; on 404, re-resolve from catalog.
2. **OzBargain RSS** every 60s as AU complement when node HTML is 403.
3. **Slickdeals + HotUK RSS** for USA/UK deal comment leaks (low prior).
4. **Blizzard `.json`** every few minutes for rare CE-code paste hope (low prior).
5. **GamerPower API** cheap heartbeat for official giveaways.
6. Keep **strict key regex**: hyphenated `4-4-5-4-4` with charset `2345689A-HJ-NP-TV-X`, ≥3 digits, ≥10 unique chars; skip `CVK5-F4DM-NBGJB-FF6H-LWQW`.

---

## Outcome

| Metric | Result |
|--------|--------|
| Fresh <10m keys | **0** |
| NEW non-Arctic HTTP 200 endpoints | **48** (≫5 required) |
| Invented keys | None |
| Skipped known | CVK5-… |

Artifacts:
- `/workspace/wow-forever-keyhunt/evolution-12-creative.md` (this file)
- `/workspace/wow-forever-keyhunt/sources-evo12.json`
- Raw bodies: `/workspace/wow-forever-keyhunt/raw/evo12/*.body`
