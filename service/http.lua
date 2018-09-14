local skynet = require "skynet"
local netpack = require "httppack"
local socketdriver = require "skynet.socketdriver"

local socket
local watchdog
local maxclient
local client_number = 0
local CMD = {}

local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}	-- agent -> connection

-- dummy handler
local process = {
	get = function(agent, rq, header) local res = skynet.call(agent, "lua", "http", "get", rq, header)  return "200", res end,
	post = function(agent, rq, header, data) res = skynet.call(agent, "lua", "http", "post", rq, header, data)  return "200", res end,
}

local http_status_msg = {
	["100"] = "Continue",
	["101"] = "Switching Protocols",
	["200"] = "OK",
	["201"] = "Created",
	["202"] = "Accepted",
	["203"] = "Non-Authoritative Information",
	["204"] = "No Content",
	["205"] = "Reset Content",
	["206"] = "Partial Content",
	["300"] = "Multiple Choices",
	["301"] = "Moved Permanently",
	["302"] = "Found",
	["303"] = "See Other",
	["304"] = "Not Modified",
	["305"] = "Use Proxy",
	["307"] = "Temporary Redirect",
	["400"] = "Bad Request",
	["401"] = "Unauthorized",
	["402"] = "Payment Required",
	["403"] = "Forbidden",
	["404"] = "Not Found",
	["405"] = "Method Not Allowed",
	["406"] = "Not Acceptable",
	["407"] = "Proxy Authentication Required",
	["408"] = "Request Time-out",
	["409"] = "Conflict",
	["410"] = "Gone",
	["411"] = "Length Required",
	["412"] = "Precondition Failed",
	["413"] = "Request Entity Too Large",
	["414"] = "Request-URI Too Large",
	["415"] = "Unsupported Media Type",
	["416"] = "Requested range not satisfiable",
	["417"] = "Expectation Failed",
	["500"] = "Internal Server Error",
	["501"] = "Not Implemented",
	["502"] = "Bad Gateway",
	["503"] = "Service Unavailable",
	["504"] = "Gateway Time-out",
	["505"] = "HTTP Version not supported",
}

-- helpers, and also utility methods for the httpd lib
local function urldecode(str)
	str = string.gsub(str, "+", " ")
	str = string.gsub(str, "%%(%x%x)",
		function(h) return char(tonumber(h,16)) end)
	str = string.gsub (str, "\r\n", "\n")
  return str
end

local function urlencode(str)
	if (str) then
		str = string.gsub(str, "\n", "\r\n")
		str = string.gsub(str, "([^%w ])",
			function (c) return format ("%%%02X", byte(c)) end)
		str = string.gsub (str, " ", "+")
	end
	return str	
end

-- helper for the read_request function: ensure that there is an entire
-- line present in the data read from the socket, read more if necessary
-- and return the line (and aux data) if there is one.
local function next_line(buf, pos)
	local b, e, str = string.find(buf, "^([^\r\n]*)\r?\n", pos)
	return b, e, str, buf
end


-- reads the entire request data and returns
-- - information about the request (method, url, peer, ...)
-- - the request headers as a table
-- - the request body
local function read_request(data)
	local request, header, body
	local method, url, httpver, path, args
	local pos = 1

	-- read request line
	local b, e, ln, rq = next_line(data, pos)
	method, url, httpver = match(ln, "^(%a+)%s+([^%s]+)%s+HTTP/([%d%.]+)$")
	if not method then return error("can't find request line") end
	if string.find(url, "?", 1, true) then
		path, args = string.match(url, "^([^?]+)%?(.+)$")
	else
		path = url
	end
	
	request = {
		method = string.lower(method),
		url = url,
		path = urldecode(path),
		args = args,
		httpver = tonumber(httpver),
		--peer = sock:info("peer")
	}
	pos = e + 1

	-- read header
	header = {}
	repeat
		b, e, ln, rq = next_line(data, pos)
		if ln == nil then
			break
		end
		if #ln > 0 then
			local name, val = string.match(ln, "^([^%s:]+)%s*:%s*(.+)$")
			header[string.lower(name)] = urldecode(val)
		end
		pos = e + 1
	until #ln == 0

	-- read body
	if header["content-length"] then
		local clen = tonumber(header["content-length"])
		if #rq - pos + 1 ~= clen then
			return error("can't find content data") 
		end
		body = string.sub(rq, pos, pos + clen - 1)
	end

	return request, header, body
end

