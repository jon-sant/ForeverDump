# VERIFY: live verification loop joined with the combat log

Verdict source: **replay** (pre-2.2.4 capture: offline replay of the recorded live events through HybridState MINOR 4). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|
| aura-expiry | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 100.0 | 0.0 |
| cast-end | 3 | 2 | 0 | 1 | 2 | 0 | 0 | 100.0 | 66.7 |
| cooldown | 11 | 11 | 0 | 0 | 10 | 0 | 0 | 100.0 | 100.0 |
| damage-range | 5 | 4 | 0 | 1 | 5 | 0 | 0 | 100.0 | 80.0 |
| dm-total | 3 | 3 | 0 | 0 | 0 | 0 | 0 | None | 100.0 |
| interrupt-attribution | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 100.0 | 100.0 |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

7 spell fact set(s), 1 NPC cast model(s), rules {"swingLag": [0.0, 1.079]}.

- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2, "minRecast": 6.021}
- spell 8052: {"auraId": 8052, "minRecast": 16.853}
- spell 8177: {"minRecast": 72.936}
- spell 17364: {"minRecast": 11.291}
- npc 4119: cast median 3.500 s (3.437-3.542, n=3)
