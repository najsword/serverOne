--[[
	@ filename : room.lua
	@ author   : zhangshiqian1214@163.com
	@ modify   : 2017-08-23 17:53
	@ company  : zhangshiqian1214
]]

require "skynet.manager"
local skynet  = require "skynet"
local service = require "service_base"
local room_ctrl = require "room.room_ctrl"
local room_impl = require "room.room_impl"
local command = service.command
local room_id = tonumber(...)

function command.enter_room(ctx, req)
	return room_ctrl.enter_room(ctx, req)
end

function command.exit_room(ctx, req)
	return room_ctrl.exit_room(ctx, req)
end

function command.logout_desk(ctx, req)
	return room_ctrl.logout_desk(ctx, req)
end

function service.on_start()
	--skynet.register(SERVICE.ROOM)
	room_ctrl.init(room_id)
end

service.modules.room = room_impl
service.start()