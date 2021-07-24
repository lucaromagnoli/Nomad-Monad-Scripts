-- @description OOP Implementation of Reaper API
-- @version 0.1
-- @author NomadMonad
local r = reaper

DEBUG = true

Sep = ', '

Reaper = {}

function Reaper:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Reaper:__tostring()
    return 'ReaLoop - Lua OOP ReaScript library'
end

function Reaper:console_msg(arg)
    r.ShowConsoleMsg(tostring(arg) .. '\n')
end

--[[
    type 0=OK,1=OKCANCEL,2=ABORTRETRYIGNORE,3=YESNOCANCEL,4=YESNO,5=RETRYCANCEL
    ret 1=OK,2=CANCEL,3=ABORT,4=RETRY,5=IGNORE,6=YES,7=NO
]]--
function Reaper:msg_box(msg, title, type)
    return r.ShowMessageBox(msg, title, type)
end

-- Generate GUID
-- @return string
function Reaper:GUID()
    return r.genGuid('')
end

--[[
    Print message(s) to Reaper console.
    Accepts a variable number of arguments that will be printed as a comma
    separated string.
--]]
-- @{...} string
function Reaper:print(...)
    local joined = ''
    for i, v in ipairs({ ... }) do
        if i == 1 then
            joined = v
        else
            joined = joined .. self.sep .. v
        end
    end
    self:console_msg(joined)
end

--[[
    Log messages(s) to Reaper console.
    Accepts a variable number of arguments that will be logged as a
    timestamped comma separated string.
--]]
-- @... variable number of arguments
function Reaper:log(...)
    self.sep = ' --- '
    self:print(os.date(), ...)
end

-- Execute action id
function Reaper:action(command, flag)
    r.Main_OnCommand(command, flag)
end

-- Apply Track/Take FX to selected item.
--[[
    @opt number
        Accepted values:
        0 = stereo output (default)
        1 = mono output
        2 = multi output
        3 = MIDI
--]]
function Reaper:apply_fx(opt)
    opt = opt or 0
    if opt == 0 then
        self:action(40209, 0) -- stereo output
    elseif opt == 1 then
        self:action(40361, 0) -- mono output
    elseif opt == 2 then
        self:action(41993, 0) -- multi output
    elseif opt == 3 then
        self:action(40436, 0) -- MIDI output
    end
end

-- Execute function within an undo block
-- @description : string : a description of the action to undo
-- @func : the function to call
-- @... : variable number of arguments to func
function Reaper:undo(description, func, ...)
    r.Undo_BeginBlock()
    func(...)
    r.Undo_EndBlock(description, -1)
end


function Reaper:defer(func)
    r.defer(func)
end

ReaLoopBaseModel = {}

function ReaLoopBaseModel:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ReaLoopBaseModel:log(...)
    Reaper:log(...)
end


-- Project

Project = ReaLoopBaseModel:new()

-- Create new Project instance.
function Project:new(o)
    o = o or { active = 0 }
    setmetatable(o, self)
    self.__index = self
    return o
end

function Project:__tostring()
    return string.format('<Project name=%s>', self:get_name())
end

-- Get project name.
-- @return string
function Project:get_name()
    return r.GetProjectName(self.active, '')
end

-- Get track by track count index.
-- @return Track
function Project:get_track(idx --[[number]])
    local media_track = r.GetTrack(self.active, idx)
    return Track:new(media_track)
end

-- Count selected tracks.
-- @return number
function Project:count_selected_tracks(master --[[boolean]])
    return r.CountSelectedTracks2(self.active, master)
end

-- Get selected track by selected count index.
--[[
    @obj Table
        accepted value: {idx = number}. Default {idx = 0}
--]]
-- @return Track
function Project:get_selected_track(obj)
    obj = obj or { idx = 0 }
    local media_track = r.GetSelectedTrack(self.active, obj.idx)
    return Track:new(media_track)
end

-- Get all selected media tracks.
--[[
    @obj Table
        accepted value:{master = true} (include master track, default false).
--]]
-- @return Table<MediaTrack>
function Project:get_selected_tracks(obj)
    obj = obj or { master = false }
    local tracks = {}
    local count = self:count_selected_tracks(obj.master)
    for i = 0, count - 1 do
        local track = self:get_selected_track({ idx = i })
        tracks[i + 1] = track
    end
    return tracks
end

-- Add track to project ad return it.
-- @idx number
-- @defaults boolean
-- @return Track
function Project:add_track(idx, defaults)
    r.InsertTrackAtIndex(idx, defaults)
    return self:get_track(idx)
end

