require('ReaWrap.models.reaper')
require('file_io')

IniFileParser = {}
function IniFileParser:new()
    r = Reaper:new()
    local o = {
        vst_ini = r:get_resource_path() .. '/reaper-vstplugins64.ini'
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function IniFileParser:log(...)
    local logger = log_func('IniFileParser')
    logger(...)
end

---Adapted from https://github.com/bartbes/inifile/blob/main/inifile.lua
---@param fpath string
---@return table
function IniFileParser:parse_file(fpath)
    local t = {}
	local section
    local section_data
    local sections_order = {}
    local text = read_file(fpath)
    for line in iter_lines(text) do
        --line = line:gsub("%s+", "")

		-- Section headers
		local s = line:match("^%[([^%]]+)%]$")
		if s then
			section = s
            section_data = {}
			t[section] = section_data
            sections_order[#sections_order + 1] = section
		end

		-- Key-value pairs
		local key, value = line:match("([%w.]+)%s-=%s-(.+)$")
		if tonumber(value) then value = tonumber(value) end
		if value == "true" then value = true end
		if value == "false" then value = false end
		if key and value ~= nil then
            if section then
                section_data[#section_data + 1] = {name = key, value = value}
            else
                t[#t + 1] = {key = value}
            end
        end
	end
    return setmetatable(t, {
        __inifile = {
            sections_order = sections_order,
        }
    })
end

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
        vendor = self:get_vendor()
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

function Plugin:is_instrument()
    if self.src_file == 'vst' then
        return self.value:match('!!!VSTi') ~= nil
    elseif self.format == 'au' then
        return self.value:match('<inst>') ~= nil
    end
    return false
end

function Plugin:get_name()
    if self.src_file == 'vst' then
        local _, _, name_vendor = self.value:match('([^,]+),([^,]+),([^,]+)')
        name_vendor = string.gsub(name_vendor, '!!!VSTi', '')
        local name, vendor = name_vendor:match('(.*)%s%((.*)%)')
        self._vendor = vendor
        return name
    end
end

function Plugin:get_vendor()
    if self._vendor ~= nil then
        return self._vendor
    end
end

---Parse vst ini file
function IniFileParser:parse_vst()
    local ini_data = self:parse_file(self.vst_ini)
    local vst_data = ini_data.vstcache
    if vst_data == nil then
        error(
                string.format('No vstcache section found in %s'),
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
