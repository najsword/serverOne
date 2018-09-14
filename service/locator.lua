require "skynet.manager"
local skynet  = require "skynet"
local service = require "service_base"
local locator_ctrl = require "locator.locator_ctrl"
local locator_impl = require "locator.locator_impl"
local command = service.command

function command.route_sid(req)
    return locator_ctrl.route_sid(req.game_id)
end

function command.register_start_info(server_id)
    return locator_ctrl.register_start_info(server_id)
end

function service.on_start()
	skynet.register(SERVICE.LOCATOR)
	locator_ctrl.init()
end

service.modules.locator = locator_impl
service.start()