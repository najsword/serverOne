local skynet = require "skynet"
local json = require "json"
local md5 = require "md5"
local random = require "random"
local db_helper = require "common.db_helper"
local create_role_config = require "config.create_role_config"
local nickname_config = require "config.nickname_config"
local role_logic = {}

function role_logic.init()

end

function role_logic.get_role_id(ctx, req)
	local role_info = db_helper.call(DB_SERVICE.agent, "role.get_role", ctx.player_id, ctx.game_id)
	if role_info then
		db_helper.call(DB_SERVICE.agent, "role.cache_role_info", ctx.player_id, ctx.game_id)
		return SYSTEM_ERROR.success, role_info.role_id
	else
		return ROLE_ERROR.role_nil
	end
end

function role_logic.create_role(ctx, req)
    local conf = create_role_config[req.create_index]
	local role_info = db_helper.call(DB_SERVICE.agent, "role.get_role", ctx.player_id, ctx.game_id)
	if role_info then
		return ROLE_ERROR.role_exist
	end
	local role_id = db_helper.call(DB_SERVICE.unique, "role.incr_role_id", nil)
	if not role_id then
		return ROLE_ERROR.role_id_limit
	end
	local nickname = req.nickname or random.random_one(nickname_config)
    role_info = {
        role_id = role_id,
        player_id = ctx.player_id,
        game_id = ctx.game_id,
		head_id = conf.head_id,
		head_url = "",
		nickname = nickname,
		sex = conf.sex,
		gold = conf.gold,
		create_time = os.time(),
	}
	db_helper.call(DB_SERVICE.agent, "role.create_role", nil, role_info)
	db_helper.call(DB_SERVICE.agent, "role.cache_role_info", ctx.player_id, ctx.game_id)
	return SYSTEM_ERROR.success, role_info.role_id
end

return role_logic