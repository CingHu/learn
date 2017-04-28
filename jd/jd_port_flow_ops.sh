#!/bin/bash


MEATADATAHEX="0x3300000001"
VNIHEX="0x33"

HOST="100.64.3.1"
RMAC="fa:16:3e:13:e1:18"
RIPADDR="192.168.100.10"

TAPNAME="port-test"
MAC="fa:16:3e:33:22:11"
IPADDR="192.168.100.120"
DEFAULT_GW="192.168.100.1"
NS_NAME=$TAPNAME

ADDFLOW="ovs-ofctl add-flow -O openflow13 br0 "
DELFLOW="ovs-ofctl del-flows -O openflow13 br0 --strict"

echo "$0 local add/del"
echo "$0 remote add/del"

function check_local {
if [ "$MEATADATAHEX" == "" -o "$VNIHEX" == "" ];then
    echo "inpute param error, exit"
    exit 1
fi
}

function check_remote {
if [ "$HOST" == "" -o "$RMAC" == "" -o "$RIPADDR" == "" ];then
    echo "inpute param error, exit"
    exit 1
fi
}

function main {
if [ "$1" == "local" -a "$2" == "add" ];then
    ovs-vsctl -- --if-exists del-port $TAPNAME -- add-port br0 $TAPNAME -- set Interface $TAPNAME type=internal -- set Interface $TAPNAME external-ids:iface-status=active -- set Interface $TAPNAME external-ids:attached-mac=$MAC
    #ovs-vsctl add-port br0 $TAPNAME -- set Interface $TAPNAME type=internal -- set Interface $TAPNAME external-ids:iface-status=active -- set Interface $TAPNAME external-ids:attached-mac=$MAC
    sudo ip netns del $NS_NAME
    sudo ip netns add $NS_NAME
    sudo ip link set $TAPNAME netns $NS_NAME
    sudo ip netns exec $NS_NAME ip link set dev lo up
    sudo ip netns exec $NS_NAME ip link set dev $TAPNAME address $MAC
    sudo ip netns exec $NS_NAME ifconfig $TAPNAME $IPADDR
    sudo ip netns exec $NS_NAME ip link set $TAPNAME up
    sudo ip netns exec $NS_NAME ip route add default via $DEFAULT_GW dev $TAPNAME
    sudo ip netns exec $NS_NAME ip a
    
    ofport=$(ovs-vsctl get interface $TAPNAME ofport)
    ofporthex=$(echo "0x"`echo "obase=16;${ofport}"|bc`)
    
    let output_conj_id=$ofport+500

    local_port_match
    add_local_flow
fi

if [ "$1" == "local" -a "$2" == "del" ];then
    local_port_match
    del_local_flow
fi

if [ "$1" == "remote" -a "$2" == "add" ];then
    hostuname="vx$HOST"
    vxofport=$(ovs-vsctl get interface $hostuname ofport)
    vxofporthex=$(echo "0x"`echo "obase=16;${vxofport}"|bc`)
    remote_port_match
    add_remote_flow
fi

if [ "$1" == "remote" -a "$2" == "del" ];then
    remote_port_match
    del_remote_flow
fi

}

function local_port_match {
    LTABLE0_MATCH1="table=0,priority=100,in_port=$ofport"
    LTABLE5_MATCH1="table=5,priority=100,ip,in_port=$ofport"
    LTABLE5_MATCH2="table=5,priority=100,arp,in_port=$ofport"
    LTABLE5_MATCH3="table=5,priority=100,udp,in_port=$ofport ,dl_dst=ff:ff:ff:ff:ff:ff,tp_src=68,tp_dst=67"
    LTABLE10_MATCH1="table=10,priority=100,ip,reg6=$ofporthex"
    LTABLE15_MATCH1="table=15,priority=1000,conj_id=$ofport ,ip,reg6=$ofporthex"
    LTABLE15_MATCH2="table=15,priority=100,ct_state=+new-est-rel-inv+trk,reg6=$ofporthex"
    LTABLE15_MATCH3="table=15,priority=100,ip,reg6=$ofporthex"
    LTABLE25_MATCH1="table=25, priority=100,arp,metadata=$MEATADATAHEX,arp_tpa=$IPADDR,arp_op=1"
    LTABLE30_MATCH1="table=30,priority=100,udp,metadata=$MEATADATAHEX,dl_dst=ff:ff:ff:ff:ff:ff,tp_src=68,tp_dst=67"
    LTABLE40_MATCH1="table=40,priority=50,ip,tun_id=$VNIHEX,dl_dst=$MAC"
    LTABLE45_MATCH1="table=45,priority=100,metadata=$MEATADATAHEX,dl_dst=$MAC"
    LTABLE50_MATCH1="table=50,priority=100,ip,reg7=$ofporthex"
    LTABLE55_MATCH1="table=55,priority=1000,conj_id=$output_conj_id,ip,reg7=$ofporthex"
    LTABLE55_MATCH2="table=55,priority=100,ct_state=+new-est-rel-inv+trk,reg7=$ofporthex"
    LTABLE55_MATCH3="table=55,priority=100,ip,reg7=$ofporthex"
    LTABLE60_MATCH1="table=60,priority=100,reg7=$ofporthex,metadata=$MEATADATAHEX"
}

