"""v2.2.7 follow-up (runs 6/6b FINDINGS): permanent regression checks for every flaw found in the analysis.

1. engine_health: a capture-module start error and a capture with combat but no HSM output are HIGH leads.
2. worldcap decode: legacy 64-bit packs lose low nibbles -> 'L', never a wrong code; p/q packs decode exactly.
3. coverage fallback: no live target signals -> target timeline rebuilt from MY offensive log events ('log-inferred').
4. coverage fallback: no HSM cast signals -> own casts rebuilt from raw UNIT_SPELLCAST_* (run 6 interrupt scored 0/1).
5. damage-meter join: the meter fight is chosen by TIME, not index (run 6b fight 1 got run 6's meter numbers).
6. replay decide determinism: combat on the tape with 0 decide records is VACUOUS (a failure), not "OK (0 groups)".
7. perf: a real capture whose mean WorldCapture/TokenScan slice exceeds the bench budget is flagged.
Synthetic data only (no names, no GUIDs from a real capture)."""
from __future__ import annotations

import sys
import types
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from fdump import analysis, coverage, damagemeter_join, perf, replay, worldcap  # noqa: E402

ME = "Player-0-00000001"
MOB = "Creature-0-1-1-1-4096-0000000001"
MOB2 = "Creature-0-1-1-1-4096-0000000002"


def fake_dump(log=None, combatlog=None, record=None):
    return types.SimpleNamespace(log=log or {}, combatlog=combatlog or {}, record=record or {})


class EngineHealth(unittest.TestCase):
    def test_capture_error_and_hsm_down(self):
        d = fake_dump(
            log={"selfErrors": [{"sid": "cap-1", "where": "capture:spell knowledge + HSM inference",
                                 "err": "Drift.lua:156: attempt to index global 'os' (a nil value)"},
                                {"sid": "cap-1", "where": "ui:tooltip", "err": "unrelated"}],
                 "inference": {"sid": "cap-1", "anchor": {}, "player": "me"},
                 "replay": {"sessions": [{"hdr": {"sid": "cap-1"}, "tape": [{"k": "dm"}, {"k": "ws"}]}]}},
            combatlog={"sessions": [{"captureSid": "cap-1", "events": [{"e": "UNIT_COMBAT"}] * 11}]})
        eh = analysis.engine_health(d)
        self.assertEqual(len(eh["captureErrors"]), 1)
        self.assertEqual([s["sid"] for s in eh["down"]], ["cap-1"])
        self.assertEqual(eh["down"][0]["unitCombat"], 11)

    def test_healthy_capture_not_down(self):
        d = fake_dump(
            log={"inference": {"sid": "cap-2", "counters": {"casts": 3}},
                 "replay": {"sessions": [{"hdr": {"sid": "cap-2"}, "tape": [{"k": "decide"}]}]}},
            combatlog={"sessions": [{"captureSid": "cap-2", "events": [{"e": "UNIT_COMBAT"}]}]})
        eh = analysis.engine_health(d)
        self.assertEqual(eh["captureErrors"], [])
        self.assertEqual(eh["down"], [])

    def test_tape_header_health_v228(self):
        d = fake_dump(
            log={"selfErrors": [{"sid": "cap-3", "where": "hsm:Timing", "err": "boom"}],
                 "inference": {"sid": "cap-3", "counters": {"casts": 1}},
                 "replay": {"sessions": [{"hdr": {"sid": "cap-3", "stats": {"v": 1, "hsm": "degraded", "hsmFailed": ["Timing"]}},
                                          "tape": [{"k": "decide"}]}]}})
        eh = analysis.engine_health(d)
        self.assertEqual([e["where"] for e in eh["captureErrors"]], ["hsm:Timing"])
        self.assertEqual(eh["tapeHealth"], [{"sid": "cap-3", "hsm": "degraded", "failed": ["Timing"]}])
        self.assertEqual(eh["down"], [])


