require "skynet.manager"
local skynet = require "skynet"
local context = require "context"
local db_helper = require "common.db_helper"
local utils = require "utils"
local chat_logic = {}


local function get_fds(ctx, req)
    local player_id = ctx.player_id
	local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", player_id)
    if online ~= nil then
        local type = req.type
        local fds = db_helper.call(DB_SERVICE.fd, "fd.get_fds", type, online.game_id, online.server_id, online.room_id, online.room_addr)
        return fds
    end
    return nil
end

local function send_data(ctx, req, fds)
    local reply ={type = req.type, from = ctx.player_id, context = req.context}
    local fd_ctx = req.fd_ctx
    
    for k, s_fd in pairs(fds) do
        local fd = tonumber(s_fd)
        if ctx.fd ~= fd then
            local ctx = fd_ctx[fd]
            context.send_client_event(ctx, M_CHAT.chat_event, reply)
        end
    end
end

function chat_logic.chat_req(ctx, req)
    local contextdata = req.context
    local type = req.type
    if contextdata == nil or type == nil then
        return CHAT_ERROR.chat_param_error
    end
    local fds = get_fds(ctx, req)
    if fds  == nil then
        skynet.error("chat fds is nil")
        return SYSTEM_ERROR.success
    end
    send_data(ctx, req, fds)
    return SYSTEM_ERROR.success
end

return chat_logic