"""Reference-data miner (v2.2.18): versioned lookup tables mined from combat logs (offline, box only).

Tables (spell / NPC ids and game data only; never player GUIDs or names):
  spells[id]  -> class (+ votes), school, castTime (START->SUCCESS median), channel, cooldown (min repeat interval per
                 caster), cost (median powerCost), powerType, aura (aura applied by this spell id: duration median,
                 maxStacks, onSelf share), amount bands (non-crit / crit min-max for damage and heal, periodic separate)
  summons[npcId] -> owner class (SPELL_SUMMON / owner field of pet events), kind (totem/pet/guardian)
  npcs[npcId]    -> maxHP per level (advanced log fields when the NPC is the info unit)
  classPower[class] -> power types seen (0 mana, 1 rage, 2 focus, 3 energy, ...)
  castFingerprints[castTime 0.1 s bucket] -> classes that own a spell with that cast time
Class truth for players comes from a small name seed of class-signature spells, then propagates to every spell id cast
only by one class (>= 2 casters or >= 3 casts). Per-run truth (player -> class, enemy flag) is written separately and
stays on the box (it carries GUIDs).
"""
import collections, csv, glob, io, json, os, re, statistics, sys

SEED = {
    "WARRIOR": ["Heroic Strike", "Mortal Strike", "Charge", "Hamstring", "Overpower", "Rend", "Execute", "Battle Shout",
                "Whirlwind", "Bloodthirst", "Sunder Armor", "Thunder Clap", "Shield Bash", "Pummel", "Intercept",
                "Berserker Rage", "Bloodrage", "Demoralizing Shout", "Shield Block", "Revenge", "Slam", "Cleave"],
    "ROGUE": ["Sinister Strike", "Eviscerate", "Backstab", "Kidney Shot", "Gouge", "Kick", "Sap", "Cheap Shot",
              "Slice and Dice", "Vanish", "Stealth", "Evasion", "Sprint", "Blind", "Garrote", "Ambush", "Rupture",
              "Expose Armor", "Hemorrhage", "Feint"],
    "MAGE": ["Frostbolt", "Fireball", "Arcane Missiles", "Frost Nova", "Polymorph", "Blink", "Fire Blast",
             "Arcane Explosion", "Ice Barrier", "Scorch", "Cone of Cold", "Counterspell", "Arcane Intellect",
             "Frost Armor", "Ice Armor", "Mana Shield", "Pyroblast", "Flamestrike", "Blizzard", "Evocation",
             "Ice Block", "Conjure Water", "Conjure Food"],
    "PRIEST": ["Power Word: Shield", "Flash Heal", "Renew", "Shadow Word: Pain", "Mind Blast", "Greater Heal",
               "Psychic Scream", "Smite", "Heal", "Lesser Heal", "Power Word: Fortitude", "Inner Fire", "Mind Flay",
               "Fade", "Dispel Magic", "Holy Fire", "Prayer of Healing", "Vampiric Embrace", "Shadowform",
               "Devouring Plague", "Mind Control"],
    "WARLOCK": ["Shadow Bolt", "Corruption", "Immolate", "Curse of Agony", "Fear", "Drain Life", "Life Tap",
                "Death Coil", "Searing Pain", "Curse of Weakness", "Curse of Tongues", "Curse of Exhaustion",
                "Drain Soul", "Drain Mana", "Howl of Terror", "Demon Skin", "Demon Armor", "Summon Imp",
                "Summon Voidwalker", "Summon Succubus", "Summon Felhunter", "Health Funnel", "Siphon Life",
                "Shadowburn", "Rain of Fire", "Hellfire", "Soul Fire", "Create Healthstone"],
    "HUNTER": ["Arcane Shot", "Serpent Sting", "Multi-Shot", "Aimed Shot", "Concussive Shot", "Wing Clip",
               "Hunter's Mark", "Raptor Strike", "Mongoose Bite", "Aspect of the Hawk", "Aspect of the Monkey",
               "Aspect of the Cheetah", "Aspect of the Pack", "Aspect of the Beast", "Scatter Shot", "Feign Death",
               "Freezing Trap", "Frost Trap", "Immolation Trap", "Explosive Trap", "Rapid Fire", "Viper Sting",
               "Scorpid Sting", "Mend Pet", "Call Pet", "Revive Pet", "Disengage", "Distracting Shot", "Volley",
               "Intimidation", "Bestial Wrath", "Counterattack", "Wyvern Sting", "Trueshot Aura"],
    "DRUID": ["Moonfire", "Wrath", "Rejuvenation", "Regrowth", "Healing Touch", "Entangling Roots", "Starfire",
              "Bear Form", "Cat Form", "Dire Bear Form", "Travel Form", "Aquatic Form", "Claw", "Rake", "Shred",
              "Ferocious Bite", "Rip", "Maul", "Swipe", "Bash", "Mark of the Wild", "Thorns", "Barkskin",
              "Hibernate", "Faerie Fire", "Faerie Fire (Feral)", "Insect Swarm", "Moonkin Form", "Tranquility",
              "Innervate", "Nature's Grasp", "Prowl", "Dash", "Feral Charge", "Pounce", "Ravage", "Cower",
              "Abolish Poison", "Remove Curse", "Swiftmend", "Demoralizing Roar", "Enrage", "Frenzied Regeneration"],
    "SHAMAN": ["Lightning Bolt", "Earth Shock", "Frost Shock", "Flame Shock", "Healing Wave", "Lesser Healing Wave",
               "Chain Lightning", "Purge", "Lightning Shield", "Ghost Wolf", "Searing Totem", "Healing Stream Totem",
               "Stoneskin Totem", "Strength of Earth Totem", "Earthbind Totem", "Grounding Totem", "Tremor Totem",
               "Windfury Totem", "Mana Spring Totem", "Magma Totem", "Fire Nova Totem", "Chain Heal",
               "Rockbiter Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Windfury Weapon", "Stormstrike",
               "Water Breathing", "Water Walking", "Astral Recall", "Cure Poison", "Cure Disease"],
    "PALADIN": ["Holy Light", "Flash of Light", "Hammer of Justice", "Seal of Righteousness", "Judgement",
                "Blessing of Might", "Divine Shield", "Consecration", "Holy Shock", "Exorcism", "Seal of the Crusader",
                "Seal of Command", "Seal of Light", "Seal of Wisdom", "Seal of Justice", "Blessing of Wisdom",
                "Blessing of Kings", "Blessing of Freedom", "Blessing of Protection", "Blessing of Sacrifice",
                "Lay on Hands", "Divine Protection", "Cleanse", "Purify", "Devotion Aura", "Retribution Aura",
                "Concentration Aura", "Hammer of Wrath", "Repentance", "Holy Wrath", "Righteous Fury",
                "Blessing of Light", "Blessing of Salvation", "Sense Undead", "Turn Undead"],
}
CLASSES = sorted(SEED)
NAME2CLASS = {n: c for c, ns in SEED.items() for n in ns}
# SPELL_* advanced layout (base 12): info 12, owner 13, curHP 14, maxHP 15, AP 16, SP 17, armor 18, absorb 19,
# ?, ?, powerType 22, curPower 23, maxPower 24, powerCost 25, x 26, y 27, map 28, facing 29, level 30, amount 31
ADV = {"SPELL": 12, "RANGE": 12, "SWING": 9}
TS_RE = re.compile(r"^(\d+)/(\d+)/(\d+) (\d+):(\d+):(\d+)\.(\d+)")


