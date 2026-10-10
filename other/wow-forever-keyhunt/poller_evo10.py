#!/usr/bin/env python3
"""Evo8: poll only fastest Arctic feeds every ~12s; format-lock 4-4-5-4-4."""
from __future__ import annotations
import json, re, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ALERTS = ROOT / "codes-live-e10.txt"
METRICS = ROOT / "evolution-10-metrics.jsonl"
KNOWN = {"CVK5-F4DM-NBGJB-FF6H-LWQW", "CVK5F4DMNBGJBFF6HLWQW"}
PAT = re.compile(r"(?<![A-Za-z0-9])([A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{5}-[A-Z0-9]{4}-[A-Z0-9]{4})(?![A-Za-z0-9])", re.I)
PAT21 = re.compile(r"(?<![A-Za-z0-9])([A-Za-z0-9]{21})(?![A-Za-z0-9])")
NOISE = {"ERROR","MESSAGE","EXPERIMENT","CALLBACK","PERFORMANCE","MEASURE","INNERHTML","OPENGRAPH","REQUESTIDLE","DANGEROUSLY","CATEGORY","EXTRACT"}
FEEDS = [
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=CompetitiveWoW&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=FreeGameFindings&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=FreeGamesOnSteam&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=GameGiveaway&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=RandomActsOfGaming&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=SeasonofDiscovery&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=classicwow&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=pcmasterrace&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=steam_giveaway&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=wow&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=wowclassic&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=woweconomy&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=wowservers&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/comments/search?subreddit=wowservers&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=AussieGaming&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=CompetitiveWoW&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=FreeGameFindings&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=FreeGamesOnSteam&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=GameGiveaway&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=RandomActsOfGaming&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=SeasonofDiscovery&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=classicwow&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=gamedeals&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=pcmasterrace&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=steam_giveaway&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=wow&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=wowclassic&limit=40&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=woweconomy&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=wowservers&limit=30&sort=desc",
    "https://arctic-shift.photon-reddit.com/api/posts/search?subreddit=wowservers&limit=40&sort=desc",
    "https://press-start.com.au/news/2026/09/18/wow-forever-mcdonalds-promo/",
    "https://t.me/s/wowforever",
    "https://us.forums.blizzard.com/en/wow/t/the-world-of-warcraft-forever-beta-now-live/2352596.json",
    "https://www.gamerpower.com/api/giveaways",
    "https://www.gamerpower.com/api/giveaways?type=beta",
    "https://www.gamerpower.com/rss/giveaways",
    "https://www.gamerpower.com/rss/pc",
    "https://www.mmo-champion.com/content/14536-Warcraft-Forever-Collection-Giveaway"
]
INTERVAL = 10
MAX_AGE = 10

def format_key(raw: str) -> str:
    s = raw.strip().upper().replace(" ", "")
    parts = s.split("-")
    if len(parts) == 5 and [len(x) for x in parts] == [4, 4, 5, 4, 4]:
        return "-".join(parts)
    body = s.replace("-", "")
    if len(body) == 21 and body.isalnum():
        return f"{body[0:4]}-{body[4:8]}-{body[8:13]}-{body[13:17]}-{body[17:21]}"
    return s

def fetch(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=12) as r:
        data = json.loads(r.read().decode())
    return data, int((time.perf_counter() - t0) * 1000)

def extract(data):
    now = time.time()
    out = []
    items = data.get("data") or []
    for it in items if isinstance(items, list) else []:
        if not isinstance(it, dict):
            continue
        blob = " ".join(str(it.get(k, "")) for k in ("title", "selftext", "body"))
        cu = it.get("created_utc")
        if cu is None:
            continue
        age_m = (now - float(cu)) / 60.0
        if age_m >= MAX_AGE:
            continue
        codes = [format_key(x) for x in PAT.findall(blob)]
        for m in PAT21.findall(blob):
            if m.upper() in NOISE or sum(c.isdigit() for c in m) < 2:
                continue
            codes.append(format_key(m))
        sid = it.get("id")
        sub = it.get("subreddit", "")
        for c in codes:
            if c in KNOWN or c.replace("-", "") in KNOWN:
                continue
            if c.endswith("-PXXX") or "XXXX" in c:
                continue
            out.append((c, round(age_m, 1), f"https://www.reddit.com/r/{sub}/comments/{sid}/"))
    return out

seen = set()
ALERTS.touch(exist_ok=True)
while True:
    t_wall0 = time.perf_counter()
    fresh = []
    with ThreadPoolExecutor(12) as ex:
        futs = {ex.submit(fetch, u): u for u in FEEDS}
        for fut in as_completed(futs):
            url = futs[fut]
            try:
                data, ms = fut.result()
                hits = extract(data)
                fresh.extend(hits)
                METRICS.open("a").write(json.dumps({"ts": datetime.now(timezone.utc).isoformat(), "url": url, "ms": ms, "fresh": len(hits)}) + "\n")
            except Exception as e:
                METRICS.open("a").write(json.dumps({"ts": datetime.now(timezone.utc).isoformat(), "url": url, "err": str(e)[:120]}) + "\n")
    for code, age, src in fresh:
        if code in seen:
            continue
        seen.add(code)
        line = f"{code} | age: {age}m | source: {src} | first_seen: {datetime.now(timezone.utc).isoformat()}"
        print(line, flush=True)
        ALERTS.open("a").write(line + "\n")
    elapsed = time.perf_counter() - t_wall0
    time.sleep(max(1.0, INTERVAL - elapsed))
