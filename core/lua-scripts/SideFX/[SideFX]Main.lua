local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)SideFX/')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
package.path = package.path .. ';' .. parent .. 'SideFX/?.lua'
require('ReaWrap.models.reaper')
require('ReaWrap.models.project')
require('ReaWrap.models.im_gui')
require('FXTree')

local r = reaper
local reawrap = Reaper:new()
local fxtree = FXTree:new()
local gui = ImGui:new('Side FX', ImGui:config_flags_docking_enable())
local FLT_MIN, FLT_MAX = gui:numeric_limits_float()


local function is_selected_item_double_clicked(sel_item)
    return sel_item ~= nil
            and gui:is_mouse_double_clicked()
            and gui:is_item_hovered()
end

local function add_fx_menu(member)
    if gui:selectable('Add FX serial') then
        fxtree:add_fx(member, 0)
    elseif gui:selectable('Add FX parallel') then
        fxtree:add_fx(member, 1)
    end
    if not member:is_root() then
        gui:separator()
    end
    if member:is_leaf() then
        if gui:selectable('Remove FX') then
            fxtree:remove_fx(member)
        end
    elseif member:is_node() then
        if gui:selectable('Remove Node') then
            fxtree:remove_fx(member)
        end
    end
end

function maybe_swap_siblings(child, child_idx, siblings)
    if gui:is_item_active() and not gui:is_item_hovered() then
        local _, drag_y = gui:get_mouse_drag_delta(gui:mouse_button_left())
        local mouse_drag = drag_y < 0 and -1 or 1
        local n_next = child_idx + mouse_drag
        if n_next >= 1 and n_next < #siblings then
            siblings[child_idx] = siblings[n_next]
            siblings[n_next] = child
            gui:reset_mouse_drag_delta(gui:mouse_button_left())
        end
    end
end

function draw_node(child, child_idx, siblings)
    local open = gui:tree_node_ex(
            child.id,
            '',
            gui:tree_node_flags_default_open()
    )
    gui:same_line()
    if gui:selectable(tostring(child), child.is_selected) then
        child.is_selected = not child.is_selected
    end
    maybe_swap_siblings(child, child_idx, siblings)
    if child.is_selected then
        fxtree:deselect_all_except(child)
        if gui:begin_popup_context_item('Node pop up') then
            add_fx_menu(child)
            gui:end_popup()
        end
    end
    --- Node attributes
    draw_node_attribute_columns()
    return open
end

function draw_leaf(child, child_idx, siblings)
    local flags = gui:tree_node_flags_leaf() | gui:tree_node_flags_default_open()
    gui:tree_node_ex(child.id, '', flags)
    gui:same_line()
    if gui:selectable(tostring(child), child.is_selected) then
        child.is_selected = not child.is_selected
    end
    maybe_swap_siblings(child, child_idx, siblings)
    if child.is_selected then
        fxtree:deselect_all_except(child)
        if gui:begin_popup_context_item('Leaf pop up') then
            add_fx_menu(child)
            gui:end_popup()
        end
    end
    if is_selected_item_double_clicked(child) then
        reawrap:show_message_box('Selected ' .. child.id, 'Y0')
    end
    draw_leaf_attribute_columns()
end

function draw_column_zero()
    gui:table_next_row()
    gui:table_set_column_index(0)
    gui:align_text_to_frame_padding()
end

function draw_leaf_attribute_columns()
    gui:table_set_column_index(1)
    gui:text('leaf attrs')
    gui:set_next_item_width(-FLT_MIN)
end

function draw_node_attribute_columns()
    gui:table_set_column_index(1)
    gui:text('node attrs')
    --gui:set_next_item_width(-FLT_MIN)
end

function traverse_fx_tree(children, level)
    level = level or 0
    for idx, child in ipairs(children) do
        gui:push_id(child.id)
            draw_column_zero()
            --- Node
        if child:has_children() then
            local open = draw_node(child, idx, children)
                if open then
                    traverse_fx_tree(child.children, level + 1)
                    gui:pop_tree()
                end
        else
            draw_leaf(child, idx, children)
            gui:pop_tree()
        end
        gui:pop_id()
    end
end

function SideFXEditor()
    gui:set_next_window_size(430, 450, ImGui:cond_first_use_ever())
    local rv, open = gui:begin_window('Side FX Editor')
    if not rv then
        return open
    end
    gui:push_style_var(gui:style_var_frame_padding(), 2, 2)
    if gui:begin_table(
            '##SideFX',
            2,
            gui:table_flags_borders_outer() | gui:table_flags_resizable()
    ) then
        draw_column_zero()
        if gui:selectable(tostring(fxtree.root), fxtree.root.is_selected) then
            fxtree.root.is_selected = not fxtree.root.is_selected
        end
        if fxtree.root.is_selected then
            fxtree:deselect_all_except(fxtree.root)
            if gui:begin_popup_context_item('Root pop up') then
                add_fx_menu(fxtree.root)
                gui:end_popup()
            end
        end
        gui:table_next_row()
        gui:table_set_column_index(1)
        gui:align_text_to_frame_padding()
        traverse_fx_tree(fxtree.root.children)
        gui:end_table()
    end
    gui:pop_style_var()
    gui:end_window()
    return open
end

items = { 'Item One', 'Item Two', 'Item Three', 'Item Four', 'Item Five' }
function swappable_test()
    ctx = gui.ctx
    gui:set_next_window_size(430, 450, ImGui:cond_first_use_ever())
    local rv, open = gui:begin_window('Side FX Editor')
    if not rv then
        return open
    end
    for n, item in ipairs(items) do
        gui:selectable(item)
        if gui:is_item_active() and not gui:is_item_hovered() then
            local n_next = n + (({ gui:get_mouse_drag_delta(gui:mouse_button_left()) })[2] < 0 and -1 or 1)
            if n_next >= 1 and n_next < #items then
                items[n] = items[n_next]
                items[n_next] = item
                gui:reset_mouse_drag_delta(gui:mouse_button_left())
            end
        end
    end
    gui:end_window()
    return open
end

function loop()
    open = SideFXEditor()
    if open then
        reawrap:defer(loop)
    else
        gui:destroy_context()
    end
end

reawrap:defer(loop)