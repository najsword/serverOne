local db_mgr = require "common.db_mgr"
local skynet = require "skynet"
local fd_db = {}

local HallFdKey = "fd_hall"
local GameFdKey = "fd_game"
local ServerFdKey = "fd_server"
local RoomTypeFdKey = "fd_roomtype"
local RoomAddrFdKey = "fd_roomaddr"

local function get_hallfd_key()
	return HallFdKey
end
local function get_gamefd_key(game_id)
	return GameFdKey..":"..game_id
end
local function get_serverfd_key(server_id)
	return ServerFdKey..":"..server_id
end
local function get_roomtypefd_key(room_id)
	return RoomTypeFdKey..":"..room_id
end
local function get_roomaddrfd_key(server_id, room_addr)
	return RoomAddrFdKey..":"..server_id.."@"..room_addr
end

function fd_db.set_fd(type, game_id, server_id, room_id, room_addr, fd)
	local redisdb = db_mgr.get_redis_db()
	if type == FD_TYPE.hall then
		redisdb:lpush(get_hallfd_key(), fd)
	elseif type == FD_TYPE.area then
		redisdb:lpush(get_gamefd_key(game_id), fd)
		redisdb:lpush(get_serverfd_key(server_id), fd)
	elseif type == FD_TYPE.room then
		redisdb:lpush(get_roomtypefd_key(room_id), fd)
		redisdb:lpush(get_roomaddrfd_key(server_id, room_addr), fd)
	end
end

function fd_db.unset_fd(type, game_id, server_id, room_id, room_addr, fd)
	local redisdb = db_mgr.get_redis_db()
	if type == FD_TYPE.hall then
		redisdb:lrem(get_hallfd_key(), 0, fd)
	elseif type == FD_TYPE.area then
		redisdb:lrem(get_gamefd_key(game_id), 0, fd)
		redisdb:lrem(get_serverfd_key(server_id), 0, fd)
	elseif type == FD_TYPE.room then
		redisdb:lrem(get_roomtypefd_key(room_id), 0, fd)
		redisdb:lrem(get_roomaddrfd_key(server_id, room_addr), 0, fd)
	end
end

function fd_db.get_fds(type, game_id, server_id, room_id, room_addr)
	local redisdb = db_mgr.get_redis_db()
	if type == FD_TYPE.hall then
		return redisdb:lrange(get_hallfd_key(), 0, -1)
	elseif type == FD_TYPE.game then
		return redisdb:lrange(get_gamefd_key(game_id), 0, -1)
	elseif type == FD_TYPE.server then
		return redisdb:lrange(get_serverfd_key(server_id), 0, -1)
	elseif type == FD_TYPE.roomtype then
		return redisdb:lrange(get_roomtypefd_key(room_id), 0, -1)
	elseif type == FD_TYPE.roomaddr then
		return redisdb:lrange(get_roomaddrfd_key(server_id, room_addr), 0, -1)
	end
end

return fd_db