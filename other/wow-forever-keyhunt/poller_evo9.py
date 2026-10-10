#!/usr/bin/env python3
"""EVOLUTION 9 — dual-cadence Arctic poller (evo7 race winner: arctic_comments_*).

HOT (~7s): comments/search by subreddit for wow, classicwow, wowclassic in parallel.
  Uses after=<unix> watermark (Arctic Date filter) + client-side id cursor so each
  poll only considers newer comments. Emits alerts as each future completes
  (as_completed), not after a full barrier.

COLD (~30s): posts/search sort=desc for the same subs as a backstop.

Keys: format_key → 4-4-5-4-4; age < 10m; skip CVK5-F4DM-NBGJB-FF6H-LWQW and *XXXX*.
Alerts → codes-live-e9.txt; metrics → evolution-9-metrics.jsonl.
Free only (Arctic Shift).
"""
from __future__ import annotations

import argparse
import json
import re
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
ALERTS_FILE = ROOT / "codes-live-e9.txt"
METRICS_FILE = ROOT / "evolution-9-metrics.jsonl"
STATE_FILE = ROOT / "state" / "e9_state.json"

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
)
ARCTIC = "https://arctic-shift.photon-reddit.com/api"
# Evo7 hunt winner path: comments by sub; evo9 hot set (per spec)
HOT_SUBS = ("wow", "classicwow", "wowclassic")
COLD_SUBS = ("wow", "classicwow", "wowclassic")

HOT_INTERVAL = 7.0
COLD_INTERVAL = 30.0
MAX_AGE_MIN = 10.0
LIMIT = 50

PAT_HYPHEN = re.compile(
    r"(?<![A-Za-z0-9])([A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{5}-[A-Z0-9]{4}-[A-Z0-9]{4})(?![A-Za-z0-9])",
    re.IGNORECASE,
)
PAT_21 = re.compile(r"(?<![A-Za-z0-9])([A-Za-z0-9]{21})(?![A-Za-z0-9])")

KNOWN_SKIP = {
    "CVK5-F4DM-NBGJB-FF6H-LWQW",
    "CVK5F4DMNBGJBFF6HLWQW",
}

NOISE = (
    "ERROR", "MESSAGE", "EXPERIMENT", "CALLBACK", "PERFORMANCE", "MEASURE",
    "INNERHTML", "OPENGRAPH", "REQUESTIDLE", "DANGEROUSLY", "CATEGORY",
    "EXTRACT", "ISEXPERIMENT", "ASSETMETRICS", "OBSERVER", "AAAAAAAA",
    "PLACEHOLDER", "EXAMPLECODE", "YOURCODEHERE",
)

_lock = threading.Lock()


def format_key(raw: str) -> str:
    """Normalize to F8MC-855P-BJGTJ-TQP6-4BX6 style (4-4-5-4-4)."""
    s = raw.strip().upper().replace(" ", "")
    if "-" in s:
        parts = s.split("-")
        if len(parts) == 5 and [len(x) for x in parts] == [4, 4, 5, 4, 4]:
            return "-".join(parts)
    body = s.replace("-", "")
    if len(body) == 21 and body.isalnum():
        return (
            f"{body[0:4]}-{body[4:8]}-{body[8:13]}-"
            f"{body[13:17]}-{body[17:21]}"
        )
    return s


def continuous(code: str) -> str:
    return code.upper().replace("-", "").replace(" ", "")


def is_xxxx(code: str) -> bool:
    return "XXXX" in code.upper() or code.upper().endswith("-PXXX")


def plausible(raw: str) -> bool:
    body = continuous(raw)
    if len(body) != 21 or not body.isalnum():
        return False
    if body in {continuous(k) for k in KNOWN_SKIP}:
        return False
    if is_xxxx(format_key(raw)):
        return False
    if not re.search(r"[A-Z]", body) or not re.search(r"[0-9]", body):
        return False
    if sum(ch.isdigit() for ch in body) < 3:
        return False
    if sum(ch.isalpha() for ch in body) < 5:
        return False
    if any(n in body for n in NOISE):
        return False
    if re.search(r"(.)\1{5,}", body):
        return False
    if body.count("A") >= 8:
        return False
    return True


