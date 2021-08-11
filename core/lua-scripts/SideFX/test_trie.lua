require('tree')
local lu = require('luaunit')

words = {
    'loss',
    'lab',
    'lake',
    'love',
    'lady',
    'law'
}

function get_objects()
    local objs = {}
    for i, w in ipairs(words) do
        local obj = {name = w}
        objs[i] = obj
    end
    return objs
end

function TestTrieFromObjects()
    local objs = get_objects()
    local trie = trie_from_objects(objs)
    local node
    for i, obj in ipairs(objs) do
        node = trie.root
        for char in obj.name:gmatch('.') do
            node = node:get_child_from_char(char)
        end
        trie_node_has_child(node, obj)
    end
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )