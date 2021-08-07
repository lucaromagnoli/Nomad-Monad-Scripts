require('ReaWrap.models.helpers')
require('file_io')

Plugin = {}
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

function Plugin:info()
    return {
        format = self:get_format(),
        is_instrument = self:is_instrument(),
        name = self:get_name(),
        vendor = self:get_vendor(),
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
    if self.src_file == 'vst' and self:is_vst3() then
        return 'vst3'
    else
        return self.src_file
    end
end

---@return boolean
function Plugin:is_instrument()
    if self.src_file == 'vst' then
        return self.value:match('!!!VSTi') ~= nil
    elseif self.src_file == 'au' then
        return self.value:match('<inst>') ~= nil
    elseif self.src_file == 'js' then
        return nil
    end
end

---@return string
function Plugin:get_name()
    if self.src_file == 'vst' then
        local _, _, name_vendor = self.value:match('([^,]+),([^,]+),([^,]+)')
        name_vendor = string.gsub(name_vendor, '!!!VSTi', '')
        local name, vendor = name_vendor:match('(.*)%s%((.*)%)')
        self._vendor = vendor
        return name
    elseif self.src_file == 'au' then
        local name, _ = self.value:match('(.*)(=<)')
        return name
    elseif self.src_file == 'js' then
        return self.name:gsub('%"', '')
    end
end

---@return string
function Plugin:get_vendor()
    if self.src_file == 'vst' then
        return self._vendor
    elseif self.src_file == 'au' then
        return self.name
    elseif self.src_file == 'js' then
        return nil
    end
end

PluginParser = IniFileParser:new()

function PluginParser:new(source_path)
    if source_path == nil then
        error('Please provide source path to initialise PluginParser')
    end
    local o = {
        vst_ini = source_path ..'/reaper-vstplugins64.ini',
        au_ini = source_path ..'/reaper-auplugins64.ini',
        js_ini = source_path ..'/reaper-jsfx.ini'
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

---Parse VST INI file
---@raise error if the AU ini file does not exist, or the file is corrupted, i.e. missing the [auplugins] section.
function PluginParser:parse_vst()
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
            return Plugin:new('vst', vst.name, vst.value)
        end
    end
end


---Parse AU INI file
---@raise error if the AU ini file does not exist, or the file is corrupted, i.e. missing the [auplugins] section.
function PluginParser:parse_au()
    local kv_pattern = '([%w.%s]+)%s-:%s-(.+)$'
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
            return Plugin:new('au', au.name, au.value)
        end
    end
end

---Parse JSFX INI file
---@raise error if the JSFX ini file does not exist, or the file is corrupted, i.e. missing the [auplugins] section.
function PluginParser:parse_js()
    local kv_pattern = 'NAME (.*) "JS: (.*)'
    local ini_data = self:parse_file(self.js_ini, kv_pattern)
    local i = 0
    return function()
        i = i + 1
        local js = ini_data[i]
        if js ~= nil then
            return Plugin:new('js', js.name, js.value)
        end
    end
end
