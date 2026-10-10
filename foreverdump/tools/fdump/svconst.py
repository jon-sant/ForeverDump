"""Lua 5.1 constant-table accounting for a SavedVariables file.

WoW loads a SavedVariables file as ONE Lua 5.1 chunk. Every table constructor lives in the chunk's main function, so
every DISTINCT string/number literal in the file (string keys `["k"] =`, field names `k =`, explicit numeric keys
`[123] =`, string and number values, plus the global names) is one entry in a single constant table. Lua 5.1 caps that
table at MAXARG_Bx = 262143 entries ("constant table overflow"); past that the whole file fails to load and the
client may later save over it.

This scanner mimics the 5.1 compiler's accounting without executing anything: numbers are keyed by their double value
(1 == 1.0, -0 == 0, unary minus folded), strings by their decoded bytes. Implicit array keys (`v, -- [n]`) and
nil/true/false never enter the constant table.
"""
import re

LUA51_MAXK = 262143

_TOK = re.compile(r"""
    (?P<ws>(?:\s+|--\[(?P<eq1>=*)\[.*?\](?P=eq1)\]|--[^\n]*)+)
  | (?P<str>"(?:[^"\\\n]|\\.|\\\n)*"|'(?:[^'\\\n]|\\.|\\\n)*')
  | (?P<lstr>\[(?P<eq2>=*)\[.*?\](?P=eq2)\])
  | (?P<nan>0/0|\(1e999-1e999\))
  | (?P<num>-?\s*(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?))
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<p>[{}\[\]=,;])
  | (?P<neg>-)
""", re.S | re.X)

_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\\": "\\", '"': '"', "'": "'",
        "\n": "\n"}