def _t(head):
    m = TS_RE.match(head)
    if not m:
        return None
    mo, d, y, hh, mm, ss, ms = m.groups()
    return log_seconds(int(y), int(mo), int(d), int(hh), int(mm), int(ss)) + int(ms) / 10.0 ** len(ms)


def log_seconds(y, mo, d, hh, mm, ss):
    """log-local wall clock -> seconds on a continuous day count (proleptic ordinal). Time audit (2026-10-10): was
    day-of-month * 86400, which jumps backwards at a month boundary (10/31 23:59 -> 11/1 00:00) and ignored the year;
    differences within a month are unchanged. The value is zone-free (the log's local clock); epoch joins go through
    aurapresence.epoch_to_logsec with the log's own UTC offset (log_utc_offset)."""
    import datetime as _dt
    return ((_dt.date(y, mo, d).toordinal() * 24 + hh) * 60 + mm) * 60 + ss


ZONE_RE = re.compile(r"^\d+/\d+/\d+ \d+:\d+:\d+(?:\.\d+)?([+-]\d+(?:\.\d+)?)$")


def log_utc_offset(path, probe=50):
    """hours east of UTC carried by the log's own timestamps ('10/10/2026 11:38:13.243-4' -> -4.0); None if absent.
    Log times are the client's local time; using the box zone instead misplaces every join when the two differ."""
    with open(path, errors="replace") as f:
        for i, raw in enumerate(f):
            if i >= probe:
                break
            j = raw.find("  ")
            m = ZONE_RE.match(raw[:j]) if j > 0 else None
            if m:
                return float(m.group(1))
    return None


