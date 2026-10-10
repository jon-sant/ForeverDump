-- forever.3 regression fixture (SYNTHETIC unit-test input, not a capture): two enemies share the first name "Johnny"
-- (runs 16 had such a pair, "Johnny Snowden"/"Johnny Morningwind"). Plates return name "Johnny" + realm = surname
-- (measured D5b). Expected: the PRIEST is marked (exact join), the WARRIOR is not; first-name-only join marks neither.
return {
 meta = { run = "regress-dupfirst", synthetic = true },
 roster = {
  { first = "Johnny", full = "Johnny Snowden", side = "E", class = "PRIEST" },
  { first = "Johnny", full = "Johnny Morningwind", side = "E", class = "WARRIOR" },
  { first = "Ally", full = "Ally Friend", side = "F", class = "MAGE" },
 },
 ev = {
  {100.0, "S", nil, nil, nil},
  {101.0, "A", "nameplate1", 1, nil}, {101.0, "P", "nameplate1", 1, "MANA"},
  {101.0, "A", "nameplate2", 2, nil}, {101.0, "P", "nameplate2", 2, "RAGE"},
  {103.0, "S", nil, nil, nil}, {105.0, "P", "nameplate1", 1, "MANA"}, {107.0, "P", "nameplate2", 2, "RAGE"},
  {110.0, "S", nil, nil, nil},
 },
}
