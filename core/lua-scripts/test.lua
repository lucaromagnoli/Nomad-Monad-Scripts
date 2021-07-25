local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = package.path .. ';' .. path .. '?.lua'
package.path = package.path .. ';' .. path .. 'ReaWrap/models/?.lua'
require('ReaWrap.models')
