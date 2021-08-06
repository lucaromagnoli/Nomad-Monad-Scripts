--- Implement ResampleTrack class and helper functions.

require('ReaWrap.models')

-- Config

DefaultTag = 'RSMPL'
LSep = '['
RSep = ']'
ResampleTrackPrefix = LSep .. DefaultTag .. RSep
ResampleTrackPrefixEscaped = '%' .. LSep .. DefaultTag .. '%' .. RSep .. ' '
SourceTrackState = 'SourceTrackState'

local r = Reaper:new()

-- Get the resample_track mapped to source_track from project key-value store.
function GetRsmplFromKeyValue(project, source_track)
    local rsmpl_guid = project:get_key_value(DefaultTag, source_track:GUID())
    local dest_track = project:track_from_guid(rsmpl_guid)
    return ResampleTrack:new(dest_track, source_track)
end

-- Create a mapping from source track to resample_track in project key-value store.
function SetRsmplToKeyValue(project, source_track, resample_track)
    project:set_key_value(
            DefaultTag, source_track:GUID(), resample_track:GUID(), true
    )
end

-- Whether source_track has a RSMPL track mapped to it in project key-value store.
function IsRsmplInKeyValue(project, source_track)
    return project:has_key_value(DefaultTag, source_track:GUID())
end

-- Delete mapping from source track to resample_track in project key-value store.
function DelRsmplFromKeyValue(project, source_track)
    project:del_key_value(DefaultTag, source_track:GUID(), true)
end


-- Save source_track state in project key-value store.
function SetSourceTrackState(project, source_track)
    project:set_key_value(
            SourceTrackState,
            source_track:GUID(),
            source_track:get_state_chunk().raw,
            true
    )
end


function BypassFxChain(fx_chain)
    for _, fx in ipairs(fx_chain) do
        if not fx:is_instrument() then
            local is_enabled = tostring(fx:is_enabled())
            fx:set_key_value('is_enabled', is_enabled, false)
            fx:disable()
        end
    end
end

function reload_fx_chain_state(fx_chain)
    for _, fx in ipairs(fx_chain) do
        if not fx:is_instrument() then
            local old_state = fx:get_key_value('is_enabled') == 'true'
            fx:set_enabled(old_state)
        end
    end
end

function bypass_render_reload(track, fx_index)
    local fx_chain = track:get_fx_chain()
    BypassFxChain(fx_chain, fx_index)
    r:apply_fx()
    reload_fx_chain_state(fx_chain, fx_index)
end

