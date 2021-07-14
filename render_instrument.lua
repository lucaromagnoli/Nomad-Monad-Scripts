-- @description Render virtual instrument to a new take
-- @author NomadMonad
-- @version 0.1a
--
local r = reaper

local function msg(str)
    r.ShowConsoleMsg(str .. '\n')
end

function FXIsInstrument(first_inst_idx, fx_idx, fx_name)
    if first_inst_idx == fx_idx then
        return true
    end
    local patterns = {'VSTi', 'VST3i', 'AUi'}
    for _, p in pairs(patterns) do
        if fx_name:find(p) then
            return true
        end
    end
    return false
end

FX = {
    name = nil,
    is_enabled = true,
    is_offline = false,
    is_instrument = false,
}

function FX:new(o)
    o  = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function FX:tostring()
    return string.format(
        'FX <name=%s, is_instrument=%s, is_enabled=%s, is_offline=%s>',
        self.name,
        self.is_instrument,
        self.is_enabled,
        self.is_offline
    )
end


Track = {
    media_track = nil,
    fx_chain = {},
    has_instrument = false
}


function Track:new(media_track)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self.media_track = media_track
    self:set_fx_chain()
    return o
  end

function Track:set_fx_chain()
    local fx_count = r.TrackFX_GetCount(self.media_track)
    for fx_idx = 0, fx_count - 1 do
        local _, name = r.TrackFX_GetFXName(self.media_track, fx_idx, '')
        local is_enabled = r.TrackFX_GetEnabled(self.media_track, fx_idx)
        local is_offline = r.TrackFX_GetOffline(self.media_track, fx_idx)
        local first_inst_idx = r.TrackFX_GetInstrument(self.media_track)
        local is_instrument=FXIsInstrument(first_inst_idx, fx_idx, name)
        if is_instrument then
            self.has_instrument = true
        end
        local fx = FX:new({
            idx = fx_idx,
            name = name,
            is_enabled=is_enabled,
            is_offline=is_offline,
            is_instrument=is_instrument
        })
        self.fx_chain[fx_idx] = fx
    end
end

function Track:disable_all_fx()
    for i, fx in pairs(self.fx_chain) do
        if (not fx.is_instrument) then
            r.TrackFX_SetEnabled(self.media_track, i, false)
        end
    end
end

function Track:state_reload()
    for i, fx in pairs(self.fx_chain) do
        if (not fx.is_instrument) then
            r.TrackFX_SetEnabled(self.media_track, i, fx.is_enabled)
        end
    end
end

r.Undo_BeginBlock(1)
r.PreventUIRefresh(1)

if r.CountSelectedMediaItems(0) == 0 then
    r.MB('Please select an item', 'Error', 0)
    return
end
local sel_media_track = r.GetSelectedTrack(0, 0)
local sel_track = Track:new(sel_media_track)
if not sel_track.has_instrument then
    r.MB('Track has no virtual instrument', 'Error', 0)
    return
end
sel_track:disable_all_fx()
r.Main_OnCommand(40209, 0)
sel_track:state_reload()

r.PreventUIRefresh(-1)
r.Undo_EndBlock('Apply to stereo take', -1)
