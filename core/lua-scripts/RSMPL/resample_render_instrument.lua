-- @description Render virtual instrument to a new take
-- @author NomadMonad
-- @version 0.1a
--
local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)RSMPL')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
require('ReaWrap.models')
require('RSMPL.resample')


local r = Reaper:new()

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

local function bypass_render_reload(track)
    r:log('bypass_render_reload')
    local fx_chain = track:get_fx_chain()
    bypass_fx_chain(fx_chain)
    r:apply_fx()
    reload_fx_chain_state(fx_chain)
end

local function main(opts)
    local p = Project:new()
    if p:count_selected_media_items() == 0 then
        r:msg_box('Please select an item', 'Error', 0)
        return
    end
    for _, sel_track in ipairs(p:get_selected_tracks()) do
        if sel_track:has_instrument() then
            r:log('track has instrument')
            bypass_render_reload(sel_track)
        else
            r:msg_box('Track has no instrument', 'Error', 0)
        end
    end
end

local no_refresh = r:prevent_refresh()
local undo = r:undo('Render instrument')
no_refresh(undo, main, opts)
