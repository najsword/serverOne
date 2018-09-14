require "skynet.manager"
local skynet = require "skynet"
local db_helper = require "common.db_helper"
local utils = require "utils"
local cluster_config = require "config.cluster_config"
local game_config = require "config.game_config"
local locator_server_config = require "config.locator_server_config"
local locator_ctrl = {}

--只能执行一次
local function set_unstart_server_map()
    local start_map = {}
    local unstart_map = {}
    for server_id, v in pairs(locator_server_config) do
        local game_id = v.game_id
        if start_map[game_id] ~= nil then
            skynet.error("cy=================gameid has store", game_id)
        elseif unstart_map[game_id] ~= nil then
            db_helper.call(DB_SERVICE.game, "room.lpush_server_id", game_id, server_id)
        else
            local num = db_helper.call(DB_SERVICE.game, "room.llen_server_id", game_id)
            if num > 0 then
                start_map[game_id] = {}
                start_map[game_id] = game_id
            else
                unstart_map[game_id] = {}
                unstart_map[game_id] = game_id
                db_helper.call(DB_SERVICE.game, "room.lpush_server_id", game_id, server_id)
            end
        end
    end
end

function locator_ctrl.init()
    set_unstart_server_map()
end

local function register_start_server(game_id)
    local server_id = 0
    local reply = db_helper.call(DB_SERVICE.game, "room.lpop_server_id", game_id)
    if reply ~= nil then
        server_id = tonumber(reply[1])
        db_helper.call(DB_SERVICE.game, "room.register_server", game_id, server_id)
        return server_id
    end
end

local function start_server(game_id, server_id)
    local str = string.format("./run_%s.sh %d", game_config[game_id].module_name, server_id)
    os.execute(str)
    skynet.error("cy========locator start gameserver =", server_id)
end

local function stop_server(server_id)
    local str = string.format("./stop_game.sh %d", server_id)
    os.execute(str)
    skynet.error("cy========locator stop gameserver =", server_id)
    local game_id = locator_server_config[server_id].game_id
    db_helper.call(DB_SERVICE.game, "room.lpush_server_id", game_id, server_id)
end

local function check_stop_server()
    local reply = db_helper.call(DB_SERVICE.game, "room.lpop_unstop_server")
    if reply ~= nil then
        local server_id = tonumber(reply[1])
        stop_server(server_id)
    end
end

local function get_server_id(game_id)
    local server_id = 0
    local reply = db_helper.call(DB_SERVICE.game, "room.get_max_server", game_id)
    if reply ~= nil then
        server_id = tonumber(reply[1])
        local fd_num = tonumber(reply[2])
        if fd_num == locator_server_config[server_id].player_limit then
            server_id = register_start_server(game_id)
            if server_id ~= 0 then
                start_server(game_id, server_id)
            end
        end
    end
    return server_id
end

function locator_ctrl.register_start_info(server_id)
    skynet.error("cy====================register_start_info", server_id)
    local game_id = locator_server_config[server_id].game_id
    db_helper.call(DB_SERVICE.game, "room.lrem_server_id", game_id, server_id)
    db_helper.call(DB_SERVICE.game, "room.register_server", game_id, server_id)
    return SYSTEM_ERROR.success
end

function locator_ctrl.route_sid(game_id)
    check_stop_server()
    local server_id =  get_server_id(game_id)
    if server_id == 0 then
        skynet.error("no find server_id for game_id=", game_id)
    end
    return cluster_config[server_id].nodename
end

return locator_ctrl