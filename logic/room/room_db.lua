local db_mgr = require "common.db_mgr"
local skynet = require "skynet"
local room_db = {}

local RoomListKey = "room_list"
local RoomInstKey = "room_inst"
local FdnumRoomKey = "fdnum_room"
local FdnumServerKey = "fdnum_server"
local Readystart_server_Key = "readystart_server"
local Readystop_server_Key = "readystop_server"

local function get_FdnumRoomKey(server_room_id)
	return FdnumRoomKey..":"..server_room_id
end
local function get_FdnumServerKey(game_id)
	return FdnumServerKey..":"..game_id
end
local function get_Readystop_server_Key()
	return Readystop_server_Key
end
local function get_Readystart_server_Key(game_id)
	return Readystart_server_Key..":"..game_id
end

local function get_room_list_key(room_id)
	return RoomListKey..":"..room_id
end
local function get_room_inst_key(server_id)
	return RoomInstKey..":"..server_id
end

---- -- --    fdnum_room  -- -- -- -- -- -- 
-- area init/area.enter_room
function room_db.register_room_info(server_id, room_id, room_addr)
	local redisdb = db_mgr.get_redis_db()
	redisdb:zadd(get_FdnumRoomKey(server_id.."@"..room_id), 0, room_addr)
end

-- room.exit_room(内部)
function room_db.unregister_room_info(server_id, room_id, room_addr)
	local redisdb = db_mgr.get_redis_db()
	redisdb:zrem(get_FdnumRoomKey(server_id.."@"..room_id),  room_addr)
end

-- area.enter_room
function room_db.get_max_room(server_id, room_id)
	local redisdb = db_mgr.get_redis_db()
	return redisdb:zrevrangebyscore(get_FdnumRoomKey(server_id.."@"..room_id), "+inf", "-inf", "withscores", "limit", 0, 1) 
end

-- room.exit_room(内部)
local function get_roomid_num(server_id, room_id)
	local redisdb = db_mgr.get_redis_db()
	local reply = redisdb:zcard(get_FdnumRoomKey(server_id.."@"..room_id))
	return tonumber(reply)
end

-- room.enter_room
function room_db.incrby_player(server_id, room_id, room_addr, fd)
	local redisdb = db_mgr.get_redis_db()
	redisdb:zincrby(get_FdnumRoomKey(server_id.."@"..room_id), 1, room_addr) 
end

-- room.exit_room
local function decrby_player(server_id, room_id, room_addr, fd)
	local redisdb = db_mgr.get_redis_db()
	local reply = redisdb:zincrby(get_FdnumRoomKey(server_id.."@"..room_id), -1, room_addr)
	return tonumber(reply[1])
end
---- -- --    fdnum_room  -- -- -- -- -- -- 


---- -- --    fdnum_server  -- -- -- -- -- --
-- area.enter_area
function room_db.server_incrby_fd(game_id, server_id, fd)
	local redisdb = db_mgr.get_redis_db()
	redisdb:zincrby(get_FdnumServerKey(game_id), 1, server_id) 
end

-- area.exit_area
local function server_decrby_fd(game_id, server_id, fd)
	local redisdb = db_mgr.get_redis_db()
	local reply = redisdb:zincrby(get_FdnumServerKey(game_id), -1, server_id)
	return tonumber(reply[1])
end

function room_db.get_max_server(game_id)
	local redisdb = db_mgr.get_redis_db()
	return redisdb:zrevrangebyscore(get_FdnumServerKey(game_id), "+inf", "-inf", "withscores", "limit", 0, 1) 
end

function room_db.register_server(game_id, server_id)
	local redisdb = db_mgr.get_redis_db()
	redisdb:zadd(get_FdnumServerKey(game_id), 0, server_id)
end

local function get_server_count(game_id)
	local redisdb = db_mgr.get_redis_db()
	local reply = redisdb:zcard(get_FdnumServerKey(game_id))
	return tonumber(reply)
end
---- -- --    fdnum_server  -- -- -- -- -- --


-- area.exit_area
local function unregister_server(game_id, server_id)
	local redisdb = db_mgr.get_redis_db()
	redisdb:zrem(get_FdnumServerKey(game_id), server_id)
	--room_db.lpush_server_id(game_id, server_id)
