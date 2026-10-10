"""JSON inputs for the SECRETS-GUIDE generator (tools/guide/build_guide.py), matching tools/guide/README.md:
  --lab     {"lab": [...], "controls": [...]}            (ForeverDumpLogDB arrays as-is)
  --combat  schema foreverdump.combat/1                  (combat probe set + detectability + token survey observations)
  --hsm     schema foreverdump.hsm/1                     (inference rules + HSM prediction checks, inputs, sample)
  tokens.json / inference.json are written alongside (the generator folds tokens into --combat observations and
  inference rules into --hsm rules; it has no dedicated flags)."""
import datetime

from .dump import as_list
from . import probes

GUIDE_ITEM = {
    "UnitHealth": "health.current", "UnitHealthMax": "health.max", "UnitHealthPercent": "health.percent",
    "UnitGetTotalAbsorbs": "health.absorbs", "UnitGetIncomingHeals": "health.incomingHeals", "UnitCastingInfo": "cast.info",
    "GetUnitSpeed": "movement.speed", "UnitName": "unit.name", "aura:GetAuraDataByIndex[HELPFUL]": "aura.buffs",
    "aura:GetAuraDataByIndex[HARMFUL]": "aura.debuffs", "UnitThreatSituation": "threat", "UnitInRange": "range",
    "C_Spell.IsSpellInRange": "range", "GetRaidTargetIndex": "raidMarker", "C_DamageMeter.GetCombatSessionFromType": "damageMeter",
}
EXTRA_OBS = {"UnitPower", "UnitPowerMax", "UnitGUID", "UnitIsUnit(u,player)", "CanCompareUnitTokens", "UnitCastingDuration",
             "UnitChannelInfo", "UnitChannelDuration", "UnitSpellTargetName", "UnitAffectingCombat", "UnitIsDeadOrGhost",
             "UnitDetailedThreatSituation", "UnitPosition", "ShouldUnitIdentityBeSecret"}
# v2.2.22 (audit): "T" = container with SOME secret fields -> "X" (the guide's "container: check per field" code, with
# the per-field codes in the cell note), never "S". The whole-struct "S" made every aura / info struct with one secret
# field read as fully secret in the guide.
CODE = {"S": "S", "T": "X", "K": "X", "C": "C", "N": "N", "E": "E"}


def guide_unit(ucls):
    if ucls == "player" or ucls.endswith(":self"):
        return "player"
    if ucls == "global":
        return "any"
    fam, _, kind = ucls.partition(":")
    if fam in ("party", "raid", "partypet", "raidpet"):
        return "party_raid"
    if fam == "nameplate":
        return "nameplate"
    if kind.endswith("-player"):
        return "other_player"
    if kind == "friendly-npc":
        return "friendly_npc"
    return "target_hostile_npc"


def guide_ctx(ctx):
    return ctx if ctx in ("ooc", "combat") else "restricted"


def _code(counts, hsv=None):
    d = probes.dominant(counts)
    if d == "-":
        return None
    weak = d.endswith("*")
    c = CODE.get(d.rstrip("*"), "E")
    if c == "X" and isinstance(hsv, dict) and probes.dominant(hsv).rstrip("*") == "true":
        c = "X"   # v2.2.22: HasSecretValues() == true means SOME values secret (was "S": whole object); see fields
    return c + ("?" if weak else "")


def _merge(items, item, unit, ctx, cell):
    cur = items.setdefault(item, {}).setdefault(unit, {}).get(ctx)
    if cur is None or (cell.get("n") or 0) > (cur.get("n") or 0):
        items[item][unit][ctx] = cell


DET_MAP = {"casting": ("det.cast.other", "det.cast.self"), "whichSpell": ("det.cast.otherSpell", None),
           "anyAura": ("det.aura.present.other", "det.aura.present.self"), "stacksDuration": ("det.aura.stacks", "det.aura.stacks"),
           "dispellable": ("det.aura.dispellable", "det.aura.dispellable"), "myAura": ("det.aura.mine", "det.aura.mine")}
ANS = {"yes": "C", "partial": "C?", "no": "S"}


