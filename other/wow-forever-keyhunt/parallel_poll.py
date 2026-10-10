#!/usr/bin/env python3
"""High-parallelism free-source poller for WoW Forever beta codes. No X/Twitter paid API."""
import concurrent.futures as cf
import json, re, time, os, hashlib
from datetime import datetime, timezone, timedelta
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode

OUT = "/workspace/wow-forever-keyhunt"
RAW = f"{OUT}/raw"
LIVE = f"{OUT}/codes-live.txt"
SEEN_FILE = f"{OUT}/raw/seen_codes.json"
ET = timezone(timedelta(hours=-4))

KNOWN = {
    "8R4H-WP8S-DCBDV-FQFX-K5GK","JP5G-3XKK-8CPJ6-SCF8-TSQW","MQP5-MRXM-39QLC-6HTW-QNRJ",
    "F8MC-855P-BJGTJ-TQP6-4BX6","VS8R-TGC5-C35L6-49VK-TC8G","LL9F-DX98-P6DXG-RKCV-93BG",
    "98MB-CDDN-8PWT8-HXRX-6MQW","8WL8M6FFMLB9D3DBV4WF5","SSW9D9L46PPDPSG93DFMP",
    "48WFWPCPDC5N4PFCK6NXL","8HF9HS9D4H49JGBDM6K3B",
}

PAT_C = re.compile(r"(?<![A-Z0-9])([A-Z0-9]{21})(?![A-Z0-9])")
PAT_W = re.compile(r"(?<![A-Z0-9])([A-Z0-9]{4,5}-[A-Z0-9]{4,5}-[A-Z0-9]{4,5}-[A-Z0-9]{4,5}-[A-Z0-9]{4,5})(?![A-Z0-9])")
CLAIM = re.compile(r"\b(claimed|taken|already (gone|used|taken)|redeemed|snagged)\b", re.I)
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/128.0.0.0 Safari/537.36"

def load_seen():
    try:
        return set(json.load(open(SEEN_FILE)))
    except Exception:
        return set(KNOWN)

def save_seen(seen):
    json.dump(sorted(seen), open(SEEN_FILE, "w"))

def http_get(url, accept="*/*", timeout=20):
    req = Request(url, headers={"User-Agent": UA, "Accept": accept})
    with urlopen(req, timeout=timeout) as r:
        return r.status, r.read()

def looks_like_code(code):
    if code in KNOWN:
        return False
    if "-" in code:
        parts = code.split("-")
        if len(parts) != 5:
            return False
        # reject UUID-ish hex-only windows from HTML junk
        hexish = sum(1 for ch in code if ch in "ABCDEF")
        digits = sum(ch.isdigit() for ch in code)
        if digits < 2:
            return False
        return True
    # compact 21-char MyMaccas style: mix of letters+digits
    if code.isalpha() or code.isdigit():
        return False
    if sum(ch.isdigit() for ch in code) < 3:
        return False
    if sum(ch.isalpha() for ch in code) < 5:
        return False
    return True

def extract_from_text(text, source, created_utc=None, url="", author="", claim_hint=False):
    now = time.time()
    text_u = text.upper()
    found = set(PAT_C.findall(text_u)) | set(PAT_W.findall(text_u))
    out = []
    for code in found:
        if not looks_like_code(code):
            continue
        age_m = None
        if created_utc:
            age_m = (now - created_utc) / 60.0
        claimed = claim_hint or bool(CLAIM.search(text))
        out.append({
            "code": code,
            "source": source,
            "url": url,
            "author": author,
            "created_utc": created_utc,
            "age_m": age_m,
            "claimed": claimed,
            "snippet": text.replace("\n", " ")[:160],
        })
    return out

# ---------- sources ----------
def src_arctic_thread():
    hits = []
    try:
        q = urlencode({"link_id": "1wik331", "limit": "100", "sort": "desc"})
        st, body = http_get(
            f"https://arctic-shift.photon-reddit.com/api/comments/search?{q}",
            accept="application/json",
        )
        data = json.loads(body)
        rows = data.get("data") or []
        # index replies for claim detection
        children = {}
        for c in rows:
            p = (c.get("parent_id") or "").replace("t1_", "").replace("t3_", "")
            children.setdefault(p, []).append(c)
        for c in rows:
            body_t = c.get("body") or ""
            replies = " ".join((r.get("body") or "") for r in children.get(c.get("id"), [])[:10])
            claim = bool(CLAIM.search(replies)) or bool(re.search(r"(edit:?\s*)?(claimed|taken)", body_t, re.I))
            url = f"https://www.reddit.com/r/australian/comments/1wik331/_/{c.get('id')}/"
            hits += extract_from_text(
                body_t, "arctic:r/australian/1wik331", c.get("created_utc"), url, c.get("author"), claim
            )
        open(f"{RAW}/poll_arctic_thread.json", "wb").write(body)
        return "arctic_thread", st, len(rows), hits
    except Exception as e:
        return "arctic_thread", 0, 0, [{"error": str(e)}]

