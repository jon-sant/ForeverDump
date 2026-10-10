-- forever.7 R13 fixture (SYNTHETIC unit-test input, not a capture): friendly group roles. raid1 = HEALER (claimed at
-- once, bound to "Mend Well"), raid2 = DAMAGER (a queue role, not a spec: never counted against anyone).
return {
 meta = { run = "regress-spec-role", synthetic = true, groupRoles = { {1, "HEALER"}, {2, "DAMAGER"} } },
 roster = {
  { first = "Mend", full = "Mend Well", side = "F", class = "PRIEST" },
  { first = "Stab", full = "Stab Back", side = "F", class = "ROGUE" },
  { first = "Foe", full = "Foe Man", side = "E", class = "MAGE" },
 },
 ev = {
  {100.0, "S", nil, nil, nil},
  {101.0, "A", "nameplate1", 3, nil}, {101.0, "P", "nameplate1", 3, "MANA"},
  {105.0, "S", nil, nil, nil}, {106.0, "P", "nameplate1", 3, "MANA"},
 },
}
