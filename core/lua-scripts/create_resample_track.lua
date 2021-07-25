-- @description Create new RSMPL Track from selected tracks
-- @author NomadMonad
-- @version 0.1a

DEBUG = true

local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

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
    local track = project:add_track(index, true)
    track:set_name(name)
    track:set_color(color)
    local rsmpl = self:new(track.media_track, source_track)
    project:set_key_value(DefaultTag, source_track:GUID(), rsmpl:GUID(), true)
    return rsmpl
end

local function copy_fx_chain(source_track, rsmpl_track, index)
    index = index or 1
    instruments, audio_fx = get_inst_and_fx(track)
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
    return true
end

local function unlink_from_rsmpl_track(project, track, rsmpl_track)
    local rsmpl_name = rsmpl_track:get_name()
    local new_name = string.gsub(rsmpl_name, ResampleTrackPrefixEscaped, '')
    rsmpl_track:set_name(new_name)
    return del_rsmpl_track(project, track)
end

local function rsmpl_track_dialogue(rsmpl_track)
    local title = string.format(
            'Selected track is already linked to a RSMPL track - %s',
            rsmpl_track:get_name()
    )
    local msg = [[
        'Would you you like to unlink it and link it to a new one?'
    ]]
    return r:msg_box(msg, title, 1)
end

-- @return boolean
local function check_rsmpl_track(project, source_track)
    if has_rsmpl_track(project, source_track) then
            -- create resample track instance to get track name
        local rsmpl_track = get_rsmpl_track(project, source_track)
        if not rsmpl_track:is_valid() then
            return del_rsmpl_track(project, source_track)
        else
            local confirm = rsmpl_track_dialogue(rsmpl_track)
            if  confirm then
                return unlink_from_rsmpl_track(project, source_track, rsmpl_track)
            else
                return confirm
            end
        end
    end
    return true
end

-- Create a table of RSMPLTrack from currently selected tracks.
--@return Table<RSMPLTrack>
local function get_rsmpl_tracks(project)
    local resample_tracks = {}
    local resp = 1
    for i, source_track in ipairs(project:get_selected_tracks()) do
        if check_rsmpl_track(project, source_track) then
            local resample_track = ResampleTrack:from_source_track(project, source_track)
            resample_tracks[i] = resample_track
        end
    end
    return resample_tracks
end


local function main(opts)
    for _, rsmpl in ipairs(get_rsmpl_tracks(p)) do
        r:print(rsmpl)
    end
end

local no_refresh = r:prevent_refresh()
local undo = r:undo('Create Resample Track')
no_refresh(undo, main, opts)
