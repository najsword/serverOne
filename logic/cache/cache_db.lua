local db_mgr = require "common.db_mgr"
local json = require "json"  
local skynet = require "skynet"
local utils = require "utils"
local cache_db = {}

local CacheInfoKey = "cache_info"
local function get_cache_info_key(pack_info)
    local player_id = pack_info.player_id
    local pack_id = pack_info.pack_id
	return CacheInfoKey .. ":" .. player_id .. ":" .. pack_id
end

function cache_db.insert_cache_info(pack_info, pack_data)
    local redisdb = db_mgr.get_redis_db()
    redisdb:hset(get_cache_info_key(pack_info), pack_data.proto_id, json.encode(pack_data))
end

function cache_db.get_cache_info(pack_info)
    local redisdb = db_mgr.get_redis_db()
    return redisdb:hgetall(get_cache_info_key(pack_info))
end

function cache_db.get_cache_info_by_protoid(pack_info, proto_id)
    local redisdb = db_mgr.get_redis_db()
    local data = redisdb:hget(get_cache_info_key(pack_info), proto_id)
    utils.print_r(data)
    if data == nil then
        return nil
    end
    return json.decode(data)
end

function cache_db.remove_cache_info(pack_info)
    local redisdb = db_mgr.get_redis_db()
    pack_info.pack_id = "*"
    local keys = redisdb:keys(get_cache_info_key(pack_info))
    redisdb:del(keys)
end

return cache_db