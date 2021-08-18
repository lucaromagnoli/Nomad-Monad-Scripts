local info = debug.getinfo(3, "Sl")
if info.short_src ==  'test_FXTree.lua' then
    local l_path = package.path:gmatch("(.-)?.lua;")()
    package.path = package.path .. ';' .. l_path .. 'ReaWrap/models/?.lua'
else
    act_ctx = ({ reaper.get_action_context() })[2]
    parent = act_ctx:match('(.+)SideFX/')
    package.path = package.path .. ';' .. parent .. '?.lua'
    package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
    package.path = package.path .. ';' .. parent .. 'utils/?.lua'
end

require('ReaWrap.models.helpers')
require('tree')
require('maths')


FXAttributes = {
    'bypass', 'mix', 'volume', 'pan', 'mute', 'solo', 'sidechain'
}

FXLeaf = Leaf:new()
---@param fx_guid string : The GUID of the FX wrapped by the leaf
---@param track table : ReaWrap.Track
function FXLeaf:new(fx_guid, track)
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

---Get the idx of the FX encapsulated by the leaf
---@return number
function FXLeaf:get_fx_idx()
    return self:get_fx().idx
end

function FXLeaf:save_state()
    return ('{id = "%s" , fx_guid = "%s", is_selected = "%s", type_ = "%s"}'):format(
            self.id, self.fx_guid, self.is_selected, self:get_type()
    )
end


---Save object state. Applies to Root and Node.
---@param o table
---@return string
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

    return ('return { id = "%s", is_selected = %s, type = "%s", children = { %s } }'):format(
            o.id,
            o.is_selected,
            o:get_type(),
            children_buffer
    )
end


FXRoot = Root:new()
function FXRoot:new()
    local o = self.get_object()
    o.is_selected = true
    self.__index = self
    setmetatable(o, self)
    return o
end

function FXRoot:__tostring()
    return string.format('FXRoot %s', self.id)
end

function FXRoot:get_type()
    return 'FXRoot'
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

function FXNode:get_object()
    local base_object = Node:get_object()
    base_object.is_selected = false
    base_object.gain = nil
    base_object.summing = nil
    base_object.inputs = {}
    base_object.outputs = {}
    for _, k in ipairs(FXAttributes) do
        base_object[k] = nil
    end
    return base_object
end

function FXNode:__tostring()
    return string.format('Parallel Chain')
end

function FXNode:get_type()
    return 'FXNode'
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


local function fx_is_valid(track, guid)
    return track:fx_from_guid(guid) ~= nil
end

FXTree = {}

