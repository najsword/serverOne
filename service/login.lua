require "skynet.manager"
local skynet  = require "skynet"
local service = require "service_base"
local login_ctrl = require "login.login_ctrl"
local login_impl = require "login.login_impl"
local command = service.command

function command.cast_logout(fd)
    return login_ctrl.cast_logout(fd)
end

function command.logout_account(ctx, req)
    skynet.error("cy============================ login   logout_account")
    return login_ctrl.logout_account(ctx, req)
end

function service.on_start()
	skynet.register(SERVICE.LOGIN)
	login_ctrl.init()
end

service.modules.login = login_impl
service.start()