require "skynet.manager"
local skynet = require "skynet"
local room_logic = require "room.room_logic"
local room_ctrl = {}


function room_ctrl.init(room_id)
	room_logic.init(room_id)
end

function room_ctrl.enter_room(ctx, req)
	local code, reply_data = room_logic.check_enter_room(ctx, req)
	if code ~= SYSTEM_ERROR.success then
		return code, reply_data
	end
	local player_info = reply_data
	room_logic.change_enter_room_state(ctx, player_info)
	return room_logic.get_enter_room_reply()
end

function room_ctrl.exit_room(ctx, req)
	return room_logic.change_exit_room_state(ctx, req)
end

function room_ctrl.group_request(ctx, req)
	return room_logic.group_request(ctx, req)
end

function room_ctrl.logout_desk(ctx, req)
	return room_logic.logout_desk(ctx, req)
end


return room_ctrl