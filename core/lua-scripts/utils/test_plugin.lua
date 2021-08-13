require('plugin')
local lu = require('luaunit')

local plugins_manager = PluginsManager:init('ini_data', 'OSX')

function TestPluginsMap()
    for _, v in ipairs({'VST', 'VST3', 'VSTi', 'VST3i', 'AU', 'AUi', 'JS'}) do
        assert(plugins_manager.plugins_map[v] ~=nil)
        print(v)
        print(#plugins_manager.plugins_map[v])
        assert(#plugins_manager.plugins_map[v] > 0)
    end
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
