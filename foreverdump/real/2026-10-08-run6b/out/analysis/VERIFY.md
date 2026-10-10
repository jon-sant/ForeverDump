# VERIFY: live verification loop joined with the combat log

Verdict source: **ring** (SV ring ForeverDumpDB.verify). V verified / C contradicted / U unverified / X unexpected. truth: confirmed = the log agrees with the live verdict; refuted = the log disagrees; missed = the log shows something the engine had no window for.

| check | n | V | C | U | confirmed | refuted | missed | accuracy % | coverage % |
|---|---|---|---|---|---|---|---|---|---|
| unexpected:drift | 2 | 0 | 0 | 0 | 0 | 0 | 0 | None | 0.0 |

## Unexpected findings (live)

| kind | key | detail | n | ctx |
|---|---|---|---|---|
| drift | token-matrix:ooc|world|solo/nameplateN/threat | matrix-change | 1 | o |
| drift | token-matrix:ooc|world|solo/mouseover/threat | matrix-change | 1 | o |

## Knowledge patch for the next build (ForeverDump/Data/KnowledgePatch.lua)

5 spell fact set(s), 0 NPC cast model(s), rules {"swingLag": [0.0, 0.558]}.

- spell 8042: {"interrupt": true, "lockout": 2}
- spell 8044: {"interrupt": true, "lockout": 2}
- spell 8045: {"interrupt": true, "lockout": 2}
- spell 8046: {"interrupt": true, "lockout": 2, "minRecast": 6.689}
- spell 8052: {"auraId": 8052, "minRecast": 18.804}