def combat(dump, build=None, captured=None, source=None):
    cp = dump.log.get("combatProbe") or {}
    items, obs, extra = {}, [], {}
    for ctx, byU in (cp.get("cells") or {}).items():
        for ucls, byI in (byU or {}).items():
            for item, c in (byI or {}).items():
                if not isinstance(c, dict):
                    continue
                gid = GUIDE_ITEM.get(item)
                rets = dict(probes.kv(c.get("r")))
                first = rets.get(1) or rets.get("1") or (next(iter(rets.values())) if rets else None)
                if item.startswith("aura:GetAuraDataByIndex[HARMFUL") and (c.get("f") or {}).get("dispelName"):
                    code = _code(c["f"]["dispelName"])
                    if code:
                        _merge(items, "aura.dispel", guide_unit(ucls), guide_ctx(ctx),
                               {"code": code, "n": c.get("n"), "api": "C_UnitAuras.GetAuraDataByIndex", "note": "dispelName field"})
                code = _code(first, c.get("hsv"))
                if code is None:
                    continue
                cell = {"code": code, "n": c.get("n"), "api": item}
                if c.get("f"):   # v2.2.22: per-field dominant codes ride along with the struct code (schema: in note)
                    fl = ["%s=%s" % (k, CODE.get(probes.dominant(v).rstrip("*"), "E")) for k, v in sorted(c["f"].items())
                          if isinstance(v, dict) and probes.dominant(v) != "-"]
                    if fl:
                        cell["note"] = ("fields: " + " ".join(fl))[:200]
                if gid:
                    _merge(items, gid, guide_unit(ucls), guide_ctx(ctx), cell)
                elif item in EXTRA_OBS:
                    key = (item, guide_unit(ucls), guide_ctx(ctx))
                    if key not in extra or (cell["n"] or 0) > (extra[key]["n"] or 0):
                        extra[key] = dict(cell, item="probe." + item, unit=key[1], context=key[2])
    obs.extend(extra[k] for k in sorted(extra))
    for key, tl in (cp.get("timeLeft") or {}).items():
        ctx, _, ucls = key.partition("|")
        d = tl.get("duration") or {}
        code = "C" if tl.get("derivedOk") and tl.get("derivedState") == "C" else ("E" if tl.get("derivedOk") is False else "S")
        _merge(items, "channel.timeLeft" if tl.get("kind") == "channel" else "cast.timeLeft", guide_unit(ucls), guide_ctx(ctx),
               {"code": code, "n": 1, "api": "endTimeMS - GetTime()*1000",
                "note": "duration object %s (HasSecretValues %s)" % (d.get("state"), d.get("HasSecretValues"))})
    for ctx, byU in (cp.get("det") or {}).items():
        for ucls, byQ in (byU or {}).items():
            selfu = guide_unit(ucls) == "player"
            for q, r in (byQ or {}).items():
                m = DET_MAP.get(q)
                gid = m and (m[1] if selfu else m[0])
                if not gid or not isinstance(r, dict):
                    continue
                ans = probes._det_answer(r).rstrip("*")
                if ans not in ANS:
                    continue
                n = sum(v for k, v in r.items() if k in ("yes", "partial", "no"))
                _merge(items, gid, "any", guide_ctx(ctx), {"code": ANS[ans], "n": n, "note": ("%s: %s" % (ucls, r.get("ev") or ans))[:120]})
    inf = dump.log.get("inference") or {}
    for ctx, sigs in (inf.get("inputs") or {}).items():
        for sig, gid in (("playerCast.event", "det.cast.self"), ("aura.auraInstanceID", "det.aura.change"), ("aura.duration", "det.aura.duration")):
            r = (sigs or {}).get(sig)
            if r:
                code = "C" if r.get("r", 0) and not r.get("u", 0) else ("S" if not r.get("r", 0) else "C?")
                _merge(items, gid, "any", guide_ctx(ctx), {"code": code, "n": r.get("r", 0) + r.get("u", 0),
                                                           "note": "%s readable %s / unreadable %s" % (sig, r.get("r", 0), r.get("u", 0))})
    tk = probes.tokens(dump)
    for f in tk["families"]:
        for ctx, c in f["ctx"].items():
            g = (c["checks"].get("UnitGUID") or {}).get("exist")
            if g:
                obs.append({"item": "unitToken.%s.identity" % f["family"], "unit": "any", "context": guide_ctx(ctx),
                            "code": CODE.get(g.rstrip("*"), "E") + ("?" if g.endswith("*") else ""), "n": c["exist"], "api": "UnitGUID",
                            "note": f["summary"]["works"][:100]})
    # v2.2.4: C_DamageMeter field classification (DamageMeter.lua: per combat + after combat; codes only)
    for ctx, fields in ((dump.log.get("damageMeter") or {}).get("schema") or {}).items():
        gctx = "ooc" if ctx == "after-combat" else guide_ctx(ctx)
        for k, counts in sorted((fields or {}).items()):
            if not isinstance(counts, dict) or k.startswith("error:"):
                continue
            c = _code(counts)
            if c:
                obs.append({"item": "damageMeter.%s" % k, "unit": "any", "context": gctx, "code": c, "n": sum(v for v in counts.values()
                            if isinstance(v, (int, float))), "api": "C_DamageMeter", "note": "DamageMeter.lua %s" % ctx})
    return {"schema": "foreverdump.combat/1", "build": build, "captured": captured,
            "source": source or "ForeverDump CombatProbe/Tokens", "items": items, "observations": obs}


def lab(dump):
    return {"lab": as_list(dump.log.get("lab")), "controls": as_list(dump.log.get("controls"))}


def build_label(dump):
    m = dump.meta()
    return "%s.%s" % (m.get("version", "?"), m.get("build", "?"))


def captured(dump):
    m = dump.meta()
    t = m.get("time")
    if isinstance(t, (int, float)):
        from . import timefmt
        d = timefmt.dt(t)
        return (d if d.tzinfo else d.astimezone()).isoformat(timespec="seconds")
    return m.get("date")
