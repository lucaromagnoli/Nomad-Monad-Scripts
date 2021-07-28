--- Implement ResampleTrack class and helper functions.

require('ReaWrap.models')

-- Config

DefaultTag = 'RSMPL'
LSep = '['
RSep = '] '
ResampleTrackPrefix = LSep .. DefaultTag .. RSep
ResampleTrackPrefixEscaped = '%' .. LSep .. DefaultTag .. '%' .. RSep
SourceTrackState = 'SourceTrackState'


-- Get the resample_track mapped to source_track from project key-value store.
local function get_from_key_value(project, source_track)
    local rsmpl_guid = project:get_key_value(DefaultTag, source_track:GUID())
    return project:track_from_guid(rsmpl_guid)
end

-- Create a mapping from source track to resample_track in project key-value store.
local function set_to_key_value(project, source_track, resample_track)
    project:set_key_value(
            DefaultTag, source_track:GUID(), resample_track:GUID(), true
    )
end

-- Whether source_track has a RSMPL track mapped to it in project key-value store.
local function is_in_key_value(project, source_track)
    return project:has_key_value(DefaultTag, source_track:GUID())
end

-- Delete mapping from source track to resample_track in project key-value store.
local function del_from_key_value(project, source_track)
    project:del_key_value(DefaultTag, source_track:GUID(), true)
end


-- Save source_track state in project key-value store.
local function set_source_track_state(project, source_track)
    project:set_key_value(
            SourceTrackState,
            source_track:GUID(),
            source_track:get_state_chunk().raw,
            true
    )
end

ResampleTrack = Track:new()

-- @return ResampleTrack
function ResampleTrack:new(media_track --[[userdata]], source_track --[[Track]])
    local o = {
        media_track = media_track,
        source_track = source_track,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function ResampleTrack:__tostring()
    return string.format(
            '<ResampleTrack Name=%s, SourceTrack=%s>',
            self:get_name(),
            self.source_track:get_name()
    )
end

function ResampleTrack:new_from_source_track(project, source_track)
    local color = source_track:get_color()
    local index = source_track:get_index(0)
    local name = ResampleTrackPrefix .. source_track:get_name()
    local track = project:add_track(index + 1, false)
    track:set_name(name)
    track:set_color(color)
    local rsmpl_track = self:new(track.media_track, source_track)
    local send = source_track:create_send(rsmpl_track)
    send:set_info_value(SendReceiveInfoValue.I_MIDIFLAGS, 0) -- send MIDI
    send:set_info_value(SendReceiveInfoValue.I_SENDMODE, 3) -- pre fader
    source_track:set_info_value(TrackInfoValue.B_MAINSEND, 0) -- Disable audio to parent
    rsmpl_track:set_info_value(TrackInfoValue.I_RECMODE, 3) -- stereo input w latency compensation
    return rsmpl_track
end

local function move_fx_chain(source_track, rsmpl_track, fx_index)
    fx_index = fx_index or 1
    local fx_count = source_track:get_fx_count()
    while fx_count > fx_index do
        local fx = TrackFX:new(source_track, fx_count - 1)
        fx:move_to_track(rsmpl_track, 0)
        fx_count = fx_count - 1
    end
end

local function unlink_from_rsmpl_track(project, track, rsmpl_track)
    local rsmpl_name = rsmpl_track:get_name()
    local new_name = string.gsub(rsmpl_name, ResampleTrackPrefixEscaped, '')
    rsmpl_track:set_name(new_name)
    del_from_key_value(project, track)
end

local function rsmpl_track_dialogue(rsmpl_track)
    local title = string.format(
            'Selected track is already linked to a RSMPL track - %s',
            rsmpl_track:get_name()
    )
    local msg = [[
        'Would you you like to unlink it and link it to a new one?'
    ]]
    return msg_box(msg, title, MsgBoxTypes.OKCANCEL)
end

-- @return boolean
local function check_rsmpl_track(project, source_track)
    if is_in_key_value(project, source_track) then
        -- create resample track instance to get track name
        local rsmpl_track = get_from_key_value(project, source_track)
        if not rsmpl_track:is_valid() then
            del_from_key_value(project, source_track)
            return true
        else
            local confirm = rsmpl_track_dialogue(rsmpl_track)
            if confirm == MsgBoxReturnTypes.OK then
                unlink_from_rsmpl_track(project, source_track, rsmpl_track)
                return true
            else
                return false
            end
        end
    end
    return true
end

-- Create a table of RSMPLTrack from currently selected tracks.
-- @return Table<RSMPLTrack>
function create_resample_tracks(project, fx_index)
    local resample_tracks = {}
    for source_track in project:iter_selected_tracks() do
        if check_rsmpl_track(project, source_track) then
            set_source_track_state(project, source_track)
            local resample_track = ResampleTrack:new_from_source_track(project, source_track)
            move_fx_chain(source_track, resample_track, fx_index)
            set_to_key_value(project, source_track, resample_track)
            resample_tracks[#resample_tracks + 1] = resample_track
        end
    end
    return resample_tracks
end

-- Render instrument on source_track and move it to resample_track.
-- @reawrap ReaWrap.Reaper : named reawrap to avoid clash with global reaper
-- @project ReaWrap.Project
-- @return Table<RSMPLTrack>
function render_to_resample_track(reawrap, project)
    for item in project:iter_selected_items() do
        local source_track = item:get_track()
        if is_in_key_value(project, source_track) then
            local rsmpl_track = get_from_key_value(project, source_track)
            reawrap:apply_fx()
            item:move_to_track(rsmpl_track)
        end
    end
end
