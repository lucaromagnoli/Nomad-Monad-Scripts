require('ReaWrap.models.helpers')

function uuid4()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

Leaf = {}
function Leaf:new()
    local o = self.get_object()
    self.__index = self
    setmetatable(o, self)
    return o
end

function Leaf.get_object()
    return {
        id = uuid4(),
        parent = nil
    }
end

function Leaf:__tostring()
    return string.format('Leaf %s', self.id)
end

function Leaf:has_children()
    return false
end

function Leaf:is_root()
    return false
end

function Leaf:is_node()
    return false
end

function Leaf:is_leaf()
    return true
end

local function is_only_child(child)
    local count = 0
    for _, c in ipairs(child.parent.children) do
        if c ~= child then
            count = count + 1
        end
    end
    return count == 0
end

function Leaf:is_only_child()
    return is_only_child(self)
end

NodeBase = {}
function NodeBase:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NodeBase:log(...)
    logger = log_func('NodeBase')
    logger(...)
end

---@param child table object<Leaf | Node> : Must have a `parent` attribute.
function NodeBase:add_child(child, pos)
    if child == self then
        error('A node cannot be its own parent!')
    end
    child.parent = self
    if pos then
        table.insert(self.children, pos, child)
    else
        table.insert(self.children, child)
    end
end

---@param children table array<Leaf | Node> : Must have a `parent` attribute.
function NodeBase:add_children(children)
    for _, child in pairs(children) do
        self:add_child(child)
    end
end

function NodeBase:get_child_idx(child)
    for i, c in ipairs(self.children) do
        if c == child then
            return i
        end
    end
end

function NodeBase:has_child(child)
    for _, c in ipairs(self.children) do
        if c == child then
            return true
        end
    end
    return false
end

function NodeBase:remove_child(child)
    child.parent = nil
    local child_idx = self:get_child_idx(child)
    table.remove(self.children, child_idx)
end

function NodeBase:remove_children(children)
    local new_children = {}
    for _, child in ipairs(self.children) do
        local idx = self:get_child_idx(child, children)
        if children[idx] == nil then
            new_children[#new_children + 1] = child
        end
    end
    self.children = new_children
end

function NodeBase:move_children_to(children, node)
    self:remove_children(children)
    for _, c in ipairs(children) do
        node:add_child(c)
    end
    node.parent = self.parent
end

function NodeBase:iter_children()
    local i = 0
    return function()
        i = i + 1
        return self.children[i]
    end
end

function NodeBase:has_children()
    return #self.children > 0
end

Root = NodeBase:new()
function Root:new()
    local o = self.get_object()
    setmetatable(o, self)
    self.__index = self
    return o
end

function Root:get_object()
    return {
        id = uuid4(),
        children = {},
    }
end

function Root:__tostring()
    return string.format('Root %s', self.id)
end

function Root:is_root()
    return true
end

function Root:is_leaf()
    return false
end

function Root:is_node()
    return false
end

Node = NodeBase:new()
function Node:new()
    local o = self.get_object()
    self.__index = self
    setmetatable(o, self)
    return o
end

function Node:get_object()
    return {
        id = uuid4(),
        parent = nil,
        children = {},
    }
end

function Node:__tostring()
    return string.format('Node %s', self.id)
end

function Node:is_root()
    return false
end

function Node:is_leaf()
    return false
end

function Node:is_node()
    return true
end

function Node:is_only_child()
    return is_only_child(self)
end

---@param child table <Leaf | Node>
function Node:new_from_child(child)
    local node = self:new()
    local parent = child.parent
    local child_idx = parent:get_child_idx(child)
    parent:add_child(node, child_idx)
    parent:remove_child(child)

    return node
end

---@param children table <Leaf | Node>
function Node:new_from_children(children)
    local parent = children[1].parent
    parent:remove_children(children)
    local node = self:new()
    for _, child in pairs(children) do
        node:add_child(child)
    end
    parent:add_child(node)
    return node
end

function depth_first_traverse(children, level, func)
    level = level or 0
    for _, child in ipairs(children) do
        coroutine.yield(child, level)
        if child:has_children() then
            depth_first_traverse(child.children, level + 1)
        end
    end
end

function traverse_tree(children)
    local co_traverse = coroutine.create(depth_first_traverse)
    local status = coroutine.status(co_traverse)
    while status ~= 'dead' do
        return function()
            local _, val, level = coroutine.resume(co_traverse, children)
            status = coroutine.status(co_traverse)
            return val, level
        end
    end
end

TrieNode = Node:new()

function TrieNode:new(char)
    local o = self:get_object()
    o.char = char
    self.__index = self
    setmetatable(o, self)
    return o
end

function TrieNode:__tostring()
    return string.format('TrieNode %s', self.id)
end

TrieLeaf = Leaf:new()

function TrieLeaf:new(obj)
    local o = self:get_object()
    o.object = obj
    self.__index = self
    setmetatable(o, self)
    return o
end

function TrieLeaf:__tostring()
    return string.format('TrieLeaf %s', self.id)
end


function TrieNode:add_child_from_char(char)
    local child_node = self:new(char)
    self:add_child(child_node)
    return child_node
end

function TrieNode:get_child_from_char(char)
    for i, child in ipairs(self.children) do
        if child.char == char then
            return child
        end
    end
end


Trie = {}

function Trie:new()
    local o = {
        root = TrieNode:new()
    }
    self.__index = self
    setmetatable(o, self)
    return o
end

function Trie:__tostring()
    return string.format('Trie | root %s', self.root)
end

local function find_word_matches(root, word)
    local node = root
    local has_matches = false
    local i = 1
    local chars = Trie:word_to_chars(word)
    local has_chars = true
    while has_chars do
        local char = chars[i]
        if char ~= nil then
            new_node = node:get_child_from_char(char)
            if new_node ~= nil then
                has_matches = true
                node = new_node
                i = i + 1
            else
                has_chars = false
                has_matches = false
            end
        else
            has_chars = false
        end
    end
    if node:is_leaf() then
        coroutine.yield(node)
    else
        for child, _ in traverse_tree(node.children) do
            if child:is_leaf() then
                coroutine.yield(child)
            end
        end
    end
end

function Trie:find_word_matches(word)
    local matches = {}
    local coro_matches = coroutine.create(find_word_matches)
    local status = coroutine.status(coro_matches, self.root, word)
    while status ~= 'dead' do
        local _, match = coroutine.resume(coro_matches, self.root, word)
        if match then
            matches[#matches + 1]  = match
        end
        status = coroutine.status(coro_matches, self.root, word)
    end
    return matches
end

function Trie:word_to_chars(word)
    local chars = {}
    for char in word:gmatch('.') do
        chars[#chars + 1] = char
    end
    return chars
end

function trie_from_objects(objects)
    local trie = Trie:new()
    local node
    for _, obj in pairs(objects) do
        node = trie.root
        for char in obj.name:gmatch('.') do
            local child = node:get_child_from_char(char)
            if child then
                node = child
            else
                node = node:add_child_from_char(char)
            end
        end
        leaf = TrieLeaf:new(obj)
        node:add_child(leaf)
    end
    return trie
end

function trie_node_has_child(node, child)
    for i, c in ipairs(node.children) do
        if c.object.name == child.name then
            return true
        end
    end
    return false
end
