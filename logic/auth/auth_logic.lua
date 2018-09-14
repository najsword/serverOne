local skynet = require "skynet"
local json = require "json"
local md5 = require "md5"
local random = require "random"
local crypt = require "sky_crypt"
local context = require "context"
local db_helper = require "common.db_helper"
local create_player_config = require "config.create_player_config"
local nickname_config = require "config.nickname_config"
local utils = require "utils"
local auth_logic = {}

local fd_map = {}

function auth_logic.init()

end

function auth_logic.auth_secret(ctx, req)
	local reply = {}
	if req.step == 1 then
		local ckey =  crypt.base64decode(req.ckey)
		local challenge = crypt.make_random()
		local serverKey = crypt.make_random()
		local skey = crypt.dhexchange(serverKey)
		local secret = crypt.dhsecret(ckey, skey)
		fd_map[ctx.fd] = {}
		fd_map[ctx.fd] = {challenge = challenge, secret = secret}
		reply.challenge = crypt.base64encode(challenge)
		reply.skey = crypt.base64encode(skey)
	elseif req.step == 2 then
		local chmac =  crypt.base64decode(req.chmac)
		local shmac = crypt.hmac64(fd_map[ctx.fd].challenge, fd_map[ctx.fd].secret)
		if shmac ~= chmac then
			skynet.error("cy===================== secret not correct")
			context.rpc_call(ctx.gate, ctx.watchdog, "close_fd", ctx.fd)
		end
	end
	return SYSTEM_ERROR.success, reply
end

local function set_auth_info(ctx, wait_num, player_id)
	local userinfo = {}
	userinfo.user = player_id
	local auth_info = {}
	auth_info.login_addr = 17
	auth_info.subid = 1
	auth_info.secret = fd_map[ctx.fd].secret
	auth_info.waitnum = wait_num
	auth_info.waitsecond = math.floor(wait_num/WAIT_ARGS.basenum) * WAIT_ARGS.basetime
	auth_info.pid = 1
	local online = db_helper.call(DB_SERVICE.hall, "hall.get_player_online", player_id)
	local offline = tonumber(online.offline)
	if offline == OFFLINE_STATE.on then
		auth_info.waitsecond = 0
		auth_info.waitnum = 0
		auth_info.pid = -1
		--auth_info.login_addr = 17
		--auth_info.subid = 1
	end
	db_helper.call(DB_SERVICE.auth, "auth.set_auth_info", userinfo, auth_info)
	fd_map[ctx.fd] = nil
	return auth_info
end

local function decode_passwd(ctx, password)
	return crypt.base64encode(crypt.desdecode(fd_map[ctx.fd].secret, password))
end

function auth_logic.register_account(ctx, req)
	local passwd = decode_passwd(ctx, req.password)
	local conf = create_player_config[req.create_index]
	local account_info = db_helper.call(DB_SERVICE.account, "auth.get_normal_account", nil, req.account)
	if account_info then
		return AUTH_ERROR.account_exist
	end
	local player_id = db_helper.call(DB_SERVICE.unique, "auth.incr_player_id", nil)
	if not player_id then
		return AUTH_ERROR.player_id_limit
	end
	local nickname = req.nickname or random.random_one(nickname_config)
	local player_info = {
		player_id = player_id,
		head_id = conf.head_id,
		head_url = "",
		nickname = nickname,
		sex = conf.sex,
		gold = conf.gold,
		create_time = os.time(),
	}

	db_helper.call(DB_SERVICE.account, "auth.create_player", nil, player_info)

	local account_info = {
		player_id = player_id,
		telephone = req.telephone,
		account = req.account,
		password = passwd,
		create_time = os.time(),
	}
	db_helper.call(DB_SERVICE.account, "auth.create_normal_account", player_id, account_info)
	return SYSTEM_ERROR.success
end

function auth_logic.login_account(ctx, req)
	local passwd = decode_passwd(ctx, req.password)
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
	local auth_info = set_auth_info(ctx, req.wait_num, account_info.player_id)
	local reply = {}
	reply.player = player_info
	reply.auth_info = auth_info
	return SYSTEM_ERROR.success, reply
end

function auth_logic.weixin_login(ctx, req)
	local reply = {}
	local weixin_info = db_helper.call(DB_SERVICE.account, "auth.get_weixin_account", nil, req.union_id)
	if not weixin_info then
		local player_id = db_helper.call(DB_SERVICE.unique, "auth.incr_player_id", nil)
		if not player_id then
			return AUTH_ERROR.player_id_limit
		end
		local conf = random.random_one(create_player_config)
		local player_info = {
			player_id = player_id,
			head_id = conf.head_id,
			head_url = req.head_url,
			nickname = req.nickname,
			sex = req.sex,
			gold = conf.gold,
			create_time = os.time(),
		}
		db_helper.call(DB_SERVICE.account, "auth.create_player", nil, player_info)

		weixin_info = {
			player_id = player_id,
			union_id = req.union_id,
			create_time = os.time(),
		}
		db_helper.call(DB_SERVICE.account, "auth.create_weixin_account", player_id, weixin_info)

		local auth_info = set_auth_info(ctx, req.wait_num, player_id)
		reply.player = player_info
		reply.auth_info = auth_info
		return SYSTEM_ERROR.success, reply
	end

	local player_info = db_helper.call(DB_SERVICE.account, "auth.get_player", weixin_info.player_id)
	if not player_info then
		return AUTH_ERROR.player_not_exist
	end
	local auth_info = set_auth_info(ctx, req.wait_num, weixin_info.player_id)
	reply.player = player_info
	reply.auth_info = auth_info
	return SYSTEM_ERROR.success, reply
end

function auth_logic.visitor_login(ctx, req)
	local reply = {}
	req.visit_token = (not req.visit_token or req.visit_token == "") and ctx.session or req.visit_token
	
	local visitor_info = db_helper.call(DB_SERVICE.account, "auth.get_visitor_account", nil, req.visit_token)
	if not visitor_info then
		local player_id = db_helper.call(DB_SERVICE.unique, "auth.incr_player_id", nil)
		if not player_id then
			return AUTH_ERROR.player_id_limit
		end
		local conf = random.random_one(create_player_config)
		local nickname = random.random_one(nickname_config)
		local player_info = {
			player_id = player_id,
			head_id = conf.head_id,
			head_url = "",
			nickname = "游客"..player_id,
			sex = conf.sex,
			gold = conf.gold,
			create_time = os.time(),
		}

		db_helper.call(DB_SERVICE.account, "auth.create_player", nil, player_info)

		visitor_info = {
			player_id = player_id,
			visit_token = req.visit_token,
			create_time = os.time(),
		}
		db_helper.call(DB_SERVICE.account, "auth.create_visitor_account", player_id, visitor_info)
		
		local auth_info = set_auth_info(ctx, req.wait_num, player_id)
		reply.player = player_info
		reply.auth_info = auth_info
		reply.visit_token = req.visit_token
		return SYSTEM_ERROR.success, reply
	end

	local player_info = db_helper.call(DB_SERVICE.account, "auth.get_player", visitor_info.player_id)
	if not player_info then
		return AUTH_ERROR.player_not_exist
	end
	
	local auth_info = set_auth_info(ctx, req.wait_num, visitor_info.player_id)
	reply.player = player_info
	reply.auth_info = auth_info
	reply.visit_token = visit_token
	return SYSTEM_ERROR.success, reply
end	

return auth_logic