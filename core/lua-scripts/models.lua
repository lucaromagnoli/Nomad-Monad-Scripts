-- @description OOP Implementation of Reaper API
-- @version 0.1
-- @author NomadMonad

local r = reaper

local function msg(object)
    r.ShowConsoleMsg(tostring(object) .. '\n')
end


local function log(...)
    local joined = ''
    for _, v in ipairs(arg) do
        if joined then
            joined = joined .. ', ' .. tostring(v)
        else
            joined = tostring(v)
        end
        msg(joined)
    end
end

DEBUG = true

-- FX
FX = {
    track = nil,
    idx = nil
}

function FX:new(track, idx)
    local o = {
        track = track,
        idx = idx
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function FX:__tostring()
    return string.format(
        'FX <idx=%s, name=%s, is_instrument=%s, is_enabled=%s, is_offline=%s>',
        self.idx,
        self:get_name(),
        self:is_instrument(),
        self:is_enabled(),
        self:is_offline()
    )
end

function FX:delete()
    -- Delete FX
    r.TrackFX_Delete(self.track.media_track, self.idx)
end


function FX:get_name()
    -- Get FX Name
    -- @return string
    local retval, name = r.TrackFX_GetFXName(self.track.media_track, self.idx, '')
    if retval then
        return name
    else
        return nil
    end
end

function FX:is_enabled()
    -- Whether FX is enabled
    -- @return boolean
    return r.TrackFX_GetEnabled(self.track.media_track, self.idx)
end

function FX:is_offline()
    -- Whether FX is offline
    -- @return boolean
    return r.TrackFX_GetOffline(self.track.media_track, self.idx)
end

function FX:is_instrument()
    -- Whether FX is a virtual instrument
    -- @return boolean
    local inst_idx = r.TrackFX_GetInstrument(self.track.media_track)
    if inst_idx == -1 then
        return false
    elseif inst_idx == self.idx then
        return true
    end
    local patterns = {'VSTi', 'VST3i', 'AUi'}
    local name = self:get_name()
    for _, p in pairs(patterns) do
        if name:find(p) then
            return true
        end
    end
    return false
end

function FX:set_enabled(enabled)
    -- Set FX Enable
    r.TrackFX_SetEnabled(self.track.media_track, self.idx, enabled)
end

function FX:enable()
    -- Enable FX
    self:set_enabled(true)
end

function FX:disable()
    -- Disable FX
    self:set_enabled(false)
end

function FX:get_guid()
    return r.TrackFX_GetFXGUID(self.track.media_track, self.idx)
end


function FX:set_key_value(key, value, persist)
    -- Save the current state of fx
    msg('in set_key_value')
    msg(self:get_guid())
    r.SetExtState(self:get_guid(), key, value, persist)
end

function FX:get_key_value(key)
    -- Save the current state of fx
    msg('in get_key_value')
    msg(self:get_guid())
    return r.GetExtState(self:get_guid(), key)
end


-- Track
Track = {
    media_track = nil,
}

function Track:new(media_track)
    local o = {media_track = media_track}
    setmetatable(o, self)
    self.__index = self
    return o
  end

function Track:__tostring()
    return string.format(
        'Track <name=%s>',
        self:get_name()
    )
end

function Track:get_name()
    -- get track name
    -- @return string
    local _, name = r.GetTrackName(self.media_track)
    return name
end

function Track:fx_count()
    -- get the total number of FX for a given track
    -- @return number
    return r.TrackFX_GetCount(self.media_track)
end

function Track:get_guid()
    -- get guid
    -- @return string
    return r.GetTrackGUID(self.media_track)
end

function Track:get_fx_chain()
    -- get all FX for a given track
    -- @return table
    local fx_chain = {}
    for fx_idx = 0, self:fx_count() - 1 do
        local fx = FX:new(self, fx_idx)
        -- if DEBUG then
        --     log('get_fx_chain()', fx)
        -- end
        fx_chain[fx_idx + 1] = fx
    end
    return fx_chain
end

function Track:has_instrument()
    for _, fx in ipairs(self:get_fx_chain()) do
        if fx:is_instrument() then
            return true
        end
    end
    return false
end

-- Project
Project = {}
