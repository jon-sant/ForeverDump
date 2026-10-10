#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os as _wos  # portable root (handoff): WOWDEV_ROOT or the nearest parent dir holding foreverdump/
def _wowdev_root():
    r = _wos.environ.get("WOWDEV_ROOT")
    if r:
        return r
    d = _wos.path.dirname(_wos.path.abspath(__file__))
    while d != _wos.path.dirname(d) and not _wos.path.isdir(_wos.path.join(d, "foreverdump")):
        d = _wos.path.dirname(d)
    return d
_WROOT = _wowdev_root()
"""Build SECRETS-GUIDE.html: a static, self-contained guide to WoW Forever / 12.x secret values.

Usage:
  python3 build_guide.py [--inventory TSV] [--research MD] [--verify verify.json]
                         [--lab lab.json|lab.md] [--combat combat.json] [--hsm hsm.json]
                         [--out SECRETS-GUIDE.html]

Curated, sourced text lives in guide_data.py (trusted HTML with [[x:SRC]] confidence markup).
Everything read from input files is HTML-escaped. JSON schemas: see README.md next to this file.
Only the Python standard library is used.
"""
import argparse, csv, datetime, html, json, os, re, sys
from collections import Counter, OrderedDict, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import guide_data as G  # noqa: E402

DEF_INV = os.path.join(HERE, "..", "api-secrecy-inventory-forever-70245.tsv")
DEF_RES = os.path.join(HERE, "..", "secrets-research.md")
DEF_VERIFY = _WROOT + "/foreverdump/real/2026-10-07-run2/out/verify/verify.json"
DEF_OUT = os.path.join(HERE, "SECRETS-GUIDE.html")

WARN = []
def warn(msg):
    WARN.append(msg)
    print("warning: " + msg, file=sys.stderr)

def esc(s):
    return html.escape("" if s is None else str(s), quote=True)

# ---------------------------------------------------------------------------- confidence markup
KIND = {"v": ("verified", "Verified in-game"), "o": ("official", "Official (Blizzard)"),
        "d": ("docs", "Docs / datamined"), "c": ("community", "Community"),
        "p": ("pending", "Pending lab"), "i": ("inference", "Inference")}
MARK = re.compile(r"\[\[([vodcpi]):([^\]|]*)(?:\|([^\]]*))?\]\]")
USED_SOURCES = Counter()

def badge(kind, ids="", note=""):
    cls, label = KIND[kind]
    links = []
    for sid in [x.strip() for x in ids.split(",") if x.strip()]:
        if sid not in G.SOURCES:
            warn("unknown source id %r" % sid)
        USED_SOURCES[sid] += 1
        links.append("<a href='#src-%s'>%s</a>" % (esc(sid), esc(sid)))
    txt = label if not links else label + ": " + ", ".join(links)
    if note:
        txt += " (" + esc(note) + ")"
    return "<span class='b b-%s' title='%s'>%s</span>" % (cls, esc(label), txt)

def md(s):
    """Trusted curated HTML -> HTML with badges."""
    return MARK.sub(lambda m: badge(m.group(1), m.group(2) or "", m.group(3) or ""), s or "")

def code_block(src, lang="lua"):
    return "<pre class='code'><code class='%s'>%s</code></pre>" % (lang, esc(src))

# ---------------------------------------------------------------------------- inputs
def load_inventory(path):
    rows = []
    try:
        with open(path, newline="", encoding="utf-8") as f:
            for r in csv.DictReader(f, delimiter="\t"):
                rows.append(r)
    except OSError as e:
        warn("inventory not readable (%s): impacted-functions section will be empty" % e)
    return rows

def parse_tags(s):
    out = OrderedDict()
    for part in (s or "").split(";"):
        if not part:
            continue
        k, _, v = part.partition("=")
        out[k] = v
    return out

def load_json(path, what):
    if not path:
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        warn("%s not loaded (%s)" % (what, e))
        return None

