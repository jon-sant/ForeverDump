#!/usr/bin/env python3
"""Evo12: poll creative free feeds (RSS/JSON/4chan/API) for Forever keys."""
from __future__ import annotations
import json, re, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parent
ALERTS = ROOT / "codes-live-e12.txt"
METRICS = ROOT / "evolution-12-metrics.jsonl"
KNOWN = {"CVK5-F4DM-NBGJB-FF6H-LWQW", "CVK5F4DMNBGJBFF6HLWQW"}
PAT = re.compile(
    r"(?<![A-Za-z0-9])([A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{5}-[A-Z0-9]{4}-[A-Z0-9]{4})(?![A-Za-z0-9])",
    re.I,
)
PAT21 = re.compile(r"(?<![A-Za-z0-9])([A-Za-z0-9]{21})(?![A-Za-z0-9])")
INTERVAL = 25
MAX_AGE = 10

FEEDS = json.loads((ROOT / "sources-evo12-poll.json").read_text()) if (ROOT / "sources-evo12-poll.json").exists() else [
    "https://a.4cdn.org/vg/catalog.json",
    "https://www.ozbargain.com.au/forum/new/feed",
    "https://www.hotukdeals.com/rss/hot",
    "https://www.gamerpower.com/api/giveaways?type=game&platform=pc",
]


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
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "*/*"})
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=15) as r:
        body = r.read()
        ctype = r.headers.get("Content-Type", "")
    return body, ctype, int((time.perf_counter() - t0) * 1000)


def extract_codes(text: str):
    out = []
    for m in PAT.findall(text):
        c = format_key(m)
        if "XXXX" in c or c in KNOWN:
            continue
        out.append(c)
    for m in PAT21.findall(text):
        if sum(c.isdigit() for c in m) < 2:
            continue
        c = format_key(m)
        if c in KNOWN or "XXXX" in c:
            continue
        out.append(c)
    return list(dict.fromkeys(out))


def age_ok(age_m):
    return age_m is not None and 0 <= age_m < MAX_AGE


def parse_feed(url: str, body: bytes, ctype: str):
    """Return list of (code, age_m, source_url)."""
    now = time.time()
    text = body.decode("utf-8", "ignore")
    hits = []
    # JSON
    if "json" in ctype or url.endswith(".json") or "/api/" in url or "a.4cdn.org" in url:
        try:
            data = json.loads(text)
        except Exception:
            data = None
        if data is not None:
            # 4chan catalog
            if isinstance(data, list) and data and isinstance(data[0], dict) and "threads" in data[0]:
                for page in data:
                    for th in page.get("threads", []):
                        blob = " ".join(str(th.get(k, "")) for k in ("sub", "com"))
                        if not re.search(r"wow|warcraft|forever|maccas|beta", blob, re.I):
                            continue
                        # follow thread for ages — defer: only catalog keywords here
                        for c in extract_codes(blob):
                            hits.append((c, None, url))
                return hits
            # 4chan thread
            if isinstance(data, dict) and "posts" in data:
                for p in data["posts"]:
                    com = re.sub(r"<[^>]+>", " ", p.get("com") or "")
                    cu = p.get("time")
                    age = (now - float(cu)) / 60.0 if cu else None
                    if not age_ok(age):
                        continue
                    for c in extract_codes(com):
                        no = data["posts"][0].get("no")
                        hits.append((c, round(age, 1), f"https://boards.4chan.org/vg/thread/{no}#p{p.get('no')}"))
                return hits
            # GamerPower list
            if isinstance(data, list):
                for item in data:
                    if not isinstance(item, dict):
                        continue
                    blob = " ".join(str(item.get(k, "")) for k in ("title", "description", "instructions"))
                    if not re.search(r"warcraft|forever", blob, re.I):
                        continue
                    for c in extract_codes(blob):
                        hits.append((c, 0.0, item.get("open_giveaway_url") or url))
                return hits
            # Discourse-like
            if isinstance(data, dict):
                blob = json.dumps(data)[:200000]
                for c in extract_codes(blob):
                    hits.append((c, None, url))
                return hits
    # RSS/Atom
    if "xml" in ctype or "rss" in ctype or "/rss" in url or "/feed" in url or text.lstrip().startswith("<?xml") or "<rss" in text[:200]:
        try:
            root = ET.fromstring(body)
        except Exception:
            return hits
        for item in root.findall(".//item") + root.findall(".//{http://www.w3.org/2005/Atom}entry"):
            title = (item.findtext("title") or item.findtext("{http://www.w3.org/2005/Atom}title") or "")
            desc = (item.findtext("description") or item.findtext("{http://www.w3.org/2005/Atom}summary") or "")
            link = (item.findtext("link") or "")
            if not link:
                el = item.find("{http://www.w3.org/2005/Atom}link")
                if el is not None:
                    link = el.attrib.get("href", "")
            pub = item.findtext("pubDate") or item.findtext("{http://www.w3.org/2005/Atom}updated") or item.findtext("{http://www.w3.org/2005/Atom}published")
            age = None
            if pub:
                try:
                    age = (now - parsedate_to_datetime(pub).timestamp()) / 60.0
                except Exception:
                    try:
                        age = (now - datetime.fromisoformat(pub.replace("Z", "+00:00")).timestamp()) / 60.0
                    except Exception:
                        age = None
            blob = title + " " + desc
            if not re.search(r"warcraft|forever|maccas|beta\s*key|wow", blob, re.I) and not extract_codes(blob):
                continue
            if age is not None and not age_ok(age):
                continue
            for c in extract_codes(blob):
                hits.append((c, None if age is None else round(age, 1), link or url))
        return hits
    # HTML fallback — only codes, age unknown (skip unless we want unknown)
    return hits


def main():
    seen = set()
    ALERTS.touch(exist_ok=True)
    # also ensure live wowfg thread in rotation
    feeds = list(FEEDS)
    feeds.append("https://a.4cdn.org/vg/thread/581529693.json")
    feeds = list(dict.fromkeys(feeds))
    while True:
        t0 = time.perf_counter()
        fresh = []
        with ThreadPoolExecutor(min(12, max(2, len(feeds)))) as ex:
            futs = {ex.submit(fetch, u): u for u in feeds}
            for fut in as_completed(futs):
                url = futs[fut]
                try:
                    body, ctype, ms = fut.result()
                    hits = parse_feed(url, body, ctype)
                    # only alert with known young age
                    for c, age, src in hits:
                        if age is None or not age_ok(age):
                            continue
                        fresh.append((c, age, src))
                    with METRICS.open("a") as f:
                        f.write(json.dumps({"ts": datetime.now(timezone.utc).isoformat(), "url": url, "ms": ms, "hits": len(hits)}) + "\n")
                except Exception as e:
                    with METRICS.open("a") as f:
                        f.write(json.dumps({"ts": datetime.now(timezone.utc).isoformat(), "url": url, "err": str(e)[:120]}) + "\n")
        for c, age, src in fresh:
            if c in seen:
                continue
            seen.add(c)
            line = f"{c} | age: {age}m | source: {src} | first_seen: {datetime.now(timezone.utc).isoformat()}"
            print(line, flush=True)
            with ALERTS.open("a") as f:
                f.write(line + "\n")
            with (ROOT / "codes-live.txt").open("a") as f:
                f.write(line + "\n")
        time.sleep(max(1.0, INTERVAL - (time.perf_counter() - t0)))


if __name__ == "__main__":
    main()
