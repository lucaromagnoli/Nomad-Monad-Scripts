local act_ctx = ({ reaper.get_action_context() })[2]
local parent = act_ctx:match('(.+)SideFX/')
package.path = package.path .. ';' .. parent .. '?.lua'
package.path = package.path .. ';' .. parent .. 'ReaWrap/models/?.lua'
package.path = package.path .. ';' .. parent .. 'utils/?.lua'
package.path = package.path .. ';' .. parent .. 'SideFX/?.lua'
require('ReaWrap.models.reaper')
require('ReaWrap.models.project')
require('ReaWrap.models.constants')
require('utils.plugin')
require('FXTree')

local reawrap = Reaper:new()
local project = Project:new()
local rsrc_path = reawrap:get_resource_path()
for track in project:iter_selected_tracks() do
    track:set_info_value(TrackInfoValue.I_NCHAN, 128)
    for fx in track:iter_fx_chain() do
        for pin in fx:iter_input_pins() do
            reawrap:print(pin)
            reawrap:print(pin:get_mappings())
        end
        for pin in fx:iter_output_pins() do
            reawrap:print(pin)
            reawrap:print(pin:get_mappings())
        end
        --in_pins = fx:get_input_pins()
        --in_pins[1]:set_mappings(4)
        --in_pins[2]:set_mappings(8)
        --out_pins = fx:get_output_pins()
        --out_pins[1]:set_mappings(4)
        --out_pins[2]:set_mappings(8)
    end
end
