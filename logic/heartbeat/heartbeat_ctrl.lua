require "skynet.manager"
local skynet = require "skynet"
local db_helper = require "common.db_helper"
local context = require "context"
local utils = require "utils"
local heartbeat_ctrl = {}

local player_heartbeat_map = {}  -- player_id : {update_time, state}

local function do_kick_work(player_id)
    local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", player_id)
    if tonumber(online.offline) == OFFLINE_STATE.on then
        context.call(online.watchdog, "player_leave", tonumber(online.fd))
    end
end

local function do_offline_work(player_id)
    local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", player_id)
    if tonumber(online.offline) == OFFLINE_STATE.off then
        db_helper.call(DB_SERVICE.hall, "hall.update_player_online", player_id, "offline", OFFLINE_STATE.on)
        context.call(online.watchdog, "close", tonumber(online.fd))
    end
end

local function cal_offline_player()
    local curtime = skynet.now()
    for player_id, v in pairs(player_heartbeat_map) do
        local dif_time = (curtime - v.update_time) / 100
        if dif_time < HEART_BEAT_TIME.intval * HEART_BEAT_TIME.intcnt then
            v.state = HEART_BEAT_STATE.normal 
        elseif dif_time >= HEART_BEAT_TIME.kicktime then
            if v.state ~= HEART_BEAT_STATE.kick then
                v.state = HEART_BEAT_STATE.kick
                do_kick_work(player_id)
            end
        elseif dif_time >= HEART_BEAT_TIME.intval * HEART_BEAT_TIME.intcnt then
            if v.state ~= HEART_BEAT_STATE.offline then
                v.state = HEART_BEAT_STATE.offline
                do_offline_work(player_id)
            end
        end
        --skynet.error("cy============================heartbeat state=", dif_time, player_id, v.state)
    end
end

function heartbeat_ctrl.init()
    skynet.fork(function()
		while true do
			skynet.sleep(300)
            cal_offline_player()
		end
	end)
end

function heartbeat_ctrl.reset_updatetime(player_id)
    if player_id then 
        player_heartbeat_map[player_id] = player_heartbeat_map[player_id] or {}
        player_heartbeat_map[player_id].update_time = skynet.now()
    end
end

function heartbeat_ctrl.del_playerId(player_id)
    if player_id then 
        player_heartbeat_map[player_id] = nil
    end
end

return heartbeat_ctrl