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
local gui = ImGui:new('Side FX', ImGui:config_flags_docking_enable())
local FLT_MIN, FLT_MAX = gui:numeric_limits_float()


function create_tree()
    local node_0, node_1, leaf_0, leaf_1
    local root = Root:new()
    for i=0, 2 do
        node_0 = Node:new()
        root:add_child(node_0)
        for j=0, 5 do
            leaf_0 = Leaf:new()
            node_0:add_child(leaf_0)
        end
        for j=0, 2 do
            node_1 = Node:new()
            node_0:add_child(node_1)
            for z=0, 2 do
                leaf_1 = Leaf:new()
                node_1:add_child(leaf_1)
            end
        end
    end
    for i=0, 2 do
        leaf = Leaf:new()
        root:add_child(leaf)
    end
    return root
end

--local fxtree = create_tree()

placeholder_members = { 0.0, 0.0, 1.0, 3.1416, 100.0, 999.0, 0.0, 0.0 }

function is_selected_item_double_clicked(sel_item)
    return sel_item ~= nil
            and gui:is_mouse_double_clicked()
            and gui:is_item_hovered()
end

local function add_fx_handler(member, mode, fx)
    local node
    leaf = FXLeaf:new(fx)
    if mode == 0 then
        if member:is_root() then
            member:add_child(leaf)
        else
            member_idx = member.parent:get_child_idx(member)
            member.parent:add_child(leaf, member_idx + 1)
        end
    elseif mode == 1 then
        if member:is_leaf() then
            local member_parent = member.parent
            local member_idx = member_parent:get_child_idx(member)
            node_parent = FXNode:new()
            member_parent:remove_child(member)
            node_parent:add_child(member)
            member_parent:add_child(node_parent, member_idx)
            node_child = FXNode:new()
            node_child:add_child(leaf)
            node_parent:add_child(node_child)
        else
            node = FXNode:new()
            node:add_child(leaf)
            member:add_child(node)
        end
    end
end

local function add_fx_menu(child)
    if gui:selectable('Add FX serial') then
        add_fx_handler(child, 0)
        --reawrap:show_message_box('Add serial FX to ' .. child.id, 'Y0')
    elseif gui:selectable('Add FX parallel') then
        add_fx_handler(child, 1)
        --reawrap:show_message_box('Add parallel FX to ' .. child.id, 'Y0')
    end
end

function traverse_fx_tree(children, level)
    level = level or 0
    local rv
    for idx, child in ipairs(children) do
        gui:push_id(child.id)
        gui:table_next_row()
        gui:table_set_column_index(0)
        gui:align_text_to_frame_padding()
        if child:has_children() then
            local open = gui:tree_node_ex(child.id, ('%s'):format(child))
            if gui:begin_popup_context_item('Leaf pop up') then
                add_fx_menu(child)
                gui:end_popup()
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
            local flags = gui:tree_node_flags_leaf()
            gui:tree_node_ex(child.id, '', flags)
            gui:same_line()
            is_selected = current_child == child
            local is_selectable = gui:selectable(tostring(child), is_selected)
            if gui:begin_popup_context_item('Leaf pop up') then
                add_fx_menu(child)
                gui:end_popup()
            end
            if is_selectable then
                current_child = child
            end
            if is_selected then
                gui:set_item_default_focus()
            end
            if is_selected_item_double_clicked(child) then
                reawrap:show_message_box('Selected ' .. child.id, 'Y0')
            end
            gui:table_set_column_index(1)
            gui:text(level)
            gui:set_next_item_width(-FLT_MIN)
            gui:pop_tree()
        end
        gui:pop_id()
    end
end

local fxtree = FXRoot:new()
local is_selected

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
        gui:selectable(tostring(fxtree), is_selected)
        if gui:begin_popup_context_item('Leaf pop up') then
            add_fx_menu(fxtree)
            gui:end_popup()
        end
        gui:table_next_row()
        gui:table_set_column_index(1)
        gui:align_text_to_frame_padding()
        traverse_fx_tree(fxtree.children)

        gui:end_table()
    end
    gui:pop_style_var()
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