end

function room_db.exit_room(server_id, room_id, room_addr, fd)
	local num = decrby_player(server_id, room_id, room_addr, fd)
	if num == 0 then
		num = get_roomid_num(server_id, room_id)
		if num > 1 then
			room_db.unregister_room_info(server_id, room_id, room_addr)
		end
	end
end

function room_db.exit_area(game_id, server_id, fd)
	local num = server_decrby_fd(game_id, server_id, fd)
	if num == 0 then
		num = get_server_count(game_id)
		if num > 1 then
			unregister_server(game_id, server_id)
			room_db.lpush_unstop_server(server_id)
		end
	end
end

---- -- --    readystart_server  -- -- -- -- -- -- 
function room_db.lpush_server_id(game_id, server_id)
	local redisdb = db_mgr.get_redis_db()
	redisdb:lpush(get_Readystart_server_Key(game_id), server_id)
end

function room_db.lpop_server_id(game_id)
	local redisdb = db_mgr.get_redis_db()
	redisdb:lpop(get_Readystart_server_Key(game_id))
end

function room_db.lrem_server_id(game_id, server_id)
	local redisdb = db_mgr.get_redis_db()
	redisdb:lrem(get_Readystart_server_Key(game_id), 0, server_id)
end

function room_db.llen_server_id(game_id)
	local redisdb = db_mgr.get_redis_db()
	local reply = redisdb:llen(get_Readystart_server_Key(game_id))
	return tonumber(reply)
end
---- -- --    readystart_server  -- -- -- -- -- -- 

---- -- --    readystop_server  -- -- -- -- -- -- 
function room_db.lpush_unstop_server(server_id)
	local redisdb = db_mgr.get_redis_db()
	redisdb:lpush(get_Readystop_server_Key(), server_id)
end

function room_db.lpop_unstop_server()
	local redisdb = db_mgr.get_redis_db()
	redisdb:lpop(get_Readystop_server_Key())
end
---- -- --    readystop_server  -- -- -- -- -- -- 

-- function room_db.player_enter_room(server_id)
-- 	local redisdb = db_mgr.get_redis_db()
-- 	local player_num = redisdb:hget(get_room_inst_key(server_id), "player_num")
-- 	redisdb:hset(get_room_inst_key(server_id), "player_num", tonumber(player_num)+1)
-- end

-- function room_db.player_exit_room(server_id)
-- 	local redisdb = db_mgr.get_redis_db()
-- 	local player_num = redisdb:hget(get_room_inst_key(server_id), "player_num")
-- 	redisdb:hset(get_room_inst_key(server_id), "player_num", tonumber(player_num)-1)
-- end

-- room
-- function room_db.get_room_inst(server_id)
-- 	local redisdb = db_mgr.get_redis_db()
-- 	return array_totable(redisdb:hgetall(get_room_inst_key(server_id)))
-- end

-- function room_db.get_room_list(room_id)
-- 	local reply = {}
-- 	local redisdb = db_mgr.get_redis_db()
-- 	local room_list = redisdb:zrange(get_room_list_key(room_id), 0, -1)
-- 	for k, v in pairs(room_list) do
-- 		local inst = room_db.get_room_inst(tonumber(v))
-- 		table.insert(reply, inst)
-- 	end
-- 	return reply
-- end

-- function room_db.remove_room_inst(room_id, server_id)
-- 	local redisdb = db_mgr.get_redis_db()
-- 	redisdb:zrem(get_room_list_key(room_id), server_id)
-- 	local inst = room_db.get_room_inst(server_id)
-- 	for k, v in pairs(inst) do
-- 		print("remove k=")
-- 		redisdb:hdel(get_room_inst_key(server_id), k)
-- 	end
-- end

-- function room_db.register_room(id, room_inst_info)
-- 	local redisdb = db_mgr.get_redis_db()
-- 	local room_id = room_inst_info.room_id
-- 	local server_id = room_inst_info.server_id
-- 	local room_inst = assert(table.toarray(room_inst_info), "room_inst_info is not table")
-- 	redisdb:hmset(get_room_inst_key(server_id), table.unpack(room_inst))
-- 	--redisdb:zadd(get_room_list_key(room_id), 0, server_id)
-- end


return room_db