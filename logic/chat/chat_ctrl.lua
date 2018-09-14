require "skynet.manager"
local skynet = require "skynet"
local context = require "context"
local db_helper = require "common.db_helper"
local chat_logic = require "chat.chat_logic"
local chat_ctrl = {}

local fd_ctx = {}
local logic_svc_pool = {}
local logic_svc_index = 1

local function init_logic_pool()
	local logic_count = skynet.getenv("chat_logic_count")
	for i=1, logic_count do
		local svc = skynet.newservice("chat_logic_svc")
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

function chat_ctrl.init()
    init_logic_pool()
end

function chat_ctrl.set_ctx(ctx)
    fd_ctx[ctx.fd] = {}
    fd_ctx[ctx.fd]= {fd = ctx.fd, watchdog = ctx.watchdog, gate = ctx.gate}
    return SYSTEM_ERROR.success
end

function chat_ctrl.chat_req(ctx, req)
    local svc = get_logic_svc()
    req.fd_ctx = fd_ctx
	return context.call(svc, "chat_req", ctx, req)
end


return chat_ctrl