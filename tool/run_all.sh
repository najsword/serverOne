#!/bin/bash
dir=..
branch=__default__
redisdir=$dir/redis
skynetdir=$dir/skynet

#start skynet
if [  -n "$1" ] ;then
    nohup $skynetdir/skynet $dir/config/config_auth $branch >> console.log 2>&1 &
    nohup $skynetdir/skynet $dir/config/config_gate $branch >> console.log 2>&1 &
    nohup $skynetdir/skynet $dir/config/config_login $branch >> console.log 2>&1 &
    nohup $skynetdir/skynet $dir/config/config_hall $branch >> console.log 2>&1 &
    nohup $skynetdir/skynet $dir/config/config_db $branch  >> console.log 2>&1 &
    nohup $skynetdir/skynet $dir/config/config_chat $branch  >> console.log 2>&1 &
    sleep 2s
    nohup $skynetdir/skynet $dir/config/config_locator $branch  >> console.log 2>&1 &
    sleep 1s
    nohup $skynetdir/skynet $dir/config/config_xpnn21 $branch  >> console.log 2>&1 &
else
    ./run_db.sh
    ./run_auth.sh
    ./run_gate.sh
    ./run_login.sh
    ./run_hall.sh
    ./run_chat.sh
    sleep 1s
    ./run_locator.sh
    sleep 1s
    ./run_xpnn.sh 21
fi