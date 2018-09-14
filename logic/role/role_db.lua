local db_mgr = require "common.db_mgr"
local role_db = {}

local IncrIdKey = "incr_role_id"
local RoleInfoKey = "role_info"

local function get_role_info_key(id)
	return RoleInfoKey..":"..id
end

function role_db.incr_role_id(id)
	local redisdb = db_mgr.get_redis_db()
	local role_id = tonumber(redisdb:incr(IncrIdKey))
	return role_id
end

function role_db.get_role(player_id, game_id)
	local mysqldb = db_mgr.get_mysql_db()
	local result = mysqldb:query(string.format("select * from tb_role where player_id='%d' and game_id='%d'", player_id, game_id))
	if result.err then
		error(result.err)
	end
	return result[1]
end

function role_db.get_role_by_role_id(id)
	local mysqldb = db_mgr.get_mysql_db()
	local result = mysqldb:query(string.format("select * from tb_role where role_id='%d'", id))
	if result.err then
		error(result.err)
	end
	return result[1]
end

function role_db.create_role(id, role_info)
	local mysqldb = db_mgr.get_mysql_db()
	local sql = string.format("insert into tb_role(role_id, player_id, game_id, head_id, head_url, nickname, sex, gold, create_time) values(%d, '%d', '%d', %d, '%s', '%s', %d, %d,'%s');",
		role_info.role_id,role_info.player_id,role_info.game_id,role_info.head_id,role_info.head_url,role_info.nickname,role_info.sex,role_info.gold,role_info.create_time)
	local result = mysqldb:query(sql)
	if result.err then
		error(result.err)
	end
	return result[1]
end

--载入到redis
function role_db.cache_role_info(player_id, game_id)
	local role_info = role_db.get_role(player_id, game_id)
	if not role_info then
		return nil
	end
	role_db.set_role_info_cache(tonumber(role_info.role_id), role_info)
	return role_info
end

function role_db.set_role_info_cache(id, role_info)
	local redisdb = db_mgr.get_redis_db()
	local data = assert(table.toarray(role_info), "online is not table")
	redisdb:hmset(get_role_info_key(id), table.unpack(data))
	return
end

function role_db.get_role_info_cache(id)
	local redisdb = db_mgr.get_redis_db()
	local role_info = array_totable(redisdb:hgetall(get_role_info_key(id)))
	role_info.role_id = tonumber(role_info.role_id)
	role_info.player_id = tonumber(role_info.player_id)
	role_info.game_id = tonumber(role_info.game_id)
	role_info.head_id = tonumber(role_info.head_id)
	role_info.sex = tonumber(role_info.sex)
	role_info.gold = tonumber(role_info.gold)
	return role_info
end


return role_db