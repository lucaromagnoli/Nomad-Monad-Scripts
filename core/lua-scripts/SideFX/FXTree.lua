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

require('ReaWrap.models.project')
require('ReaWrap.models.reaper')
require('tree')

local r = Reaper:new()
local p = Project:new()

FXLeaf = Leaf:new()
---@param fx any
function FXLeaf:new(fx)
    local o = self.get_object()
    o.fx = fx
    self.__index = self
    setmetatable(o, self)
    return o
end

FXRoot = Root:new()
function FXRoot:new()
    local o = self.get_object()
    self.__index = self
    setmetatable(o, self)
    return o
end


FXNode = Node:new()
function FXNode:new()
    local o = self.get_object()
    self.__index = self
    setmetatable(o, self)
    return o
end
