-- @description Create new RSMPL Track from selected tracks
-- @author NomadMonad
-- @version 0.1a
local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)RSMPL')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
require('ReaWrap.models')
require('RSMPL.resample')


local r = Reaper:new()
local p = Project:new()

local function main(opts)
    if not p:has_selected_media_items()
    then
        r:msg_box('Please select an item', 'No item selected')
        return
    end
    render_to_resample_track(r, p, fx_index)
end

local no_refresh = r:prevent_refresh()
local undo = r:undo('Render to Resample Track')
no_refresh(undo, main, opts)
