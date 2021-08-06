require('tree')
local lu = require('luaunit')

local function get_children(leaves, nodes)
    local children = {}
    local leaf_ctr = 1
    nodes = nodes or 0
    for i = 1, leaves + nodes do
        if leaf_ctr <= leaves then
            children[i] = Leaf:new()
            leaf_ctr = leaf_ctr + 1
        else
            children[i] = Node:new()
        end
    end
    return children
end

function TestRootAddChild()
    local root = Root:new()
    local leaf = Leaf:new()
    root:add_child(leaf)
    assert(root.children[1] == leaf)
end

function TestRootAddChildren()
    local root = Root:new()
    local children = get_children(2, 1)
    root:add_children(children)
    assert(#root.children == 3)
end

function TestNodeAddChildren()
    local node = Node:new()
    local children = get_children(2, 1)
    node:add_children(children)
    assert(#node.children == 3)
end


function TestNodeAddItselfAsChild()
    local node = Node:new()
    lu.assertError(node.add_child, node, child)
end



--- Behavioural tests
function TestNodeFromChildren()
    local root = Root:new()
    local children = get_children(10)
    root:add_children(children)
    assert(
            #root.children == 10,
            ('should be 1. found %s'):format(#root.children)
    )
    local node = Node:new_from_children(children)
    assert(
            #root.children == 1,
            ('should be 1. found %s'):format(#root.children)
    )
    assert(table.unpack(root.children) == node)
    assert(#node.children == 10)
    assert(node.parent == root)
end

function TestMoveChildrenToNode()
    local root = Root:new()
    local children = get_children(10)
    root:add_children(children)
    assert(
            #root.children == 10,
            ('should be 1. found %s'):format(#root.children)
    )
    local node1 = Node:new_from_children(children)
    assert(
            #root.children == 1,
            ('should be 1. found %s'):format(#root.children)
    )
    assert(table.unpack(root.children) == node1)
    assert(#node1.children == 10)
    assert(node1.parent == root)
    local function get_odd_children()
        local odd_children = {}
        for i, child in ipairs(node1.children) do
            if i % 2 ~= 0 then
                odd_children[#odd_children + 1] = child
            end
        end
        return odd_children
    end
    local node2 = Node:new()
    node1:move_children_to(get_odd_children(), node2)
    assert(
            #node1.children == 5,
            ('node 1 children should be 5. Found %s'):format(#node1.children)
    )
    assert(
            #node2.children == 5, (
            'node 2 children should be 5. Found %s'):format(#node2.children)
    )
    assert(
            node1.parent == root,
            ('node 1 parent should be root. Found %s'):format(node1.parent)
    )
    assert(
            node2.parent == root,
            ('node 2 parent should be root. Found %s'):format(node2.parent)
    )
    assert(
            root.children[1] == node1,
            ('Child 1 should be node 1. Found %s'):format(root.children[1])
    )
    assert(
            root.children[1] == node1,
            ('Child 2 should be node 2. Found %s'):format(root.children[2])
    )
end


local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )


--
--node1 = Node:new_from_children(root.children)
--print('root children after moving to node 1')
--for child in root:iter_children() do
--    print(child)
--end
--print('should be the new node 1\n')
--
--print('node 1 children after init')
--for child in node1:iter_children() do
--    print(child)
--end
--print('should be all previous root children\n')
--
--node2 = Node:new(root)
--print('new node 2 ' .. tostring(node2))
--print('node 2 children after init')
--for child in node2:iter_children() do
--    print(child)
--end
--print('should be none\n')
--
--local odd_children = {}
--for i, c in pairs(node1.children) do
--    if i % 2 ~= 0 then
--        odd_children[#odd_children + 1] = c
--    end
--end
--
--node1:move_children_to(odd_children, node2)
--print('node 1 children after moving to node 2')
--for child in node1:iter_children() do
--    print(child)
--end
--print('\n')
--
--print('node 2 children after moving')
--for child in node2:iter_children() do
--    print(child)
--end
--print('\n')
--
--print('root children after moving children from node 1 to node 2')
--for child in root:iter_children() do
--    print(child)
--end
--print('Should be node 1 and node 2\n')
--
--local node3 = root:add_node()
--node3:add_leaves(10)
--local subnode3 = node3:add_node()
--subnode3:add_leaves(10)
--
--
--
--print('root children after adding node 3')
--for child in root:iter_children() do
--    print(child)
--end
--print('Should be node 1, node 2 and node 3 \n')
--
--print('tree traversal')
--
--spaces = '      '
--prev_level = 0
--for child, level in traverse_tree(root.children) do
--    separator = string.rep(spaces, level)
--    print(separator .. tostring(child))
--end