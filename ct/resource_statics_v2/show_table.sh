#!/bin/bash

server=$(cat hosts | grep kgc_server -A 3|sed -n '2p')
if [ ${server} = "" ];then
    echo "Error: ksc server is NULL"
    exit 1
fi

python generate_network_table.py

#echo "{}" > server.json
ansible $server  -m shell -a 'cat /tmp/server.json' | grep -v SUCCESS>server.json
content=$(cat server.json)
if [ "${content}" = "" ];then
     exit 1
fi


python generate_server_table.py
mv server.json server-${RANDOM}.json


