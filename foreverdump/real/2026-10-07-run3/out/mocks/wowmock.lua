-- wowmock.lua: busted-friendly WoW client mock driven by a ForeverDump dump.
-- Generated data comes from forever_data.lua (same folder). Lua 5.1 compatible.
--
--   local wow = dofile("mocks/wowmock.lua")
--   wow.install()                       -- populate _G with C_* stubs, Enum, CreateFrame, ...
--   wow.loadAddon("path/to/MyAddon", "MyAddon")  -- runs the .toc file list with (addonName, ns)
--   wow.fire("PLAYER_LOGIN")
--   wow.setReturn("C_Spell.GetSpellCooldown", function(id) return {...} end)
local M = {}
local here = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")
M.dir = here
M.data = dofile(here .. "forever_data.lua")
M.now = 1000
M.inCombat = false
M.frames = {}
M.timers = {}
M.calls = {}            -- [fullName] = count
M.returns = {}          -- [fullName] = function(...) or table of values
M.secretTouches = 0
M.strictSecrets = true  -- error when addon code does arithmetic/compare/concat/index on a secret
-- Secret simulation from the secrets map (forever_data.lua .secrets, documented + observed):
--   "documented" (default): always-secret returns/payload fields are secret; conditional/observed ones are secret
--                           while M.inCombat (wow.setCombat(true)).
--   "all": every documented/observed secret position is secret, in or out of combat.  "off": never.
M.secretMode = "documented"
M.secretOverride = {}   -- [fullName or EVENT] = false (never secret) | true (always secret)

-- ---------------------------------------------------------------- secrets
local secretMT = {}
local function secretError(op)
    return function()
        M.secretTouches = M.secretTouches + 1
        if M.strictSecrets then error("attempt to " .. op .. " a secret value", 2) end
        return nil
    end
end
for op, name in pairs({ __add = "perform arithmetic on", __sub = "perform arithmetic on", __mul = "perform arithmetic on",
    __div = "perform arithmetic on", __mod = "perform arithmetic on", __pow = "perform arithmetic on",
    __unm = "perform arithmetic on", __concat = "concatenate", __lt = "compare", __le = "compare",
    __len = "get length of", __index = "index", __newindex = "index", __call = "call" }) do
    secretMT[op] = secretError(name)
end
secretMT.__tostring = function() return "<secret>" end
M.SECRET = setmetatable({}, secretMT)
local function issecret(v) return v == M.SECRET or getmetatable(v) == secretMT end
M.issecret = issecret

-- Convert dump markers into live values: "<secret>" -> SECRET, "<nil>" -> nil.
function M.decode(v)
    if v == "<secret>" or v == "<secrettable>" then return M.SECRET end
    if v == "<nil>" then return nil end
    if type(v) == "table" then
        local out = {}
        for k, x in pairs(v) do out[k] = M.decode(x) end
        return out
    end
    return v
end

-- ---------------------------------------------------------------- secret simulation
local SD = M.data.secrets or { returns = {}, events = {}, structs = {}, returnStructs = {} }
M.secretData = SD
local function isSecretNow(key, cls)
    local o = M.secretOverride[key]
    if o ~= nil then return o end
    if M.secretMode == "off" or not cls then return false end
    if M.secretMode == "all" or cls == "always" then return true end
    return M.inCombat -- conditional / observed
end
M.isSecretNow = isSecretNow

local function secretStruct(key, t, structName)
    local flds = SD.structs and SD.structs[structName]
    if type(t) ~= "table" or not flds or M.issecret(t) then return t end
    local copy
    for k, cls in pairs(flds) do
        if t[k] ~= nil and isSecretNow(key, cls) then
            if not copy then copy = {} for kk, vv in pairs(t) do copy[kk] = vv end end
            copy[k] = M.SECRET
        end
    end
    return copy or t
end

