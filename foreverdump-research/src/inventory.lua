local dir = arg[1]
local out = {}
APIDocumentation = { AddDocumentationTable = function(self, t) out[#out+1] = t end }
for f in io.popen('ls "'..dir..'"/*.lua'):lines() do
  local chunk = loadfile(f); if chunk then pcall(chunk) end
end
local function tags(node)
  local r = {}
  for k, v in pairs(node) do
    if type(k)=="string" and (k:find("^Secret") or k:find("^Requires") or k=="ConditionalSecret" or k=="NeverSecret" or k=="HasRestrictions" or k=="SecureHooksAllowed" or k=="MayReturnNothing" or k=="CallbackEvent" or k=="RestrictedForMacroChatMessages") then
      r[#r+1] = k.."="..tostring(v)
    end
  end
  table.sort(r); return table.concat(r, ";")
end
local function fields(list)
  local r = {}
  for _, a in ipairs(list or {}) do
    local t = tags(a)
    r[#r+1] = a.Name..":"..tostring(a.Type)..(a.Nilable and "?" or "")..(t~="" and "["..t.."]" or "")
  end
  return table.concat(r, " | ")
end
print("kind\tname\ttags\treturns_or_payload\tstruct_fields")
local structs = {}
for _, t in ipairs(out) do for _, s in ipairs(t.Tables or {}) do if s.Type=="Structure" then structs[s.Name]=s end end end
for _, t in ipairs(out) do
  local ns = t.Namespace and t.Namespace ~= "" and (t.Namespace..".") or ""
  for _, fn in ipairs(t.Functions or {}) do
    local n = (fn.Namespace == "" and "" or ns)..fn.Name
    local sf = {}
    for _, r in ipairs(fn.Returns or {}) do if structs[r.Type] then sf[#sf+1] = r.Type.."{"..fields(structs[r.Type].Fields).."}" end end
    print("function\t"..n.."\t"..tags(fn).."\t"..fields(fn.Returns).."\t"..table.concat(sf," "))
  end
  for _, ev in ipairs(t.Events or {}) do
    print("event\t"..(ev.LiteralName or ev.Name).."\t"..tags(ev).."\t"..fields(ev.Payload).."\t")
  end
  for _, p in ipairs(t.Predicates or {}) do
    print("predicate\t"..p.Name.."\tType="..tostring(p.Type)..";FailureMode="..tostring(p.FailureMode).."\t"..((p.Documentation or {})[1] or "").."\t")
  end
end
