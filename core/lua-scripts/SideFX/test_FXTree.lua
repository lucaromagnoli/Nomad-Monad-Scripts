require('FXTree')
require('tree')
local lu = require('luaunit')


function TestFXLeafNew()
    fx_leaf1 = FXLeaf:new()
    leaf1 = FXLeaf:new()
    assert(leaf1.id ~= fx_leaf1.id)
end

function TestFXLeafNew()
    fx = {name = 'fx1'}
    fx_leaf1 = FXLeaf:new(fx)
    leaf1 = FXLeaf:new()
    assert(leaf1.id ~= fx_leaf1.id)
    assert(fx_leaf1.fx == fx)
end

function TestFXRootNew()
    fx_root = FXRoot:new()
    root = Root:new()
    assert(fx_root.id ~= root.id)
end

function TestFXNodeNew()
    fx_node = FXNode:new()
    node = Node:new()
    assert(fx_node.id ~= node.id)
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
