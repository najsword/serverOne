local PATH,IP,UID = ...

IP = IP or "127.0.0.1"
UID = UID or "alice"
package.path = string.format("%s/lualib/?.lua;%s/preload/?.lua;%s/client/?.lua;%s/skynet/lualib/?.lua", PATH,PATH, PATH, PATH)
package.cpath = string.format("%s/skynet/luaclib/?.so;%s/lsocket/?.so", PATH, PATH)


require "preload"
local socket = require "simplesocket"
local IoConsole = require "client.socket"
local message = require "simplemessage"
local utils = require "utils"
local crypt = require "sky_crypt"
local os = require "os"

--test area
-- local challenge = secret.make_random()
-- local clientkey = secret.make_clientkey()
-- print("clientkey:" , clientkey)
-- local ckey = secret.make_ckey(clientkey)
-- print("ckey:\t" , secret.hexencode(ckey))

-- local serverkey = secret.make_serverkey()
-- print("serverkey:" , serverkey)
-- local skey = secret.make_skey(serverkey)
-- print("skey:\t" , secret.hexencode(skey))

-- local csecret = secret.dhsecret(skey, clientkey)
-- print("use skey clientkey dhsecret:", secret.hexencode(csecret)) --交换成功

-- local ssecret = secret.dhsecret(ckey, serverkey)
-- print("use ckey serverkey dhsecret:", secret.hexencode(ssecret)) --交换成功

-- local ssecret = secret.dhsecret(ckey, skey)                  --交换失败
-- print("use ckey skey dhsecret:\t", secret.hexencode(ssecret))


--test area end

--message.register(string.format("%s/proto/%s", PATH, "proto"))

--创建认证连接
message.peer(IP, 5003)
message.connect()

local weight = 0
local event = {}  --s2c request/s2c response/c2s request
local sitIndex = 0
local subid = 0
local login_addr = 0
local last_pack_data = nil
local player_id = nil
-- 心跳
local is_start_heart = false
local heart_interval = 3
local lst_time = nil
message.bind({}, event)

local mycards
function event:__error(what, err, req, session)
	print("error", what, err)
end

function event:ping()
	 --print("event ping")
end

--登录
function event:signin(req, resp)

end

--注册
function event:signup(req, resp)

end

function event:login(_, resp)

end

function event:joinroom(_, resp)

end

-- 发送心跳
function event:heartbeat()
	print("recv heartbeat")
	--message.request "ping"
end

function event:onuserready(args)

end

function event:onjoinroom(args)

end

function event:onleftroom(args)

end

function requestmaster()

end

function event:ongameready(args)

end

function event:ongamestart(args)

end

function event:onrequestmaster(args)

end

function event:onplay(args)

end

function event:ongameover(args)

end

function event:push(args)
	print("server push", args.text)
end

--分配pack_id
local packid = 100
local is_redo = false --true
local function get_pack_id(protoid)
	local real_packid = nil
	if protoid ~= nil then
		if protoid == 0x0901 then
			real_packid = 1
		elseif protoid == 0x0701 then
			real_packid = 2
		elseif protoid == 0x0703 then
			real_packid = 3
		elseif protoid == 0x0705 then
			real_packid = 4
		elseif protoid == 0x0d03 then
			real_packid = 5
		elseif protoid == 0x0704 then
			real_packid = 6
		elseif protoid == 0x0903 then
			real_packid = 7
		elseif protoid == 0x0904 then
			real_packid = 8
		end
	else
		if packid < 150 then
			packid = packid + 1
		else 
			packid = 101
		end
		real_packid = packid
	end
	if is_redo then
		return -real_packid
	else
		return real_packid
	end
end
--[[
1  login.signin_account
2  area.enter_area
3  room.get_role
4  area.enter_room
5  room.group_request
]]--

--auth
local challenge = nil
local skey = nil
local secret = nil
local clientkey = crypt.make_random()
local ckey = crypt.dhexchange(clientkey)

--auth.auth_secret
message.request({protoid=0x0105,packid=0,response=0}, {step=1, ckey=crypt.base64encode(ckey), chmac=""})

