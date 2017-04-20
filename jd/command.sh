#!/bin/bash

#
watch -n 1 -d "ovs-appctl bridge/dump-flows br0 | sed -e 's/duration=[^,]*,//g' | grep drop"
watch -n 1 -d "ovs-ofctl dump-flows br0 -O openflow13 | grep -v "n_packets=0" | grep -v "OFPST_FLOW" | sed -e 's/duration=[^,]*,//g'"
watch -n 1 -d "ovs-appctl bridge/dump-flows br0 | grep -v "n_packets=0" | sed -e 's/duration=[^,]*,//g'"
watch -n 1 -d "ovs-ofctl dump-flows -O openflow13 br0 | grep -v "n_packets=0" |grep -v "OFPST_FLOW"| sed -e '/NXST_FLOW/d' -e 's/\(duration\)=[^,]*,//g' -e 's/send_flow_rem//g'"


#tunnel tx/rx 
watch -n 1 -d "ovs-ofctl dump-ports br0"


#ovs
sudo ovs-vsctl add-br br0
sudo ovs-vsctl set-controller br0 tcp:127.0.0.1:6653
sudo ovs-vsctl set-fail-mode br0 secure

测试环境输入如下命令打开openflow日志，线上环境不需要
sudo ovs-appctl vlog/set vconn:ANY:DBG



#veth pair:
TAPNAME="tapb115bdf0"
NS_TAP_NAME="${TAPNAME}_ns"
NS_NAME="router"
DEFAULT_GW="172.16.1.1"

sudo ip netns del $NS_NAME
sudo ip netns add $NS_NAME
sudo ip link add name $TAPNAME type veth peer name $NS_TAP_NAME
sudo ip link set $TAPNAME up
sudo ip link set $NS_TAP_NAME netns $NS_NAME
sudo ip netns exec $NS_NAME ip link set $NS_TAP_NAME up
sudo ip netns exec $NS_NAME ip route add default via $DEFAULT_GW dev $TAPNAME
sudo ip netns exec $NS_NAME ip link set dev lo up

ovs-vsctl add-port br0 $TAPNAME


#tap:
TAPNAME="tapb115bdf0"
MAC="fa:16:3e:5e:16:34"
IPADDR="172.16.1.3/24"
DEFAULT_GW="172.16.1.1"  13910131713
NS_NAME="router"


sudo ip netns del $NS_NAME
sudo ip netns add $NS_NAME
sudo ip link set $TAPNAME netns $NS_NAME
sudo ip netns exec $NS_NAME ip link set dev lo up
sudo ip netns exec $NS_NAME ip link set dev $TAPNAME address $MAC
sudo ip netns exec $NS_NAME ifconfig $TAPNAME $IPADDR
sudo ip netns exec $NS_NAME ip link set $TAPNAME up
sudo ip netns exec $NS_NAME ip route add default via $DEFAULT_GW dev $TAPNAME
sudo ip netns exec $NS_NAME ip a


#linux security
sudo iptables -F
sudo setenforce Permissive
service httpd restart
chkconfig  httpd on
chkconfig  openvswitch on


#nova
nova boot --flavor m1.tiny --image e2fb6555-d3ed-4555-9af5-1e4d762f0cfa --vpc 274a9ebf-a4ad-4313-bcad-97fafeefac10 --nic net-id=12ff673c-1998-44ed-b986-499497909205 dxf_vm1 --security-groups 3461c71c-5d2f-44e4-bb76-172699d5e983


#wireshark
openflow_v4.type !=0 && openflow_v4.type !=1&& openflow_v4.type !=2 && openflow_v4.type !=3 && openflow_v4.type !=14

#tcpdump
tcpdump -ni lo tcp port 8080 -s 0 -A


#mysql
grant all cc to test@'192.168.8.131' identified by 'test';
grant all privileges on *.* to root@192.168.8.131 identified by '123456';
grant all privileges on *.* to root@192.168.8.1 identified by '123456';

#find && replace
find ./   -name "*.go" | grep -v vendor|xargs sed -i 's/\/jstack-cc-controller\//\/jstack-controller\//g'

#sed
sed -i "s/log.Debugf/\/\/log.Debugf/g" app/vrmonitor/vrmonitor.go
sed -i "s/log.Infof/\/\/log.Infof/g" app/vrmonitor/vrmonitor.go


#alias
alias jd='cd /home/jstack/src/jd.com/cc/jstack-controller'
alias dumpflows='sudo ovs-ofctl dump-flows br0 -O openflow13'
alias dumpgroups='sudo ovs-ofctl dump-groups br0 -O openflow13'
alias listports="sudo ovs-vsctl -- --columns=name,ofport list Interface"
alias run="./templar /etc/cc_controller/compute.json"
alias log="tailf /var/log/cc_controller/cc_controller.log"
alias build="go build templar.go"


