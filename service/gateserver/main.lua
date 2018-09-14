local skynet = require "skynet"
local cluster_monitor = require "cluster_monitor"
local sproto_helper = require "sproto_helper"
local redis_config = require "config.redis_config"
local cluster_config = require "config.cluster_config"
local http_port = skynet.getenv("http_port")
local watchdog_port = skynet.getenv("watchdog_port")
local wswatchdog_port = skynet.getenv("wswatchdog_port")

skynet.start(function()
  	local cluster_reids_id = tonumber(skynet.getenv("cluster_redis_id"))
	local cluster_server_id = tonumber(skynet.getenv("cluster_server_id"))
	
	cluster_monitor.start(redis_config[cluster_reids_id], cluster_config[cluster_server_id])

	sproto_helper.register_protos()

	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = watchdog_port, 
		maxclient = max_client,
		nodelay = true,
	})

	local wswatchdog = skynet.newservice("wswatchdog")
	skynet.call(wswatchdog, "lua", "start", {
		port = wswatchdog_port,
		maxclient = max_client,
		nodelay = true,
	})

	skynet.newservice("httpServer", http_port)
	local webclient = skynet.uniqueservice("webclient")
	local url = "https://api.weixin.qq.com/sns/oauth2/access_token?appid=APPID&secret=SECRET&code=CODE&grant_type=authorization_code"
	print(skynet.call(webclient, "lua", "request", url))

	skynet.newservice("heartbeat")

	cluster_monitor.open()
 	skynet.error("******************** gateserver start ok ********************")

end)