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
---@param fx_guid string : The GUID of the FX wrapped by the leaf
---@param track table : ReaWrap.Track
function FXLeaf:new(fx_guid, track)
    if track == nil then
        error('Please provide a track object to create a new FXLeaf instance')
    end
    local o = self.get_object()
    o.fx_guid = fx_guid
    o.track = track
    self.__index = self
    setmetatable(o, self)
    return o
end

function FXLeaf:__tostring()
    return string.format(self:get_fx_name())
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

---Return a reference to the fx object
---@return table : ReaWrap.TrackFX
function FXLeaf:get_fx()
    return self.track:fx_from_guid(self.fx_guid)
end


---Get the name of the FX encapsulated by the leaf
---@return string
function FXLeaf:get_fx_name()
    local fx = self:get_fx()
    return fx:get_name()
end

function FXLeaf:get_fx_idx()
    return self:get_fx().idx
end


function FXLeaf:save_state()
    return ('{id = %s , fx = %d}'):format(self.id, self.fx.idx)
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

local function save_state(o)
    local function save_children_state(children, buffer)
        for _, c in ipairs(children) do
            if c:has_children() then
                buffer = save_children_state(c.children, buffer)
            else
                buffer = buffer .. c:save_state() .. ', '
            end
        end
        return buffer
    end
    if o:has_children() then
        children_buffer = save_children_state(o.children, '')
    end

    return ('{ id = %s, is_selected = %s , children = { %s } }'):format(
            o.id,
            o.is_selected,
            children_buffer
    )
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

function FXRoot:save_state()
    return save_state(self)
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
    return string.format('Parallel Chain')
end

---Get the index of the last FX nested under the node
---@return number
function FXNode:get_last_fx_idx()
    local function _get_last_fx_idx(children)
        local last_child = children[#children]
        if last_child:is_leaf() then
            return last_child.fx.idx
        else
            return _get_last_fx_idx(last_child.children)
        end
    end
    return _get_last_fx_idx(self.children)
end

function FXNode:get_previous_leaf_sibling()
    local idx = self.parent:get_child_idx(self) - 1 --previous sibling
    local continue = true
    while idx >= 0 do
        local child = self.parent[idx]
        if child:is_leaf() then
            return child
        end
        idx = idx - 1
    end
    return nil
end

function FXNode:save_state()
    return save_state(self)
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

function FXTree:__tostring()
    return string.format('FXTree %s', self.track:get_name())
end

function FXTree:init()
    for fx in self.track:iter_fx_chain() do
        local fx_leaf = FXLeaf:new(fx)
        self.root:add_child(fx_leaf)
    end
end

function FXTree:traverse()
    return traverse_tree(self.root.children)
end

---@param member table
---@param mode number : 0 for serial 1 for parallel
function FXTree:add_fx(member, mode, plugin)
    if mode == 0 then
        if member:is_root() then
            self:log('member is root')
            local fx_guid = self:add_fx_plugin(plugin)
            local leaf = FXLeaf:new(fx_guid, self.track)
            member:add_child(leaf)
            leaf.is_selected = true
            self:deselect_all_except(leaf)
            --self:save_state()
        elseif member:is_node() then
            self:log('member is node')
            local member_idx = member.parent:get_child_idx(member)
            local previous_leaf = member:get_previous_leaf_sibling()
            if previous_leaf == nil then
                local fx_guid = self:add_fx_plugin(plugin)
                local leaf = FXLeaf:new(fx_guid, self.track)
                member.parent:add_child(leaf)
                leaf.is_selected = true
                self:deselect_all_except(leaf)
            else
                local last_fx_idx = previous_leaf:get_fx_idx()
                local fx_guid = self:add_fx_plugin(plugin, last_fx_idx + 1)
                local leaf = FXLeaf:new(fx_guid, self.track)
                member.parent:add_child(leaf, member_idx + 1)
                leaf.is_selected = true
                self:deselect_all_except(leaf)
            end
        else
            self:log('member is leaf')
            local member_idx = member.parent:get_child_idx(member)
            local fx_idx = member:get_fx_idx()
            local fx_guid = self:add_fx_plugin(plugin, fx_idx + 1)
            local leaf = FXLeaf:new(fx_guid, self.track)
            member.parent:add_child(leaf, member_idx + 1)
            leaf.is_selected = true
            self:deselect_all_except(leaf)
        end
    elseif mode == 1 then
        if member:is_leaf() then
            member_idx = member.parent:get_child_idx(member)
            node = FXNode:new()
            node:add_child(leaf)
            member.parent:add_child(node, member_idx + 1)
            leaf.is_selected = true
            self:deselect_all_except(leaf)
        else
            node = FXNode:new()
            node:add_child(leaf)
            member:add_child(node)
            leaf.is_selected = true
            self:deselect_all_except(leaf)
        end
    end
end

---@param plugin table
---@param position number
function FXTree:add_fx_plugin(plugin, position)
    position = position or -1
    position = 1000 + position
    local fx = self.track:fx_add_by_name(plugin.name, false, -position)
    return fx:GUID()
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

function FXTree:save_state()
    local buffer = self.root:save_state()
    --self.track:set_state_chunk(buffer)
    self:log(buffer)
end

function FXTree:load_state()
    local o = self:new()
end