def load_research(path):
    try:
        with open(path, encoding="utf-8") as f:
            txt = f.read()
    except OSError as e:
        warn("research report not readable (%s)" % e)
        return {"exists": False, "headings": [], "date": ""}
    heads = re.findall(r"^##\s+(.+)$", txt, re.M)
    st = os.stat(path)
    return {"exists": True, "headings": heads[:20], "bytes": len(txt.encode("utf-8")),
            "date": datetime.datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M")}

# verify.json contexts look like "combat/none/self": phase / active-restriction / unit
def ctx_of(c):
    parts = (c or "").split("/")
    phase = parts[0] if parts else ""
    restr = parts[1] if len(parts) > 1 else "none"
    unit = parts[2] if len(parts) > 2 else "none"
    cx = "restricted" if restr not in ("none", "") else ("combat" if phase == "combat" else "ooc")
    uc = {"self": "player", "other": "target_hostile_npc"}.get(unit)
    return cx, uc

class Verify:
    def __init__(self, data):
        self.ok = bool(data)
        self.rows = defaultdict(list)
        self.meta = {}
        if not data:
            return
        self.meta = {"build": data.get("build"), "dataVersion": data.get("dataVersion"),
                     "statusCounts": data.get("statusCounts", {})}
        for r in data.get("rows", []):
            self.rows[r.get("key")].append(r)

    def api(self, name):
        return self.rows.get("api:" + name, []) or self.rows.get("event:" + name, [])

    def summary(self, name):
        """-> (secret, clear, nil, contexts{(cx,uc): set(codes)}, note)"""
        rs = self.api(name)
        if not rs:
            return None
        sec = sum(r.get("secret", 0) for r in rs)
        clr = sum(r.get("clear", 0) for r in rs)
        nil = sum(r.get("nil", 0) for r in rs)
        cells = defaultdict(set)
        for r in rs:
            for c in r.get("secretContexts", []):
                cells[ctx_of(c)].add("S")
            for c in r.get("clearContexts", []):
                cells[ctx_of(c)].add("C")
        notes = sorted({r.get("note") for r in rs if r.get("note")})
        return sec, clr, nil, cells, "; ".join(notes)

    def field(self, func, field):
        for k, rs in self.rows.items():
            if k.startswith("field:%s#" % func) and k.endswith("." + field):
                return rs[0]
        return None

# ---------------------------------------------------------------------------- inline SVG flowcharts
def wrap(text, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if len(cur) + len(w) + 1 > width and cur:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur:
        lines.append(cur)
    return lines

def svg_flow(spec, fid):
    CW, RH, BW, BH, PAD = 250, 108, 228, 74, 16
    nodes = spec["nodes"]
    cols = max(n[0] for n in nodes.values()) + 1
    rows = max(n[1] for n in nodes.values()) + 1
    W, H = cols * CW + PAD * 2, rows * RH + PAD * 2
    def box(nid):
        c, r, _, _ = nodes[nid]
        x = PAD + c * CW + (CW - BW) / 2
        y = PAD + r * RH + (RH - BH) / 2
        return x, y
    out = ["<svg class='flow' viewBox='0 0 %d %d' role='img' aria-labelledby='%s-t' xmlns='http://www.w3.org/2000/svg'>" % (W, H, fid),
           "<title id='%s-t'>%s</title>" % (fid, esc(spec["title"])),
           "<defs><marker id='%s-arr' viewBox='0 0 10 10' refX='9' refY='5' markerWidth='7' markerHeight='7' orient='auto-start-reverse'>"
           "<path d='M0,0 L10,5 L0,10 z' class='arrowhead'/></marker></defs>" % fid]
    for a, b, label in spec["edges"]:
        ax, ay = box(a)
        bx, by = box(b)
        ca, ra = nodes[a][0], nodes[a][1]
        cb, rb = nodes[b][0], nodes[b][1]
        if ra == rb:
            if cb > ca:
                x1, y1, x2, y2 = ax + BW, ay + BH / 2, bx, by + BH / 2
            else:
                x1, y1, x2, y2 = ax, ay + BH / 2, bx + BW, by + BH / 2
        elif rb > ra:
            x1, y1, x2, y2 = ax + BW / 2, ay + BH, bx + BW / 2, by
        else:
            x1, y1, x2, y2 = ax + BW / 2, ay, bx + BW / 2, by + BH
        out.append("<line x1='%.0f' y1='%.0f' x2='%.0f' y2='%.0f' class='edge' marker-end='url(#%s-arr)'/>" % (x1, y1, x2, y2, fid))
        if label:
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            out.append("<text x='%.0f' y='%.0f' class='elabel' text-anchor='middle'>%s</text>" % (mx + 4, my - 4, esc(label)))
    for nid, (c, r, text, kind) in nodes.items():
        x, y = box(nid)
        rx = 30 if kind == "start" else 6
        out.append("<rect x='%.0f' y='%.0f' width='%d' height='%d' rx='%d' class='node n-%s'/>" % (x, y, BW, BH, rx, kind))
        lines = wrap(text, 30)[:4]
        ty = y + BH / 2 - (len(lines) - 1) * 7.5 + 4.5
        for i, ln in enumerate(lines):
            out.append("<text x='%.0f' y='%.0f' class='ntext' text-anchor='middle'>%s</text>" % (x + BW / 2, ty + i * 15, esc(ln)))
    out.append("</svg>")
    return "<figure class='fig'>%s<figcaption>%s</figcaption></figure>" % ("".join(out), esc(spec["title"]))

# ---------------------------------------------------------------------------- style
CSS = r"""
:root{--bg:#fbfbfc;--fg:#1d2127;--mut:#5b6573;--card:#fff;--line:#d9dee5;--acc:#2458b8;--code:#f2f4f7;
--ok:#1f7a3a;--okb:#e3f4e8;--bad:#a61b1b;--badb:#fbe5e5;--sec:#7a4d00;--secb:#fff1d6;--pen:#596273;--penb:#eceff3;
--v:#1f7a3a;--o:#1f4fa8;--d:#6b3fa0;--c:#a35400;--p:#596273;--i:#8a6d00;--y:#b38600;--g:#1f8a3f;--r:#c62828;--k:#7d8590}
@media (prefers-color-scheme:dark){:root{--bg:#14171c;--fg:#e4e7ec;--mut:#9aa4b2;--card:#1b1f26;--line:#2d333d;--acc:#7aa7ff;
--code:#222831;--ok:#6fd38f;--okb:#17301f;--bad:#ff8a8a;--badb:#3a1c1c;--sec:#ffc56b;--secb:#3a2c10;--pen:#aab3c0;--penb:#262c35;
--v:#6fd38f;--o:#8fb5ff;--d:#c7a4ff;--c:#ffb169;--p:#aab3c0;--i:#e6cf63;--y:#f0c33c;--g:#55d07a;--r:#ff6b6b;--k:#8b949e}}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.wrap{display:grid;grid-template-columns:260px minmax(0,1fr);gap:28px;max-width:1360px;margin:0 auto;padding:0 18px}
nav.toc{position:sticky;top:0;align-self:start;max-height:100vh;overflow:auto;padding:18px 4px 30px;font-size:13.5px}
nav.toc ol{padding-left:18px;margin:6px 0}nav.toc a{color:var(--fg);text-decoration:none}nav.toc a:hover{color:var(--acc)}
nav.toc .meta{color:var(--mut);font-size:12px}
main{min-width:0;padding:10px 0 80px}
h1{font-size:28px;margin:22px 0 4px}h2{font-size:22px;margin:42px 0 10px;padding-top:10px;border-top:2px solid var(--line)}
h3{font-size:17px;margin:26px 0 8px}h4{margin:18px 0 6px}
a{color:var(--acc)}code{background:var(--code);padding:1px 4px;border-radius:4px;font-size:.92em}
pre.code{background:var(--code);padding:12px 14px;border-radius:8px;overflow:auto;font-size:12.8px;line-height:1.45;border:1px solid var(--line)}
pre.code code{background:none;padding:0}
table{border-collapse:collapse;width:100%;margin:10px 0 16px;font-size:13.5px;background:var(--card)}
th,td{border:1px solid var(--line);padding:6px 8px;vertical-align:top;text-align:left}
th{background:var(--code);position:sticky;top:0;z-index:1}
.tbl{overflow-x:auto}.small{font-size:12.5px;color:var(--mut)}.mut{color:var(--mut)}
.b{display:inline-block;font-size:11px;line-height:1.35;padding:0 6px;border-radius:9px;border:1px solid currentColor;margin:1px 2px;white-space:nowrap;font-weight:600}
.b a{color:inherit}.b-verified{color:var(--v)}.b-official{color:var(--o)}.b-docs{color:var(--d)}.b-community{color:var(--c)}
.b-pending{color:var(--p);border-style:dashed}.b-inference{color:var(--i)}
.legend .b{margin-right:6px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 16px;margin:12px 0}
.callout{border-left:4px solid var(--acc);background:var(--card);padding:10px 14px;margin:12px 0;border-radius:0 8px 8px 0}
.warn{border-left-color:var(--bad)}
.r-ok{color:var(--ok);font-weight:600}.r-err{color:var(--bad);font-weight:600}.r-secret{color:var(--sec);font-weight:600}
.r-nil{color:var(--pen);font-weight:600}.r-pending{color:var(--pen);font-style:italic}
.cell{display:inline-block;min-width:2.2em;text-align:center;border-radius:5px;padding:0 5px;font-weight:700;font-size:12.5px}
.c-C{background:var(--okb);color:var(--ok)}.c-S{background:var(--secb);color:var(--sec)}.c-E{background:var(--badb);color:var(--bad)}
.c-X{background:var(--penb);color:var(--d)}.c-N,.c-P{background:var(--penb);color:var(--pen)}
.c-q{outline:1px dashed currentColor}
.obs{display:block;font-size:11.5px;margin-top:3px}.contra{color:var(--r);font-weight:700}
.hsm{font-weight:700;padding:0 4px;border-radius:4px}.hsm.g{color:var(--g)}.hsm.y{color:var(--y)}.hsm.k{color:var(--k)}.hsm.r{color:var(--r)}
blockquote{margin:10px 0;padding:8px 14px;border-left:4px solid var(--o);background:var(--card);border-radius:0 8px 8px 0}
blockquote footer{font-size:12.5px;color:var(--mut);margin-top:4px}
details{margin:6px 0;border:1px solid var(--line);border-radius:8px;background:var(--card)}
details>summary{cursor:pointer;padding:7px 12px;font-weight:600}details>div{padding:0 12px 10px}
.filter{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:8px 0}
.filter input[type=search]{flex:1;min-width:220px;padding:7px 10px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--fg)}
.filter label{font-size:13px}
.two{display:grid;grid-template-columns:1fr 1fr;gap:12px}.two>div{min-width:0}
.two h4{margin-top:4px}
figure.fig{margin:16px 0;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px}
figure.fig figcaption{font-size:13px;color:var(--mut);text-align:center}
svg.flow{width:100%;height:auto;max-width:820px;display:block;margin:0 auto}
svg .node{fill:var(--card);stroke:var(--line);stroke-width:1.6}svg .n-start{stroke:var(--o)}svg .n-q{stroke:var(--d)}
svg .n-ok{stroke:var(--ok);fill:var(--okb)}svg .n-bad{stroke:var(--bad);fill:var(--badb)}svg .n-act{stroke:var(--sec);fill:var(--secb)}
svg .ntext{fill:var(--fg);font-size:12px;font-family:system-ui,sans-serif}svg .elabel{fill:var(--mut);font-size:11.5px;font-family:system-ui,sans-serif}
svg .edge{stroke:var(--mut);stroke-width:1.5}svg .arrowhead{fill:var(--mut)}
.toplink{font-size:12px;float:right;font-weight:400}
@media (max-width:900px){.wrap{grid-template-columns:1fr}nav.toc{position:static;max-height:none;border-bottom:1px solid var(--line)}.two{grid-template-columns:1fr}}
@media print{nav.toc,.filter,.toplink{display:none}.wrap{display:block}body{background:#fff;color:#000;font-size:11pt}
details{border:none}details>div{display:block}th{position:static}pre.code{white-space:pre-wrap;border:1px solid #ccc}
h2{page-break-before:always}h2:first-of-type{page-break-before:avoid}a{color:#000}}
"""

JS = r"""
(function(){
  function qs(s,r){return (r||document).querySelectorAll(s);}
  var box=document.getElementById('fn-q'); if(!box) return;
  var kinds=qs('.fn-kind'), tags=document.getElementById('fn-tag');
  function run(){
    var q=box.value.toLowerCase().trim(), tag=tags.value, shownGroups=0, shownRows=0;
    var allowed={}; kinds.forEach(function(k){allowed[k.value]=k.checked;});
    qs('details.fn-group').forEach(function(g){
      var n=0;
      qs('tr[data-k]',g).forEach(function(tr){
        var ok=allowed[tr.dataset.k] && (!q || tr.dataset.s.indexOf(q)>=0) && (!tag || tr.dataset.t.indexOf(tag)>=0);
        tr.style.display=ok?'':'none'; if(ok) n++;
      });
      g.style.display=n?'':'none'; if(n){shownGroups++; shownRows+=n;}
      if(q && n) g.open=true;
    });
    document.getElementById('fn-count').textContent=shownRows+' entries in '+shownGroups+' groups';
  }
  box.addEventListener('input',run); tags.addEventListener('change',run);
  kinds.forEach(function(k){k.addEventListener('change',run);});
  run();
})();
"""

# ---------------------------------------------------------------------------- small renderers
def table(headers, rows, cls=""):
    h = "".join("<th>%s</th>" % x for x in headers)
    b = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % c for c in r) for r in rows)
    return "<div class='tbl'><table class='%s'><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>" % (cls, h, b)

