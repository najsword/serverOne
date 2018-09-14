local skynet = require "skynet"
local area_ctrl = require "area.area_ctrl"
local area_impl = {}


function area_impl.enter_area(ctx, req)
	return area_ctrl.enter_area(ctx, req)
end

function area_impl.exit_area(ctx, req)
	return area_ctrl.exit_area(ctx, req)
end

function area_impl.get_role(ctx, req)
	return area_ctrl.get_role(ctx, req)
end

function area_impl.create_role(ctx, req)
	return area_ctrl.create_role(ctx, req)
end

function area_impl.enter_room(ctx, req)
	return area_ctrl.enter_room(ctx, req)
end

return area_impl