def src_arctic_body(body_q, label):
    hits = []
    try:
        q = urlencode({"body": body_q, "limit": "50", "sort": "desc"})
        st, body = http_get(
            f"https://arctic-shift.photon-reddit.com/api/comments/search?{q}",
            accept="application/json",
        )
        data = json.loads(body)
        rows = data.get("data") or []
        for c in rows:
            body_t = c.get("body") or ""
            sub = c.get("subreddit") or "?"
            pid = (c.get("link_id") or "t3_x").replace("t3_", "")
            url = f"https://www.reddit.com/r/{sub}/comments/{pid}/_/{c.get('id')}/"
            hits += extract_from_text(
                body_t, f"arctic:body:{label}", c.get("created_utc"), url, c.get("author")
            )
        return f"arctic_body:{label}", st, len(rows), hits
    except Exception as e:
        return f"arctic_body:{label}", 0, 0, [{"error": str(e)}]

def src_arctic_sub(sub):
    hits = []
    try:
        q = urlencode({"subreddit": sub, "limit": "50", "sort": "desc"})
        st, body = http_get(
            f"https://arctic-shift.photon-reddit.com/api/comments/search?{q}",
            accept="application/json",
        )
        data = json.loads(body)
        rows = data.get("data") or []
        for c in rows:
            body_t = c.get("body") or ""
            if not (PAT_C.search(body_t.upper()) or PAT_W.search(body_t.upper())):
                continue
            pid = (c.get("link_id") or "t3_x").replace("t3_", "")
            url = f"https://www.reddit.com/r/{sub}/comments/{pid}/_/{c.get('id')}/"
            hits += extract_from_text(
                body_t, f"arctic:r/{sub}", c.get("created_utc"), url, c.get("author")
            )
        return f"arctic_sub:{sub}", st, len(rows), hits
    except Exception as e:
        return f"arctic_sub:{sub}", 0, 0, [{"error": str(e)}]

def src_html(url, label):
    hits = []
    try:
        st, body = http_get(url, accept="text/html")
        text = body.decode("utf-8", "ignore")
        open(f"{RAW}/poll_{hashlib.md5(label.encode()).hexdigest()[:8]}.html", "wb").write(body)
        # HTML rarely has reliable timestamps; mark age unknown -> not reportable as <10m
        # unless we can parse timeago / datetime
        ages = []
        # arctic/redlib data-timestamp or datetime=
        for m in re.finditer(r'data-timestamp="(\d+)"', text):
            ages.append(int(m.group(1)))
        for m in re.finditer(r'datetime="([^"]+)"', text):
            try:
                # ISO
                dt = datetime.fromisoformat(m.group(1).replace("Z", "+00:00"))
                ages.append(int(dt.timestamp()))
            except Exception:
                pass
        # extract codes without trusting age unless single recent timestamp nearby — conservative: age=None
        raw_hits = extract_from_text(text, label, None, url)
        # If page is login wall, skip
        if "Welcome to Reddit" in text and len(text) < 400000:
            # still might be wall
            if "thing id=" not in text and "comment" not in text.lower()[:2000]:
                return label, st, 0, []
        hits = raw_hits
        return label, st, len(hits), hits
    except Exception as e:
        return label, 0, 0, [{"error": str(e)}]

def src_ozbargain():
    return src_html("https://www.ozbargain.com.au/node/975129", "ozbargain:975129")

def src_icy():
    urls = [
        "https://www.icy-veins.com/wow-forever/news/players-are-earning-wow-forever-beta-codes-by-buying-australians-mcdonalds/",
        "https://www.icy-veins.com/wow-forever/news/wow-forever-beta-keys-are-now-a-mcdonalds-reward-in-australia/",
    ]
    allh = []
    last = ("icy", 0, 0, [])
    for u in urls:
        last = src_html(u, "icyveins")
        allh += [h for h in last[3] if "error" not in h]
    return "icyveins", last[1], len(allh), allh

def src_sentinel_list():
    # try listing / search snapshots
    urls = [
        "https://reddit.sentinel-team.org/",
        "https://reddit.sentinel-team.org/r/australian",
    ]
    hits = []
    st = 0
    for u in urls:
        try:
            st, body = http_get(u)
            text = body.decode("utf-8", "ignore")
            hits += extract_from_text(text, "sentinel", None, u)
        except Exception as e:
            hits.append({"error": str(e)})
    return "sentinel", st, len(hits), hits

