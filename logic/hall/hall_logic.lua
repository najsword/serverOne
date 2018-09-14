local skynet = require "skynet"
local context = require "context"
local utils = require "utils"
local cluster_monitor = require "cluster_monitor"
local db_helper = require "common.db_helper"
local hall_logic = {}

local current_conf
--local fd_playerid_map = {} --上层svc分块处理，不可以在这存内存数据

local function get_player_agent(player_id)
	local agent_count = skynet.getenv("agent_count")
	local index = toint(player_id % agent_count)
	if index == 0 then index = agent_count end
	return ".agent"..index
end

function hall_logic.init()
	current_conf = cluster_monitor.get_current_node()
end

function hall_logic.cast_logout(ctx, req)
	local player_id = ctx.player_id
	-- exit area
	local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", player_id)
	local state = tonumber(online.state)
	if state == ONLINE_STATE.onarea or state == ONLINE_STATE.onroom or state == ONLINE_STATE.ongroup then
		local area_node = cluster_monitor.get_cluster_node(online.agentnode)
		context.rpc_call(area_node.nodename, SERVICE.AREA, "exit_area", ctx, req)
		state = ONLINE_STATE.online
	end
	--exit hall
	if state == ONLINE_STATE.online then
		db_helper.call(DB_SERVICE.fd, "fd.unset_fd", FD_TYPE.hall, nil, nil, nil, nil, ctx.fd)
		db_helper.call(DB_SERVICE.hall, "hall.del_player_online_value", player_id, "hall_agentnode")
		db_helper.call(DB_SERVICE.hall, "hall.update_player_online", player_id, "state", ONLINE_STATE.offline)
		db_helper.call(DB_SERVICE.hall, "hall.update_player_online", player_id, "offline", OFFLINE_STATE.off)
	    local pack_info = {player_id = ctx.player_id}
		db_helper.call(DB_SERVICE.auth, "cache.remove_cache_info", pack_info)
		context.rpc_call(online.gate, online.watchdog, "logout", tonumber(online.fd))
	end
end

local function set_chat_ctx(ctx)
	local chat_node = cluster_monitor.get_cluster_node_by_server(SERVER.CHAT)
	if not chat_node then
		error("set_chat_ctx chat_node not online")
	end
	context.rpc_call(chat_node.nodename, SERVICE.CHAT, "set_ctx", ctx)
end

function hall_logic.cast_login(ctx, req)
	local player_id = req.player_id
	local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", player_id)
	if online and tonumber(online.state) ~= ONLINE_STATE.offline and tonumber(online.offline) ~= OFFLINE_STATE.on then
		if online.session == ctx.session then
			return
		end
		skynet.error("cy==============maybe kick_player fd=", online.fd)
		context.rpc_call(online.gate, online.watchdog, "player_leave", tonumber(online.fd))
	end
	local is_logined_game = false
	if online and online.agentnode and online.agentaddr then
		local agent_node_info = cluster_monitor.get_cluster_node(online.agentnode)
		if agent_node_info and agent_node_info.ver == tonumber(online.agentver) then
			is_logined_game = true
		else
			db_helper.call(DB_SERVICE.hall, "hall.del_player_online", player_id)
		end
	end
	online = online or {}
	online.session = ctx.session
	online.state = ONLINE_STATE.online
	online.player_id = player_id
	online.gate = ctx.gate
	online.watchdog = ctx.watchdog
	online.fd = ctx.fd
	online.ip = ctx.ip
	online.offline = OFFLINE_STATE.off
	db_helper.call(DB_SERVICE.hall, "hall.set_player_online", player_id, online)
	db_helper.call(DB_SERVICE.fd, "fd.set_fd", FD_TYPE.hall, nil, nil, nil, nil, ctx.fd)
	--db_helper.call(DB_SERVICE.hall, "hall.set_fd_playerid", online.fd, player_id)
	--大厅agent登录
	context.call(get_player_agent(player_id), "login", ctx, req)
	--设置chat ctx
	set_chat_ctx(ctx)
	if is_logined_game then
		context.rpc_call(online.agentnode, online.agentaddr, "login", ctx, req)
	end
end

function hall_logic.get_player_online_state(ctx, req)
	local player_id = ctx.player_id
	local player_online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", player_id)
	-- print("get_player_online_state =", table.tostring(player_online))
	return player_online
end

function hall_logic.get_room_inst_list(ctx, req)
	local room_id = req
	--local room_inst_list = db_helper.call(DB_SERVICE.game, "room.get_room_list", room_id)
	local reply = { room_insts = {} }

	-- for _, v in pairs(room_inst_list) do
	-- 	local room_nodeinfo = cluster_monitor.get_cluster_node(v.roomproxy)
	-- 	print("get_room_inst_list v.roomproxy=", v.roomproxy, "room_nodeinfo=", table.tostring(room_nodeinfo))
	-- 	if room_nodeinfo and room_nodeinfo.is_online == 1 and room_nodeinfo.ver == tonumber(v.ver) then
	-- 		table.insert(reply.room_insts, { roomproxy = v.roomproxy, player_num = v.player_num, player_limit = v.player_limit})
	-- 	end
	-- end
	return reply
end

return hall_logic