def extract_codes(text: str) -> list[str]:
    if not text:
        return []
    found: list[str] = []
    seen_local: set[str] = set()
    for m in PAT_HYPHEN.findall(text.upper()):
        nk = format_key(m)
        if plausible(nk) and nk not in seen_local and not is_xxxx(nk):
            seen_local.add(nk)
            found.append(nk)
    for m in PAT_21.findall(text.upper()):
        nk = format_key(m)
        if plausible(nk) and nk not in seen_local and not is_xxxx(nk):
            seen_local.add(nk)
            found.append(nk)
    return found


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def http_get_json(url: str, timeout: float = 15.0) -> tuple[int | None, Any, float, str | None]:
    t0 = time.perf_counter()
    req = urllib.request.Request(
        url, headers={"User-Agent": UA, "Accept": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
            ms = (time.perf_counter() - t0) * 1000.0
            return resp.status, json.loads(body), ms, None
    except urllib.error.HTTPError as e:
        ms = (time.perf_counter() - t0) * 1000.0
        return e.code, None, ms, f"HTTP {e.code}"
    except Exception as e:
        ms = (time.perf_counter() - t0) * 1000.0
        return None, None, ms, str(e)[:160]


def load_state() -> dict[str, Any]:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    seen: set[str] = {continuous(k) for k in KNOWN_SKIP}
    after_by: dict[str, int] = {}
    seen_ids: dict[str, list[str]] = {}
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text())
            seen |= {continuous(x) for x in data.get("seen", [])}
            after_by = {k: int(v) for k, v in (data.get("after_by") or {}).items()}
            seen_ids = {k: list(v) for k, v in (data.get("seen_ids") or {}).items()}
        except Exception:
            pass
    for path in (
        ALERTS_FILE,
        ROOT / "codes-live.txt",
        ROOT / "codes-live-e4.txt",
        ROOT / "codes-live-e7.txt",
        ROOT / "codes-live-e8.txt",
        ROOT / "seen-codes.txt",
    ):
        if not path.exists():
            continue
        try:
            txt = path.read_text(errors="ignore").upper()
            for m in PAT_HYPHEN.findall(txt):
                seen.add(continuous(m))
            for m in PAT_21.findall(txt):
                seen.add(continuous(m))
        except Exception:
            pass
    return {"seen": seen, "after_by": after_by, "seen_ids": seen_ids}


def save_state(state: dict[str, Any]) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "seen": sorted(state["seen"]),
        "after_by": state["after_by"],
        "seen_ids": {k: v[-200:] for k, v in state["seen_ids"].items()},
        "updated": now_iso(),
    }
    STATE_FILE.write_text(json.dumps(payload, indent=0) + "\n")


def append_alert(line: str) -> None:
    ALERTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with ALERTS_FILE.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def append_metrics(row: dict[str, Any]) -> None:
    with METRICS_FILE.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")


def item_url(kind: str, item: dict[str, Any], sub: str) -> str:
    perm = item.get("permalink")
    if isinstance(perm, str) and perm.startswith("/"):
        return "https://www.reddit.com" + perm
    if kind == "posts":
        return f"https://www.reddit.com/r/{sub}/comments/{item.get('id', '')}/"
    link = str(item.get("link_id") or "").replace("t3_", "")
    cid = item.get("id", "")
    return f"https://www.reddit.com/r/{sub}/comments/{link}/_/{cid}/"


def parse_created(item: dict[str, Any]) -> float | None:
    cu = item.get("created_utc")
    if cu is None:
        return None
    try:
        return float(cu)
    except (TypeError, ValueError):
        return None


def comments_url(sub: str, after_unix: int | None) -> str:
    # Arctic supports after= as Date (unix works); no id cursor (400).
    q = f"{ARCTIC}/comments/search?subreddit={sub}&limit={LIMIT}&sort=desc"
    if after_unix:
        q += f"&after={int(after_unix)}"
    return q


def posts_url(sub: str, after_unix: int | None) -> str:
    q = f"{ARCTIC}/posts/search?subreddit={sub}&limit={LIMIT}&sort=desc"
    if after_unix:
        q += f"&after={int(after_unix)}"
    return q


def fetch_feed(name: str, kind: str, sub: str, url: str) -> dict[str, Any]:
    status, payload, ms, err = http_get_json(url)
    rows: list[dict[str, Any]] = []
    if isinstance(payload, dict):
        data = payload.get("data")
        if isinstance(data, list):
            rows = [x for x in data if isinstance(x, dict)]
    return {
        "name": name,
        "kind": kind,
        "sub": sub,
        "url": url,
        "status": status,
        "ms": round(ms, 1),
        "err": err,
        "n": len(rows),
        "rows": rows,
    }


