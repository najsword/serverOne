local skynet = require "skynet"

local CMD = {}
local HTTP = {}
local http

function HTTP.open(fd, addr)
	print("watchdog conn:"..fd)
end

function HTTP.close(fd)
	print("socket close",fd)
end

local function tablify(tbl)
	local res = '<table style="border: 1px solid grey">'
	local k, v
	for k, v in pairs(tbl) do
		res = res .. '<tr><th align="right" valign="top" style="border: 1px solid grey">' .. k .. "</th><td>"
		if type(v) == "table" then
			res = res .. tablify(v)
		else
			res = res .. tostring(v)
		end
		res = res .. "</td></tr>"
	end
	res = res .. "</table>"
	return res
end

function HTTP.error(fd, msg)
	print("socket error",fd, msg)
end

function HTTP.get(rq, header)
	print("http recv:", rq.url)

	local res = table.concat {
		"<html><head><title>", rq.url, "</title></head><body><pre>",
		'<h1><b>GET</b> ', rq.url, "</h1>"}
	if rq.path == "/status" then
		res = res .. "<h2>Status</h2>" .. tablify(server:status())
	else
		res = res .. table.concat{
			"<h2>Header</h2>",
			tablify(header),
			"<h2>Request</h2>",
			tablify(rq)}
	end
	res = res .. "</pre></body></html>"

	return res
end

function HTTP.post(rq, header, data)
	print("http recv:", data)

	local res = table.concat{
		"<html><head><title>", rq.url, "</title></head><body><pre>",
		'<h1><b>POST</b> ', rq.url, "</h1>",
		"<h2>Header</h2>",
		tablify(header),
		"<h2>Request</h2>",
		tablify(rq),
		"<b>data:</b><br>", data, "<br>",
		"</pre></body></html>"}

	return res
end


function CMD.start(conf)
	skynet.call(http, "lua", "open" , conf)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "http" then
			local f = HTTP[subcmd]
			local res = f(...)
			if res then
				skynet.ret(skynet.pack(res))
			end
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)

	http = skynet.newservice("http")
end)
