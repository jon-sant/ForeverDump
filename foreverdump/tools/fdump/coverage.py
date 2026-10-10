"""Combat-event coverage matrix + live attribution scoring (v2.2.4, run 5).

Ground truth: the WoWCombatLog file (written by the client; read offline only). Live: what ForeverDump could read
during the capture WITHOUT CLEU - ForeverDumpCombatLogDB session events (UNIT_COMBAT, UNIT_AURA payload classification,
UNIT_SPELLCAST_*, PLAYER_SWING, DAMAGE_METER_*), ForeverDumpRecordDB (UNIT_POWER_FREQUENT, UNIT_HEALTH,
PLAYER_TOTEM_UPDATE), the inference signals and the post-combat C_DamageMeter reads.

  coverage(dump, fx, player)  -> dict (coverage.json)
  markdown(res)               -> COVERAGE.md
  guide_json(res)             -> the guide's --coverage input (no names, no GUIDs)

Source/target classes: me, mine (my totems/pets: SPELL_SUMMON by me), player (another player), npc. Context: combat =
inside a PLAYER_REGEN_DISABLED..ENABLED window of the live capture, else ooc.
"""
import bisect
import collections
import re
import os

from fdump import combatlog
from fdump import inference as infmod
from fdump.xref import anchor_epoch
from fdump.dump import as_list

LAG_BEFORE, LAG_AFTER = 0.35, 1.2   # UNIT_COMBAT vs file timestamp (melee combat text lags ~0.46 s, max 0.98 s)
FRAME = 0.06

CATS = [
    ("damage", "damage amounts (SPELL/SWING/RANGE/PERIODIC_DAMAGE)"),
    ("miss", "misses (SWING/SPELL_MISSED, any missType)"),
    ("crit", "critical hits (damage/heal with critical flag)"),
    ("overkill", "overkill > 0"),
    ("absorb", "absorbs (absorbed > 0 or missType ABSORB)"),
    ("heal", "heals (SPELL_HEAL / SPELL_PERIODIC_HEAL)"),
    ("energize", "mana/power gain (SPELL_ENERGIZE / PERIODIC_ENERGIZE)"),
    ("aura+", "buff/debuff applied/refreshed"),
    ("aura-", "buff/debuff removed"),
    ("cast-start", "cast start (SPELL_CAST_START)"),
    ("cast-success", "cast success (SPELL_CAST_SUCCESS)"),
    ("cast-fail", "cast failed (SPELL_CAST_FAILED)"),
    ("interrupt", "interrupts (SPELL_INTERRUPT)"),
    ("dispel", "dispels (SPELL_DISPEL / _FAILED / STOLEN)"),
    ("summon", "summons (SPELL_SUMMON: totems)"),
    ("death", "deaths (UNIT_DIED)"),
]
CAT_NOTE = dict(CATS)


def _num(v):
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None


def _cats(e):
    """file event -> [(category, detail dict)]"""
    sub, a = e["sub"], e["a"]
    out = []
    if sub.endswith("_DAMAGE") and not sub.endswith("_LANDED") or sub == "DAMAGE_SPLIT":
        base = 11 if sub.startswith("SWING") else (12 if sub.startswith("ENVIRONMENTAL") else 14)
        amt = _num(a[base]) if len(a) > base else None
        ok = _num(a[base + 1]) if len(a) > base + 1 else None
        ab = _num(a[base + 5]) if len(a) > base + 5 else None
        crit = a[base + 6] if len(a) > base + 6 else None
        d = {"amount": amt or 0, "spell": a[11] if base == 14 else None, "school": a[base + 2] if len(a) > base + 2 else None}
        out.append(("damage", d))
        if crit in (1, True, "1"):
            out.append(("crit", d))
        if ok and ok > 0:
            out.append(("overkill", dict(d, overkill=ok)))
        if ab and ab > 0:
            out.append(("absorb", d))
    elif sub.endswith("_MISSED"):
        mt = a[11] if sub.startswith("SWING") else (a[14] if len(a) > 14 else None)
        d = {"amount": 0, "missType": mt, "spell": a[11] if not sub.startswith("SWING") else None}
        out.append(("miss", d))
        if mt == "ABSORB":
            out.append(("absorb", d))
    elif sub.endswith("_HEAL") and sub.startswith("SPELL"):
        amt = _num(a[14]) if len(a) > 14 else 0
        oh = _num(a[15]) if len(a) > 15 else 0
        d = {"amount": amt or 0, "overheal": oh or 0, "spell": a[11]}
        out.append(("heal", d))
        if len(a) > 17 and a[17] in (1, True, "1"):
            out.append(("crit", d))
    elif sub.endswith("_ENERGIZE"):
        out.append(("energize", {"amount": _num(a[14]) if len(a) > 14 else None, "spell": a[11]}))
    elif sub in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH", "SPELL_AURA_APPLIED_DOSE"):
        out.append(("aura+", {"spell": a[11], "auraType": a[14] if len(a) > 14 else None}))
    elif sub in ("SPELL_AURA_REMOVED", "SPELL_AURA_REMOVED_DOSE"):
        out.append(("aura-", {"spell": a[11], "auraType": a[14] if len(a) > 14 else None}))
    elif sub == "SPELL_CAST_START":
        out.append(("cast-start", {"spell": a[11]}))
    elif sub == "SPELL_CAST_SUCCESS":
        out.append(("cast-success", {"spell": a[11]}))
    elif sub == "SPELL_CAST_FAILED":
        out.append(("cast-fail", {"spell": a[11]}))
    elif sub == "SPELL_INTERRUPT":
        out.append(("interrupt", {"spell": a[11]}))
    elif sub in ("SPELL_DISPEL", "SPELL_DISPEL_FAILED", "SPELL_STOLEN"):
        out.append(("dispel", {"spell": a[11]}))
    elif sub == "SPELL_SUMMON":
        out.append(("summon", {"spell": a[11]}))
    elif sub == "UNIT_DIED":
        out.append(("death", {}))
    return out


def _sess_dur(s):
    a, b = s.get("startTime"), s.get("stopTime")
    return (b - a) if isinstance(a, (int, float)) and isinstance(b, (int, float)) else None


def main_session(sessions, min_sec=30):
    """v2.2.9 (run 8): the capture to analyse = the NEWEST substantial one. A trailing capture that is shorter than
    min_sec with no combat (an accidental FD_Logs ON/OFF click at the end, run 7's 3.8 s idle capture) is skipped and
    reported, instead of becoming 'the' capture. Returns (session, skipped_trailing_sessions)."""
    ss = [s for s in as_list(sessions) if isinstance(s, dict)]
    skipped = []
    for s in reversed(ss):
        d = _sess_dur(s)
        trivial = d is not None and d < min_sec and not (s.get("combatEvents") or 0) and not (s.get("cleuTotal") or 0)
        if not trivial:
            return s, skipped
        skipped.append(s)
    return (ss[-1] if ss else {}), []


class Live:
    """the capture's live streams on the epoch timebase"""

    def __init__(self, dump):
        cl = as_list((dump.combatlog or {}).get("sessions"))
        self.cs, self.skipped = main_session(cl)
        anc = self.cs.get("anchor") or (dump.log.get("inference") or {}).get("anchor") or {}
        self.anchor = anc
        self.ep = lambda t: anchor_epoch(anc, t)[0]
        self.events = []
        for e in as_list(self.cs.get("events")):
            te = self.ep(e.get("t"))
            if te is not None:
                self.events.append(dict(e, te=te))
        rs = as_list((dump.record or {}).get("sessions"))
        self.record = []
        if rs:
            want = self.cs.get("captureSid")
            rsel = next((r for r in reversed(rs) if isinstance(r, dict) and want and r.get("captureSid") == want), rs[-1])
            ranc = rsel.get("anchor") or anc
            for e in as_list(rsel.get("events")):
                te = anchor_epoch(ranc, e.get("t"))[0]
                if te is not None:
                    self.record.append(dict(e, te=te))
        inf = dump.log.get("inference") or {}
        self.inf = inf
        self.signals = []
        for s in as_list(inf.get("signals")):
            te = self.ep(s.get("t"))
            if te is not None:
                self.signals.append(dict(s, te=te))
        self.span = (min((e["te"] for e in self.events), default=None), max((e["te"] for e in self.events), default=None))
        # combat windows
        self.combat = []
        start = None
        for e in self.events:
            if e["e"] == "PLAYER_REGEN_DISABLED":
                start = e["te"]
            elif e["e"] == "PLAYER_REGEN_ENABLED" and start is not None:
                self.combat.append((start, e["te"]))
                start = None
        if start is not None:
            self.combat.append((start, self.span[1]))
        # target timeline (PLAYER_TARGET_CHANGED signals carry the clear GUID; aura/cast signals on "target" refine it)
        tl = []
        for s in self.signals:
            if s.get("e") == "target" or (s.get("unit") == "target" and s.get("guid")):
                tl.append((s["te"], s.get("guid")))
        tl.sort(key=lambda x: x[0])
        self.tl_t = [x[0] for x in tl]
        self.tl_g = [x[1] for x in tl]
        self.by = collections.defaultdict(list)
        for e in self.events + self.record:
            self.by[e.get("e")].append(e)
        for k in self.by:
            self.by[k].sort(key=lambda x: x["te"])

    target_source = "live-signals"
    cast_source = "live-signals"

    def fill_targets_from_log(self, fx, player):
        """v2.2.7 (runs 6/6b): when the capture has no live target timeline (the HSM did not run, so no PLAYER_TARGET_CHANGED
        signals with a GUID), rebuild it from MY offensive log events (cast/damage at an NPC = what I was targeting).
        Labelled 'log-inferred' in every report: it scores what live COULD see on the target, not what the engine saw."""
        if self.tl_t or not player:
            return False
        tl = []
        own = ("SPELL_CAST_SUCCESS", "SPELL_CAST_START", "SPELL_DAMAGE", "SWING_DAMAGE", "SWING_DAMAGE_LANDED", "RANGE_DAMAGE",
               "SPELL_MISSED", "SWING_MISSED", "SPELL_AURA_APPLIED")
        for e in fx.get("events", []):
            a = e.get("a") or []
            if not e.get("cleu") or len(a) < 8 or e.get("sub") not in own or a[3] != player:
                continue
            if str(a[7]).startswith(("Creature-", "Vehicle-")):
                tl.append((e["t"], a[7]))
        if not tl:
            return False
        tl.sort(key=lambda x: x[0])
        self.tl_t = [x[0] - 0.05 for x in tl]   # the target was selected before my action landed
        self.tl_g = [x[1] for x in tl]
        self.target_source = "log-inferred"
        return True

    def ctx(self, t):
        for lo, hi in self.combat:
            if lo <= t <= hi:
                return "combat"
        return "ooc"

    def target_at(self, t):
        i = bisect.bisect_right(self.tl_t, t + 0.01) - 1
        return self.tl_g[i] if i >= 0 else None

    def near(self, ev, t, lo, hi, pred=None):
        lst = self.by.get(ev) or []
        ts = [x["te"] for x in lst]
        i = bisect.bisect_left(ts, t - lo)
        best = None
        while i < len(lst) and lst[i]["te"] <= t + hi:
            x = lst[i]
            if pred is None or pred(x):
                if best is None or abs(x["te"] - t) < abs(best["te"] - t):
                    best = x
            i += 1
        return best


