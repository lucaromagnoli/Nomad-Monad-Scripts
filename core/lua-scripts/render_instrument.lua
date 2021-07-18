-- @description Render virtual instrument to a new take
-- @author NomadMonad
-- @version 0.1a
--
local r = reaper

local function msg(object)
    r.ShowConsoleMsg(tostring(object) .. '\n')
end

local function reaper_dofile(file) 
    local info = debug.getinfo(1,'S')
    local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
    dofile(script_path .. file)
end

reaper_dofile("models.lua")


local function reload_fx_chain_state(track, fx_chain_state)
    for i, fx in track.get_fx_chain() do
        local old_state = fx_chain_state[i]
        msg(fx)
        msg(old_state)
    end
end

local function main()
    r.Undo_BeginBlock2(1)
    r.PreventUIRefresh(1)
    if r.CountSelectedMediaItems(0) == 0 then
        r.MB('Please select an item', 'Error', 0)
        return
    end
    local sel_media_track = r.GetSelectedTrack(0, 0)
    local sel_track = Track:new(sel_media_track)
    local fx_chain = sel_track:get_fx_chain()
    msg('-----')
    for _, fx in ipairs(fx_chain) do
        msg('in script')
        msg('idx ' .. _ .. ' fx ' .. tostring(fx))

    end

    -- if not sel_track:has_instrument() then
    --     r.MB('Track has no virtual instrument', 'Error', 0)
    --     return
    -- end
    -- local fx_chain_state = sel_track:get_fx_chain()
    -- sel_track:disable_all_fx()
    -- reload_fx_chain_state(sel_track, fx_chain_state)
    -- r.Main_OnCommand(40209, 0)
    -- r.PreventUIRefresh(-1)
    -- r.Undo_EndBlock2('Render instrument to stereo take', -1)
end

main()
