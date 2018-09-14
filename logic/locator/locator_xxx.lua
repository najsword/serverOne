require "skynet.manager"
local skynet = require "skynet"
local db_helper = require "common.db_helper"
local utils = require "utils"
local cluster_config = require "config.cluster_config"
local game_config = require "config.game_config"
local game_room_config = require "config.game_room_config"
local locator_server_config = require "config.locator_server_config"
local locator_ctrl = {}

--serverid => roomId  多对一
--roomId <==> game_id+room_type  一对一
local unstart_server = {} --roomid

local function set_game_list()
    for server_id, v in pairs(locator_server_config) do
        local type = v.room_id
        if not unstart_server[type] then
            unstart_server[type] = {}
            table.insert(unstart_server[type], server_id)
        end
    end
end

local function get_room_id(game_id, room_type)
    for room_id, v in pairs(game_room_config) do
        if v.room_type == room_type and v.game_id == game_id then
            return room_id
        end
    end
end

local function start_game_server(room_id, game_id)
    local server_id = 0
    if #unstart_server[room_id] > 0 then
        local serverId = table.remove(unstart_server[room_id], 1)
        local str = string.format("./run_%s.sh %d", game_config[game_id].module_name, serverId)
        os.execute(str)
        skynet.error("cy========locator start gameserver =", serverId)
        server_id = serverId
    end
    return server_id
end

local function stop_game_server(room_id, server_id)
    local str = string.format("./stop_game.sh %d", server_id)
    os.execute(str)
    table.insert(unstart_server[room_id], server_id)
    db_helper.call(DB_SERVICE.game, "room.remove_room_inst",room_id, server_id)
    skynet.error("cy========locator stop gameserver =",  server_id)
end

local function gameserver_manager(game_id, room_type)
    local empty_roomnum = 0
    local min_player_num = -1 --最少非empty人数
    local player_limit = 0
    local server_id = 0 --最少非emptyserver
    local stop_empty_server_id = 0
    local room_id = get_room_id(game_id, room_type)
    if not room_id then
        skynet.error("get_room_id nil,game_id, room_type=", game_id, room_type)
        return 
    end
    local room_inst_list = db_helper.call(DB_SERVICE.game, "room.get_room_list", room_id)

    for _, v in pairs(room_inst_list) do
        player_limit = tonumber(v.player_limit)
        local player_num = tonumber(v.player_num)
        local continue = false
        if player_num == 0 then
            empty_roomnum = empty_roomnum + 1
            if empty_roomnum == 1 then
                stop_empty_server_id = v.server_id
                continue = true
            elseif empty_roomnum > 1 then
                stop_game_server(room_id, v.server_id)
                continue = true
            end
        end
        if continue == false and min_player_num == -1 then
            min_player_num = player_num
            server_id = v.server_id
        elseif continue == false and min_player_num > player_num then
            min_player_num = player_num
            server_id = v.server_id
        end
    end
    server_id = type(server_id) == "string" and tonumber(server_id) or server_id
    stop_empty_server_id = type(stop_empty_server_id) == "string" and tonumber(stop_empty_server_id) or stop_empty_server_id
    if server_id == 0 and stop_empty_server_id == 0 or min_player_num == player_limit and stop_empty_server_id == 0 then
        server_id = start_game_server(room_id, game_id)
        assert(server_id ~= -1, "start_game_server get server_id nil")
    elseif min_player_num ~= -1 and min_player_num ~= player_limit and stop_empty_server_id ~= 0 then
        stop_game_server(room_id, stop_empty_server_id)
    end
    if server_id == 0 and stop_empty_server_id ~= 0 then
        return stop_empty_server_id
    else
        return server_id
    end
end

function locator_ctrl.init()
    set_game_list()
    gameserver_manager(101, 2)  -- xpnn平民场
end

function locator_ctrl.route_sid(game_id, room_type)
    local server_id =  gameserver_manager(game_id, room_type)
    if server_id == 0 then
        skynet.error("no config for game_id,room_type=", game_id, room_type)
    end
    return cluster_config[server_id].nodename
end

return locator_ctrl