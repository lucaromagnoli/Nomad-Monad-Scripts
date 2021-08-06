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
local p = Project:new()
local gui = ImGui:new('RSMPL - Render up to FX', 'sans-serif', 500, 200)
local FLT_MIN, FLT_MAX = gui:numeric_limits_float()
local allow_double_click = reaper.ImGui_SelectableFlags_AllowDoubleClick()
local current_idx = 1
local selected_fx = nil

function is_selected_item_double_clicked(sel_fx)
    return sel_fx ~= nil and gui:is_mouse_double_clicked() and gui:is_item_hovered()
end

function confirm_selection(fx)
    local fx_name = fx:get_name()
    return r:msg_box(fx_name, 'Render up to FX', 1)
end

function iter_fx_chain(ctx, fx_chain)
    for i, fx in ipairs(fx_chain) do
        local is_selected = current_idx == i
        local _, is_selectable = gui:selectable(fx:get_name(), is_selected)
        if is_selectable then
            current_idx = i
        end
        if is_selected then
            gui:set_item_default_focus()
            selected_fx = fx
        end
        if is_selected_item_double_clicked(ctx, selected_fx) then
            if confirm_selection(selected_fx) then
                r:log('rendering up to fx', selected_fx)
                --bypass_render_reload(sel_track, selected_fx)
                gui:done()
            end
        end
    end
end


local function iter_tracks(ctx)
    if p:count_selected_media_items() == 0 then
        r:msg_box('Please select an item', 'RSMPL Error', 0)
        return
    end
    for _, sel_track in ipairs(p:get_selected_tracks()) do
        local name = sel_track:get_name()
        gui:text(name)
        local fx_chain = sel_track:get_fx_chain()
        local width = -FLT_MIN
        local height = #fx_chain * gui:get_text_line_height_with_spacing()
        local label = '##FX listbox'
        local listbox_context = gui:list_box_context(label, width, height)
        listbox_context(iter_fx_chain, ctx, fx_chain)
        gui:text(name)
    end
end


local function main()
    loop = gui:loop(iter_tracks)
    reaper.defer(loop)
end

local no_refresh = r:prevent_refresh()
local undo = r:undo('Render instrument')
no_refresh(undo, main)
