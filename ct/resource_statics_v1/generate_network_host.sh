#!/bin/bash

server=$(cat hosts | grep kgc_server -A 3|sed -n '2p')
if [ ${server} = "" ];then
    echo "Error: ksc server is NULL"
    exit 1
fi

echo "[all:vars]" > dbhosts
echo "ansible_ssh_user=secure" >> dbhosts
echo "ansible_become=yes">>dbhosts
echo "ansible_become_method=sudo">>dbhosts
echo "ansible_become_user=root">>dbhosts

echo "[network]" >> dbhosts

ansible $server  -m shell -a "source ~/admin-openrc.sh;openstack network agent list | grep '-network-' | cut -d'|' -f4|sed -e 's/\ //g'|awk -F"-" '{print \$NF}'|sed -e 's/e/./g'|sort|uniq" |grep -v "SUCCESS" >> dbhosts

