-- expand a TOC (and the XML it includes) into an ordered list of Lua files, like the client loader
local M = {}
local function norm(p) return (p:gsub("\\", "/")) end
local function dirname(p) return p:match("^(.*)/[^/]*$") or "." end
local function xml(path, out)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close()
    s = s:gsub("<!%-%-.-%-%->", "")
    local base = dirname(path)
    for tag, file in s:gmatch("<(%a+)%s+file%s*=%s*\"([^\"]+)\"") do
        local p = base .. "/" .. norm(file)
        if tag == "Script" then out[#out + 1] = p
        elseif tag == "Include" then local g = io.open(p); if g then g:close(); xml(p, out) end end
    end
end
function M.files(toc)
    local out, base = {}, dirname(toc)
    for line in io.lines(toc) do
        line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            local p = base .. "/" .. norm(line)
            if p:match("%.xml$") then xml(p, out) else out[#out + 1] = p end
        end
    end
    return out
end
return M
