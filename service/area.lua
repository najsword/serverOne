require "skynet.manager"
local skynet  = require "skynet"
local service = require "service_base"
local area_ctrl = require "area.area_ctrl"
local area_impl = require "area.area_impl"
local command = service.command
local game_id = tonumber(...)

function command.enter_area(ctx, req)
	return area_ctrl.enter_area(ctx, req)
end

function command.exit_area(ctx, req)
	return area_ctrl.exit_area(ctx, req)
end

function command.create_role(ctx, req)
	return area_ctrl.create_role(ctx, req)
end

function command.get_role(ctx, req)
	return area_ctrl.get_role(ctx, req)
end

function command.get_room(room_id)
    return area_ctrl.get_room(room_id)
end

function command.enter_room(ctx, req)
    return area_ctrl.enter_room(ctx, req)
end

function service.on_start()
    skynet.register(SERVICE.AREA)
	area_ctrl.init(game_id)
end

service.modules.area = area_impl
service.start()