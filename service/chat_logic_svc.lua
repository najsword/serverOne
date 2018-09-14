local skynet = require "skynet"
local command = require "command_base"
local chat_logic = require "chat.chat_logic"

function command.chat_req(ctx, req)
    return chat_logic.chat_req(ctx, req)
end

function command.set_ctx(ctx, req)
    return chat_logic.set_ctx(ctx, req)
end

skynet.start(function()
	
end)
