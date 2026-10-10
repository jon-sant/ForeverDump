import os
os.chdir('/workspace/foreverdump/ForeverDump')
def edit(p, pairs):
    s = open(p).read()
    for a, b in pairs:
        assert a in s, (p, a[:60])
        s = s.replace(a, b, 1)
    open(p, 'w').write(s)
edit('Core.lua', [('''    restrictions = {          -- v2.2 restrictions tracker''','''    lab = {                   -- v2.2 workarounds lab (Lab.lua): sanctioned secret-value paths, boundary diagnostics only
        auto = true,          -- FD_Logs: run once out of combat (ON) and once in the first combat
        poll = false,         -- opt-in: sample UnitHealth/UnitPower("player") secrecy every pollInterval s while capturing
        pollInterval = 0.5,
    },
    restrictions = {          -- v2.2 restrictions tracker''')])
edit('ForeverDump.toc', [('Controls.lua\n', 'Controls.lua\nLab.lua\n')])
edit('Logs.lua', [('''    if why == "on" then
        if c.probe and ns.Probe then''','''    if why == "on" and ns.Lab and ns.config.lab.auto ~= false then
        local okL = pcall(ns.Lab.Run, "capture:on")
        if okL then started[#started + 1] = "workarounds lab" end
    end
    if ns.Lab and ns.config.lab.poll and not ns.Lab.Polling() then
        ns.Lab.StartPoll()
        started[#started + 1] = "secrecy polling " .. tostring(ns.config.lab.pollInterval) .. "s"
    end
    if why == "on" then
        if c.probe and ns.Probe then'''), ('''    if reason == "off" and ns.Controls and ns.config.secrets.controls ~= false then''','''    if ns.Lab and ns.Lab.Polling() then ns.Lab.StopPoll() end
    if reason == "off" and ns.Controls and ns.config.secrets.controls ~= false then''')])
edit('Commands.lua', [('''    elseif cmd == "debug" then''','''    elseif cmd == "lab" then
        local sub, w = string.lower(rest[1] or ""), string.lower(rest[2] or "")
        if sub == "poll" then
            ns.config.lab.poll = (w == "on")
            if w == "on" then ns.Lab.StartPoll() else ns.Lab.StopPoll() end
            ns.Print("secrecy polling " .. (w == "on" and "ON" or "off") .. " (lab.poll, every " .. tostring(ns.config.lab.pollInterval) .. "s)")
        else
            local rec = ns.Lab.Run("command")
            local n, absent = 0, 0
            for _, it in ipairs(rec and rec.items or {}) do n = n + 1 if it.available == false then absent = absent + 1 end end
            ns.Print(string.format("lab (%s): %d approaches measured, %d absent in this build -> ForeverDumpLogDB.lab (converter: fdump.py lab)",
                rec and rec.ctx or "?", n - absent, absent))
        end
    elseif cmd == "debug" then'''), ('''    p("  /fdump debug on''','''    p("  /fdump lab [poll on|off]   workarounds lab: sanctioned secret-value paths (sinks, curves, durations), boundary checks")
    p("  /fdump debug on'''), ('''["restrictions.maxFlips"] = true,''','''["restrictions.maxFlips"] = true, ["lab.auto"] = true, ["lab.poll"] = true, ["lab.pollInterval"] = true,
    ["secrets.controls"] = true, ["secrets.opsPrint"] = true,''')])
edit('Controls.lua', [('''    for _, op in ipairs(OPS) do
        local ok, res = pcall(op[2], v)
        r[op[1]] = { ok = ok, err = (not ok) and errText(res) or nil, resultSecret = ok and isSecret(res) or nil }
    end''','''    for _, op in ipairs(OPS) do
        local ok, res = pcall(op[2], v)
        local e = { ok = ok, err = (not ok) and errText(res) or nil, resultSecret = ok and isSecret(res) or nil }
        -- string results: only "is it a numeric string" (never the string), and only when the result is not secret
        if ok and type(res) == "string" and not e.resultSecret then e.numericString = tonumber(res) ~= nil end
        if ok and op[1] == "tostring" and e.resultSecret then
            local okN, nv = pcall(tonumber, res)
            e.tonumberOk, e.tonumberNil = okN, okN and nv == nil or nil   -- live 2026-10-07: tonumber(secret string) -> nil
        end
        r[op[1]] = e
    end'''), ('''    local rec = { reason = reason, ctx = ctx }''','''    local rec = { reason = reason, ctx = ctx, execution = "addon" }   -- chat /run is force-tainted (ForceTaint_Strong)''')])
print("ok")
