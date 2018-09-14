local heartbeat_ctrl = require "heartbeat.heartbeat_ctrl"

local heartbeat_impl = {}


function heartbeat_impl.init()
    heartbeat_ctrl.init()
end

function heartbeat_impl.reset_updatetime(player_id)
    heartbeat_ctrl.reset_updatetime(player_id)
end

function heartbeat_impl.del_playerId(player_id)
    heartbeat_ctrl.del_playerId(player_id)
end

return heartbeat_impl