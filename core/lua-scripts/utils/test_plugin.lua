require('plugin')
local lu = require('luaunit')

local plugins_manager = PluginsManager:init('ini_data', 'OSX')

function TestPluginsMap()
    for _, v in ipairs({'VST', 'VST3', 'VSTi', 'VST3i', 'AU', 'AUi', 'JS'}) do
        assert(plugins_manager.plugins_map[v] ~=nil)
        assert(#plugins_manager.plugins_map[v] > 0)
    end
end


function TestIterPluginsAll()
    local unique = {}
    for i, plugin in plugins_manager:iter_plugins() do
        unique[plugin.format] = true
    end
    for i, s in ipairs(Plugin.formats) do
        assert(unique[s] ~= nil)
    end
end

function TestIterPluginsSection()
    for _, section in ipairs(Plugin.formats) do
        for i, plugin in plugins_manager:iter_plugins(section) do
            assert(plugin.format == section)
        end
    end
end



local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
