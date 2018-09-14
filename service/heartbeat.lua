require "skynet.manager"
local skynet  = require "skynet"
local service = require "service_base"
local heartbeat_ctrl = require "heartbeat.heartbeat_ctrl"
local heartbeat_impl = require "heartbeat.heartbeat_impl"
local command = service.command

function command.reset_updatetime(player_id)
    return heartbeat_ctrl.reset_updatetime(player_id)
end

function command.del_playerId(player_id)
    return heartbeat_ctrl.del_playerId(player_id)
end

function service.on_start()
	skynet.register(SERVICE.HEARTBEAT)
	heartbeat_ctrl.init()
end

service.modules.heartbeat = heartbeat_impl
service.start()