def _args(e):
    return as_list(e.get("a")) if isinstance(e.get("a"), list) else []


def _secret(v):
    return isinstance(v, str) and v.startswith("<secret")


def classes(fx, player):
    pets = set()
    for e in fx.get("events", []):
        if e.get("cleu") and e["sub"] == "SPELL_SUMMON" and e["a"][3] == player:
            pets.add(e["a"][7])

    def cls(g):
        if not g or g == "0000000000000000":
            return "none"
        if g == player:
            return "me"
        if g in pets:
            return "mine"
        return "player" if str(g).startswith("Player-") else ("npc" if str(g).startswith(("Creature-", "Vehicle-")) else "other")
    return cls, pets


# ------------------------------------------------------------------ live replay (HSM attribution)
def _knowledge_events(dump, t0, reparse=None):
    """Python port of Knowledge.ToHSM for the SV spell knowledge (clear, collected out of combat). reparse = {id: parsed}
    from the CURRENT parser (knowlint.reparse): stored v2.2.3 parses had e.g. Earth Shock lockout 2 s as an aura."""
    out = []
    kdb = dump.db.get("knowledge") if isinstance(getattr(dump, "db", None), dict) else None
    for b in ((kdb or {}).values() if isinstance(kdb, dict) else []):
        for sid, e in (((b or {}).get("spells") or {}).items() if isinstance(b, dict) else []):
            try:
                sid = int(sid)
            except (TypeError, ValueError):
                continue
            d = (e or {}).get("data") or {}
            p = d.get("parsed") or {}
            if reparse and isinstance(reparse.get(sid), dict):
                p = reparse[sid]
            k = {}
            if p.get("auraDuration"):
                k["aura"] = {"duration": p["auraDuration"], "helpful": True if d.get("IsSpellHelpful") is True else None}
            if d.get("IsSpellHelpful") is True:
                k["helpful"] = True
            elif d.get("IsSpellHarmful") is True:
                k["harmful"] = True
            if p.get("summon"):
                k["summon"] = {"duration": p.get("summonDuration"), "name": p.get("summonName")}
            ln = (e or {}).get("learned") or {}
            if ln.get("auraDuration") or ln.get("untilCancelled"):
                au = k.setdefault("aura", {})
                au["duration"] = ln.get("auraDuration") or (au.get("duration") if not ln.get("untilCancelled") else None)
                if ln.get("helpful") is not None:
                    au["helpful"] = ln["helpful"]
                if ln.get("self"):
                    au["self"] = True
            if isinstance(d.get("baseCooldown"), (int, float)) and d["baseCooldown"] > 0:
                k["cooldown"] = d["baseCooldown"] / 1000.0
            if isinstance(d.get("baseGCD"), (int, float)):
                k["gcd"] = d["baseGCD"] / 1000.0
            if p.get("interrupt"):
                k["interrupt"] = True
                k["lockout"] = p.get("lockout")
            if p.get("consumable") and "aura" in k:
                k["aura"]["consumable"] = True
            if isinstance(d.get("info.castTime"), (int, float)):
                k["castTime"] = d["info.castTime"] / 1000.0
            if p.get("amountMin"):
                k["amount"] = {"min": p["amountMin"], "max": p.get("amountMax"), "kind": p.get("amountKind")}
            if k:
                out.append(dict(k, t=t0, k="learn", spell=sid))
    return out


def _dm_records(dump, live):
    """post-combat DM totals per fight: v2.2.4 DamageMeter.lua reads, else the v2.2 CombatLog snapshots"""
    recs = []
    for r in as_list((dump.log.get("damageMeter") or {}).get("fights")):
        te = live.ep(r.get("t"))
        ty = r.get("types") or {}
        dd, hd, it = ty.get("DamageDone") or {}, ty.get("HealingDone") or {}, ty.get("Interrupts") or {}
        spells = {int(k): (v.get("amount") if isinstance(v, dict) else v) for k, v in (r.get("spells") or {}).items()}
        sources = {}
        for name, block in ty.items():
            if isinstance(block, dict) and isinstance(block.get("sources"), list):
                sources[name] = block["sources"]
        recs.append({"te": te, "source": "DamageMeter.lua", "damage": dd.get("me"), "others": dd.get("others"), "healing": hd.get("me"),
                     "interrupts": it.get("me"), "dispels": (ty.get("Dispels") or {}).get("me"),
                     "taken": (ty.get("DamageTaken") or {}).get("me"), "dur": dd.get("dur"), "spells": spells,
                     "enemy": (ty.get("EnemyDamageTaken") or {}).get("total"),
                     "sources": sources or None, "deep": r.get("deep"),
                     "nSources": sum(len(v) for v in sources.values()) if sources else 0})
    if recs:
        return recs
    for s in as_list(live.cs.get("damageMeter")):
        if s.get("inCombat"):
            continue
        bt = s.get("byType") or {}

        def mine(name):
            v = bt.get(name) or {}
            tot = 0
            found = False
            for src in as_list(v.get("combatSources")) if isinstance(v.get("combatSources"), list) else []:
                if isinstance(src, dict) and src.get("isLocalPlayer") is True and isinstance(src.get("totalAmount"), (int, float)):
                    tot += src["totalAmount"]
                    found = True
            return tot if found else (0 if isinstance(v.get("totalAmount"), (int, float)) else None)

        def others(name):
            v = bt.get(name) or {}
            return sum(src.get("totalAmount") or 0 for src in (v.get("combatSources") if isinstance(v.get("combatSources"), list) else [])
                       if isinstance(src, dict) and src.get("isLocalPlayer") is not True)
        te = s.get("time")
        if s.get("gameTime") is not None:
            te = live.ep(s["gameTime"]) or te
        recs.append({"te": te, "source": "CombatLog snapshot", "reason": s.get("reason"), "damage": mine("DamageDone"),
                     "others": others("DamageDone"), "healing": mine("HealingDone"), "interrupts": mine("Interrupts"),
                     "taken": mine("DamageTaken"), "dur": (bt.get("DamageDone") or {}).get("durationSeconds"),
                     "enemy": (bt.get("EnemyDamageTaken") or {}).get("totalAmount"), "spells": None})
    return recs


ENEMY_CAST_EVENTS = ("UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
                     "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP")


CAST_EVENTS_PLAYER = ("UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
                      "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP")


def group_size(dump, span=None):
    """largest group size recorded in the replay tape headers of sessions overlapping span (None = unknown)"""
    log = getattr(dump, "log", None) or {}
    best, best_any = None, None
    for s in as_list((log.get("replay") or {}).get("sessions")):
        if not isinstance(s, dict):
            continue
        h = s.get("hdr") or {}
        g = max([x for x in (h.get("groupSize"), h.get("groupSizeEnd")) if isinstance(x, (int, float))] or [0])
        if not g:
            continue
        best_any = max(best_any or 0, g)
        t0 = h.get("t0")
        if span and span[0] is not None and isinstance(t0, (int, float)) and span[0] - 120 <= t0 <= (span[1] or t0):
            best = max(best or 0, g)
    return int(best or best_any) if (best or best_any) else None


