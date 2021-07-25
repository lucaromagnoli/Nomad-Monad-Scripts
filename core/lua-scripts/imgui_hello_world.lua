DEBUG = true

local path = ({ reaper.get_action_context() })[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

require('models')

local r = Reaper:new()
local project = Project:new()
local gui = ImGui:new('ImGuiHelloWorld', 'sans-serif', 500, 200)
local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
local allow_double_click = reaper.ImGui_SelectableFlags_AllowDoubleClick()
local current_idx = 1
local selected_fx = nil

function is_selected_item_double_clicked(ctx, sel_fx)
    return sel_fx ~= nil
            and reaper.ImGui_IsMouseDoubleClicked(ctx, 0)
            and reaper.ImGui_IsItemHovered(ctx)
end

function confirm_selection(fx)
    local fx_name = fx:get_name()
    return r:msg_box('copy FX Chain from ' .. fx_name, 'xsada', 1)
end

function get_inst_and_fx(track --[[Track]])
    local inst_chain = {}
    local fx_chain = {}
    for i, fx in ipairs(track:get_fx_chain()) do
        if fx:is_instrument() then
            inst_chain[i] = fx
        else
            fx_chain[i] = fx
        end
    end
    return inst_chain, fx_chain
end

function FXChain(ctx)
    --if not widgets.lists then
    --    widgets.lists = { current_idx = 1 }
    --end
    for _, track in ipairs(project:get_selected_tracks()) do
        local track_name = track:get_name()
        local instruments, audio_fx = get_inst_and_fx(track)
        gui:text(track_name)
        for _, v in ipairs(instruments) do
            gui:text(v)
        end
        if reaper.ImGui_BeginListBox(ctx, '##listbox 2', -FLT_MIN, #fx_chain * reaper.ImGui_GetTextLineHeightWithSpacing(ctx)) then
            for i, fx in ipairs(audio_fx) do
                local is_selected = current_idx == i
                local is_selectable = reaper.ImGui_Selectable(ctx, fx:get_name(), is_selected)
                if is_selectable then
                    current_idx = i
                end
                if is_selected then
                    reaper.ImGui_SetItemDefaultFocus(ctx)
                    selected_fx = fx
                end
            end
            reaper.ImGui_EndListBox(ctx)
        end
    end
    if is_selected_item_double_clicked(ctx, selected_fx) then
        if confirm_selection(selected_fx) then
            r:log('copying fx chain')
            gui:done()
        end
    end
end

click_count, text = 0, 'The quick brown fox jumps over the lazy dog'

function Frame(ctx)
    local rv
    if gui:button('Click me!') then
        click_count = click_count + 1
    end

    if click_count % 2 == 1 then
        gui:same_line()
        gui:text('hello dear imgui!')
    end

    rv, text = gui:input_text('text input', text)
    r:log(text)
    local items = {'item 1', 'item 2', 'item 3'}
    local current_item = 1
    rv, current_item, items = gui:list_box('list box label', current_item, items)
    if rv then
       r:log('rv', rv, 'current_item', current_item)
    end
end

function menu(ctx)
    if reaper.ImGui_BeginMenu(ctx, 'File') then
        if reaper.ImGui_MenuItem(ctx, 'Open') then
            reaper.ShowConsoleMsg('opening...\n')
        end
        if reaper.ImGui_MenuItem(ctx, 'Save') then
            reaper.ShowConsoleMsg('saving...\n')
        end
        reaper.ImGui_EndMenu(ctx)
    end
end


loop = gui:loop(FXChain)
reaper.defer(loop)