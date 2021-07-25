local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = package.path .. ';' .. path .. '?.lua'
package.path = package.path .. ';' .. path .. 'ReaWrap/models/?.lua'
require('ReaWrap.models')

local r = Reaper:new()
local p = Project:new()

for _, track in ipairs(p:get_selected_tracks()) do
    r:print(track)
end