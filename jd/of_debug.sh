#!/bin/bash

if[ #? -eq 1  ];then
    echo "Error: $0 [port_name]"
    exit 1
fi

PN=$1
dumpflows="ovs-ofctl dump-flows br0 -O openflow13"

ofport=$(ovs-vsctl get Interface $PN ofport)
if [ -n $ofport ];then
    echo "Error: ofpot of $PN is null"
    exit 1
fi

echo "OK: ofport of $PN is $ofport"

echo "checkout controller cache"
cache=$(ccc curdetail)
if [ -n $cache ];then
    echo "Error: $PN not exist in cache"
    exit 1
fi

echo $cache | grep $PN -C 4

echo "get flow for $PN"
flows=$(dumpflows)
echo $flows | grep "in_port=$ofport"


