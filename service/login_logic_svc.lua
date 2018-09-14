local skynet = require "skynet"
local json = require "json"
local command = require "command_base"
local login_logic = require "login.login_logic"

function command.signin_account(ctx, req)
	return login_logic.signin_account(ctx, req)
end

function command.weixin_account(ctx, req)
	return login_logic.weixin_account(ctx, req)
end

function command.vistor_account(ctx, req)
	return login_logic.vistor_account(ctx, req)
end

skynet.start(function()
	login_logic.init()
end)
