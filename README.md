-----------------------------------
# 模块分类
## 实现模块
    基础服务：集群模块 消息处理模块  数据库模块
    gateserver: 网关模块 http模块 websocket模块 
    authserver: 网关模块  断线重连模块 排队认证模块
    loginserver: 登录模块
    hallserver: game模块
    locatorserver:  locator模块
    gameserver: game模块
    chatserver: chat模块
    dbserver: 数据库模块

## 待实现模块
    AOI模块
    日志染色
    热更新 
    宕机重启  redis存放在线用户的rpc请求
    限流降级
    redis mysql事务
	
## 垂直分布
    auth 认证、注册、排队
    login 登录
    hall 平台 (认证、第三方、支付、邮件)
    area (mmo)
    room (副本/moba/rpg)
    desk (team)  同服组队，或者跨服组队(desk服务独立于room实现)
    locator  辅助启动、负载均衡gameserver
    chat  聊天

## 注意：
    redis无法存放int数据
    pkill skynet;rm -f console.log;touch console.log;./start.sh 1;cat console.log;tail -f console.log
    
-----------------------------------
# 使用
## 源码地址(了解)
    https://github.com/zhangshiqian1214/skynet-server
## 修改（了解）：
    1 顶层makefile添加lsocket库支持
    2 skynet makefile添加 skynet_crypt httppack add支持
    lualib-src/lua-crypt.c  lualib-src/lua-httppack.c  lualib-src/add.c

## 安装(重要)
    1 步骤就一步： cd serverOne; make all;
    2 步骤解释：serverOne依赖skynet、redis、lsocket，makefile负责编译它们，同时需要安装mysql数据库。
    3 编译遇到问题（提供参考，没有遇到则忽略）
    skynet: yum install dos2unix; yum install libcurl-dev libcurl-devel
    make socket  安装客户端lsocket
    问题： 安装 Redis 执行 make #error "Newer version of jemalloc required"
    => make MALLOC=libc
    openssl/crypto.h: No such file or directory
    => yum install openssl-devel
    “uuid/uuid.h: No such file or directory
    => yum install libuuid-devel

    测试cluster：1 ./run_test1.sh  ./run_test.sh

## 运行服务端（重要）
    执行步骤：./run_redis.sh; redis启动一次即可  ./restart.sh; 重复服务端命令
    服务端操作相关：
    1 只启动gate login hall db服务，redis没有其他服务
    单服务启动
    ./run_redis.sh
    ./run_gate.sh
    ./run_login.sh
    ./run_hall.sh
    ./run_db.sh
    2 单服务停止
    pkill -u `whoami` -xf "./skynet/skynet ./config/config_xpnn __default__"
    3 停止game服务
    pkill -u `whoami` -xf "./skynet/skynet ./config/config_xpnn21 __default__"

## 运行客户端（重要）
    执行步骤： ./client.sh uid  uid是用户id可以是任何正整数,表示用户唯一标识，例如：./client.sh 1
    客户端相关：
    1 控制台输入0   正常退出客户端
    2 控制台ctrl+c  断线(socket直接断开)
