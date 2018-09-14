#!/bin/bash
dir=..
branch=__default__
redisdir=$dir/redis
skynetdir=$dir/skynet

index=$1

#start skynet
if [  -n "$2" ] ;then
    ($skynetdir/skynet $dir/config/config_xpnn$index $branch)
else
    nohup $skynetdir/skynet $dir/config/config_xpnn$index $branch > xpnn_$index.log 2>&1 &
fi