def ul(items):
    return "<ul>%s</ul>" % "".join("<li>%s</li>" % md(x) for x in items)

def cell(code, title=""):
    base = (code or "P")[0]
    q = " c-q" if "?" in (code or "") else ""
    return "<span class='cell c-%s%s' title='%s'>%s</span>" % (esc(base), q, esc(title), esc(code or "P"))

RESULT_CLS = {"ok": "r-ok", "err": "r-err", "secret": "r-secret", "nil": "r-nil", "pending": "r-pending"}

def section(sid, num, title, body):
    return "<section id='%s'><h2>%d. %s <a class='toplink' href='#top'>top</a></h2>%s</section>" % (sid, num, esc(title), body)

# ---------------------------------------------------------------------------- lab / combat / hsm adapters
class Lab:
    def __init__(self, path):
        self.recs, self.controls, self.md, self.path = [], [], None, path
        if not path:
            return
        if path.lower().endswith(".md"):
            try:
                with open(path, encoding="utf-8") as f:
                    self.md = f.read()
            except OSError as e:
                warn("lab md not loaded (%s)" % e)
            return
        data = load_json(path, "lab json")
        if isinstance(data, list):
            self.recs = data
        elif isinstance(data, dict):
            self.recs = data.get("lab") or data.get("items_by_run") or []
            self.controls = data.get("controls") or []
            if isinstance(self.recs, dict):
                self.recs = list(self.recs.values())
            if isinstance(self.controls, dict):
                self.controls = list(self.controls.values())

    def op(self, subject, op, field):
        """-> list of (ctx, entry) from controls[*].ops[subject][op]"""
        out = []
        for rec in self.controls:
            ops = rec.get("ops") if isinstance(rec, dict) else None
            if not isinstance(ops, dict):
                continue
            e = (ops.get(subject) or {}).get(op)
            if isinstance(e, dict):
                out.append((rec.get("ctx", "?"), e))
        return out

