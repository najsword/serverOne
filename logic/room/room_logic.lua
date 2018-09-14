require "skynet.manager"
local skynet = require "skynet"
local context = require "context"
local random = require "random"
local utils = require "utils"
local cluster_monitor = require "cluster_monitor"
local db_helper = require "common.db_helper"
local game_config = require "config.game_config"
local room_config = require "config.game_room_config"
local game_room_config = require "config.game_room_config"
local cluster_config = require "config.cluster_config"
local room_logic = {}

local room_id
local room_conf
local game_conf

local server_id
local current_conf
local configs

local desk_pool = {}
local agent_pool = {}

local using_agents = {}  -- session : agent
local player_session_map = {} --player_id : session

local incr_group_id = 0
local using_desks = {} -- group_id : desksvc
local player_group_map = {} -- player_id : group_id
local group_players_map = {} -- group_id : { player_id }

local function init_desk_pool()
	local desk_count = skynet.getenv("init_desk_count")
	for i=1, desk_count do
		local desk_svc = skynet.launch("snlua", "desk", game_conf.module_name)
		context.call(desk_svc, "init", configs, room_id)
		table.insert(desk_pool, desk_svc)
	end
	collectgarbage("collect")
end

local function init_agent_pool()
	local agent_count = skynet.getenv("init_agent_count")
	for i=1, agent_count do
		local agent = skynet.launch("snlua", "agent")
		context.call(agent, "init", configs)
		table.insert(agent_pool, agent)
	end
end

