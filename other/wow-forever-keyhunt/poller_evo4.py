#!/usr/bin/env python3
"""EVOLUTION 4 — WoW Forever beta key hunt (age-gated, parallel mirrors).

User feedback: stop wasting time on old single-use codes that already have
views; always attach AGE to every code.

- Parallel poll of ALL configured no-login mirrors each cycle (~30–60s)
- For each code: store first_seen, source_post_time, age_at_report
- ONLY alert codes with age < max_age_min (default 10). Older = ignored as taken.
- Hit format: CODE | age: Xm | source: URL | first_seen: ISO
- No paid X API.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
STATE_DIR = ROOT / "state"
RAW_DIR = ROOT / "raw" / "e4"
CODES_DB = STATE_DIR / "codes_db.json"
ALERTS_FILE = ROOT / "codes-live-e4.txt"
METRICS = ROOT / "evolution-4-metrics.jsonl"
SEEN_LEGACY = ROOT / "seen-codes.txt"
CONFIG_FILE = ROOT / "evo4-config.json"
ARCTIC_SEED = ROOT / "raw" / "arctic_codes_extract.json"

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
)

THREAD_ID = "1wik331"
THREAD_PATH = (
    "r/australian/comments/1wik331/maccas_wow_forever_beta_key_mega_thread"
)

PAT_21 = re.compile(r"(?<![A-Za-z0-9])([A-Za-z0-9]{21})(?![A-Za-z0-9])")
PAT_HYPHEN = re.compile(
    r"(?<![A-Za-z0-9])([A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}"
    r"(?:-[A-Z0-9]{4,5})?)(?![A-Za-z0-9])"
)
def format_key(raw: str) -> str:
    """Normalize to F8MC-855P-BJGTJ-TQP6-4BX6 style (4-4-5-4-4)."""
    s = raw.strip().upper().replace(' ', '')
    if '-' in s:
        parts = s.split('-')
        if len(parts) == 5 and [len(x) for x in parts] == [4, 4, 5, 4, 4]:
            return '-'.join(parts)
    body = s.replace('-', '')
    if len(body) == 21 and body.isalnum():
        return f"{body[0:4]}-{body[4:8]}-{body[8:13]}-{body[13:17]}-{body[17:21]}"
    return s


NOISE = (
    "ERROR", "MESSAGE", "EXPERIMENT", "CALLBACK", "PERFORMANCE", "MEASURE",
    "INNERHTML", "OPENGRAPH", "REQUESTIDLE", "DANGEROUSLY", "CATEGORY",
    "EXTRACT", "ISEXPERIMENT", "ASSETMETRICS", "OBSERVER",
)

DEFAULT_SOURCES: list[dict[str, Any]] = [
    {
        "id": "arctic_shift",
        "url": (
            "https://arctic-shift.photon-reddit.com/api/comments/search"
            f"?link_id=t3_{THREAD_ID}&limit=100&sort=desc"
        ),
        "kind": "arctic_json",
        "priority": 1,
    },
    {
        "id": "arctic_shift_alt",
        "url": (
            "https://arctic-shift.photon-reddit.com/api/comments/search"
            f"?link_id={THREAD_ID}&limit=50&sort=desc"
        ),
        "kind": "arctic_json",
        "priority": 2,
    },
    {
        "id": "pullpush",
        "url": (
            "https://api.pullpush.io/reddit/search/comment/"
            f"?link_id=t3_{THREAD_ID}&size=50&sort=desc"
        ),
        "kind": "pullpush_json",
        "priority": 3,
    },
    {
        "id": "oldreddit_json",
        "url": f"https://old.reddit.com/{THREAD_PATH}.json?limit=100&sort=new",
        "kind": "reddit_listing_json",
        "priority": 4,
    },
    {
        "id": "oldreddit_short_json",
        "url": (
            f"https://old.reddit.com/r/australian/comments/{THREAD_ID}.json"
            "?limit=100&sort=new"
        ),
        "kind": "reddit_listing_json",
        "priority": 5,
    },
    {
        "id": "redlib_privacyredirect",
        "url": f"https://redlib.privacyredirect.com/{THREAD_PATH}",
        "kind": "html",
        "priority": 6,
    },
    {
        "id": "libreddit_projectsegfau",
        "url": f"https://libreddit.projectsegfau.lt/{THREAD_PATH}",
        "kind": "html",
        "priority": 7,
    },
    {
        "id": "icyveins_maccas",
        "url": (
            "https://www.icy-veins.com/wow-forever/news/"
            "players-are-earning-wow-forever-beta-codes-by-buying-australians-mcdonalds/"
        ),
        "kind": "html",
        "priority": 8,
    },
    {
        "id": "blizzard_wow_news",
        "url": "https://news.blizzard.com/en-us/world-of-warcraft",
        "kind": "html",
        "priority": 9,
    },
    {
        "id": "ozbargain_front",
        "url": "https://www.ozbargain.com.au/",
        "kind": "html",
        "priority": 10,
    },
]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_config() -> dict[str, Any]:
    cfg: dict[str, Any] = {
        "max_age_min": 10.0,
        "interval_sec": 40.0,
        "sources": DEFAULT_SOURCES,
    }
    if CONFIG_FILE.exists():
        try:
            user = json.loads(CONFIG_FILE.read_text())
            for k, v in user.items():
                if k != "sources":
                    cfg[k] = v
            if isinstance(user.get("sources"), list) and user["sources"]:
                cfg["sources"] = user["sources"]
        except Exception:
            pass
    return cfg


def plausible(code: str) -> bool:
    c = code.upper()
    if "-" in c:
        parts = c.split("-")
        if not (4 <= len(parts) <= 5):
            return False
        if not re.search(r"[A-Z]", c) or not re.search(r"[0-9]", c):
            return False
        if any(p in ("XXXX", "YYYY", "ZZZZ", "0000", "TEST", "DEAD", "BEEF") for p in parts):
            return False
        return True
    if len(c) != 21:
        return False
    if not re.search(r"[A-Z]", c) or not re.search(r"[0-9]", c):
        return False
    if sum(ch.isdigit() for ch in c) < 3:
        return False
    if any(n in c for n in NOISE):
        return False
    return True


def extract_codes(text: str) -> list[str]:
    found: list[str] = []
    for m in PAT_21.findall(text):
        c = m.upper()
        if plausible(c):
            found.append(c)
    for m in PAT_HYPHEN.findall(text.upper()):
        if plausible(m):
            found.append(m)
    out: list[str] = []
    seen: set[str] = set()
    for c in found:
        if c not in seen:
            seen.add(c)
            out.append(c)
    return out


def http_get(url: str, timeout: float = 18.0) -> tuple[int, bytes, float]:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Accept": "application/json,text/html;q=0.9,*/*;q=0.8",
        },
    )
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
            return int(resp.status), body, (time.perf_counter() - t0) * 1000
    except urllib.error.HTTPError as e:
        try:
            body = e.read() if e.fp else b""
        except Exception:
            body = b""
        return int(e.code), body, (time.perf_counter() - t0) * 1000
    except Exception as e:
        return 0, str(e).encode(), (time.perf_counter() - t0) * 1000


def _hits_from_comment_dicts(
    comments: list[Any], source_id: str, source_url: str
) -> tuple[list[dict], float | None]:
    out: list[dict] = []
    tip: float | None = None
    for c in comments:
        if not isinstance(c, dict):
            continue
        created = c.get("created_utc") or c.get("created")
        if created is not None:
            created_f = float(created)
            tip = created_f if tip is None else max(tip, created_f)
        else:
            created_f = None
        body = c.get("body") or ""
        author = c.get("author") or "?"
        cid = c.get("id") or ""
        permalink = c.get("permalink") or ""
        for code in extract_codes(body):
            out.append(
                {
                    "code": code,
                    "source_post_time": created_f,
                    "author": author,
                    "comment_id": cid,
                    "source_id": source_id,
                    "source_url": (
                        f"https://www.reddit.com{permalink}" if permalink else source_url
                    ),
                }
            )
    return out, tip


def parse_arctic_or_pullpush(
    payload: bytes, source_id: str, source_url: str
) -> tuple[list[dict], float | None, bool]:
    try:
        data = json.loads(payload.decode("utf-8", errors="replace"))
    except json.JSONDecodeError:
        return [], None, False
    if isinstance(data, dict) and (data.get("error") or data.get("message")):
        return [], None, False
    comments = data.get("data") if isinstance(data, dict) else data
    if not isinstance(comments, list):
        return [], None, False
    hits, tip = _hits_from_comment_dicts(comments, source_id, source_url)
    return hits, tip, True


def parse_reddit_listing(
    payload: bytes, source_id: str, source_url: str
) -> tuple[list[dict], float | None, bool]:
    text = payload.decode("utf-8", errors="replace")
    if text.lstrip().startswith("<") or "Welcome to Reddit" in text[:800]:
        return [], None, False
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return [], None, False

    out: list[dict] = []
    tip: float | None = None

    def walk(node: Any) -> None:
        nonlocal tip
        if isinstance(node, dict):
            kind = node.get("kind")
            d = node.get("data") if kind else node
            if isinstance(d, dict) and "body" in d and "created_utc" in d:
                created = d.get("created_utc")
                created_f = float(created) if created is not None else None
                if created_f is not None:
                    tip = created_f if tip is None else max(tip, created_f)
                body = d.get("body") or ""
                author = d.get("author") or "?"
                cid = d.get("id") or ""
                permalink = d.get("permalink") or ""
                for code in extract_codes(body):
                    out.append(
                        {
                            "code": code,
                            "source_post_time": created_f,
                            "author": author,
                            "comment_id": cid,
                            "source_id": source_id,
                            "source_url": (
                                f"https://www.reddit.com{permalink}"
                                if permalink
                                else source_url
                            ),
                        }
                    )
                replies = d.get("replies")
                if isinstance(replies, dict):
                    walk(replies)
            children = d.get("children") if isinstance(d, dict) else None
            if isinstance(children, list):
                for ch in children:
                    walk(ch)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    if isinstance(data, list) and len(data) >= 2:
        walk(data[1])
    else:
        walk(data)
    alive = tip is not None or bool(out) or (
        isinstance(data, list) and len(data) >= 1
    )
    return out, tip, alive


def parse_html(
    payload: bytes, source_id: str, source_url: str
) -> tuple[list[dict], float | None, bool]:
    text = payload.decode("utf-8", errors="replace")
    head = text[:900].lower()
    if any(
        x in head
        for x in (
            "making sure you're not a bot",
            "just a moment",
            "verifying your browser",
            "cf-browser-verification",
            "enable javascript and cookies",
        )
    ):
        return [], None, False
    out: list[dict] = []
    for code in extract_codes(text):
        # HTML without reliable post timestamps → age unknown → cannot alert
        out.append(
            {
                "code": code,
                "source_post_time": None,
                "author": "?",
                "comment_id": "",
                "source_id": source_id,
                "source_url": source_url,
            }
        )
    return out, None, True


def fetch_one(src: dict[str, Any]) -> dict[str, Any]:
    status, body, ms = http_get(src["url"])
    hits: list[dict] = []
    tip: float | None = None
    alive = False
    note = ""

    if status == 200 and len(body) > 40:
        kind = src["kind"]
        if kind in ("arctic_json", "pullpush_json"):
            hits, tip, alive = parse_arctic_or_pullpush(body, src["id"], src["url"])
            if not alive:
                note = "error_or_empty_json"
        elif kind == "reddit_listing_json":
            hits, tip, alive = parse_reddit_listing(body, src["id"], src["url"])
            if not alive:
                note = "html_login_wall_or_empty"
        else:
            hits, tip, alive = parse_html(body, src["id"], src["url"])
            if not alive:
                note = "bot_wall"
        if src["id"] == "arctic_shift" and alive:
            RAW_DIR.mkdir(parents=True, exist_ok=True)
            (RAW_DIR / "arctic_latest.json").write_bytes(body)
    elif status == 429:
        note = "rate_limited"
    elif status in (403, 451):
        note = "blocked"
    elif status == 0:
        note = "network_error"
    else:
        note = f"http_{status}"

    return {
        "source_id": src["id"],
        "url": src["url"],
        "http_status": status,
        "latency_ms": round(ms, 1),
        "alive": alive,
        "hits": hits,
        "tip_created_utc": tip,
        "note": note,
        "bytes": len(body),
    }


def load_db() -> dict[str, dict]:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if CODES_DB.exists():
        try:
            return json.loads(CODES_DB.read_text())
        except Exception:
            return {}
    return {}


def save_db(db: dict[str, dict]) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    CODES_DB.write_text(json.dumps(db, indent=2, sort_keys=True) + "\n")


def seed_db(db: dict[str, dict]) -> dict[str, dict]:
    if SEEN_LEGACY.exists():
        for line in SEEN_LEGACY.read_text().splitlines():
            line = line.strip().upper()
            if not line or line.startswith("#"):
                continue
            code = line.split()[0]
            if code not in db and plausible(code):
                db[code] = {
                    "code": code,
                    "first_seen": now_iso(),
                    "source_post_time": None,
                    "source_post_time_iso": None,
                    "age_at_report": None,
                    "source_url": "legacy_seed",
                    "source_id": "legacy",
                    "alerted": False,
                    "ignored_as_old": True,
                }
    if ARCTIC_SEED.exists():
        try:
            for row in json.loads(ARCTIC_SEED.read_text()):
                code = (row.get("code") or "").upper()
                if not code or not plausible(code):
                    continue
                created = row.get("created_utc")
                if code in db:
                    continue
                db[code] = {
                    "code": code,
                    "first_seen": now_iso(),
                    "source_post_time": created,
                    "source_post_time_iso": (
                        datetime.fromtimestamp(created, tz=timezone.utc).isoformat()
                        if created
                        else None
                    ),
                    "age_at_report": None,
                    "source_url": (
                        f"https://www.reddit.com/r/australian/comments/"
                        f"{THREAD_ID}/_/{row.get('comment_id', '')}/"
                    ),
                    "source_id": "arctic_seed",
                    "alerted": False,
                    "ignored_as_old": True,
                }
        except Exception:
            pass
    return db


def format_alert(code: str, age_min: float, source_url: str, first_seen: str) -> str:
    if age_min < 1:
        age_s = f"{age_min:.1f}m"
    else:
        age_s = f"{int(age_min)}m"
    return f"{format_key(code)} | age: {age_s} | source: {source_url} | first_seen: {first_seen}"


def append_metric(obj: dict) -> None:
    with METRICS.open("a") as f:
        f.write(json.dumps(obj) + "\n")


def poll_cycle(
    sources: list[dict[str, Any]],
    db: dict[str, dict],
    max_age_min: float,
) -> dict[str, Any]:
    t0 = time.perf_counter()
    results: list[dict] = []
    with ThreadPoolExecutor(max_workers=min(12, max(4, len(sources)))) as ex:
        futs = {ex.submit(fetch_one, s): s["id"] for s in sources}
        for fut in as_completed(futs):
            try:
                results.append(fut.result())
            except Exception as e:
                results.append(
                    {
                        "source_id": futs[fut],
                        "url": "",
                        "http_status": 0,
                        "latency_ms": 0.0,
                        "alive": False,
                        "hits": [],
                        "tip_created_utc": None,
                        "note": f"exception:{e}",
                        "bytes": 0,
                    }
                )
    wall_ms = (time.perf_counter() - t0) * 1000
    now = time.time()
    alerts: list[str] = []
    ignored_old = 0
    new_tracked = 0

    id_priority = {s["id"]: s.get("priority", 99) for s in sources}
    results.sort(key=lambda r: id_priority.get(r["source_id"], 99))

    seen_cycle: set[str] = set()
    for r in results:
        for h in r["hits"]:
            code = h["code"]
            if code in seen_cycle:
                continue
            seen_cycle.add(code)
            post_ts = h.get("source_post_time")
            age_min = (now - post_ts) / 60.0 if post_ts else None
            entry = db.get(code)
            if entry is None:
                entry = {
                    "code": code,
                    "first_seen": now_iso(),
                    "source_post_time": post_ts,
                    "source_post_time_iso": (
                        datetime.fromtimestamp(post_ts, tz=timezone.utc).isoformat()
                        if post_ts
                        else None
                    ),
                    "age_at_report": None,
                    "source_url": h.get("source_url") or r["url"],
                    "source_id": h.get("source_id") or r["source_id"],
                    "author": h.get("author"),
                    "comment_id": h.get("comment_id"),
                    "alerted": False,
                    "ignored_as_old": False,
                }
                db[code] = entry
                new_tracked += 1
            else:
                if entry.get("source_post_time") is None and post_ts is not None:
                    entry["source_post_time"] = post_ts
                    entry["source_post_time_iso"] = datetime.fromtimestamp(
                        post_ts, tz=timezone.utc
                    ).isoformat()
                    age_min = (now - post_ts) / 60.0

            if age_min is None or age_min >= max_age_min:
                entry["ignored_as_old"] = True
                ignored_old += 1
                continue

            if not entry.get("alerted"):
                entry["age_at_report"] = round(age_min, 2)
                entry["alerted"] = True
                entry["ignored_as_old"] = False
                line = format_alert(
                    code, age_min, entry["source_url"], entry["first_seen"]
                )
                alerts.append(line)
                with ALERTS_FILE.open("a") as f:
                    f.write(line + "\n")
                print(f"  *** ALERT {line}")

    alive = [r for r in results if r["alive"]]
    dead = [r for r in results if not r["alive"]]
    latencies = [r["latency_ms"] for r in results]
    tip_ages = [
        (now - r["tip_created_utc"]) / 60.0
        for r in results
        if r.get("tip_created_utc")
    ]

    summary = {
        "ts": now_iso(),
        "wall_ms": round(wall_ms, 1),
        "max_age_min": max_age_min,
        "sources_total": len(results),
        "sources_alive": len(alive),
        "sources_alive_ids": [r["source_id"] for r in alive],
        "sources_dead": [
            {"id": r["source_id"], "http": r["http_status"], "note": r["note"]}
            for r in dead
        ],
        "latency_ms_min": round(min(latencies), 1) if latencies else None,
        "latency_ms_max": round(max(latencies), 1) if latencies else None,
        "latency_ms_avg": round(sum(latencies) / len(latencies), 1) if latencies else None,
        "tip_age_min": round(min(tip_ages), 1) if tip_ages else None,
        "codes_seen_cycle": len(seen_cycle),
        "new_tracked": new_tracked,
        "ignored_old": ignored_old,
        "alerts": len(alerts),
        "per_source": [
            {
                "id": r["source_id"],
                "http": r["http_status"],
                "ms": r["latency_ms"],
                "alive": r["alive"],
                "hits": len(r["hits"]),
                "note": r["note"],
            }
            for r in sorted(results, key=lambda x: x["source_id"])
        ],
    }
    append_metric(summary)
    save_db(db)

    print(
        f"  wall={wall_ms:.0f}ms alive={len(alive)}/{len(results)} "
        f"lat={summary['latency_ms_min']}-{summary['latency_ms_max']}ms "
        f"tip_age_min={summary['tip_age_min']} "
        f"codes={len(seen_cycle)} ignored_old={ignored_old} alerts={len(alerts)}"
    )
    for r in sorted(results, key=lambda x: x["source_id"]):
        flag = "ALIVE" if r["alive"] else "dead "
        print(
            f"    [{flag}] {r['source_id']:28s} http={r['http_status']:3} "
            f"{r['latency_ms']:7.0f}ms hits={len(r['hits']):3} {r['note']}"
        )
    return summary


def main() -> int:
    ap = argparse.ArgumentParser(description="Evo4 age-gated parallel key poller")
    ap.add_argument("--cycles", type=int, default=5)
    ap.add_argument("--interval", type=float, default=None)
    ap.add_argument("--max-age-min", type=float, default=None)
    ap.add_argument("--continuous", action="store_true")
    args = ap.parse_args()

    cfg = load_config()
    max_age = (
        args.max_age_min if args.max_age_min is not None else float(cfg["max_age_min"])
    )
    interval = (
        args.interval if args.interval is not None else float(cfg["interval_sec"])
    )
    sources = cfg["sources"]

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if not ALERTS_FILE.exists():
        ALERTS_FILE.write_text(
            "# Evo4 alerts — CODE | age: Xm | source: URL | first_seen: ISO\n"
        )
    if not CONFIG_FILE.exists():
        CONFIG_FILE.write_text(
            json.dumps(
                {
                    "max_age_min": 10.0,
                    "interval_sec": 40.0,
                    "note": "No paid X API. Parallel no-login mirrors only.",
                },
                indent=2,
            )
            + "\n"
        )

    db = seed_db(load_db())
    save_db(db)

    print(f"=== EVOLUTION 4 POLLER start {now_iso()} ===")
    print(
        f"max_age_min={max_age} interval={interval}s sources={len(sources)} "
        f"db_codes={len(db)} (PARALLEL fetch)"
    )
    print("NO paid X API. Age on every alert. Older than gate = ignored.")

    cycle = 0
    last_success: dict[str, str] = {}
    try:
        while True:
            cycle += 1
            if not args.continuous and cycle > args.cycles:
                break
            label = f"{cycle}" if args.continuous else f"{cycle}/{args.cycles}"
            print(f"-- cycle {label} --")
            summary = poll_cycle(sources, db, max_age)
            for ps in summary["per_source"]:
                if ps["alive"]:
                    last_success[ps["id"]] = summary["ts"]
            if not args.continuous and cycle >= args.cycles:
                break
            sleep_s = interval
            arctic_http = [
                ps["http"]
                for ps in summary["per_source"]
                if ps["id"].startswith("arctic")
            ]
            if arctic_http and all(s == 429 for s in arctic_http):
                sleep_s = max(interval, 60.0)
                print(f"  arctic 429 backoff -> {sleep_s}s")
            time.sleep(sleep_s)
    except KeyboardInterrupt:
        print("interrupted")

    print(f"=== EVO4 DONE cycles={cycle} ===")
    alert_lines = [
        ln
        for ln in ALERTS_FILE.read_text().splitlines()
        if ln.strip() and not ln.startswith("#")
    ]
    if alert_lines:
        print("FRESH ALERTS (age < gate):")
        for ln in alert_lines:
            print(f"  {ln}")
    else:
        print(f"NO FRESH CODES (nothing with age < {max_age} min).")
        print("Last successful poll times (alive sources):")
        if last_success:
            for sid, ts in sorted(last_success.items()):
                print(f"  {sid}: {ts}")
        else:
            print("  (none alive this run)")
        try:
            last = json.loads(METRICS.read_text().strip().splitlines()[-1])
            print(
                f"Index tip_age_min={last.get('tip_age_min')} "
                "(comments older than gate ignored as taken)"
            )
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
