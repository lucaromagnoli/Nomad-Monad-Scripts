local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)SideFX/')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
package.path = package.path .. ';' .. parent .. 'utils/?.lua'
package.path = package.path .. ';' .. parent .. 'SideFX/?.lua'
require('ReaWrap.models.reaper')
require('ReaWrap.models.project')
require('ReaWrap.models.im_gui')
require('utils.plugin')
require('FXTree')

local reawrap = Reaper:new()
local project = Project:new()
local rsrc_path = reawrap:get_resource_path()
local os = reawrap:get_app_version():match('.+%/(%a+)')
local plugin_manager = PluginsManager:init(rsrc_path, os)
local gui = ImGui:new('Side FX', ImGui:config_flags_docking_enable())
local FLT_MIN, FLT_MAX = gui:numeric_limits_float()

--- Global state
--local project_fx_trees = load_project_fx_trees()
local project_fx_trees = {}
local open_browser = false
local sel_member = nil
local fx_menu_mode = nil
local selected_section
local current_section_idx = 1
local selected_plugin = nil
local current_plugin_idx = -1
local plugins_sections = {'All Plugins', 'VST', 'VSTi', 'VST3', 'VST3i', 'AU', 'AUi', 'JS'}

local function save_project_fx_trees()
    for _, fxtree in pairs(project_fx_trees) do
        fxtree:save_state()
    end
end

local function load_project_fx_trees()
    for track in project:iter_tracks() do
        tree = FXTree:load_state(project, track)
        project_fx_trees[track:GUID()] = tree
    end
end

local function draw_column_zero()
    gui:table_next_row()
    gui:table_set_column_index(0)
    gui:align_text_to_frame_padding()
end

local function draw_root_attribute_columns(leaf)
    for i, k in ipairs(FXAttributes) do
        gui:table_set_column_index(i)
        gui:text_disabled('---')
    end
end

local function draw_leaf_attribute_columns(leaf)
    for i, k in ipairs(FXAttributes) do
        gui:table_set_column_index(i)
        gui:text(leaf[k])
    end
end

local function draw_node_attribute_columns(node)
    for i, k in ipairs(FXAttributes) do
        gui:table_set_column_index(i)
        gui:text(node[k])
    end
end

local function is_selected_item_double_clicked(sel_item)
    return sel_item ~= nil
            and gui:is_mouse_double_clicked()
            and gui:is_item_hovered()
end

local function iter_plugins_sections()
    for s_idx, section in ipairs(plugins_sections) do
        local is_selected = current_section_idx == s_idx
        if gui:selectable(section, is_selected) then
            current_section_idx = s_idx
            current_plugin_idx = -1
        end
        if is_selected then
            gui:set_item_default_focus()
            selected_section = section
        end
    end
end

local function iter_plugins(section)
    local is_selectable, name
    for p_idx, plugin in plugin_manager:iter_plugins(section) do
        local is_selected = current_plugin_idx == p_idx
        if plugin.format == 'JS' then
            name = plugin.alias
        else
             name = plugin.name
        end
        _, is_selectable = gui:selectable(name, is_selected)
        gui:same_line()
        gui:text(plugin.format)
        if is_selectable then
            current_plugin_idx = p_idx
        end
        if is_selected then
            gui:set_item_default_focus()
            selected_plugin= plugin
        end
    end
end

function fx_browser()
    if gui:begin_popup_modal('FXBrowser', open_browser, gui:window_flags_menu_bar()) then
        -- Left
        if gui:begin_child('left pane', 150, 0, true) then
            iter_plugins_sections()
            gui:end_child()
        end
        gui:same_line()

        -- Right
        gui:begin_group()
        if gui:begin_child('right pane', 0, -gui:get_frame_height_with_spacing()) then
            -- Leave room for 1 line below us
            local retval, buffer = gui:input_text('Search')
            gui:separator()
            if retval then
                gui:text(buffer)
            else
                if selected_section == 'All Plugins' then
                    selected_section = nil
                end
                iter_plugins(selected_section)
            end
            gui:end_child()
            end

        if gui:button('add fx') then
            open_browser = false
            confirm = true
            gui:close_current_popup()
        end
        gui:end_group()
        gui:end_popup()
    else
        open_browser = false
        gui:close_current_popup()
        confirm = false
    end
    if confirm then
        return confirm, selected_plugin
    else
        return confirm, nil
    end
end

