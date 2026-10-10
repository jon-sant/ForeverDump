#!/usr/bin/env python3
"""EVOLUTION 7 — WoW Forever beta key hunt (Arctic Shift parallel, age-gated).

- Parallel Arctic Shift polls every ~12–15s for NEW posts + comments in
  r/wow, r/classicwow, r/wowclassic, r/australian
- Regex: hyphenated 4-4-5-4-4 AND continuous 21-char; normalize via format_key
- Age gate: created_utc age < 10 minutes (stale/taken skipped)
- Alerts → codes-live-e7.txt: CODE | age: Xm | source: URL | first_seen: ISO
- Dedup by normalized code; skip known CVK5-F4DM-NBGJB-FF6H-LWQW
- Free only (no paid X API)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
ALERTS_FILE = ROOT / "codes-live-e7.txt"
STATE_FILE = ROOT / "state" / "e7_seen.json"
METRICS_FILE = ROOT / "raw" / "e7" / "metrics.jsonl"
RACE_FILE = ROOT / "evolution-7-race.jsonl"

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
)
ARCTIC = "https://arctic-shift.photon-reddit.com/api"
SUBREDDITS = ("wow", "classicwow", "wowclassic", "australian")
MEGA_LINK = "t3_1wik331"

# Canonical example: F8MC-855P-BJGTJ-TQP6-4BX6  (4-4-5-4-4)
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


def plausible(raw: str) -> bool:
    """Reject HTML/base64 junk; require mixed alnum and enough digits."""
    body = continuous(raw)
    if len(body) != 21 or not body.isalnum():
        return False
    if body in {continuous(k) for k in KNOWN_SKIP}:
        return False
    if not re.search(r"[A-Z]", body) or not re.search(r"[0-9]", body):
        return False
    if sum(ch.isdigit() for ch in body) < 3:
        return False
    if sum(ch.isalpha() for ch in body) < 5:
        return False
    if any(n in body for n in NOISE):
        return False
    # reject long runs of same char
    if re.search(r"(.)\1{5,}", body):
        return False
    # reject mostly-A / mostly-hex UUID-ish dumps with too few digit variety
    if body.count("A") >= 8:
        return False
    return True


def extract_codes(text: str) -> list[str]:
    if not text:
        return []
    found: list[str] = []
    seen_local: set[str] = set()
    for m in PAT_HYPHEN.findall(text.upper()):
        if plausible(m):
            nk = format_key(m)
            if nk not in seen_local:
                seen_local.add(nk)
                found.append(nk)
    for m in PAT_21.findall(text.upper()):
        if plausible(m):
            nk = format_key(m)
            if nk not in seen_local:
                seen_local.add(nk)
                found.append(nk)
    return found


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def http_get_json(url: str, timeout: float = 20.0) -> tuple[int | None, Any, float, str | None]:
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


def load_seen() -> set[str]:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    seen: set[str] = {continuous(k) for k in KNOWN_SKIP}
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text())
            if isinstance(data, list):
                seen |= {continuous(x) for x in data}
            elif isinstance(data, dict):
                seen |= {continuous(x) for x in data.get("seen", [])}
        except Exception:
            pass
    # also seed from prior alert files
    for path in (ALERTS_FILE, ROOT / "codes-live.txt", ROOT / "codes-live-e4.txt", ROOT / "seen-codes.txt"):
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
    return seen


def save_seen(seen: set[str]) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(sorted(seen), indent=0) + "\n")


def build_endpoints(after_unix: int | None = None) -> list[dict[str, str]]:
    """Build parallel Arctic Shift + free mirror endpoints."""
    eps: list[dict[str, str]] = []
    after_q = f"&after={after_unix}" if after_unix else ""
    for sub in SUBREDDITS:
        eps.append({
            "name": f"posts_{sub}",
            "kind": "posts",
            "sub": sub,
            "url": (
                f"{ARCTIC}/posts/search?subreddit={sub}"
                f"&limit=50&sort=desc{after_q}"
            ),
        })
        eps.append({
            "name": f"comments_{sub}",
            "kind": "comments",
            "sub": sub,
            "url": (
                f"{ARCTIC}/comments/search?subreddit={sub}"
                f"&limit=50&sort=desc{after_q}"
            ),
        })
    # megathread comments (often stale but free)
    eps.append({
        "name": "comments_megathread",
        "kind": "comments",
        "sub": "australian",
        "url": (
            f"{ARCTIC}/comments/search?link_id={MEGA_LINK}"
            f"&limit=50&sort=desc{after_q}"
        ),
    })
    # other free endpoint (pullpush — may 429)
    eps.append({
        "name": "pullpush_wow_comments",
        "kind": "pullpush_comments",
        "sub": "wow",
        "url": (
            "https://api.pullpush.io/reddit/search/comment/"
            "?subreddit=wow&size=25&sort=desc"
        ),
    })
    return eps


def item_url(kind: str, item: dict[str, Any], sub: str) -> str:
    perm = item.get("permalink")
    if isinstance(perm, str) and perm.startswith("/"):
        return "https://www.reddit.com" + perm
    if kind == "posts":
        return f"https://www.reddit.com/r/{sub}/comments/{item.get('id', '')}/"
    link = str(item.get("link_id") or "").replace("t3_", "")
    cid = item.get("id", "")
    return f"https://www.reddit.com/r/{sub}/comments/{link}/_/{cid}/"


def item_text(kind: str, item: dict[str, Any]) -> str:
    if kind.startswith("pullpush") or kind == "comments":
        return item.get("body") or ""
    title = item.get("title") or ""
    selftext = item.get("selftext") or ""
    return f"{title}\n{selftext}"


def parse_created(item: dict[str, Any]) -> float | None:
    cu = item.get("created_utc")
    if cu is None:
        return None
    try:
        return float(cu)
    except (TypeError, ValueError):
        return None


def fetch_endpoint(ep: dict[str, str]) -> dict[str, Any]:
    status, payload, ms, err = http_get_json(ep["url"])
    rows: list[dict[str, Any]] = []
    if isinstance(payload, dict):
        data = payload.get("data")
        if isinstance(data, list):
            rows = [x for x in data if isinstance(x, dict)]
        elif isinstance(data, dict) and isinstance(data.get("children"), list):
            # reddit listing shape
            for ch in data["children"]:
                if isinstance(ch, dict) and isinstance(ch.get("data"), dict):
                    rows.append(ch["data"])
    return {
        "name": ep["name"],
        "kind": ep["kind"],
        "sub": ep.get("sub", ""),
        "url": ep["url"],
        "status": status,
        "ms": round(ms, 1),
        "err": err,
        "n": len(rows),
        "rows": rows,
    }


def scan_result(
    result: dict[str, Any],
    max_age_min: float,
    seen: set[str],
) -> list[dict[str, Any]]:
    """Return NEW fresh alerts from one endpoint result."""
    alerts: list[dict[str, Any]] = []
    kind = result["kind"]
    sub = result["sub"]
    now = time.time()
    text_kind = "comments" if "comment" in kind else "posts"
    for item in result.get("rows") or []:
        created = parse_created(item)
        if created is None:
            continue
        age_min = (now - created) / 60.0
        if age_min < 0 or age_min >= max_age_min:
            continue
        text = item_text(text_kind if kind != "posts" else "posts", item)
        # pullpush uses body
        if kind.startswith("pullpush"):
            text = item.get("body") or item.get("selftext") or item.get("title") or ""
        for code in extract_codes(text):
            cont = continuous(code)
            if cont in seen:
                continue
            alerts.append({
                "code": code,
                "age_min": age_min,
                "source": item_url(
                    "posts" if kind == "posts" else "comments", item, sub or item.get("subreddit") or "wow"
                ),
                "endpoint": result["name"],
                "created_utc": created,
                "author": item.get("author"),
                "id": item.get("id"),
            })
    return alerts


def append_alert(line: str) -> None:
    ALERTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with ALERTS_FILE.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def append_metrics(row: dict[str, Any]) -> None:
    METRICS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with METRICS_FILE.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")


def run_cycle(
    max_age_min: float,
    seen: set[str],
    after_minutes: float = 15.0,
) -> dict[str, Any]:
    after_unix = int(time.time() - after_minutes * 60)
    endpoints = build_endpoints(after_unix=after_unix)
    t0 = time.perf_counter()
    results: list[dict[str, Any]] = []
    with ThreadPoolExecutor(max_workers=min(16, len(endpoints))) as pool:
        futs = {pool.submit(fetch_endpoint, ep): ep["name"] for ep in endpoints}
        for fut in as_completed(futs):
            try:
                results.append(fut.result())
            except Exception as e:
                results.append({
                    "name": futs[fut],
                    "kind": "?",
                    "sub": "",
                    "url": "",
                    "status": None,
                    "ms": 0,
                    "err": str(e)[:160],
                    "n": 0,
                    "rows": [],
                })
    wall_ms = (time.perf_counter() - t0) * 1000.0

    fresh_alerts: list[dict[str, Any]] = []
    for res in results:
        for al in scan_result(res, max_age_min, seen):
            cont = continuous(al["code"])
            if cont in seen:
                continue
            seen.add(cont)
            first_seen = now_iso()
            age_str = f"{al['age_min']:.1f}".rstrip("0").rstrip(".")
            line = (
                f"{al['code']} | age: {age_str}m | source: {al['source']} "
                f"| first_seen: {first_seen}"
            )
            append_alert(line)
            al["line"] = line
            al["first_seen"] = first_seen
            fresh_alerts.append(al)
            print(f"ALERT {line}", flush=True)

    save_seen(seen)

    summary = {
        "ts": now_iso(),
        "wall_ms": round(wall_ms, 1),
        "max_age_min": max_age_min,
        "endpoints": [
            {
                "name": r["name"],
                "status": r["status"],
                "ms": r["ms"],
                "n": r["n"],
                "err": r["err"],
            }
            for r in sorted(results, key=lambda x: x["ms"])
        ],
        "alive": sum(1 for r in results if r["status"] == 200),
        "total_eps": len(results),
        "fresh_alerts": [a["code"] for a in fresh_alerts],
        "fresh_n": len(fresh_alerts),
    }
    append_metrics(summary)
    return {"summary": summary, "alerts": fresh_alerts, "results": results}


def run_race(rounds: int = 3) -> dict[str, Any]:
    """Timed race: arctic posts-by-sub vs comments search vs other free endpoint."""
    race_eps = []
    for sub in SUBREDDITS:
        race_eps.append({
            "name": f"arctic_posts_{sub}",
            "kind": "posts",
            "sub": sub,
            "url": f"{ARCTIC}/posts/search?subreddit={sub}&limit=25&sort=desc",
        })
        race_eps.append({
            "name": f"arctic_comments_{sub}",
            "kind": "comments",
            "sub": sub,
            "url": f"{ARCTIC}/comments/search?subreddit={sub}&limit=25&sort=desc",
        })
    race_eps.append({
        "name": "arctic_comments_megathread",
        "kind": "comments",
        "sub": "australian",
        "url": f"{ARCTIC}/comments/search?link_id={MEGA_LINK}&limit=25&sort=desc",
    })
    race_eps.append({
        "name": "pullpush_wow_comments",
        "kind": "pullpush_comments",
        "sub": "wow",
        "url": "https://api.pullpush.io/reddit/search/comment/?subreddit=wow&size=25&sort=desc",
    })
    race_eps.append({
        "name": "arctic_posts_ids_known",
        "kind": "posts",
        "sub": "wow",
        "url": f"{ARCTIC}/posts/ids?ids=1wk89wa",
    })

    all_rounds: list[dict[str, Any]] = []
    for i in range(rounds):
        t0 = time.perf_counter()
        ranked: list[dict[str, Any]] = []
        with ThreadPoolExecutor(max_workers=min(16, len(race_eps))) as pool:
            futs = [pool.submit(fetch_endpoint, ep) for ep in race_eps]
            for fut in as_completed(futs):
                res = fut.result()
                # tip age + hit count (not age-gated for race observability)
                tip_age = None
                hits: list[str] = []
                fresh: list[str] = []
                now = time.time()
                for item in res.get("rows") or []:
                    cu = parse_created(item)
                    if cu is not None:
                        age = (now - cu) / 60.0
                        if tip_age is None or age < tip_age:
                            tip_age = age
                        text = item_text(
                            "posts" if res["kind"] == "posts" else "comments", item
                        )
                        if res["kind"].startswith("pullpush"):
                            text = item.get("body") or ""
                        codes = extract_codes(text)
                        hits.extend(codes)
                        if age < 10:
                            fresh.extend(codes)
                ranked.append({
                    "name": res["name"],
                    "ms": res["ms"],
                    "status": res["status"] if res["status"] is not None else "ERR",
                    "n": res["n"],
                    "tip_age_min": round(tip_age, 2) if tip_age is not None else None,
                    "hits": hits[:10],
                    "fresh": fresh[:10],
                    "err": res["err"],
                })
        wall = (time.perf_counter() - t0) * 1000.0
        ranked.sort(key=lambda x: (x["status"] != 200, x["ms"]))
        row = {
            "round": i + 1,
            "ts": now_iso(),
            "wall_ms": round(wall, 1),
            "ranked": ranked,
        }
        with RACE_FILE.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(row) + "\n")
        all_rounds.append(row)
        print(
            f"RACE round {i+1}: wall={wall:.0f}ms "
            f"fastest_ok={[r['name']+':'+str(r['ms']) for r in ranked if r['status']==200][:3]}",
            flush=True,
        )
        if i + 1 < rounds:
            time.sleep(1.0)

    # aggregate winner: lowest median ms among status=200 arctic endpoints
    by_name: dict[str, list[float]] = {}
    tip_by: dict[str, list[float]] = {}
    ok_count: dict[str, int] = {}
    for rnd in all_rounds:
        for r in rnd["ranked"]:
            if r["status"] == 200:
                by_name.setdefault(r["name"], []).append(r["ms"])
                ok_count[r["name"]] = ok_count.get(r["name"], 0) + 1
                if r.get("tip_age_min") is not None:
                    tip_by.setdefault(r["name"], []).append(r["tip_age_min"])

    def median(xs: list[float]) -> float:
        ys = sorted(xs)
        n = len(ys)
        if n == 0:
            return 99999.0
        mid = n // 2
        return ys[mid] if n % 2 else 0.5 * (ys[mid - 1] + ys[mid])

    scored = []
    for name, samples in by_name.items():
        scored.append({
            "name": name,
            "median_ms": round(median(samples), 1),
            "ok_rounds": ok_count.get(name, 0),
            "median_tip_age_min": round(median(tip_by.get(name, [])), 2)
            if tip_by.get(name)
            else None,
        })
    # Winner priority: reliable (ok all rounds) then fastest median, then freshest tip
    def hunt_score(x):
        tip = x["median_tip_age_min"]
        # Prefer tip < 15m (actually fresh), then freshest tip, then speed
        fresh_penalty = 0 if (tip is not None and tip < 15) else 10000
        tip_sort = tip if tip is not None else 9999
        return (fresh_penalty, tip_sort, x["median_ms"], -x["ok_rounds"])

    scored.sort(key=hunt_score)
    winner = scored[0] if scored else None

    # Category winners
    cat = {
        "posts_by_subreddit": [s for s in scored if s["name"].startswith("arctic_posts_") and "ids" not in s["name"]],
        "comments_search": [s for s in scored if s["name"].startswith("arctic_comments_")],
        "other_free": [s for s in scored if not s["name"].startswith("arctic_")],
    }
    cat_winners = {
        k: (sorted(v, key=lambda x: x["median_ms"])[0] if v else None)
        for k, v in cat.items()
    }

    return {
        "rounds": all_rounds,
        "scored": scored,
        "winner": winner,
        "category_winners": cat_winners,
    }


def write_evolution_md(race: dict[str, Any]) -> None:
    winner = race.get("winner") or {}
    cats = race.get("category_winners") or {}
    lines = [
        "# Evolution 7 — Arctic parallel posts+comments, 4-4-5-4-4 format lock",
        "",
        "## Changes",
        "- Poller: `poller_evo7.py`",
        "- Parallel Arctic Shift every **12–15s**: posts/search + comments/search for "
        "`wow`, `classicwow`, `wowclassic`, `australian` (+ megathread + pullpush)",
        "- Key format locked: **4-4-5-4-4** via `format_key`; 21-char continuous hyphenated on emit",
        "- Age gate: `created_utc` age **< 10m**; stamp age on every alert",
        "- Alerts: `codes-live-e7.txt` — `CODE | age: Xm | source: URL | first_seen: ISO`",
        "- Dedup by normalized continuous code; skip `CVK5-F4DM-NBGJB-FF6H-LWQW`",
        "- Free only (no paid X API)",
        "",
        "## Race (arctic posts-by-sub vs comments search vs other free)",
        f"- Log: `evolution-7-race.jsonl` ({len(race.get('rounds') or [])} rounds)",
    ]
    if winner:
        lines.append(
            f"- **Overall winner:** `{winner.get('name')}` "
            f"median **{winner.get('median_ms')}ms** "
            f"(ok {winner.get('ok_rounds')}/{len(race.get('rounds') or [])} rounds"
            + (
                f", tip_age≈{winner.get('median_tip_age_min')}m"
                if winner.get("median_tip_age_min") is not None
                else ""
            )
            + ")"
        )
    for label, key in [
        ("Posts-by-subreddit", "posts_by_subreddit"),
        ("Comments search", "comments_search"),
        ("Other free", "other_free"),
    ]:
        w = cats.get(key)
        if w:
            lines.append(
                f"- **{label} winner:** `{w['name']}` median {w['median_ms']}ms"
                + (
                    f", tip≈{w['median_tip_age_min']}m"
                    if w.get("median_tip_age_min") is not None
                    else ""
                )
            )
        else:
            lines.append(f"- **{label} winner:** none (all failed / 429)")

    lines += [
        "",
        "### Ranked (median ms, successful only)",
        "| Endpoint | median_ms | tip_age_min | ok_rounds |",
        "|----------|-----------|-------------|-----------|",
    ]
    for s in race.get("scored") or []:
        tip = s.get("median_tip_age_min")
        tip_s = f"{tip}" if tip is not None else "—"
        lines.append(
            f"| `{s['name']}` | {s['median_ms']} | {tip_s} | {s['ok_rounds']} |"
        )

    lines += [
        "",
        "## Next hypothesis (Evolution 8)",
        "Cut notice latency by dual-cadence: hot-path only the 2–3 fastest Arctic "
        "comment endpoints (lowest tip_age) every **6–8s** with `after=` watermark, "
        "while posts-by-sub and slower mirrors run every **20–30s**; emit on first "
        "sighting without waiting for the full parallel barrier (per-future "
        "streaming alerts) and keep a rolling in-memory id cursor so we never "
        "re-scan the same Arctic page.",
        "",
    ]
    (ROOT / "evolution-7.md").write_text("\n".join(lines) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser(description="Evo7 WoW Forever key poller")
    ap.add_argument("--cycles", type=int, default=5, help="Number of poll cycles")
    ap.add_argument("--interval", type=float, default=13.0, help="Seconds between cycles")
    ap.add_argument("--max-age-min", type=float, default=10.0)
    ap.add_argument("--race-only", action="store_true")
    ap.add_argument("--race-rounds", type=int, default=3)
    ap.add_argument("--no-race", action="store_true")
    ap.add_argument("--continuous", action="store_true")
    args = ap.parse_args()

    ALERTS_FILE.touch(exist_ok=True)
    seen = load_seen()

    race_info: dict[str, Any] | None = None
    if not args.no_race:
        # reset race log for clean evo7 run
        if RACE_FILE.exists() and not args.race_only:
            # keep prior lines; append new rounds with marker
            pass
        print("=== EVO7 RACE ===", flush=True)
        race_info = run_race(rounds=args.race_rounds)
        write_evolution_md(race_info)
        w = race_info.get("winner") or {}
        print(
            f"RACE winner: {w.get('name')} median_ms={w.get('median_ms')} "
            f"tip={w.get('median_tip_age_min')}",
            flush=True,
        )
        if args.race_only:
            return 0

    print(
        f"=== EVO7 POLL cycles={args.cycles if not args.continuous else '∞'} "
        f"interval={args.interval}s max_age={args.max_age_min}m ===",
        flush=True,
    )
    cycle = 0
    all_alerts: list[dict[str, Any]] = []
    try:
        while True:
            cycle += 1
            t0 = time.perf_counter()
            out = run_cycle(args.max_age_min, seen)
            all_alerts.extend(out["alerts"])
            s = out["summary"]
            print(
                f"cycle {cycle}: wall={s['wall_ms']:.0f}ms "
                f"alive={s['alive']}/{s['total_eps']} "
                f"fresh={s['fresh_n']} "
                f"codes={s['fresh_alerts']}",
                flush=True,
            )
            if not args.continuous and cycle >= args.cycles:
                break
            elapsed = time.perf_counter() - t0
            sleep_for = max(0.0, args.interval - elapsed)
            time.sleep(sleep_for)
    except KeyboardInterrupt:
        print("interrupted", flush=True)

    if not all_alerts:
        append_alert(f"NO_FRESH + {now_iso()}")
        print("NO_FRESH codes this run", flush=True)
    else:
        print(f"TOTAL fresh alerts: {len(all_alerts)}", flush=True)
        for a in all_alerts:
            print(a["line"], flush=True)

    # refresh md with race if we ran it
    if race_info:
        write_evolution_md(race_info)

    return 0


if __name__ == "__main__":
    sys.exit(main())
