# Evolution 10 — Additional free public sources (WoW Forever beta keys)

**Probe time:** 2026-09-18 21:36 ET  
**Baseline already used:** Arctic `r/wow`, `r/australian` (megathread `1wik331`), `r/classicwow`, OzBargain, Icy Veins articles.  
**Skip:** `CVK5-F4DM-NBGJB-FF6H-LWQW`

---

## Fresh keys NOW (age &lt; 10m)

**None found** at probe time across expanded Arctic subs, GamerPower API/RSS, Blizzard thread JSON, MMO-Champion, Frugal Feeds, Press-Start, and public Telegram preview pages.

---

## Stale notable (NOT &lt;10m — likely taken)

Decoded from public `r/wowclassic` self-post (obfuscated `…PXXX` + “Replace last three XXX letters with **vee see three**” → **VC3**):

- **`4GVP-QQ4H-CX6CL-Q9PX-PVC3`** — age **~47m** at probe — https://www.reddit.com/r/wowclassic/comments/1wk7qla/ — author `notyetimpooping`  
- Comments already mourning “too late” → treat as **redeemed / do not race**.

---

## Category findings (1–11)

### 1) Discord public channels / scrapers
| Lead | Poll w/o login? | Latency / notes | Fresh keys? |
|------|-----------------|-----------------|-------------|
| [WoW Forever NA directory](https://discord.com/servers/wow-forever-na-1528511731523915907) | **No** (chat needs Discord auth) | Directory page public; no key channel advertised | No |
| Invite metadata `discord.com/api/v9/invites/{code}` | Metadata only | Fast; **no message bodies** | No |
| `discord.gg/gam3sgg` (GAMES.GG) | Metadata yes | General freebies bot (~90k) — not Forever-specific | No |
| Disboard keyword search | Cloudflare wall | Not reliable from bots | No |
| Public Discord history scrapers / “leaks” dumps | — | **No verified Forever/MyMacca dump** found | No |

### 2) Facebook groups / Marketplace AU
| Lead | Poll w/o login? | Notes | Fresh keys? |
|------|-----------------|-------|-------------|
| [World of Warcraft Oceanic](https://www.facebook.com/groups/WorldofWarcraftOceanic/) | **No** (302/empty to bots) | SERP suggests AU key chatter | Unknown / not scrapable |
| [WoW Classic Community](https://www.facebook.com/groups/WoWClassicCommunity/) | Login wall | Occasional MyMacca mentions in search snippets | No (blocked) |
| Facebook Marketplace AU | Login | Scam-prone; not pollable | No |

### 3) discord.gg + “wow forever beta key”
No invite resolved to a **public key-paste** server. Community hubs are LFG/news only.

### 4) Telegram
| Channel | Public preview | Fresh keys? |
|---------|----------------|-------------|
| https://t.me/s/wowforever | Empty rename junk (~1 sub) | No |
| https://t.me/s/gam3sgg | Games.gg promo | No |
| `@wowkeys` / `@betakeys` style | No verified Forever dump | No |

### 5) Blizzard forums / MMO-Champion
| URL | Poll w/o login? | Keys pasted? |
|-----|-----------------|--------------|
| https://us.forums.blizzard.com/en/wow/t/the-world-of-warcraft-forever-beta-now-live/2352596.json | Yes (JSON 200) | Discussion only — **no** MyMacca codes |
| https://www.mmo-champion.com/content/14541-The-World-of-Warcraft-Forever-Beta-Now-Live | Yes | News HTML — no codes |
| https://www.mmo-champion.com/content/14536-Warcraft-Forever-Collection-Giveaway | Yes to read; winner via **PM** | Not a public paste feed |

### 6) Twitch drops / streamer chat
No official Forever Twitch Drops key campaign found. Chat giveaways are not a free durable poll API (need IRC/auth + live stream). **Skip for no-login poller.**

### 7) Microsoft / @Windows-style giveaways
**None found** for WoW Forever beta keys on Microsoft/Xbox/Windows channels.

### 8) Pastebin / Ghostbin / Haste
Pastebin search 302/empty; psbdmp DNS dead; paste.ee/controlc 404. **No live Forever key pastes.**

### 9) Guilded / Steam / ResetEra / NeoGAF
| Site | Result |
|------|--------|
| Guilded discover | No Forever key community found |
| Steam discussions | WoW not on Steam — irrelevant |
| ResetEra / NeoGAF / Whirlpool search | **403** |

### 10) CN / KR / EU / TW forums
Bahamut & Inven pages fetchable; **no English MyMacca key dumps** observed. AU codes stay on AU/EN social surfaces.

### 11) RSS / JSON free feeds
| Feed | OK? | Forever keys now? |
|------|-----|-------------------|
| https://www.gamerpower.com/api/giveaways | Yes (101) | **No** WoW/Forever |
| https://www.gamerpower.com/api/giveaways?type=beta | Yes (4) | Unrelated Steam betas |
| https://www.gamerpower.com/rss/giveaways | Yes | No Forever |
| https://www.gamerpower.com/rss/pc | Yes | No Forever |
| Lemmy / Mastodon search APIs | Yes | No Forever key posts |
| Bluesky public search | **403** this egress | — |

---

## NEW Arctic Reddit targets (highest value add)

Same host you already poll: `https://arctic-shift.photon-reddit.com/api/{posts|comments}/search?subreddit=SUB&limit=40&sort=desc`

| Subreddit | Why | Poll OK? | Fresh &lt;10m now? |
|-----------|-----|----------|-------------------|
| **`wowclassic`** | **Proven drop** (obfuscated key self-post) | Yes ~400–900ms | No (stale ~47m only) |
| `sydney` | Macca key **request** posts | Yes | No |
| `brisbane` | Request posts | Yes | No |
| `perth` | Request posts (“ANY AUS MACCAS CODE”) | Yes | No |
| `wowservers` | “searching for a beta key” posts | Yes | No |
| `melbourne` / `australia` / `AussieGaming` | AU adjacency | Yes (AussieGaming thin) | No |

Also useful: per-request `comments/search?link_id={id}` when a city ask post appears (replies were empty/low during probe).

**Still dead for freshness:** megathread `1wik331` tip age ~11h+.

**Extractor gap:** dumpers use `…XXX` + “vee see three”. Decode VC3 before age-gate; don’t alert raw `PXXX`.

---

## Ranked poller additions

1. Arctic **posts+comments** `wowclassic` (must)
2. Arctic **posts** `sydney`,`brisbane`,`perth`,`wowservers` (+ comments or link_id follow-up)
3. GamerPower API + RSS every 5–15m (slow watch)
4. Blizzard thread `.json` + MMO-C giveaway HTML occasional
5. Frugal Feeds / Press-Start HTML occasional (news; low paste rate)
6. **Do not automate:** Facebook, Discord chat, unverified Telegram “key” channels, Pastebin scrapers, ResetEra/NeoGAF, paid X

Full URL list with probe `ok/ms/n`: `sources-evo10.json` (36 feeds; **22 newly appended** this pass).
