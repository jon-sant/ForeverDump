#!/usr/bin/env python3
"""Report the current WoW Forever build from every source and flag new builds.

Sources:
  1. Blizzard patch service (authoritative, also used by Gethe's CI):
       https://us.version.battle.net/v2/products/<product>/versions
  2. wago.tools:        https://wago.tools/api/builds/<product>/latest
  3. Gethe mirror:      raw version.txt on branch "forever"
  4. Ketho BIR:         GetBuildInfo() line in the README on branch "forever"

Usage:
  check_build.py [--product wow_classic_beta] [--region us] [--state FILE] [--json] [--update-state]

Exit codes:
  0   no new build (or no state file yet, unless --update-state was used)
  10  the patch-service build differs from the build recorded in --state
  2   the patch service could not be reached
Standard library only.
"""
import argparse, json, os, re, sys, urllib.request

UA = {"User-Agent": "ForeverDump-refresh/1.0"}

def get(url, timeout=20):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")

def patch_service(product, region):
    txt = get(f"https://us.version.battle.net/v2/products/{product}/versions")
    header = None
    for line in txt.splitlines():
        if not line or line.startswith("##"):
            continue
        cols = line.split("|")
        if header is None:
            header = [c.split("!")[0] for c in cols]
            continue
        row = dict(zip(header, cols))
        if row.get("Region") == region:
            return {"version": row.get("VersionsName"), "build": row.get("BuildId"),
                    "build_config": row.get("BuildConfig"), "cdn_config": row.get("CDNConfig"),
                    "product_config": row.get("ProductConfig")}
    raise RuntimeError(f"no {region} row for {product}")

def wago(product):
    d = json.loads(get(f"https://wago.tools/api/builds/{product}/latest"))
    return {"version": d.get("version"), "found_at": d.get("created_at"),
            "build_config": d.get("build_config"), "cdn_config": d.get("cdn_config")}

def gethe(branch):
    return {"version": get(f"https://raw.githubusercontent.com/Gethe/wow-ui-source/{branch}/version.txt").strip()}

def ketho(branch):
    readme = get(f"https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/{branch}/README.md")
    m = re.search(r'GetBuildInfo\(\)\s*=>\s*"([\d.]+)",\s*"(\d+)"', readme)
    return {"version": f"{m.group(1)}.{m.group(2)}" if m else None}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--product", default="wow_classic_beta")
    ap.add_argument("--region", default="us")
    ap.add_argument("--branch", default="forever", help="Gethe/Ketho branch name")
    ap.add_argument("--state", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".state", "last_build.json"))
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--update-state", action="store_true", help="record the current build as seen")
    a = ap.parse_args()

    out = {"product": a.product, "region": a.region}
    try:
        out["patch_service"] = patch_service(a.product, a.region)
    except Exception as e:
        print(f"patch service error: {e}", file=sys.stderr)
        return 2
    for name, fn, arg in (("wago_tools", wago, a.product), ("gethe_ui_source", gethe, a.branch), ("ketho_bir", ketho, a.branch)):
        try:
            out[name] = fn(arg)
        except Exception as e:
            out[name] = {"error": str(e)}

    current = out["patch_service"]["version"]
    prev = None
    if os.path.exists(a.state):
        with open(a.state) as f:
            prev = json.load(f).get("version")
    out["last_seen"] = prev
    out["new_build"] = prev is not None and prev != current
    out["community_lag"] = {k: out[k].get("version") != current for k in ("wago_tools", "gethe_ui_source", "ketho_bir")}

    if a.update_state:
        os.makedirs(os.path.dirname(a.state), exist_ok=True)
        with open(a.state, "w") as f:
            json.dump(out["patch_service"], f, indent=2)

    if a.json:
        print(json.dumps(out, indent=2))
    else:
        print(f"{a.product} ({a.region})")
        print(f"  Blizzard patch service : {current}  (BuildConfig {out['patch_service']['build_config']})")
        for k, label in (("wago_tools", "wago.tools"), ("gethe_ui_source", "Gethe/wow-ui-source"), ("ketho_bir", "Ketho BIR")):
            v = out[k].get("version") or out[k].get("error")
            print(f"  {label:<23}: {v}{'   <- behind' if out['community_lag'][k] else ''}")
        print(f"  last seen (state)      : {prev}")
        print("  NEW BUILD" if out["new_build"] else "  no new build since last check")
    return 10 if out["new_build"] else 0

if __name__ == "__main__":
    sys.exit(main())
