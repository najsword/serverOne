local skynet = require "skynet"
local chat_ctrl = require "chat.chat_ctrl"
local chat_impl = {}


function chat_impl.chat_req(ctx, req)
	return chat_ctrl.chat_req(ctx, req)
end

function chat_impl.set_ctx(ctx)
    return chat_ctrl.set_ctx(ctx)
end


return chat_impl