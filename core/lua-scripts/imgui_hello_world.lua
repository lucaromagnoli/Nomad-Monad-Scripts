DEBUG = true

local path = ({ reaper.get_action_context() })[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

require('models')

local r = Reaper:new()
local project = Project:new()
local gui = ImGui:new('RSMPL', 'sans-serif', 500, 200)


function Frame()
    r:log('in Frame()')
    for _, track in ipairs(project:get_selected_tracks()) do
        local track_name = track:get_name()
        r:log('track_name', track_name)
        gui:text(track_name)
        for _, fx in ipairs(track:get_fx_chain()) do
            gui:text(fx:get_name())
        end
    end
end


function Menu()
    r:print('in Menu')
    local menu_bar = gui:begin_menu_bar()
    r:log('menu_bar ' .. tostring(menu_bar))
    if  menu_bar then
        if gui:begin_menu('File') then
            if gui:menu_item('Save') then
                r:log('Saving file')
            end
            gui:end_menu()
        end
        gui:end_menu_bar()
    end
end

--local window_flags = reaper.ImGui_WindowFlags_MenuBar() |
--                     reaper.ImGui_WindowFlags_NoDecoration()
--r:print(window_flags)
--loop = gui:loop(Frame, 'My Script', true, window_flags)
--reaper.defer(loop)
--
--

--reaper.ImGui_SetNextWindowPos(ctx, 0, 0)
--reaper.ImGui_SetNextWindowSize(ctx, reaper.ImGui_GetDisplaySize(ctx))
--reaper.ImGui_Begin(ctx, 'Window', nil, window_flags)
--
local ctx = reaper.ImGui_CreateContext('My script')
local size = reaper.GetAppVersion():match('OSX') and 12 or 14
local font = reaper.ImGui_CreateFont('sans-serif', size)
reaper.ImGui_AttachFont(ctx, font)

click_count, text = 0, 'The quick brown fox jumps over the lazy dog'

function frame(ctx)
  local rv

  if reaper.ImGui_Button(ctx, 'Click me!') then
    click_count = click_count + 1
  end

  if click_count % 2 == 1 then
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, 'hello dear imgui!')
  end

  rv, text = reaper.ImGui_InputText(ctx, 'text input', text)
end

loop = gui:loop(frame)
reaper.defer(loop)