local skynet = require "skynet"
local context = require "context"
local cluster_monitor = require "cluster_monitor"
local login_ctrl = {}

local logic_svc_pool = {}
local logic_svc_index = 1
local request_sessions = {}

local function init_logic_pool()
	local logic_count = skynet.getenv("login_logic_count")
	for i=1, logic_count do
		local svc = skynet.newservice("login_logic_svc")
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

function login_ctrl.init()
    init_logic_pool()
end

function login_ctrl.cast_login(ctx, player_info)
    skynet.error("cy===============================logincast_loginsssssssssss")
	local hall_node = cluster_monitor.get_cluster_node_by_server(SERVER.HALL)
	if not hall_node then
		error("cast_login hallserver not online")
	end
	context.rpc_call(hall_node.nodename, SERVICE.HALL, "cast_login", ctx, player_info)
end

function login_ctrl.cast_logout(ctx, req)
    skynet.error("cy===============================logincast_logoutsssssssssss")
	local hall_node = cluster_monitor.get_cluster_node_by_server(SERVER.HALL)
	if not hall_node then
		error("cast_logout hallserver not online")
	end
	context.rpc_call(hall_node.nodename, SERVICE.HALL, "cast_logout", ctx, req)
end

function login_ctrl.signin_account(ctx, req)
	if not req.account then
		return AUTH_ERROR.account_nil
	end
	if not req.password then
		return AUTH_ERROR.password_nil
    end
    if not req.subid then
		return AUTH_ERROR.subid_nil
	end
	if ctx.player_id then
		return AUTH_ERROR.repeat_login
    end

	local session_info = request_sessions[ctx.session]
	
	if session_info then
		return SYSTEM_ERROR.busy
	end
	request_sessions[ctx.session] = true

	local svc = get_logic_svc()
	local ec, reply = context.call(svc, "signin_account", ctx, req)
	if ec ~= SYSTEM_ERROR.success then
		request_sessions[ctx.session] = nil
		return ec
	end

	ctx.account_type = ACCOUNT_TYPE.normal
	login_ctrl.cast_login(ctx, reply.player)
	request_sessions[ctx.session] = nil
	return SYSTEM_ERROR.success, reply
end

function login_ctrl.weixin_account(ctx, req)
    if not req.subid then
		return AUTH_ERROR.subid_nil
	end
	if ctx.player_id then
		return AUTH_ERROR.repeat_login
    end
	local session_info = request_sessions[ctx.session]
	if session_info then
		return SYSTEM_ERROR.busy
	end
	request_sessions[ctx.session] = true

	local svc = get_logic_svc()
	local ec, reply = context.call(svc, "weixin_account", ctx, req)
	if ec ~= SYSTEM_ERROR.success then
		request_sessions[ctx.session] = nil
		return ec
	end
	ctx.account_type = ACCOUNT_TYPE.weixin
	login_ctrl.cast_login(ctx, reply.player)
	request_sessions[ctx.session] = nil
	return SYSTEM_ERROR.success, reply
end

function login_ctrl.vistor_account(ctx, req)
    if not req.subid then
		return AUTH_ERROR.subid_nil
	end
	if ctx.player_id then
		return AUTH_ERROR.repeat_login
    end
	local session_info = request_sessions[ctx.session]
	if session_info then
		return SYSTEM_ERROR.busy
	end
	request_sessions[ctx.session] = true

	local svc = get_logic_svc()
	local ec, reply = context.call(svc, "vistor_account", ctx, req)
	if ec ~= SYSTEM_ERROR.success then
		request_sessions[ctx.session] = nil
		return ec
	end
	ctx.account_type = ACCOUNT_TYPE.vistor
	login_ctrl.cast_login(ctx, reply.player)
	request_sessions[ctx.session] = nil
	return SYSTEM_ERROR.success, reply
end

function login_ctrl.logout_account(ctx, req)
	login_ctrl.cast_logout(ctx, req)
	return SYSTEM_ERROR.success
end

return login_ctrl