SUFFIX_RE = re.compile(r"^\d+/\d+/\d+ \d+:\d+:\d+(?:\.\d+)?([+-]\d+(?:\.\d+)?)$")


def lines(path):
    """(log seconds, fields). v2.2.26 DST: log seconds are the wall clock of the file's FIRST zone suffix
    (= log_utc_offset), so a capture spanning a DST change (11/1 02:00 EDT -4 -> 01:00 EST -5) stays continuous:
    a row stamped in another zone is shifted by the suffix difference. Rows without a suffix are left as they are."""
    ref = None
    with open(path, errors="replace") as f:
        for raw in f:
            i = raw.find("  ")
            if i < 0:
                continue
            head, rest = raw[:i], raw[i + 2:].rstrip("\n")
            try:
                p = next(csv.reader(io.StringIO(rest)))
            except Exception:
                continue
            if not p:
                continue
            t = _t(head)
            m = SUFFIX_RE.match(head) if t is not None else None
            if m:
                suf = float(m.group(1))
                if ref is None:
                    ref = suf
                elif suf != ref:
                    t -= (suf - ref) * 3600
            yield t, p


def npc_id(guid):
    if isinstance(guid, str) and guid.startswith(("Creature-", "Pet-", "Vehicle-")):
        parts = guid.split("-")
        if len(parts) > 5:
            try:
                return int(parts[5])
            except ValueError:
                return None
    return None


def is_player(g):
    return isinstance(g, str) and g.startswith("Player-")


def _int(x, default=None):
    try:
        return int(x)
    except (TypeError, ValueError):
        try:
            return int(x, 16)
        except (TypeError, ValueError):
            return default


