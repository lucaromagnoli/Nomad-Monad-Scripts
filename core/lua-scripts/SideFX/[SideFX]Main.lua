local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)SideFX/')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
package.path = package.path .. ';' .. parent .. 'SideFX/?.lua'
require('ReaWrap.models.reaper')
require('ReaWrap.models.project')
require('ReaWrap.models.im_gui')
require('FXTree')

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

function traverse_fx_tree(children, level)
    level = level or 0
    for _, child in ipairs(children) do
        gui:push_id(child.id)
        gui:table_next_row()
        gui:table_set_column_index(0)
        gui:align_text_to_frame_padding()
        --is_selected = current_child == child
        if child:has_children() then
            local open = gui:tree_node_ex(
                    child.id,
                    '',
                    gui:tree_node_flags_default_open()
            )
            gui:same_line()
            if gui:selectable(tostring(child), child.is_selected) then
                child.is_selected = not child.is_selected
            end
            if child.is_selected then
                fxtree:deselect_all_except(child)
                if gui:begin_popup_context_item('Node pop up') then
                    add_fx_menu(child)
                    gui:end_popup()
                end
            end
            gui:table_set_column_index(1)
            gui:text(level)
            gui:set_next_item_width(-FLT_MIN)
            --retval, placeholder_members[i] = gui:input_double('##value', placeholder_members[i], 1.0)
            if open then
                traverse_fx_tree(child.children, level + 1)
                gui:pop_tree()
            end
        else
            local flags = gui:tree_node_flags_leaf() | gui:tree_node_flags_default_open()
            gui:tree_node_ex(child.id, '', flags)
            gui:same_line()
            if gui:selectable(tostring(child), child.is_selected) then
                child.is_selected = not child.is_selected
            end
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
            gui:table_set_column_index(1)
            --gui:checkbox('Checkbox')
            gui:text(mbl)
            gui:set_next_item_width(-FLT_MIN)
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
        gui:table_next_row()
        gui:table_set_column_index(0)
        gui:align_text_to_frame_padding()
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


multiple = { false, false, false, false, false }
function selectables_test()
    gui:set_next_window_size(430, 450, ImGui:cond_first_use_ever())
    local rv, open = gui:begin_window('Side FX Editor')
    if not rv then
        return open
    end
    for i, sel in ipairs(multiple) do
        if gui:selectable(('Object %d'):format(i - 1), sel) then
            if (gui:get_key_mods() & gui:key_mod_flags_ctrl()) == 0 then
                -- Clear selection when CTRL is not held
                for j = 1, #multiple do
                    multiple[j] = false
                end
            end
            multiple[i] = not sel
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