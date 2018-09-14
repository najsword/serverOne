local skynet = require "skynet"
local context = require "context"
local utils = require "utils"
local db_helper = require "common.db_helper"
local cache_logic = {}


function cache_logic.set_cache(packid, player_id, proto_id, ec, data)
    if packid == nil or player_id == nil or proto_id == nil then
        return
    end
    local pack_info = {player_id = player_id, pack_id = packid}
    local pack_data = {proto_id = proto_id, ec = ec, data = data}
    db_helper.call(DB_SERVICE.auth, "cache.insert_cache_info", pack_info, pack_data)
end

function cache_logic.get_cache(player_id, packid, protoid)
    if player_id == nil or packid == nil or protoid == nil then
        return nil
    end
	local pack_info = {player_id = player_id, pack_id = packid}
    return db_helper.call(DB_SERVICE.auth, "cache.get_cache_info_by_protoid", pack_info, protoid)
end

function cache_logic.set_c_context(c, player_id)	
    local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", player_id)
    if online and tonumber(online.offline) == OFFLINE_STATE.on then
        skynet.error("cy=========================================================================do reconnect work ssssss")
        context.rpc_call(online.gate, online.watchdog, "set_c_context", c.fd, online)
        context.rpc_call(online.gate, SERVICE.HEARTBEAT, "reset_updatetime", player_id)
        local update_online_info = {
            offline = OFFLINE_STATE.off,
            fd = c.fd,
            ip = c.ip,
            gate = c.gate,
            watchdog = c.watchdog,
        }
        db_helper.call(DB_SERVICE.hall, "hall.set_player_online", player_id, update_online_info)
	end
end

return cache_logic