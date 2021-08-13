require('ReaWrap.models.helpers')
require('file_io')


Plugin = {
    formats = {
        'VST', 'VSTi', 'VST3', 'VST3i', 'AU', 'AUi', 'JS'
    }
}
function Plugin:new(src_file, name, value)
    local o = {
        src_file = src_file,
        name = name,
        value = value
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function Plugin:log(...)
    local logger = log_func('Plugin')
    logger(...)
end

function Plugin:get_info()
    return {
        format = self:get_format(),
        name = self:get_name(),
        vendor = self:get_vendor(),
        alias = self:get_alias() --- only for JS
    }
end

function Plugin:is_vst3()
    for token in string.gmatch(self.name, "[^.]+") do
        if token == 'vst3' then
            return true
        end
    end
    return false
end

function Plugin:get_format()
    if self.src_file == 'VST' then
        if self:is_vst3() then
            if self:is_instrument() then
                return 'VST3i'
            else
                return 'VST3'
            end
        else
            if self:is_instrument() then
                return 'VSTi'
            else
                return 'VST'
            end
        end
    elseif self.src_file == 'AU' then
        if self:is_instrument() then
            return 'AUi'
        else
            return 'AU'
        end
    elseif self.src_file == 'JS' then
        return 'JS'
    end
end

---@return boolean
function Plugin:is_instrument()
    if self.src_file == 'VST' then
        return self.value:match('!!!VSTi') ~= nil
    elseif self.src_file == 'AU' then
        return self.value:match('<inst>') ~= nil
    elseif self.src_file == 'JS' then
        return nil
    end
end

---@return string
function Plugin:get_name()
    if self.src_file == 'VST' then
        local _, _, name_vendor = self.value:match('([^,]+),([^,]+),([^,]+)')
        name_vendor = string.gsub(name_vendor, '!!!VSTi', '')
        local name, vendor = name_vendor:match('(.*)%s%((.*)%)')
        self._vendor = vendor
        return name
    elseif self.src_file == 'AU' then
        local name, _ = self.value:match('(.*)(=<)')
        return name
    elseif self.src_file == 'JS' then
        return self.name:gsub('%"', '')
    end
end

---@return string|nil
function Plugin:get_vendor()
    if self.src_file == 'VST' then
        return self._vendor
    elseif self.src_file == 'AU' then
        return self.name
    elseif self.src_file == 'JS' then
        return nil
    end
end

---@return string|nil
function Plugin:get_alias()
    if self.src_file == 'JS' then
        return self.value:gsub('%"', '')
    else
        return nil
    end
end

PluginsManager = {}

---Create new instance.
---@param source_path string
---@param os string
function PluginsManager:new(source_path, os)
    if source_path == nil then
        error('Please provide source path to initialise PluginsManager')
    end
    local o = {
        parser = IniFileParser:new(source_path),
        os = os,
        vst_ini = source_path ..'/reaper-vstplugins64.ini',
        au_ini = source_path ..'/reaper-auplugins64.ini',
        js_ini = source_path ..'/reaper-jsfx.ini',
        plugins_map = {}
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

---Wraps IniFileParser.parse_file().
---@param fname string
---@param pattern string
function PluginsManager:parse_file(fname, pattern)
    return self.parser:parse_file(fname, pattern)
end

---Create new instance and parse all plugins files.
---@param source_path string
---@param os string
function PluginsManager:init(source_path, os)
    p = self:new(source_path, os)
    p:load_plugins()
    return p
end

---Parse VST INI file
---@raise error if the AU ini file does not exist, or the file is corrupted, i.e. missing the [auplugins] section.
function PluginsManager:parse_vst()
    local ini_data = self:parse_file(self.vst_ini)
    local vst_data = ini_data.vstcache
    if vst_data == nil then
        error(
                string.format('No [vstcache] section found in %s'),
                self.vst_ini
        )
    end
    local i = 0
    return function()
        i = i + 1
        local vst = vst_data[i]
        if vst ~= nil then
            return Plugin:new('VST', vst.name, vst.value)
        end
    end
end


---Parse AU INI file
---@raise error if the AU ini file does not exist, or the file is corrupted, i.e. missing the [auplugins] section.
function PluginsManager:parse_au()
    local kv_pattern = '([%w.%s]+)%s-:%s?(.+)$'
    local ini_data = self:parse_file(self.au_ini, kv_pattern)
    local au_data = ini_data.auplugins
    if au_data == nil then
        error(
                string.format('No [auplugins] section found in %s'),
                self.au_ini
        )
    end
    local i = 0
    return function()
        i = i + 1
        local au = au_data[i]
        if au ~= nil then
            return Plugin:new('AU', au.name, au.value)
        end
    end
end

---Parse JSFX INI file
---@raise error if the JSFX ini file does not exist, or the file is corrupted, i.e. missing the [auplugins] section.
function PluginsManager:parse_js()
    local kv_pattern = 'NAME (.*) "JS: (.*)'
    local ini_data = self:parse_file(self.js_ini, kv_pattern)
    local i = 0
    return function()
        i = i + 1
        local js = ini_data[i]
        if js ~= nil then
            return Plugin:new('JS', js.name, js.value)
        end
    end
end

function PluginsManager:load_plugins()
    local plugin_info
    self.plugins_map['VST'] = {}
    self.plugins_map['VSTi'] = {}
    self.plugins_map['VST3'] = {}
    self.plugins_map['VST3i'] = {}
    self.plugins_map['AU'] = {}
    self.plugins_map['AUi'] = {}
    self.plugins_map['JS']  = {}

    for plugin in self:parse_vst() do
        plugin_info = plugin:get_info()
        table.insert(self.plugins_map[plugin_info.format], plugin_info)
    end
    for plugin in self:parse_au() do
        plugin_info = plugin:get_info()
        table.insert(self.plugins_map[plugin_info.format], plugin_info)
    end
    for plugin in self:parse_js() do
        plugin_info = plugin:get_info()
        table.insert(self.plugins_map[plugin_info.format], plugin_info)
    end
end

function PluginsManager:iter_all_plugins()
    local i = 0
    local function inner()
        for _, format in ipairs(Plugin.formats) do
            for _, plugin in ipairs(self.plugins_map[format]) do
                i = i + 1
                coroutine.yield(i, plugin)
            end
        end
    end
    local iter_coro = coroutine.create(inner)
    local status = coroutine.status(iter_coro)
    while status ~= 'dead' do
        return function()
            local _, idx, plugin = coroutine.resume(iter_coro)
            status = coroutine.status(iter_coro)
            return idx, plugin
        end
    end
end
