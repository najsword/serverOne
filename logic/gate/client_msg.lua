local skynet = require "skynet"
local json = require "json"
local proto_map = require "proto_map"
local cluster_monitor = require "cluster_monitor"
local context = require "context"
local gate_mgr = require "gate.gate_mgr"
local cache_logic = require "cache.cache_logic"
local sproto_helper = require "sproto_helper"
local client_msg = {}

function client_msg.get_context(c)
	local ctx = {}
	ctx.gate = cluster_monitor.get_current_nodename()
	ctx.watchdog = skynet.self()
	ctx.is_websocket = gate_mgr.is_websocket()
	ctx.fd = c.fd
	ctx.ip = c.ip
	ctx.session = c.session
	ctx.player_id = c.player_id
	ctx.role_id = c.role_id
	ctx.game_id = c.game_id
	return ctx
end

function client_msg.dispatch(c, header, msg)
	if not header or not header.protoid then
		skynet.error("client_msg.dispatch not header or not header.protoid")
		return
	end

	if header.protoid == 0x0002 then
		header.errorcode = SYSTEM_ERROR.success
		client_msg.send(c.fd, header)
		context.send(SERVICE.HEARTBEAT, "reset_updatetime", c.player_id)
		return
	end

	if  header.playerid ~= nil then
		cache_logic.set_c_context(c, header.playerid)
	end	

	skynet.error("cy==============================client_msg protoid=", header.protoid)

	local proto = proto_map.protos[header.protoid]
	if not proto then
		header.errorcode = SYSTEM_ERROR.unknow_proto
		client_msg.send(c.fd, header)
		skynet.error("client_msg.dispatch not proto")
		return
	end
	--print("dispatch proto=", table.tostring(proto))

	if proto.type ~= PROTO_TYPE.C2S then
		header.errorcode = SYSTEM_ERROR.invalid_proto
		client_msg.send(c.fd, header)
		skynet.error("client_msg.dispatch proto.type ~= PROTO_TYPE.C2S")
		return
	end

	--待修改
	if proto.service and (proto.service ~= SERVICE.AUTH and proto.service ~= SERVICE.LOGIN) and not c.auth_ok then
		header.errorcode = SYSTEM_ERROR.no_auth_account
		client_msg.send(c.fd, header)
		-- print("dispatch proto.service=", proto.service, "c.auth_ok=", c.auth_ok)
		skynet.error("client_msg.dispatch proto.service ~= SERVICE.AUTH and not c.auth_ok")
		return
	end

	if proto.server == SERVER.GAME and not c.agentnode and not header.roomproxy then
		header.errorcode = SYSTEM_ERROR.unknow_roomproxy
		client_msg.send(c.fd, header)
		skynet.error("client_msg.dispatch proto.server == SERVER.GAME and not c.agentnode and not header.roomproxy")
		return
	end

	if not proto.service and not c.agentnode and not c.agentaddr then
		header.errorcode = SYSTEM_ERROR.no_login_game
		-- print("dispatch proto.service=", proto.service, "c.agentnode=", c.agentnode, "c.agentaddr=", c.agentaddr)
		client_msg.send(c.fd, header)
		skynet.error("client_msg.dispatch not proto.service and not c.agentnode and not c.agentaddr")
		return
	end

	local nodename, service
	local target_node
	local ctx = client_msg.get_context(c)

	if proto.service then --auth hall area chat login
		if proto.server == SERVER.GAME then  --area
			skynet.error("cy===============client_msg proto.service is for SERVER.GAME")
			if not c.agentnode then
				local rpc_err
				local locator_node = cluster_monitor.get_cluster_node_by_server(SERVER.LOCATOR)
				local msgData = {game_id=header.roomproxy}
			    rpc_err, nodename = context.rpc_call(locator_node.nodename, SERVICE.LOCATOR, "route_sid", msgData)
				--rpc_err, nodename = context.rpc_call(locator_node.nodename, SERVICE.LOCATOR, "dispatch_client_msg", ctx, msgData) err test
				skynet.error("cy=======roomproxy,nodename=", header.roomproxy, nodename)
				if rpc_err ~= RPC_ERROR.success then
					nodename = "xpnn1"  -- 待修改 无locator测试用
					skynet.error("cy======locator route_sid fail,rpc_err,roomproxy=", rpc_err, header.roomproxy)
				end
			else
				nodename = c.agentnode
			end
			service = proto.service
		else --auth hall chat login
			target_node = cluster_monitor.get_cluster_node_by_server(proto.server)
			skynet.error("cy===============client_msg proto.service is not for SERVER.GAME", target_node, proto.server)
			if not target_node or target_node.is_online == 0 then
				header.errorcode = SYSTEM_ERROR.service_maintance
				client_msg.send(c.fd, header)
				return
			end
			nodename = target_node.nodename
			service = proto.service
		end
	else --属于agent或游戏台agent  desk m_xpnn  room
		if proto.is_agent then --玩家agent,在游戏中则使用游戏agent,否则使用大厅的agent
			skynet.error("cy===============client_msg proto.service is  agent")
			if c.agentnode and c.agentver then
				target_node	= cluster_monitor.get_cluster_node(c.agentnode)
				if target_node and c.agentver < target_node.ver then
					c.agentnode = nil
					c.agentaddr = nil
					c.agentver = nil
				end
			end
			nodename = c.agentnode or c.hall_agentnode
			service = c.agentaddr or c.hall_agentaddr
		else --游戏台agent  desk m_xpnn room
			skynet.error("cy===============client_msg proto.service is not agent,proto.module=", proto.module)
			nodename = c.agentnode --or header.roomproxy
			if proto.module == "room" then
				service = c.roomaddr
			else
				service = c.deskaddr
			end
		end
	end
	
	if not target_node then
		target_node	= cluster_monitor.get_cluster_node(nodename)
	end

	if not target_node or target_node.is_online == 0 then
		header.errorcode = SYSTEM_ERROR.service_maintance
		client_msg.send(c.fd, header)
		skynet.error("client_msg.dispatch header.errorcode = SYSTEM_ERROR.service_maintance")
		return
	end

	skynet.error("client_msg.dispatch nodename, service=", nodename, service)
	local rpc_err = context.rpc_call(nodename, service, "dispatch_client_msg", ctx, msg)
	if rpc_err ~= RPC_ERROR.success then
		header.errorcode = SYSTEM_ERROR.service_stoped
		client_msg.send(c.fd, header)
		skynet.error("client_msg.dispatch  rpc_err = ", rpc_err)
		return
	end
end

function client_msg.send(fd, header, data)
	if skynet.getenv("websocket_test") and gate_mgr.is_websocket() then
		local j_packet = json.encode({header = header, data = data})
		skynet.send(gate_mgr.get_gate(), "lua", "send_buffer", fd, j_packet, true)
		return
	end

	local buffer = sproto_helper.pack(header, data)
	if buffer then
		skynet.send(gate_mgr.get_gate(), "lua", "send_buffer", fd, buffer)
	end
end

return client_msg