-- apply the map to a function's return list (vals[1..n])
local function applySecretReturns(full, vals, n)
    local pos, rs = SD.returns and SD.returns[full], SD.returnStructs and SD.returnStructs[full]
    if not pos and not rs and M.secretOverride[full] == nil then return n end
    if M.secretOverride[full] == true then
        for i = 1, math.max(n, 1) do vals[i] = M.SECRET end
        return math.max(n, 1)
    end
    for i, cls in pairs(pos or {}) do
        -- struct returns keep the table and get per-field secrets below (the client returns a table with secret fields)
        if not (rs and rs[i] and type(vals[i]) == "table") and isSecretNow(full, cls) then
            vals[i] = M.SECRET
            if i > n then n = i end
        end
    end
    for i, structName in pairs(rs or {}) do vals[i] = secretStruct(full, vals[i], structName) end
    return n
end
M.applySecretReturns = applySecretReturns

local function applySecretPayload(event, args, n)
    local pos = SD.events and SD.events[event]
    if M.secretOverride[event] == false or (not pos and M.secretOverride[event] == nil) then return n end
    for i, cls in pairs(pos or {}) do
        if i <= n and args[i] ~= nil and isSecretNow(event, cls) then args[i] = M.SECRET end
    end
    if M.secretOverride[event] == true then for i = 1, n do args[i] = M.SECRET end end
    return n
end
M.applySecretPayload = applySecretPayload

-- ---------------------------------------------------------------- function stubs
local function stub(full)
    return function(...)
        M.calls[full] = (M.calls[full] or 0) + 1
        local r = M.returns[full]
        local vals, n = {}, 0
        if type(r) == "function" then
            local function pk(...) return { ... }, select("#", ...) end
            vals, n = pk(r(...))
        elseif type(r) == "table" then
            n = r.n or #r
            for i = 1, n do vals[i] = r[i] end
        else
            local d = M.data.returns[full]
            if d then
                n = d.n or #d.values
                for i = 1, n do vals[i] = M.decode(d.values[i]) end
            end
        end
        n = applySecretReturns(full, vals, n)
        return unpack(vals, 1, n)
    end
end

function M.setReturn(full, value) M.returns[full] = value end

-- ---------------------------------------------------------------- widgets
local Widget = {}
local function newObject(objectType, name, parent)
    local methods = M.data.widgets[objectType] or M.data.widgets.Frame or {}
    local obj = { __type = objectType, __name = name, __parent = parent, __scripts = {}, __events = {},
        __shown = true, __points = {}, __children = {}, __width = 0, __height = 0, __text = nil }
    local mt = { __index = function(t, k)
        local impl = Widget[k]
        if impl and methods[k] then return impl end
        if methods[k] then
            return function() M.calls[objectType .. ":" .. k] = (M.calls[objectType .. ":" .. k] or 0) + 1 end
        end
        return nil
    end }
    setmetatable(obj, mt)
    if name then _G[name] = obj end
    if parent and type(parent) == "table" and parent.__children then table.insert(parent.__children, obj) end
    M.frames[#M.frames + 1] = obj
    return obj
end
M.newObject = newObject

function Widget:GetName() return self.__name end
function Widget:GetObjectType() return self.__type end
function Widget:IsObjectType(t)
    if t == self.__type then return true end
    local isa = M.data.isA[self.__type]
    return isa and isa[t] or false
end
function Widget:GetParent() return self.__parent end
function Widget:SetParent(p) self.__parent = p end
function Widget:SetScript(k, f) self.__scripts[k] = f end
function Widget:GetScript(k) return self.__scripts[k] end
function Widget:HookScript(k, f)
    local old = self.__scripts[k]
    self.__scripts[k] = old and function(...) old(...) f(...) end or f
end
function Widget:HasScript(k) return true end
M.forbidden = {}            -- [event] = count of restricted registrations (COMBAT_LOG_EVENT* on Forever)
M.strictRestrictions = false -- true: error like ADDON_ACTION_FORBIDDEN instead of only counting
M.RESTRICTED_EVENTS = { COMBAT_LOG_EVENT = true, COMBAT_LOG_EVENT_UNFILTERED = true }
function Widget:RegisterEvent(e)
    if M.RESTRICTED_EVENTS[e] then
        M.forbidden[e] = (M.forbidden[e] or 0) + 1
        if M.strictRestrictions then error("ADDON_ACTION_FORBIDDEN: " .. tostring(e) .. " is restricted on Forever", 2) end
    end
    if M.data.eventSet and next(M.data.eventSet) and not M.data.eventSet[e] then
        error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2)
    end
    self.__events[e] = true
