#!/bin/sh
#export ROOT=$(cd `dirname $0`; pwd)
export ROOT=$(dirname $(pwd))

$ROOT/skynet/3rd/lua/lua $ROOT/client/simpleclient.lua $ROOT "127.0.0.1" $1