class WorldCapDecode(unittest.TestCase):
    def test_exact_pq(self):
        codes = [4, 4, 4, 1, 1, 4, 4, 5, 5, 5, 0, 0, 5, 3, 3, 6]
        p = sum(c << (4 * i) for i, c in enumerate(codes[:8]))
        q = sum(c << (4 * i) for i, c in enumerate(codes[8:]))
        dec, fmt = worldcap.decode({"p": p, "q": q})
        self.assertEqual(fmt, "exact")
        self.assertEqual([dec[f] for f in worldcap.FIELDS], [worldcap.CODES[c] for c in codes])

    def test_legacy_lossy_marks_lost(self):
        codes = [4, 4, 4, 1, 1, 4, 4, 5, 5, 5, 0, 0, 5, 3, 3, 6]
        exact = sum(c << (4 * i) for i, c in enumerate(codes))
        as_double = float(exact)              # what a Lua 5.1 number stored
        dec, fmt = worldcap.decode({"p": as_double})
        self.assertEqual(fmt, "legacy-lossy")
        k = worldcap.lost_nibbles(as_double)
        self.assertGreaterEqual(k, 2)
        for i, f in enumerate(worldcap.FIELDS):
            if i < k:
                self.assertEqual(dec[f], "L", f)       # never a wrong code for a lost nibble
            else:
                self.assertEqual(dec[f], worldcap.CODES[codes[i]], f)


def stub_live(events=(), signals=(), tl=None):
    lv = coverage.Live.__new__(coverage.Live)
    lv.events = list(events)
    lv.signals = list(signals)
    lv.record = []
    lv.inf = {}
    lv.cs = {}
    lv.anchor = {}
    lv.by = {}
    for e in lv.events:
        lv.by.setdefault(e["e"], []).append(e)
    lv.span = (min((e["te"] for e in lv.events), default=0), max((e["te"] for e in lv.events), default=0))
    lv.combat = []
    lv.tl_t, lv.tl_g = ([x[0] for x in tl], [x[1] for x in tl]) if tl else ([], [])
    return lv


class CoverageFallbacks(unittest.TestCase):
    def test_target_timeline_from_log(self):
        lv = stub_live()
        fx = {"events": [
            {"cleu": True, "sub": "SPELL_DAMAGE", "t": 100.0, "a": [0, 0, 0, ME, 0, 0, 0, MOB]},
            {"cleu": True, "sub": "SPELL_HEAL", "t": 101.0, "a": [0, 0, 0, ME, 0, 0, 0, ME]},          # not offensive
            {"cleu": True, "sub": "SPELL_DAMAGE", "t": 102.0, "a": [0, 0, 0, MOB, 0, 0, 0, MOB2]},     # not mine
            {"cleu": True, "sub": "SWING_DAMAGE", "t": 110.0, "a": [0, 0, 0, ME, 0, 0, 0, MOB2]}]}
        self.assertTrue(lv.fill_targets_from_log(fx, ME))
        self.assertEqual(lv.target_source, "log-inferred")
        self.assertIsNone(lv.target_at(99.0))
        self.assertEqual(lv.target_at(100.0), MOB)
        self.assertEqual(lv.target_at(105.0), MOB)
        self.assertEqual(lv.target_at(110.0), MOB2)

    def test_live_targets_win(self):
        lv = stub_live(tl=[(50.0, MOB)])
        self.assertFalse(lv.fill_targets_from_log({"events": []}, ME))
        self.assertEqual(lv.target_source, "live-signals")

    def test_casts_from_raw_events_when_hsm_down(self):
        t = 1000.0
        ev = [{"e": "UNIT_SPELLCAST_SUCCEEDED", "te": t, "a": ["player", "secret", 8046]},
              {"e": "UNIT_SPELLCAST_SUCCEEDED", "te": t + 5, "a": ["player", "secret", 8008]},
              {"e": "UNIT_SPELLCAST_SUCCEEDED", "te": t + 6, "a": ["target", "secret", None]}]
        lv = stub_live(events=ev, tl=[(t - 1, MOB)])
        rp = {8008: {"helpful": True}}
        stream, _ = coverage.build_stream(fake_dump(), lv, ME, reparse=rp)
        casts = [x for x in stream if x["k"] == "cast"]
        self.assertEqual(lv.cast_source, "raw-events")
        self.assertEqual([(c["spell"], c["target"]) for c in casts], [(8046, MOB), (8008, "player")])

    def test_signal_casts_win(self):
        t = 1000.0
        ev = [{"e": "UNIT_SPELLCAST_SUCCEEDED", "te": t, "a": ["player", "secret", 8046]}]
        sig = [{"e": "cast", "te": t, "unit": "player", "ev": "SUCCEEDED", "sid": 8046, "target": MOB}]
        lv = stub_live(events=ev, signals=sig, tl=[(t - 1, MOB)])
        stream, _ = coverage.build_stream(fake_dump(), lv, ME)
        self.assertEqual(len([x for x in stream if x["k"] == "cast"]), 1)
        self.assertEqual(lv.cast_source, "live-signals")