function event:auth_secret(header, data)
	print("auth_secret ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "auth_secret fail")
	if data.challenge then
		challenge = crypt.base64decode(data.challenge)
		skey = crypt.base64decode(data.skey)
		secret = crypt.dhsecret(ckey, skey)
		local chmac = crypt.hmac64(challenge, secret)
		-- auth.auth_secret
		message.request({protoid=0x0105,packid=0,response=0}, {step=2, ckey="", chmac=crypt.base64encode(chmac)})
	else
		-- auth.login_account
		message.request({protoid=0x0102,packid=0,response=0}, {account = UID, password= crypt.desencode(secret, "1")})
		--message.request({protoid=0x0103,packid=0,response=0}, { union_id = UID, head_url= "1", nickname="wx_xixi", sex=1})
		--message.request({protoid=0x0104,packid=0,response=0}, { visit_token = ""})
	end
end

local function enter_login(auth_info)
	-- 排队
	if auth_info.waitsecond ~= 0 then
		print("sleeptime=", auth_info.waitsecond)
		utils.Sleep(auth_info.waitsecond)
	end
	-- 创建登录连接
	message.close()
	message.peer(IP, 5001)
	message.connect()

	subid = auth_info.subid
	login_addr = auth_info.login_addr
	if auth_info.pid == -1 then
		is_redo = true
	else
		is_redo = false
	end
	-- login.signin_account
	message.request({protoid=0x0901,playerid=player_id,packid=get_pack_id(0x0901),response=0}, { account = UID, password= crypt.desencode(secret, "1"), subid = subid, login_addr = login_addr})
	--message.request({protoid=0x0903,playerid=player_id,packid=get_pack_id(0x0903),response=0}, { subid = subid, login_addr = login_addr})
	--message.request({protoid=0x0904,playerid=player_id,packid=get_pack_id(0x0904),response=0}, { subid = subid, login_addr = login_addr})
end

function event:register_account(header, data)
	print("register_account ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "register_account fail")
	player_id = data.player.player_id
	print("register_account, subid login_addr, waitsecond, waitnum=",data.auth_info.subid, data.auth_info.login_addr, data.auth_info.subid, data.auth_info.waitsecond, data.auth_info.waitnum)
	enter_login(data.auth_info)
end

function event:login_account(header, data)
	print("login_account ack")
	if header.errorcode ~= SYSTEM_ERROR.success then
		print("login_account fail")
		-- auth.register_account
		message.request({protoid=0x0101,packid=0,response=0}, { account = UID, password= crypt.desencode(secret, "1"), telephone="110", agent_id = UID, create_index=1})
		return
	end
	player_id = data.player.player_id
	print("login_account, subid login_addr, waitsecond, waitnum=",data.auth_info.subid, data.auth_info.login_addr, data.auth_info.subid, data.auth_info.waitsecond, data.auth_info.waitnum)
	enter_login(data.auth_info)
	-- hall.get_room_inst_list
--	message.request({protoid=0x0201,response=0}, 10101)
	-- hall.get_player_online_state
--	message.request({protoid=0x0202,response=0}, nil)

	--room.enter_room
	--message.request({protoid=0x0d01,response=0,roomproxy=101,roomtype=2}, nil)
end

function event:weixin_login(header, data)
	print("weixin_login ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "weixin_login fail")
	player_id = data.player.player_id
	print("login_account, subid login_addr, waitsecond, waitnum=",data.auth_info.subid, data.auth_info.login_addr, data.auth_info.subid, data.auth_info.waitsecond, data.auth_info.waitnum)
	enter_login(data.auth_info)
end

function event:visitor_login(header, data)
	print("visitor_login ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "visitor_login fail")
	player_id = data.player.player_id
	print("login_account, subid login_addr, waitsecond, waitnum=",data.auth_info.subid, data.auth_info.login_addr, data.auth_info.subid, data.auth_info.waitsecond, data.auth_info.waitnum)
	enter_login(data.auth_info)
end

--login
function event:signin_account(header, data)
	print("signin_account ack")
	if header.errorcode ~= SYSTEM_ERROR.success then
		print("signin_account fail")
		return
	end
	is_start_heart = true
	lst_time = os.time()
	--area.enter_area
	message.request({protoid=0x0701,packid=get_pack_id(0x0701),roomproxy=101,response=0}, {game_id=101})
end

function event:weixin_account(header, data)
	print("weixin_account ack")
	if header.errorcode ~= SYSTEM_ERROR.success then
		print("weixin_account fail")
		return
	end
	is_start_heart = true
	lst_time = os.time()
	--area.enter_area
	message.request({protoid=0x0701,packid=get_pack_id(0x0701),roomproxy=101,response=0}, {game_id=101})
end

function event:vistor_account(header, data)
	print("vistor_account ack")
	if header.errorcode ~= SYSTEM_ERROR.success then
		print("vistor_account fail")
		return
	end
	is_start_heart = true
	lst_time = os.time()
	--area.enter_area
	message.request({protoid=0x0701,packid=get_pack_id(0x0701),roomproxy=101,response=0}, {game_id=101})
end

function event:logout_account(header, ata)
	print("logout_account ack")
	if header.errorcode ~= SYSTEM_ERROR.success then
		print("logout_account fail")
		return
	end
end

--hall
function event:get_room_inst_list(header, data)
	print("get_room_inst_list ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "get_room_inst_list fail")
end

function event:get_player_online_state(header, data)
	print("get_player_online_state ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "get_player_online_state fail")
end

--area
function event:enter_area(header, data)
	print("enter_area ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "enter_area fail")
	--room.get_role
	message.request({protoid=0x0703,packid=get_pack_id(0x0703),response=0}, {})
end

function event:exit_area(header, data)
	print("exit_area ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "exit_area fail")
end

function event:get_role(header, data)
	print("get_role ack")
	if header.errorcode ==  ROLE_ERROR.role_nil then
		--room.create_role
		print("ready create_role")
		message.request({protoid=0x0704,packid=get_pack_id(0x0704),response=0}, {create_index=1})
		return
	elseif header.errorcode ~=  SYSTEM_ERROR.success then
		print("get_role fail")
		return
	end
	--room.exit_area
	--message.request({protoid=0x0702,response=0}, {})

	--area.enter_room
	message.request({protoid=0x0705,packid=get_pack_id(0x0705),response=0}, {roomtype=2})
end

function event:create_role(header, data)
	print("create_role ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "create_role fail")
	--area.enter_room
	message.request({protoid=0x0705,packid=get_pack_id(0x0705),response=0}, {roomtype=2})
end

function event:enter_room(header, data)
	print("enter_room ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "enter_room fail")

	--message.close()
	--room.group_request
	message.request({protoid=0x0d03,packid=get_pack_id(0x0d03),response=0}, nil)

	--utils.Sleep(10)
	--room.exit_room
	--message.request({protoid=0x0d02,response=0}, nil)
end

--room
function event:exit_room(header, data)
	print("exit_room ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "exit_room fail")
	--area.exit_area
	message.request({protoid=0x0702,response=0}, nil)
end

function event:group_request(header, data)
	print("group_request ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "group_request fail")
	
	--room.exit_room
	--message.request({protoid=0x0d02,response=0}, nil)

	--room.logout_desk
	--message.request({protoid=0x0d04,response=0}, nil)

	--chat.chat_req
	--message.request({protoid=0x0801,response=0}, {type=1, context="it is a hall chat"})
end

function event:logout_desk(header, data)
	print("logout_desk ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "logout_desk fail")
end

function event:seat_state_event(header, data)
	print("seat_state_event ack")
	-- utils.print_r(header)
	-- utils.print_r(data)
end

function event:game_start_event(header, data)
	-- proto未定义
	print("game_start_event ack")
	-- utils.print_r(header)
	-- utils.print_r(data)
end

function event:game_end_event(header, data)
	-- proto未定义
	print("game_end_event ack")
end

function event:exit_desk_event(header, data)
	print("exit_desk_event ack")
end

function event:add_cd_event(header, data)
	print("add_cd_event ack")
end

function event:del_cd_event(header, data)
	print("del_cd_event ack")
end

-- chat
function event:chat_req(header, data)
	print("chat_req ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "chat_req fail")
end

function event:chat_event(header, data)
	print("chat_event ack", header.errorcode)
	utils.print_r(header)
	utils.print_r(data)
end

-- gate.heart_beat
function event:heart_beat(header, data)
	--print("heart_beat ack")
	assert(header.errorcode == SYSTEM_ERROR.success, "heart_beat fail")
end


local function getCmd(cmd)
	if cmd == "0" then
		--login.logout_account
		message.request({protoid=0x0902,packid=0,response=0}, nil)
		is_start_heart = false
	end
end

local function send_heart_beat(is_start_heart)
	if is_start_heart == false then
		return 
	end
	local dtime = os.time() - lst_time
	if dtime >= heart_interval then
		lst_time = os.time()
		-- gate.heart_beat
		message.request({protoid=0x0002,packid=0,response=0}, nil)
    end
end

-- singup
--message.request({protoid=0x0101,response=0}, { account = UID, password= "1", telephone="110", agent_id = UID, create_index=1, nickname=UID})

while true do
	message.update(1)
	send_heart_beat(is_start_heart)
	local cmd = IoConsole.readstdin()
	if cmd ~= nil then
		getCmd(cmd)
	end
end
