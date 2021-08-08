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
    o.splitter = nil
    o.mixer = nil
    self.__index = self
    setmetatable(o, self)
    return o
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
