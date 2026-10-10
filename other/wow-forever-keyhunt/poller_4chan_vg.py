#!/usr/bin/env python3
"""Poll 4chan /vg/ for WoW Forever beta keys (4-4-5-4-4)."""
from __future__ import annotations
import json, re, time, urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ALERTS = ROOT / "codes-live-4chan.txt"
METRICS = ROOT / "evolution-12-4chan-metrics.jsonl"
KNOWN = {"CVK5-F4DM-NBGJB-FF6H-LWQW", "CVK5F4DMNBGJBFF6HLWQW"}
PAT = re.compile(
    r"(?<![A-Za-z0-9])([A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{5}-[A-Z0-9]{4}-[A-Z0-9]{4})(?![A-Za-z0-9])",
    re.I,
)
PAT21 = re.compile(r"(?<![A-Za-z0-9])([A-Za-z0-9]{21})(?![A-Za-z0-9])")
INTERVAL = 20
MAX_AGE_MIN = 10


def format_key(raw: str) -> str:
    s = raw.strip().upper().replace(" ", "")
    parts = s.split("-")
    if len(parts) == 5 and [len(x) for x in parts] == [4, 4, 5, 4, 4]:
        return "-".join(parts)
    body = s.replace("-", "")
    if len(body) == 21 and body.isalnum():
        return f"{body[0:4]}-{body[4:8]}-{body[8:13]}-{body[13:17]}-{body[17:21]}"
    return s


def get_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=15) as r:
        data = json.loads(r.read().decode())
    return data, int((time.perf_counter() - t0) * 1000)


def wowish(text: str) -> bool:
    return bool(re.search(r"wow|warcraft|forever|maccas|beta\s*key", text, re.I))


def main() -> None:
    seen: set[str] = set()
    ALERTS.touch(exist_ok=True)
    while True:
        t0 = time.perf_counter()
        fresh = []
        try:
            catalog, ms = get_json("https://a.4cdn.org/vg/catalog.json")
            thread_nos = []
            for page in catalog:
                for th in page.get("threads", []):
                    blob = " ".join(str(th.get(k, "")) for k in ("sub", "com"))
                    if wowish(blob):
                        thread_nos.append(th.get("no"))
            thread_nos = thread_nos[:8]
            now = time.time()
            for no in thread_nos:
                try:
                    data, ms2 = get_json(f"https://a.4cdn.org/vg/thread/{no}.json")
                except Exception:
                    continue
                for p in data.get("posts", []):
                    com = p.get("com") or ""
                    # strip html tags roughly
                    com = re.sub(r"<[^>]+>", " ", com)
                    cu = p.get("time")
                    if not cu:
                        continue
                    age_m = (now - float(cu)) / 60.0
                    if age_m >= MAX_AGE_MIN:
                        continue
                    codes = [format_key(x) for x in PAT.findall(com)]
                    for m in PAT21.findall(com):
                        if sum(c.isdigit() for c in m) < 2:
                            continue
                        codes.append(format_key(m))
                    for c in codes:
                        if c in KNOWN or "XXXX" in c:
                            continue
                        fresh.append(
                            (
                                c,
                                round(age_m, 1),
                                f"https://boards.4chan.org/vg/thread/{no}#p{p.get('no')}",
                            )
                        )
            with METRICS.open("a") as f:
                f.write(
                    json.dumps(
                        {
                            "ts": datetime.now(timezone.utc).isoformat(),
                            "catalog_ms": ms,
                            "threads": thread_nos,
                            "fresh_n": len(fresh),
                        }
                    )
                    + "\n"
                )
        except Exception as e:
            with METRICS.open("a") as f:
                f.write(
                    json.dumps(
                        {
                            "ts": datetime.now(timezone.utc).isoformat(),
                            "err": str(e)[:160],
                        }
                    )
                    + "\n"
                )
        for code, age, src in fresh:
            if code in seen:
                continue
            seen.add(code)
            line = f"{code} | age: {age}m | source: {src} | first_seen: {datetime.now(timezone.utc).isoformat()}"
            print(line, flush=True)
            with ALERTS.open("a") as f:
                f.write(line + "\n")
            # also mirror into codes-live.txt
            with (ROOT / "codes-live.txt").open("a") as f:
                f.write(line + "\n")
        time.sleep(max(1.0, INTERVAL - (time.perf_counter() - t0)))


if __name__ == "__main__":
    main()