def build_stream(dump, live, player, hpmax_standin=None, reparse=None, seed_events=None):
    """live events -> HybridState replay stream (same library as the addon). Each scorable event carries ref = index."""
    ev = []
    refs = {}
    t0 = (live.span[0] or 0) - 1
    ev += _knowledge_events(dump, t0, reparse)
    # v2.2.12: group size of the capture (ReplayLog tape header, clear GetNumGroupMembers) -> the engine's dm-frame gate
    gs = group_size(dump, live.span)
    if gs:
        ev.append({"t": t0, "k": "group", "size": gs})
    my = player
    # casts from the inference signals (they carry the HSM unit key and target)
    for s in live.signals:
        if s.get("e") == "cast" and s.get("unit") in ("player", "target"):
            unit = "player" if s["unit"] == "player" else (s.get("guid") or "target")
            ev.append({"t": s["te"], "k": "cast", "ev": "UNIT_SPELLCAST_" + str(s.get("ev")), "unit": unit, "spell": s.get("sid"),
                       "player": s["unit"] == "player", "target": s.get("target")})
        elif s.get("e") == "aura" and s.get("unit") in ("player", "target"):
            unit = "player" if s["unit"] == "player" else (s.get("guid") or "target")
            ev.append({"t": s["te"], "k": "aura", "unit": unit, "added": as_list(s.get("adds")), "removed": as_list(s.get("rems")),
                       "full": s.get("full"), "_tok": s["unit"]})
    # v2.2.7 (run 6 interrupt scored 0/1): with the HSM down there are no cast signals, so the replay saw no own cast and
    # the interrupt fell to elimination. Rebuild player casts from the raw UNIT_SPELLCAST_* records (spellID is clear for
    # the player), mirroring Inference.lua's target choice. Labelled live.cast_source = "raw-events".
    if not any(x["k"] == "cast" for x in ev):
        kn = reparse or {}
        for e in live.events:
            name, a = e["e"], _args(e)
            if name not in CAST_EVENTS_PLAYER or not a or a[0] != "player":
                continue
            sid = a[2] if len(a) > 2 and isinstance(a[2], int) else None
            target = None
            if name == "UNIT_SPELLCAST_SUCCEEDED":
                g = live.target_at(e["te"])
                k = kn.get(sid) or kn.get(str(sid)) or {} if sid is not None else {}
                k = k if isinstance(k, dict) else {}
                aura = k.get("aura") if isinstance(k.get("aura"), dict) else {}
                hostile = bool(g) and str(g).startswith(("Creature-", "Vehicle-"))
                if aura.get("self") or k.get("summon") or (k.get("helpful") and (hostile or not g)):
                    target = "player"
                else:
                    target = g or "player"
            ev.append({"t": e["te"], "k": "cast", "ev": name, "unit": "player", "spell": sid, "player": True, "target": target})
            live.cast_source = "raw-events"
    # secret added-aura flag from the session payload classification
    secret_adds = {}
    secret_rems = {}
    for e in live.by.get("UNIT_AURA", []):
        a = _args(e)
        if len(a) > 1 and a[0] in ("player", "target") and isinstance(a[1], dict) and _secret(a[1].get("addedAuras")):
            secret_adds[(a[0], round(e["te"], 2))] = True
        if len(a) > 1 and a[0] in ("player", "target") and isinstance(a[1], dict) and _secret(a[1].get("removedAuraInstanceIDs")):
            secret_rems[(a[0], round(e["te"], 2))] = True
    n = 0
    for x in ev:
        if x["k"] == "aura" and secret_adds.get((x.get("_tok"), round(x["t"], 2))):
            x["addedSecret"] = True
            x["ref"] = "a%d" % n
            refs[x["ref"]] = x
            n += 1
    for x in ev:
        if x["k"] == "aura" and secret_rems.get((x.get("_tok"), round(x["t"], 2))):
            x["removedSecret"] = True
        x.pop("_tok", None)
    for e in live.events:
        name, a = e["e"], _args(e)
        if name in ("PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"):
            ev.append({"t": e["te"], "k": "combat", "on": name == "PLAYER_REGEN_DISABLED"})
        elif name == "PLAYER_SWING":
            ev.append({"t": e["te"], "k": "swing"})
        elif name == "DAMAGE_METER_COMBAT_SESSION_UPDATED" and a and isinstance(a[0], (int, float)):
            ev.append({"t": e["te"], "k": "dm", "type": a[0]})
        elif name == "UNIT_COMBAT" and a and a[0] in ("player", "target"):
            unit = "player" if a[0] == "player" else (live.target_at(e["te"]) or "target")
            r = "u%d" % n
            n += 1
            x = {"t": e["te"], "k": "uc", "unit": unit, "action": a[1] if len(a) > 1 else None, "flag": a[2] if len(a) > 2 else None,
                 "amount": a[3] if len(a) > 3 and isinstance(a[3], (int, float)) else None,
                 "school": a[4] if len(a) > 4 and isinstance(a[4], (int, float)) else None, "player": a[0] == "player", "ref": r}
            refs[r] = dict(x, tok=a[0])
            ev.append(x)
        elif name == "UNIT_SPELLCAST_INTERRUPTED" and a and a[0] == "target":
            r = "i%d" % n
            n += 1
            x = {"t": e["te"], "k": "interrupt", "unit": live.target_at(e["te"]) or "target", "ref": r}
            refs[r] = x
            ev.append(x)
    # v2.2.4 MINOR 4: enemy cast timing (target token, hostile = Creature GUID), player cast fails, health events
    for e in live.events:
        name, a = e["e"], _args(e)
        if not a:
            continue
        if name.startswith("UNIT_SPELLCAST_") and a[0] == "target" and name in ENEMY_CAST_EVENTS:
            g = live.target_at(e["te"])
            if g and str(g).startswith(("Creature-", "Vehicle-")):
                bar = a[4] if name == "UNIT_SPELLCAST_INTERRUPTED" and len(a) > 4 else (a[3] if len(a) > 3 else None)
                ev.append({"t": e["te"], "k": "ecast", "ev": name, "unit": g, "bar": bar if isinstance(bar, str) and not _secret(bar) else None})
        elif name in ("UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET") and a[0] == "player" and len(a) > 2 and isinstance(a[2], int):
            ev.append({"t": e["te"], "k": "failed", "spell": a[2], "ev": name})
        elif name == "UNIT_HEALTH" and a[0] == "player":
            ev.append({"t": e["te"], "k": "hpevt", "unit": "player"})
    # v2.2.4 CooldownTracker: SPELL_UPDATE_COOLDOWN payloads (clear; RecordDB + 'cdp' signals), isActive/isOnGCD reads
    seen_cdp = {}
    for e in live.by.get("SPELL_UPDATE_COOLDOWN", []):
        a = _args(e)
        if a and isinstance(a[0], int) and len(a) > 3:
            key = (a[0], a[2] if isinstance(a[2], int) else None, a[3] if isinstance(a[3], int) else None)
            if seen_cdp.get(a[0]) != key:
                seen_cdp[a[0]] = key
                ev.append({"t": e["te"], "k": "cdp", "spell": a[0], "cat": key[1], "src": key[2]})
    for s_ in live.signals:
        if s_.get("e") == "cdp" and isinstance(s_.get("id"), int):
            ev.append({"t": s_["te"], "k": "cdp", "spell": s_["id"], "cat": s_.get("cat"), "src": s_.get("src")})
        elif s_.get("e") == "cdobs" and isinstance(s_.get("id"), int):
            ev.append({"t": s_["te"], "k": "cdobs", "spell": s_["id"], "a": s_.get("a"), "g": s_.get("g"), "r": s_.get("r"), "du": s_.get("du")})
    for x in (seed_events or []):
        ev.append(dict(x, t=t0))
    for s_ in live.signals:
        if s_.get("e") == "hpmax" and isinstance(s_.get("v"), (int, float)):
            ev.append({"t": s_["te"], "k": "hpmax", "unit": "player", "v": s_["v"]})
    if hpmax_standin and not any(x["k"] == "hpmax" for x in ev):
        # captures before v2.2.4 did not record UnitHealthMax(player) (clear live; now recorded): the log's advanced
        # maxHP stands in so the estimator can be scored. Marked in the report.
        ev.append({"t": t0, "k": "hpmax", "unit": "player", "v": hpmax_standin, "standin": True})
    # ledger probes: what the HSM believes is on player/target from cached clear aura data, every 1 s in combat
    for lo, hi in live.combat:
        t = lo + 0.5
        while t < hi:
            g = live.target_at(t)
            ev.append({"t": t, "k": "probe", "units": ["player"] + ([g] if g else [])})
            t += 1.0
    for d in _dm_records(dump, live):
        if d.get("te") is not None:
            ev.append({"t": d["te"], "k": "dmrec", "damage": d.get("damage"), "healing": d.get("healing"), "interrupts": d.get("interrupts"),
                       "dispels": d.get("dispels"), "taken": d.get("taken"), "spells": d.get("spells") or None,
                       "sources": d.get("sources") or None})
    order = {"group": 0, "learn": 0, "cdseed": 0, "hpmax": 0, "cdp": 1, "cdobs": 3, "combat": 1, "dm": 2, "swing": 3, "cast": 4, "failed": 4, "ecast": 5, "aura": 5, "uc": 6, "hpevt": 6,
             "interrupt": 7, "dmrec": 8, "probe": 9}
    ev.sort(key=lambda x: (x["t"], order.get(x["k"], 9)))
    return ev, refs


# v2.2.16 attribution safety: same-class actor census for the ambiguity guard. Live it comes from the 'census' signal
# (clear UnitClass of group members / enemy plates, Inference.lua). Captures before v2.2.16 have none: an offline
# stand-in from the combat log counts other players who cast one of MY class spells (spells I cast that are not
# generic: cast by <= 40 % of all casters, auto attack/shot excluded). Friendly = seen so far (roster presence),
# enemy = seen in the last 60 s (plates come and go). Used only by the replay scorer, never at runtime.
GENERIC_SPELLS = {6603, 75}


def census_casts(fx):
    casts = []
    for e in fx.get("events", []):
        if e.get("cleu") and e["sub"] == "SPELL_CAST_SUCCESS":
            a = e["a"]
            if len(a) > 11 and isinstance(a[3], str) and a[3].startswith("Player-"):
                casts.append((e["t"], a[3], a[11], a[5] if isinstance(a[5], int) else 0))
    return casts


def census_standin(fx, player, step=2.0, enemy_window=60.0, casts=None):
    casts = [c for c in (casts if casts is not None else census_casts(fx))
             if isinstance(c[1], str) and c[1].startswith("Player-")]
    casts = [(t, g, sp, fl if isinstance(fl, int) else 0) for t, g, sp, fl in casts]
    if not casts:
        return []
    mine = {sp for _, g, sp, _ in casts if g == player and sp not in GENERIC_SPELLS}
    by_spell = collections.defaultdict(set)
    allc = set()
    for _, g, sp, _ in casts:
        by_spell[sp].add(g)
        allc.add(g)
    cls_spells = {sp for sp in mine if len(by_spell[sp]) <= max(2, 0.4 * len(allc))}
    out, friendly, enemy_last, last = [], set(), {}, None
    casts.sort()
    i, t, t_end = 0, casts[0][0], casts[-1][0]
    while t <= t_end + step:
        while i < len(casts) and casts[i][0] <= t:
            tc, g, sp, fl = casts[i]
            if g != player and sp in cls_spells:
                if fl & 0x40:
                    enemy_last[g] = tc
                else:
                    friendly.add(g)
            i += 1
        en = sum(1 for g, tc in enemy_last.items() if t - tc <= enemy_window)
        cur = (len(friendly), en)
        if cur != last:
            out.append({"t": t, "k": "census", "sameClass": cur[0], "sameClassEnemy": cur[1], "standin": True})
            last = cur
        t += step
    return out


def census_live(live):
    return [{"t": s_["te"], "k": "census", "sameClass": s_.get("same") or 0, "sameClassEnemy": s_.get("sameEnemy") or 0}
            for s_ in live.signals if s_.get("e") == "census" and s_.get("te") is not None]


def add_census(stream, cen):
    """merge census events into a sorted replay stream (they apply before same-time events)"""
    if not cen:
        return stream
    out = list(stream) + [dict(c) for c in cen]
    out.sort(key=lambda x: (x["t"], 0 if x["k"] == "census" else 1))
    return out


# ------------------------------------------------------------------ truth matching
def _truth_uc(refs, fx, cls, player, live):
    """ref -> truth source class for UNIT_COMBAT / interrupt / secret aura events"""
    dmg, heals, auras, ints = [], [], [], []
    for e in fx.get("events", []):
        if not e.get("cleu"):
            continue
        a, sub = e["a"], e["sub"]
        for cat, d in _cats(e):
            if cat in ("damage", "miss"):
                dmg.append((e["t"], d.get("amount") or 0, cls(a[3]), a[7], cat, d))
            elif cat == "heal":
                heals.append((e["t"], d.get("amount") or 0, cls(a[3]), a[7], d))
            elif cat == "aura+":
                auras.append((e["t"], cls(a[3]), a[7], d))
            elif cat == "interrupt":
                ints.append((e["t"], cls(a[3]), a[7]))
    used = set()
    out = {}
    for r, x in sorted(refs.items(), key=lambda kv: kv[1]["t"]):
        t = x["t"]
        if x["k"] == "uc":
            act = x.get("action")
            dst = player if x.get("player") else x.get("unit")
            if act == "HEAL":
                best = None
                for i, h in enumerate(heals):
                    if ("h", i) in used or h[3] != dst:
                        continue
                    dt = t - h[0]
                    if -LAG_BEFORE <= dt <= LAG_AFTER and h[1] == x.get("amount"):
                        if best is None or abs(dt) < abs(t - heals[best][0]):
                            best = i
                if best is not None:
                    used.add(("h", best))
                    out[r] = {"src": heals[best][2], "cat": "heal", "dt": round(t - heals[best][0], 3), "amount": heals[best][1],
                              "overheal": heals[best][4].get("overheal")}
                continue
            best = None
            for i, d in enumerate(dmg):
                if ("d", i) in used or d[3] != dst:
                    continue
                dt = t - d[0]
                okamt = (d[1] == x.get("amount")) if act == "WOUND" else (d[4] == "miss" or d[1] == 0)
                if -LAG_BEFORE <= dt <= LAG_AFTER and okamt:
                    if best is None or abs(dt) < abs(t - dmg[best][0]):
                        best = i
            if best is not None:
                used.add(("d", best))
                d = dmg[best]
                out[r] = {"src": d[2], "cat": d[4], "dt": round(t - d[0], 3), "amount": d[1], "school": d[5].get("school")}
        elif x["k"] == "interrupt":
            best = min(ints, key=lambda i: abs(i[0] - t), default=None)
            if best and abs(best[0] - t) <= 0.3:
                out[r] = {"src": best[1], "cat": "interrupt"}
            else:
                out[r] = {"src": "none-in-log", "cat": "interrupt"}
        elif x["k"] == "aura":
            unit = x.get("unit")
            cand = [au for au in auras if abs(au[0] - t) <= 0.35 and (au[2] == (player if unit == "player" else unit))]
            if cand:
                srcs = set(c[1] for c in cand)
                out[r] = {"src": "me" if srcs & {"me", "mine"} else sorted(srcs)[0], "cat": "aura+", "n": len(cand)}
    return out


