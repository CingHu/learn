#!/bin/bash

sh ./generate_network_host.sh

> networks.json
echo "[" >> networks.json
ansible -i dbhosts network  -m copy -a 'src=./network-resource-statics.sh dest=/tmp/network-resource-statics.sh mode=755'
ansible -i dbhosts network  -m shell -a '/tmp/network-resource-statics.sh' |grep -v "SUCCESS"  >> networks.json
sed -i '$s/,//g' networks.json
echo "]" >> networks.json

server=$(cat hosts | grep kgc_server -A 3|sed -n '2p')
if [ ${server} = "" ];then
    echo "Error: ksc server is NULL"
    exit 1
fi

ansible $server  -m copy -a 'src=./server-resource-statics.sh dest=/tmp/server-resource-statics.sh mode=755'
ansible $server  -m shell -a '/tmp/server-resource-statics.sh' |grep -v "SUCCESS"  > server.json

