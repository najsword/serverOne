local skynet = require "skynet"
local json = require "json"
local command = require "command_base"
local area_logic = require "area.area_logic"

function command.enter_area(ctx, req)
	return area_logic.enter_area(ctx, req)
end

function command.exit_area(ctx, req)
	return area_logic.exit_area(ctx, req)
end

function command.get_role(ctx, req)
	return area_logic.get_role(ctx, req)
end

function command.create_role(ctx, req)
	return area_logic.create_role(ctx, req)
end

skynet.start(function()

end)
