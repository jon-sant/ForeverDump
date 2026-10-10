-- v2.2.24 (run 18): scoreboard faction is authoritative for team membership; a mind-controlled team-mate (transiently
-- hostile) must not stay marked enemy. usage: lua5.1 tests/v2224_friend.lua ForeverDump
local dir = arg[1] or "ForeverDump"
local CE = dofile(dir .. "/Lib/ClassEvidence.lua")
local fails, n = 0, 0
local function check(c, m) n = n + 1 if not c then fails = fails + 1 print("FAIL " .. m) end end
local e = CE.new()
-- MC first (plate hostility), then the scoreboard row says friend -> cleared
e:MarkEnemy("name:Clam")
e:Assign("name:Clam", "DRUID", "score")
check(e.units["name:Clam"].enemy == true, "transient enemy mark set")
e:MarkFriend("name:Clam", "score")
check(not e.units["name:Clam"].enemy, "scoreboard friend clears the enemy mark")
-- later hostility (MC again) is vetoed
e:MarkEnemy("name:Clam")
check(not e.units["name:Clam"].enemy, "MarkEnemy vetoed for a scoreboard friend")
local s = e:Summary()
check(s.enemyCleared == 1 and s.enemyVetoed == 1 and s.enemies == 0, "summary counters enemyCleared/enemyVetoed")
check(e:Get("name:Clam") == "DRUID", "class kept")
-- real enemies untouched
e:MarkEnemy("name:Ank")
check(e.units["name:Ank"].enemy == true, "enemy without friend mark stays enemy")
-- Derive: only UNIQUE friendly rows mark friend (crossFac first names share one key with an enemy)
local f = io.open(dir .. "/Derive.lua") local src = f:read("*a") f:close()
check(src:find('row.enemy == false and (how == "unique" or how == "exact-unique" or how == "exact") then e:MarkFriend', 1, true) ~= nil, "Derive marks friend only for unique rows")
print(string.format("v2224_friend: %d checks, %d failed", n, fails))
if fails > 0 then os.exit(1) end
