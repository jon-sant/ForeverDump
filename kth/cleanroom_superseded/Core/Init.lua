-- K.T.H. Forever - Core/Init.lua
-- Clean-room Forever port of K.T.H. (Kill The Healer). Original concept: H.H.T.D. by John Wellesz;
-- K.T.H. Midnight adaptation by Scone. No original code is used (the original is All Rights Reserved).
local _, ns = ...
ns.VERSION = "1.0.0-forever"
ns.DEFAULTS = {
    sound = true,        -- alert sounds
    probable = false,    -- show the weaker PROBABLE tier on plates/list
    friendly = true,     -- track friendly healers too
    plates = true,       -- nameplate markers
    msgShown = true,     -- own message frame
    locked = true,
    debug = false,
    anywhere = false,    -- also run outside battlegrounds (world PvP); off by default
    marks = {},          -- custom marks: ["E:Name"] = true
}

-- Messages go ONLY to K.T.H.'s own ScrollingMessageFrame (never DEFAULT_CHAT_FRAME / ChatFrameN / print).
local pending = {}
function ns.msg(text)
    local f = ns.UI and ns.UI.msgFrame
    if f then
        pcall(f.AddMessage, f, "|cffff5555K.T.H.|r " .. tostring(text))
    else
        pending[#pending + 1] = text
    end
end
function ns.flushPending()
    local p = pending
    pending = {}
    for _, t in ipairs(p) do ns.msg(t) end
end
function ns.debug(text)
    if ns.db and ns.db.debug then ns.msg("|cff888888dbg|r " .. tostring(text)) end
end
