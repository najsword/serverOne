local skynet = require "skynet"
local db_helper = require "common.db_helper"
local utils = require "utils"
local context = require "context"
local crypt = require "sky_crypt"

local login_logic = {}

function login_logic.init()

end

local function get_auth_info(req)
	local user_info = {user = req.playerid}
	return db_helper.call(DB_SERVICE.auth, "auth.get_auth_info", user_info)
end

local function decode_passwd(secret, password)
	return crypt.base64encode(crypt.desdecode(secret, password))
end

function login_logic.signin_account(ctx, req)
	local auth_info = get_auth_info(req)
	if auth_info == nil then
		return AUTH_ERROR.auth_info_expire
	end
	local passwd = decode_passwd(auth_info.secret, req.password)
	local account_info = db_helper.call(DB_SERVICE.account, "auth.get_normal_account", nil, req.account)
	if not account_info then
		return AUTH_ERROR.account_not_exist
	end
	if account_info.password ~= passwd then
		return AUTH_ERROR.password_wrong
	end
	local player_info = db_helper.call(DB_SERVICE.account, "auth.get_player", account_info.player_id)
	if not player_info then
		return AUTH_ERROR.player_not_exist
	end
	local reply = {}
	reply.player = player_info
	return SYSTEM_ERROR.success, reply
end

function login_logic.weixin_account(ctx, req)
	local auth_info = get_auth_info(req)
	if auth_info == nil then
		return AUTH_ERROR.auth_info_expire
	end
	local player_info = db_helper.call(DB_SERVICE.account, "auth.get_player", req.playerid)
	if not player_info then
		return AUTH_ERROR.player_not_exist
	end
	local reply = {}
	reply.player = player_info
	return SYSTEM_ERROR.success, reply
end

function login_logic.vistor_account(ctx, req)
	local auth_info = get_auth_info(req)
	if auth_info == nil then
		return AUTH_ERROR.auth_info_expire
	end
	local player_info = db_helper.call(DB_SERVICE.account, "auth.get_player", req.playerid)
	if not player_info then
		return AUTH_ERROR.player_not_exist
	end
	local reply = {}
	reply.player = player_info
	return SYSTEM_ERROR.success, reply
end

return login_logic