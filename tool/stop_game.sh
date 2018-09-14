#!/bin/bash
index=$1
pkill -u `whoami` -xf "../skynet/skynet ../config/config_xpnn$index __default__"
