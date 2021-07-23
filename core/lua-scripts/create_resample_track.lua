-- @description Create new RSMPL Track from selected tracks
-- @author NomadMonad
-- @version 0.1a

DEBUG = true

local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

require('models')

local r = Reaper:new()

ResampleTrack = Track:new()

-- @return ResampleTrack
function ResampleTrack:new(media_track --[[userdata]], source --[[Track]])
    local o = {
        media_track = media_track,
        source = source,
    }
    setmetatable(o, self)
    self.__index = self
    return o
  end

function ResampleTrack:__tostring()
    return string.format(
        '<ResampleTrack Name=%s, SourceTrack=%s>',
        self:get_name(),
        self.string
    )
end

function ResampleTrack:from_source_track(source_track, project)
    local color = source_track:get_color()
    local index = source_track:get_index()
    local name = '[RSMPL] ' .. source_track:get_name()
    local track = project:add_track(index, true)
    track:set_name(name)
    track:set_color(color)
    local rsmpl = self:new(track.media_track, source_track)
    project:set_key_value('RSMPL', source_track:GUID(), rsmpl:GUID(), true)
    return rsmpl
end

local function get_rsmpl_track(project, track)
    local rsmpl_guid = project:get_key_value('RSMPL', track:GUID())
    return project:track_from_guid(rsmpl_guid)
end

local function has_rsmpl_track(project, track)
    return project:has_key_value('RSMPL', track:GUID())
end

local function unlink_from_rsmpl_track(project, track)
    project:del_key_value('RSMPL', track:GUID(), true)
end

local function copy_fx_chain()
end


--@return Table{ResampleTrack}
local function from_selected_tracks(project)
    local resample_tracks = {}
    local resp = 1
    for _, source_track in ipairs(project:get_selected_tracks(false)) do
        if has_rsmpl_track(project, source_track) then
            local rsmpl_track = ResampleTrack:from_source_track(source_track, project)
            local title = string.format(
                'Track is already linked to a RSMPL track - %s',
                rsmpl_track:get_name()
            )
            local msg = [[
                'Would you you like to unlink it from current RSMPL track and link it to a new one?'
            ]]
            resp = r:msg_box(msg, title, 1)
            if resp == 1 then
                rsmpl_track:set_name()
                unlink_from_rsmpl_track(project, source_track)
            end
        end
        if resp == 1 then
            local resample_track = ResampleTrack:new()
            resample_tracks[#resample_tracks+1] = resample_track
        end
    end
    return resample_tracks
end


local function main()
    local p = Project:new()
    for _, rsmpl in ipairs(from_selected_tracks(p)) do
        r:print(rsmpl)
    end
end

main()
