# Evolution 13 — More free pollable sources

**Probed at:** 2026-09-18 22:00:33 ET
**Report written:** 2026-09-18 22:02:37 ET
**Region:** USA
**Key format:** `4-4-5-4-4 (example F8MC-855P-BJGTJ-TQP6-4BX6)`

## Fresh keys (<10m)

**NO FRESH KEY** under 10 minutes this evolution (reconfirmed @ fold 2026-09-18 10:04:06 PM ET).

- Skipped known: `CVK5-F4DM-NBGJB-FF6H-LWQW`
- Live scans @ probe: Arctic `r/wowforever` (posts/comments ages under a few minutes), 4chan `/vg/` wowfg `581529693` (replies <1m, 0 codes), `/v/` Forever thread `747964449`, Blizzard Discourse Maccas/free-keys/extra-keys topics, Google+Bing News RSS, HotUK/Slickdeals/gg.deals RSS, Alienware giveaways API, Telegram public channels, Warmane/Tauri, Lemmy dbzer0.
- No invented codes. No paid X API.

## Restart note (poller_evo12)

`sources-evo12-poll.json` was appended with evo13 **JSON/RSS/API** URLs, then **folded remaining Telegram** channels (`ggdeals`, `FreeGamesHub`, `FreePCGames`, `indiegala`, `wowforever`, `epicfreegames`).
**Current poll feed count: 73** (was 67 before final fold @ 2026-09-18 10:04:06 PM ET).

`poller_evo12.py` loads FEEDS once at start — **restart required** (and was restarted after this fold):

```bash
pkill -f poller_evo12.py || true
cd /workspace/wow-forever-keyhunt && nohup python3 poller_evo12.py >> poller_evo12.log 2>&1 &
```