function add_fx_menu(fxtree, member)
    sel_member = member  ---don't touch this, it's needed.
    if gui:selectable('Add FX serial') then
        open_browser = true
        fx_menu_mode = 0
        sel_member = member
        return
    elseif gui:selectable('Add FX parallel') then
        open_browser = true
        fx_menu_mode = 1
        sel_member = member
        return
    end
    if not member:is_root() then
        gui:separator()
    end
    if sel_member:is_leaf() then
        if gui:selectable('Remove FX') then
            if sel_member:is_only_child() and not sel_member.parent:is_root() then
                fxtree:remove_fx(sel_member.parent)
            else
                fxtree:remove_fx(sel_member)
            end
        end
    elseif sel_member:is_node() then
        if gui:selectable('Remove Node') then
            fxtree:remove_fx(sel_member)
        end
    end
end

local function maybe_swap_siblings(child, child_idx, siblings)
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

local function draw_node(fxtree, child, child_idx, siblings)
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
            add_fx_menu(fxtree, child)
            gui:end_popup()
        end
    end
    draw_node_attribute_columns(child)
    return open
end

local function draw_leaf(fxtree, child, child_idx, siblings)
    local flags = gui:tree_node_flags_leaf() | gui:tree_node_flags_default_open()
    gui:tree_node_ex(child.id, '', flags)
    gui:same_line()
    if not fxtree:fx_is_valid(child.fx_guid) then
        fxtree:remove_child(child)
        return
    end
    if gui:selectable(tostring(child), child.is_selected) then
        child.is_selected = not child.is_selected
    end
    maybe_swap_siblings(child, child_idx, siblings)
    if child.is_selected then
        fxtree:deselect_all_except(child)
        if gui:begin_popup_context_item('Leaf pop up') then
            add_fx_menu(fxtree, child)
            gui:end_popup()
        end
    end
    if is_selected_item_double_clicked(child) then
        reawrap:show_message_box('Selected ' .. child.id, 'Y0')
    end
    draw_leaf_attribute_columns(child)
end

local function draw_headers()
    gui:table_setup_column('FX Chain')
    for i, k in ipairs(FXAttributes) do
        gui:table_setup_column(k)
        gui:text(k)
    end
    gui:table_headers_row()
end

local function traverse_fx_tree(fxtree, children, level)
    level = level or 0
    local open
    for idx, child in ipairs(children) do
        gui:push_id(child.id)
        draw_column_zero()
        if child:has_children() then
            open = draw_node(fxtree, child, idx, children)
            if open then
                traverse_fx_tree(fxtree, child.children, level + 1)
                gui:pop_tree()
            end
        else
            open = draw_leaf(fxtree, child, idx, children)
            gui:pop_tree()
        end
        gui:pop_id()
    end
end

function side_fx_editor(fxtree)
    local table_flags = gui:table_flags_borders()
            | gui:table_flags_borders_outer()
            | gui:table_flags_resizable()
    gui:push_style_var(gui:style_var_frame_padding(), 2, 2)
    if gui:begin_table(
            '##SideFX',
            #FXAttributes + 1,
            table_flags) then
        draw_headers(fxtree)
        draw_column_zero()
        if gui:selectable(tostring(fxtree.root.id), fxtree.root.is_selected) then
            fxtree.root.is_selected = not fxtree.root.is_selected
        end
        if fxtree.root.is_selected then
            fxtree:deselect_all_except(fxtree.root)
            if gui:begin_popup_context_item('Root pop up') then
                add_fx_menu(fxtree, fxtree.root)
                gui:end_popup()
            end
        end
        draw_root_attribute_columns()
        traverse_fx_tree(fxtree, fxtree.root.children)
        gui:end_table()
    end
    if open_browser then
        gui:open_popup('FXBrowser')
    end
    local confirm, fx = fx_browser(open_browser)
    if confirm then
        fxtree:add_fx(sel_member, fx_menu_mode, fx)
    end
    gui:pop_style_var()
end

function side_fx_window(fxtree)
    gui:set_next_window_size(430, 450, ImGui:cond_first_use_ever())
    local rv, open = gui:begin_window('Side FX Editor')
    if not rv then
        return open
    end
    if fxtree ~= nil then
        side_fx_editor(fxtree)
    else
       gui:text('No track selected')
    end
    gui:end_window()
    return open
end


function loop()
    local track_fx_tree
    if project:has_selected_tracks() then
        for track in project:iter_selected_tracks() do
            if project_fx_trees[track:GUID()] == nil then
                track_fx_tree = FXTree:load_state(project, track)
                project_fx_trees[track:GUID()] = track_fx_tree
            else
                track_fx_tree = project_fx_trees[track:GUID()]
            end
        end
        open = side_fx_window(track_fx_tree)
    else
        open = side_fx_window(nil)
    end
    if open then
        reawrap:defer(loop)
    else
        gui:destroy_context()
    end
end

--load_project_fx_trees()
reawrap:defer(loop)
reawrap:atexit(save_project_fx_trees)
