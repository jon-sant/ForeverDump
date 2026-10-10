# What you can do with a secret (operations matrix)

Captured from addon code (not chat /run, which is force-tainted: `ForceTaint_Strong`). Only booleans and error
texts are stored; never the value. `ok/S` = succeeded and the result is secret.

| context | value | state | arith | compare | concat | equal | format | print | setText | statusBar | tableKey | tostring | truthy |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ooc/addon | UnitHealth(player) | S | **err** | **err** | ok/S | **err** | ok/S | ok | ok | ok | **err** | ok/S (tonumber->nil) | ok |
| ooc/addon | UnitHealthMax(player) | C | ok | ok | ok | ok | ok | ok | **err** | ok | ok | ok | ok |
| ooc/addon | UnitPower(player) | S | **err** | **err** | ok/S | **err** | ok/S | ok | **err** | ok | **err** | ok/S (tonumber->nil) | ok |
| ooc/addon | secretwrap(1) | S | **err** | **err** | ok/S | **err** | ok/S | ok | **err** | ok | **err** | ok/S (tonumber->nil) | ok |
| combat/addon | UnitHealth(player) | S | **err** | **err** | ok/S | **err** | ok/S | ok | **err** | ok | **err** | ok/S (tonumber->nil) | ok |
| combat/addon | UnitHealthMax(player) | C | ok | ok | ok | ok | ok | ok | **err** | ok | ok | ok | ok |
| combat/addon | UnitPower(player) | S | **err** | **err** | ok/S | **err** | ok/S | ok | **err** | ok | **err** | ok/S (tonumber->nil) | ok |
| combat/addon | secretwrap(1) | S | **err** | **err** | ok/S | **err** | ok/S | ok | **err** | ok | **err** | ok/S (tonumber->nil) | ok |

## Error texts

- `Interface/AddOns/ForeverDump/Controls.lua:155: attempt to compare local 'v' (a secret number value, while execution tainted by 'ForeverDump')` (compare)
- `Interface/AddOns/ForeverDump/Controls.lua:156: attempt to compare local 'v' (a secret number value, while execution tainted by 'ForeverDump')` (equal)
- `Interface/AddOns/ForeverDump/Controls.lua:154: attempt to perform arithmetic on local 'v' (a secret number value, while execution tainted by 'ForeverDump')` (arith)
- `Interface/AddOns/ForeverDump/Controls.lua:160: attempted to perform indexed assignment on a table that cannot be indexed with secret keys` (tableKey)
- `FontString:SetText(): Font not set
Lua Taint: ForeverDump` (setText)