def _mine(c):
    return c in ("me", "mine")


def score(attrs, truth, refs):
    """per category: n, attributed, correct, false-self (claimed mine, truth other), missed-self"""
    cats = collections.defaultdict(lambda: collections.Counter())
    rows = []
    for at in attrs:
        r = at.get("ref")
        tr = truth.get(r)
        x = refs.get(r) or {}
        if at["k"] == "uc":
            if x.get("player"):
                cat = "heal-on-me" if x.get("action") == "HEAL" else "damage-taken"
            else:
                cat = "damage-on-target" if x.get("action") == "WOUND" else ("miss-on-target" if x.get("action") != "HEAL" else "heal-on-target")
        elif at["k"] == "interrupt":
            cat = "interrupt"
        else:
            cat = "aura-on-target" if x.get("unit") != "player" else "aura-on-me"
        c = cats[cat]
        c["n"] += 1
        src = at.get("src")
        if not tr:
            c["noTruth"] += 1
            continue
        tsrc = tr["src"]
        c["truthMine" if _mine(tsrc) else "truthOther"] += 1
        if cat == "damage-taken":
            ok = src == "hostile" and not _mine(tsrc)
            c["attributed"] += 1 if src not in (None, "none") else 0
            c["correct"] += 1 if ok else 0
            continue
        if src in (None, "none"):
            if _mine(tsrc):
                c["missedSelf"] += 1
            continue
        c["attributed"] += 1
        claim_mine = src == "mine"
        if claim_mine == _mine(tsrc):
            c["correct"] += 1
        elif claim_mine:
            c["falseSelf"] += 1
            rows.append({"t": x.get("t"), "cat": cat, "claim": src, "truth": tsrc, "rule": at.get("rule"), "amount": x.get("amount")})
        else:
            c["missedSelf"] += 1
            rows.append({"t": x.get("t"), "cat": cat, "claim": src, "truth": tsrc, "rule": at.get("rule"), "amount": x.get("amount")})
    out = {}
    for cat, c in cats.items():
        scorable = c["n"] - c["noTruth"]
        out[cat] = dict(c, scorable=scorable, accuracy=round(100.0 * c["correct"] / scorable, 1) if scorable else None,
                        coverage=round(100.0 * c["attributed"] / scorable, 1) if scorable else None)
    return out, rows


def naive_score(refs, truth):
    """reference: 'everything on my target is mine' (what a meter without attribution would show)"""
    c = collections.Counter()
    for r, x in refs.items():
        if x["k"] != "uc" or x.get("player") or x.get("action") != "WOUND":
            continue
        tr = truth.get(r)
        if not tr:
            continue
        c["n"] += 1
        if _mine(tr["src"]):
            c["correct"] += 1
        else:
            c["falseSelf"] += 1
            c["falseSelfAmount"] += x.get("amount") or 0
    return dict(c, accuracy=round(100.0 * c["correct"] / c["n"], 1) if c["n"] else None)


# ------------------------------------------------------------------ coverage matrix
def matrix(fx, live, cls, player):
    lo, hi = live.span
    rows = collections.defaultdict(lambda: collections.Counter())
    if lo is None:
        return {}

    def uc_match(t, tok, act_ok, amt):
        return live.near("UNIT_COMBAT", t, LAG_BEFORE * -1 if False else 0.35, LAG_AFTER,
                         pred=lambda x: _args(x)[:1] == [tok] and act_ok(_args(x)) and (amt is None or (len(_args(x)) > 3 and _args(x)[3] == amt)))
    for e in fx.get("events", []):
        if not e.get("cleu") or not (lo - 1 <= e["t"] <= hi + 1):
            continue
        a, t = e["a"], e["t"]
        src, dst = cls(a[3]), cls(a[7])
        tg = live.target_at(t)
        tok = "player" if a[7] == player else ("target" if tg and a[7] == tg else None)
        stok = "player" if a[3] == player else ("target" if tg and a[3] == tg else None)
        ctx = live.ctx(t)
        for cat, d in _cats(e):
            key = (cat, src, dst, ctx)
            r = rows[key]
            r["log"] += 1
            r["onToken"] += 1 if (tok or stok) else 0
            vis = amt = spell = False
            if cat in ("damage", "miss", "crit", "overkill", "absorb", "heal") and tok:
                if cat == "heal":
                    m = uc_match(t, tok, lambda x: len(x) > 1 and x[1] == "HEAL", d.get("amount"))
                elif cat == "miss":
                    m = uc_match(t, tok, lambda x: len(x) > 1 and x[1] not in ("WOUND", "HEAL"), None)
                else:
                    m = uc_match(t, tok, lambda x: len(x) > 1 and x[1] == "WOUND", d.get("amount"))
                if m:
                    ma = _args(m)
                    vis = True
                    amt = len(ma) > 3 and isinstance(ma[3], (int, float))
                    if cat == "crit":
                        vis = len(ma) > 2 and ma[2] == "CRITICAL"
                    if cat in ("overkill", "absorb"):
                        vis = amt = False   # UNIT_COMBAT carries no overkill/absorbed field
                    # spell: only my own damage is tied to a clear spellID (my UNIT_SPELLCAST_SUCCEEDED in the same frame)
                    spell = src == "me" and d.get("spell") is not None and bool(live.near(
                        "UNIT_SPELLCAST_SUCCEEDED", t, FRAME, FRAME, pred=lambda x: _args(x)[:1] == ["player"] and isinstance(_args(x)[2] if len(_args(x)) > 2 else None, (int, float))))
            elif cat == "energize" and tok == "player":
                m = live.near("UNIT_POWER_FREQUENT", t, 0.3, 0.3, pred=lambda x: _args(x)[:1] == ["player"])
                vis = bool(m)
                amt = vis and ctx == "ooc"    # UnitPower: clear out of combat, secret in combat (verify 12/12)
            elif cat in ("aura+", "aura-") and tok:
                m = live.near("UNIT_AURA", t, 0.35, 0.35, pred=lambda x: _args(x)[:1] == [tok])
                vis = bool(m)
                if m:
                    p = _args(m)[1] if len(_args(m)) > 1 and isinstance(_args(m)[1], dict) else {}
                    fld = "addedAuras" if cat == "aura+" else "removedAuraInstanceIDs"
                    spell = fld in p and not _secret(p.get(fld))
                    amt = spell
            elif cat in ("cast-start", "cast-success", "cast-fail") and stok:
                ev = {"cast-start": "UNIT_SPELLCAST_START", "cast-success": "UNIT_SPELLCAST_SUCCEEDED", "cast-fail": "UNIT_SPELLCAST_FAILED"}[cat]
                m = live.near(ev, t, 0.3, 0.3, pred=lambda x: _args(x)[:1] == [stok])
                if not m and cat == "cast-fail":
                    m = live.near("UNIT_SPELLCAST_FAILED_QUIET", t, 0.3, 0.3, pred=lambda x: _args(x)[:1] == [stok])
                vis = bool(m)
                if m:
                    ma = _args(m)
                    spell = len(ma) > 2 and isinstance(ma[2], (int, float))
            elif cat == "interrupt" and tok:
                m = live.near("UNIT_SPELLCAST_INTERRUPTED", t, 0.3, 0.3, pred=lambda x: _args(x)[:1] == [tok])
                vis = bool(m)
            elif cat == "summon" and src == "me":
                m = live.near("PLAYER_TOTEM_UPDATE", t, 0.5, 0.5)
                vis = bool(m)
                spell = vis
            elif cat == "death" and (tok or a[7] == player):
                m = live.near("UNIT_DIED", t, 0.5, 0.5) or live.near("UNIT_HEALTH", t, 0.3, 0.3, pred=lambda x: _args(x)[:1] == [tok])
                vis = bool(m)
            r["visible"] += 1 if vis else 0
            r["amount"] += 1 if amt else 0
            r["spell"] += 1 if spell else 0
    out = []
    for (cat, src, dst, ctx), c in sorted(rows.items()):
        out.append({"cat": cat, "src": src, "dst": dst, "ctx": ctx, "log": c["log"], "onToken": c["onToken"], "visible": c["visible"],
                    "amount": c["amount"], "spell": c["spell"]})
    return out


# ------------------------------------------------------------------ fights, DM reconciliation, other-player analysis
def log_span(fx):
    """(first, last) CLEU time in the combat log file, or None"""
    ts = [e["t"] for e in fx.get("events", []) if e.get("cleu") and isinstance(e.get("t"), (int, float))]
    return (min(ts), max(ts)) if ts else None


