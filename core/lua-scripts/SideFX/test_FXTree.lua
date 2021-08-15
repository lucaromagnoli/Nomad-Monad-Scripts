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

function TestFXNodeLastChildIdx()
    --- setup
    root = FXRoot:new()
    leaf1 = FXLeaf:new({idx = 0})
    leaf2 = FXLeaf:new({ idx = 1 })
    node1 = FXNode:new()
    root:add_child(leaf1)
    root:add_child(leaf2)
    root:add_child(node1)
    node2 = FXNode:new()
    leaf3 = FXLeaf:new({idx = 2})
    node1:add_child(leaf3)
    node1:add_child(node2)
    leaf4 = FXLeaf:new({idx = 3})
    leaf5 = FXLeaf:new({idx = 4})
    node2:add_child(leaf4)
    node2:add_child(leaf5)
    --- test
    node1_last_idx = node1:get_last_fx_idx()
    assert(node1_last_idx == 4)
    node2_last_idx = node2:get_last_fx_idx()
    assert(node2_last_idx == 4)
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