def norm_ctx(c):
    c = (c or "").lower()
    if c in ("ooc", "out", "outofcombat"):
        return "ooc"
    if c in ("combat", "incombat"):
        return "combat"
    return "restricted"

def combat_obs(data):
    obs = {}
    if not isinstance(data, dict):
        return obs
    def put(item, unit, ctx, rec):
        if not isinstance(rec, dict):
            rec = {"code": str(rec)}
        code = str(rec.get("code", "P"))[:4]
        obs[(str(item), str(unit), norm_ctx(ctx))] = (code, rec.get("n"), rec.get("note", ""), rec.get("api", ""))
    for item, byu in (data.get("items") or {}).items():
        if isinstance(byu, dict):
            for unit, byc in byu.items():
                if isinstance(byc, dict):
                    for ctx, rec in byc.items():
                        put(item, unit, ctx, rec)
    for o in data.get("observations") or []:
        if isinstance(o, dict) and o.get("item"):
            put(o["item"], o.get("unit", "any"), o.get("context", "combat"), o)
    return obs

# ---------------------------------------------------------------------------- sections
def s_header(ctx):
    v = ctx["verify"]
    inputs = [("inventory", ctx["inv_path"], "%d rows" % len(ctx["inv"])),
              ("research", ctx["res_path"], "updated " + ctx["research"].get("date", "?") if ctx["research"].get("exists") else "missing"),
              ("verify", ctx["verify_path"] or "-", ("%s, %s" % (v.meta.get("build"), v.meta.get("dataVersion"))) if v.ok else "not used"),
              ("--lab", ctx["lab"].path or "-", "loaded" if (ctx["lab"].recs or ctx["lab"].controls or ctx["lab"].md) else "not provided: lab cells show 'pending'"),
              ("--combat", ctx["combat_path"] or "-", "%d observations" % len(ctx["combat"]) if ctx["combat"] else "not provided"),
              ("--hsm", ctx["hsm_path"] or "-", "loaded" if ctx["hsm"] else "not provided: HSM rules show 'pending'")]
    leg = " ".join(badge(k) for k in "vodcpi")
    cells = " ".join("%s %s" % (cell(k), esc(v_)) for k, v_ in [("C", "clear"), ("S", "secret"), ("E", "Lua error / refused"), ("X", "container: check HasSecretValues()"), ("N", "nil / nothing"), ("P", "pending"), ("S?", "dashed = unconfirmed")])
    return ("<header id='top'><h1>WoW Forever secret values: migration guide</h1>"
            "<p class='mut'>Client: WoW Forever 1.60.1 build 70245 (TOC 16001, <code>WOW_PROJECT_ID</code> 18 = CAMELOT), Midnight 12.x addon rules. "
            "Generated %s ET by <code>guide/build_guide.py</code>.</p>"
            "<div class='card legend'><b>Confidence badges:</b> %s<br><b>Cell codes:</b> %s</div>"
            "<details><summary>Inputs used for this build</summary><div>%s</div></details></header>"
            % (esc(ctx["now"]), leg, cells, table(["input", "path", "status"], [[esc(a), "<code>%s</code>" % esc(b), esc(c)] for a, b, c in inputs])))

def s_tldr(ctx):
    mm = table(["What you do", "Example", "Result"],
               [[esc(a), "<code>%s</code>" % esc(b), "<span class='%s'>%s</span>" % (RESULT_CLS.get(k, ""), esc(c))] for a, b, c, k in G.MENTAL_MODEL])
    return (ul(G.TLDR) + "<h3>Mental model: a box you may carry but not open</h3>" + mm +
            "<div class='callout'>Start here if you port combat addons: <a href='#combat'>Combat secrets</a> (what is secret, per unit and context, with before/after code) and <a href='#tokens'>Unit tokens</a>.</div>")

def obs_cells(ctx, item):
    """(uc,cx) -> list of observed codes, from verify (+combat json)."""
    out = defaultdict(list)
    v = ctx["verify"]
    for api in item.get("observe", []):
        s = v.summary(api) if v.ok else None
        if not s:
            continue
        for (cx, uc), codes in s[3].items():
            if item.get("unitless"):
                uc = G.ANY
            if uc:
                for c in sorted(codes):
                    if c == "C" and (item.get("nilable") or item.get("container")):
                        c = "N?"
                    out[(uc, cx)].append(("verify", api, c))
    for (iid, unit, cx), (code, n, note, api) in ctx["combat"].items():
        if iid == item["id"]:
            out[(unit, cx)].append(("combat", (api or "") + (" " + str(note) if note else ""), code + ("x%s" % n if n else "")))
    return out

def contradiction(expected, observed_codes):
    e = (expected or "")[:1]
    obs = {c[:1] for c in observed_codes}
    if not obs or "?" in (expected or "") or e not in ("C", "S"):
        return False
    return obs == {"C" if e == "S" else "S"}

