"""SavedVariables size per section: re-serialize each subtree compactly and scale to the real file size."""
import json
import os


def _size(v):
    return len(json.dumps(v, ensure_ascii=False, separators=(",", ":"), default=str))


def breakdown(raw, path, depth=3, min_frac=0.003):
    total_file = os.path.getsize(path)
    rows = []
    est_total = sum(_size(v) for v in raw.values()) or 1
    factor = total_file / est_total

    def walk(name, v, d):
        s = _size(v)
        rows.append((name, s * factor))
        if d < depth and isinstance(v, dict):
            for k, sub in v.items():
                if isinstance(sub, (dict, list)) and _size(sub) * factor >= total_file * min_frac:
                    walk(name + " > " + str(k), sub, d + 1)
    for k, v in raw.items():
        walk(k, v, 1)
    rows.sort(key=lambda r: -r[1])
    return {"file": path, "bytes": total_file, "factor": round(factor, 3),
            "rows": [{"path": n, "bytes": int(b), "pct": round(100.0 * b / total_file, 1)} for n, b in rows]}


def text(r, limit=60):
    out = ["SV file %.2f MB (sizes estimated from re-serialization, scaled to the file size; factor %.2f)" % (r["bytes"] / 1e6, r["factor"])]
    for row in r["rows"][:limit]:
        out.append("  %7.2f MB  %5.1f%%  %s" % (row["bytes"] / 1e6, row["pct"], row["path"]))
    return "\n".join(out)