def mine(paths):
    """one pass per log: collect raw observations; classes resolved at the end"""
    obs = {"cast": collections.defaultdict(list), "school": collections.defaultdict(collections.Counter),
           "name": {}, "casters": collections.defaultdict(set), "castsBy": collections.defaultdict(collections.Counter),
           "repeat": collections.defaultdict(list), "cost": collections.defaultdict(list),
           "ptype": collections.defaultdict(collections.Counter), "aura": collections.defaultdict(list),
           "auraSelf": collections.defaultdict(collections.Counter), "stacks": collections.defaultdict(int),
           "amt": collections.defaultdict(lambda: collections.defaultdict(list)),
           "summon": collections.defaultdict(collections.Counter), "petOwner": collections.defaultdict(collections.Counter),
           "npcHP": collections.defaultdict(dict), "channel": collections.defaultdict(list),
           "playerPower": collections.defaultdict(collections.Counter), "totemNames": {}}
    per_run = {}
    for path in paths:
        run = os.path.basename(os.path.dirname(path))
        start, last_ok, aura_on = {}, {}, {}
        chan = {}
        rp = per_run.setdefault(run, {"players": {}, "votes": collections.defaultdict(collections.Counter),
                                      "spells": collections.defaultdict(collections.Counter)})
        for t, p in lines(path):
            sub = p[0]
            if len(p) < 9 or t is None:
                continue
            src, sflags, dst = p[1], _int(p[3], 0), p[5]
            if is_player(src):
                pl = rp["players"].setdefault(src, {"first": t, "last": t, "hostile": bool(sflags & 0x40),
                                                    "mine": bool(sflags & 0x1), "_hv": 0, "_fv": 0})
                pl["last"] = t
                # v2.2.24 (run 18): a mind-controlled team-mate logs as a hostile PET (0x1148); those flags do not
                # vote, and side = majority of the remaining flags (was: any hostile flag -> hostile for good)
                if not sflags & 0x1000:
                    if sflags & 0x40:
                        pl["_hv"] += 1
                    elif sflags & 0x10:
                        pl["_fv"] += 1
                    pl["hostile"] = pl["_hv"] > pl["_fv"]
            if not sub.startswith(("SPELL_", "RANGE_")) or len(p) < 12:
                continue
            sid = _int(p[9])
            if sid is None:
                continue
            obs["name"].setdefault(sid, p[10])
            sch = _int(p[11])
            if sch:
                obs["school"][sid][sch] += 1
            base = 12
            adv = len(p) > base + 18 and p[base] not in ("", "0000000000000000")
            if is_player(src):
                if sub in ("SPELL_CAST_SUCCESS", "SPELL_CAST_START", "SPELL_AURA_APPLIED", "SPELL_DAMAGE", "SPELL_HEAL",
                           "SPELL_SUMMON", "SPELL_PERIODIC_DAMAGE", "SPELL_PERIODIC_HEAL", "RANGE_DAMAGE"):
                    rp["spells"][src][sid] += 1
                    c = NAME2CLASS.get(p[10])
                    if c:
                        rp["votes"][src][c] += 1
                if adv and p[base] == src:
                    pt = _int(p[base + 10])
                    if pt is not None:
                        rp["players"][src].setdefault("ptypes", collections.Counter())[pt] += 1
            if sub == "SPELL_CAST_START" and is_player(src):
                start[(src, sid)] = t
            elif sub == "SPELL_CAST_SUCCESS" and is_player(src):
                st = start.pop((src, sid), None)
                if st is not None and t - st <= 10:
                    obs["cast"][sid].append(round(t - st, 2))
                else:
                    obs["cast"][sid].append(0.0)
                obs["casters"][sid].add((run, src))
                obs["castsBy"][sid][(run, src)] += 1
                lt = last_ok.get((src, sid))
                if lt is not None:
                    obs["repeat"][sid].append(t - lt)
                last_ok[(src, sid)] = t
                if adv and p[base] == src:
                    cost = _int(p[base + 13])
                    if cost:
                        obs["cost"][sid].append(cost)
                    pt = _int(p[base + 10])
                    if pt is not None:
                        obs["ptype"][sid][pt] += 1
            elif sub == "SPELL_CAST_FAILED" and is_player(src):
                start.pop((src, sid), None)
            elif sub in ("SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH") and is_player(src):
                aura_on[(dst, sid, src)] = t
                obs["auraSelf"][sid]["self" if dst == src else "other"] += 1
            elif sub == "SPELL_AURA_APPLIED_DOSE":
                obs["stacks"][sid] = max(obs["stacks"][sid], _int(p[13] if len(p) > 13 else 0, 0) or 0)
            elif sub == "SPELL_AURA_REMOVED":
                a0 = aura_on.pop((dst, sid, src), None)
                if a0 is not None and 0 < t - a0 <= 1800:
                    obs["aura"][sid].append(round(t - a0, 1))
            elif sub == "SPELL_SUMMON":
                n = npc_id(dst)
                if n is not None and is_player(src):
                    obs["summon"][n][("summon", src, run)] += 1
                    obs["totemNames"].setdefault(n, p[6] if "Totem" in (p[6] or "") else None)
            if adv:
                info, owner = p[base], p[base + 1]
                n = npc_id(info)
                if n is not None and is_player(owner):
                    obs["petOwner"][n][(owner, run)] += 1
                if is_player(info):
                    pmx, plvl = _int(p[base + 3]), _int(p[base + 18])
                    if pmx and plvl:
                        hd = rp.setdefault("hp", {}).setdefault(info, {})
                        hd[plvl] = max(hd.get(plvl, 0), pmx)
                if n is not None:
                    mx, lvl = _int(p[base + 3]), _int(p[base + 18])
                    if mx and lvl is not None:
                        d = obs["npcHP"][n]
                        d[lvl] = max(d.get(lvl, 0), mx)
            # amounts (players only, base-relative suffix)
            if is_player(src) and adv and sub in ("SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE", "RANGE_DAMAGE",
                                                  "SPELL_HEAL", "SPELL_PERIODIC_HEAL"):
                amt = _int(p[base + 19]) if len(p) > base + 19 else None
                heal = "HEAL" in sub
                crit_i = base + 19 + (3 if heal else 6)
                crit = len(p) > crit_i and p[crit_i] == "1"
                if amt and amt > 0:
                    k = ("heal" if heal else "dmg") + ("P" if "PERIODIC" in sub else "") + ("C" if crit else "")
                    obs["amt"][sid][k].append(amt)
        # resolve classes for this run
        for g, v in rp["votes"].items():
            if g in rp["players"] and v:
                c, n = v.most_common(1)[0]
                if n >= 2 and n >= 0.8 * sum(v.values()):
                    rp["players"][g]["class"] = c
    return obs, per_run


