-- Offline: run the CURRENT addon parser (ForeverDump/Knowledge.lua K.Parse / K.Lint / K.ParseHeader) over stored texts.
-- usage: lua5.1 kparse.lua <Knowledge.lua> <input.lua>   (input returns { [id] = { text = "...", tooltip = { {l=,r=}, ... } } })
local kpath, inpath = arg[1], arg[2]
local ns = { IsSecret = function() return false end, On = function() end, config = { knowledge = {} } }
assert(loadfile(kpath))("ForeverDump", ns)
local K = ns.Knowledge
local data = dofile(inpath)
local function enc(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then return string.format("%.17g", v) end
    if t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"' end
    if t == "table" and depth < 8 then
        local n = #v
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = enc(v[i], depth + 1) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = enc(tostring(k)) .. ":" .. enc(x, depth + 1) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end
local out = {}
for id, x in pairs(data) do
    local p = x.text and K.Parse(x.text) or nil
    out[tostring(id)] = { parsed = p or {}, lint = x.text and K.Lint(x.text, p) or {}, header = x.tooltip and K.ParseHeader(x.tooltip) or nil }
end
io.write(enc(out))
