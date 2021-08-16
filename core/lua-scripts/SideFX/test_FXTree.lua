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

function TestLoadState()
    local state = 'return { id = "dde149d0-a286-416b-8482-16ed2a7ca474", is_selected = false, type = "FXRoot", children = { {id = "24349c19-742d-4689-9d2a-e88cb347d8e1" , fx_guid = "{52D81EB2-6C25-494D-BA73-8B52008A6AB4}", is_selected = "false", type_ = "FXLeaf"}, {id = "b35fc105-8576-4b00-8d2d-cb6869cd65b8" , fx_guid = "{86972459-4E77-AF41-B5A1-9C3CE53B04BA}", is_selected = "false", type_ = "FXLeaf"}, {id = "0fdfbf01-758e-419e-9611-2c8a217f8cb0" , fx_guid = "{F834A4F2-2706-4C40-B969-8C1744A79913}", is_selected = "true", type_ = "FXLeaf"},  } }'
    local root = load_state(state)
    assert(root:is_root())
    assert(root:has_children())
    for i, c in ipairs(root.children) do
        assert(c:is_leaf())
    end
    assert(root.children[1].fx_guid == "{52D81EB2-6C25-494D-BA73-8B52008A6AB4}")
    assert(root.children[2].fx_guid == "{86972459-4E77-AF41-B5A1-9C3CE53B04BA}")
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