def propagate(obs, per_run, rounds=3):
    """spell -> class from players whose class is known; then re-classify players from the new spells"""
    spell_class = {}
    for _ in range(rounds):
        sc = collections.defaultdict(collections.Counter)
        for run, rp in per_run.items():
            for g, sp in rp["spells"].items():
                c = rp["players"].get(g, {}).get("class")
                if not c:
                    continue
                for sid, n in sp.items():
                    sc[sid][(c, g)] += n
        spell_class = {}
        for sid, cg in sc.items():
            by = collections.Counter()
            casters = collections.defaultdict(set)
            for (c, g), n in cg.items():
                by[c] += n
                casters[c].add(g)
            if len(by) == 1:
                c = next(iter(by))
                # >= 3 distinct casters (or a seed name): one or two players of one class casting a generic spell
                # (mount, bandage, flag capture) must not tag it as a class spell
                if len(casters[c]) >= 3 or NAME2CLASS.get(obs["name"].get(sid)) == c:
                    spell_class[sid] = (c, by[c], len(casters[c]))
        for run, rp in per_run.items():
            for g, sp in rp["spells"].items():
                pl = rp["players"].get(g)
                if not pl:
                    continue
                v = collections.Counter()
                for sid, n in sp.items():
                    if sid in spell_class:
                        v[spell_class[sid][0]] += n
                if v:
                    c, n = v.most_common(1)[0]
                    if n >= 2 and n >= 0.9 * sum(v.values()):
                        pl["class"] = c
    return spell_class


def _band(xs):
    xs = sorted(xs)
    if not xs:
        return None
    lo, hi = xs[int(0.02 * (len(xs) - 1))], xs[int(0.98 * (len(xs) - 1))]
    return {"min": lo, "max": hi, "n": len(xs)}


