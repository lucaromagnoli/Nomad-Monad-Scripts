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

function loop()
    open = PropertyEditor()
    if open then
        reawrap:defer(loop)
    else
        gui:destroy_context()
    end

end

reawrap:defer(loop)

function create_tree()
    local root = Root:new()
    for i=0, 2 do
        node = Node:new()
        root:add_child(node)
        for j=0, 5 do
            leaf = Leaf:new()
            node:add_child(leaf)
        end
    end
    for i=0, 2 do
        leaf = Leaf:new()
        root:add_child(leaf)
    end
    return root
end

local fxtree = create_tree()

placeholder_members = { 0.0, 0.0, 1.0, 3.1416, 100.0, 999.0, 0.0, 0.0 }

function ShowPlaceholderObject(prefix, uid)
    local rv

    -- Use object uid as identifier. Most commonly you could also use the object pointer as a base ID.
    gui:push_id(uid)

    -- Text and Tree nodes are less high than framed widgets, using AlignTextToFramePadding() we add vertical spacing to make the tree lines equal high.
    gui:table_next_row()
    gui:table_set_column_index(0)
    gui:align_text_to_frame_padding()
    local node_open = gui:tree_node_ex('Object', ('%s_%u'):format(prefix, uid))
    gui:table_set_column_index(1)
    gui:text('my sailor is rich')

    if node_open then
        for i = 0, #placeholder_members - 1 do
            gui:push_id(i) -- Use field index as identifier.
            if i < 2 then
                ShowPlaceholderObject('Child', 424242)
            else
                -- Here we use a TreeNode to highlight on hover (we could use e.g. Selectable as well)
                gui:table_next_row()
                gui:table_set_column_index(0)
                gui:align_text_to_frame_padding()
                local flags = gui:tree_node_flags_leaf() |
                        gui:tree_node_flags_no_tree_push_on_open() |
                        gui:tree_node_flags_bullet()
                gui:tree_node_ex('Field', ('Field_%d'):format(i), flags)

                gui:table_set_column_index(1)
                gui:set_next_item_width(-FLT_MIN)
                if i >= 5 then
                    rv, placeholder_members[i] = gui:input_double('##value', placeholder_members[i], 1.0)
                else
                    rv, placeholder_members[i] = gui:drag_double('##value', placeholder_members[i], 0.01)
                end
            end
            gui:pop_id()
        end
        gui:tree_pop()
    end
    gui:pop_id()
end

function traverse_fx_tree(children)
    local rv
    for i, child in ipairs(children) do
        -- Use object uid as identifier. Most commonly you could also use the object pointer as a base ID.
        gui:push_id(child.id)
        gui:table_next_row()
        gui:table_set_column_index(0)
        gui:align_text_to_frame_padding()
        if gui:tree_node_ex('Child', ('%s'):format(child)) then
            gui:table_set_column_index(1)
            gui:text('hello node')
            gui:pop_tree()
        end
        gui:pop_id()
    end
end

function PropertyEditor()
    gui:set_next_window_size(430, 450, ImGui:cond_first_use_ever())
    local rv, open = gui:begin_window('Side FX Editor')
    if not rv then
        return open
    end
    gui:push_style_var(gui:style_var_frame_padding(), 2, 2)
    if gui:begin_table('split', 2, gui:table_flags_borders_outer() | gui:table_flags_resizable()) then
        -- Iterate placeholder objects (all the same data)
        traverse_fx_tree(fxtree.children)
        gui:end_table()
    end
    gui:pop_style_var()
    gui:end_window()
    return open
end
