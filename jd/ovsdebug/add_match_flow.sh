#!/bin/bash


PORTID=$1

DROPTABLE=200
HARDTIME=1800

BRIDGE="br0"
MAX_OFPORT="65280"

if [ "${PORTID}" == "" ];then
       echo "Error, please input port_id, ex: sh $0 port-1nlzrq3pop"
       exit
fi

PORTMAC=$(ovs-vsctl list Interface  $PORTID | grep external_ids | awk -F "attached-mac=" '{print $2}' | cut -d"," -f1|sed -e 's/\"//g')
if [ "${PORTMAC}" == "" ];then
       echo "Error, can not find mac of $PORTID from ovsdb"
       exit
fi

function get_ofport_num()
{

        local ofport=""
        local result=0
        local max=0

        ofport=$(ovs-vsctl get Interface $1 ofport)
        if [ $? -ne 0 ];then
                echo "Error, get ofport of $1 fail from ovsdb"
                return 1
        fi

        if [ "${ofport}" == "" ]; then
                echo "Error, ofport of $1 is null"
                return 1
        fi

        result=$(echo $ofport | awk '{print int($0)}')
        max=$(echo $MAX_OFPORT | awk '{print int($0)}')
        if [ $result -le 0 -o $result -ge $max ];then
                echo "Error, ofport of $1 is valid, value:$ofport"
                return 1
        fi


        echo $ofport
        return 0
}

INPORT=$(get_ofport_num $PORTID)
if [ $? != 0 ];then
      echo "Error, ofport of $PORTID is invalid"
      exit 1
fi

ifconfig $BRIDGE up
ovs-ofctl add-flow -O openflow13 $BRIDGE "table=$DROPTABLE, hard_timeout=$HARDTIME, priority=1000, dl_dst=$PORTMAC, actions=push_vlan:0x8100,move:NXM_NX_REG8[0..11]->OXM_OF_VLAN_VID[],LOCAL"
ovs-ofctl add-flow -O openflow13 $BRIDGE "table=$DROPTABLE, hard_timeout=$HARDTIME, priority=1000, in_port=$INPORT, actions=push_vlan:0x8100,move:NXM_NX_REG8[0..11]->OXM_OF_VLAN_VID[],LOCAL"
ovs-ofctl add-flow -O openflow13 $BRIDGE "table=$DROPTABLE, hard_timeout=$HARDTIME, priority=1000, dl_src=$PORTMAC, actions=push_vlan:0x8100,move:NXM_NX_REG8[0..11]->OXM_OF_VLAN_VID[],LOCAL"
ovs-ofctl dump-flows -O openflow13 $BRIDGE table=$DROPTABLE | grep -E "${PORTMAC}|in_port=$INPORT "

