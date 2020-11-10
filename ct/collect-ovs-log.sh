#!/bin/bash


#ovs-appctl vlog/set any:any:dbg
#ovs-appctl vlog/set any:any:info
#/usr/bin/dpdk-pdump -d librte_pmd_pcap.so -- --pdump port=0,queue=*,rx-dev=/tmp/hupkts.pcap,tx-dev=/tmp/hupkts.pcap --server-socket-path=/var/run/openvswitch
#ovs-vsctl clear Bridge br0 mirror


mkdir ovslog > /dev/null
date=$(date "+%Y-%m-%d %H:%M:%S" | sed 's/\ /_/g')
file=ovslog/ovs-$date.log
>$file
function run_cmd(){
    echo "$*" >> $file
    $* >> $file
    echo -e "===========$* End========\n\n\n" >> $file
}
for bridge in  `ovs-vsctl list bridge | grep name | cut -d":" -f2`
do
    run_cmd ovs-ofctl dump-flows ${bridge} -O openflow13
    run_cmd ovs-ofctl dump-ports ${bridge} -O openflow13
    run_cmd ovs-appctl fdb/show $bridge
    run_cmd ovs-appctl fdb/stats-show $bridge
    run_cmd ovs-appctl bond/show
    run_cmd ovs-appctl dpctl/show -s 
done
run_cmd ovs-vsctl show
run_cmd ovs-appctl dpctl/dump-flows
run_cmd ovs-appctl dpctl/dump-conntrack
run_cmd ovs-vsctl list interface
run_cmd ovs-appctl dpctl/dump-flows -mmm
run_cmd cat /proc/net/nf_conntrack
run_cmd ip link show
run_cmd ovsdb-tool show-log -mmm
run_cmd ovs-appctl  dpif-netdev/pmd-stats-show
run_cmd ovs-appctl dpif-netdev/pmd-rxq-show
run_cmd ovs-appctl dpif-netdev/pmd-perf-show
run_cmd ovs-appctl dpif-netdev/pmd-rxq-show
run_cmd ovs-appctl dpif/show
run_cmd ovs-appctl memory/show
run_cmd ovs-appctl coverage/show
run_cmd ovs-appctl  ovs/route/show
run_cmd ovs-appctl  tnl/neigh/show
run_cmd ovs-appctl  tnl/arp/show



for ns in `ip netns list | awk '{print $1}'`
do
    run_cmd ip netns exec $ns ip a
    run_cmd ip netns exec $ns ip route
    run_cmd ip netns exec $ns ip neigh
done
run_cmd dmesg
run_cmd dmesg -T
run_cmd  cp /var/log/openvswitch/ovsdb-server.log ovslog/ovsdb-server.log-$date.log
run_cmd  cp /var/log/messages   ovslog/messages-$date.log


