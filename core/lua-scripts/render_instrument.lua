-- @description Render virtual instrument to a new take
-- @author NomadMonad
-- @version 0.1a
--
function reaperDoFile(file) 
    local info = debug.getinfo(1,'S')
    local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
    dofile(script_path .. file)
end

reaperDoFile("models.lua")

local function msg(str)
    r.ShowConsoleMsg(str .. '\n')
end

local r = reaper

r.Undo_BeginBlock(1)
r.PreventUIRefresh(1)

if r.CountSelectedMediaItems(0) == 0 then
    r.MB('Please select an item', 'Error', 0)
    return
end
local sel_media_track = r.GetSelectedTrack(0, 0)
local sel_track = Track:new(sel_media_track)
if not sel_track.has_instrument then
    r.MB('Track has no virtual instrument', 'Error', 0)
    return
end
sel_track:disable_all_fx()
r.Main_OnCommand(40209, 0)
sel_track:state_reload()

r.PreventUIRefresh(-1)
r.Undo_EndBlock('Apply to stereo take', -1)
