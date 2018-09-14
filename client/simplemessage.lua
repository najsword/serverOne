local socket = require "simplesocket"
local sproto = require "sproto"
local sproto_helper = require "sproto_helper"

local proto_map = require "proto_map"
local utils = require "utils"
local message = {}
local var = {
	session_id = 0 ,
	session = {},  -- [var.session_id] = { name = funcName, req = args }
	object = {},
}

sproto_helper.register_protos()

function message.register(name)
	local f = assert(io.open(name .. ".s2c.sproto"))
	local t = f:read "a"
	f:close()
	--sproto:host([packagename]) creates a host object to deliver the rpc message.
	var.host = sproto.parse(t):host "package"
	local f = assert(io.open(name .. ".c2s.sproto"))
	local t = f:read "a"
	f:close()
	--host:attach(sprotoobj) creates a function(protoname, message, session, ud) to pack and encode request message with sprotoobj
	var.request = var.host:attach(sproto.parse(t))
end

function message.peer(addr, port)
	var.addr = addr
	var.port = port
end

function message.connect()
	socket.connect(var.addr, var.port)
	socket.isconnect()
end

function message.bind(obj, handler)
	var.object[obj] = handler
end

function message.close()
	socket.close()
end

-- c2s request
function message.request(header, data)
	var.session_id = var.session_id + 1
	var.session[var.session_id] = { name = header, req = data }
	socket.write(sproto_helper.pack(header, data))
	return var.session_id
end

function message.update(ti)
	local msg = socket.read(ti)
	if not msg then
		return false
	end
	local header, data = sproto_helper.unpack(msg, #msg)
	local proto = proto_map.protos[header.protoid]
	local funcname = proto.name

	for obj, handler in pairs(var.object) do
		local f = handler[funcname]
		if f then
			local ok, err_msg = pcall(f, obj, header, data)
			if not ok then
				print(string.format("funcname  for [%s] error : %s", funcname, tostring(obj), err_msg))
			end
		end
	end

	--[[host:dispatch(blob [,sz])unpack and decode (sproto:pdecode) the binary string with type the host created (packagename).
If .type is exist, it's a REQUEST message with .type , returns "REQUEST", protoname, message, responser, .ud. The responser is a function
	 for encode the response message. The responser will be nil when .session is not exist.
If .type is not exist, it's a RESPONSE message for .session . Returns "RESPONSE", .session, message, .ud .
--]]

--[[
	local t, session_id, resp, err = var.host:dispatch(msg)
	if t == "REQUEST" then  --s2c request
		--print("s2c request=", session_id, resp)
		for obj, handler in pairs(var.object) do
			local f = handler[session_id]	-- session_id is request type
			if f then
				local ok, err_msg = pcall(f, obj, resp)	-- resp is content of push
				if not ok then
					print(string.format("push %s for [%s] error : %s", session_id, tostring(obj), err_msg))
				end
			end
		end
	else --s2c response
		--print("s2c response=", session_id, resp)
		local session = var.session[session_id]
		var.session[session_id] = nil

		for obj, handler in pairs(var.object) do
			if err then
				local f = handler.__error
				if f then
					local ok, err_msg = pcall(f, obj, session.name, err, session.req, session_id)
					if not ok then
						print(string.format("session %s[%d] error(%s) for [%s] error : %s", session.name, session_id, err, tostring(obj), err_msg))
					end
				end
			else
				local f = handler[session.name]  -- session_id => request type
				if f then
					local ok, err_msg = pcall(f, obj, session.req, resp, session_id)
					if not ok then
						print(string.format("session %s[%d] for [%s] error : %s", session.name, session_id, tostring(obj), err_msg))
					end
				end
			end
		end
	end
]]--
	return true
end

return message
