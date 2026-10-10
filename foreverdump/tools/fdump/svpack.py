"""v2.2.11 offline decoder for SVPack (ForeverDump/SVPack.lua): SavedVariables packed into Lua-source chunk strings so
the file stays under Lua 5.1's 262,143-constant limit. parse_savedvariables() calls unpack_all() so every tool reads old
(plain) and new (packed) files the same way. Packed form (format 1):
  {__fdpack=1, chunks={"return{list},{hash},n", ...}, nodes=N, cn={node per chunk}, cb={list base per chunk},
   gp={graft parent}, gk={graft key}, gc={graft child}, literals=L, bytes=B}
A var whose in-game rebuild failed is saved as {packedRescue = <packed>} and decoded the same way here."""
from .luasv import _Parser, LuaParseError, as_list


def is_packed(v):
    return isinstance(v, dict) and "__fdpack" in v


def _chunk(src):
    p = _Parser(src)
    p.ws()
    if not src.startswith("return", p.i):
        raise LuaParseError("svpack chunk does not start with return")
    p.i += 6
    a = p.value()
    p.expect(",")
    h = p.value()
    p.expect(",")
    n = p.value()
    return a, h, int(n)


def _items(t):
    if isinstance(t, list):
        return list(enumerate(t, 1))
    if isinstance(t, dict):
        return list(t.items())
    return []


def _normalize(t):
    """luasv shape: a table whose keys are exactly 1..n becomes a list; integral floats from %.17g become ints."""
    if isinstance(t, dict):
        if t and all(isinstance(k, int) for k in t):
            keys = sorted(t)
            if keys == list(range(1, len(keys) + 1)):
                return [t[k] for k in keys]
        return t
    return t


def unpack_value(p):
    if not is_packed(p):
        return p
    if p.get("__fdpack") != 1:
        raise LuaParseError("unknown svpack format %r" % p.get("__fdpack"))
    n = int(p.get("nodes") or 1)
    nodes = [None] + [dict() for _ in range(n)]
    chunks = as_list(p.get("chunks"))
    cn, cb = as_list(p.get("cn")), as_list(p.get("cb"))
    for i, src in enumerate(chunks):
        a, h, cnt = _chunk(src)
        node = nodes[int(cn[i])]
        base = int(cb[i]) if i < len(cb) else 0
        al = dict(_items(a))
        for j in range(1, cnt + 1):
            v = al.get(j)
            if v is not None:
                node[base + j] = v
        for k, v in _items(h):
            node[k] = v
    gp, gk, gc = as_list(p.get("gp")), as_list(p.get("gk")), as_list(p.get("gc"))
    grafts = list(zip(gp, gk, gc))
    # children before parents so each node is normalized (list/dict) once it is complete
    children = {}
    for par, key, ch in grafts:
        children.setdefault(int(par), []).append((key, int(ch)))
    done = {}

    def build(i):
        if i in done:
            return done[i]
        node = nodes[i]
        for key, ch in children.get(i, ()):
            if isinstance(key, float) and key.is_integer():
                key = int(key)
            node[key] = build(ch)
        done[i] = _normalize(node)
        return done[i]
    return build(1)


LAST = {}   # {var: {chunks, literals, bytes} or {rescued, freshKeys}} of the last unpack_all (not injected into raw)


def unpack_all(raw):
    """in place on parse_savedvariables output; returns raw. A rescued var's fresh in-game keys are kept under
    <var>['_svpackFresh'] only when there are any."""
    info = {}
    for name, v in list(raw.items()):
        if is_packed(v):
            raw[name] = unpack_value(v)
            info[name] = {"chunks": len(as_list(v.get("chunks"))), "literals": v.get("literals"), "bytes": v.get("bytes")}
        elif isinstance(v, dict) and is_packed(v.get("packedRescue")):
            rescued = unpack_value(v["packedRescue"])
            rest = {k: x for k, x in v.items() if k != "packedRescue"}
            info[name] = {"rescued": True, "freshKeys": sorted(map(str, rest))}
            raw[name] = rescued
            if rest and isinstance(rescued, dict):
                rescued["_svpackFresh"] = rest
    LAST.clear()
    LAST.update(info)
    return raw