ResampleTrack = Track:new()
---@param dest_track userdata MediaItemTrack pointer
---@param source_track table Track
---@return table ResampleTrack
function ResampleTrack:new(dest_track --[[Track]], source_track --[[Track]])
    local o = {
        pointer = dest_track.pointer,
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
    local dest_track = project:add_track(index + 1, false)
    dest_track:set_name(name)
    dest_track:set_color(color)
    local rsmpl_track = self:new(dest_track, source_track)
    local send = source_track:create_send(rsmpl_track)
    send:set_info_value(SendReceiveInfoValue.I_MIDIFLAGS, 0) -- send MIDI
    send:set_info_value(SendReceiveInfoValue.I_SENDMODE, 3) -- pre fader
    source_track:set_info_value(TrackInfoValue.B_MAINSEND, 0) -- Disable audio to parent
    rsmpl_track:set_info_value(TrackInfoValue.I_RECMODE, 3) -- stereo input w latency compensation
    return rsmpl_track
end

function SourceTrackHasValidRsmplTrack(project, source)
    if IsRsmplInKeyValue(project, source) then
        local rsmpl = GetRsmplFromKeyValue(project, source)
        if rsmpl:is_valid() then
            return true
        end
    end
    return false
end

---Get send from source to resample_track
---@param resample_track
function get_resample_track_send(resample_track)
    for send in resample_track.source_track:iter_sends() do
        if send:get_name() == resample_track:get_name() then
            return send
        end
    end
end

function move_fx_chain(source_track, rsmpl_track, fx_index)
    fx_index = fx_index or 1
    local fx_count = source_track:get_fx_count()
    while fx_count > fx_index do
        local fx = TrackFX:new(source_track, fx_count - 1)
        fx:move_to_track(rsmpl_track, 0)
        fx_count = fx_count - 1
    end
end

function unlink_from_rsmpl_track(project, track, rsmpl_track)
    local rsmpl_name = rsmpl_track:get_name()
    local new_name = string.gsub(rsmpl_name, ResampleTrackPrefixEscaped, '')
    rsmpl_track:set_name(new_name)
    DelRsmplFromKeyValue(project, track)
end

function rsmpl_track_dialogue(rsmpl_track)
    local title = string.format(
            'Selected track is already linked to a RSMPL track - %s',
            rsmpl_track:get_name()
    )
    local msg = [[
        'Would you you like to unlink it and link it to a new one?'
    ]]
    return msg_box(msg, title, MsgBoxTypes.OKCANCEL)
end

---@return boolean
function check_rsmpl_track(project, source_track)
    if IsRsmplInKeyValue(project, source_track) then
        -- create resample track instance to get track name
        local rsmpl_track = GetRsmplFromKeyValue(project, source_track)
        if not rsmpl_track:is_valid() then
            DelRsmplFromKeyValue(project, source_track)
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


---@return table ResampleTrack
function create_resample_track(project, source_track, fx_index)
    if check_rsmpl_track(project, source_track) then
        SetSourceTrackState(project, source_track)
        local rsmpl_track = ResampleTrack:new_from_source_track(project, source_track)
        move_fx_chain(source_track, rsmpl_track, fx_index)
        SetRsmplToKeyValue(project, source_track, rsmpl_track)
        return rsmpl_track
    end
end

function get_midi_take_to_render(media_item)
    local takes = media_item:get_takes()
    local midi_take = takes[#takes]
    local source_type =  midi_take:get_pcm_source():get_type()
    if source_type == 'MIDI' then
        return midi_take
    end
end


---Render instrument on source_track and move it to resample_track.
---@param reawrap table ReaWrap.Reaper : named reawrap to avoid clash with global reaper
---@param project table ReaWrap.Project
---@return table RSMPLTrack
function render_to_resample_track(reawrap, project, source_track, media_item, midi_take)
    local midi_take_name = midi_take:get_name()
    local rsmpl_track = GetRsmplFromKeyValue(project, source_track)
    -- new empty item
    local rsmpl_item = rsmpl_track:add_media_item()
    item_position = media_item:get_position(false)
    item_length = media_item:get_length(false)
    rsmpl_item:set_position(item_position)
    rsmpl_item:set_length(item_length)
    -- save media_item state
    previous_state = media_item:get_state_chunk()
    media_item:set_info_string(
            MediaItemInfoString.P_EXT..':state',
            previous_state
    )
    -- render to new take
    reawrap:apply_fx()
    takes = media_item:get_takes()
    local last_take = takes[#takes]
    local pcm_source = last_take:get_pcm_source()
    if pcm_source:get_type() ~= 'WAVE' then
        reawrap:msg_box('No media item take', 'RSMPL Error')
    end
    -- copy take to rsmpl
    local rsmpl_take = rsmpl_item:add_take()
    rsmpl_take:set_pcm_source(pcm_source)
    local rsmpl_take_name = ResampleTrackPrefix .. ' ' .. midi_take_name
    rsmpl_take:set_name(rsmpl_take_name)
    -- reload media item state and set send volume to 0
    media_item:set_state_chunk(previous_state)
    src_to_rsmpl_snd = get_resample_track_send(rsmpl_track)
    send_env = src_to_rsmpl_snd:get_envelope(EnvelopeType.volume)
    send_env:add_points_around_edges(item_position, item_position + item_length)
end
