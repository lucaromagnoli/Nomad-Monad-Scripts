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

---global fixture
objs = get_objects()
trie = trie_from_objects(objs)

function TestTrieFromObjects()
    local node
    for i, obj in ipairs(objs) do
        node = trie.root
        for char in obj.name:gmatch('.') do
            node = node:get_child_from_char(char)
        end
        trie_node_has_child(node, obj)
    end
end

function TestFindWordMatches()
    local matches = trie:find_word_matches('la')
    assert(matches[1].object.name == 'lab')
    assert(matches[2].object.name == 'lake')
    assert(matches[3].object.name == 'lady')
    assert(matches[4].object.name == 'law')
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
