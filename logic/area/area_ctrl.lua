require "skynet.manager"
local skynet = require "skynet"
local context = require "context"
local db_helper = require "common.db_helper"
local cluster_monitor = require "cluster_monitor"
local game_room_config = require "config.game_room_config"
local server_id = tonumber(skynet.getenv("cluster_server_id"))
local area_logic = require "area.area_logic"
local area_ctrl = {}

local logic_svc_pool = {}
local logic_svc_index = 1

local room_id_list = {}  -- {room_id}
local current_conf
local game_id


local function init_logic_pool()
	local logic_count = skynet.getenv("area_logic_count")
	for i=1, logic_count do
		local svc = skynet.newservice("area_logic_svc")
		logic_svc_pool[#logic_svc_pool + 1] = svc
	end
end

local function get_logic_svc()
	local svc = logic_svc_pool[logic_svc_index]
	logic_svc_index = logic_svc_index + 1
	if logic_svc_index > #logic_svc_pool then
		logic_svc_index = 1
	end
	return svc
end

local function create_room()
    for room_id, v in pairs(game_room_config) do
        if v.game_id == game_id then
			local addr = skynet.newservice("room", room_id)
			table.insert(room_id_list, room_id)
			db_helper.call(DB_SERVICE.game, "room.register_room_info", server_id, room_id, addr)
        end
    end
end

local function create_room_by_room_id(room_id)
	local addr = skynet.newservice("room", room_id)
	db_helper.call(DB_SERVICE.game, "room.register_room_info", server_id, room_id, addr)
	return addr
end

local function register_server(server_id)	
	local locator_node = cluster_monitor.get_cluster_node_by_server(SERVER.LOCATOR)
	if not locator_node then
		error("register_server locatorserver not online")
	end
	context.rpc_call(locator_node.nodename, SERVICE.LOCATOR, "register_start_info", server_id)
end

function area_ctrl.init(gameid)
	game_id = gameid
	current_conf = cluster_monitor.get_current_node()
	init_logic_pool()
	create_room()
	register_server(server_id)	
end

function area_ctrl.get_room(room_id)
	--return room_addr_map[room_id]
end

function area_ctrl.enter_area(ctx, req)
	local svc = get_logic_svc()
	req = req or {}
	req.current_conf = current_conf
	req.server_id = server_id
	req.game_id = game_id
	return context.call(svc, "enter_area", ctx, req)
end

function area_ctrl.exit_area(ctx, req)
	local svc = get_logic_svc()
	req = req or {}
	req.game_id = game_id
	req.server_id = server_id
	return context.call(svc, "exit_area", ctx, req)
end

function area_ctrl.get_role(ctx, req)
	local svc = get_logic_svc()
	return context.call(svc, "get_role", ctx, req)
end

function area_ctrl.create_role(ctx, req)
	local svc = get_logic_svc()
	return context.call(svc, "create_role", ctx, req)
end

-- 根据人数条件+其它选择
local function get_room_addr(ctx, req)
	for k, room_id in pairs(room_id_list) do
		local conf = game_room_config[room_id]
		if conf.room_type == req.roomtype then
			local role_info = db_helper.call(DB_SERVICE.agent, "role.get_role_by_role_id", ctx.role_id)
			if role_info.gold < conf.min_enter then
				return AREA_ERROR.gold_not_enough
			end
			local reply = db_helper.call(DB_SERVICE.game, "room.get_max_room", server_id, room_id)
			local room_addr = tonumber(reply[1])
			local player_num = tonumber(reply[2])
			-- 动态创建
			if player_num >= conf.player_limit then
				room_addr = create_room_by_room_id(room_id)
				--return AREA_ERROR.room_not_enough
			end
			return SYSTEM_ERROR.success, room_addr, room_id
		end	
	end
	return AREA_ERROR.room_forbid_enter
end

function area_ctrl.enter_room(ctx, req)
	local ec, room_addr,room_id = get_room_addr(ctx, req)
	if ec ~= SYSTEM_ERROR.success then
		return ec
	end
	local ec_code, reply = context.call(room_addr, "enter_room", ctx, req)
	if ec_code ~= SYSTEM_ERROR.success then
		return ec_code
	end
	return SYSTEM_ERROR.success,reply
end

return area_ctrl