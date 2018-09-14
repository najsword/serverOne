	模块分类
实现模块
基础服务：集群模块 消息处理模块  数据库模块
gateserver: 网关模块 http模块 websocket模块 
authserver: 网关模块  断线重连模块 排队认证模块
loginserver: 登录模块
hallserver: game模块
locatorserver:  locator模块
gameserver: game模块
chatserver: chat模块
dbserver: 数据库模块

待实现模块
AOI模块
日志染色
热更新 
宕机重启  redis存放在线用户的rpc请求
限流降级
redis mysql事务

-----------------------------------
	使用
下载
https://github.com/zhangshiqian1214/skynet-server
修改：
1 顶层makefile添加lsocket库支持
2 skynet makefile添加 skynet_crypt httppack add支持
lualib-src/lua-crypt.c  lualib-src/lua-httppack.c  lualib-src/add.c

安装
skynet: yum install dos2unix; yum install libcurl-dev libcurl-devel
make socket  安装客户端lsocket
问题： 安装 Redis 执行 make #error "Newer version of jemalloc required"
=> make MALLOC=libc
openssl/crypto.h: No such file or directory
=> yum install openssl-devel
“uuid/uuid.h: No such file or directory
=> yum install libuuid-devel

测试cluster：1 ./run_test1.sh  ./run_test.sh

运行
1 只启动gate login hall db服务，redis没有其他服务
单服务启动
./run_redis.sh
./run_gate.sh
./run_login.sh
./run_hall.sh
./run_db.sh
单服务停止
pkill -u `whoami` -xf "./skynet/skynet ./config/config_xpnn __default__"
停止game服务
pkill -u `whoami` -xf "./skynet/skynet ./config/config_xpnn21 __default__"
2 启动客户端
./client.sh 1
控制台输入0   正常退出客户端
控制台ctrl+c  断线(socket直接断开)

重启所有服务
./restart.sh