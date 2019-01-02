#!/bin/bash

NICNAME=$1

if [ "$NICNAME" == "" ];then
    echo "Error: please input $0 nicname"
    exit
fi

#挂载大页
#mount -t hugetlbfs -o pagesize=1G none /mnt/huge_1GB

#加载vfio-pci驱动
echo "load vfio-pci driver"
modprobe vfio-pci
chmod a+x /dev/vfio
chmod 0666 /dev/vfio/*

is_exist=$(ip a | grep $NICNAME)
if [ "$is_exist" != "" ];then
    ifconfig $NICNAME down
    ./dpdk-devbind.py --bind=vfio-pci $NICNAME
else
    echo "Warn: NIC $NICNAME is not kernel space"
fi

if [ -f /etc/sysconfig/network-scripts/ifcfg-eth1 ];then
    IP=$(cat /etc/sysconfig/network-scripts/ifcfg-eth1 | grep  IPADDR |cut -d"=" -f2)
    echo "get ip $IP"
    if [ "$IP" == ""  ];then
        echo "can not find ip for $NICNAME"
        exit 1
    fi
else
    IP=$2
fi

if [ "$IP" == "" ];then
    echo "Error: please input ip for $NICNAME"
    echo "$0 $NICNAME ip/mask"
    exit 1
fi

if [ ! -f ./dpdk-devbind.py ];then
    echo "Error: ./dpdk-devbind.py not exist"
    exit 1
fi

pci=$(./dpdk-devbind.py --status | grep "Network devices using DPDK-compatible driver" -A 2 | tail -1 | awk '{print $1}')
echo "binding pci : $pci"
if [ "$pci" == "" ];then
    echo "Error can not find nic by dpdk binding"
    exit 1
fi

#首先启动openvswitch
echo "start ovsdb"
mkdir /var/run/openvswitch
if [ -f /var/run/openvswitch/ovsdb-server.pid ];then
    kill -9 `cat /var/run/openvswitch/ovsdb-server.pid`
fi
ovsdb-server /etc/openvswitch/conf.db -vconsole:emer -vsyslog:err -vfile:info --remote=punix:/var/run/openvswitch/db.sock --private-key=db:Open_vSwitch,SSL,private_key --certificate=db:Open_vSwitch,SSL,certificate --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert --no-chdir --log-file=/var/log/openvswitch/ovsdb-server.log --pidfile=/var/run/openvswitch/ovsdb-server.pid --detach

#配置openvsiwtch
echo "setup ovsdb"
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=3000000030
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem=1024,1024
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true

#配置完成后启动ovs-vswitchd
echo "start ovs-vswitchd"
if [ -f /var/run/openvswitch/ovs-vswitchd.pid ];then
    kill -9 `cat /var/run/openvswitch/ovs-vswitchd.pid`
fi
ovs-vswitchd unix:/var/run/openvswitch/db.sock -vconsole:emer -vsyslog:err -vfile:info --mlockall --no-chdir --log-file=/var/log/openvswitch/ovs-vswitchd.log --pidfile=/var/run/openvswitch/ovs-vswitchd.pid --detach


#创建网桥
echo "add dpdk br0 and br-phy"
ovs-vsctl del-port dpdk0
ovs-vsctl --may-exist add-br br0 -- set Bridge br0 datapath_type=netdev
ovs-vsctl --may-exist add-br br-phy -- set Bridge br-phy datapath_type=netdev

#绑定物理网卡
echo "nic binding to ovs"
ovs-vsctl  --may-exist add-port br-phy dpdk0 -- set Interface dpdk0 type=dpdk options:dpdk-devargs=$pci
ip addr add "$IP/24" dev br-phy
ip link set br-phy up

if [ -f /etc/sysconfig/network-scripts/route-eth1 ];then
    #添加路由
    while read r
    do
        echo "add $r"
        n=$(echo "$r" | awk '{print $NF}')
        rt=$(echo $r | sed "s/$n/br-phy/g")
        ip route add $rt
    done < /etc/sysconfig/network-scripts/route-eth1
fi


#配置ovs与Controller连接
echo "set ovs failmode and connected to controller"
sudo ovs-vsctl set-controller br0 tcp:127.0.0.1:6653
sudo ovs-vsctl set-fail-mode br0 secure

echo "setup finished"
echo "==========================================="
echo "please add route table for br-phy"
echo "==========================================="



