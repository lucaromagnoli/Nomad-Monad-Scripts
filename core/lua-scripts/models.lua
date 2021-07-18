-- @description OOP Implementation of Reaper API
-- @version 0.1
-- @author NomadMonad

local r = reaper

-- FX
FX = {
    idx = nil,
    media_track = nil
}

function FX:new(media_track, idx)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self.media_track = media_track
    self.idx = idx
    return o
end

function FX:__tostring()
    return string.format(
        'FX <name=%s, is_instrument=%s, is_enabled=%s, is_offline=%s>',
        self:get_name(),
        self:is_enabled(),
        self:is_instrument(),
        self:is_offline()
    )
end

function FX:delete()
    -- Delete FX
    r.TrackFX_Delete(self.media_track, self.idx)
end


function FX:get_name()
    -- Get FX Name
    -- @return string
    return r.TrackFX_GetFXName(self.media_track, self.idx, '')
end

function FX:is_enabled()
    -- Whether FX is enabled
    -- @return boolean
    return r.TrackFX_GetEnabled(self.media_track, self.idx)
end

function FX:is_offline()
    -- Whether FX is offline
    -- @return boolean
    return r.TrackFX_GetOffline(self.media_track, self.idx)
end

function FX:is_instrument()
    -- Whether FX is a virtual instrument
    -- @return boolean
    if r.TrackFX_GetInstrument(self.media_track) == self.idx then
        return true
    end
    local patterns = {'VSTi', 'VST3i', 'AUi'}
    for _, p in pairs(patterns) do
        if self.get_name():find(p) then
            return true
        end
    end
    return false
end

function FX:enable()
    -- Enable FX
    r.TrackFX_SetEnabled(self.media_track, self.idx, true)
end

function FX:disable()
    -- Disable FX
    r.TrackFX_SetEnabled(self.media_track, self.idx, false)
end

-- Track
Track = {
    media_track = nil
}

function Track:new(media_track --[[MediaTrack]])
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self.media_track = media_track
    self:set_fx_chain()
    return o
  end

function Track:__tostring()
    return string.format(
        'Track <name=%s>',
        self:get_name(),
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

function Track:get_fx_chain()
    -- get all FX for a given track
    -- @return table
    local fx_chain = {}
    for fx_idx = 0, self.fx_count() - 1 do
        local fx = FX:new({
            idx = fx_idx,
            media_track = self.media_track
        })
        fx_chain[fx_idx] = fx
    end
    return fx_chain
end

function Track:disable_all_fx(include_inst --[[boolean]])
    -- disable all FX for a given track
    -- @param include_inst: whether to disable instruments
    for _, fx in pairs(self.get_fx_chain()) do
        if include_inst then
            fx:disable()
        elseif not fx.is_instrument() then
            fx:disable()
        end
    end
end

-- Project
Project = {}
