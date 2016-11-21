#!/bin/bash

#
watch -n 1 -d "ovs-ofctl dump-flows br0 -O openflow13 | grep drop"
watch -n 1 -d "ovs-appctl bridge/dump-flows br0 | grep drop"



#
veth pair:
TAPNAME="tapb115bdf0"
NS_TAP_NAME="${TAPNAME}_ns"
NS_NAME="router"

echo $NS_TAP_NAME
echo $NS_NAME
echo $TAPNAME

sudo ip netns del $NS_NAME
sudo ip netns add $NS_NAME
sudo ip link add name $TAPNAME type veth peer name $NS_TAP_NAME
sudo ip link set $TAPNAME up
sudo ip link set $NS_TAP_NAME netns $NS_NAME
sudo ip netns exec $NS_NAME ip link set $NS_TAP_NAME up
sudo ip netns exec $NS_NAME ip link set dev lo up

ovs-vsctl add-port br0 $TAPNAME


tap:

TAPNAME="tapb115bdf0"
MAC="fa:16:3e:73:c9:74"
IPADDR="172.16.1.4/24"
NS_NAME="router"


TAPNAME="tapb115bdf0"
MAC="fa:16:3e:5e:16:34"
IPADDR="172.16.1.3/24"

NS_NAME="router"


sudo ip netns del $NS_NAME
sudo ip netns add $NS_NAME
sudo ip link set $TAPNAME netns $NS_NAME
sudo ip netns exec $NS_NAME ip link set dev lo up
sudo ip netns exec $NS_NAME ip link set dev $TAPNAME address $MAC
sudo ip netns exec $NS_NAME ifconfig $TAPNAME $IPADDR
sudo ip netns exec $NS_NAME ip link set $TAPNAME up
sudo ip netns exec $NS_NAME ip a


#
sudo iptables -F
sudo setenforce Permissive
service httpd restart
chkconfig  httpd on


#
nova boot --flavor m1.tiny --image e2fb6555-d3ed-4555-9af5-1e4d762f0cfa --vpc 274a9ebf-a4ad-4313-bcad-97fafeefac10 --nic net-id=12ff673c-1998-44ed-b986-499497909205 dxf_vm1 --security-groups 3461c71c-5d2f-44e4-bb76-172699d5e983


#wireshark
openflow_v4.type !=0 && openflow_v4.type !=1&& openflow_v4.type !=2 && openflow_v4.type !=3 && openflow_v4.type !=14

