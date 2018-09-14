--[[
	@ filename : dispatcher.lua
	@ author   : zhangshiqian1214@163.com
	@ modify   : 2017-08-23 17:53
	@ company  : zhangshiqian1214
]]


local skynet = require "skynet"
local queue = require "skynet.queue"
local cluster = require "skynet.cluster"
local proto_map = require "proto_map"
local logger = require "logger"
local db_helper = require "common.db_helper"
local sproto_helper = require "sproto_helper"
local cache_logic = require "cache.cache_logic"
local utils = require "utils"

local cs = queue()
local dispatcher = {}
dispatcher.service_base = nil

local function queue_func(ret, func, ctx, data)
	local ok, msg = xpcall(function()
		local ret1, ret2 = func(ctx, data)
		ret[1] = ret1
		ret[2] = ret2
	end, debug.traceback) 
	if not ok then
		error(msg)
	end
end

local function call_func(func, ctx, data)
	local ret1, ret2
	local ok, msg = xpcall(function()
		ret1, ret2 = func(ctx, data)
	end, debug.traceback)
	if not ok then
		error(msg)
end
	return ret1, ret2
end

local function _dispatch_client_msg(ctx, header, data)
	local service_base = dispatcher.service_base
	if service_base == nil then
		header.errorcode = SYSTEM_ERROR.service_not_impl
		dispatcher.response_client_msg(ctx, header)
		return 
	end

	local proto = proto_map.protos[header.protoid]
	if not proto then
		header.errorcode = SYSTEM_ERROR.unknow_proto
		dispatcher.response_client_msg(ctx, header)
		return
	end

	logger.debugf("the message from client:%s.%s", proto.module, proto.name)

	local modname = proto.module
	local funcname = proto.name
	local mod = service_base.modules[modname]

	skynet.error("cy=== dispatch_client_msg funcname,modname=", funcname, modname)
	if mod == nil then
		logger.debugf("the module[%s] object is not found in this service", proto.module)
		header.errorcode = SYSTEM_ERROR.module_not_impl
		dispatcher.response_client_msg(ctx, header)
		return
	end
	local func = mod[funcname]
	if func == nil then
		logger.debugf("the implement of proto[%s] is not found in the module[%s]", proto.name, proto.module)
		header.errorcode = SYSTEM_ERROR.func_not_impl
		dispatcher.response_client_msg(ctx, header)
		return
	end

	local ec, reply
	ctx.packid = header.packid
	local player_id = ctx.player_id or header.playerid
	if  header.playerid ~= nil then
		data.playerid = header.playerid
	end	

	if ctx.packid < 0 then
		ctx.packid = -ctx.packid
		local cache_result = cache_logic.get_cache(player_id, ctx.packid, header.protoid)
		if cache_result ~= nil then
			skynet.error("cy===================================docache",player_id, ctx.packid)
			ec = cache_result.ec
			reply = cache_result.data
		end
	else
		skynet.error("cy===================================undocacheeeeeeeeeee",player_id, ctx.packid)
		if service_base.is_agent then
			local ret = {}
			cs(queue_func, ret, func, ctx, data)
			ec = ret[1]
			reply = ret[2]
		else
			ec, reply = call_func(func, ctx, data)
		end
		if ctx.packid ~= 0 then
			cache_logic.set_cache(ctx.packid, player_id, header.protoid, ec, reply)
		end
	end
	
	skynet.error("_dispatch_client_msg ec, reply=", ec, utils.print_r(reply))
	if ec == SYSTEM_ERROR.forward then
		return SYSTEM_ERROR.forward
	elseif ec ~= SYSTEM_ERROR.success then
		if ec == nil then
			ec = SYSTEM_ERROR.unknow
			logger.errorf("proto[%s] not return error code", proto.fullname)
		end
		logger.infof("the implement of proto[%s.%s] return error[%s]", proto.module, proto.name, errmsg(ec))		
	else
		if proto.response ~= nil and reply == nil then
			logger.errorf("proto[%s] must has return value error[%s]", proto.fullname, errmsg(ec))
		end
	end
	logger.debugf("proto[%s.%s] ret = [%s]", proto.module, proto.name, errmsg(ec))
	header.errorcode = ec
	-- 添加 设为返回包
	header.response = 1 
	dispatcher.response_client_msg(ctx, header, reply)
	
	return ec, reply
end

local function dispatch_client_msg(ctx, header, data)
	assert(header, "dispatch header is nil")
	local ok, msg = xpcall(function()
		local ec, reply = _dispatch_client_msg(ctx, header, data)
	end, debug.traceback)
	if not ok then
		header.errorcode = SYSTEM_ERROR.service_stoped
		dispatcher.response_client_msg(ctx, header, data)
		error("service_stoped:"..msg)
	end
end

function dispatcher.response_client_msg(ctx, header, data)
	local buffer = sproto_helper.pack(header, data)
	if not buffer then
		return
	end
	cluster.call(ctx.gate, ctx.watchdog, "send_client_msg", ctx.fd, buffer)
end

function dispatcher.dispatch_client_msg(ctx, buffer)
	local header, data = sproto_helper.unpack(buffer, #buffer)
	assert(header, "dispatch_client_msg header is nil")
	assert(header.protoid, "dispatch_client_msg protoid is nil")
	if ctx.is_websocket then
		header.response = nil
	end
	dispatch_client_msg(ctx, header, data)
end

function dispatcher.dispatch_service_msg(method, ...)
	local service_base = dispatcher.service_base
	if service_base == nil then
		return SYSTEM_ERROR.service_not_impl
	end

	logger.debugf("the message from client:%s", method)
	local modname, funcname = string.match(method, "([%w_]+)%.([%w_]+)")
	if not modname or not funcname then
		return SYSTEM_ERROR.decode_failure
	end

	local mod = service_base.modules[modname]
	if mod == nil then
		
		logger.debugf("the module[%s] object is not found in this service", modname)
		return SYSTEM_ERROR.module_not_impl
	end

	local func = mod[funcname]
	if func == nil then
		logger.debugf("the implement of proto[%s] is not found in the module[%s]", funcname, modname)
		return SYSTEM_ERROR.func_not_impl
	end

	local ret1, ret2
	if service_base.is_agent then
		local ret = {}
		cs(queue_func, ret, func, ctx, data)
		ret1 = ret[1]
		ret2 = ret[2]
	else
		ret1, ret2 = call_func(func, ctx, data)
	end

	return ret1, ret2
end

skynet.register_protocol {
	name     = "client",
	id       = skynet.PTYPE_CLIENT,
	pack     = dispatcher.pack,
	unpack   = dispatcher.unpack,
	dispatch = dispatch_client_msg,
}

return dispatcher

