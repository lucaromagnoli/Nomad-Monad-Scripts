-- @description Render virtual instrument to a new take
-- @author NomadMonad
-- @version 0.1a
--
local r = reaper

local function msg(object)
    r.ShowConsoleMsg(tostring(object) .. '\n')
end

DEBUG = true

-- local function log(...)
--     if DEBUG then
--         local joined = ''
--         for _, v in ipairs(arg) do
--             if joined then
--                 joined = joined .. ', ' .. tostring(v)
--             else
--                 joined = tostring(v)
--             end
--             msg(joined)
--         end
--     end
-- end


local function reaper_dofile(file) 
    local info = debug.getinfo(1,'S')
    local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
    dofile(script_path .. file)
end

reaper_dofile("models.lua")



local function bypass_fx_chain(fx_chain)
    for _, fx in ipairs(fx_chain) do
        if not fx:is_instrument() then
            local is_enabled = tostring(fx:is_enabled())
            fx:set_key_value('is_enabled', is_enabled, false)
            fx:disable()
        end
    end
end

local function reload_fx_chain_state(fx_chain)
    for _, fx in ipairs(fx_chain) do
        if not fx:is_instrument() then
            local old_state = fx:get_key_value('is_enabled') == 'true'
            fx:set_enabled(old_state)
        end
    end
end



local function main()
    if r.CountSelectedMediaItems(0) == 0 then
        r.MB('Please select an item', 'Error', 0)
        return
    end
    local sel_media_track = r.GetSelectedTrack(0, 0)
    local sel_track = Track:new(sel_media_track)
    local fx_chain = sel_track:get_fx_chain()
    msg(sel_track)
    msg(fx_chain)
    local has_instrument = sel_track:has_instrument()
    if has_instrument then
        r.Undo_BeginBlock(1)
        r.PreventUIRefresh(1)
        bypass_fx_chain(fx_chain)
        r.Main_OnCommand(40209, 0) -- render to stereo take
        reload_fx_chain_state(fx_chain)
        r.PreventUIRefresh(-1)
        r.Undo_EndBlock('Render to stereo take', -1)
    else
        r.MB('Track has no instrument', 'Error', 0)
    end

end

main()
