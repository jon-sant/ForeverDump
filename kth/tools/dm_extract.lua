-- forever.5: extract C_DamageMeter snapshots (FD "damageMeter" node) from a ForeverDump SV as JSON lines, raw values.
-- usage: lua5.1 dm_extract.lua <ForeverDump.lua> > out.jsonl   (values are written exactly as stored; "<secret>" stays)
dofile(arg[1])
local DB = ForeverDumpCombatLogDB
local function J(v)
  local tv = type(v)
  if tv == "table" then
    local isArr = #v > 0 or next(v) == nil
    local p = {}
    if isArr then for _, x in ipairs(v) do p[#p+1] = J(x) end return "[" .. table.concat(p, ",") .. "]" end
    for k, x in pairs(v) do p[#p+1] = string.format("%q", tostring(k)) .. ":" .. J(x) end
    return "{" .. table.concat(p, ",") .. "}"
  elseif tv == "string" then return (string.format("%q", v):gsub("\\\n", "\\n"))
  elseif tv == "number" then if v ~= v or v == math.huge or v == -math.huge then return "null" end return string.format("%.17g", v)
  elseif tv == "boolean" then return tostring(v) end
  return "null"
end
local n = 0
local function scan(t, depth)
  if type(t) ~= "table" or depth > 6 then return end
  if t.byType then n = n + 1; io.write(J(t), "\n"); return end
  for _, v in pairs(t) do scan(v, depth + 1) end
end
for i, c in ipairs(DB.chunks) do
  local f = loadstring(c)
  if f then local r = { pcall(f) } if r[1] then for k = 2, #r do scan(r[k], 0) end end end
end
io.stderr:write("snapshots ", n, "\n")
