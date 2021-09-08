-- @description Create new RSMPL Track from selected tracks
-- @author NomadMonad
-- @version 0.1a
local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)RSMPL/')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
require('ReaWrap.models')
require('RSMPL.resample')


local r = Reaper:new()
local p = Project:new()

local function main(opts)
    local source_track
    local midi_take
    if not p:has_selected_media_items()
    then
        r:msg_box('Please select an item', 'No item selected')
        return
    end
    for media_item in p:iter_selected_media_items() do
        midi_take = get_midi_take_to_render(media_item)
        if midi_take == nil then
            r:msg_box('No MIDI take in item', 'RSMPL Error')
            return
        else
            source_track = Track:from_media_item(media_item)
            local has_valid_rsmpl = SourceTrackHasValidRsmplTrack(p, source_track)
            if not has_valid_rsmpl then
                local confirm = msg_box(
                        'Would you like to create a new one?',
                        'No RSMPL track associated to sample track',
                        MsgBoxTypes.OKCANCEL
                )
                if confirm == MsgBoxReturnTypes.OK then
                    create_resample_track(p, source_track)
                else
                    return
                end
            end
        end
        render_to_resample_track(r, p, source_track, media_item, midi_take)
    end
end

local no_refresh = r:prevent_refresh()
local undo = r:undo('Render to Resample Track')
no_refresh(undo, main, opts)
