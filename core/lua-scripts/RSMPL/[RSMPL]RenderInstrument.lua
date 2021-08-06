-- @description Render virtual instrument to a new take
-- @author NomadMonad
-- @version 0.1a
--
local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)RSMPL/')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
require('ReaWrap.models')
require('RSMPL.resample')


local r = Reaper:new()

local function main(opts)
    local p = Project:new()
    if p:count_selected_media_items() == 0 then
        r:msg_box('Please select an item', 'Error', 0)
        return
    end
    for _, sel_track in ipairs(p:get_selected_tracks()) do
        if sel_track:has_instrument() then
            bypass_render_reload(sel_track)
        else
            r:msg_box('Track has no instrument', 'Error', 0)
        end
    end
end

local no_refresh = r:prevent_refresh()
local undo = r:undo('Render instrument')
no_refresh(undo, main, opts)
