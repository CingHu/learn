#!/bin/bash

source /root/admin-openrc.sh
zone="public_dvr"

echo "{"
echo "\"zone\": \"$zone\","
openstack network agent list > /tmp/agents
network_node_count=$(cat /tmp/agents | grep network|grep $zone | cut -d"|" -f4|sort|uniq|wc -l)
echo "\"net-node\": $network_node_count,"

agent_down=$(cat /tmp/agents | grep network |grep $zone |grep -v ":-)"| cut -d"|" -f4|sort|uniq |wc -l)
echo "\"agent-down-node\": $agent_down,"

router=$(openstack router list |grep -e True -e ACTIVE -e UP|wc -l)
echo "\"total-router\": $router,"

fip=$(openstack port list --network ext-net --device-owner network:floatingip |wc -l)
echo "\"total-fip\": $fip,"

echo "\"ztime\":\"`date '+%Y-%m-%d'`\"}"