-- Create new track from GUID.
-- @guid string
function Project:track_from_guid(guid)
    local track = r.BR_GetMediaTrackByGUID(self.active, guid)
    return Track:new(track)
end

-- Count selected media items
-- @return number
function Project:count_selected_media_items()
    return r.CountSelectedMediaItems(self.active)
end

-- Get selected media item by count index
-- @idx number
-- @return MediaItem
function Project:get_selected_media_item(idx --[[number]])
    local sel_item = r.GetSelectedMediaItem(self.active, idx)
    return MediaItem:new(sel_item)
end

-- Get all selected media items
-- @return Table<MediaItem>
function Project:get_selected_media_items()
    local selected_media_items = {}
    for i = 0, self:count_selected_media_items() - 1 do
        local media_item = self:get_selected_media_item(i)
        selected_media_items[i + 1] = media_item
    end
    return selected_media_items
end

-- Get value by section and key from project state.
-- @section string
-- @key string
-- @return string
function Project:get_key_value(section, key)
    return r.GetExtState(section, key)
end

-- Set value by section and key into project state.
-- @section string
-- @key string
-- @value string
-- @persist boolean
function Project:set_key_value(section, key, value, persist)
    return r.SetExtState(section, key, value, persist)
end

--Delete value by section and key into project state.
--@section string
--@key string
--@persist boolean
function Project:del_key_value(section, key, persist)
    return r.DeleteExtState(section, key, persist)
end

--Whether section and key value is stored in project state.
--@section string
--@key string
--@persist boolean
function Project:has_key_value(section, key)
    return r.HasExtState(section, key)
end

-- Track
Track = ReaLoopBaseModel:new()

-- Create new instance of Track
-- @media_track userdata : Pointer to Reaper MediaTrack
-- @return Track
function Track:new(media_track --[[userdata]])
    local o = { media_track = media_track }
    setmetatable(o, self)
    self.__index = self
    return o
end

-- @return string
function Track:__tostring()
    return string.format(
            '<Track name=%s>',
            self:get_name()
    )
end