end
function Widget:RegisterUnitEvent(e) self.__events[e] = true end
function Widget:UnregisterEvent(e) self.__events[e] = nil end
function Widget:RegisterAllEvents()
    for e in pairs(M.RESTRICTED_EVENTS) do M.forbidden[e] = (M.forbidden[e] or 0) + 1 end -- includes restricted events
    if M.strictRestrictions then error("ADDON_ACTION_FORBIDDEN: RegisterAllEvents includes restricted events", 2) end
    self.__allEvents = true
end
function Widget:UnregisterAllEvents() self.__events = {} self.__allEvents = nil end
function Widget:IsEventRegistered(e) return self.__allEvents or self.__events[e] or false end
function Widget:Show() self.__shown = true if self.__scripts.OnShow then self.__scripts.OnShow(self) end end
function Widget:Hide() self.__shown = false if self.__scripts.OnHide then self.__scripts.OnHide(self) end end
function Widget:IsShown() return self.__shown end
function Widget:IsVisible() return self.__shown end
function Widget:SetShown(s) if s then self:Show() else self:Hide() end end
function Widget:SetPoint(...) self.__points[#self.__points + 1] = { ... } end
function Widget:ClearAllPoints() self.__points = {} end
function Widget:GetNumPoints() return #self.__points end
function Widget:SetSize(w, h) self.__width, self.__height = w, h end
function Widget:SetWidth(w) self.__width = w end
function Widget:SetHeight(h) self.__height = h end
function Widget:GetWidth() return self.__width end
function Widget:GetHeight() return self.__height end
function Widget:GetSize() return self.__width, self.__height end
function Widget:SetText(t) self.__text = t end
function Widget:GetText() return self.__text end
function Widget:SetFormattedText(fmt, ...) self.__text = string.format(fmt, ...) end
function Widget:CreateTexture(name) return newObject("Texture", name, self) end
function Widget:CreateMaskTexture(name) return newObject("MaskTexture", name, self) end
function Widget:CreateFontString(name) return newObject("FontString", name, self) end
function Widget:CreateLine(name) return newObject("Line", name, self) end
function Widget:CreateAnimationGroup(name) return newObject("AnimationGroup", name, self) end
function Widget:CreateAnimation(t, name) return newObject(t or "Animation", name, self) end
function Widget:GetChildren() return unpack(self.__children) end

function M.CreateFrame(frameType, name, parent, template, id)
    if not M.data.widgets[frameType] then
        error("CreateFrame: Unknown frame type '" .. tostring(frameType) .. "'", 2)
    end
    local f = newObject(frameType, name, parent)
    f.__template = template
    if f.__scripts.OnLoad then f.__scripts.OnLoad(f) end
    return f
end

-- ---------------------------------------------------------------- events, time
local cleuArgs
function M.fire(event, ...)
    local argc = select("#", ...)
    local args = { ... }
    argc = applySecretPayload(event, args, argc)
    local n = 0
    for _, f in ipairs(M.frames) do
        if (f.__allEvents or f.__events[event]) and f.__scripts.OnEvent then
            f.__scripts.OnEvent(f, event, unpack(args, 1, argc))
            n = n + 1
        end
    end
    if M.eventRegistryCallbacks[event] then
        for _, cb in ipairs(M.eventRegistryCallbacks[event]) do cb[1](cb[2], unpack(args, 1, argc)) n = n + 1 end
    end
    return n
end
M.eventRegistryCallbacks = {}
function M.setCombatLog(args) cleuArgs = args end

function M.advance(dt)
    M.now = M.now + (dt or 0)
    local due, keep = {}, {}
    for _, t in ipairs(M.timers) do
        if t.at <= M.now and not t.cancelled then due[#due + 1] = t else keep[#keep + 1] = t end
    end
    M.timers = keep
    table.sort(due, function(a, b) return a.at < b.at end)
    for _, t in ipairs(due) do
        t.cb(t.handle)
        if t.iterations and t.iterations ~= 1 and not t.cancelled then
            t.iterations = t.iterations > 1 and t.iterations - 1 or t.iterations
            t.at = M.now + t.delay
            M.timers[#M.timers + 1] = t
        end
    end
    for _, f in ipairs(M.frames) do
        if f.__scripts.OnUpdate and f.__shown then f.__scripts.OnUpdate(f, dt or 0) end
    end
end

function M.setCombat(flag)
    local was = M.inCombat
    M.inCombat = flag and true or false
    if flag and not was then M.fire("PLAYER_REGEN_DISABLED") elseif was and not flag then M.fire("PLAYER_REGEN_ENABLED") end
end

-- ---------------------------------------------------------------- install
local function strsplit(sep, s, limit)
    local out, pattern, pos = {}, "([^" .. sep:gsub("%p", "%%%0") .. "]*)", 1
    s = tostring(s)
    while true do
        if limit and #out == limit - 1 then out[#out + 1] = s:sub(pos) break end
        local a, b = s:find("[" .. sep:gsub("%p", "%%%0") .. "]", pos)
        if not a then out[#out + 1] = s:sub(pos) break end
        out[#out + 1] = s:sub(pos, a - 1)
        pos = b + 1
    end
    return unpack(out)
end

function M.install(env, opts)
    env = env or _G
    opts = opts or {}
    for ns, fns in pairs(M.data.namespaces) do
        local t = {}
        for _, fn in ipairs(fns) do t[fn] = stub(ns .. "." .. fn) end
        env[ns] = t
    end
    for _, fn in ipairs(M.data.globals) do
        if env[fn] == nil then env[fn] = stub(fn) end
    end
    env.Enum = M.decode(M.data.Enum)
    env.Constants = M.decode(M.data.Constants)
    for k, v in pairs(M.data.constants) do if env[k] == nil then env[k] = v end end
    for k, v in pairs(M.data.project) do env[k] = v end
    if opts.strings ~= false then
        local ok, strings = pcall(dofile, M.dir .. "forever_strings.lua")
        if ok and type(strings) == "table" then for k, v in pairs(strings) do if env[k] == nil then env[k] = v end end end
    end
    env.CreateFrame = M.CreateFrame
    env.UIParent = env.UIParent or newObject("Frame", "UIParent")
    env.WorldFrame = env.WorldFrame or newObject(M.data.widgets.WorldFrame and "WorldFrame" or "Frame", "WorldFrame")
    env.GetTime = function() return M.now end
    env.GetTimePreciseSec = env.GetTime
    env.InCombatLockdown = function() return M.inCombat end
    env.UnitAffectingCombat = function(u) return M.inCombat end
    env.issecretvalue = function(v) return issecret(v) end
    env.issecrettable = function(v) return issecret(v) end
    env.canaccessvalue = function(v) return not issecret(v) end
    env.canaccesstable = env.canaccessvalue
    env.CombatLogGetCurrentEventInfo = function() if cleuArgs then return unpack(cleuArgs, 1, cleuArgs.n or #cleuArgs) end end
    env.C_Timer = env.C_Timer or {}
    env.C_Timer.After = function(d, cb) M.timers[#M.timers + 1] = { at = M.now + d, delay = d, cb = cb } end
    env.C_Timer.NewTimer = function(d, cb)
        local h = { Cancel = function(self) self.t.cancelled = true end, IsCancelled = function(self) return self.t.cancelled end }
        h.t = { at = M.now + d, delay = d, cb = cb, handle = h, iterations = 1 }
        M.timers[#M.timers + 1] = h.t
        return h
    end
    env.C_Timer.NewTicker = function(d, cb, it)
        local h = env.C_Timer.NewTimer(d, cb)
        h.t.iterations = it or -1
        return h
    end
    env.hooksecurefunc = function(a, b, c)
        local t, k, f = env, a, b
        if type(a) == "table" then t, k, f = a, b, c end
        local old = t[k]
        t[k] = function(...) local r = { old(...) } f(...) return unpack(r) end
    end
    env.issecure = function() return false end
    env.securecall = function(f, ...) if type(f) == "string" then f = env[f] end return f(...) end
    env.securecallfunction = env.securecall
    env.geterrorhandler = function() return function(e) error(e, 0) end end
    env.seterrorhandler = function() end
    env.debugprofilestop = function() return os.clock() * 1000 end
    env.debugstack = function() return debug.traceback() end
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.table.wipe = env.wipe
    env.tinsert, env.tremove, env.sort = table.insert, table.remove, table.sort
    env.strsplit = strsplit
    env.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
    env.strtrim = function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strmatch, env.strfind, env.strsub, env.gsub = string.match, string.find, string.sub, string.gsub
    env.strlower, env.strupper, env.strlen, env.format, env.strrep = string.lower, string.upper, string.len, string.format, string.rep
    env.floor, env.ceil, env.abs, env.max, env.min, env.mod = math.floor, math.ceil, math.abs, math.max, math.min, math.fmod
    env.tContains = function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
    env.Mixin = function(o, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do o[k] = v end end return o end
    env.CreateFromMixins = function(...) return env.Mixin({}, ...) end
    env.date, env.time = os.date, os.time
    env.SlashCmdList = env.SlashCmdList or {}
    env.UISpecialFrames = env.UISpecialFrames or {}
    env.StaticPopupDialogs = env.StaticPopupDialogs or {}
    env.DEFAULT_CHAT_FRAME = env.DEFAULT_CHAT_FRAME or newObject("ScrollingMessageFrame", "DEFAULT_CHAT_FRAME")
    rawset(env.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg) M.chat[#M.chat + 1] = msg end)
    env.EventRegistry = env.EventRegistry or {
        RegisterCallback = function(_, ev, f, owner)
            M.eventRegistryCallbacks[ev] = M.eventRegistryCallbacks[ev] or {}
            table.insert(M.eventRegistryCallbacks[ev], { f, owner })
        end,
        TriggerEvent = function(_, ev, ...) M.fire(ev, ...) end,
    }
    env.print = env.print or print
    return env
end
M.chat = {}

-- Run a slash command registered via SLASH_<KEY>n / SlashCmdList.
function M.slash(line)
    local cmd, rest = line:match("^(%S+)%s*(.*)$")
    for key, fn in pairs(_G.SlashCmdList) do
        for i = 1, 9 do
            local s = _G["SLASH_" .. key .. i]
            if s and s:lower() == cmd:lower() then return fn(rest) end
        end
    end
    error("unknown slash command " .. tostring(cmd))
end

-- Load an addon folder: reads <name>.toc (or _Camelot / _Mainline variant), runs listed .lua files with (name, ns).
function M.loadAddon(dir, name, ns)
    name = name or dir:match("([^/\\]+)[/\\]?$")
    ns = ns or {}
    local toc
    for _, suffix in ipairs({ "_Camelot", "_Mainline", "" }) do
        local f = io.open(dir .. "/" .. name .. suffix .. ".toc")
        if f then toc = f:read("*a") f:close() break end
    end
    assert(toc, "no .toc for " .. name)
    for line in toc:gmatch("[^\r\n]+") do
        line = line:gsub("%s+$", "")
        if line ~= "" and not line:match("^#") and line:lower():match("%.lua$") then
            local chunk = assert(loadfile(dir .. "/" .. line:gsub("\\", "/")))
            chunk(name, ns)
        end
    end
    M.fire("ADDON_LOADED", name)
    return ns
end

return M