def s_combat(ctx):
    inv = ctx["inv_by_name"]
    parts = ["<p>One block per value addons commonly read in combat. <b>Expected</b> = what the 70245 docs and Blizzard posts say (cell code, hover for the reason). "
             "<b>obs</b> = what the user's capture saw (verify.json; v2.1 classified nil/containers as clear, shown as N?) plus any <code>--combat</code> JSON. "
             "<span class='contra'>Red</span> marks a contradiction between docs and observation. The run covered you (player) and a hostile NPC target in the open world; other cells await the lab.</p>",
             "<div class='callout'>Contexts: <b>ooc</b> = no restriction active; <b>combat</b> = Combat restriction active (open world counts); <b>restricted</b> = Encounter / ChallengeMode / PvPMatch / Map active.</div>"]
    toc = " &middot; ".join("<a href='#c-%s'>%s</a>" % (esc(i["id"]), esc(i["title"])) for i in G.COMBAT_ITEMS)
    parts.append("<p class='small'>%s</p>" % toc)
    for item in G.COMBAT_ITEMS:
        obs = obs_cells(ctx, item)
        rows = []
        ucs = [(G.ANY, "All units (session)")] if item.get("unitless") else G.UNIT_CLASSES
        for uc, ulabel in ucs:
            r = [esc(ulabel)]
            for cx, _ in G.CONTEXTS:
                code, why = item["expect"][uc][cx]
                h = cell(code, why)
                o = obs.get((uc, cx), [])
                if o:
                    codes = [c for _, _, c in o]
                    cls = "obs contra" if contradiction(code, codes) else "obs"
                    src = "; ".join("%s %s" % (k, a) for k, a, _ in o)
                    h += "<span class='%s' title='%s'>obs: %s</span>" % (cls, esc(src), esc(", ".join(sorted(set(codes)))))
                r.append(h)
            rows.append(r)
        tags = []
        for api in item["apis"]:
            rr = inv.get(api)
            t = rr["tags"] if rr else "(not in inventory)"
            t = ";".join(x for x in t.split(";") if not x.startswith("SecretArguments")) or "no secrecy tag"
            tags.append("<code>%s</code> <span class='small'>%s</span>" % (esc(api), esc(t)))
        parts.append("<div class='card' id='c-%s'><h3>%s</h3><p>%s</p><p class='small'>Documented tags: %s</p>%s<p class='small'>Recommended pattern: <a href='#%s'>%s</a></p></div>"
                     % (esc(item["id"]), esc(item["title"]), md(item["summary"]), "; ".join(tags),
                        table(["Unit class"] + [esc(l) for _, l in G.CONTEXTS], rows),
                        esc(item["pattern"]), esc(dict((p[0], p[1]) for p in G.COMBAT_PATTERNS).get(item["pattern"], item["pattern"]))))
    extra = [(k, v) for k, v in ctx["combat"].items() if k[0] not in {i["id"] for i in G.COMBAT_ITEMS} and not k[0].startswith("det.")]
    if extra:
        parts.append("<h3>Other --combat observations</h3>" + table(["item", "unit", "context", "code", "n", "api", "note"],
                     [[esc(a), esc(b), esc(c), cell(v[0]), esc(v[1]), esc(v[3]), esc(v[2])] for (a, b, c), v in sorted(extra)]))
    parts.append("<h3 id='tooltips'>Spell text and tooltips in combat</h3>" + ul(G.TOOLTIP_FINDINGS))
    parts.append("<h3>Recommended patterns (before / after)</h3>")
    for pid, title, before, after, note in G.COMBAT_PATTERNS:
        parts.append("<div class='card' id='%s'><h4>%s</h4><div class='two'><div><b>Before</b>%s</div><div><b>After</b>%s</div></div><p class='small'>%s</p></div>"
                     % (esc(pid), esc(title), code_block(before), code_block(after), md(note)))
    return "".join(parts)

def s_tokens(ctx):
    qa = "".join("<div class='card'><h4>%s</h4><p>%s</p></div>" % (esc(q), md(a)) for q, a in G.TOKEN_ANSWER)
    tb = table(["Token family", "Resolves?", "Identity secret when?", "Values secret when?", "Macro / secure usage OK?", "Confidence"],
               [[esc(r[0])] + [md(x) for x in r[1:]] for r in G.TOKEN_TABLE])
    return ("<p><b>Short answer:</b> tokens still resolve; secrecy attaches to the values you get back, and some APIs refuse some token kinds. "
            "The table is the reference; the five questions below explain it.</p>" + tb + qa + "<p class='small'>%s</p>" % md(G.TOKEN_TYPES_NOTE))

def s_changed(ctx):
    a = table(["Area", "Before 12.0", "12.x / Forever"], [[esc(x), md(y), md(z)] for x, y, z in G.PRE_VS_NOW])
    t = table(["Date", "Milestone", "Change"], [[esc(d), esc(m), md(c)] for d, m, c in G.TIMELINE])
    return a + "<h3>Timeline</h3>" + t + "<h3>Forever-specific differences</h3>" + ul(G.FOREVER_SPECIFICS)

def s_intent(ctx):
    q = []
    for sid, text in G.QUOTES:
        src = G.SOURCES.get(sid, ("?", "", "?", "", ""))
        USED_SOURCES[sid] += 1
        q.append("<blockquote>%s<footer>%s, %s %s</footer></blockquote>" % (esc(text), esc(src[0]), esc(src[2]), badge("o", sid)))
    return "".join(q) + "<h3>Community reaction and what it means for you</h3>" + ul(G.COMMUNITY_REACTION)

def s_mechanics(ctx):
    rt = table(["Enum", "Restriction type", "When"], [[esc(a), "<code>%s</code>" % esc(b), md(c)] for a, b, c in G.RESTRICTION_TYPES])
    rs = table(["Enum", "State", "Semantics"], [[esc(a), "<code>%s</code>" % esc(b), md(c)] for a, b, c in G.RESTRICTION_STATES])
    ft = table(["Tag", "Meaning"], [["<code>%s</code>" % esc(a), esc(b)] for a, b in G.FIELD_TAGS])
    preds = [r for r in ctx["inv"] if r.get("kind") == "predicate"]
    use = Counter()
    for r in ctx["inv"]:
        for k in parse_tags(r.get("tags")):
            use[k] += 1
        for k in re.findall(r"\[(\w+)=", (r.get("returns_or_payload") or "") + (r.get("struct_fields") or "")):
            use[k] += 1
    pt = table(["Predicate", "Definition", "Uses in 70245 docs"],
               [["<code>%s</code>" % esc(r["name"]), "<span class='small'>%s</span>" % esc(r.get("tags")), esc(use.get(r["name"], 0))]
                for r in sorted(preds, key=lambda r: -use.get(r["name"], 0))])
    return ("<h3>Restriction types</h3>" + rt + "<h3>Restriction states</h3>" + rs + svg_flow(G.FLOW_RESTRICT, "f-restrict") +
            "<h3>Doc tags (predicates)</h3>" + ft +
            "<details><summary>All %d predicates in the inventory, by number of uses</summary><div>%s</div></details>" % (len(preds), pt) +
            "<h3>Containers, strings, taint, SavedVariables</h3>" + ul(G.MECH_NOTES) +
            "<h4>Real taint log from the user's run</h4>" + code_block(G.TAINT_EXAMPLE, "log"))

def lab_op_text(lab, spec, expect):
    if not spec:
        return "<span class='r-pending'>n/a</span>"
    subject, op, field = spec
    hits = lab.op(subject, op, field)
    if not hits:
        return badge("p", "", "Lab: controls %s / %s" % (subject, op))
    out = []
    for cx, e in hits:
        okv = e.get("ok")
        if field == "ok":
            txt = "ok" if okv else "error" + (": " + str(e.get("err"))[:80] if e.get("err") else "")
        else:
            txt = "%s=%s" % (field, e.get(field))
        bad = (expect == "err" and okv) or (expect in ("ok", "secret", "nil") and okv is False)
        out.append("<span class='%s'>%s: %s</span>" % ("contra" if bad else "", esc(cx), esc(txt)))
    return "<br>".join(out)

