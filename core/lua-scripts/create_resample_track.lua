-- @description Create new RSMPL Track from selected tracks
-- @author NomadMonad
-- @version 0.1a

local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = package.path .. ';' .. path .. '?.lua'
package.path = package.path .. ';' .. path .. 'ReaWrap/models/?.lua'
require('ReaWrap.models')

DefaultTag = 'RSMPL'
LSep = '['
RSep = ']'
ResampleTrackPrefix = LSep .. DefaultTag .. RSep
ResampleTrackPrefixEscaped = '%'.. LSep .. DefaultTag .. '%' .. RSep

local r = Reaper:new()
local p = Project:new()

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


function ResampleTrack:from_source_track(project, source_track)
    local color = source_track:get_color()
    local index = source_track:get_index()
    local name = ResampleTrackPrefix .. source_track:get_name()
    local track = project:add_track(index, false)
    track:set_name(name)
    track:set_color(color)
    local rsmpl = self:new(track.media_track, source_track)
    project:set_key_value(DefaultTag, source_track:GUID(), rsmpl:GUID(), true)
    return rsmpl
end

local function get_inst_and_fx(track)
    local instruments = {}
    local audio_fx = {}
    for fx in track:iter_fx_chain() do
        if fx:is_instrument() then
            instruments[#instruments + 1] = fx
        else
            audio_fx[#audio_fx + 1] = fx
        end
    end
    return instruments, audio_fx
end

local function move_fx_chain(source_track, rsmpl_track, index)
    index = index or 1
    local fx_count = source_track:get_fx_count()
    while  fx_count > index do
        local fx = TrackFX:new(source_track, fx_count - 1)
        fx_count = fx_count - 1
        fx:move_to_track(rsmpl_track, 0)
    end
end


local function get_rsmpl_track(project, track)
    local rsmpl_guid = project:get_key_value(DefaultTag, track:GUID())
    return project:track_from_guid(rsmpl_guid)
end


local function has_rsmpl_track(project, track)
    return project:has_key_value(DefaultTag, track:GUID())
end


local function del_rsmpl_track(project, track)
    project:del_key_value(DefaultTag, track:GUID(), true)
end


local function unlink_from_rsmpl_track(project, track, rsmpl_track)
    local rsmpl_name = rsmpl_track:get_name()
    local new_name = string.gsub(rsmpl_name, ResampleTrackPrefixEscaped, '')
    rsmpl_track:set_name(new_name)
    del_rsmpl_track(project, track)
end


local function rsmpl_track_dialogue(rsmpl_track)
    local title = string.format(
            'Selected track is already linked to a RSMPL track - %s',
            rsmpl_track:get_name()
    )
    local msg = [[
        'Would you you like to unlink it and link it to a new one?'
    ]]
    return r:msg_box(msg, title, MsgBoxTypes.OKCANCEL)
end

-- @return boolean
local function check_rsmpl_track(project, source_track)
    if has_rsmpl_track(project, source_track) then
            -- create resample track instance to get track name
        local rsmpl_track = get_rsmpl_track(project, source_track)
        if not rsmpl_track:is_valid() then
            del_rsmpl_track(project, source_track)
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
--@return Table<RSMPLTrack>
local function create_rsmpl_tracks(project, index)
    local resample_tracks = {}
    for source_track in project:iter_selected_tracks() do
        if check_rsmpl_track(project, source_track) then
            local resample_track = ResampleTrack:from_source_track(project, source_track)
            move_fx_chain(source_track, resample_track, index)
            resample_tracks[#resample_tracks + 1] = resample_track
        end
    end
    return resample_tracks
end


local function main(opts)
    if not p:has_selected_tracks()
        then r:msg_box('Please select a track', 'No track selected')
        return
    end
    for _, rsmpl in ipairs(create_rsmpl_tracks(p)) do
        r:print(rsmpl)
    end
end

local no_refresh = r:prevent_refresh()
local undo = r:undo('Create Resample Track')
no_refresh(undo, main, opts)