local function init_desk()
	local desk
	if #desk_pool > 0 then
		desk = table.remove(desk_pool, #desk_pool)
	else
		desk = skynet.launch("snlua", "desk")
		context.call(desk, "init", configs, room_id)
	end
	return desk
end

local function init_agent(ctx)
	local agent
	if #agent_pool > 0 then
		agent = table.remove(agent_pool, #agent_pool)
	else
		-- agent = skynet.launch("snlua", "agent")
		agent = skynet.newservice("agent")
		context.call(agent, "init", configs)
	end
	return agent
end

-- local function init_room()
-- 	local room_inst_info = {
-- 		server_id = server_id,
-- 		room_id = room_id,
-- 		roomproxy = current_conf.nodename,
-- 		ver = current_conf.ver,
-- 		player_num = 0,
-- 		player_limit = game_room_config[room_id].player_limit,
-- 	}
-- 	db_helper.call(DB_SERVICE.game, "room.register_room", nil, room_inst_info)
-- end

local function get_incr_group_id()
	incr_group_id = incr_group_id + 1
	return incr_group_id
end

local function get_desk_by_group_id(group_id)
	if using_desks[group_id] then
		local desk = using_desks[group_id]
		local ec = context.call(desk, "can_group")
		return ec, using_desks[group_id]
	end
	local desk = init_desk()
	using_desks[group_id] = desk
	return true, desk
end

local function get_joinable_groupid_desk()
	local joinable_group_list = {}
	local ec, desk = nil
	for group_id, players in pairs(group_players_map) do
		if #players < room_conf.max_group_player then
			skynet.error("cy==================can groupid=", group_id)
		    ec, desk = get_desk_by_group_id(group_id)
			if ec == true then
				table.insert(joinable_group_list, { group_id = group_id, player_count = #players, desk = desk })
			end
		end
	end
	if table.empty(joinable_group_list) then
		local group_id = get_incr_group_id()
	    ec, desk = get_desk_by_group_id(group_id)
		return group_id, desk
	end
	local joinable_group = random.random_one(joinable_group_list)
	return joinable_group.group_id, joinable_group.desk
end

function room_logic.init(roomid)
	room_id = roomid
	room_conf = room_config[room_id]
    game_conf = game_config[room_conf.game_id]
	server_id = tonumber(skynet.getenv("cluster_server_id"))
	current_conf = cluster_monitor.get_current_node()
	configs = require("config."..game_conf.module_name.."_config")
	init_desk_pool()
	init_agent_pool()
	--init_room()
end

function room_logic.get_configs()
	return configs
end

function room_logic.update_configs(updates)
	for k, v in pairs(updates) do
		configs[k] = v
	end
end

function room_logic.check_enter_room(ctx, req)
    local reply = {}
    local player_online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", ctx.player_id)
    if tonumber(player_online.state) ~= ONLINE_STATE.onarea then
        skynet.error("[error]= player no in area")
        return GAME_ERROR.no_in_hall
    end
	if player_online.room_id and tonumber(player_online.room_id) ~= room_id then
		skynet.error("[error]= player enter err game/room")
		reply.room_id = tonumber(player_online.room_id)
		reply.roomproxy = player_online.agentnode
		local tmp_room_conf = room_config[tonumber(player_online.room_id)]
		if tmp_room_conf.game_id ~= room_conf.game_id then
			return GAME_ERROR.in_other_game, reply
		else
			return GAME_ERROR.in_other_room, reply
		end
	elseif player_online.agentnode and player_online.agentnode ~= current_conf.nodename then
		skynet.error("[error]= player enter err roomnode")
		reply.room_id = tonumber(player_online.room_id)
		reply.roomproxy = player_online.agentnode
		return GAME_ERROR.in_other_room_inst, reply
    end
    local old_session = player_session_map[ctx.player_id]
	if old_session then
		skynet.error("[error]= player enter err enter_room_double")
		return GAME_ERROR.enter_room_double
    end
    local player_info = db_helper.call(DB_SERVICE.agent, "player.get_player_info", ctx.player_id)
    if player_info.gold < room_conf.min_enter then
        skynet.error("[error]= player enter err gold_not_enough")
		return GAME_ERROR.gold_not_enough
	end
    return SYSTEM_ERROR.success,player_info
end

function room_logic.get_enter_room_reply()
    local reply = {}
	reply.room_id = room_id
	reply.roomproxy = current_conf.nodename
    return SYSTEM_ERROR.success, reply
end

function room_logic.change_enter_room_state(ctx, player_info)
	local agent = init_agent(ctx)
	using_agents[ctx.session] = agent
	player_session_map[ctx.player_id] = ctx.session
	context.call(agent, "login", ctx, player_info)
	context.rpc_call(ctx.gate, ctx.watchdog, "set_room_addr", ctx.fd, skynet.self())
	db_helper.call(DB_SERVICE.fd, "fd.set_fd", FD_TYPE.room, nil, server_id, room_id, skynet.self(), ctx.fd)
	--db_helper.call(DB_SERVICE.game, "room.player_enter_room", server_id)
	db_helper.call(DB_SERVICE.game, "room.incrby_player", server_id, room_id, skynet.self(), ctx.fd)
	local update_online_info = {
		room_id = room_id,
		state = ONLINE_STATE.onroom,
		roomaddr = skynet.self()
	}
    db_helper.call(DB_SERVICE.hall, "hall.set_player_online", ctx.player_id,  update_online_info)
end

function room_logic.change_exit_room_state(ctx, req)
    room_logic.logout_desk(ctx, req)
    local agent = using_agents[ctx.session]
	if  agent then
        context.call(agent, "logout", ctx)
        using_agents[ctx.session] = nil
        skynet.kill(agent)
	end
	player_session_map[ctx.player_id] = nil
	context.rpc_call(ctx.gate, ctx.watchdog, "set_room_addr", ctx.fd, nil)
	db_helper.call(DB_SERVICE.fd, "fd.unset_fd", FD_TYPE.room, nil, server_id, room_id, skynet.self(), ctx.fd)
	--db_helper.call(DB_SERVICE.game, "room.player_exit_room", server_id)
	db_helper.call(DB_SERVICE.game, "room.exit_room", server_id, room_id, skynet.self(), ctx.fd)
	db_helper.call(DB_SERVICE.hall, "hall.update_player_online", ctx.player_id, "state", ONLINE_STATE.onarea)
	db_helper.call(DB_SERVICE.hall, "hall.del_player_online_value", ctx.player_id, "roomaddr")
	return SYSTEM_ERROR.success
end

local function check_group_request(ctx, req)
    local agent = using_agents[ctx.session]
	if not agent then
		return GAME_ERROR.no_login_room
	end
    return SYSTEM_ERROR.success,agent
end

function room_logic.group_request(ctx, req)
	local err, agent = check_group_request(ctx, req)
	if  err ~= SYSTEM_ERROR.success then
		return err
	end
	local group_id, desk = get_joinable_groupid_desk()
	skynet.error("cy=============group_id desk=", group_id, desk)
	if room_conf.group_type == GROUP_TYPE.auto then
		group_players_map[group_id] = group_players_map[group_id] or {}
		table.insert(group_players_map[group_id], ctx.player_id)
		player_group_map[ctx.player_id] = group_id
		--local desk = get_desk_by_group_id(group_id)
		local ec = context.call(desk, "login_desk", ctx, agent)
		if ec ~= SYSTEM_ERROR.success then
			return ec
		end
	elseif room_conf.group_type == GROUP_TYPE.ready then

	end
	local update_online_info = {
		state = ONLINE_STATE.ongroup,
	}
    db_helper.call(DB_SERVICE.hall, "hall.set_player_online", ctx.player_id, update_online_info)
	return SYSTEM_ERROR.success
end

local function check_logout_desk(ctx, req)
	local agent = using_agents[ctx.session]
	if not agent then
		return GAME_ERROR.no_login_room
	end
	local group_id = player_group_map[ctx.player_id]
	if not group_id then
		return GAME_ERROR.no_login_desk
	end
	local desk = using_desks[group_id]
	if not desk then
		return GAME_ERROR.no_login_desk
    end
    return SYSTEM_ERROR.success, desk, group_id
end

function room_logic.logout_desk(ctx, req)
	local err, desk, group_id = check_logout_desk(ctx, req)
	if  err ~= SYSTEM_ERROR.success then
		return err
	end
	player_group_map[ctx.player_id] = nil
	utils.removebyvalue(group_players_map[group_id], ctx.player_id, false)
	local ec = context.call(desk, "logout_desk", ctx)
	if ec ~= SYSTEM_ERROR.success then
		return ec
	end
	local update_online_info = {
		state = ONLINE_STATE.onroom,
	}
    db_helper.call(DB_SERVICE.hall, "hall.set_player_online", ctx.player_id, update_online_info)
	return SYSTEM_ERROR.success
end

return room_logic