Parser note: 4chan thread JSON + RSS `pubDate` age correctly; Arctic/Discourse dict dumps currently get `age=None` in poller_evo12 (won't alert until parser reads `created_utc` / `created_at`). Still worth polling for metrics / future upgrade.

### Fold completion (2026-09-18 10:04:06 PM ET)

- Appended 6 missing Telegram pollables into `sources-evo12-poll.json` (HTML forums intentionally not folded — poller is JSON/RSS/API + Telegram HTML).
- Fresh re-scan @ fold time: Arctic (wow/wowforever/classicwow/australian), 4chan `/vg/` wowfg + `/v/` Forever, Blizzard free/extra/maccas topics, Gamerpower — **NO FRESH** non-skipped 4-4-5-4-4 under 10m. Skip CVK5…. Gamerpower matched product-title false positive `BOMB-BOTS-ARENA-GIFT-PACK` (not a key; age=None).

## NEW sources summary

- **67** new endpoints (0 overlap with `sources-evo12.json` URLs)
- Machine list: `sources-evo13.json`

| Category | Count |
|---|---|
| arctic_reddit | 16 |
| 4chan | 8 |
| blizzard_forums | 6 |
| telegram | 6 |
| news_rss | 4 |
| deal_sites | 4 |
| private_servers | 4 |
| reddit_alts | 4 |
| discord | 4 |
| giveaways_api | 2 |
| addon_forums | 2 |
| free_calendars | 1 |
| lemmy | 1 |
| steam | 1 |
| discord_rss | 1 |
| forums | 1 |
| news | 1 |
| giveaways | 1 |

## High-value NEW poll targets

| ID | URL | Why | Probe |
|---|---|---|---|
| `arctic_posts_wowforever` | `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=wowforever&limit=50&sort=desc` | r/wowforever exists & ACTIVE (~minutes-old posts). High priority. | 200 / 185553B / 696ms |
| `arctic_comments_wowforever` | `https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=wowforever&limit=50&sort=desc` | Live comments; no 4-4-5-4-4 this probe. | 200 / 95191B / 692ms |
| `arctic_posts_classicwowtbc` | `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=classicwowtbc&limit=50&sort=desc` | NEW sub vs prior arctic set. | 200 / 220866B / 707ms |
| `arctic_posts_SeasonofDiscovery` | `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=SeasonofDiscovery&limit=50&sort=desc` | NEW. | 200 / 187692B / 635ms |
| `arctic_posts_CompetitiveWoW` | `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=CompetitiveWoW&limit=50&sort=desc` | NEW. | 200 / 191483B / 701ms |
| `gnews_forever_key` | `https://news.google.com/rss/search?q=%22Forever%20beta%20key%22%20OR%20%22Warcraft%20Forever%22%20key&hl=en-US&gl=US&ceid=US:en` | US-biased. Mentions Forever beta access articles; no codes. | 200 / 80816B / 626ms |
| `bing_news_forever` | `https://www.bing.com/news/search?q=Warcraft+Forever+beta+key&format=rss` | How-to-get-key articles; no code pastes. | 200 / 9089B / 490ms |
| `hotuk_rss_new` | `https://www.hotukdeals.com/rss/new` | Complement to hotuk /rss/hot already in evo12. | 200 / 82257B / 194ms |
| `slickdeals_rss` | `https://slickdeals.net/newsearch.php?q=warcraft+forever&rss=1` | HTML search existed in evo12; RSS is NEW pollable. | 200 / 41960B / 814ms |
| `ggdeals_news_rss` | `https://gg.deals/news/feed/` | Free/news firehose; no Forever key this probe. | 200 / 23512B / 184ms |
| `alienware_api_na` | `https://na.alienwarearena.com/api/v1/giveaways` | 20 live giveaways; none Warcraft Forever this probe. | 200 / 23530B / 6625ms |
| `blizz_thread_maccas_aussie` | `https://us.forums.blizzard.com/en/wow/t/for-the-aussie-players-beta-keys-through-mcdonalds-app/2350633.json` | McDonalds AU promo discussion; no codes this probe. | 200 / 89104B / 840ms |
| `blizz_thread_free_beta_keys` | `https://us.forums.blizzard.com/en/wow/t/free-beta-keys/2353972.json` | Opt-in free keys Q&A; active same day; no pastes. | 200 / 39700B / 572ms |
| `blizz_search_forever_key` | `https://us.forums.blizzard.com/en/wow/search.json?q=forever%20key` | Surfaces beta-key / Maccas / free-keys threads. No code pastes. | 200 / 108280B / 734ms |
| `blizz_thread_extra_beta_keys` | `https://us.forums.blizzard.com/en/wow/t/extra-beta-keys/2352990.json` | Extra/referral keys discussion. | 200 / 45067B / 651ms |
| `4chan_vr_catalog` | `https://a.4cdn.org/vr/catalog.json` | Backup board. No Forever OP hits this probe (Forever signal stays on /vg/). | 200 / 387581B / 110ms |
| `4chan_v_forever_thread` | `https://a.4cdn.org/v/thread/747964449.json` | /v/ Forever discussion thread (sentiment/AMA); no key pastes this probe. | 200 / 68803B / 87ms |
| `tg_wowforever` | `https://t.me/s/wowforever` | Channel renamed to WoW Forever 2026-09-12; currently empty of key dumps — watch. | 200 / 29330B / 895ms |
| `tg_FreePCGames` | `https://t.me/s/FreePCGames` | Active FreePCGames. | 200 / 103284B / 1274ms |
| `tg_ggdeals` | `https://t.me/s/ggdeals` | Active deals channel (~20 msgs). | 200 / 110468B / 1253ms |
| `lemmy_dbzer0_search` | `https://lemmy.dbzer0.com/api/v3/search?q=Forever%20beta%20key&type_=All&limit=20` | Alt to lemmy.world (often 403). | 200 / 133711B / 2302ms |
| `epic_free_promotions` | `https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=US&allowCountries=US` | No WoW Forever in current free slate. | 200 / 43062B / 260ms |
| `warmane_forum` | `https://forum.warmane.com/` | 200 OK; people sometimes dump retail keys. No codes this probe. | 200 / 69494B / 265ms |

## Probe notes by bucket (2026-09-18 22:00:33 ET)

### 4chan
- NEW catalogs HTTP 200: `/vr/ /vp/ /vm/ /vmg/ /g/ /biz/ /int/`.
- No `/games/` board on 4chan — used adjacent boards.
- Forever signal still on `/vg/` `/wowfg/` (live `581529693`).
- `/v/thread/747964449` Forever discussion — **0** 4-4-5-4-4 codes this probe.

### Arctic Reddit (NEW subs)
- **`r/wowforever` exists and is hot** (sub-minute–few-minute post/comment ages @ ~21:58 ET).
- Also 200: `classicwowtbc`, `SeasonofDiscovery`, `CompetitiveWoW`, `woweconomy`, `WowUI`, `pcmasterrace`, `ShouldIbuythisgame`, `truegaming`, `ClassicWowPlus` (comments).
- Prefer `arctic-shift.photon-reddit.com` (`arctic.wtf` timed out).
- Redlib mirrors mostly Anubis bot-wall (HTML 200, not JSON).

### News / deals RSS
- Google News + Bing News (US) 200 — access/how-to articles; **no key pastes**.
- HotUK `/rss/new` + `/rss/tag/gaming` NEW vs existing `/rss/hot`.
- Slickdeals search `rss=1` NEW vs prior HTML search.
- gg.deals news feed 200.

### Giveaway / free calendars
- Alienware Arena **API** NA+EU giveaways 200 (HTML page was evo12; API is new) — no Forever item.
- Epic freeGamesPromotions US JSON 200 — no Forever.
- Ubisoft free calendar path 404.

### Blizzard Discourse (NEW)
- `search.json?q=forever%20key`, EU beta-feedback category JSON.
- Topic JSONs: Maccas AU, Free Beta Keys (same-day), Extra keys, friend-invites.
- Discussion only — **no** pasted codes.

### Telegram beyond FreeGames/wowkeys
- Active: `ggdeals`, `FreeGamesHub`, `FreePCGames`, `indiegala`.
- `t.me/s/wowforever` exists (renamed 2026-09-12 UTC) — empty of dumps; watch.
- Many @betakeys/@mcdonaldskeys-style names are empty placeholders.

### Reddit alts / private servers / addons
- **Up:** Poal, Ruqqus lander, Tildes `~games`, Warmane, Tauri, Wowinterface forums, Curseforge wow.
- **Down/blocked:** Saidit DNS, Raddle 403, Lemmy.world 403, Kbin fail, Wowinterface RSS 403.
- Lemmy **dbzer0** search API 200 (good `lemmy.world` alternative).

### Discord / CN / Notion
- Invite APIs for wow/classicwow/sod 200 (metadata only).
- rssforever RSSHub root 200; sample discord channel route 503 — need real channel IDs.
- Baidu Tieba 403; Weibo thin; Bilibili 200 low signal; Google site:notion/airtable 429.
- Bluesky public search 403 from this box.

## Dead / blocked (do not poll)

- arctic.wtf timed out; use arctic-shift.photon-reddit.com
- redlib.* mostly Anubis bot-wall (HTTP 200 HTML) — not usable JSON
- Saidit DNS fail; Raddle/Lemmy.world 403; Kbin fail; Bluesky public.api 403
- Baidu Tieba 403; Weibo thin; QQ/NGA blocked; Notion/Airtable via Google 429
- psbdmp down; Pastebin dumps API dead; Kickstarter/BackerKit skipped per brief
- 4chan has no /games/ board — used /vr /vp /vm /vmg /g /biz /int

## Full NEW source ID list

- `4chan_vr_catalog` — `https://a.4cdn.org/vr/catalog.json`
- `4chan_vp_catalog` — `https://a.4cdn.org/vp/catalog.json`
- `4chan_vm_catalog` — `https://a.4cdn.org/vm/catalog.json`
- `4chan_vmg_catalog` — `https://a.4cdn.org/vmg/catalog.json`
- `4chan_g_catalog` — `https://a.4cdn.org/g/catalog.json`
- `4chan_biz_catalog` — `https://a.4cdn.org/biz/catalog.json`
- `4chan_int_catalog` — `https://a.4cdn.org/int/catalog.json`
- `4chan_v_forever_thread` — `https://a.4cdn.org/v/thread/747964449.json`
- `arctic_posts_wowforever` — `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=wowforever&limit=50&sort=desc`
- `arctic_comments_wowforever` — `https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=wowforever&limit=50&sort=desc`
- `arctic_posts_classicwowtbc` — `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=classicwowtbc&limit=50&sort=desc`
- `arctic_comments_classicwowtbc` — `https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=classicwowtbc&limit=50&sort=desc`
- `arctic_posts_SeasonofDiscovery` — `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=SeasonofDiscovery&limit=50&sort=desc`
- `arctic_comments_SeasonofDiscovery` — `https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=SeasonofDiscovery&limit=50&sort=desc`
- `arctic_posts_CompetitiveWoW` — `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=CompetitiveWoW&limit=50&sort=desc`
- `arctic_comments_CompetitiveWoW` — `https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=CompetitiveWoW&limit=50&sort=desc`
- `arctic_posts_woweconomy` — `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=woweconomy&limit=50&sort=desc`
- `arctic_comments_woweconomy` — `https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=woweconomy&limit=50&sort=desc`
- `arctic_posts_WowUI` — `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=WowUI&limit=50&sort=desc`
- `arctic_posts_pcmasterrace` — `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=pcmasterrace&limit=50&sort=desc`
- `arctic_comments_pcmasterrace` — `https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=pcmasterrace&limit=50&sort=desc`
- `arctic_posts_ShouldIbuythisgame` — `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=ShouldIbuythisgame&limit=50&sort=desc`
- `arctic_posts_truegaming` — `https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=truegaming&limit=50&sort=desc`
- `arctic_comments_ClassicWowPlus` — `https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=ClassicWowPlus&limit=50&sort=desc`
- `gnews_forever_key` — `https://news.google.com/rss/search?q=%22Forever%20beta%20key%22%20OR%20%22Warcraft%20Forever%22%20key&hl=en-US&gl=US&ceid=US:en`
- `gnews_maccas` — `https://news.google.com/rss/search?q=Warcraft+Forever+McDonalds+key&hl=en-US&gl=US&ceid=US:en`
- `bing_news_forever` — `https://www.bing.com/news/search?q=Warcraft+Forever+beta+key&format=rss`
- `bing_news_forever2` — `https://www.bing.com/news/search?q=%22Forever+beta%22+key&format=RSS`
- `hotuk_rss_new` — `https://www.hotukdeals.com/rss/new`
- `hotuk_rss_gaming` — `https://www.hotukdeals.com/rss/tag/gaming`
- `slickdeals_rss` — `https://slickdeals.net/newsearch.php?q=warcraft+forever&rss=1`
- `ggdeals_news_rss` — `https://gg.deals/news/feed/`
- `alienware_api_na` — `https://na.alienwarearena.com/api/v1/giveaways`
- `alienware_api_eu` — `https://eu.alienwarearena.com/api/v1/giveaways`
- `epic_free_promotions` — `https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=US&allowCountries=US`
- `blizz_search_forever_key` — `https://us.forums.blizzard.com/en/wow/search.json?q=forever%20key`
- `blizz_eu_beta_feedback` — `https://eu.forums.blizzard.com/en/wow/c/beta-feedback/33.json`
- `blizz_thread_beta_key_invites` — `https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-key-and-friend-invites/2349157.json`
- `blizz_thread_maccas_aussie` — `https://us.forums.blizzard.com/en/wow/t/for-the-aussie-players-beta-keys-through-mcdonalds-app/2350633.json`
- `blizz_thread_free_beta_keys` — `https://us.forums.blizzard.com/en/wow/t/free-beta-keys/2353972.json`
- `blizz_thread_extra_beta_keys` — `https://us.forums.blizzard.com/en/wow/t/extra-beta-keys/2352990.json`
- `lemmy_dbzer0_search` — `https://lemmy.dbzer0.com/api/v3/search?q=Forever%20beta%20key&type_=All&limit=20`
- `tg_ggdeals` — `https://t.me/s/ggdeals`
- `tg_FreeGamesHub` — `https://t.me/s/FreeGamesHub`
- `tg_FreePCGames` — `https://t.me/s/FreePCGames`
- `tg_indiegala` — `https://t.me/s/indiegala`
- `tg_wowforever` — `https://t.me/s/wowforever`
- `tg_epicfreegames` — `https://t.me/s/epicfreegames`
- `warmane_forum` — `https://forum.warmane.com/`
- `warmane_search_forever` — `https://forum.warmane.com/search.php?do=process&query=forever+beta+key`
- `tauri_forum` — `https://forum.tauriwow.com/`
- `wowcircle_forum` — `https://forum.wowcircle.net/`
- `wowinterface_forums` — `https://www.wowinterface.com/forums/forumdisplay.php?f=3`
- `curseforge_wow` — `https://www.curseforge.com/wow`
- `steam_discussions_search_forever` — `https://steamcommunity.com/discussions/forum/0/search/?q=Warcraft+Forever+beta`
- `poal_gaming` — `https://poal.co/s/gaming`
- `ruqqus_root` — `https://ruqqus.com/`
- `tildes_games` — `https://tildes.net/~games`
- `tildes_search_forever` — `https://tildes.net/search?q=warcraft+forever`
- `discord_invite_wow` — `https://discord.com/api/v9/invites/wow?with_counts=true`
- `discord_invite_classicwow` — `https://discord.com/api/v9/invites/classicwow?with_counts=true`
- `discord_invite_sod` — `https://discord.com/api/v9/invites/sod?with_counts=true`
- `discords_gg_wow_tag` — `https://discords.com/servers/tag/world-of-warcraft`
- `rsshub_rssforever` — `https://rsshub.rssforever.com/`
- `mmo_champion_forum` — `https://www.mmo-champion.com/forumdisplay.php?f=20`
- `wowhead_news_forever` — `https://www.wowhead.com/news?filter-by=forever`
- `freegameplanet` — `https://www.freegameplanet.com/`

## Files

- `sources-evo13.json` — NEW urls only (67)
- `sources-evo12-poll.json` — appended working JSON/RSS/API + 6 Telegram (**73 feeds; restart poller**)
- This report: `evolution-13.md` @ 2026-09-18 22:02:37 ET