def fights_truth(fx, live, cls, player):
    """v2.2.9 (run 8): a fight the combat log FILE does not cover (run 8's BG: FD_Logs switched the file off at ON) gets
    logCovered=False and None totals downstream - never 0 ('log=0' read as 'the log saw nothing'). Damage to hostile
    players counts as mine (battlegrounds), not only damage to NPCs."""
    out = []
    span = log_span(fx)
    for i, (lo, hi) in enumerate(live.combat):
        f = {"n": i + 1, "start": lo, "stop": hi, "dur": round(hi - lo, 1), "mineDamage": 0, "otherOnTargets": 0, "otherBySrc": collections.Counter(),
             "takenDamage": 0, "healEffective": 0, "healRaw": 0, "interruptsMine": 0, "targets": set(),
             "logCovered": bool(span) and span[0] - 1 <= lo and hi <= span[1] + 1}
        for e in fx.get("events", []):
            if not e.get("cleu") or not (lo - 0.5 <= e["t"] <= hi + 0.5):
                continue
            a = e["a"]
            sc, dc = cls(a[3]), cls(a[7])
            for cat, d in _cats(e):
                if cat == "damage":
                    if _mine(sc) and dc in ("npc", "player"):
                        f["mineDamage"] += d["amount"]
                        f["targets"].add(a[7])
                    if a[7] == player:
                        f["takenDamage"] += d["amount"]
                elif cat == "heal" and _mine(sc) and dc == "me":
                    f["healEffective"] += max(0, d["amount"] - (d.get("overheal") or 0))
                    f["healRaw"] += d["amount"]
                elif cat == "interrupt" and _mine(sc):
                    f["interruptsMine"] += 1
        for e in fx.get("events", []):
            if not e.get("cleu") or not (lo - 0.5 <= e["t"] <= hi + 0.5):
                continue
            a = e["a"]
            if a[7] in f["targets"] and not _mine(cls(a[3])):
                for cat, d in _cats(e):
                    if cat == "damage":
                        f["otherOnTargets"] += d["amount"]
                        f["otherBySrc"][cls(a[3])] += d["amount"]
        f["targets"] = len(f["targets"])
        f["otherBySrc"] = dict(f["otherBySrc"])
        out.append(f)
    return out


def other_player(fx, live, cls, player, refs, truth, attrs_after):
    """the newest fight in which another player damaged a creature I was fighting: event timeline + attribution"""
    if not live.combat:
        return None
    by_ref = {a.get("ref"): a for a in attrs_after}
    for lo, hi in reversed(live.combat):
        others = [e for e in fx.get("events", []) if e.get("cleu") and lo - 1 <= e["t"] <= hi + 1 and cls(e["a"][3]) == "player"
                  and e["a"][7] and str(e["a"][7]).startswith("Creature-")]
        mine_dst = set(e["a"][7] for e in fx.get("events", []) if e.get("cleu") and lo - 1 <= e["t"] <= hi + 1 and _mine(cls(e["a"][3])))
        others = [e for e in others if e["a"][7] in mine_dst or e["sub"] == "SPELL_CAST_START"]
        if not any(e["a"][7] in mine_dst for e in others):
            continue
        tgt = next(e["a"][7] for e in others if e["a"][7] in mine_dst)
        srcs = sorted(set(e["a"][3] for e in others))
        label = {g: "other player %s" % chr(65 + i) for i, g in enumerate(srcs)}
        tl = []
        for e in fx.get("events", []):
            if not e.get("cleu") or not (lo - 4 <= e["t"] <= hi + 1):
                continue
            a = e["a"]
            sc = cls(a[3])
            if sc == "player" and a[3] in label and (a[7] == tgt or e["sub"] == "SPELL_CAST_START" or a[7] in (None, "0000000000000000")):
                pass
            elif not (a[7] == tgt and _mine(sc)) and not (a[7] == tgt and sc == "player"):
                continue
            who = "me" if sc == "me" else ("my totem" if sc == "mine" else label.get(a[3], "another player"))
            spell = a[12] if len(a) > 12 and e["sub"].startswith("SPELL") else ("melee" if e["sub"].startswith("SWING") else "")
            amt = None
            for cat, d in _cats(e):
                if cat in ("damage", "heal"):
                    amt = d.get("amount")
            tl.append({"t": round(e["t"], 3), "who": who, "sub": e["sub"], "spell": spell, "amount": amt})
        live_rows = []
        for r, x in sorted(refs.items(), key=lambda kv: kv[1]["t"]):
            if x["k"] != "uc" or x.get("player") or not (lo - 1 <= x["t"] <= hi + 1) or x.get("tok") != "target":
                continue
            at = by_ref.get(r) or {}
            tr = truth.get(r) or {}
            dm = live.near("DAMAGE_METER_COMBAT_SESSION_UPDATED", x["t"], 0.03, 0.03)
            live_rows.append({"t": round(x["t"], 3), "action": x.get("action"), "amount": x.get("amount"), "school": x.get("school"),
                              "crit": x.get("flag") == "CRITICAL", "dmEvent": bool(dm), "hsm": at.get("src"), "rule": at.get("rule"),
                              "truth": ("me" if _mine(tr.get("src")) else tr.get("src")) if tr else None})
        oth_log = sum(x["amount"] or 0 for x in tl if x["who"].startswith("other") and x["sub"].endswith("_DAMAGE"))
        oth_live = sum(r["amount"] or 0 for r in live_rows if r["hsm"] == "other")
        mine_live = sum(r["amount"] or 0 for r in live_rows if r["hsm"] == "mine")
        false_self = [r for r in live_rows if r["hsm"] == "mine" and r["truth"] not in (None, "me")]
        casts = [x for x in tl if x["who"].startswith("other") and x["sub"] in ("SPELL_CAST_START", "SPELL_CAST_SUCCESS")]
        auras = [x for x in tl if x["who"].startswith("other") and x["sub"].startswith("SPELL_AURA")]
        return {"fight": [lo, hi], "target": "Creature (%s)" % str(tgt).split("-")[5] if str(tgt).count("-") >= 5 else "creature",
                "others": list(label.values()), "timeline": tl, "live": live_rows, "otherDamageLog": oth_log, "otherDamageLive": oth_live,
                "mineDamageLive": mine_live, "falseSelf": false_self, "otherCasts": len(casts), "otherAurasOnTarget": len(auras)}
    return None


def session_join(fights, recs, slack=2.0):
    """v2.2.16: join log fights to C_DamageMeter records by the meter's SESSION window. In a BG the record is the
    cumulative session (38-159 s in run 9), not the last 1-18 s fight: sum every log fight inside [te - dur, te].
    A fight straddling the window start makes the row partial (log sums are then a lower bound)."""
    out, used = [], set()
    keys = (("logMine", "mineDamage"), ("logOtherOnTargets", "otherOnTargets"), ("logTaken", "takenDamage"),
            ("logHealEff", "healEffective"), ("logInterrupts", "interruptsMine"))
    for r in sorted(recs, key=lambda x: x.get("te") or 0):
        te, dur = r.get("te"), r.get("dur")
        if te is None:
            continue
        w0 = te - (dur if isinstance(dur, (int, float)) else 0) - slack
        inside = [f for f in fights if f.get("stop") is not None and w0 - slack <= f["stop"] <= te + slack]
        if not inside:
            continue
        partial = any(f["start"] < w0 for f in inside)
        row = {"fight": "+".join(str(f["n"]) for f in inside) if len(inside) > 1 else inside[0]["n"], "fights": [f["n"] for f in inside],
               "window": "session", "partial": partial or None,
               "dur": round(sum(f.get("dur") or 0 for f in inside), 1), "dmDur": dur,
               "dmMine": r.get("damage"), "dmOthers": r.get("others"), "dmTaken": r.get("taken"), "dmHeal": r.get("healing"),
               "dmInterrupts": r.get("interrupts"), "dmEnemy": r.get("enemy"), "source": r.get("source")}
        for k, fk in keys:
            vals = [f.get(fk) for f in inside if isinstance(f.get(fk), (int, float))]
            row[k] = round(sum(vals), 1) if vals else None
        used.update(row["fights"])
        out.append(row)
    for f in fights:   # fights with no meter record keep a row (DM columns empty)
        if f["n"] not in used:
            out.append({"fight": f["n"], "fights": [f["n"]], "window": "none", "dur": f["dur"], "dmDur": None, "logMine": f["mineDamage"],
                        "dmMine": None, "logOtherOnTargets": f["otherOnTargets"], "dmOthers": None, "logTaken": f["takenDamage"], "dmTaken": None,
                        "logHealEff": f["healEffective"], "dmHeal": None, "logInterrupts": f["interruptsMine"], "dmInterrupts": None,
                        "dmEnemy": None, "source": None})
    out.sort(key=lambda x: x["fights"][0])
    return out


def dm_findings(dump, live, fights):
    d = dump.log.get("damageMeter") or {}
    ev = collections.Counter()
    secret_args = 0
    dm_ev = [e for e in live.events if e.get("e") == "DAMAGE_METER_COMBAT_SESSION_UPDATED"]
    for e in dm_ev:
        a = _args(e)
        ev[str(a[0]) if a else "?"] += 1
        if any(_secret(x) for x in a) or e.get("s"):
            secret_args += 1
    ev_ctx = collections.Counter(live.ctx(e["te"]) for e in dm_ev)
    recs = _dm_records(dump, live)
    recon = session_join(fights, recs)
    # CombatProbe cells for C_DamageMeter
    cells = []
    cp = (dump.log.get("combatProbe") or {})
    for ctx, byU in (cp.get("cells") or {}).items() if isinstance(cp.get("cells"), dict) else []:
        for ucls, byK in (byU or {}).items():
            for k, v in (byK or {}).items():
                if "DamageMeter" in str(k):
                    cells.append({"ctx": ctx, "unit": ucls, "key": k, "v": v})
    deep_fights = [r for r in as_list(d.get("fights")) if isinstance(r, dict) and r.get("deep")]
    n_src, units = 0, set()
    for r in deep_fights:
        for block in (r.get("types") or {}).values():
            if isinstance(block, dict):
                for src in as_list(block.get("sources")):
                    n_src += 1
                    if isinstance(src, dict) and src.get("id"):
                        units.add(src["id"])
    return {"functions": d.get("functions"), "unavailable": d.get("unavailable"), "schema": d.get("schema"), "events": dict(ev),
            "eventsByCtx": dict(ev_ctx), "secretArgEvents": secret_args, "moduleEvents": d.get("events"), "records": len(recs),
            "recordSource": recs[0]["source"] if recs else None, "reconcile": recon, "probeCells": cells[:60],
            "deep": {"fights": len(deep_fights), "nSources": n_src, "nUnits": len(units)}}


# ------------------------------------------------------------------ v2.2.4 MINOR 4 scoring (cast model, cooldown fails, overheal, ledger)
def player_hp_truth(fx, player):
    """advanced-log unit info for the player: [(t, currentHP, maxHP)] (truth only, offline)"""
    out = []
    for e in fx.get("events", []):
        if not e.get("cleu"):
            continue
        adv = e.get("adv")
        if isinstance(adv, list) and len(adv) > 3 and adv[0] == player and isinstance(adv[2], int) and isinstance(adv[3], int) and adv[3] > 0:
            out.append((e["t"], adv[2], adv[3]))
    return out