def _decode(lit):
    body = lit[1:-1]
    if "\\" not in body:
        return body
    out, i, n = [], 0, len(body)
    while i < n:
        c = body[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        d = body[i + 1]
        if d.isdigit():
            j = i + 1
            while j < n and j < i + 4 and body[j].isdigit():
                j += 1
            out.append(chr(int(body[i + 1:j])))
            i = j
        else:
            out.append(_ESC.get(d, d))
            i += 2
    return "".join(out)


def _num(t):
    t = t.replace(" ", "").replace("\t", "").replace("\n", "")
    neg = t.startswith("-")
    if neg:
        t = t[1:]
    v = float(int(t, 16)) if t[:2].lower() == "0x" else float(t)
    v = -v if neg else v
    return ("n", 0.0 if v == 0 else v)


def scan(text, depth=3):
    """-> dict(total, by_path{path: (unique_in_subtree, first_introduced)}, kinds{str,num}, examples)."""
    if text.startswith("\ufeff"):
        text = text[1:]
    seen = {}            # const -> introducing path
    sub_sets = {}        # path -> set of consts (subtree, up to `depth`)
    path = []            # stack of key labels
    pending_key = None   # key label for the next value
    arr_idx = []         # implicit index counters per open table
    stack_keys = []
    kinds = {"s": 0, "n": 0, "b": 0}
    i, n = 0, len(text)
    m = _TOK.match
    prev_p = None

    def add(c):
        if c[0] == "b":                       # nil/true/false: RK constant only while nk <= MAXINDEXRK (255)
            if c not in seen and len(seen) <= 255:
                seen[c] = tuple(path[:depth])
                kinds["b"] += 1
            return
        p = tuple(path[:depth])
        if c not in seen:
            seen[c] = p
            kinds[c[0]] += 1
        for d in range(1, len(p) + 1):
            s = sub_sets.get(p[:d])
            if s is None:
                s = sub_sets[p[:d]] = set()
            s.add(c)

    toks = []
    while i < n:
        mo = m(text, i)
        if not mo:
            raise ValueError("svconst: cannot tokenize at offset %d: %r" % (i, text[i:i + 30]))
        i = mo.end()
        kind = mo.lastgroup
        if kind == "ws":
            continue
        toks.append((kind, mo.group(kind)))
    # second pass: structure (top level `Name = value`; tables of `[k] = v`, `k = v`, `v`)
    j, T = 0, len(toks)

    def value_const(kind, tv):
        if kind == "str":
            return ("s", _decode(tv))
        if kind == "lstr":
            body = re.match(r"\[(=*)\[(.*)\]\1\]$", tv, re.S).group(2)
            if body.startswith("\r\n"):
                body = body[2:]
            elif body.startswith("\n"):
                body = body[1:]
            return ("s", body)
        if kind == "num":
            return _num(tv)
        if kind == "nan":                     # NaN spellings: 0/0 (<= v2.2.12: OP_DIV on the constant 0, not folded)
            if tv.startswith("("):            # v2.2.13: (1e999-1e999), OP_SUB on the constant inf (NaN is never folded)
                return ("n", float("inf"))
            return ("n", 0.0)
        return None

    def label(c):
        return c[1] if c[0] == "s" else ("#" if isinstance(c[1], float) else str(c[1]))

    while j < T:
        kind, tv = toks[j]
        if not path and not arr_idx:
            if kind == "name" and toks[j + 1] == ("p", "="):
                path.append(tv)
                add(("s", tv))
                j += 2
                kind, tv = toks[j]
                if kind == "p" and tv == "{":
                    arr_idx.append(0)
                    j += 1
                    continue
                c = value_const(kind, tv)
                if c:
                    add(c)
                path.pop()
                j += 1
                continue
            j += 1
            continue
        if kind == "p" and tv == "}":
            arr_idx.pop()
            path.pop()
            j += 1
            continue
        if kind == "p" and tv in ",;":
            j += 1
            continue
        key = None
        if kind == "p" and tv == "[":
            kc = value_const(*toks[j + 1])
            add(kc)
            key = "[]" if kc[0] == "n" else kc[1]
            j += 4    # [ k ] =
        elif kind == "name" and j + 1 < T and toks[j + 1] == ("p", "="):
            add(("s", tv))
            key = tv
            j += 2
        else:
            key = "[]i"                       # list item: luaK_exp2nextreg, no RK boolean constant
        kind, tv = toks[j]
        if kind == "p" and tv == "{":
            path.append("[]" if key == "[]i" else key)
            arr_idx.append(0)
            j += 1
            continue
        c = value_const(kind, tv)
        if c is None and kind == "name" and tv in ("true", "false", "nil") and key != "[]i":
            c = ("b", tv)
        if c:
            path.append("[]" if key == "[]i" else key)
            add(c)
            path.pop()
        j += 1
    total = len(seen)
    intro = {}
    for p in seen.values():
        for d in range(1, len(p) + 1):
            intro[p[:d]] = intro.get(p[:d], 0) + 1
    by_path = {" > ".join(p): (len(s), intro.get(p, 0)) for p, s in sub_sets.items()}
    return {"total": total, "limit": LUA51_MAXK, "kinds": kinds, "by_path": by_path}


def scan_file(path, depth=3):
    """cached on disk per file content + counter code (svcache.py)"""
    try:
        from .svcache import cached
    except ImportError:                       # run as a script: python3 tools/fdump/svconst.py FILE
        from svcache import cached

    def compute(p):
        with open(p, "r", encoding="utf-8", errors="surrogateescape") as f:
            return scan(f.read(), depth)
    return cached("svconst-d%d" % depth, path, ("svconst.py",), compute)


def text(r, limit=40):
    out = ["unique Lua constants: %d of %d (%.1f%%)  strings %d  numbers %d" % (
        r["total"], r["limit"], 100.0 * r["total"] / r["limit"], r["kinds"]["s"], r["kinds"]["n"])]
    out.append("  %9s %9s  %s" % ("subtree", "first-in", "path"))
    rows = sorted(r["by_path"].items(), key=lambda kv: -kv[1][0])
    for p, (u, f) in rows[:limit]:
        out.append("  %9d %9d  %s" % (u, f, p))
    return "\n".join(out)


if __name__ == "__main__":
    import sys
    print(text(scan_file(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 3)))
