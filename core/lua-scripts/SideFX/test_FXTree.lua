require('FXTree')
require('tree')
local lu = require('luaunit')


function TestFXLeafNew()
    fx_leaf1 = FXLeaf:new('fx-guid-1', 'track')
    fx_leaf2 = FXLeaf:new('fx-guid-2', 'track')
    assert(fx_leaf1.id ~= fx_leaf2.id)
    assert(fx_leaf1.fx_guid ~= fx_leaf2.fx_guid)
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

--function TestFXNodeLastChildIdx()
--    --- setup
--    root = FXRoot:new()
--    leaf1 = FXLeaf:new('fxguid')
--    leaf2 = FXLeaf:new('fxguid')
--    node1 = FXNode:new()
--    root:add_child(leaf1)
--    root:add_child(leaf2)
--    root:add_child(node1)
--    node2 = FXNode:new()
--    leaf3 = FXLeaf:new('fxguid')
--    node1:add_child(leaf3)
--    node1:add_child(node2)
--    leaf4 = FXLeaf:new('fxguid')
--    leaf5 = FXLeaf:new('fxguid')
--    node2:add_child(leaf4)
--    node2:add_child(leaf5)
--    --- test
--    node1_last_idx = node1:get_last_fx_idx()
--    assert(node1_last_idx == 4)
--    node2_last_idx = node2:get_last_fx_idx()
--    assert(node2_last_idx == 4)
--end

function TestSaveLoadState()
    local root = FXRoot:new()
    local node = FXNode:new()
    node.inputs = {1, 2}
    node.outputs = {dry = {3, 4}, wet = {5, 6}}
    local leaf = FXLeaf:new('fx-guid-1', 'track1')
    root:add_child(node)
    node:add_child(leaf)
    local state = root:save_state()
    root_new = load_state(state, 'track1')
    assert(root_new.ttype == 'FXRoot')
    local node_new = root_new.children[1]
    assert(node_new.ttype == 'FXNode')
    assert(node_new.id == node.id)
    local leaf_new = node_new.children[1]
    assert(leaf_new.ttype == 'FXLeaf')
    assert(leaf_new.id == leaf.id)
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
