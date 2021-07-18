-- @description OOP Implementation of Reaper API
-- @version 0.1
-- @author NomadMonad

local r = reaper

local function msg(object)
    r.ShowConsoleMsg(tostring(object) .. '\n')
end


-- FX
FX = {
    media_track = nil,
    idx = nil
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
    r.TrackFX_Delete(self.media_track, self.idx)
end


function FX:get_name()
    -- Get FX Name
    -- @return string
    local retval, name = r.TrackFX_GetFXName(self.media_track, self.idx, '')
    if retval then
        return name
    else
        return nil
    end
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
    local inst_idx = r.TrackFX_GetInstrument(self.media_track)
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

function FX:enable()
    -- Enable FX
    r.TrackFX_SetEnabled(self.idx, true)
end

function FX:disable()
    -- Disable FX
    r.TrackFX_SetEnabled(self.idx, false)
end

-- Track
Track = {
    media_track = nil,
    fx_chain = {}
}

function Track:new(media_track)
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

function Track:set_fx_chain()
    -- get all FX for a given track
    -- @return table
    msg('in get_fx_chain')
    local fx_chain = {}
    local fx_count = self:fx_count()
    msg('self fx_count' .. fx_count)
    for fx_idx = 0, fx_count - 1 do
        self.fx_chain[fx_idx + 1] = FX:new(self.media_track, fx_idx)
    end
end

function Track:get_fx_chain()
    return self.fx_chain
end

function Track:has_instrument()
    for _, fx in ipairs(self.get_fx_chain()) do
        if fx:is_instrument() then
            return true
        end
    end
    return false
end

function Track:disable_all_fx(include_inst --[[boolean]])
    -- disable all FX for a given track
    -- @param include_inst: whether to disable instruments
    for _, fx in pairs(self.get_fx_chain()) do
        if include_inst then
            fx:disable()
        elseif not fx:is_instrument() then
            fx:disable()
        end
    end
end

-- Project
Project = {}
