"""Expected secrecy (ground truth) from the Forever 70245 API secrecy inventory
(data/api-secrecy-inventory-forever-70245.tsv: one row per documented function / event / predicate with every Secret*,
Requires*, NeverSecret, ConditionalSecret tag, the returns/payload and the expanded struct fields).

expected(key, pos, field) -> {"class": always|conditional|never|none, "tag", "nilable", "container", "mayReturnNothing",
                              "variadic", "source"}
Rules (research notes, 2026-10-07): SecretReturns / SecretPayloads / SecretValue -> always; function/event-level
SecretWhen* / SecretIn* / SecretOn* -> conditional (and propagated to every struct field not marked NeverSecret);
NeverSecret -> never; ConditionalSecret -> conditional; else none."""
import os
import re

DEFAULT = os.path.join(os.path.dirname(__file__), "data", "api-secrecy-inventory-forever-70245.tsv")
CONTAINER_TYPES = re.compile(r"^(Lua\w*Object|LuaDurationObject|table|LuaValueReference|\w*Calculator|\w*Binding\w*)$")
COND_TAG = re.compile(r"^(SecretWhen\w+|SecretIn\w+|SecretOn\w+)$")
# tag -> live predicate (for reporting)
PREDICATE = {
    "SecretWhenCooldownsRestricted": "C_Secrets.ShouldSpellCooldownBeSecret / ShouldCooldownsBeSecret",
    "SecretWhenAurasRestricted": "C_Secrets.ShouldAurasBeSecret",
    "SecretWhenUnitAuraRestricted": "C_Secrets.ShouldUnitAura{Index,Instance,Slot}BeSecret",
    "SecretWhenUnitStatsRestricted": "C_Secrets.ShouldUnitStatsBeSecret",
    "SecretWhenUnitPowerRestricted": "C_Secrets.ShouldUnitPowerBeSecret(unit, powerType)",
    "SecretWhenUnitPowerMaxRestricted": "C_Secrets.ShouldUnitPowerMaxBeSecret",
    "SecretWhenUnitHealthMaxRestricted": "C_Secrets.ShouldUnitHealthMaxBeSecret(unit)",
    "SecretWhenUnitIdentityRestricted": "C_Secrets.ShouldUnitIdentityBeSecret(unit)",
    "SecretWhenUnitNameIdentityRestricted": "C_Secrets.ShouldUnitIdentityBeSecret(unit)",
    "SecretWhenUnitComparisonRestricted": "C_Secrets.ShouldUnitComparisonBeSecret",
    "SecretWhenUnitSpellCastRestricted": "C_Secrets.ShouldUnitSpellCastBeSecret / ShouldUnitSpellCastingBeSecret",
    "SecretWhenUnitThreatStateRestricted": "C_Secrets.ShouldUnitThreatStateBeSecret",
    "SecretWhenUnitThreatValuesRestricted": "C_Secrets.ShouldUnitThreatValuesBeSecret",
    "SecretWhenTotemSlotSecret": "C_Secrets.ShouldTotemSlotBeSecret",
    "SecretWhenInCombat": "InCombatLockdown()",
    "SecretInChatMessagingLockdown": "GetAddOnRestrictionState(Chat) == Active",
    "SecretInActivePvPMatch": "GetAddOnRestrictionState(PvPMatch) == Active",
    "SecretOnRestrictedMaps": "GetAddOnRestrictionState(Map) == Active",
}


def _tags(s):
    out = {}
    for part in (s or "").split(";"):
        part = part.strip()
        if not part:
            continue
        k, _, v = part.partition("=")
        out[k.strip()] = v.strip() if v else "true"
    return out


def _slot(s):
    """'name:type?[Flag=true;...]' -> dict"""
    s = s.strip()
    m = re.match(r"^([^:\[]+):([^\[]*?)(\?)?(?:\[(.*)\])?$", s)
    if not m:
        return {"name": s, "type": "", "nilable": False, "flags": {}}
    return {"name": m.group(1).strip(), "type": m.group(2).strip(), "nilable": bool(m.group(3)), "flags": _tags(m.group(4))}


def _split_top(s, sep=" | "):
    """split on ' | ' outside [...] / {...}"""
    out, depth, cur, i = [], 0, "", 0
    while i < len(s):
        ch = s[i]
        if ch in "[{":
            depth += 1
        elif ch in "]}":
            depth -= 1
        if depth == 0 and s.startswith(sep, i):
            out.append(cur)
            cur = ""
            i += len(sep)
            continue
        cur += ch
        i += 1
    if cur.strip():
        out.append(cur)
    return out