def emit_alerts_from_result(
    result: dict[str, Any],
    state: dict[str, Any],
    max_age_min: float,
) -> list[dict[str, Any]]:
    """Scan one feed result and emit NEW fresh alerts immediately."""
    alerts: list[dict[str, Any]] = []
    kind = result["kind"]
    sub = result["sub"]
    feed_key = result["name"]
    now = time.time()
    id_set = set(state["seen_ids"].get(feed_key, []))
    max_cu = state["after_by"].get(feed_key)
    new_ids: list[str] = []

    for item in result.get("rows") or []:
        iid = str(item.get("id") or "")
        created = parse_created(item)
        if created is not None:
            if max_cu is None or created > max_cu:
                max_cu = int(created)
        if iid and iid in id_set:
            continue
        if iid:
            new_ids.append(iid)
        if created is None:
            continue
        age_min = (now - created) / 60.0
        if age_min < 0 or age_min >= max_age_min:
            continue
        if kind == "posts":
            text = f"{item.get('title') or ''}\n{item.get('selftext') or ''}"
        else:
            text = item.get("body") or ""
        for code in extract_codes(text):
            cont = continuous(code)
            with _lock:
                if cont in state["seen"]:
                    continue
                if is_xxxx(code) or cont in {continuous(k) for k in KNOWN_SKIP}:
                    continue
                state["seen"].add(cont)
            first_seen = now_iso()
            age_str = f"{age_min:.1f}".rstrip("0").rstrip(".")
            src = item_url(kind, item, sub or item.get("subreddit") or "wow")
            line = (
                f"{code} | age: {age_str}m | source: {src} "
                f"| first_seen: {first_seen}"
            )
            append_alert(line)
            print(f"ALERT {line}", flush=True)
            alerts.append({
                "code": code,
                "age_min": round(age_min, 2),
                "source": src,
                "endpoint": feed_key,
                "first_seen": first_seen,
            })

    with _lock:
        if max_cu is not None:
            # keep watermark just below newest so after= still returns tip on next poll
            # Arctic after= is exclusive of exact tip in practice when equal → use tip-1
            state["after_by"][feed_key] = int(max_cu)
        if new_ids:
            prev = state["seen_ids"].setdefault(feed_key, [])
            prev.extend(new_ids)
            # cap
            if len(prev) > 500:
                state["seen_ids"][feed_key] = prev[-400:]
    return alerts


def run_hot_cycle(state: dict[str, Any], max_age_min: float = MAX_AGE_MIN) -> dict[str, Any]:
    """Parallel comments/search; emit per-future as results arrive."""
    feeds = []
    for sub in HOT_SUBS:
        name = f"arctic_comments_{sub}"
        # Use stored after watermark; on first run seed to now-10m to bound volume
        after = state["after_by"].get(name)
        if after is None:
            after = int(time.time() - max_age_min * 60)
        # after= is "posted after"; use watermark-1 so we don't miss exact-second ties,
        # then filter by seen ids.
        after_q = max(0, int(after) - 1) if after else None
        feeds.append({
            "name": name,
            "kind": "comments",
            "sub": sub,
            "url": comments_url(sub, after_q),
        })

    t0 = time.perf_counter()
    fresh: list[dict[str, Any]] = []
    ep_rows: list[dict[str, Any]] = []

    with ThreadPoolExecutor(max_workers=len(feeds)) as pool:
        futs = {
            pool.submit(fetch_feed, f["name"], f["kind"], f["sub"], f["url"]): f
            for f in feeds
        }
        for fut in as_completed(futs):
            meta = futs[fut]
            try:
                result = fut.result()
            except Exception as e:
                result = {
                    "name": meta["name"],
                    "kind": meta["kind"],
                    "sub": meta["sub"],
                    "url": meta["url"],
                    "status": None,
                    "ms": 0,
                    "err": str(e)[:160],
                    "n": 0,
                    "rows": [],
                }
            # Emit immediately — do not wait for sibling feeds
            alerts = emit_alerts_from_result(result, state, max_age_min)
            fresh.extend(alerts)
            tip_age = None
            now = time.time()
            for item in result.get("rows") or []:
                cu = parse_created(item)
                if cu is not None:
                    age = (now - cu) / 60.0
                    if tip_age is None or age < tip_age:
                        tip_age = age
            ep_rows.append({
                "name": result["name"],
                "status": result["status"],
                "ms": result["ms"],
                "n": result["n"],
                "err": result["err"],
                "tip_age_min": round(tip_age, 2) if tip_age is not None else None,
                "fresh_n": len(alerts),
                "fresh": [a["code"] for a in alerts],
            })
            print(
                f"HOT {result['name']}: {result['ms']}ms n={result['n']} "
                f"tip={ep_rows[-1]['tip_age_min']} fresh={len(alerts)}",
                flush=True,
            )

    wall_ms = (time.perf_counter() - t0) * 1000.0
    save_state(state)
    summary = {
        "ts": now_iso(),
        "path": "hot",
        "wall_ms": round(wall_ms, 1),
        "alive": sum(1 for r in ep_rows if r["status"] == 200),
        "total_eps": len(ep_rows),
        "fresh_n": len(fresh),
        "fresh_alerts": [a["code"] for a in fresh],
        "endpoints": sorted(ep_rows, key=lambda x: x["ms"]),
    }
    append_metrics(summary)
    return summary