function FXTree:new(project, track)
    local o = {
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
    return fx_is_valid(self.track, fx_guid)
end

---@param member table
---@param mode number : 0 for serial 1 for parallel
function FXTree:add_fx(member, mode, plugin)
    local leaf
    if mode == 0 then
        if member:is_root() then
            local fx_guid = self:add_fx_plugin(plugin.name):GUID()
            leaf = FXLeaf:new(fx_guid, self.track)
            member:add_child(leaf)
        elseif member:is_node() then
            local member_idx = member.parent:get_child_idx(member)
            local previous_leaf = member:get_previous_leaf_sibling()
            if previous_leaf == nil then
                local fx_guid = self:add_fx_plugin(plugin.name):GUID()
                leaf = FXLeaf:new(fx_guid, self.track)
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
            leaf = FXLeaf:new(fx_guid, self.track)
            member.parent:add_child(leaf, member_idx + 1)
        end
    elseif mode == 1 then
        if member:is_root() or member:is_node() then
            leaf = self:new_parallel_chain(member, plugin)
        end
        --if member:is_leaf() then
        --    member_idx = member.parent:get_child_idx(member)
        --    node = FXNode:new()
        --    node:add_child(leaf)
        --    member.parent:add_child(node, member_idx + 1)
        --else
        --    node = FXNode:new()
        --    node:add_child(leaf)
        --    member:add_child(node)
        --end
    end
    leaf.is_selected = true
    self:deselect_all_except(leaf)
    self:save_state()
end

---@param plugin_name string
---@param position number
---@return table the TrackFX object
function FXTree:add_fx_plugin(plugin_name, position)
    position = position or -1
    position = 1000 + position
    return self.track:fx_add_by_name(plugin_name, false, -position)
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


function FXTree:new_parallel_chain(parent, plugin)
    local node = FXNode:new()
    parent:add_child(node)
    local prev_leaf = node:get_previous_leaf_sibling()
    if prev_leaf ~= nil then
        local next_idx = prev_leaf:get_fx_idx() + 1
        node.inputs = self:get_node_inputs(prev_leaf)
    else
        node.inputs = {1, 2}
        next_idx = 0
    end
    node.outputs = self:get_node_outputs(node.inputs)
    node_gain = self:add_fx_plugin('SideFX - Gain', next_idx)
    node.gain = node_gain:GUID()
    self:set_node_fx_inputs(node.inputs, node_gain)
    self:set_node_fx_outputs(node.outputs.dry, node_gain)
    node_summing = self:add_fx_plugin('SideFX - Summing', node_gain.idx + 1)
    self:set_node_summing_inputs(node.outputs, node_summing)
    self:set_node_fx_outputs(node.inputs, node_summing)
    node.summing = node_summing:GUID()
    local fx = self:add_fx_plugin(plugin.name, node_gain.idx + 1)
    self:set_node_fx_inputs(node.inputs, fx)
    self:set_node_fx_outputs(node.outputs.wet, fx)
    return FXLeaf:new(fx:GUID(), self.track)
end

---A node takes its inputs from the previous fx in the chain, or from 1,2 if the
---parent is root
---@param sibling table Leaf
---@return table
function FXTree:get_node_inputs(sibling)
    local fx = sibling:get_fx()
    local out_pins = fx:get_output_pins()
    local inputs = {}
    for _, o in ipairs(out_pins) do
        local m, _ = o:get_mappings()
        local l = log_base(m, 2)
        local lfloor = math.floor(l)
        --- we are only expecting a single pin per channel
        assert(l == lfloor)
        inputs[#inputs + 1] = lfloor
    end
    -- left and right should be contiguous
    assert(inputs[2] - inputs[1] == 1)
    return inputs
end

---A node has 2 stereo outputs in total. One for the dry signal, one for the fxchain.
---The dry signal outputs on the two channels subsequent to the input and the fx signal on the
---two channels subsequent to the dry signal. E.g. If the input is 1-2 then the dry output
---will be on 3-4 and the fx output will be on 5-6. This function returns the final bitmask
---for left and right, which is the sum of dry and fx for each channel.
function FXTree:get_node_outputs(inputs)
    dry_l = inputs[1] + 2
    dry_r = inputs[2] + 2
    fx_l = dry_l + 2
    fx_r = dry_r + 2
    return {
        dry = { math.floor( 2 ^ (dry_l - 1)), math.floor(2 ^ (dry_r - 1)) },
        wet = { math.floor(2 ^ (fx_l - 1)), math.floor(2 ^ (fx_r - 1)) },
    }
end

function FXTree:set_node_fx_inputs(inputs, fx)
    --- a plugin may have aux inputs, we only care about 1 and 2.
    local input_pins = fx:get_input_pins()
    for i=1, 2 do
        input_pins[i]:set_mappings(inputs[i])
    end
end

function FXTree:set_node_fx_outputs(outputs, fx)
    --- a plugin may have multi outs, we only care about 1 and 2.
    local output_pins = fx:get_output_pins()
    for i=1, 2 do
        output_pins[i]:set_mappings(outputs[i])
    end
end


function FXTree:set_node_summing_inputs(outputs, summing)
    local inputs = {
        outputs.dry[1] + outputs.wet[1],
        outputs.dry[2] + outputs.wet[2]
    }
    self:set_node_fx_inputs(inputs, summing)
end

---Summing will output on the same pins as the main inputs
function FXTree:set_node_summing_outputs(inputs, summing)
    self:set_node_fx_outputs(inputs, summing)
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
    local state_string = project:get_ext_state('FXTree', track:GUID())
    root = load_state(state_string, track)
    local tree = FXTree:new(project, track)
    tree.root = root
    return tree
end

TypesTable = {
    FXRoot = FXRoot,
    FXNode = FXNode,
    FXLeaf = FXLeaf
}


local function recurse_children(src_tbl, parent, track)
    for i, c in ipairs(src_tbl) do
        local ttype = TypesTable[c.type_]
        local obj = ttype:new()
        if obj:is_leaf() and fx_is_valid(track, c.fx_guid) then
            obj.fx_guid = c.fx_guid
            obj.track = track
        else
            goto continue
        end
        table.insert(parent.children, obj)
        obj.parent = parent
        obj.id = c.id
        obj.is_selected = c.is_selected == 'true'
        if c.children ~= nil then
            recurse_children(c.children, obj, track)
        end
        ::continue::
    end
end

function load_state(state_string, track)
    local state_table = load(state_string)()
    root = FXRoot:new()
    if state_table ~= nil then
        local children = {}
        root.id = state_table.id
        root.children = children
        if state_table.children ~= nil then
            recurse_children(state_table.children, root, track)
        end
    end
    return root
end
