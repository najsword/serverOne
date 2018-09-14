#!/bin/bash
dir=..
branch=__default__
redisdir=$dir/redis
skynetdir=$dir/skynet

#start skynet
if [  -n "$1" ] ;then
    ($skynetdir/skynet $dir/config/config_locator $branch)
else
    nohup $skynetdir/skynet $dir/config/config_locator $branch >> console.log 2>&1 &
fi