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
require('binary')


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
    if not self.parent:has_children() then
        return nil
    end
    local idx = self.parent:get_child_idx(self) - 1 --previous sibling
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
            local fx_guid = self:add_fx_plugin(plugin):GUID()
            leaf = FXLeaf:new(fx_guid, self.track)
            member:add_child(leaf)
        elseif member:is_node() then
            local member_idx = member.parent:get_child_idx(member)
            local previous_leaf = member:get_previous_leaf_sibling()
            if previous_leaf == nil then
                local fx_guid = self:add_fx_plugin(plugin):GUID()
                leaf = FXLeaf:new(fx_guid, self.track)
                member.parent:add_child(leaf)
            else
                local last_fx_idx = previous_leaf:get_fx_idx()
                local fx_guid = self:add_fx_plugin(plugin, last_fx_idx + 1):GUID()
                leaf = FXLeaf:new(fx_guid, self.track)
                member.parent:add_child(leaf, member_idx + 1)
            end
        else
            local member_idx = member.parent:get_child_idx(member)
            local fx_idx = member:get_fx_idx()
            local fx_guid = self:add_fx_plugin(plugin, fx_idx + 1):GUID()
            leaf = FXLeaf:new(fx_guid, self.track)
            member.parent:add_child(leaf, member_idx + 1)
        end
    elseif mode == 1 then
        if member:is_root() or member:is_node() then
            self:new_node(member)
        else

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

---@param plugin table
---@param position number
---@return table the TrackFX object
function FXTree:add_fx_plugin(plugin, position)
    position = position or -1
    position = 1000 + position
    return self.track:fx_add_by_name(plugin.name, false, -position)
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

function FXTree:new_node(parent)
    local node = FXNode:new()
    parent:add_child(node)
    local prev_leaf = node:get_previous_leaf_sibling()
    local prev_idx = prev_leaf:get_fx_idx()
    node.inputs = self:get_inputs(prev_leaf)
    node.outputs = self:get_outputs(node.inputs)
    node_gain = self:add_fx_plugin('JS: SideFX - Gain', prev_idx + 1)
    node.gain = node_gain:GUID()
    self:set_gain_inputs(node_gain)
    self:set_gain_outputs(node_gain)
    node_summing = self:add_fx_plugin('JS: SideFX - Summing', prev_idx + 1)
    self:set_summing_inputs(node_summing)
    self:set_summing_outputs(node_summing)
    node.summing = node_summing:GUID()
end

---A node takes its inputs from the previous fx in the chain
function FXTree:get_inputs(sibling)
    local outputs = {}
    local fx = sibling:get_fx()
    local out_pins = fx:get_output_pins()
    for _, o in ipairs(out_pins) do
        local m, _ = o:get_mappings()
        local b = Binary:from_decimal(m)
        local bits_indices = b:to_bits_indices()
        outputs[#outputs + 1] = bits_indices
    end
    return self:transform_inputs(outputs)
end

---Validate inputs and return them as a two items table {l, r}
function FXTree:transform_inputs(outputs)
    local out_1 = outputs[1]  --left
    local out_2 = outputs[2]  --right
    --- there should be only one output per channel
    assert(#out_1 == 1)
    assert(#out_2 == 2)
    --- difference between left and right should be 1, e.g. left 1 right 2
    assert(out_2[1] - out_1[1] == 1)
    return {out_1[1], out_2[1]}
end

---A node has 2 stereo outputs in total. One for the dry signal, one for the fxchain.
---The dry signal outputs on the two channels subsequent to the input and the fx signal on the
---two channels subsequent to the dry signal. E.g. If the input is 1-2 then the dry output
---will be on 3-4 and the fx output will be on 5-6.
function FXTree:get_outputs(inputs)
    dry_l = inputs[1] + 2
    dry_r = inputs[2] + 2
    fx_l = dry_l + 2
    fx_r = dry_r + 2
    return {{dry_l, dry_r}, {fx_l, fx_r}}
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
