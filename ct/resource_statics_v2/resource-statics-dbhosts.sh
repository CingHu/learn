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


#echo "{}" > server.json
ansible $server  -m copy  -a 'src=./server-db-statics.py dest=/tmp/server-db-statics.py mode=755'
ansible $server  -m shell -a 'echo {}>/tmp/server.json'
ansible $server -B 36000 -P 0  -m shell -a '/tmp/server-db-statics.py>/tmp/server.json'



