local WROOT = os.getenv("WOWDEV_ROOT") or (function() -- portable root (handoff)
  local s = debug.getinfo(1, "S").source:sub(2)
  if s:sub(1, 1) ~= "/" then local p = io.popen("pwd"); s = p:read("*l") .. "/" .. s; p:close() end
  return s:match("^(.*)/kth/") or s:match("^(.*)/foreverdump/") or ".."
end)()
-- Load an addon tree (TOC order, XML expanded) into ForeverDump's Forever mock and report errors + Blizzard chat writes.
-- usage: FORE_DOCS=... lua5.1 load_smoke.lua <KTH.toc> [<diag.toc>]
package.path = WROOT .. "/foreverdump/tests/?.lua;" .. WROOT .. "/kth/tests/?.lua;" .. package.path
local W = dofile(WROOT .. "/foreverdump/tests/wowenv.lua"); _G.__W = W
local TF = require("tocfiles")
dofile(WROOT .. "/kth/tests/mockextra.lua")
local errors = {}
seterrorhandler(function(m) errors[#errors + 1] = tostring(m) .. (os.getenv("TB") and debug.traceback("", 2) or "") end)
local function load(toc, name)
    local ns = {}
    for _, f in ipairs(TF.files(toc)) do
        local chunk, err = loadfile(f)
        if not chunk then errors[#errors + 1] = "COMPILE " .. err
        else
            local ok, e = pcall(chunk, name, ns)
            if not ok then errors[#errors + 1] = "LOAD " .. f .. ": " .. tostring(e) end
        end
    end
    return ns
end
local loaded = {}
for i = 1, #arg do
    local toc = arg[i]
    local name = toc:match("([^/]+)%.toc$")
    loaded[name] = load(toc, name)
end
_G.__LOADED = loaded
local function fire(...) local ok, e = pcall(W.fire, ...) if not ok then errors[#errors + 1] = "FIRE " .. tostring(e) end end
for name in pairs(loaded) do fire("ADDON_LOADED", name) end
IsLoggedIn = function() return true end
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 50 do local ok, e = pcall(W.tick, 1) if not ok then errors[#errors + 1] = "TICK " .. tostring(e) end end
if SlashCmdList.KTHFORVERDIAG then pcall(SlashCmdList.KTHFORVERDIAG, "") end
-- regression (forever.3): open every K.T.H. options UI the user can open (/kthg, /hhtd) and toggle its widgets
local uiOpened = 0
for _, cmd in ipairs({ "KTHG", "ACECONSOLE_HHTD", "ACECONSOLE_HHTDG" }) do
    local f = SlashCmdList[cmd]
    if f then uiOpened = uiOpened + 1; local ok, e = pcall(f, "") if not ok then errors[#errors + 1] = "SLASH " .. cmd .. ": " .. tostring(e) end end
end
print("options UIs opened:", uiOpened)
local A = LibStub("AceAddon-3.0"):GetAddon("K.T.H.", true)
print("KTH addon object:", A ~= nil, "MN:", A and A.Constants.MN, "enabled:", A and A:IsEnabled())
print("errors:", #errors)
for _, e in ipairs(errors) do print("  " .. e:sub(1, 300)) end
print("blizzChat lines:", #W.blizzChat)
for _, l in ipairs(W.blizzChat) do print("  BLIZZ> " .. tostring(l):sub(1, 200)) end
print("diag frame lines:", #(_G.__diagLines or {}))
for _, l in ipairs(_G.__diagLines or {}) do print("  DIAG> " .. tostring(l):sub(1, 200)) end
if os.getenv("CHK") then dofile("/tmp/chk.lua") end
local rr = W.state.restrictedRegistrations
local n = 0 for e, c in pairs(rr) do n = n + 1 print("  RESTRICTED REGISTER> " .. e .. " x" .. c) end
print("restricted registrations:", n)
local ur = {}
for k, n in pairs(W.undefinedReads or {}) do ur[#ur + 1] = k .. "x" .. n end
table.sort(ur)
print("undefined global reads:", #ur, table.concat(ur, " "))
