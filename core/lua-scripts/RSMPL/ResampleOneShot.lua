
function ConsoleMsg(arg)
    reaper.ShowConsoleMsg(tostring(arg) .. '\n')
end


local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)RSMPL/')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
require('ReaWrap.models')

local r = Reaper:new()
local p = Project:new()


local function copy_track(source_track)
    local color = source_track:get_color()
    local index = source_track:get_index(0)
    local name = source_track:get_name()
    local dest_track = p:add_track(index + 1, false)
    dest_track:set_name(name..' [RESAMPLE]')
    dest_track:set_color(color)
    return dest_track
end

local function copy_track_items(source_track, dest_track)
    for item in source_track:iter_media_items() do
        local state_chunk = item:get_state_chunk()
        state_chunk = state_chunk:gsub("POOLEDEVTS {.-}", "POOLEDEVTS " .. r:guid())
        state_chunk = state_chunk:gsub("IGUID {.-}", "IGUID " .. r:guid())
        state_chunk = state_chunk:gsub("GUID {.-}", "GUID " .. r:guid())
        local new_item = dest_track:add_media_item()
        new_item:set_position(item:get_position())
        new_item:set_length(item:get_length())
        new_item:set_state_chunk(state_chunk)
    end
end

local function bounce_item_in_place(media_item) 
    r:apply_fx()
    for take in media_item:iter_takes() do
        local pcm_source = take:get_pcm_source()
        if pcm_source:get_type() == 'WAVE' then
            return pcm_source:get_filename()
        end
    end
end

local function remove_wave_item(track)
    local todelete
     for item in track:iter_media_items() do
        for take in item:iter_takes() do
            local pcm_source = take:get_pcm_source()
            if pcm_source:get_type() == 'WAVE' then
                todelete = item
            end
        end
     end
     if todelete then
        track:delete_media_item(todelete)
     end
end

local function clean_up(source_track, dest_track)
     -- crop to active take
     r:main_on_command(40131, 0)
     remove_wave_item(source_track)
     remove_wave_item(dest_track)
end



local function add_sampler(dest_track, fname)
    local reas_5000 = dest_track:add_fx_by_name('ReaSamplOmatic5000 (Cockos)')
    reas_5000:set_open()
    r:insert_media(fname, 2048)
end



local function main(opts)
    if p:count_selected_tracks() == 0 then
        r:msg_box('Please select a track', 'Error', 0)
        return
    end
    if p:count_selected_media_items() == 0 then
        r:msg_box('Please select an item', 'Error', 0)
        return
    end
    local sel_track
    for item in p:iter_selected_media_items() do
        local source_track = Track:from_media_item(item)
        if source_track:has_instrument() then
            local dest_track = copy_track(source_track)
            copy_track_items(source_track, dest_track)
            local fname = bounce_item_in_place(item)
            add_sampler(dest_track, fname)
            clean_up(source_track, dest_track)
        else
            r:msg_box('Track has no instrument to resample', 'Error', 0)
        end
    end
end



local no_refresh = r:prevent_refresh()
local undo = r:undo('Render instrument')
no_refresh(undo, main, opts)

