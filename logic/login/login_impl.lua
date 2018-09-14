local login_ctrl = require "login.login_ctrl"

local login_impl = {}

function login_impl.signin_account(ctx, req)
	return login_ctrl.signin_account(ctx, req)
end

function login_impl.weixin_account(ctx, req)
	return login_ctrl.weixin_account(ctx, req)
end

function login_impl.vistor_account(ctx, req)
	return login_ctrl.vistor_account(ctx, req)
end

function login_impl.logout_account(ctx, req)
	return login_ctrl.logout_account(ctx, req)
end

return login_impl