class Inventory:
    def __init__(self, path=None):
        self.path = path or DEFAULT
        self.functions, self.events, self.predicates, self.structs = {}, {}, {}, {}
        if not os.path.exists(self.path):
            return
        with open(self.path, encoding="utf-8") as f:
            next(f, None)
            for line in f:
                cols = line.rstrip("\n").split("\t")
                if len(cols) < 3:
                    continue
                cols += [""] * (5 - len(cols))
                kind, name, tags, rets, structs = cols[:5]
                entry = {"tags": _tags(tags), "slots": [_slot(x) for x in _split_top(rets)] if rets.strip() else [], "structs": {}}
                for sm in re.finditer(r"(\w+)\{(.*?)\}(?=\s*(?:;|\||$)|\s+\w+\{)", structs):
                    fields = [_slot(x) for x in _split_top(sm.group(2))]
                    entry["structs"][sm.group(1)] = fields
                    self.structs.setdefault(sm.group(1), fields)
                if kind == "function":
                    self.functions[name] = entry
                elif kind == "event":
                    self.events[name] = entry
                elif kind == "predicate":
                    self.predicates[name] = entry

    def __bool__(self):
        return bool(self.functions or self.events)

    def entry(self, key):
        kind, _, name = key.partition(":")
        return (self.functions if kind == "api" else self.events if kind == "event" else {}).get(name)

    @staticmethod
    def _parent(tags):
        if tags.get("SecretReturns") == "true" or tags.get("SecretPayloads") == "true":
            return "always", None
        for k in sorted(tags):
            if COND_TAG.match(k) and tags[k] == "true":
                return "conditional", k
        return "none", None

    @staticmethod
    def _slot_class(slot, parent):
        f = slot.get("flags") or {}
        if f.get("SecretValue") == "true":
            return "always"
        if f.get("NeverSecret") == "true":
            return "never"
        if f.get("ConditionalSecret") == "true":
            return "conditional"
        return parent

    def expected(self, key, pos=1, field=None):
        e = self.entry(key)
        if e is None:
            return None
        pc, tag = self._parent(e["tags"])
        out = {"tag": tag, "predicate": PREDICATE.get(tag), "mayReturnNothing": e["tags"].get("MayReturnNothing") == "true",
               "variadic": not e["slots"], "source": "inventory-70245", "returns": len(e["slots"])}
        slot = e["slots"][pos - 1] if 0 < pos <= len(e["slots"]) else None
        cls = self._slot_class(slot, pc) if slot else pc
        out["nilable"] = bool(slot and slot["nilable"])
        out["type"] = slot["type"] if slot else None
        out["container"] = bool(slot and (CONTAINER_TYPES.match(slot["type"] or "") or slot["type"] in e["structs"]
                                          or slot["type"] in self.structs))
        if field is not None:
            fields = e["structs"].get(slot["type"]) if slot else None
            fields = fields or (self.structs.get(slot["type"]) if slot else None) or []
            fs = next((x for x in fields if x["name"] == field), None)
            if fs:
                cls = self._slot_class(fs, cls)   # function tag propagated unless the field says otherwise
                out["nilable"] = fs["nilable"]
                out["type"] = fs["type"]
                out["container"] = bool(CONTAINER_TYPES.match(fs["type"] or ""))
                out["fieldDocumented"] = True
            else:
                out["fieldDocumented"] = False
        out["class"] = cls
        return out

    def struct_field(self, struct, field):
        fields = self.structs.get(struct) or []
        fs = next((x for x in fields if x["name"] == field), None)
        if not fs:
            return None
        return {"class": self._slot_class(fs, "none"), "nilable": fs["nilable"], "type": fs["type"], "tag": None,
                "source": "inventory-70245 (struct)"}

    def stats(self):
        import collections
        c = collections.Counter()
        for e in self.functions.values():
            pc, _ = self._parent(e["tags"])
            c["functions:" + pc] += 1
        for e in self.events.values():
            pc, _ = self._parent(e["tags"])
            c["events:" + pc] += 1
        nev = sum(1 for s in self.structs.values() for f in s if (f.get("flags") or {}).get("NeverSecret") == "true")
        return {"functions": len(self.functions), "events": len(self.events), "predicates": len(self.predicates),
                "structs": len(self.structs), "neverSecretFields": nev, "byClass": dict(c)}
