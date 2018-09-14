require "skynet.manager"
local skynet  = require "skynet"
local service = require "service_base"
local chat_ctrl = require "chat.chat_ctrl"
local chat_impl = require "chat.chat_impl"
local command = service.command

function command.chat_req(ctx, req)
    return chat_ctrl.chat_req(ctx, req)
end

function command.set_ctx(ctx)
    return chat_ctrl.set_ctx(ctx)
end

function service.on_start()
	skynet.register(SERVICE.CHAT)
	chat_ctrl.init()
end

service.modules.chat = chat_impl
service.start()