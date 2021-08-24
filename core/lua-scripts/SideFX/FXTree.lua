local info = debug.getinfo(3, "Sl")
if info.short_src == 'test_FXTree.lua' then
    local parent = package.path:gmatch("(.-)?.lua;")()
    package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
    package.path = package.path .. ';' .. parent .. 'utils/?.lua'
else
    act_ctx = ({ reaper.get_action_context() })[2]
    parent = act_ctx:match('(.+)SideFX/')
    package.path = package.path .. ';' .. parent .. '?.lua'
    package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
    package.path = package.path .. ';' .. parent .. 'utils/?.lua'
end

require('ReaWrap.models.helpers')
require('ReaWrap.models.constants')
require('tree')
require('maths')

local function serialize(o)
    local buffer = ''
    for k, v in pairs(o) do
        local vtype = type(v)
        if k == 'inputs' then
            buffer = buffer .. ('%s = {%s}'):format(k, table.concat(v, ', '))
        elseif k == 'outputs' then
            if v.dry ~= nil  and v.wet ~= nil then
                local dry = table.concat(v.dry, ', ')
                local wet = table.concat(v.wet, ', ')
                buffer = buffer .. ('%s = {dry = {%s}, wet = {%s}}'):format(k, dry, wet)
            else
                goto continue
            end
        elseif k == 'parent' then
            buffer = buffer .. ('%s = %q'):format(k, tostring(o.parent.id))
        elseif vtype == 'number' or vtype == 'boolean' then
            buffer = buffer .. ('%s = %s'):format(k, v)
        elseif vtype == 'string' then
            buffer = buffer .. ('%s = %q'):format(k, v)
        else
            goto continue
        end
        buffer = buffer .. ', '
        :: continue ::
    end
    return '{' .. buffer .. '}'
end

FXAttributes = {
    'bypass', 'mix', 'volume', 'pan', 'mute', 'solo', 'sidechain'
}

FXLeaf = Leaf:new()
---@param fx_guid string : The GUID of the FX wrapped by the leaf
function FXLeaf:new(fx_guid)
    local o = self:get_object(fx_guid)
    self.__index = self
    setmetatable(o, self)
    return o
end

function FXLeaf:get_object(fx_guid)
    local base_object = Leaf:get_object()
    base_object.ttype = 'FXLeaf'
    base_object.fx_guid = fx_guid
    base_object.is_selected = false
    for _, v in pairs(FXAttributes) do
        base_object[v] = ''
    end
    return base_object
end

function FXLeaf:__tostring()
    return ('FXLeaf %s'):format(self.id)
end

function FXLeaf:log(...)
    local logger = log_func('FXLeaf')
    logger(...)
end

---Return a reference to the fx object
---@param track table ReaWrap.Track
---@return table : ReaWrap.TrackFX
function FXLeaf:get_fx(track)
    return track:fx_from_guid(self.fx_guid)
end

---Get the name of the FX encapsulated by the leaf
---@return string
function FXLeaf:get_fx_name()
    local fx = self:get_fx()
    return fx:get_name()
end

---Get the idx of the FX encapsulated by the leaf
---@return number
function FXLeaf:get_fx_idx()
    return self:get_fx().idx
end


