#!/usr/bin/env python3
"""EVOLUTION 2 — WoW Forever MyMaccas beta key poller.

Fastest working source today: Arctic Shift comments JSON (~0.4–1.2s).
Reddit.com / old.reddit / most redlib mirrors: botwall/403.
Sentinel live page 404; one historical snapshot only (stale).
X/Twitter: must be browser (curl HTML is not a live feed).

Only FRESH codes (age <= FRESH_MAX_MIN) are appended to codes-live.txt
and printed. Older dumps are tracked in seen-set only (no re-report).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CODES_LIVE = ROOT / "codes-live.txt"
SEEN_FILE = ROOT / "seen-codes.txt"
METRICS = ROOT / "evolution-2-metrics.jsonl"
RAW = ROOT / "raw"
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
)

# MyMaccas / Battle.net style continuous 21-char keys observed in thread
PAT_21 = re.compile(r"(?<![A-Za-z0-9])([A-Za-z0-9]{21})(?![A-Za-z0-9])")
# Already-reported seed (do not re-report)
SEED_KNOWN = {
    "8WL8M6FFMLB9D3DBV4WF5",
    "SSW9D9L46PPDPSG93DFMP",
    "48WFWPCPDC5N4PFCK6NXL",
    "8HF9HS9D4H49JGBDM6K3B",
}

SOURCES = [
    {
        "id": "arctic_shift_newest",
        "url": "https://arctic-shift.photon-reddit.com/api/comments/search?link_id=1wik331&limit=50",
        "kind": "arctic_json",
        "note": "fastest working JSON; tip can lag Reddit live",
    },
    {
        "id": "sentinel_snapshot_hist",
        "url": "https://reddit.sentinel-team.org/posts/1wik331/snapshots/2026-09-18T04%3A43%3A27.967557Z",
        "kind": "html",
        "note": "historical only — not for fresh notice",
    },
]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_seen() -> set[str]:
    seen = set(SEED_KNOWN)
    if SEEN_FILE.exists():
        for line in SEEN_FILE.read_text().splitlines():
            line = line.strip().upper()
            if line and not line.startswith("#"):
                seen.add(line.split()[0])
    if CODES_LIVE.exists():
        for line in CODES_LIVE.read_text().splitlines():
            # format: ISO | CODE | age_min=N | source=... | ...
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 2:
                seen.add(parts[1].strip().upper())
    return seen


def save_seen(seen: set[str]) -> None:
    SEEN_FILE.write_text(
        "# dedupe set — one code per line\n" + "\n".join(sorted(seen)) + "\n"
    )


def plausible(code: str) -> bool:
    c = code.upper()
    if len(c) != 21:
        return False
    if not re.search(r"[A-Z]", c) or not re.search(r"[0-9]", c):
        return False
    if sum(ch.isdigit() for ch in c) < 3:
        return False
    # reject obvious JS/HTML noise
    noise = ("ERROR", "MESSAGE", "EXPERIMENT", "CALLBACK", "PERFORMANCE", "MEASURE")
    if any(n in c for n in noise):
        return False
    return True


def http_get(url: str, timeout: float = 20.0) -> tuple[int, bytes, float]:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Accept": "application/json,text/html,*/*",
        },
    )
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
            ms = (time.perf_counter() - t0) * 1000
            return resp.status, body, ms
    except urllib.error.HTTPError as e:
        ms = (time.perf_counter() - t0) * 1000
        return e.code, e.read() if e.fp else b"", ms
    except Exception as e:
        ms = (time.perf_counter() - t0) * 1000
        return 0, str(e).encode(), ms


def extract_arctic(payload: bytes) -> list[dict]:
    """Return list of {code, created_utc, author, source_id}."""
    out: list[dict] = []
    try:
        data = json.loads(payload.decode("utf-8", errors="replace"))
    except json.JSONDecodeError:
        return out
    comments = data.get("data") or []
    for c in comments:
        body = c.get("body") or ""
        created = c.get("created_utc")
        author = c.get("author") or "?"
        for m in PAT_21.findall(body):
            code = m.upper()
            if not plausible(code):
                continue
            if code not in body.upper():
                continue
            out.append(
                {
                    "code": code,
                    "created_utc": created,
                    "author": author,
                    "source_id": "arctic_shift_newest",
                }
            )
    return out


def extract_html(payload: bytes, source_id: str) -> list[dict]:
    text = payload.decode("utf-8", errors="replace")
    out: list[dict] = []
    for m in PAT_21.findall(text):
        code = m.upper()
        if plausible(code):
            out.append(
                {
                    "code": code,
                    "created_utc": None,  # unknown from static HTML
                    "author": "?",
                    "source_id": source_id,
                }
            )
    return out


def append_metric(obj: dict) -> None:
    with METRICS.open("a") as f:
        f.write(json.dumps(obj) + "\n")


def append_live(code: str, age_min: float | None, source: str, author: str) -> None:
    age_s = f"{age_min:.1f}" if age_min is not None else "unknown"
    line = (
        f"{now_iso()} | {code} | age_min={age_s} | source={source} | author={author}\n"
    )
    with CODES_LIVE.open("a") as f:
        f.write(line)


def poll_once(
    seen: set[str],
    fresh_max_min: float,
    include_hist: bool,
) -> tuple[list[dict], list[dict]]:
    """Returns (fresh_new, all_hits_meta)."""
    fresh_new: list[dict] = []
    now = time.time()

    for src in SOURCES:
        if src["kind"] == "html" and not include_hist:
            # skip stale sentinel unless asked
            continue
        status, body, ms = http_get(src["url"])
        hits: list[dict] = []
        tip_comment_age = None
        if status == 200 and src["kind"] == "arctic_json":
            hits = extract_arctic(body)
            RAW.mkdir(exist_ok=True)
            (RAW / "arctic_live_latest.json").write_bytes(body)
            try:
                import json as _json
                _comments = (_json.loads(body.decode("utf-8", errors="replace")).get("data") or [])
                if _comments:
                    tip_comment_age = (now - max(c["created_utc"] for c in _comments)) / 60.0
            except Exception:
                tip_comment_age = None
        elif status == 200 and src["kind"] == "html":
            hits = extract_html(body, src["id"])

        newest_age = tip_comment_age
        ages = [
            (now - h["created_utc"]) / 60.0
            for h in hits
            if h.get("created_utc")
        ]
        if ages:
            # prefer youngest CODE age if any, else tip comment age
            newest_age = min(ages)

        append_metric(
            {
                "ts": now_iso(),
                "source": src["id"],
                "http_status": status,
                "latency_ms": round(ms, 1),
                "hits": len(hits),
                "newest_comment_age_min": round(newest_age, 1) if newest_age is not None else None,
                "note": src.get("note"),
            }
        )
        print(
            f"  [{src['id']}] http={status} {ms:.0f}ms hits={len(hits)} "
            f"tip_age_min={newest_age:.0f}" if newest_age is not None else
            f"  [{src['id']}] http={status} {ms:.0f}ms hits={len(hits)} tip_age_min=n/a"
        )

        for h in hits:
            code = h["code"]
            created = h.get("created_utc")
            age_min = (now - created) / 60.0 if created else None
            is_fresh = age_min is not None and age_min <= fresh_max_min
            if code in seen:
                continue
            # Always remember so we don't spam later; only REPORT if fresh
            seen.add(code)
            if is_fresh:
                append_live(code, age_min, h["source_id"], h.get("author") or "?")
                fresh_new.append({**h, "age_min": age_min})
                print(
                    f"  *** FRESH {code} age_min={age_min:.1f} "
                    f"src={h['source_id']} u/{h.get('author')}"
                )
            else:
                # silently absorb into seen — do not dump old keys
                pass

    save_seen(seen)
    return fresh_new, []


def main() -> int:
    ap = argparse.ArgumentParser(description="Evo2 fresh-key poller")
    ap.add_argument("--cycles", type=int, default=5)
    ap.add_argument("--interval", type=float, default=8.0, help="seconds between polls")
    ap.add_argument(
        "--fresh-max-min",
        type=float,
        default=30.0,
        help="only report codes posted within this many minutes",
    )
    ap.add_argument(
        "--include-hist",
        action="store_true",
        help="also hit sentinel historical snapshot (not for fresh)",
    )
    args = ap.parse_args()

    RAW.mkdir(exist_ok=True)
    if not CODES_LIVE.exists():
        CODES_LIVE.write_text(
            "# FRESH codes only — ISO | CODE | age_min= | source= | author=\n"
        )

    seen = load_seen()
    print(f"=== EVOLUTION 2 POLLER start {now_iso()} ===")
    print(f"seen={len(seen)} fresh_max_min={args.fresh_max_min} cycles={args.cycles}")
    print(
        "NOTE: X/Twitter requires browser watcher — not polled here. "
        "Reddit.com blocked; Arctic Shift is primary."
    )

    all_fresh: list[dict] = []
    for i in range(args.cycles):
        print(f"-- cycle {i+1}/{args.cycles} --")
        fresh, _ = poll_once(seen, args.fresh_max_min, args.include_hist)
        all_fresh.extend(fresh)
        # adaptive backoff if last metric was 429
        sleep_s = args.interval
        try:
            last = METRICS.read_text().strip().splitlines()[-1]
            if '"http_status": 429' in last:
                sleep_s = max(args.interval, 20.0)
                print(f"  backoff -> {sleep_s}s after 429")
        except Exception:
            pass
        if i + 1 < args.cycles:
            time.sleep(sleep_s)

    print(f"=== DONE fresh_new_total={len(all_fresh)} ===")
    if all_fresh:
        print("FRESH CODES:")
        for h in all_fresh:
            print(
                f"  {h['code']}  age_min={h['age_min']:.1f}  "
                f"src={h['source_id']}  u/{h.get('author')}"
            )
    else:
        print(
            "NO FRESH CODES this run "
            f"(nothing with age <= {args.fresh_max_min} min)."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
