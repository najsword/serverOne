require "skynet.manager"
local skynet = require "skynet"
local context = require "context"
local db_helper = require "common.db_helper"
local role_ctrl = require "role.role_ctrl"
local area_logic = {}

function area_logic.enter_area(ctx, req)
    local current_conf = req.current_conf
    local update_online_info = {
        state = ONLINE_STATE.onarea,
        agentnode = current_conf.nodename,
        agentver = current_conf.ver,
        server_id = req.server_id,
        game_id = req.game_id,
    }
    db_helper.call(DB_SERVICE.fd, "fd.set_fd", FD_TYPE.area, req.game_id, req.server_id, nil, nil, ctx.fd)
    db_helper.call(DB_SERVICE.hall, "hall.set_player_online", ctx.player_id, update_online_info)
    db_helper.call(DB_SERVICE.game, "room.server_incrby_fd", req.game_id, req.server_id, ctx.fd)
    context.rpc_call(ctx.gate, ctx.watchdog, "enter_area", ctx.fd, current_conf.nodename, current_conf.ver, req.game_id)
    return SYSTEM_ERROR.success
end

local function _exit_room(ctx, req)
    local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", ctx.player_id)
    local room_addr = tonumber(online.roomaddr)
	context.call(room_addr, "exit_room", ctx, req)
end

local function _exit_area(ctx, req)
    db_helper.call(DB_SERVICE.fd, "fd.unset_fd", FD_TYPE.area, req.game_id, req.server_id, nil, nil, ctx.fd)
    db_helper.call(DB_SERVICE.hall, "hall.update_player_online", ctx.player_id, "state", ONLINE_STATE.online)
    db_helper.call(DB_SERVICE.hall, "hall.del_player_online_value", ctx.player_id, "game_id")
    db_helper.call(DB_SERVICE.hall, "hall.del_player_online_value", ctx.player_id, "server_id")
    db_helper.call(DB_SERVICE.hall, "hall.del_player_online_value", ctx.player_id, "role_id")
    db_helper.call(DB_SERVICE.hall, "hall.del_player_online_value", ctx.player_id, "agentnode")
    db_helper.call(DB_SERVICE.hall, "hall.del_player_online_value", ctx.player_id, "agentver")
    db_helper.call(DB_SERVICE.game, "room.exit_area", req.game_id, req.server_id, ctx.fd)
    context.rpc_call(ctx.gate, ctx.watchdog, "exit_area", ctx.fd)
end

function area_logic.exit_area(ctx, req)
    local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", ctx.player_id)
    local state = tonumber(online.state)
    if state == ONLINE_STATE.onroom or state == ONLINE_STATE.ongroup then
        _exit_room(ctx, req)
        _exit_area(ctx, req)
    end
    if state == ONLINE_STATE.onarea then
        _exit_area(ctx, req)
    end
    return SYSTEM_ERROR.success
end

function area_logic.get_role(ctx, req)
    local ec, role_id = role_ctrl.get_role(ctx, req)
    if ec ~= SYSTEM_ERROR.success then
        return ec
    end
    db_helper.call(DB_SERVICE.hall, "hall.update_player_online", ctx.player_id, "role_id", role_id)
    context.rpc_call(ctx.gate, ctx.watchdog, "set_role_id", ctx.fd, role_id)
    return SYSTEM_ERROR.success
end

function area_logic.create_role(ctx, req)
    local ec, role_id = role_ctrl.create_role(ctx, req)
    if ec ~= SYSTEM_ERROR.success then
        return ec
    end
    db_helper.call(DB_SERVICE.hall, "hall.update_player_online", ctx.player_id, "role_id", role_id)
    context.rpc_call(ctx.gate, ctx.watchdog, "set_role_id", ctx.fd, role_id)
	return SYSTEM_ERROR.success
end

return area_logic