def s_ops(ctx):
    rows = []
    for name, ex, res, k, src, spec in G.OPS:
        rows.append([esc(name), "<code>%s</code>" % esc(ex), "<span class='%s'>%s</span>" % (RESULT_CLS.get(k, ""), esc(res)), md(src), lab_op_text(ctx["lab"], spec, k)])
    return ("<p>What tainted (addon) code may do with a secret. The last column shows ForeverDump's controls matrix from <code>--lab</code> when provided "
            "(<code>ForeverDumpLogDB.controls[*].ops</code>, per context).</p>" +
            table(["Operation", "Example", "Result for a secret", "Source", "Lab (Forever 70245)"], rows))

def s_detect(ctx):
    rows = []
    for did, sig, unit, apis, cells in G.DETECT:
        r = [esc(sig), esc(unit), "<span class='small'>%s</span>" % esc(apis)]
        for cx, _ in G.CONTEXTS:
            code, note = cells[cx]
            h = cell(code, G.DETECT_CODES.get(code, "")) + " <span class='small'>%s</span>" % md(note)
            o = ctx["combat"].get((did, "any", cx))
            if o:
                h += "<span class='obs %s'>obs: %s</span>" % ("contra" if contradiction(code, [o[0]]) else "", esc(o[0]))
            r.append(h)
        rows.append(r)
    codes = ", ".join("%s %s" % (cell(k), esc(v)) for k, v in G.DETECT_CODES.items())
    cards = []
    for p in G.INFERENCE:
        cards.append("<div class='card' id='%s'><h4>%s</h4><p><b>Signals:</b> %s</p>%s"
                     "<p><b>Preconditions:</b> %s</p><p><b>Failure modes:</b> %s</p><p><b>Expected accuracy:</b> %s</p><p class='small'>%s</p></div>"
                     % (esc(p["id"]), esc(p["title"]), md(p["signals"]), code_block(p["sketch"]), md(p["pre"]), md(p["fail"]), md(p["acc"]), md(p["note"])))
    return ("<p>Which state an addon can still <i>detect</i> (yes/no, counts, timing) even when the values are secret. "
            "'Pending' cells need the ForeverDump lab or a <code>--combat</code> JSON with <code>det.*</code> ids.</p>"
            "<h3>Detectability</h3>" + table(["Signal", "Unit", "APIs / events"] + [esc(l) for _, l in G.CONTEXTS], rows) +
            "<p class='small'>%s</p>" % codes +
            "<h3>Inference patterns (legitimate)</h3><p>Reasoning over non-secret signals and event timing: your own casts, event arrival, NeverSecret fields, "
            "data cached while readable. Show inferred state as inferred, and keep the engine widget as the source of truth.</p>" + "".join(cards) +
            svg_flow(G.FLOW_INFER, "f-infer") +
            "<div class='callout warn'><b>Not inference: side channels.</b> These extract hidden values through loopholes. Blizzard closes them case by case and they go against the stated intent; this guide does not show how to build them."
            + ul(G.SIDE_CHANNELS) + "</div>")

def s_hsm(ctx):
    st = table(["State", "Colour", "Meaning"], [[esc(a), "<span class='hsm %s'>%s</span>" % (c, {"g": "green", "y": "yellow", "k": "grey", "r": "red"}[c]), esc(m)] for a, c, m in G.HSM_STATES])
    steps = "<ol>%s</ol>" % "".join("<li><b>%s.</b> %s</li>" % (esc(a), b) for a, b in G.HSM_VERIFY)
    h = ctx["hsm"]
    if h:
        rules = h.get("rules") or []
        rr = []
        for r in rules:
            stt = str(r.get("status", "pending"))
            cls = {"verified": "r-ok", "failing": "r-err", "contradicted": "r-err"}.get(stt, "r-pending")
            rr.append([esc(r.get("id")), esc(r.get("context", "")), esc(r.get("predictions", "")), esc(r.get("verified", "")),
                       esc(r.get("contradicted", "")), esc(r.get("pending", r.get("unverified", ""))), esc(r.get("meanErrorSec", "")),
                       "<span class='%s'>%s</span>" % (cls, esc(stt))])
        res = ("<p class='small'>From <code>%s</code> (build %s, captured %s).</p>" % (esc(ctx["hsm_path"]), esc(h.get("build", "?")), esc(h.get("captured", "?"))) +
               table(["Rule", "Context", "Predictions", "Verified", "Contradicted", "Pending", "Mean error (s)", "Status"], rr))
        inputs = h.get("inputs") or {}
        if inputs:
            ir = [[esc(cx), "<code>%s</code>" % esc(sig), esc(v.get("r", 0)), esc(v.get("u", 0))]
                  for cx, byS in sorted(inputs.items()) if isinstance(byS, dict) for sig, v in sorted(byS.items()) if isinstance(v, dict)]
            res += "<details><summary>Rule-input readability per context</summary><div>%s</div></details>" % table(["Context", "Signal", "Readable", "Unreadable"], ir)
        preds = (h.get("predictions") or [])[:40]
        if preds:
            res += "<details><summary>Sample predictions (first %d)</summary><div>%s</div></details>" % (len(preds), table(
                ["t", "unit", "spell", "kind", "rule", "conf", "outcome", "error (s)"],
                [[esc(p.get(k, "")) for k in ("t", "unit", "spell", "kind", "rule", "conf", "outcome", "errorSec")] for p in preds]))
    else:
        res = (badge("p", "", "no --hsm JSON") + table(["Rule", "Status"], [[esc(p["id"] + ": " + p["title"]), "<span class='r-pending'>pending: no scored capture yet</span>"] for p in G.INFERENCE]))
    return ("<p>%s</p>" % md(G.HSM_INTRO) +
            "<h3>The in-game HSM window</h3>" + ul(G.HSM_WINDOW) +
            "<h3>How to verify predictions with it</h3>" + steps +
            "<h3>Architecture</h3>" + svg_flow(G.FLOW_HSM, "f-hsm") +
            "<h3>State lifecycle</h3>" + st +
            "<h3>Verified vs pending</h3>" + res +
            "<h3>Known failure modes</h3>" + ul(G.HSM_FAILURES) +
            "<h3>Lua skeleton</h3>" + code_block(G.HSM_SKELETON))

