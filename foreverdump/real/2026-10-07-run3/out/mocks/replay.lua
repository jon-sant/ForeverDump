-- replay.lua: feed a ForeverDump recorder session (fixtures/session_N.lua) into an addon.
--   local wow = dofile("mocks/wowmock.lua"); wow.install()
--   local Replay = dofile("mocks/replay.lua")
--   local session = Replay.load("mocks/fixtures/session_1.lua")
--   Replay.run(session, { frame = MyAddonFrame })              -- frame's OnEvent, registered events only
--   Replay.run(session, { handler = function(event, ...) end })   -- or a plain function
--   Replay.run(session, {})                                        -- broadcast to every mock frame (wow.fire)
-- Works for recorder sessions, /fdump cl sessions and `fdump.py combatlog` file fixtures (same entry shape;
-- CLEU entries set CombatLogGetCurrentEventInfo() and fire COMBAT_LOG_EVENT_UNFILTERED with no payload).
-- Options: events = { NAME = true } filter, all = true (ignore registration), skipCallbacks = true,
--          includeFileOnly = true (also fire non-CLEU file lines such as ZONE_CHANGE),
--          cleu = false (skip legacy CLEU entries: Forever mode), forever = false (skip synthetic Forever events:
--          legacy mode). Entries with `g` stub getters (e.g. C_CombatText.GetCurrentEventInfo) during dispatch.
--          onEvent = function(entry, args, n) end (inspection hook). Returns stats.
local here = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")
local Replay = {}
local wow

local function mock()
    wow = wow or (package.loaded.wowmock) or dofile(here .. "wowmock.lua")
    return wow
end

function Replay.load(path)
    local s = dofile(path)
    assert(type(s) == "table" and type(s.events) == "table", "not a ForeverDump session fixture: " .. path)
    return s
end

function Replay.decodeArgs(entry)
    local w = mock()
    local a, n = entry.a or {}, entry.n or #(entry.a or {})
    local out = {}
    for i = 1, n do out[i] = w.decode(a[i]) end
    return out, n
end

function Replay.run(session, opts)
    local w = mock()
    opts = opts or {}
    local stats = { delivered = 0, skipped = 0, redacted = 0, secrets = 0, combat = 0, errors = {} }
    local t0 = session.events[1] and session.events[1].t or 0
    local base = w.now
    for _, entry in ipairs(session.events) do
        local wanted = (not opts.events or opts.events[entry.e]) and not (opts.skipCallbacks and entry.cb)
        if wanted and entry.redacted and not opts.includeRedacted then wanted = false stats.redacted = stats.redacted + 1 end
        if wanted and entry.fileOnly and not opts.includeFileOnly then wanted = false end  -- e.g. COMBAT_LOG_VERSION lines
        if wanted and entry.cleu and opts.cleu == false then wanted = false end
        if wanted and entry.synthetic and opts.forever == false then wanted = false end
        if wanted then
            w.now = base + ((entry.t or t0) - t0)
            w.inCombat = entry.c and true or false
            if entry.c then stats.combat = stats.combat + 1 end
            local args, n = Replay.decodeArgs(entry)
            if entry.s then stats.secrets = stats.secrets + #entry.s end
            if entry.cleu then
                local cl = { n = n }
                for i = 1, n do cl[i] = args[i] end
                w.setCombatLog(cl)
                args, n = {}, 0  -- in the real client CLEU has no payload; use CombatLogGetCurrentEventInfo()
            end
            if entry.g then
                for name, r in pairs(entry.g) do
                    if type(r) == "table" and r.a then
                        local vals = { n = r.n or #r.a }
                        for i = 1, vals.n do vals[i] = w.decode(r.a[i]) end
                        w.returns[name] = vals
                    end
                end
            end
            if opts.onEvent then opts.onEvent(entry, args, n) end
            local ok, err = true, nil
            if opts.handler then
                ok, err = pcall(opts.handler, entry.e, unpack(args, 1, n))
            elseif opts.frame then
                local f = opts.frame
                local script = f.GetScript and f:GetScript("OnEvent") or (f.__scripts and f.__scripts.OnEvent)
                if script and (opts.all or (f.IsEventRegistered and f:IsEventRegistered(entry.e))) then
                    ok, err = pcall(script, f, entry.e, unpack(args, 1, n))
                else
                    ok = nil
                end
            else
                ok, err = pcall(w.fire, entry.e, unpack(args, 1, n))
            end
            if ok == nil then stats.skipped = stats.skipped + 1
            else
                stats.delivered = stats.delivered + 1
                if not ok then stats.errors[#stats.errors + 1] = { event = entry.e, t = entry.t, err = tostring(err) } end
            end
            if entry.cleu then w.setCombatLog(nil) end
            if entry.g then for name in pairs(entry.g) do w.returns[name] = nil end end
        else
            stats.skipped = stats.skipped + 1
        end
    end
    w.inCombat = false
    return stats
end

return Replay