def score_casts(rep, fx, cls):
    """enemy cast-duration predictions (live START -> model) vs the log's SPELL_CAST_START -> SUCCESS of the same NPC"""
    starts = []
    for e in fx.get("events", []):
        if e.get("cleu") and e["sub"] == "SPELL_CAST_START" and cls(e["a"][3]) == "npc":
            starts.append(e)
    succ = collections.defaultdict(list)
    ints = []
    for e in fx.get("events", []):
        if not e.get("cleu"):
            continue
        if e["sub"] == "SPELL_CAST_SUCCESS" and cls(e["a"][3]) == "npc":
            succ[e["a"][3]].append(e)
        elif e["sub"] == "SPELL_INTERRUPT":
            ints.append(e)
    log_casts = []
    for st in starts:
        src, sp = st["a"][3], st["a"][11]
        end = next((x for x in succ[src] if x["t"] > st["t"] and x["a"][11] == sp and x["t"] - st["t"] < 15), None)
        it = next((x for x in ints if x["a"][7] == src and 0 < x["t"] - st["t"] < 15 and (end is None or x["t"] < end["t"])), None)
        log_casts.append({"t": st["t"], "npc": str(src).split("-")[5] if str(src).count("-") >= 6 else None, "spell": sp, "spellName": st["a"][12],
                          "dur": round(end["t"] - st["t"], 3) if end and not it else None, "interruptedAfter": round(it["t"] - st["t"], 3) if it else None})
    rows, errs = [], []
    for c in as_list(rep.get("casts")):
        lc = min(log_casts, key=lambda x: abs(x["t"] - c["t"]), default=None)
        if not lc or abs(lc["t"] - c["t"]) > 0.3:
            rows.append(dict(c, log=None))
            continue
        r = {"t": round(c["t"], 3), "key": c.get("key"), "pred": c.get("pred"), "n": c.get("n"), "live": c.get("actual") or c.get("elapsed"),
             "outcome": c.get("outcome"), "logDur": lc["dur"], "logInterruptedAfter": lc["interruptedAfter"], "spell": lc["spell"], "spellName": lc["spellName"]}
        if c.get("pred") is not None and lc["dur"] is not None:
            r["err"] = round(c["pred"] - lc["dur"], 3)
            errs.append(abs(r["err"]))
        if c.get("pred") is not None and lc["interruptedAfter"] is not None:
            r["predRemainingAtInterrupt"] = round(c["pred"] - lc["interruptedAfter"], 3)
        if c.get("actual") is not None and lc["dur"] is not None:
            r["liveVsLog"] = round(c["actual"] - lc["dur"], 3)
        rows.append(r)
    return {"logCasts": log_casts, "rows": rows, "predicted": len(errs), "mae": round(sum(errs) / len(errs), 3) if errs else None,
            "within150ms": sum(1 for x in errs if x <= 0.15), "model": rep.get("castModel")}


_PRECOND_RE = re.compile(r"\bdead\b|\bghost\b", re.I)   # only "You are dead" provably fails before the cooldown check


def score_cooldowns(rep, fx, player):
    """UNIT_SPELLCAST_FAILED replayed through the cooldown model vs the log's SPELL_CAST_FAILED reasons + recast timing"""
    fails = [e for e in fx.get("events", []) if e.get("cleu") and e["sub"] == "SPELL_CAST_FAILED" and e["a"][3] == player]
    at = [x for x in as_list(rep.get("attributions")) if x.get("k") == "failed"]
    rows = []
    c = collections.Counter()
    for e in fails:
        reason = e["a"][-1]
        sp = e["a"][11]
        m = min((x for x in at if x.get("spell") == sp), key=lambda x: abs(x["t"] - e["t"]), default=None)
        if not m or abs(m["t"] - e["t"]) > 0.1:
            continue
        nyr = reason == "Not yet recovered"
        inside = m.get("rule") == "fail-inside-cd"
        if m.get("rule") == "fail-dead" or (not nyr and _PRECOND_RE.search(str(reason))):
            # v2.2.16: "You are dead" fails before the cooldown check: not cooldown evidence
            c["precondition"] += 1
            rows.append({"t": round(e["t"], 3), "spell": sp, "reason": reason, "rule": m.get("rule"), "remaining": m.get("remaining"), "verdict": "precondition"})
            continue
        verdict = "confirms" if (nyr and inside) else ("contradicts" if nyr and not inside else ("n/a" if not nyr and not inside else "inside-other-reason"))
        c[verdict] += 1
        rows.append({"t": round(e["t"], 3), "spell": sp, "reason": reason, "rule": m.get("rule"), "remaining": m.get("remaining"), "verdict": verdict})
    # recast vs predicted ready
    succ = [e for e in fx.get("events", []) if e.get("cleu") and e["sub"] == "SPELL_CAST_SUCCESS" and e["a"][3] == player]
    recast = []
    for p in as_list(rep.get("predictions")):
        ends = p.get("cooldownEnds")
        if not ends:
            continue
        nxt = next((e for e in succ if e["a"][11] == p.get("spell") and e["t"] > p["t"] + 0.2), None)
        if nxt and nxt["t"] - ends < 30:
            d = round(nxt["t"] - ends, 3)
            recast.append({"spell": p.get("spell"), "cast": round(p["t"], 3), "predictedReady": round(ends, 3), "recast": round(nxt["t"], 3),
                           "recastMinusReady": d, "verdict": "contradicts" if d < -0.1 else "consistent", "cdConfirm": p.get("cdConfirm")})
    return {"fails": rows, "counts": dict(c), "recast": recast}


def score_overheal(attrs, truth, refs):
    rows = []
    for at in attrs:
        if at.get("k") != "uc":
            continue
        x = refs.get(at.get("ref")) or {}
        tr = truth.get(at.get("ref")) or {}
        if not x.get("player") or x.get("action") != "HEAL" or tr.get("overheal") is None:
            continue
        rows.append({"t": round(x["t"], 3), "amount": x.get("amount"), "est": at.get("overhealEst"), "log": tr.get("overheal"), "conf": at.get("hpConf")})
    have = [r for r in rows if r["est"] is not None]
    err = [abs(r["est"] - r["log"]) for r in have]
    cls_ok = sum(1 for r in have if (r["est"] > 0) == (r["log"] > 0))
    return {"n": len(rows), "estimated": len(have), "mae": round(sum(err) / len(err), 1) if err else None, "exact": sum(1 for e in err if e == 0),
            "overhealYesNoCorrect": cls_ok, "big": [r for r in have if r["amount"] and r["amount"] >= 50]}


def score_cdtracker(rep, attrs, fx, player):
    """CooldownTracker (MINOR 5) vs the log: tracker state at each of my successful casts (a cast while the tracker said
    'cooling' with > 0.15 s left = contradiction), NYR fails vs tracker state, learned readies / GCD windows vs the next cast"""
    q = [x for x in attrs if x.get("k") == "cdq"]
    c = collections.Counter()
    bad = []
    for x in q:
        if x.get("state") == "cooling" and (x.get("remaining") or 0) > 0.15:
            c["castWhileCooling"] += 1
            bad.append({"t": round(x["t"], 3), "spell": x.get("spell"), "remaining": round(x.get("remaining") or 0, 3), "source": x.get("source")})
        elif x.get("state") == "gcd" and (x.get("remaining") or 0) > 0.15:
            c["castInsideGcd"] += 1
            bad.append({"t": round(x["t"], 3), "spell": x.get("spell"), "remaining": round(x.get("remaining") or 0, 3), "source": x.get("source"), "gcd": True})
        else:
            c["consistent"] += 1
    fails = [e for e in fx.get("events", []) if e.get("cleu") and e["sub"] == "SPELL_CAST_FAILED" and e["a"][3] == player]
    fa = [x for x in attrs if x.get("k") == "failed"]
    nyr = collections.Counter()
    for e in fails:
        m = min((x for x in fa if x.get("spell") == e["a"][11]), key=lambda x: abs(x["t"] - e["t"]), default=None)
        if not m or abs(m["t"] - e["t"]) > 0.1:
            continue
        if e["a"][-1] == "Not yet recovered":
            nyr["confirms" if m.get("cdState") in ("cooling", "gcd") else "missed"] += 1
    cd = rep.get("cd") or {}
    return {"casts": len(q), "counts": dict(c), "contradictions": bad[:30], "nyr": dict(nyr),
            "readies": as_list(cd.get("readies")), "gcds": as_list(cd.get("gcds")),
            "spells": cd.get("spells") if isinstance(cd.get("spells"), dict) else {}}


def aura_truth(fx):
    """[(dst, spell, applied, removed)] from the log"""
    open_ = {}
    out = []
    for e in fx.get("events", []):
        if not e.get("cleu"):
            continue
        a, sub = e["a"], e["sub"]
        if sub in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH"):
            k = (a[7], a[11])
            if k not in open_:
                open_[k] = e["t"]
        elif sub == "SPELL_AURA_REMOVED":
            k = (a[7], a[11])
            if k in open_:
                out.append((k[0], k[1], open_.pop(k), e["t"]))
            else:
                out.append((k[0], k[1], None, e["t"]))
    for k, t in open_.items():
        out.append((k[0], k[1], t, None))
    return out


def score_ledger(rep, fx, player, live):
    """cache-resolved inferences: auras believed present from ledger data cached while clear vs the log (aura
    present at the probe time); plus target token -> GUID resolution through the last clear mapping"""
    tr = aura_truth(fx)
    span_lo = min((e["t"] for e in fx.get("events", []) if e.get("cleu")), default=None)

    def present(dst, sp, t):
        for d, s_, a0, a1 in tr:
            if d == dst and s_ == sp and (a0 is None or a0 <= t + 0.3) and (a1 is None or t - 0.3 <= a1):
                return True
        # aura applied before the log started and never removed in it: unknown
        return None
    c = collections.Counter()
    byconf = collections.defaultdict(collections.Counter)
    wrong = []
    for pr in as_list(rep.get("probes")):
        dst = player if pr["unit"] == "player" else pr["unit"]
        for a in as_list(pr.get("auras")):
            ok = present(dst, a.get("spell"), pr["t"])
            if ok is None and span_lo is not None and pr["t"] >= span_lo:
                ok = False if any(d == dst and s_ == a.get("spell") for d, s_, _, _ in tr) else None
            key = "unknown" if ok is None else ("correct" if ok else "wrong")
            if a.get("conf") == "maybe-removed":
                # never claimed as present (HybridState L584): a removal the log confirms vindicates the doubt flag
                key = "unknown" if ok is None else ("stillPresent" if ok else "removalConfirmed")
                byconf["maybe-removed"][key] += 1
                continue
            c[key] += 1
            byconf[a.get("conf")][key] += 1
            if ok is False and len(wrong) < 20:
                wrong.append({"t": round(pr["t"], 3), "unit": "player" if pr["unit"] == "player" else "target", "spell": a.get("spell"), "conf": a.get("conf")})
    # token -> GUID: live target WOUND amounts matched to the log by amount + time, any destination
    dmg = []
    for e in fx.get("events", []):
        if e.get("cleu"):
            for cat, d in _cats(e):
                if cat == "damage" and d.get("amount"):
                    dmg.append((e["t"], d["amount"], e["a"][7]))
    tok = collections.Counter()
    for x in live.events:
        a = _args(x)
        if x["e"] != "UNIT_COMBAT" or not a or a[0] != "target" or len(a) < 4 or a[1] != "WOUND":
            continue
        m = [d for d in dmg if d[1] == a[3] and -LAG_BEFORE <= x["te"] - d[0] <= LAG_AFTER]
        if len(m) != 1:
            continue
        g = live.target_at(x["te"])
        tok["n"] += 1
        tok["correct" if g == m[0][2] else "wrong"] += 1
    return {"auraProbes": dict(c), "byConf": {k: dict(v) for k, v in byconf.items()}, "wrong": wrong, "tokenGuid": dict(tok),
            "ledger": rep.get("ledger")}


