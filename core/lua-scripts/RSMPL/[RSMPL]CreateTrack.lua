-- @description Create new RSMPL Track from selected tracks
-- @author NomadMonad
-- @version 0.1a

local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)RSMPL/')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
require('ReaWrap.models')
require('RSMPL.resample')

local r = Reaper:new()
local p = Project:new()

local function main(opts)
    if not p:has_selected_tracks()
    then
        r:msg_box('Please select a track', 'No track selected')
        return
    end
    for track in p:iter_selected_tracks() do
        create_resample_track(p, track)
    end
end

local no_refresh = r:prevent_refresh()
local undo = r:undo('Create Resample Track')
no_refresh(undo, main, opts)