SECRET_TAG = re.compile(r"SecretReturns|SecretWhen|SecretIn|SecretOn|SecretPayloads|HasRestrictions|Requires")
FILTER_TAGS = ["SecretReturns", "SecretWhen", "SecretPayloads", "HasRestrictions", "Requires", "NeverSecret", "ConditionalSecret", "SecretValue"]

def system_of(r):
    n = r["name"]
    if r["kind"] == "event":
        return "Events: " + n.split("_")[0] + "_*"
    if "." in n:
        return n.split(".")[0]
    for p in ("Unit", "Get", "Is", "Set", "C"):
        if n.startswith(p):
            return "Global: " + p + "*"
    return "Global: other"

def s_functions(ctx):
    rows = [r for r in ctx["inv"] if r.get("kind") in ("function", "event") and
            (SECRET_TAG.search(r.get("tags") or "") or re.search(r"ConditionalSecret|SecretValue", (r.get("returns_or_payload") or "") + (r.get("struct_fields") or "")))]
    groups = defaultdict(list)
    for r in rows:
        groups[system_of(r)].append(r)
    v = ctx["verify"]
    out = ["<p>%d functions/events from the 70245 docs carry a secrecy predicate, payload tag or precondition (from the inventory TSV). "
           "Grouped by system; search, tag and kind filters need JavaScript (without it everything is listed). 'Observed' joins the user's verify.json.</p>" % len(rows),
           "<div class='filter'><input type='search' id='fn-q' placeholder='Search name, tag, return...' aria-label='Search functions'>"
           "<select id='fn-tag' aria-label='Tag filter'><option value=''>any tag</option>%s</select>"
           "<label><input type='checkbox' class='fn-kind' value='function' checked> functions</label>"
           "<label><input type='checkbox' class='fn-kind' value='event' checked> events</label><span id='fn-count' class='small'></span></div>"
           % "".join("<option value='%s'>%s</option>" % (t, t) for t in FILTER_TAGS)]
    for g in sorted(groups, key=lambda k: (k.startswith("Events"), k.startswith("Global"), k.lower())):
        trs = []
        for r in sorted(groups[g], key=lambda r: r["name"]):
            tags = parse_tags(r.get("tags"))
            tag_html = " ".join("<code class='%s'>%s</code>" % ("", esc(k + ("=" + v_ if v_ and v_ != "true" else ""))) for k, v_ in tags.items())
            ret = (r.get("returns_or_payload") or "")
            sf = r.get("struct_fields") or ""
            ret_s = ret if len(ret) < 170 else ret[:167] + "..."
            fields_note = ""
            if sf:
                fields_note = "<details><summary class='small'>struct fields</summary><div class='small'>%s</div></details>" % esc(sf)
            s = v.summary(r["name"]) if v.ok else None
            obs = ""
            if s:
                sec, clr, nil, cells, note = s
                obs = "S %d / C %d" % (sec, clr) + (" / nil %d" % nil if nil else "")
                if note and "nil/containers" in note:
                    obs += " <span class='small' title='%s'>(v2.1: nil/containers counted clear)</span>" % esc(note)
            search = (r["name"] + " " + (r.get("tags") or "") + " " + ret).lower()
            ttag = " ".join(sorted(set(re.findall(r"(\w+)=", (r.get("tags") or "") + " " + ret + " " + sf))))
            trs.append("<tr data-k='%s' data-s='%s' data-t='%s'><td><code>%s</code></td><td class='small'>%s</td><td class='small'>%s%s</td><td class='small'>%s</td></tr>"
                       % (esc(r["kind"]), esc(search), esc(ttag), esc(r["name"]), tag_html, esc(ret_s), fields_note, obs))
        out.append("<details class='fn-group'><summary>%s <span class='small'>(%d)</span></summary><div><div class='tbl'><table><thead><tr><th>Name</th><th>Tags</th><th>Returns / payload</th><th>Observed</th></tr></thead><tbody>%s</tbody></table></div></div></details>"
                   % (esc(g), len(groups[g]), "".join(trs)))
    return "".join(out)

def s_observed(ctx):
    v = ctx["verify"]
    out = [ul(G.FOREVER_SPECIFICS)]
    if v.ok:
        sc = v.meta.get("statusCounts", {})
        out.append("<p>verify.json (%s, %s): %s.</p>" % (esc(v.meta.get("build")), esc(v.meta.get("dataVersion")), esc(", ".join("%s %s" % (k, n) for k, n in sorted(sc.items())))))
        sec_rows = []
        for key, rs in v.rows.items():
            for r in rs:
                if r.get("secret", 0) > 0 and r.get("status") == "CONFIRMED":
                    sec_rows.append([("<code>%s</code>" % esc(key)) + (" <span class='small'>%s</span>" % esc(r.get("name") or r.get("field") or "")),
                                     esc(r.get("secret")), esc(r.get("clear")), "<span class='small'>%s</span>" % esc(", ".join(r.get("secretContexts", []))),
                                     "<span class='small'>%s</span>" % esc(", ".join(r.get("clearContexts", []))), esc(r.get("predicate") or r.get("expected") or "")])
        sec_rows.sort(key=lambda x: x[0])
        out.append("<h3>Values observed secret at least once</h3><p class='small'>Context = phase / active restriction / unit (self = you, other = your target).</p>" +
                   table(["Key / return", "Secret", "Clear", "Secret in", "Clear in", "Doc expectation"], sec_rows))
        inc = [[("<code>%s</code>" % esc(k)), esc(r.get("status")), "<span class='small'>%s</span>" % esc(r.get("note"))] for k, rs in sorted(v.rows.items()) for r in rs if r.get("status") == "INCONCLUSIVE"]
        if inc:
            out.append("<h3>Documented secret but never seen secret (inconclusive)</h3><p>%s</p>" % md(
                "These are artefacts of how v2.1 classified samples: nil returns and containers (duration objects) were counted as clear. A duration object is never <code>issecretvalue</code>; ask <code>HasSecretValues()</code> [[d:RESEARCH]].") + table(["Key", "Status", "Note"], inc))
    else:
        out.append(badge("p", "", "no verify.json"))
    lab = ctx["lab"]
    if lab.md:
        out.append("<h3>Lab results (markdown, verbatim)</h3>" + code_block(lab.md, "md"))
    if lab.recs:
        rr = []
        for rec in lab.recs:
            for it in rec.get("items", []) if isinstance(rec, dict) else []:
                extra = {k: v_ for k, v_ in it.items() if k not in ("group", "id", "approach", "available", "ok", "err", "absent")}
                rr.append([esc(rec.get("ctx")), esc(it.get("group")), "<code>%s</code>" % esc(it.get("id")), "<span class='small'>%s</span>" % esc(it.get("approach")),
                           esc(it.get("available")), "<span class='%s'>%s</span>" % ("r-ok" if it.get("ok") else "r-err", esc(it.get("ok"))),
                           "<span class='small'>%s</span>" % esc(it.get("err") or ", ".join(it.get("absent") or [])),
                           "<span class='small'>%s</span>" % esc(json.dumps(extra, sort_keys=True)[:300])])
        out.append("<h3>Lab results</h3>" + table(["Context", "Group", "Item", "Approach", "Available", "OK", "Error / absent", "Readback codes"], rr))
    return "".join(out)