def run_cold_cycle(state: dict[str, Any], max_age_min: float = MAX_AGE_MIN) -> dict[str, Any]:
    """posts/search sort=desc backstop for same subs."""
    feeds = []
    for sub in COLD_SUBS:
        name = f"arctic_posts_{sub}"
        after = state["after_by"].get(name)
        if after is None:
            after = int(time.time() - max_age_min * 60)
        after_q = max(0, int(after) - 1) if after else None
        feeds.append({
            "name": name,
            "kind": "posts",
            "sub": sub,
            "url": posts_url(sub, after_q),
        })

    t0 = time.perf_counter()
    fresh: list[dict[str, Any]] = []
    ep_rows: list[dict[str, Any]] = []

    with ThreadPoolExecutor(max_workers=len(feeds)) as pool:
        futs = {
            pool.submit(fetch_feed, f["name"], f["kind"], f["sub"], f["url"]): f
            for f in feeds
        }
        for fut in as_completed(futs):
            meta = futs[fut]
            try:
                result = fut.result()
            except Exception as e:
                result = {
                    "name": meta["name"],
                    "kind": meta["kind"],
                    "sub": meta["sub"],
                    "url": meta["url"],
                    "status": None,
                    "ms": 0,
                    "err": str(e)[:160],
                    "n": 0,
                    "rows": [],
                }
            alerts = emit_alerts_from_result(result, state, max_age_min)
            fresh.extend(alerts)
            tip_age = None
            now = time.time()
            for item in result.get("rows") or []:
                cu = parse_created(item)
                if cu is not None:
                    age = (now - cu) / 60.0
                    if tip_age is None or age < tip_age:
                        tip_age = age
            ep_rows.append({
                "name": result["name"],
                "status": result["status"],
                "ms": result["ms"],
                "n": result["n"],
                "err": result["err"],
                "tip_age_min": round(tip_age, 2) if tip_age is not None else None,
                "fresh_n": len(alerts),
                "fresh": [a["code"] for a in alerts],
            })
            print(
                f"COLD {result['name']}: {result['ms']}ms n={result['n']} "
                f"tip={ep_rows[-1]['tip_age_min']} fresh={len(alerts)}",
                flush=True,
            )

    wall_ms = (time.perf_counter() - t0) * 1000.0
    save_state(state)
    summary = {
        "ts": now_iso(),
        "path": "cold",
        "wall_ms": round(wall_ms, 1),
        "alive": sum(1 for r in ep_rows if r["status"] == 200),
        "total_eps": len(ep_rows),
        "fresh_n": len(fresh),
        "fresh_alerts": [a["code"] for a in fresh],
        "endpoints": sorted(ep_rows, key=lambda x: x["ms"]),
    }
    append_metrics(summary)
    return summary


def run_loop(smoke_hot: int | None = None) -> list[str]:
    """Main loop. If smoke_hot is set, run that many hot cycles (+1 cold) then exit."""
    ALERTS_FILE.touch(exist_ok=True)
    state = load_state()
    all_fresh: list[str] = []
    next_cold = 0.0  # run cold on first opportunity after hots start
    hot_done = 0

    if smoke_hot is not None:
        # short smoke: N hot cycles, one cold interleaved after first hot
        for i in range(smoke_hot):
            print(f"=== SMOKE HOT {i+1}/{smoke_hot} ===", flush=True)
            s = run_hot_cycle(state)
            all_fresh.extend(s.get("fresh_alerts") or [])
            if i == 0:
                print("=== SMOKE COLD ===", flush=True)
                c = run_cold_cycle(state)
                all_fresh.extend(c.get("fresh_alerts") or [])
            if i + 1 < smoke_hot:
                time.sleep(HOT_INTERVAL)
        return all_fresh

    # continuous
    while True:
        cycle_t0 = time.perf_counter()
        s = run_hot_cycle(state)
        all_fresh.extend(s.get("fresh_alerts") or [])
        hot_done += 1
        now = time.time()
        if now >= next_cold:
            c = run_cold_cycle(state)
            all_fresh.extend(c.get("fresh_alerts") or [])
            next_cold = time.time() + COLD_INTERVAL
        elapsed = time.perf_counter() - cycle_t0
        time.sleep(max(0.5, HOT_INTERVAL - elapsed))


def main() -> None:
    ap = argparse.ArgumentParser(description="Evo9 dual-cadence Arctic keyhunt")
    ap.add_argument(
        "--smoke",
        type=int,
        default=None,
        metavar="N",
        help="Run N hot cycles (+1 cold) then exit",
    )
    args = ap.parse_args()
    fresh = run_loop(smoke_hot=args.smoke)
    if args.smoke is not None:
        if fresh:
            print("FRESH_CODES:", ", ".join(fresh), flush=True)
        else:
            print("NO_FRESH", flush=True)


if __name__ == "__main__":
    main()
