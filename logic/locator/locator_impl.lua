local locator_ctrl = require "locator.locator_ctrl"

local locator_impl = {}


function locator_impl.init()
    locator_ctrl.init()
end

function locator_impl.route_sid(req)
    locator_ctrl.route_sid(req.game_id)
end

return locator_impl