def s_workarounds(ctx):
    out = []
    for pid, title, src, note in G.PATTERNS:
        out.append("<div class='card' id='%s'><h4>%s</h4>%s<p class='small'>%s</p></div>" % (esc(pid), esc(title), code_block(src), md(note)))
    out.append("<p>Combat-specific patterns (cast bars, health bars, auras, dispels, names, damage meter) are in <a href='#combat'>Combat secrets</a>.</p>")
    out.append("<h3>Pitfalls</h3>" + ul(G.PITFALLS))
    return "".join(out)

def s_flows(ctx):
    return svg_flow(G.FLOW_SECRET, "f-secret") + "<p class='small'>More diagrams: restriction lifecycle in <a href='#mechanics'>Mechanics</a>, inference in <a href='#detect'>Detecting state</a>, HSM architecture in <a href='#hsm'>HSM</a>.</p>"

def s_checklist(ctx):
    return "<ol>%s</ol>" % "".join("<li><b>%s.</b> %s</li>" % (esc(a), md(b)) for a, b in G.CHECKLIST)

def s_diag(ctx):
    return table(["Question", "How"], [[esc(a), md(b)] for a, b in G.DIAG])

def s_sources(ctx):
    rows = []
    for sid, (title, url, date, kind, note) in sorted(G.SOURCES.items(), key=lambda kv: (kv[1][3], kv[0])):
        k = {"official": "o", "docs": "d", "community": "c", "verified": "v"}[kind]
        link = "<a href='%s'>%s</a>" % (esc(url), esc(title)) if url else esc(title)
        rows.append(["<span id='src-%s'><code>%s</code></span>" % (esc(sid), esc(sid)), link, "<span class='b b-%s'>%s</span>" % (KIND[k][0], esc(kind)),
                     esc(date), "<span class='small'>%s</span>" % esc(note), esc(USED_SOURCES.get(sid, 0))])
    return ("<p>Blizzard Discord posts need a login; each is mirrored verbatim on the linked Warcraft Wiki page. 'Verified' = the user's own in-game data on Forever 70245.</p>" +
            table(["ID", "Source", "Kind", "Date", "Note", "Cited"], rows))

SECTIONS = [
    ("tldr", "TL;DR and mental model", s_tldr),
    ("combat", "Combat secrets", s_combat),
    ("tokens", "Unit tokens", s_tokens),
    ("changed", "What changed", s_changed),
    ("intent", "Blizzard's intent", s_intent),
    ("mechanics", "Mechanics: restrictions, predicates, containers, taint", s_mechanics),
    ("ops", "Operations matrix", s_ops),
    ("detect", "Detecting state and inference", s_detect),
    ("hsm", "Hybrid state machine (HSM)", s_hsm),
    ("functions", "Impacted functions and events", s_functions),
    ("observed", "Observed on Forever 70245", s_observed),
    ("workarounds", "Workarounds and porting patterns", s_workarounds),
    ("flows", "Flowcharts", s_flows),
    ("checklist", "Migration checklist", s_checklist),
    ("diagnose", "Detect, log, diagnose", s_diag),
    ("sources", "Sources", s_sources),
]

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--inventory", default=DEF_INV)
    ap.add_argument("--research", default=DEF_RES)
    ap.add_argument("--verify", default=DEF_VERIFY if os.path.exists(DEF_VERIFY) else None)
    ap.add_argument("--lab")
    ap.add_argument("--combat")
    ap.add_argument("--hsm")
    ap.add_argument("--out", default=DEF_OUT)
    a = ap.parse_args(argv)
    inv = load_inventory(a.inventory)
    ctx = {"inv": inv, "inv_by_name": {r["name"]: r for r in inv if r.get("kind") in ("function", "event")},
           "inv_path": os.path.relpath(a.inventory, HERE), "res_path": os.path.relpath(a.research, HERE),
           "research": load_research(a.research), "verify_path": a.verify,
           "verify": Verify(load_json(a.verify, "verify json")), "lab": Lab(a.lab),
           "combat_path": a.combat, "combat": combat_obs(load_json(a.combat, "combat json")),
           "hsm_path": a.hsm, "hsm": load_json(a.hsm, "hsm json"),
           "now": datetime.datetime.now().strftime("%Y-%m-%d %H:%M")}
    body = []
    for i, (sid, title, fn) in enumerate(SECTIONS, 1):
        body.append(section(sid, i, title, fn(ctx)))
    head = s_header(ctx)
    sources_html = body.pop()  # re-render sources last so citation counts are complete
    body.append(section("sources", len(SECTIONS), "Sources", s_sources(ctx)))
    toc = "<ol>%s</ol>" % "".join("<li><a href='#%s'>%s</a></li>" % (sid, esc(t)) for sid, t, _ in SECTIONS)
    doc = ("<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'>"
           "<meta name='color-scheme' content='light dark'><title>WoW Forever secret values: migration guide</title><style>%s</style></head>"
           "<body><div class='wrap'><nav class='toc' aria-label='Contents'><b>Contents</b>%s<p class='meta'>Forever 1.60.1.70245<br>generated %s ET</p></nav>"
           "<main>%s%s</main></div><script>%s</script></body></html>") % (CSS, toc, esc(ctx["now"]), head, "".join(body), JS)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(doc)
    unknown = [s for s in USED_SOURCES if s not in G.SOURCES]
    print("wrote %s (%d bytes); %d sources cited, %d unknown, %d warnings" % (a.out, len(doc.encode("utf-8")), len(USED_SOURCES), len(unknown), len(WARN)))
    return 0

if __name__ == "__main__":
    sys.exit(main())
