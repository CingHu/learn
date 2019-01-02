#!/bin/bash

> /tmp/hosts
echo "get host from db start"
ccs host-list --type VS| grep host- |cut -d"|" -f4 | sed -e "s/\ //g" > /tmp/hosts
echo "get host from db end"

num=$(cat /tmp/hosts | wc -l)
if [ "$num" == "0" ];then
    echo "Error: the num of host is 0"
    exit 1
fi

for h in `cat /tmp/hosts`
do
   echo "check host $h" 
   ssh -o StrictHostKeyChecking=no  $h 'cc_controller -v'
done