def analyze(dump, fx, player, lua="lua5.1"):
    live = Live(dump)
    live.fill_targets_from_log(fx, player)
    cls, pets = classes(fx, player)
    res = {"player": "me", "span": live.span, "combat": live.combat, "targetSource": live.target_source,
           "matrix": matrix(fx, live, cls, player)}
    hpt = player_hp_truth(fx, player)
    standin = collections.Counter(m for _, _, m in hpt).most_common(1)[0][0] if hpt else None
    try:
        from fdump import knowlint, timing
        rp = knowlint.reparse(knowlint.spells(dump), lua=lua)
        rp = {sid: v.get("parsed") for sid, v in (rp or {}).items()}
        seed = [dict(x, k="cdseed") for x in timing.seed_events(timing.load_seed())]
    except Exception:   # noqa: BLE001 - reparse / seed are improvements, never a hard dependency
        rp, seed = None, None
    stream, refs = build_stream(dump, live, player, hpmax_standin=standin, reparse=rp, seed_events=seed)
    cen = census_live(live)
    res["censusSource"] = "live" if cen else "log stand-in"
    stream = add_census(stream, cen or census_standin(fx, player))
    try:   # v2.2.16: the shipped self-link seed (Data/SelfLinkSeed.lua) is loaded live before any cast
        from fdump import selflink
        if stream:
            stream = selflink.stream_events(stream[0]["t"]) + stream
    except Exception:   # noqa: BLE001
        pass
    res["castSource"] = live.cast_source
    res["hpMaxStandin"] = standin if not any(s_.get("e") == "hpmax" for s_ in live.signals) else None
    truth = _truth_uc(refs, fx, cls, player, live)
    res["replay"] = {}
    attrs = {}
    for mode, legacy in (("before", True), ("after", False)):
        r = infmod.run_replay(stream, lua=lua, legacy=legacy)
        if r is None:
            res["replay"][mode] = {"error": "lua5.1 missing"}
            continue
        at = as_list(r.get("attributions"))
        attrs[mode] = at
        sc, errs = score(at, truth, refs)
        res["replay"][mode] = {"scores": sc, "errors": errs[:40], "contradictions": as_list(r.get("contradictions")),
                               "counters": r.get("counters"), "fights": as_list(r.get("fights")),
                               "reconcile": [i for i in as_list(r.get("inferences")) if isinstance(i, dict) and i.get("rule") == "dm-reconcile"],
                               "predictionOutcomes": dict(collections.Counter(str(p.get("outcome")) for p in as_list(r.get("predictions"))))}
        if mode == "after":
            res["casts"] = score_casts(r, fx, cls)
            res["cooldowns"] = score_cooldowns(r, fx, player)
            res["overheal"] = score_overheal(at, truth, refs)
            res["ledger"] = score_ledger(r, fx, player, live)
            res["interrupts"] = [x for x in at if x.get("k") == "interrupt"]
            res["verdicts"] = as_list(r.get("verdicts"))
            res["cdtrack"] = score_cdtracker(r, at, fx, player)
            res["verdictCounts"] = r.get("verdictCounts")
    res["naive"] = naive_score(refs, truth)
    lags = collections.defaultdict(list)
    for r, tr in truth.items():
        if "dt" in tr and refs.get(r, {}).get("k") == "uc":
            lags[tr["cat"] + ("/melee" if tr.get("school") == 1 and tr["cat"] == "damage" else "")].append(tr["dt"])
    res["timing"] = {k: {"n": len(v), "min": min(v), "median": sorted(v)[len(v) // 2], "max": max(v)} for k, v in lags.items()}
    fights = fights_truth(fx, live, cls, player)
    res["fights"] = fights
    res["damageMeter"] = dm_findings(dump, live, fights)
    res["otherPlayer"] = other_player(fx, live, cls, player, refs, truth, attrs.get("after") or [])
    inp = live.inf.get("inputs") or {}
    res["unreadable"] = {ctx: {k: v for k, v in (sig or {}).items() if isinstance(v, dict) and v.get("u")} for ctx, sig in inp.items()}
    res["streamEvents"] = collections.Counter(x["k"] for x in stream)
    # in-memory context for the miss explainer / analyze (stripped before any JSON is written)
    res["_ctx"] = {"live": live, "cls": cls, "stream": stream, "refs": refs, "truth": truth, "attrs": attrs}
    # v2.2.15: parallel candidate (shadow) rules, scored per rule: live rule vs candidate claims on the same events
    try:
        from fdump import candscore
        if attrs.get("after"):
            res["candidates"] = candscore.score_candidates(attrs["after"], truth, refs)
            res["ruleMetrics"] = candscore.rule_metrics(attrs["after"], truth, refs)
    except Exception as ex:  # report, never break the analysis
        res["candidatesError"] = repr(ex)
    return res


def public(res):
    return {k: v for k, v in res.items() if not k.startswith("_")}


# ------------------------------------------------------------------ output
SRC_ORDER = ["me", "mine", "player", "npc", "other", "none"]
LABEL = {"me": "me", "mine": "my totems/pets", "player": "another player", "npc": "hostile NPC", "none": "-", "other": "other"}


def summary_by_cat(res):
    agg = collections.defaultdict(lambda: collections.Counter())
    for r in res["matrix"]:
        k = (r["cat"], r["src"], r["ctx"])
        for f in ("log", "onToken", "visible", "amount", "spell"):
            agg[k][f] += r[f]
    return agg


def _pct(a, b):
    return "-" if not b else "%d/%d" % (a, b)


def markdown(res):
    L = ["# Combat-event coverage: combat log (truth) vs what the addon read live", "",
         "Truth = the WoWCombatLog file, read offline only. Live = event payloads/timing and API values the capture saw "
         "(no CLEU, no side channels). Columns: **log** events in the capture span; **tok** the event touched a unit token "
         "the addon follows (player/target); **seen** a live event matched it (time window + amount); **amt** the amount/"
         "value was readable; **spell** the spellID was readable live.", ""]
    if res.get("targetSource") == "log-inferred":
        L += ["**Target timeline: log-inferred.** This capture has no live target signals (the HSM did not run), so the "
              "target at each moment is rebuilt from my own offensive log events. **seen** then means the live event stream "
              "carried a matching event on the target token, not that the engine processed it.", ""]
    if res.get("castSource") == "raw-events":
        L += ["**Own casts: raw events.** No HSM cast signals; the replay's own casts come from the raw UNIT_SPELLCAST_* "
              "records (target chosen like Inference.lua).", ""]
    agg = summary_by_cat(res)
    L += ["## Matrix (category x source x context)", "", "| category | source | ctx | log | tok | seen | amt | spell |", "|---|---|---|---|---|---|---|---|"]
    for cat, _ in CATS:
        for src in SRC_ORDER:
            for ctx in ("ooc", "combat"):
                c = agg.get((cat, src, ctx))
                if not c:
                    continue
                L.append("| %s | %s | %s | %d | %d | %d | %d | %d |" % (cat, LABEL.get(src, src), ctx, c["log"], c["onToken"], c["visible"], c["amount"], c["spell"]))
    L += ["", "Full rows with target classes: coverage.json `matrix`.", ""]
    L += ["## Live attribution (HSM replay of the recorded live events, scored against the log)", "",
          "before = v2.2.3 library behaviour (no UNIT_COMBAT/DM/swing/interrupt attribution, secret-timing window 2.4 s); "
          "after = HybridState MINOR 3 (v2.2.4). accuracy = correct / events with a log match; coverage = attributed / matched; "
          "falseSelf = attributed to me but the log says someone else (counted as contradictions).", "",
          "| category | n | before acc | before cov | before falseSelf | after acc | after cov | after falseSelf | after missedSelf |", "|---|---|---|---|---|---|---|---|---|"]
    b = (res["replay"].get("before") or {}).get("scores") or {}
    a = (res["replay"].get("after") or {}).get("scores") or {}
    for cat in sorted(set(b) | set(a)):
        x, y = b.get(cat) or {}, a.get(cat) or {}
        L.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (cat, y.get("scorable", x.get("scorable")), x.get("accuracy"), x.get("coverage"),
                                                                 x.get("falseSelf", 0), y.get("accuracy"), y.get("coverage"), y.get("falseSelf", 0), y.get("missedSelf", 0)))
    nv = res.get("naive") or {}
    L += ["", "Reference: a meter that counts everything on my target as mine: %s%% correct, %s false-self hit(s), %s damage wrongly "
          "credited to me." % (nv.get("accuracy"), nv.get("falseSelf", 0), nv.get("falseSelfAmount", 0)), ""]
    errs = (res["replay"].get("after") or {}).get("errors") or []
    if errs:
        L += ["Remaining errors (after):", ""] + ["- %s %s: claimed %s, log %s (rule %s, amount %s)" % (e.get("t"), e["cat"], e["claim"], e["truth"], e["rule"], e.get("amount")) for e in errs]
    L += ["", "## Timing models (trained on this log)", "", "| channel | n | min | median | max |", "|---|---|---|---|---|"]
    for k, v in sorted(res["timing"].items()):
        L.append("| UNIT_COMBAT - file time, %s | %d | %.3f | %.3f | %.3f |" % (k, v["n"], v["min"], v["median"], v["max"]))
    L += ["", "## Fights: log vs C_DamageMeter (post-combat, clear)", "",
          "| fight | dur (log/DM) | my damage log/DM | others on my targets log / DM others | taken log/DM | my effective heal on me log/DM | my interrupts log/DM |", "|---|---|---|---|---|---|---|"]
    for r in res["damageMeter"]["reconcile"]:
        L.append("| %s | %s/%s | %s/%s | %s / %s | %s/%s | %s/%s | %s/%s |" % (str(r["fight"]) + (" (partial)" if r.get("partial") else ""), r["dur"], r["dmDur"], r["logMine"], r["dmMine"], r["logOtherOnTargets"],
                                                                         r["dmOthers"], r["logTaken"], r["dmTaken"], r["logHealEff"], r["dmHeal"], r["logInterrupts"], r["dmInterrupts"]))
    aft = res["replay"].get("after") or {}
    if aft.get("reconcile"):
        L += ["", "HSM live reconciliation at PLAYER_REGEN_ENABLED (after):", ""]
        for i in aft["reconcile"]:
            L.append("- DM mine %s vs live mine %s; live other %s; others-on-target (live total - DM mine) %s; interrupts DM %s / live %s" % (
                i.get("dmMine"), i.get("liveMine"), i.get("liveOther"), i.get("othersOnTarget"), i.get("dmInterrupts"), i.get("liveInterrupts")))
    op = res.get("otherPlayer")
    if op:
        L += ["", "## Another player on my target (newest such fight)", "",
              "Others: %s. Their casts in the log: %d; their auras on the target: %d. Damage by others: log %s, live 'other' %s; "
              "live 'mine' %s; false self-attributions: %d." % (", ".join(op["others"]), op["otherCasts"], op["otherAurasOnTarget"], op["otherDamageLog"],
                                                               op["otherDamageLive"], op["mineDamageLive"], len(op["falseSelf"])), "",
              "| t | live UNIT_COMBAT | amount | school | crit | DM event | HSM | rule | log truth |", "|---|---|---|---|---|---|---|---|---|"]
        for r in op["live"]:
            L.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (r["t"], r["action"], r["amount"], r["school"], r["crit"], r["dmEvent"], r["hsm"], r["rule"], r["truth"]))
        L += ["", "Log timeline:", "", "| t | who | event | spell | amount |", "|---|---|---|---|---|"]
        for x in op["timeline"]:
            L.append("| %s | %s | %s | %s | %s |" % (x["t"], x["who"], x["sub"], x["spell"], x["amount"]))
    dm = res["damageMeter"]
    L += ["", "## C_DamageMeter", "", "- DAMAGE_METER_COMBAT_SESSION_UPDATED by type: %s (by context %s); events with a secret argument: %d" % (
        dm["events"], dm["eventsByCtx"], dm["secretArgEvents"]),
        "- post-combat records: %d (%s)" % (dm["records"], dm["recordSource"])]
    deep = dm.get("deep") or {}
    if deep.get("fights"):
        L.append("- deep per-unit sources (IdKey'd): %d source-rows / %d distinct IdKeys across %d deep fight(s)" % (
            deep.get("nSources", 0), deep.get("nUnits", 0), deep.get("fights", 0)))
    if dm.get("probeCells"):
        L += ["", "CombatProbe cells (v2.2 probe set):", "", "| context | API | result codes | fields | predicate |", "|---|---|---|---|---|"]
        for c in dm["probeCells"]:
            v = c.get("v") or {}
            L.append("| %s | %s | %s | %s | %s |" % (c["ctx"], c["key"], v.get("r"), v.get("f"), v.get("p")))
    if dm.get("schema"):
        L += ["", "| context | field | codes |", "|---|---|---|"]
        for ctx, f in sorted(dm["schema"].items()):
            for k, v in sorted(f.items()):
                L.append("| %s | %s | %s |" % (ctx, k, v))
    L += _md_v224(res)
    if res.get("unreadable"):
        L += ["", "## Unreadable rule inputs (Inference.inputs, u > 0)", ""]
        for ctx, sig in sorted(res["unreadable"].items()):
            L.append("- %s: %s" % (ctx, ", ".join("%s r%d/u%d" % (k, v.get("r", 0), v.get("u", 0)) for k, v in sorted(sig.items()))))
    return "\n".join(L) + "\n"


def _md_v224(res):
    """v2.2.4 sections: cooldown/GCD tracker, cooldown model vs log fails, enemy cast bars, overheal, Ledger, verdicts"""
    L = []
    ct = res.get("cdtrack")
    if ct:
        c = ct.get("counts") or {}
        L += ["", "## Cooldown / GCD tracker (HybridState MINOR 5) vs the log", "",
              "State the tracker held at each of my successful casts (log SPELL_CAST_SUCCESS). A cast while the tracker said "
              "'cooling' (or 'gcd') with more than 0.15 s left is a contradiction. 'Not yet recovered' fails in the log should "
              "find the tracker cooling.", "",
              "- casts checked: %d; consistent %d; cast while cooling %d; cast inside GCD %d" % (
                  ct.get("casts", 0), c.get("consistent", 0), c.get("castWhileCooling", 0), c.get("castInsideGcd", 0)),
              "- log 'Not yet recovered' fails: tracker cooling/gcd %d, tracker idle (missed) %d" % (
                  (ct.get("nyr") or {}).get("confirms", 0), (ct.get("nyr") or {}).get("missed", 0)),
              "- learned readies: %d; GCD windows observed: %d; spells tracked: %d" % (
                  len(ct.get("readies") or []), len(ct.get("gcds") or []), len(ct.get("spells") or {}))]
        if ct.get("contradictions"):
            L += ["", "| t | spell | remaining | source | gcd |", "|---|---|---|---|---|"]
            for x in ct["contradictions"]:
                L.append("| %s | %s | %s | %s | %s |" % (x["t"], x["spell"], x["remaining"], x.get("source"), "yes" if x.get("gcd") else ""))
        sp = ct.get("spells") or {}
        if sp:
            L += ["", "| spell | category | shared-recovery category | fail confirms | learned n | gcd n |", "|---|---|---|---|---|---|"]
            for k in sorted(sp, key=lambda x: int(x)):
                v = sp[k] or {}
                L.append("| %s | %s | %s | %s | %s | %s |" % (k, v.get("category", ""), v.get("srCategory", ""), v.get("failConfirm", 0),
                                                         v.get("learnedN", 0), v.get("gcdN", 0)))
    cd = res.get("cooldowns")
    if cd:
        L += ["", "## Cooldown model vs log cast failures", "", "- fail verdicts: %s" % (cd.get("counts") or {}), "",
              "| spell | cast | predicted ready (+s) | recast (+s) | recast - ready | verdict |", "|---|---|---|---|---|---|"]
        for r in cd.get("recast") or []:
            L.append("| %s | %s | %.1f | %.1f | %s | %s |" % (r["spell"], _hms(r["cast"]), r["predictedReady"] - r["cast"], r["recast"] - r["cast"],
                                                          r["recastMinusReady"], r["verdict"]))
    ca = res.get("casts")
    if ca:
        L += ["", "## Enemy cast bars: live duration model vs log", "",
              "- log NPC casts: %d; predicted: %d; mean abs error %s s; within 150 ms: %d" % (
                  len(ca.get("logCasts") or []), ca.get("predicted", 0), ca.get("mae"), ca.get("within150ms", 0))]
        for k, v in sorted((ca.get("model") or {}).items()):
            L.append("- model %s: n %s, median %.3f s (min %.3f, max %.3f)" % (k, v.get("n"), v.get("median"), v.get("min"), v.get("max")))
    oh = res.get("overheal")
    if oh:
        L += ["", "## Overheal estimate vs log", "",
              "- heals %d, estimated %d, exact %d, overheal yes/no correct %d, mean abs error %s" % (
                  oh.get("n", 0), oh.get("estimated", 0), oh.get("exact", 0), oh.get("overhealYesNoCorrect", 0), oh.get("mae"))]
    lg = res.get("ledger")
    if lg:
        L += ["", "## Ledger (cached clear facts) vs log", "",
              "- aura claims (live / cached-fresh / cached-stale) vs log: %s; by confidence: %s" % (lg.get("auraProbes"), lg.get("byConf")),
              "- 'maybe-removed' entries are doubts, never claims: removalConfirmed = the log shows the aura really was gone, "
              "stillPresent = the doubt was unnecessary",
              "- token->GUID resolutions: %s" % (lg.get("tokenGuid"),),
              "- ledger stats: %s" % ((lg.get("ledger") or {}).get("stats"),)]
        wr = collections.Counter((w.get("unit"), w.get("spell"), w.get("conf")) for w in lg.get("wrong") or [])
        for (u, spl, conf), n in wr.most_common(5):
            L.append("- wrong: %s spell %s conf %s x%d" % (u, spl, conf, n))
    vc = res.get("verdictCounts")
    if vc:
        L += ["", "## Live verdicts (verify ring, replayed)", "", "| kind | V | C | U | X |", "|---|---|---|---|---|"]
        kinds = collections.defaultdict(dict)
        for k, n in vc.items():
            kd, v = k.rsplit("|", 1)
            kinds[kd][v] = n
        for kd in sorted(kinds):
            L.append("| %s | %s | %s | %s | %s |" % (kd, kinds[kd].get("V", 0), kinds[kd].get("C", 0), kinds[kd].get("U", 0), kinds[kd].get("X", 0)))
    return L


def _hms(t):
    import datetime
    try:
        from . import timefmt
        return timefmt.clock(t)
    except (TypeError, ValueError, OSError):
        return str(t)


def guide_json(res, build=None, captured=None):
    agg = summary_by_cat(res)
    rows = []
    for (cat, src, ctx), c in sorted(agg.items()):
        rows.append({"cat": cat, "src": LABEL.get(src, src), "ctx": ctx, "log": c["log"], "onToken": c["onToken"], "visible": c["visible"],
                     "amount": c["amount"], "spell": c["spell"], "note": CAT_NOTE.get(cat, "")})
    rep = {}
    for mode in ("before", "after"):
        rep[mode] = (res["replay"].get(mode) or {}).get("scores") or {}
    op = res.get("otherPlayer") or {}
    return {"schema": "foreverdump.coverage/1", "build": build, "captured": captured, "matrix": rows, "attribution": rep, "naive": res.get("naive"),
            "timing": res.get("timing"), "dmReconcile": res["damageMeter"]["reconcile"], "dmEvents": res["damageMeter"]["events"],
            "dmSchema": res["damageMeter"].get("schema"),
            "dmProbe": [{"ctx": c["ctx"], "api": c["key"], "result": (c.get("v") or {}).get("r"), "fields": (c.get("v") or {}).get("f")}
                        for c in res["damageMeter"].get("probeCells") or []],
            "otherPlayer": {k: op.get(k) for k in ("otherDamageLog", "otherDamageLive", "mineDamageLive", "otherCasts", "otherAurasOnTarget")} if op else None,
            "otherPlayerLive": op.get("live") if op else None,
            "cdTracker": {k: (res.get("cdtrack") or {}).get(k) for k in ("casts", "counts", "nyr")} if res.get("cdtrack") else None,
            "cooldownFails": (res.get("cooldowns") or {}).get("counts"),
            "castModel": {k: (res.get("casts") or {}).get(k) for k in ("predicted", "mae", "within150ms")} if res.get("casts") else None,
            "overheal": {k: (res.get("overheal") or {}).get(k) for k in ("n", "exact", "overhealYesNoCorrect", "mae")} if res.get("overheal") else None,
            "ledger": {k: (res.get("ledger") or {}).get(k) for k in ("auraProbes", "tokenGuid")} if res.get("ledger") else None,
            "verdictCounts": res.get("verdictCounts")}
