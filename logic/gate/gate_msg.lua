local skynet = require "skynet"
local json = require "json"
local gate_mgr = require "gate.gate_mgr"
local client_msg = require "gate.client_msg"
local cluster_monitor = require "cluster_monitor"
local cache_logic = require "cache.cache_logic"
local sproto_helper = require "sproto_helper"
local db_helper = require "common.db_helper"
local context = require "context"

local gate_msg = {}

--开放网关
function gate_msg.start(conf)
	skynet.call(gate_mgr.get_gate(), "lua", "open", conf)
end

function gate_msg.player_leave(fd)
	local c = gate_mgr.get_connection(fd)
	if c ~= nil then
		local ctx = client_msg.get_context(c)
		if ctx ~= nil and ctx.player_id ~= nil then
			local login_node = cluster_monitor.get_cluster_node_by_server(SERVER.LOGIN)
			if not login_node then
				error("cast_logout loginnode not online")
			end
			context.rpc_call(login_node.nodename, SERVICE.LOGIN, "logout_account", ctx, nil)
			return true
		end
	end
	return false
end

function gate_msg.close(fd)
	local c = gate_mgr.get_connection(fd)
	if c ~= nil then
		skynet.error("cy====================================gate_msg.close",fd)
		local ctx = client_msg.get_context(c)
		if ctx ~= nil and ctx.player_id ~= nil then
			local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", ctx.player_id )
			if tonumber(online.offline) == OFFLINE_STATE.off then
				db_helper.call(DB_SERVICE.hall, "hall.update_player_online", ctx.player_id , "offline", OFFLINE_STATE.on)
			end
		end
		--gate_mgr.close_connection(fd)
	end
end

function gate_msg.logout(fd)
	local c = gate_mgr.get_connection(fd)
	if c ~= nil then
		skynet.error("cy====================================gate_msg.logout",fd)
		context.send(SERVICE.HEARTBEAT, "del_playerId", c.player_id)
		gate_mgr.close_connection(fd)
		skynet.send(gate_mgr.get_gate(), "lua", "kick", fd)
	end
end

function gate_msg.close_fd(fd)
	gate_mgr.close_connection(fd)
	skynet.send(gate_mgr.get_gate(), "lua", "kick", fd)
end

function gate_msg.login_open_switch(isopen)

end

function gate_msg.monitor_node_change(conf)
	if not conf then return end
	if not conf.nodename then return end
	local callback = cluster_monitor.get_subcribe_callback(conf.nodename)
	if not callback then
		return
	end
	return callback(conf)
end

function gate_msg.send_client_msg(fd, buffer)
	print("gate_msg.send_client_msg 111 fd=", fd, "#buffer=", #buffer)
	if skynet.getenv("websocket_test") and gate_mgr.is_websocket() then
		local header, content = sproto_helper.unpack_header(buffer)
		if not header then
			return
		end
		header.response = 1
		local header, result = sproto_helper.unpack_data(header, content)
		local j_packet = json.encode({header = header, data = result})
		skynet.send(gate_mgr.get_gate(), "lua", "send_buffer", fd, j_packet, true)
		return
	end
	
	skynet.send(gate_mgr.get_gate(), "lua", "send_buffer", fd, buffer)

	local header, content = sproto_helper.unpack_header(buffer)
	if not header then
		return
	end
	header.response = 1
	local header, result = sproto_helper.unpack_data(header, content)
	print("gate_msg.send_client_msg 222 header=", table.tostring(header), "#result=", table.tostring(result))
end

--暂时不用
function gate_msg.reponse_client_msg(fd, buffer)
	skynet.send(gate_mgr.get_gate(), "lua", "send_buffer", fd, buffer)
end

function gate_msg.set_c_context(fd, online)
	local src_fd = tonumber(online.fd)
	if src_fd ~= fd then
		gate_msg.close_fd(src_fd)
	end
	local c = gate_mgr.get_connection(fd)
	if c then
		c.session = online.session
		c.player_id = tonumber(online.player_id)
		c.hall_agentnode = online.hall_agentnode
		c.role_id = tonumber(online.role_id)
		c.agentnode = online.agentnode
		c.agentver = tonumber(online.agentver)
		c.game_id = tonumber(online.game_id)
		c.agentaddr = tonumber(online.agentaddr)
		c.roomaddr = tonumber(online.roomaddr)
		c.auth_ok = true
	end
end

function gate_msg.login_ok(fd, player_id, agentnode, agentaddr)
	-- print("gate_msg.login_ok fd=", fd, "player_id=", player_id, "agentnode=", agentnode, "agentaddr=", agentaddr)
	local c = gate_mgr.get_connection(fd)
	if c then
		c.player_id = player_id
		c.hall_agentnode = agentnode
		c.hall_agentaddr = agentaddr
		c.auth_ok = true
	end
end

function gate_msg.login_failure(fd)
	local c = gate_mgr.get_connection(fd)
	if c then
		c.auth_ok = false
	end
end

function gate_msg.set_agent(fd, agentaddr)
	local c = gate_mgr.get_connection(fd)
	if c then
		c.agentaddr = agentaddr
	end
end

--添加
function gate_msg.enter_area(fd, agentnode, agentver, game_id)
	local c = gate_mgr.get_connection(fd)
	if c then
		c.agentnode = agentnode
		c.agentver = agentver
		c.game_id = game_id
	end
end

--添加
function gate_msg.exit_area(fd)
	local c = gate_mgr.get_connection(fd)
	if c then
		c.agentnode = nil
		c.agentver = nil
	end
end

--添加
function gate_msg.set_role_id(fd, role_id)
	local c = gate_mgr.get_connection(fd)
	if c then
		c.role_id = role_id
	end
end

--添加
function gate_msg.set_room_addr(fd, roomaddr)
	local c = gate_mgr.get_connection(fd)
	if c then
		c.roomaddr = roomaddr
	end
end

function gate_msg.login_desk(fd, deskaddr)
	local c = gate_mgr.get_connection(fd)
	if c then
		c.deskaddr = deskaddr
	end
end

function gate_msg.logout_desk(fd)
	local c = gate_mgr.get_connection(fd)
	if c then
		c.deskaddr = nil
	end
end

return gate_msg