class MeterJoinByTime(unittest.TestCase):
    def test_earlier_capture_fight_not_used(self):
        old = {"epoch": 5000, "deep": True, "types": {"DamageDone": {"me": 1327}, "DamageTaken": {"me": 290}}}
        cur = {"epoch": 9262, "deep": True, "types": {"DamageDone": {"me": 439}, "DamageTaken": {"me": 494}}}
        snap = {"epoch": 9275, "types": {"DamageDone": {"me": 439}}}
        fight = {"n": 1, "start": 9213.8, "stop": 9261.9, "mineDamage": 439, "takenDamage": 494}
        self.assertIs(damagemeter_join._raw_fight_for([old, cur, snap], fight, 0), cur)
        # no meter fight in the window -> None, never a neighbour's numbers
        self.assertIsNone(damagemeter_join._raw_fight_for([old], fight, 0))
        # pre-epoch SVs keep the index fallback
        self.assertEqual(damagemeter_join._raw_fight_for([{"types": {}}], fight, 0), {"types": {}})


class DecideDeterminism(unittest.TestCase):
    def test_vacuous_is_not_ok(self):
        r = replay.decide_determinism([{"k": "dm", "ty": 0}, {"k": "ws"}], {})
        self.assertTrue(r["vacuous"])
        self.assertFalse(r["ok"])
        s = replay._summary([{"decide": r, "n": 2}])
        self.assertFalse(s["ok"])
        self.assertEqual(s["decideVacuous"], 1)

    def test_decide_records_ok(self):
        r = replay.decide_determinism([{"k": "dm"}, {"k": "decide", "r": 1, "b": 3, "kind": "damage", "c": "mine"}], {})
        self.assertFalse(r["vacuous"])
        self.assertTrue(r["ok"])

    def test_no_combat_not_vacuous(self):
        r = replay.decide_determinism([{"k": "ws"}, {"k": "hdr"}], {})
        self.assertFalse(r["vacuous"])
        self.assertTrue(r["ok"])


class SliceBudget(unittest.TestCase):
    def rec(self, ms_per_call, n=300):
        return {"sid": "cap-x", "duration": 60, "handlers": {"WorldCapture.Slice": {"n": n, "ms": ms_per_call * n, "max": 0.5}}}

    def test_over_budget_flagged(self):
        out = perf.session(self.rec(0.127))
        self.assertTrue(any("WorldCapture.Slice" in f and "budget" in f for f in out["flags"]), out["flags"])

    def test_under_budget_clean(self):
        out = perf.session(self.rec(0.07))
        self.assertFalse(any("budget" in f for f in out["flags"]), out["flags"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
