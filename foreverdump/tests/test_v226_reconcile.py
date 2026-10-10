"""v2.2.6: HSM self-reconcile (liveEst ↔ post-combat meter) + per-unit IdKey join."""
from __future__ import annotations
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HS = ROOT / "ForeverDump" / "Lib" / "HybridState.lua"


def run_lua(src: str) -> str:
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
        f.write(src)
        path = f.name
    try:
        r = subprocess.run(["lua5.1", path], capture_output=True, text=True, cwd=str(ROOT))
        if r.returncode != 0:
            raise AssertionError(r.stderr or r.stdout or "lua failed")
        return r.stdout
    finally:
        os.unlink(path)


class TestReconcile(unittest.TestCase):
    def test_live_est_fields(self):
        src = textwrap.dedent(f"""
        dofile("{HS.as_posix()}")
        local t = 0
        local hs = HybridState.New({{ now = function() t = t + 0.01; return t end }})
        hs:OnCombatState(true)
        local f = hs:Fight()
        assert(f.liveEst and f.world and f.dispels, "fight missing liveEst/world/dispels")
        hs:OnDamageMeter(0)
        hs:OnDamageMeter(7)
        assert(f.liveEst.dmTicks[0] == 1 and f.liveEst.dmTicks[7] == 1)
        print("OK liveEst")
        """)
        self.assertIn("OK liveEst", run_lua(src))

    def test_reconcile_match_and_off(self):
        src = textwrap.dedent(f"""
        dofile("{HS.as_posix()}")
        local t = 0
        local hs = HybridState.New({{ now = function() t = t + 0.01; return t end }})
        hs:OnCombatState(true)
        hs:Learn(123, {{ amount = {{ min = 10, max = 12, kind = "damage" }}, interrupt = true, dispel = true }})
        hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 123, true, "Creature-0-0-0-0-100-000")
        hs:OnUnitCombat("Creature-0-0-0-0-100-000", "WOUND", nil, 11, 1, false)
        hs:OnCombatState(false)
        local out = hs:ReconcileDM({{
            damage = 11, healing = 0, interrupts = 0, dispels = 0, taken = 0,
            sources = {{
                DamageDone = {{ {{ id = "player", isLocalPlayer = true, total = 11 }} }},
                DamageTaken = {{ {{ id = "player", isLocalPlayer = true, total = 0 }} }},
            }},
        }})
        assert(out and out.summary, "no summary")
        assert(out.metrics.damage.status == "match", out.metrics.damage.status)
        assert(out.summary.match >= 1, "expected match")
        hs:OnCombatState(true)
        hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 123, true, "target")
        hs:OnUnitCombat("target", "WOUND", nil, 50, 1, false)
        hs:OnCombatState(false)
        local out2 = hs:ReconcileDM({{ damage = 10, healing = 0, interrupts = 0, dispels = 0, taken = 0 }})
        assert(out2.metrics.damage.status == "off", out2.metrics.damage.status)
        assert(out2.metrics.damage.delta and out2.metrics.damage.delta > 0)
        print("OK reconcile match/off")
        """)
        self.assertIn("OK reconcile", run_lua(src))

    def test_healing_effective_vs_gross(self):
        # v2.2.7 (run 6b 18:41:02): the meter counts effective healing; UNIT_COMBAT HEAL is gross.
        # Lesser Healing Wave 227 (56 over) + 229 (0 over): gross 456, effective 400 = meter -> match.
        # Without an hp estimate the gross is compared exactly as before (456 vs 400 -> off, contradiction).
        src = textwrap.dedent(f"""
        dofile("{HS.as_posix()}")
        local function run(withHp)
            local t = 0
            local hs = HybridState.New({{ now = function() return t end }})
            if withHp then
                hs:OnHealthMax("player", 1455)
                t = 1 hs:OnHealthEvent("player")
                t = 20 hs:OnHealthEvent("player")  -- quiet out of combat -> anchored full
            end
            t = 30 hs:OnCombatState(true)
            hs:OnHealthEvent("player") hs:OnUnitCombat("player", "WOUND", "", 171, 1, true)
            t = 31 hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8008, true, "player")
            hs:OnHealthEvent("player") hs:OnUnitCombat("player", "HEAL", "", 227, 8, true)
            t = 40 hs:OnHealthEvent("player") hs:OnUnitCombat("player", "WOUND", "", 229, 1, true)
            t = 41 hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 8008, true, "player")
            hs:OnHealthEvent("player") hs:OnUnitCombat("player", "HEAL", "", 229, 8, true)
            t = 50 hs:OnCombatState(false)
            local f = hs:Fight()
            assert(f.heal.mine == 456, "gross heal " .. tostring(f.heal.mine))
            return hs:ReconcileDM({{ damage = 0, healing = 400, interrupts = 0, dispels = 0, taken = 400 }}), hs
        end
        local out = run(true)
        local h = out.metrics.healing
        assert(h.live == 400 and h.status == "match" and h.delta == 0, "effective " .. tostring(h.live) .. " " .. h.status)
        assert(out.liveHealGross == 456 and out.liveHealOver == 56, "gross/over carried")
        local out2, hs2 = run(false)
        local h2 = out2.metrics.healing
        assert(h2.live == 456 and h2.status == "off" and h2.delta == 56, "no estimate: gross " .. tostring(h2.live) .. " " .. h2.status)
        local found = false
        for _, c in ipairs(hs2.contradictions) do if c.kind == "self-attribution-exceeds-dm-healing" then found = true end end
        assert(found, "gross over meter without an estimate still contradicts")
        print("OK healing effective")
        """)
        self.assertIn("OK healing effective", run_lua(src))

    def test_per_unit_sources(self):
        src = textwrap.dedent(f"""
        dofile("{HS.as_posix()}")
        local t = 0
        local hs = HybridState.New({{
            now = function() t = t + 0.01; return t end,
            idKey = function(kind, raw)
                if kind == "npc" then
                    local nid = tostring(raw):match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or "100"
                    return "npc:" .. nid
                end
                return kind .. ":x"
            end,
        }})
        hs:OnCombatState(true)
        hs:Learn(123, {{ amount = {{ min = 10, max = 12, kind = "damage" }} }})
        local guid = "Creature-0-0-0-0-100-0000000001"
        hs:OnCast("UNIT_SPELLCAST_SUCCEEDED", "player", 123, true, guid)
        hs:OnUnitCombat(guid, "WOUND", nil, 11, 1, false)
        hs:OnCombatState(false)
        local out = hs:ReconcileDM({{
            damage = 11, healing = 0, interrupts = 0, dispels = 0, taken = 0,
            sources = {{
                DamageDone = {{
                    {{ id = "player", isLocalPlayer = true, total = 11 }},
                    {{ id = "npc:100", kind = "Creature", total = 0 }},
                }},
                EnemyDamageTaken = {{
                    {{ id = "npc:100", kind = "Creature", total = 11 }},
                }},
            }},
        }})
        assert(out.units and out.units["player"], "missing player unit")
        assert(out.units["player"].verdict == "match" or out.units["player"].status.damage.status == "match")
        print("OK per-unit")
        """)
        self.assertIn("OK per-unit", run_lua(src))


if __name__ == "__main__":
    unittest.main()