--Get track numerical-value attributes.
--[[
    Accepted param values:
    B_MUTE : bool * : muted
    B_PHASE : bool * : track phase inverted
    B_RECMON_IN_EFFECT : bool * : record monitoring in effect (current audio-thread playback state, read-only)
    IP_TRACKNUMBER : int : track number 1-based, 0=not found, -1=master track (read-only, returns the int directly)
    I_SOLO : int * : soloed, 0=not soloed, 1=soloed, 2=soloed in place, 5=safe soloed, 6=safe soloed in place
    B_SOLO_DEFEAT : bool * : when set, if anything else is soloed and this track is not muted, this track acts soloed
    I_FXEN : int * : fx enabled, 0=bypassed, !0=fx active
    I_RECARM : int * : record armed, 0=not record armed, 1=record armed
    I_RECINPUT : int * : record input, <0=no input. if 4096 set, input is MIDI and low 5 bits represent channel (0=all, 1-16=only chan), next 6 bits represent physical input (63=all, 62=VKB). If 4096 is not set, low 10 bits (0..1023) are input start channel (ReaRoute/Loopback start at 512). If 2048 is set, input is multichannel input (using track channel count), or if 1024 is set, input is stereo input, otherwise input is mono.
    I_RECMODE : int * : record mode, 0=input, 1=stereo out, 2=none, 3=stereo out w/latency compensation, 4=midi output, 5=mono out, 6=mono out w/ latency compensation, 7=midi overdub, 8=midi replace
    I_RECMON : int * : record monitoring, 0=off, 1=normal, 2=not when playing (tape style)
    I_RECMONITEMS : int * : monitor items while recording, 0=off, 1=on
    B_AUTO_RECARM : bool * : automatically set record arm when selected (does not immediately affect recarm state, script should set directly if desired)
    I_AUTOMODE : int * : track automation mode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
    I_NCHAN : int * : number of track channels, 2-64, even numbers only
    I_SELECTED : int * : track selected, 0=unselected, 1=selected
    I_WNDH : int * : current TCP window height in pixels including envelopes (read-only)
    I_TCPH : int * : current TCP window height in pixels not including envelopes (read-only)
    I_TCPY : int * : current TCP window Y-position in pixels relative to top of arrange view (read-only)
    I_MCPX : int * : current MCP X-position in pixels relative to mixer container
    I_MCPY : int * : current MCP Y-position in pixels relative to mixer container
    I_MCPW : int * : current MCP width in pixels
    I_MCPH : int * : current MCP height in pixels
    I_FOLDERDEPTH : int * : folder depth change, 0=normal, 1=track is a folder parent, -1=track is the last in the innermost folder, -2=track is the last in the innermost and next-innermost folders, etc
    I_FOLDERCOMPACT : int * : folder compacted state (only valid on folders), 0=normal, 1=small, 2=tiny children
    I_MIDIHWOUT : int * : track midi hardware output index, <0=disabled, low 5 bits are which channels (0=all, 1-16), next 5 bits are output device index (0-31)
    I_PERFFLAGS : int * : track performance flags, &1=no media buffering, &2=no anticipative FX
    I_CUSTOMCOLOR : int * : custom color, OS dependent color|0x100000 (i.e. ColorToNative(r,g,b)|0x100000). If you do not |0x100000, then it will not be used, but will store the color
    I_HEIGHTOVERRIDE : int * : custom height override for TCP window, 0 for none, otherwise size in pixels
    B_HEIGHTLOCK : bool * : track height lock (must set I_HEIGHTOVERRIDE before locking)
    D_VOL : double * : trim volume of track, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
    D_PAN : double * : trim pan of track, -1..1
    D_WIDTH : double * : width of track, -1..1
    D_DUALPANL : double * : dualpan position 1, -1..1, only if I_PANMODE==6
    D_DUALPANR : double * : dualpan position 2, -1..1, only if I_PANMODE==6
    I_PANMODE : int * : pan mode, 0=classic 3.x, 3=new balance, 5=stereo pan, 6=dual pan
    D_PANLAW : double * : pan law of track, <0=project default, 1=+0dB, etc
    P_ENV:<envchunkname or P_ENV:{GUID... : TrackEnvelope * : (read-only) chunkname can be <VOLENV, <PANENV, etc; GUID is the stringified envelope GUID.
    B_SHOWINMIXER : bool * : track control panel visible in mixer (do not use on master track)
    B_SHOWINTCP : bool * : track control panel visible in arrange view (do not use on master track)
    B_MAINSEND : bool * : track sends audio to parent
    C_MAINSEND_OFFS : char * : channel offset of track send to parent
    B_FREEMODE : bool * : track free item positioning enabled (call UpdateTimeline() after changing)
    C_BEATATTACHMODE : char * : track timebase, -1=project default, 0=time, 1=beats (position, length, rate), 2=beats (position only)
    F_MCP_FXSEND_SCALE : float * : scale of fx+send area in MCP (0=minimum allowed, 1=maximum allowed)
    F_MCP_FXPARM_SCALE : float * : scale of fx parameter area in MCP (0=minimum allowed, 1=maximum allowed)
    F_MCP_SENDRGN_SCALE : float * : scale of send area as proportion of the fx+send total area (0=minimum allowed, 1=maximum allowed)
    F_TCP_FXPARM_SCALE : float * : scale of TCP parameter area when TCP FX are embedded (0=min allowed, default, 1=max allowed)
    I_PLAY_OFFSET_FLAG : int * : track playback offset state, &1=bypassed, &2=offset value is measured in samples (otherwise measured in seconds)
    D_PLAY_OFFSET : double * : track playback offset, units depend on I_PLAY_OFFSET_FLAG
    P_PARTRACK : MediaTrack * : parent track (read-only)
    P_PROJECT : ReaProject * : parent project (read-only)
--]]
-- @param string
-- @return number
function Track:get_info_number(param)
    return r.GetMediaTrackInfo_Value(self.media_track, param)
end

-- Set track numerical-value attributes.
--[[
    Accepted param values:
    B_MUTE : bool * : muted
    B_PHASE : bool * : track phase inverted
    B_RECMON_IN_EFFECT : bool * : record monitoring in effect (current audio-thread playback state, read-only)
    IP_TRACKNUMBER : int : track number 1-based, 0=not found, -1=master track (read-only, returns the int directly)
    I_SOLO : int * : soloed, 0=not soloed, 1=soloed, 2=soloed in place, 5=safe soloed, 6=safe soloed in place
    B_SOLO_DEFEAT : bool * : when set, if anything else is soloed and this track is not muted, this track acts soloed
    I_FXEN : int * : fx enabled, 0=bypassed, !0=fx active
    I_RECARM : int * : record armed, 0=not record armed, 1=record armed
    I_RECINPUT : int * : record input, <0=no input. if 4096 set, input is MIDI and low 5 bits represent channel (0=all, 1-16=only chan), next 6 bits represent physical input (63=all, 62=VKB). If 4096 is not set, low 10 bits (0..1023) are input start channel (ReaRoute/Loopback start at 512). If 2048 is set, input is multichannel input (using track channel count), or if 1024 is set, input is stereo input, otherwise input is mono.
    I_RECMODE : int * : record mode, 0=input, 1=stereo out, 2=none, 3=stereo out w/latency compensation, 4=midi output, 5=mono out, 6=mono out w/ latency compensation, 7=midi overdub, 8=midi replace
    I_RECMON : int * : record monitoring, 0=off, 1=normal, 2=not when playing (tape style)
    I_RECMONITEMS : int * : monitor items while recording, 0=off, 1=on
    B_AUTO_RECARM : bool * : automatically set record arm when selected (does not immediately affect recarm state, script should set directly if desired)
    I_AUTOMODE : int * : track automation mode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
    I_NCHAN : int * : number of track channels, 2-64, even numbers only
    I_SELECTED : int * : track selected, 0=unselected, 1=selected
    I_WNDH : int * : current TCP window height in pixels including envelopes (read-only)
    I_TCPH : int * : current TCP window height in pixels not including envelopes (read-only)
    I_TCPY : int * : current TCP window Y-position in pixels relative to top of arrange view (read-only)
    I_MCPX : int * : current MCP X-position in pixels relative to mixer container
    I_MCPY : int * : current MCP Y-position in pixels relative to mixer container
    I_MCPW : int * : current MCP width in pixels
    I_MCPH : int * : current MCP height in pixels
    I_FOLDERDEPTH : int * : folder depth change, 0=normal, 1=track is a folder parent, -1=track is the last in the innermost folder, -2=track is the last in the innermost and next-innermost folders, etc
    I_FOLDERCOMPACT : int * : folder compacted state (only valid on folders), 0=normal, 1=small, 2=tiny children
    I_MIDIHWOUT : int * : track midi hardware output index, <0=disabled, low 5 bits are which channels (0=all, 1-16), next 5 bits are output device index (0-31)
    I_PERFFLAGS : int * : track performance flags, &1=no media buffering, &2=no anticipative FX
    I_CUSTOMCOLOR : int * : custom color, OS dependent color|0x100000 (i.e. ColorToNative(r,g,b)|0x100000). If you do not |0x100000, then it will not be used, but will store the color
    I_HEIGHTOVERRIDE : int * : custom height override for TCP window, 0 for none, otherwise size in pixels
    B_HEIGHTLOCK : bool * : track height lock (must set I_HEIGHTOVERRIDE before locking)
    D_VOL : double * : trim volume of track, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
    D_PAN : double * : trim pan of track, -1..1
    D_WIDTH : double * : width of track, -1..1
    D_DUALPANL : double * : dualpan position 1, -1..1, only if I_PANMODE==6
    D_DUALPANR : double * : dualpan position 2, -1..1, only if I_PANMODE==6
    I_PANMODE : int * : pan mode, 0=classic 3.x, 3=new balance, 5=stereo pan, 6=dual pan
    D_PANLAW : double * : pan law of track, <0=project default, 1=+0dB, etc
    P_ENV:<envchunkname or P_ENV:{GUID... : TrackEnvelope * : (read-only) chunkname can be <VOLENV, <PANENV, etc; GUID is the stringified envelope GUID.
    B_SHOWINMIXER : bool * : track control panel visible in mixer (do not use on master track)
    B_SHOWINTCP : bool * : track control panel visible in arrange view (do not use on master track)
    B_MAINSEND : bool * : track sends audio to parent
    C_MAINSEND_OFFS : char * : channel offset of track send to parent
    B_FREEMODE : bool * : track free item positioning enabled (call UpdateTimeline() after changing)
    C_BEATATTACHMODE : char * : track timebase, -1=project default, 0=time, 1=beats (position, length, rate), 2=beats (position only)
    F_MCP_FXSEND_SCALE : float * : scale of fx+send area in MCP (0=minimum allowed, 1=maximum allowed)
    F_MCP_FXPARM_SCALE : float * : scale of fx parameter area in MCP (0=minimum allowed, 1=maximum allowed)
    F_MCP_SENDRGN_SCALE : float * : scale of send area as proportion of the fx+send total area (0=minimum allowed, 1=maximum allowed)
    F_TCP_FXPARM_SCALE : float * : scale of TCP parameter area when TCP FX are embedded (0=min allowed, default, 1=max allowed)
    I_PLAY_OFFSET_FLAG : int * : track playback offset state, &1=bypassed, &2=offset value is measured in samples (otherwise measured in seconds)
    D_PLAY_OFFSET : double * : track playback offset, units depend on I_PLAY_OFFSET_FLAG
    P_PARTRACK : MediaTrack * : parent track (read-only)
    P_PROJECT : ReaProject * : parent project (read-only)
--]]
-- @param string
function Track:set_info_number(param)
end

-- Get track info values as string.
--[[
    Accepted param values:
    P_NAME : track name (on master returns NULL)
    P_ICON : track icon (full filename, or relative to resource_path/data/track_icons)
    P_MCP_LAYOUT : layout name
    P_RAZOREDITS : list of razor edit areas, as space-separated triples of
    start time, end time, and envelope GUID string.
    P_TCP_LAYOUT : layout name
    P_EXT:xyz : extension-specific persistent data
    GUID : globally unique identifier
--]]
-- @return string
function Track:get_info_string(param --[[string]])
    local retval, info_string = r.GetSetMediaTrackInfo_String(self.media_track, param, '', false)
    if retval then
        return info_string
    else
        return nil
    end
end

-- Set track info values as string.
--[[
    Accepted param values:
    P_NAME : track name
    P_ICON : track icon (full filename, or relative to resource_path/data/track_icons)
    P_MCP_LAYOUT : layout name
    P_RAZOREDITS : list of razor edit areas, as space-separated triples of
    start time, end time, and envelope GUID string.
    P_TCP_LAYOUT : layout name
    P_EXT:xyz : extension-specific persistent data
    GUID : globally unique identifier
--]]
-- @param string
-- @value string
-- @return boolean
function Track:set_info_string(param --[[string]], value --[[string]])
    local retval, _ = r.GetSetMediaTrackInfo_String(self.media_track, param, value, true)
    return retval
end

-- Get track name.
-- @return string
function Track:get_name()
    local _, name = r.GetTrackName(self.media_track)
    return name
end

-- Get track index.
-- @return number
function Track:get_index()
    return self:get_info_number('IP_TRACKNUMBER')
end

-- Get track color.
-- @return string
function Track:get_color()
    return r.GetTrackColor(self.media_track)
end

-- Get track icon. Full filename, or relative to resource_path/data/track_icons.
-- @return string
function Track:get_icon()
    local retval, info_string = r.GetSetMediaTrackInfo_String(self.media_track, 'P_ICON', '', false)
    if retval then
        return info_string
    else
        return nil
    end
end

-- Get MCP layout.
-- @return string
function Track:get_mcp_layout()
    local retval, info_string = r.GetSetMediaTrackInfo_String(self.media_track, 'P_TCP_LAYOUT', '', false)
    if retval then
        return info_string
    else
        return nil
    end
end

-- Get TCP layout.
-- @return string
function Track:get_tcp_layout()
    local retval, info_string = r.GetSetMediaTrackInfo_String(self.media_track, 'P_MCP_LAYOUT', '', false)
    if retval then
        return info_string
    else
        return nil
    end
end

function Track:get_key_value_store()
    local retval, info_string = r.GetSetMediaTrackInfo_String(self.media_track, 'P_EXT', '', false)
    if retval then
        return info_string
    else
        return nil
    end
end

-- Total number of FX in Track
-- @return number
function Track:get_fx_count()
    return r.TrackFX_GetCount(self.media_track)
end

-- Get Track FX Chain
-- @return Table<FX>
function Track:get_fx_chain()
    local fx_chain = {}
    for i = 0, self:get_fx_count() - 1 do
        local fx = TrackFX:new(self, i)
        fx_chain[i + 1] = fx
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


-- Get track state chunk
-- @return string
function Track:get_state_chunk(is_undo --[[boolean]])
    local retval, state = r.GetTrackStateChunk(self.media_track, '', is_undo)
    if retval then
        return state
    end
end

-- Set Track name
-- @name string: track name
function Track:set_name(name)
    self:set_info_string('P_NAME', name)
end

-- Set Track icon
-- @color string
function Track:set_color(color)
    r.SetTrackColor(self.media_item, color)
end

-- Set Track color
-- @icon string: full filename, or relative to resource_path/data/track_icons
function Track:set_color(name)
    self:set_info_string('P_ICON', name)
end

-- Set MCP layout
-- @name string: layout name
function Track:set_mcp_layout(name)
    r:set_info_string('P_MCP_LAYOUT', name)
end

-- Set TCP layout
-- @name string: layout name
function Track:set_tcp_layout(name)
    r:set_info_string('P_TCP_LAYOUT', name)
end

-- Set razor edits
--[[
    @razoredits table:
    list of razor edit areas
    as space-separated triples of start time, end time,
    and envelope GUID string.
--]]
function Track:set_razor_edits(razoredits)
    r:set_info_string('P_MCP_LAYOUT', name)
end

-- Set persistent track data
-- @ext string: extension name
function Track:set_key_value(ext)
    r:set_info_string('P_TCP_LAYOUT', name)
end



-- Get Track Globally Unique ID
-- @return string
function Track:GUID()
    return r.GetTrackGUID(self.media_track)
end

-- Add media item to track and return it.
-- @return MediaItem
function Track:add_media_item()
    local media_item = r.AddMediaItemToTrack(self.media_track)
    return MediaItem:new(media_item)
end

-- TrackFX
TrackFX = ReaLoopBaseModel:new()

function TrackFX:new(track, idx)
    local o = {
        track = track,
        idx = idx
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function TrackFX:__tostring()
    return string.format(
            '<FX idx=%s, name=%s, is_instrument=%s, is_enabled=%s, is_offline=%s>',
            self.idx,
            self:get_name(),
            self:is_instrument(),
            self:is_enabled(),
            self:is_offline()
    )
end

-- Delete FX
function TrackFX:delete()
    r.TrackFX_Delete(self.track.media_track, self.idx)
end

-- Get FX Name
-- @return string
function TrackFX:get_name()
    local retval, name = r.TrackFX_GetFXName(self.track.media_track, self.idx, '')
    if retval then
        return name
    else
        return nil
    end
end

-- Whether FX is enabled
-- @return boolean
function TrackFX:is_enabled()
    return r.TrackFX_GetEnabled(self.track.media_track, self.idx)
end

-- Whether FX is offline
-- @return boolean
function TrackFX:is_offline()
    return r.TrackFX_GetOffline(self.track.media_track, self.idx)
end

-- Whether FX is a virtual instrument
-- @return boolean
function TrackFX:is_instrument()
    local inst_idx = r.TrackFX_GetInstrument(self.track.media_track)
    if inst_idx == -1 then
        return false
    elseif inst_idx == self.idx then
        return true
    end
    local patterns = { 'VSTi', 'VST3i', 'AUi' }
    local name = self:get_name()
    for _, p in pairs(patterns) do
        if name:find(p) then
            return true
        end
    end
    return false
end

-- Set FX Enable
function TrackFX:set_enabled(enabled)
    r.TrackFX_SetEnabled(self.track.media_track, self.idx, enabled)
end

-- Enable FX
function TrackFX:enable()
    self:set_enabled(true)
end

-- Disable FX
function TrackFX:disable()
    self:set_enabled(false)
end

-- FX globally unique identifier
-- @return string
function TrackFX:GUID()
    return r.TrackFX_GetFXGUID(self.track.media_track, self.idx)
end

-- Set FX key-value store
function TrackFX:set_key_value(key, value, persist)
    r.SetExtState(self:GUID(), key, value, persist)
end

-- Get FX key-value store
function TrackFX:get_key_value(key)
    return r.GetExtState(self:GUID(), key)
end

-- Copy FX to track
function TrackFX:copy_to_track(dest_track, dest_index)
    r.TrackFX_CopyToTrack(self.track.media_track, self.index, dest_track, dest_index, false)
end

-- Move FX to track
function TrackFX:move_to_track(dest_track, dest_index)
    r.TrackFX_CopyToTrack(self.track.media_track, self.index, dest_track, dest_index, true)
end

-- Delete FX from track
function TrackFX:delete()
    reaper.TrackFX_Delete(self.track.media_track, self.index)
end

-- MediaItem

MediaItem = ReaLoopBaseModel:new()

function MediaItem:new(media_item)
    -- MediaItem constructor
    -- @media_item : userdata
    local o = { media_item = media_item }
    setmetatable(o, self)
    self.__index = self
    return o
end

function MediaItem:__tostring()
    return string.format(
            '<MediaItem GUID=%s>', self:GUID()
    )
end

-- @return string
function MediaItem:GUID()
    return r.BR_GetMediaItemGUID(self.media_item)
end

-- @return string
function MediaItem:get_info_value(param --[[string]])
    return r.GetMediaItemInfo_Value(self.media_item, param)
end


-- Set media item numerical-value attributes
--[[
    Accepted params:
    B_MUTE : bool * : muted (item solo overrides). setting this value will clear C_MUTE_SOLO.
    B_MUTE_ACTUAL : bool * : muted (ignores solo). setting this value will not affect C_MUTE_SOLO.
    C_MUTE_SOLO : char * : solo override (-1=soloed, 0=no override, 1=unsoloed).
    B_LOOPSRC : bool * : loop source
    B_ALLTAKESPLAY : bool * : all takes play
    B_UISEL : bool * : selected in arrange view
    C_BEATATTACHMODE : char * : item timebase, -1=track or project default, 1=beats (position, length, rate),
     2=beats (position only). for auto-stretch timebase: C_BEATATTACHMODE=1, C_AUTOSTRETCH=1
    C_AUTOSTRETCH: : char * : auto-stretch at project tempo changes, 1=enabled, requires C_BEATATTACHMODE=1
    C_LOCK : char * : locked, &1=locked
    D_VOL : double * : item volume, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
    D_POSITION : double * : item position in seconds
    D_LENGTH : double * : item length in seconds
    D_SNAPOFFSET : double * : item snap offset in seconds
    D_FADEINLEN : double * : item manual fadein length in seconds
    D_FADEOUTLEN : double * : item manual fadeout length in seconds
    D_FADEINDIR : double * : item fadein curvature, -1..1
    D_FADEOUTDIR : double * : item fadeout curvature, -1..1
    D_FADEINLEN_AUTO : double * : item auto-fadein length in seconds, -1=no auto-fadein
    D_FADEOUTLEN_AUTO : double * : item auto-fadeout length in seconds, -1=no auto-fadeout
    C_FADEINSHAPE : int * : fadein shape, 0..6, 0=linear
    C_FADEOUTSHAPE : int * : fadeout shape, 0..6, 0=linear
    I_GROUPID : int * : group ID, 0=no group
    I_LASTY : int * : Y-position of track in pixels (read-only)
    I_LASTH : int * : height in track in pixels (read-only)
    I_CUSTOMCOLOR : int * : custom color, OS dependent color|0x100000 (i.e. ColorToNative(r,g,b)|0x100000).
     If you do not |0x100000, then it will not be used, but will store the color
    I_CURTAKE : int * : active take number
    IP_ITEMNUMBER : int : item number on this track (read-only, returns the item number directly)
    F_FREEMODE_Y : float * : free item positioning Y-position, 0=top of track, 1=bottom of track (will never be 1)
    F_FREEMODE_H : float * : free item positioning height, 0=no height, 1=full height of track (will never be 0)
 --]]
function MediaItem:set_info_value(param --[[string]], value --[[any]])
    return r.SetMediaItemInfo_Value(self.media_item, param, value)
end

function MediaItem:set_length(length --[[number]], refreshUI --[[boolean]])
    r.SetMediaItemLength(self.media_item, length, refreshUI)
end

function MediaItem:set_position(position --[[number]], refreshUI --[[boolean]])
    r.SetMediaItemLength(self.media_item, position, refreshUI)
end

-- Total number of takes in MediaItem
-- @return number
function MediaItem:count_takes()
    return r.GetMediaItemNumTakes(self.media_item)
end

-- Get take by selected idx
-- @return MediaItemTake
function MediaItem:get_take(idx --[[number]])
    local take = r.GetMediaItemTake(self.media_item, idx)
    return MediaItemTake:new(take)
end

-- Get all takes
-- @return Table<MediaItemTake>
function MediaItem:get_takes()
    local takes = {}
    for i = 0, self:count_takes() - 1 do
        local take = self:get_take(i)
        local media_item_take = MediaItemTake:new(self.media_item, take)
        takes[i + 1] = media_item_take
    end
    return takes
end

-- Add take to media item and return it
-- @return MediaItemTake
function MediaItem:add_take()
    local take
    r.AddTakeToMediaItem(self.media_item)
    return MediaItemTake:new(take)
end

function MediaItem:get_state_chunk(is_undo --[[boolean - optional]])
    is_undo = is_undo or false
    local retval, chunk = r.GetItemStateChunk(self.media_item, '', is_undo)
    if retval then
        return chunk
    else
        return nil
    end
end

-- MediaItemTake

MediaItemTake = ReaLoopBaseModel:new()

-- @media_item: userdata
-- @take: userdata
-- @return MediaItemTake
function MediaItemTake:new(media_item, take)
    local o = {
        media_item = media_item,
        take = take
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function MediaItemTake:__tostring()
    return string.format('<MediaItemTake GUID=%s>', self:GUID())
end

function MediaItemTake:GUID()
    return r.BR_GetMediaItemTakeGUID(self.take)
end

-- @return string
function MediaItemTake:get_info_value(param)
    return r.GetMediaItemTakeInfo_Value(self.take, param)
end

-- @return PCMSource
function MediaItemTake:get_pcm_source()
    local source = r.GetMediaItemTake_Source(self.take)
    return PCMSource:new(self.take, source)
end

function MediaItemTake:set_pcm_source(source)
    r.SetMediaItemTake_Source(self.take, source)
end


-- PCMSource

PCMSource = ReaLoopBaseModel:new()

function PCMSource:new(take --[[userdata]], source --[[userdata]])
    local o = {
        media_item_take = take,
        pcm_source = source,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

--@return string
function PCMSource:filename()
    return r.GetMediaSourceFileName(self.source, '')
end

--@return number
function PCMSource:length()
    return r.GetMediaSourceFileName(self.source, '')
end

--@return number
function PCMSource:channels_num()
    return r.GetMediaSourceNumChannels(self.source)
end

-- TODO
function PCMSource:parent()
    return r.GetMediaSourceParent(self.source)
end

-- @return number
function PCMSource:sample_rate()
    return r.GetMediaSourceSampleRate(self.source)
end

-- @return string
function PCMSource:type()
    return r.GetMediaSourceType(self.source, '')
end

function PCMSource:destroy()
    r.PCM_Source_Destroy(self.source)
end

-- Get section info
--[[
    @return : a Table with 3 items (number, number, boolean) on success,
    nil otherwise
--]]
function PCMSource:get_section_info()
    local retval, offset, length, is_reversed = r.PCM_Source_GetSectionInfo(self.source)
    if retval then
        return { offset, length, is_reversed }
    else
        return nil
    end
end


ImGui = {}

function ImGui:new(label, font_name, width, height)
    font_name = font_name or 'sans-serif'
    width = width or 400
    height = height or 80
    local size = self:get_app_version():match('OSX') and 12 or 14
    local font = self:create_font(font_name, size)
    local ctx = self:create_context(label)
    local o = {
        ctx = ctx,
        font = font,
        label = label,
        width = width,
        height = height
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function ImGui:log(...)
    if DEBUG then
        Reaper:log('ImGui', ...)
    end
end

--[[
    Returns app version which may include an OS/arch signifier, such as: "6.17"
    windows 32-bit), "6.17/x64" (windows 64-bit), "6.17/OSX64" (macOS 64-bit Intel),
    "6.17/OSX" (macOS 32-bit), "6.17/macOS-arm64", "6.17/linux-x86_64",
    "6.17/linux-i686", "6.17/linux-aarch64", "6.17/linux-armv7l", etc
--]]
function ImGui:get_app_version()
    return r.GetAppVersion()
end

function ImGui:create_font(font_name, size)
     return r.ImGui_CreateFont(font_name, size)
end

function ImGui:attach_font()
    r.ImGui_AttachFont(self.ctx, self.font)
end

function ImGui:push_font()
    r.ImGui_PushFont(self.ctx, self.font)
end

function ImGui:pop_font()
    r.ImGui_PopFont(self.ctx)
end

function ImGui:create_context(label)
    return r.ImGui_CreateContext(label)
end

--[[
    Set the variable if the object/window has no persistently saved data
    (no entry in .ini file)
--]]
function ImGui:first_condition()
    return r.ImGui_Cond_FirstUseEver()
end

function ImGui:set_next_window_size(width, height, cond)
    width = width or self.width
    height = height or self.height
    cond = cond or self:first_condition()
    r.ImGui_SetNextWindowSize(self.ctx, width, height, cond)
end

--[[
    Push window to the stack and start appending to it. See ImGui:end_window.
    Passing true to 'p_open' shows a window-closing widget in the upper-right corner of the window,
    which clicking will set the boolean to false when returned.
    You may append multiple times to the same window during the same frame
    by calling Begin()/End() pairs multiple times.
    Some information such as 'flags' or 'open' will only be considered
    by the first call to Begin().
    Begin() return false to indicate the window is collapsed or fully clipped,
    so you may early out and omit submitting anything to the window.
    Note that the bottom of window stack always contains a window called "Debug".

    @label string : label for the window
    @p_open boolean : shows a window-closing widget in the upper-right corner of the window
    @return boolean : whether window is visible
    @return boolean : whether window is open
--]]
function ImGui:begin_window(label, p_open)
    label = label or self.label
    p_open = p_open or true
    return r.ImGui_Begin(self.ctx, self.label, p_open)
end

-- Pop window from the stack. See ImGui:begin_window
function ImGui:end_window()
    r.ImGui_End(self.ctx)
end

function ImGui:window_context(label, p_open)
    local visible, open = self:begin_window(label, p_open)
    return function(func)
        if visible then
            func(self.ctx)
            self:end_window()
        end
        return open
    end
end

function ImGui:destroy_context()
    r.ImGui_DestroyContext(self.ctx)
end

function ImGui:loop(func)
    function loop()
        --self:attach_font()
        --self:push_font()
        --self:set_next_window_size()
        local window = self:window_context()
        local open = window(func)
        --self:pop_font()
        if open then
            r.defer(loop)
        else
            self:destroy_context()
        end
    end
    return loop
end