SOURCES = []
# Build parallel job list
def jobs():
    j = [
        src_arctic_thread,
        src_ozbargain,
        src_icy,
        src_sentinel_list,
        lambda: src_arctic_body("MyMaccas", "MyMaccas"),
        lambda: src_arctic_body("free code", "freecode"),
        lambda: src_arctic_body("enjoy", "enjoy"),
        lambda: src_arctic_sub("australian"),
        lambda: src_arctic_sub("classicwow"),
        lambda: src_arctic_sub("wow"),
        lambda: src_arctic_sub("wowclassic"),
        lambda: src_html("https://libreddit.projectsegfau.lt/r/australian/comments/1wik331/?sort=new", "libreddit:segfau"),
        lambda: src_html("https://redlib.catsarch.com/r/australian/comments/1wik331/?sort=new", "redlib:catsarch"),
        lambda: src_html("https://l.opnxng.com/r/australian/comments/1wik331/?sort=new", "redlib:opnxng"),
        lambda: src_html("https://redlib.perennialte.ch/r/australian/comments/1wik331/?sort=new", "redlib:perennial"),
        lambda: src_html("https://old.reddit.com/r/australian/comments/1wik331/?sort=new", "oldreddit:thread"),
        lambda: src_html("https://old.reddit.com/r/classicwow/new/", "oldreddit:classicwow"),
        lambda: src_html("https://old.reddit.com/search/?q=MyMaccas+Forever+code&sort=new&t=day", "oldreddit:search"),
        lambda: src_html("https://www.reddit.com/r/australian/comments/1wik331.json?sort=new&limit=100", "redditjson"),
    ]
    return j

def poll_once(round_id, seen):
    now = time.time()
    results = []
    fresh = []
    with cf.ThreadPoolExecutor(max_workers=16) as ex:
        futs = [ex.submit(fn) for fn in jobs()]
        for fut in cf.as_completed(futs):
            try:
                label, st, n, hits = fut.result()
            except Exception as e:
                results.append({"label": "?", "error": str(e)})
                continue
            err = [h for h in hits if isinstance(h, dict) and "error" in h]
            code_hits = [h for h in hits if isinstance(h, dict) and "code" in h]
            results.append({"label": label, "http": st, "n": n, "codes": len(code_hits), "errors": len(err)})
            for h in code_hits:
                age = h.get("age_m")
                # ONLY report age < 10m with known timestamp
                if age is None:
                    continue
                if age >= 10:
                    continue
                if h.get("claimed"):
                    continue
                code = h["code"]
                if code in seen or code in KNOWN:
                    continue
                fresh.append(h)
    # dedup fresh by code keep newest
    best = {}
    for h in fresh:
        c = h["code"]
        if c not in best or (h.get("created_utc") or 0) > (best[c].get("created_utc") or 0):
            best[c] = h
    fresh = list(best.values())
    return results, fresh

def append_live(hits):
    lines = []
    ts = datetime.now(ET).strftime("%Y-%m-%d %H:%M:%S ET")
    for h in hits:
        age_i = max(0, int(h["age_m"]))
        line = f"{h['code']} | age: {age_i}m | {h['source']} | {h.get('url','')} | scraped {ts}"
        lines.append(line)
        print("FRESH", line, flush=True)
    if lines:
        with open(LIVE, "a") as f:
            f.write("\n".join(lines) + "\n")
    return lines

def main():
    seen = load_seen() | set(KNOWN)
    # also ingest any prior extract as seen (old)
    try:
        for x in json.load(open(f"{RAW}/arctic_codes_extract.json")):
            seen.add(x["code"])
    except Exception:
        pass
    try:
        for x in json.load(open(f"{RAW}/codes_full_ranked.json")).get("codes", []):
            seen.add(x["code"])
    except Exception:
        pass

    rounds = int(os.environ.get("POLL_ROUNDS", "8"))
    sleep_s = float(os.environ.get("POLL_SLEEP", "12"))
    summary = []
    all_fresh = []
    for i in range(rounds):
        t0 = time.time()
        results, fresh = poll_once(i, seen)
        for h in fresh:
            seen.add(h["code"])
        appended = append_live(fresh)
        all_fresh.extend(fresh)
        save_seen(seen)
        ok = sum(1 for r in results if r.get("http") in (200, 304))
        print(
            f"ROUND {i+1}/{rounds} ok_sources={ok}/{len(results)} fresh_lt10m={len(fresh)} took={time.time()-t0:.1f}s",
            flush=True,
        )
        for r in sorted(results, key=lambda x: x.get("label", "")):
            if r.get("codes") or r.get("errors") or r.get("http") not in (200, 0, None):
                print(f"  {r}", flush=True)
        summary.append({"round": i + 1, "fresh": len(fresh), "ok": ok, "n": len(results)})
        if i < rounds - 1:
            time.sleep(sleep_s)
    json.dump({"summary": summary, "fresh": all_fresh, "seen_n": len(seen)}, open(f"{RAW}/poll_summary.json", "w"), indent=2)
    print("DONE fresh_total", len(all_fresh), flush=True)

if __name__ == "__main__":
    main()