function add_local_flow {
    $ADDFLOW "${LTABLE0_MATCH1} actions=set_field:$ofporthex->reg6,write_metadata:$MEATADATAHEX,goto_table:5"
    $ADDFLOW "${LTABLE5_MATCH1} actions=goto_table:10"
    $ADDFLOW "${LTABLE5_MATCH2} actions=goto_table:20"
    $ADDFLOW "${LTABLE5_MATCH3} actions=goto_table:20"
    $ADDFLOW "${LTABLE10_MATCH1} actions=ct(table=15,zone=OXM_OF_METADATA[0..15])"
    $ADDFLOW "${LTABLE15_MATCH1} actions=ct(commit,table=20,zone=NXM_NX_CT_ZONE[])"
    $ADDFLOW "${LTABLE15_MATCH2} actions=conjunction($ofport,1/2)"
    $ADDFLOW "${LTABLE15_MATCH3} actions=conjunction($ofport,2/2)"
    $ADDFLOW "${LTABLE25_MATCH1} actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],set_field:$MAC->eth_src,set_field:2->arp_op,move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],set_field:$MAC->arp_sha,move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],set_field:$IPADDR->arp_spa,IN_PORT"
    $ADDFLOW "${LTABLE30_MATCH1} actions=CONTROLLER:65535"
    $ADDFLOW "${LTABLE40_MATCH1} actions=write_metadata:$MEATADATAHEX,goto_table:45"
    $ADDFLOW "${LTABLE45_MATCH1} actions=set_field:$ofporthex->reg7,goto_table:50"
    $ADDFLOW "${LTABLE50_MATCH1} actions=ct(table=55,zone=OXM_OF_METADATA[0..15])"
    $ADDFLOW "${LTABLE55_MATCH1} actions=ct(commit,table=60,zone=NXM_NX_CT_ZONE[])"
    $ADDFLOW "${LTABLE55_MATCH2} actions=conjunction($output_conj_id,1/2)"
    $ADDFLOW "${LTABLE55_MATCH3} actions=conjunction($output_conj_id,2/2)"
    $ADDFLOW "${LTABLE60_MATCH1} actions=output:NXM_NX_REG7[]"
}

function del_local_flow {
    $DELFLOW "${LTABLE0_MATCH1}" 
    $DELFLOW "${LTABLE5_MATCH1}"
    $DELFLOW "${LTABLE5_MATCH2}"
    $DELFLOW "${LTABLE5_MATCH3}"
    $DELFLOW "${LTABLE10_MATCH1}"
    $DELFLOW "${LTABLE15_MATCH1}"
    $DELFLOW "${LTABLE15_MATCH2}"
    $DELFLOW "${LTABLE15_MATCH3}"
    $DELFLOW "${LTABLE25_MATCH1}"
    $DELFLOW "${LTABLE30_MATCH1}"
    $DELFLOW "${LTABLE40_MATCH1}"
    $DELFLOW "${LTABLE45_MATCH1}"
    $DELFLOW "${LTABLE50_MATCH1}"
    $DELFLOW "${LTABLE55_MATCH1}"
    $DELFLOW "${LTABLE55_MATCH2}"
    $DELFLOW "${LTABLE55_MATCH3}"
    $DELFLOW "${LTABLE60_MATCH1}"
}

function remote_port_match {
    RTABLE0_MATCH1="table=0,priority=1000,tun_id=$VNIHEX,in_port=$vxofport"
    RTABLE25_MATCH1="table=25,priority=100,arp,metadata=$MEATADATAHEX,arp_tpa=$RIPADDR,arp_op=1"
    RTABLE45_MATCH1="table=45,priority=100,metadata=$MEATADATAHEX,dl_dst=$RMAC"
    LTABLE60_MATCH1="table=60,priority=100,reg7=$vxofporthex,metadata=$MEATADATAHEX"
}

function add_remote_flow {
    $ADDFLOW "${RTABLE0_MATCH1} actions=goto_table:40"
    $ADDFLOW "${RTABLE25_MATCH1} actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],set_field:$RMAC->eth_src,set_field:2->arp_op,move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],set_field:$RMAC->arp_sha,move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],set_field:$RIPADDR->arp_spa,IN_PORT"
    $ADDFLOW "${RTABLE45_MATCH1} actions=set_field:$VNIHEX->tun_id,set_field:$vxofporthex->reg7,goto_table:60"
    $ADDFLOW "${LTABLE60_MATCH1} actions=output:NXM_NX_REG7[]"
}

function del_remote_flow {
    $DELFLOW "${RTABLE0_MATCH1}"
    $DELFLOW "${RTABLE25_MATCH1}"
    $DELFLOW "${RTABLE45_MATCH1}"
    $DELFLOW "${LTABLE60_MATCH1}"
}

main $*
