require('ReaWrap.models.helpers')

function read_file(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

function iter_lines(text)
    return text:gmatch("([^\r\n]+)\r?\n")
end

IniFileParser = {}
function IniFileParser:new(source_path)
    local o = {source_path = source_path}
    setmetatable(o, self)
    self.__index = self
    return o
end

function IniFileParser:log(...)
    logger = log_func('IniFileParser')
    logger(...)
end

---@param fpath string
---@return table
function IniFileParser:parse_file(fpath, kv_pattern)
    kv_pattern = kv_pattern or '([%w.]+)%s-=%s-(.+)$'
    local ini_table = {}
	local section
    local section_data
    local sections_order = {}
    local text = read_file(fpath)
    for line in iter_lines(text) do
		-- Section headers
		local s = line:match('^%[([^%]]+)%]$')
		if s then
			section = s
            section_data = {}
			ini_table[section] = section_data
            sections_order[#sections_order + 1] = section
		end
		-- Key-value pairs
		local key, value = line:match(kv_pattern)
		if key and value ~= nil then
            if section then
                section_data[#section_data + 1] = {name = key, value = value}
            else
                ini_table[#ini_table + 1] = { name = key, value = value}
            end
        end
	end
    return setmetatable(ini_table, {
        __inifile = {
            sections_order = sections_order,
        }
    })
end
