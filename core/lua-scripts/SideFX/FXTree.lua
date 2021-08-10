local info = debug.getinfo(3, "Sl")
if info.short_src ==  'test_FXTree.lua' then
    local l_path = package.path:gmatch("(.-)?.lua;")()
    package.path = package.path .. ';' .. l_path .. 'ReaWrap/models/?.lua'
else
    act_ctx = ({ reaper.get_action_context() })[2]
    parent = act_ctx:match('(.+)SideFX/')
    package.path = package.path .. ';' .. parent .. '?.lua'
    package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
end

require('ReaWrap.models.helpers')
require('tree')

FXAttributes = {
    'bypass', 'mix', 'volume', 'pan', 'mute', 'solo', 'sidechain'
}


FXLeaf = Leaf:new()
---@param fx any
function FXLeaf:new(fx)
    local o = self.get_object()
    o.fx = fx
    self.__index = self
    setmetatable(o, self)
    return o
end

function FXLeaf:__tostring()
    return string.format('FXLeaf %s', self.id)
end

function FXLeaf:get_object()
    local base_object = Leaf:get_object()
    base_object.is_selected = false
    for _, k in ipairs(FXAttributes) do
        base_object[k] = nil
    end
    return base_object
end

function FXLeaf:log(...)
    local logger = log_func('FXLeaf')
    logger(...)
end

function FXLeaf:get_type()
    return 'FXLeaf'
end


function FXLeaf:iter_input_mappings()
    for pin in self.fx:iter_input_pins() do
        local bitmask, _ = pin:get_mappings()
        self:log(self.fx, pin, bitmask)
    end
    --local function iter_pins()
    --    for pin in self.fx:iter_input_pins() do
    --        local bitmask, high32 = pin:get_mappings()
    --        coroutine.yield(pin, bitmask, high32)
    --    end
    --end
    --local iter_coro = coroutine.create(iter_pins)
    --local status = coroutine.status(iter_coro)
    --while status ~= dead do
    --    return function()
    --        local pin, bitmask, high32 = coroutine.resume(iter_coro)
    --        status = coroutine.status(iter_coro)
    --        return pin, bitmask, high32
    --    end
    --end
end

function FXLeaf:get_output_mappings()
    for pin in self.fx:iter_output_pins() do
        local bitmask, high32 = pin:get_mappings()
        return pin, bitmask, high32
    end
end


FXRoot = Root:new()
function FXRoot:new()
    local o = self.get_object()
    o.is_selected = false
    self.__index = self
    setmetatable(o, self)
    return o
end

function FXRoot:__tostring()
    return string.format('FXRoot %s', self.id)
end

FXNode = Node:new()
function FXNode:new()
    local o = self.get_object()
    self.__index = self
    setmetatable(o, self)
    return o
end

FXNode = Node:new()
function FXNode:get_object()
    local base_object = Node:get_object()
    base_object.is_selected = false
    base_object.splitter = nil
    base_object.mixer = nil
    for _, k in ipairs(FXAttributes) do
        base_object[k] = nil
    end
    return base_object
end

function FXNode:__tostring()
    return string.format('FXNode %s', self.id)
end


FXTree = {}

function FXTree:new(track)
    local o = {
        root = FXRoot:new(),
        track = track
    }
    self.__index = self
    setmetatable(o, self)
    return o
end

function FXTree:log(...)
    logger = log_func('FXTree')
    logger(...)
end

function FXTree:init()
    self:log(self.track)
    for fx in self.track:iter_fx_chain() do
        local fx_leaf = FXLeaf:new(fx)
        self.root:add_child(fx_leaf)
    end
end

function FXTree:traverse()
    return traverse_tree(self.root.children)
end

function FXTree:add_fx(member, mode, fx)
    local node, member_idx
    leaf = FXLeaf:new(fx)
    if mode == 0 then
        if member:is_root() then
            member:add_child(leaf)
        else
            member_idx = member.parent:get_child_idx(member)
            member.parent:add_child(leaf, member_idx + 1)
        end
    elseif mode == 1 then
        if member:is_leaf() then
            member_idx = member.parent:get_child_idx(member)
            node = FXNode:new()
            node:add_child(leaf)
            member.parent:add_child(node, member_idx + 1)
        else
            node = FXNode:new()
            node:add_child(leaf)
            member:add_child(node)
        end
    end
    leaf.is_selected = true
    self:deselect_all_except(leaf)
end

function FXTree:remove_fx(member)
    member.parent:remove_child(member)
end

function FXTree:deselect_all_except(member)
    if not member:is_root() then
        self.root.is_selected = false
    end
    for child, _ in traverse_tree(self.root.children) do
        if child ~= member then
            child.is_selected = false
        end
    end
end

