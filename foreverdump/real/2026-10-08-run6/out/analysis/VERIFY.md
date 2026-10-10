# VERIFY: live verification loop joined with the combat log

Verdict source: **replay** (pre-2.2.4 capture: offline replay of the recorded live events through HybridState MINOR 4). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|
| cast-end | 1 | 0 | 0 | 1 | 0 | 0 | 0 | None | 0.0 |
| cooldown | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 100.0 | 100.0 |
| damage-range | 3 | 3 | 0 | 0 | 3 | 0 | 0 | 100.0 | 100.0 |
| dm-damage | 1 | 1 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-dispels | 1 | 0 | 0 | 1 | 0 | 0 | 0 | None | 0.0 |
| dm-healing | 1 | 1 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-interrupts | 1 | 1 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| dm-taken | 1 | 0 | 0 | 1 | 0 | 0 | 0 | None | 0.0 |
| interrupt-attribution | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 100.0 | 100.0 |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

5 spell fact set(s), 1 NPC cast model(s), rules {"swingLag": [0.0, 0.631]}.

- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2}
- spell 8052: {"auraId": 8052, "minRecast": 18.804}
- npc 4096: cast median 3.062 s (3.062-3.062, n=1)