def build(paths, build_id=None):
    obs, per_run = mine(paths)
    spell_class = propagate(obs, per_run)
    spells = {}
    allids = set(obs["name"])
    for sid in allids:
        e = {}
        if sid in spell_class:
            c, n, ncast = spell_class[sid]
            e["class"] = c
            e["votes"] = n
            e["casters"] = ncast
        if obs["school"].get(sid):
            e["school"] = obs["school"][sid].most_common(1)[0][0]
        ct = obs["cast"].get(sid)
        if ct and len(ct) >= 2:
            # v2.2.20: low quantile, not the median: pushback only lengthens START->SUCCESS (run 15 moved 3 medians by
            # 0.5-3 s); the 10th percentile tracks the planned cast time
            cts = sorted(ct)
            p10, med = cts[int(0.1 * (len(cts) - 1))], cts[(len(cts) - 1) // 2]
            # a p10 under half the median is a talent/proc shortcut (e.g. Fel Domination 712: 0.5 s vs 6 s), not pushback
            e["castTime"] = round(p10 if p10 >= 0.5 * med else med, 2)
        rep = sorted(x for x in obs["repeat"].get(sid, []) if x >= 1.4)
        if len(rep) >= 3:
            e["cooldown"] = round(rep[0], 1)
        if obs["cost"].get(sid):
            e["cost"] = int(statistics.median(obs["cost"][sid]))
        if obs["ptype"].get(sid):
            e["powerType"] = obs["ptype"][sid].most_common(1)[0][0]
        if obs["aura"].get(sid):
            e["auraDur"] = round(statistics.median(obs["aura"][sid]), 1)
        if obs["stacks"].get(sid):
            e["maxStacks"] = obs["stacks"][sid]
        if obs["auraSelf"].get(sid):
            a = obs["auraSelf"][sid]
            e["auraSelfShare"] = round(a["self"] / float(a["self"] + a["other"]), 2)
        for k, xs in (obs["amt"].get(sid) or {}).items():
            if len(xs) >= 3:
                e.setdefault("amount", {})[k] = _band(xs)
        if e:
            spells[sid] = e
    # summons / pets -> owner class
    summons = {}
    for n in set(obs["summon"]) | set(obs["petOwner"]):
        v = collections.Counter()
        kind = "pet"
        for (k, g, run), cnt in obs["summon"].get(n, {}).items():
            c = per_run.get(run, {}).get("players", {}).get(g, {}).get("class")
            if c:
                v[c] += cnt
            kind = "totem" if obs["totemNames"].get(n) else "summon"
        for (g, run), cnt in obs["petOwner"].get(n, {}).items():
            c = per_run.get(run, {}).get("players", {}).get(g, {}).get("class")
            if c:
                v[c] += 1
        if v:
            c, cnt = v.most_common(1)[0]
            summons[n] = {"ownerClass": c, "share": round(cnt / float(sum(v.values())), 2), "n": sum(v.values()),
                          "kind": kind}
    npcs = {n: {"maxHP": {str(l): h for l, h in sorted(d.items())}} for n, d in obs["npcHP"].items()}
    class_power = collections.defaultdict(collections.Counter)
    for run, rp in per_run.items():
        for g, pl in rp["players"].items():
            if pl.get("class") and pl.get("ptypes"):
                for pt, cnt in pl["ptypes"].items():
                    class_power[pl["class"]][pt] += cnt
    cp = {c: {str(k): v for k, v in cnt.items()} for c, cnt in class_power.items()}
    # class x level -> median max health of players (enemy health estimate base when UnitHealthMax is secret)
    clhp = collections.defaultdict(list)
    for run, rp in per_run.items():
        for g, lv in (rp.get("hp") or {}).items():
            c = rp["players"].get(g, {}).get("class")
            if c:
                for lvl, mx in lv.items():
                    clhp["%s:%d" % (c, lvl)].append(mx)
    class_level_hp = {k: int(statistics.median(v)) for k, v in sorted(clhp.items()) if len(v) >= 2}
    fp = collections.defaultdict(set)
    poisoned = set()
    for sid, e in spells.items():
        if e.get("castTime", 0) > 0:
            if e.get("class"):
                fp["%.1f" % e["castTime"]].add(e["class"])
            else:
                poisoned.add("%.1f" % e["castTime"])   # a classless (generic) spell shares this cast time
    for k in poisoned:
        fp.pop(k, None)
    out = {"schema": 1, "build": build_id, "sources": len(paths), "classes": CLASSES,
           "spells": {str(k): v for k, v in sorted(spells.items())}, "summons": {str(k): v for k, v in sorted(summons.items())},
           "npcs": {str(k): v for k, v in sorted(npcs.items())}, "classPower": cp, "classLevelHP": class_level_hp,
           "castFingerprints": {k: sorted(v) for k, v in sorted(fp.items())},
           "spellNames": {str(k): v for k, v in sorted(obs["name"].items()) if k in spells}}
    return out, per_run, spell_class


def merge_learned(ref, learned):
    """fold runtime-learned tables (ForeverDumpDB.refLearned[build]) into the seeds.
    spellClass votes tag classless spells (>=3 votes, one class); a vote against the seed class is a conflict.
    castMs from my own casts fills castTime; a >250 ms change vs the seed is build drift (recorded, seed updated
    only when the learned build is newer than the seed build)."""
    stats = collections.Counter()
    ref.setdefault("drift", {})
    for build, L in sorted((learned or {}).items(), key=lambda kv: str(kv[0])):
        if not isinstance(L, dict):
            continue
        newer = ref.get("build") is None or str(build) > str(ref.get("build"))
        for sid, votes in (L.get("spellClass") or {}).items():
            if not isinstance(votes, dict) or not votes:
                continue
            e = ref["spells"].setdefault(str(sid), {})
            c, n = max(votes.items(), key=lambda kv: kv[1])
            if e.get("class"):
                if c != e["class"] and n >= 3:
                    e["conflict"] = c
                    stats["conflict"] += 1
                else:
                    stats["confirmed"] += 1
            elif n >= 3 and len(votes) == 1:
                e["class"], e["votes"], e["learned"] = c, n, str(build)
                stats["tagged"] += 1
        for sid, c in (L.get("castMs") or {}).items():
            if not isinstance(c, dict) or not c.get("min"):
                continue
            e = ref["spells"].setdefault(str(sid), {})
            live = round(c["min"] / 1000.0, 2)
            if e.get("castTime") and abs(e["castTime"] - live) > 0.25:
                ref["drift"].setdefault(str(build), {})[str(sid)] = {"seed": e["castTime"], "live": live}
                stats["drift"] += 1
                if newer:
                    e["castTime"] = live
            elif not e.get("castTime"):
                e["castTime"] = live
                stats["castTime"] += 1
    return stats


def learned_from_sv(paths):
    from .svcache import parse_file
    out = {}
    for p in paths:
        sv = parse_file(p)
        db = sv.get("ForeverDumpDB") if isinstance(sv, dict) else None
        for b, L in ((db or {}).get("refLearned") or {}).items():
            out.setdefault(str(b), {"spellClass": {}, "castMs": {}})
            for sid, v in (L.get("spellClass") or {}).items():
                d = out[str(b)]["spellClass"].setdefault(str(sid), {})
                for c, n in v.items():
                    d[c] = d.get(c, 0) + n
            for sid, v in (L.get("castMs") or {}).items():
                d = out[str(b)]["castMs"].setdefault(str(sid), {"n": 0})
                d["n"] += v.get("n", 0)
                d["min"] = min(d.get("min", v.get("min")), v.get("min")) if v.get("min") else d.get("min")
    return out


def to_lua(ref):
    """compact runtime table: class code per spell, cast time, aura duration, school, owner class per summon"""
    code = {c: i + 1 for i, c in enumerate(ref["classes"])}
    L = ["-- generated by tools/fdump/refdata.py (v2.2.18) - mined reference data; spell / NPC ids only",
         "local _, ns = ...", "ns.RefData = {", '    build = %s,' % (ref.get("build") or "nil"), "    schema = 1,",
         "    classes = { " + ", ".join('"%s"' % c for c in ref["classes"]) + " },",
         "    -- spellId = { class code, castTime, auraDur, school, cooldown }", "    spells = {"]
    row = []
    for sid, e in ref["spells"].items():
        if not (e.get("class") or e.get("castTime") or e.get("auraDur")):
            continue
        row.append("[%s]={%s,%s,%s,%s,%s}" % (sid, code.get(e.get("class"), 0), e.get("castTime", 0) or 0,
                                              e.get("auraDur", 0) or 0, e.get("school", 0) or 0, e.get("cooldown", 0) or 0))
        if len(row) == 6:
            L.append("        " + ",".join(row) + ",")
            row = []
    if row:
        L.append("        " + ",".join(row) + ",")
    L.append("    },")
    L.append("    -- npcId = owner class code (totems / pets / summons)")
    L.append("    summons = { " + ", ".join("[%s]=%d" % (n, code[v["ownerClass"]]) for n, v in ref["summons"].items()
                                       if v["share"] >= 0.9) + " },")
    L.append("    -- class code = power types seen (0 mana, 1 rage, 2 focus, 3 energy)")
    L.append("    classPower = { " + ", ".join("[%d]={%s}" % (code[c], ",".join(sorted(v, key=int)))
                                          for c, v in sorted(ref["classPower"].items())) + " },")
    L.append("    -- class code = { [level] = median max health } (players, mined)")
    clh = collections.defaultdict(dict)
    for k, v in (ref.get("classLevelHP") or {}).items():
        c, lvl = k.split(":")
        clh[code[c]][int(lvl)] = v
    L.append("    classLevelHP = { " + ", ".join("[%d]={%s}" % (c, ",".join("[%d]=%d" % kv for kv in sorted(d.items())))
                                            for c, d in sorted(clh.items())) + " },")
    L.append("}")
    return "\n".join(L) + "\n"


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("logs", nargs="*")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "data", "refdata.json"))
    ap.add_argument("--lua", default=None)
    ap.add_argument("--truth", default=None, help="per-run player truth (GUIDs: box only)")
    ap.add_argument("--build", type=int, default=None)
    ap.add_argument("--learned", nargs="*", default=None, help="ForeverDump.lua SV files: fold refLearned into the seeds")
    a = ap.parse_args(argv)
    paths = a.logs or sorted(glob.glob("real/*/WoWCombatLog*.txt"))
    ref, per_run, _ = build(paths, a.build)
    if a.learned:
        print("refdata: learned merge", dict(merge_learned(ref, learned_from_sv(a.learned))))
    json.dump(ref, open(a.out, "w"), indent=0, sort_keys=True)
    if a.lua:
        open(a.lua, "w").write(to_lua(ref))
    if a.truth:
        tr = {run: {g: {k: v for k, v in pl.items() if k != "ptypes" and not k.startswith("_")} for g, pl in rp["players"].items()}
              for run, rp in per_run.items()}
        json.dump(tr, open(a.truth, "w"))
    nc = sum(1 for e in ref["spells"].values() if e.get("class"))
    print("refdata: %d spells (%d with class), %d summons, %d npcs, classPower %s" % (
        len(ref["spells"]), nc, len(ref["summons"]), len(ref["npcs"]),
        {c: sorted(v) for c, v in ref["classPower"].items()}))


if __name__ == "__main__":
    main()
