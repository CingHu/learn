#!/bin/bash
#
# The MIT License (MIT)
# Copyright (c) 2014 neunn (wangtq@neunn.com)
# 2014-07-11 
#

CONFIG_FILE="/etc/ssh/sshd_config"
TIMEOUT=60
COUNTMAX=10

test $UID != 0 && echo "Please use root" && exit 1

sed -i '/^[[:space:]]*ClientAliveInterval.*$/d' $CONFIG_FILE
sed -i '/^[[:space:]]*ClientAliveCountMax.*$/d' $CONFIG_FILE

echo "ClientAliveInterval $TIMEOUT" >> $CONFIG_FILE
echo "ClientAliveCountMax $COUNTMAX" >> $CONFIG_FILE

echo "Add config to $file successu"

echo "Restart ssh service"
service ssh restart
exit 0