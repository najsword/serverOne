local skynet = require "skynet"
local role_logic = require "role.role_logic"
local role_ctrl = {}


function role_ctrl.init()

end

function role_ctrl.get_role(ctx, req)
	return  role_logic.get_role_id(ctx, req)
end

function role_ctrl.create_role(ctx, req)
	return  role_logic.create_role(ctx, req)
end

return role_ctrl