---placheholder
function set_node_outputs(node)
    local dry, wet
    if next(self.outputs) == nil then
        dry_exp = {2, 3}
        wet_exp = {4, 5}
    else
        local last_used = self.outputs[#self.outputs].wet_exp
        dry_exp = { last_used[1] + 2, last_used[2] + 2 }
        wet_exp = { last_used[1] + 4, last_used[2] + 4 }
    end
    dry = { math.floor(2 ^ dry_exp[1]), math.floor(2 ^ dry_exp[2]) }
    wet = { math.floor(2 ^ wet_exp[1]), math.floor(2 ^ wet_exp[2]) }
    table.insert(
            self.outputs,
            {
                dry_exp = dry_exp,
                wet_exp = wet_exp
            }
    )
    node.outputs = {dry = dry, wet = wet}
end


function set_summing_inputs(track)
    local l_bitmask, r_bitmask = 0, 0
    for _, out in ipairs(self.outputs) do
        l_bitmask = l_bitmask + math.floor(2 ^ out.dry_exp[1] + 2 ^ out.wet_exp[1])
        r_bitmask = r_bitmask + math.floor(2 ^ out.dry_exp[2] + 2 ^ out.wet_exp[2])
    end
    local summing_fx = self:get_summing(track)
    local input_pins = summing_fx:get_input_pins()
    input_pins[1]:set_mappings(l_bitmask)
    input_pins[2]:set_mappings(r_bitmask)
end

FXNode = Node:new()
function FXNode:new()
    local o = self.get_object()
    self.__index = self
    setmetatable(o, self)
    return o
end

function FXNode:get_object()
    local base_object = Node:get_object()
    base_object.ttype = 'FXNode'
    base_object.is_selected = false
    base_object.gain_guid = ''
    base_object.inputs = {}
    base_object.outputs = {}
    for _, k in ipairs(FXAttributes) do
        base_object[k] = ''
    end
    return base_object
end

function FXNode:__tostring()
    return ('FXNode %s'):format(self.id)
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
    while idx > 0 do
        local child = self.parent.children[idx]
        if child:is_leaf() then
            return child
        end
        idx = idx - 1
    end
    return nil
end

function FXNode:get_previous_sibling()
    local idx = self.parent:get_child_idx(self) - 1
    if idx > 0 then
        return self.parent.children[idx]
    end
end

function FXNode:set_io(track)
    local gain = track:fx_from_guid(self.gain_guid)
    self:set_fx_inputs(self.inputs, gain)
    self:set_fx_outputs(self.outputs.dry, gain)
    for i, child in ipairs(self.children) do
        if child:is_leaf() then
            local fx_obj = track:fx_from_guid(child.fx_guid)
            self:set_fx_inputs(self.inputs, fx_obj)
            self:set_fx_outputs(self.outputs.wet, fx_obj)
        end
    end
end

function FXNode:set_fx_inputs(inputs, fx)
    --- a plugin may have aux inputs, we only care about 1 and 2.
    local input_pins = fx:get_input_pins()
    for i = 1, 2 do
        input_pins[i]:set_mappings(inputs[i])
    end
end

function FXNode:set_fx_outputs(outputs, fx)
    --- a plugin may have multi outs, we only care about 1 and 2.
    local output_pins = fx:get_output_pins()
    for i = 1, 2 do
        output_pins[i]:set_mappings(outputs[i])
    end
end


FXRoot = Root:new()
function FXRoot:new()
    local o = self.get_object()
    o.ttype = 'FXRoot'
    o.is_selected = true
    self.__index = self
    setmetatable(o, self)
    return o
end

function FXRoot:__tostring()
    return ('FXRoot %s'):format(self.id)
end

function FXRoot:save_state()
    local buffer = serialize(self) .. '; '
    for c, l in traverse_tree(self.children) do
        buffer = buffer .. serialize(c) .. '; '
    end
    return buffer
end

local function get_constructor(ttype)
    if ttype == 'FXRoot' then
        return FXRoot
    elseif ttype == 'FXBranch' then
        return FXBranch
    elseif ttype == 'FXNode' then
        return FXNode
    elseif ttype == 'FXLeaf' then
        return FXLeaf
    end
end

local function load_object_state(constructor, data)
    local object = constructor:new()
    for k, v in pairs(data) do
        object[k] = v
    end
    return object
end

function load_state(state_string, track)
    local constructor, o_type, object, root
    local objects = {}
    for line in state_string:gmatch("([^;]+)") do
        line = 'return ' .. line
        local member = load(line)()
        if member ~= nil then
            constructor = get_constructor(member.ttype)
            object = load_object_state(constructor, member)
            objects[object.id] = object
            o_type = object.ttype
            if o_type == 'FXRoot' then
                root = object
            elseif o_type == 'FXBranch' or o_type == 'FXNode' or o_type == 'FXLeaf' then
                local parent = objects[object.parent]
                parent:add_child(object)
            end
        end
    end
    return root
end

local function fx_is_valid(track, guid)
    return track:fx_from_guid(guid) ~= nil
end

FXTree = {}

function FXTree:new(project, track)
    local o = {
        id = uuid4(),
        ttype = 'FXTree',
        root = FXRoot:new(),
        project = project,
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
        local fx_leaf = FXLeaf:new(fx:GUID())
        self.root:add_child(fx_leaf)
    end
end

function FXTree:traverse()
    return traverse_tree(self.root.children)
end

function FXTree:fx_is_valid(fx_guid)
    local v = self.track:fx_from_guid(fx_guid) ~= nil
    return v
end

---@param plugin_name string
---@param position number
---@return table the TrackFX object
function FXTree:add_fx_plugin(plugin_name, position)
    position = position or -1
    position = 1000 + position
    return self.track:fx_add_by_name(plugin_name, false, -position)
end

function FXTree:add_gain_fx(position)
    return self:add_fx_plugin('SideFX - Gain', position)
end

function FXTree:add_summing_fx(position)
    return self:add_fx_plugin('SideFX - Summing', position)
end

function FXTree:remove_fx(member)
    local fx_idx = member:get_fx_idx()
    self.track:fx_delete(fx_idx)
    self:remove_child(member)
    self:save_state()
end

function FXTree:remove_child(member)
    member.parent:remove_child(member)
end


function FXTree:remove_parallel_chain(member)
    local branch = member.parent
    local summing = self.track:fx_from_guid(branch.summing_guid)
    self.track:fx_delete(summing.idx)
    self:log(member.gain_guid)
    local gain = self.track:fx_from_guid(member.gain_guid)
    self.track:fx_delete(gain.idx)
    for i, child in ipairs(member.children) do
        local fx = self.track:fx_from_guid(child.fx_guid)
        self.track:fx_delete(fx.idx)
    end
    branch:remove_child(node)
    if branch:is_only_child() then
        self:remove_child(branch)
    end
    self:set_io()
end

---@param member table
---@param mode number : 0 for serial 1 for parallel
function FXTree:add_fx(member, mode, plugin)
    local leaf
    if mode == 0 then
        if member:is_root() then
            local fx_guid = self:add_fx_plugin(plugin.name):GUID()
            leaf = FXLeaf:new(fx_guid)
            member:add_child(leaf)
        elseif member:is_node() then
            local member_idx = member.parent:get_child_idx(member)
            local previous_leaf = member:get_previous_leaf_sibling()
            if previous_leaf == nil then
                local fx_guid = self:add_fx_plugin(plugin.name):GUID()
                leaf = FXLeaf:new(fx_guid)
                member.parent:add_child(leaf)
            else
                local last_fx_idx = previous_leaf:get_fx_idx()
                local fx_guid = self:add_fx_plugin(plugin.name, last_fx_idx + 1):GUID()
                leaf = FXLeaf:new(fx_guid, self.track)
                member.parent:add_child(leaf, member_idx + 1)
            end
        else
            local member_idx = member.parent:get_child_idx(member)
            local fx_idx = member:get_fx_idx()
            local fx_guid = self:add_fx_plugin(plugin.name, fx_idx + 1):GUID()
            leaf = FXLeaf:new(fx_guid)
            member.parent:add_child(leaf, member_idx + 1)
        end
    elseif mode == 1 then

    end
    leaf.is_selected = true
    self:deselect_all_except(leaf)
    --self:save_state()
end

---@param channels number (even numbers up to 64)
function FXTree:set_channels(channels)
    self.track:set_info_value(TrackInfoValue.I_NCHAN, channels)
end


function FXTree:set_io()
    for i, child in ipairs(self.root.children) do
        if child.ttype == 'FXBranch' then
            child:set_io(self.track)
        end
    end
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
    local state = self.root:save_state()
    self.project:set_ext_state('FXTree', self.track:GUID(), state)
end

---@param track table : ReaWrap.Track
---@return table: FXTree
function FXTree:load_state(project, track)
    local tree = self:new(project, track)
    local state_string = project:get_ext_state('FXTree', track:GUID())
    local root = load_state(state_string, track)
    if root ~= nil then
        tree.root = root
    end
    return tree
end
