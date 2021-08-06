local function uuid4()
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
        parent = nil,
    }
end

function Leaf:__tostring()
    return string.format('Leaf %s', self.id)
end

function Leaf:has_children()
    return false
end

NodeBase = {}
function NodeBase:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
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

function NodeBase:get_child_idx(child, children)
    for i, child_ in ipairs(children) do
        if child_ == child then
            return i
        end
    end
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
        __reverse_index = {}
    }
end

function Root:__tostring()
    return string.format('Root %s', self.id)
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
        __reverse_index = {}
    }
end

function Node:__tostring()
    return string.format('Node %s', self.id)
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
    while status ~= dead do
        return function()
            local _, val, level = coroutine.resume(co_traverse, children)
            status = coroutine.status(co_traverse)
            return val, level
        end
    end
end