local function process_request( agent, rq, headers, body )
	local ok, status, res, hdr, answer, smsg, k, v

	-- check whether we can process the request. If so, call the handler
	if rq.httpver < 1.0 or rq.httpver > 1.1 then
		res = "<html><head>Error</head><body><h1>HTTP version not supported</h1></body></html>"
		status = "505"
	else
		if rq.method ~= nil and process[string.lower(rq.method)] ~= nil then
			ok, status, res, hdr = pcall(process[string.lower(rq.method)], agent, rq, headers, body)
		end

		-- check return status
		if ok then
			res = res or "(no data)"
			status = tostring(status)
		elseif not ok and res == nil then
			res = "<html><head>Error</head><body><h1>Internal Error</h1>"
			res = res .. "<p>" .. status .. "</p></body></html>"
			status = "500"
			keepalive = false
		else
			res = "<html><head>Error</head><body><h1>Not Implemented</h1></body></html>"
			status = "501"
			keepalive = false
		end

		-- compose reply to client: a simple http header and the result of the
		-- handler as body.
		smesg = http_status_msg[status] or "unknown status"
		answer = "HTTP/" .. rq.httpver .. " " .. status .. " " .. smesg .. "\r\n"
		answer = answer .. "Content-Type: text/html\r\n"
		answer = answer .. "Content-Length: " .. tostring(#res) .. "\r\n"

		if hdr then
			for k, v in pairs(hdr) do
				answer = answer .. k .. ": " .. tostring(v) .. "\r\n"
			end
		end
		answer = answer .. "\r\n"
		answer = answer .. res
	end

	return ok, status, res, hdr, smesg, answer
end

function CMD.open( source , conf )
	assert(not socket)
	local address = conf.address or "0.0.0.0"
	local port = assert(conf.port)
	maxclient = conf.maxclient or 1024
	watchdog = conf.watchdog or source
	print("cy====httpserver", conf.address,conf.port)
	socket = socketdriver.listen(address, port)
	socketdriver.start(socket)
end

function CMD.close()
	assert(socket)
	socketdriver.close(socket)
	socket = nil
end

local function unforward(c)
	if c.agent then
		forwarding[c.agent] = nil
		c.agent = nil
		c.client = nil
	end
end

local function start(c)
	if not c.mode then
		c.mode = "open"
		socketdriver.start(c.fd)
	end
end

function CMD.forward(source, fd, client, address)
	local c = assert(connection[fd])
	unforward(c)
	start(c)

	c.client = client or 0
	c.agent = address or source

	forwarding[c.agent] = c
end

function CMD.accept(source, fd)
	local c = assert(connection[fd])
	unforward(c)
	start(c)
end

function CMD.kick(source, fd)
	local c
	if fd then
		c = connection[fd]
	else
		c = forwarding[source]
	end

	assert(c)

	if c.mode ~= "close" then
		c.mode = "close"
		socketdriver.close(c.fd)
	end
end

local MSG = {}
-- 网关消息分发，如果有agent，需要等客户端确定服务端已经分配好agent后才能后续通讯
function MSG.data(fd, msg, sz)
	-- recv a package, forward it
	local c = connection[fd]
	local agent = c.agent
	if agent == nil then
		agent = watchdog
	end
	local rq, headers, body = read_request(msg)
	local ok, status, res, hdr, smesg, answer = process_request(agent, rq, headers, body)

	socketdriver.send(fd, answer)
	connection[fd] = nil
	socketdriver.close(fd)
end

function MSG.open(fd, msg)
	if client_number >= maxclient then
		socketdriver.close(fd)
		return
	end
	local c = {
		fd = fd,
		ip = msg,
	}
	connection[fd] = c
	client_number = client_number + 1
	skynet.send(watchdog, "lua", "http", "open", fd, msg)
end

local function close_fd(fd, message)
	local c = connection[fd]
	if c then
		unforward(c)
		connection[fd] = nil
		client_number = client_number - 1
	end
end

function MSG.close(fd)
	close_fd(fd)
	skynet.send(watchdog, "lua", "http", "close", fd)
end

function MSG.error(fd, msg)
	close_fd(fd)
	skynet.send(watchdog, "lua", "http", "error", fd, msg)
end

skynet.register_protocol {
	name = "socket",
	id = skynet.PTYPE_SOCKET,	-- PTYPE_SOCKET = 6
	unpack = function ( msg, sz )
		local type, fd, data, sz = netpack.filter( msg, sz)
		print("cy===netpack", msg, sz,type, fd, data, sz)
		return type, fd, data, sz
	end,
	dispatch = function (_, _, type, ...)
		if type then
			print("cy===dispatch", type)
			MSG[type](...)
		end
	end
}

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

skynet.start(function()
	skynet.dispatch("lua", function (_, address, cmd, ...)
		local f = assert(CMD[cmd])
		skynet.ret(skynet.pack(f(address, ...)))
	end)
end)
