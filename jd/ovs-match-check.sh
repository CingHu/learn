#!/bin/bash

DROPTABLE=200
HARDTIME=1800

BRIDGE="br0"
MAX_OFPORT="65280"


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

function filter_port()
{
    if [[ $# -lt 1 || "$1" == "" ]];then
           echo "Error, please input port_id, ex: sh $0 port-1nlzrq3pop"
           exit
    fi
    local PORTID=$1
    local PORTMAC=""
    local INPORT=0

    PORTMAC=$(ovs-vsctl list Interface  $PORTID | grep external_ids | awk -F "attached-mac=" '{print $2}' | cut -d"," -f1|sed -e 's/\"//g')
    if [ "${PORTMAC}" == "" ];then
           echo "Error, can not find mac of $PORTID from ovsdb"
           exit
    fi

    INPORT=$(get_ofport_num $PORTID)
    if [ $? != 0 ];then
          echo "Error, ofport of $PORTID is invalid"
          exit 1
    fi

    set -x
    ifconfig $BRIDGE up
    ovs-ofctl add-flow -O openflow13 $BRIDGE "table=$DROPTABLE, hard_timeout=$HARDTIME, priority=1000, dl_dst=$PORTMAC, actions=push_vlan:0x8100,move:NXM_NX_REG8[0..11]->OXM_OF_VLAN_VID[],LOCAL"
    ovs-ofctl add-flow -O openflow13 $BRIDGE "table=$DROPTABLE, hard_timeout=$HARDTIME, priority=1000, in_port=$INPORT, actions=push_vlan:0x8100,move:NXM_NX_REG8[0..11]->OXM_OF_VLAN_VID[],LOCAL"
    ovs-ofctl add-flow -O openflow13 $BRIDGE "table=$DROPTABLE, hard_timeout=$HARDTIME, priority=1000, dl_src=$PORTMAC, actions=push_vlan:0x8100,move:NXM_NX_REG8[0..11]->OXM_OF_VLAN_VID[],LOCAL"
    set +x
}

function filter_match()
{
    set -x
    ifconfig $BRIDGE up
    ovs-ofctl add-flow -O openflow13 $BRIDGE "table=$DROPTABLE, hard_timeout=$HARDTIME, priority=1000, $* actions=push_vlan:0x8100,move:NXM_NX_REG8[0..11]->OXM_OF_VLAN_VID[],LOCAL"
    set +x
}

function delete_flows()
{
    ovs-ofctl dump-flows -O openflow15 br0 table=$DROPTABLE | grep priority=1000 | sed 's/^.*priority=1000,\(.*\) actions.*$/\1/g' | while read line;
    do
    set -x
    ovs-ofctl del-flows -O openflow13 $BRIDGE --strict "table=$DROPTABLE, priority=1000, cookie=0x0/0xffffffffffffffff, $line"
    set +x
    done
}

function list_flows()
{
    ovs-ofctl dump-flows -O openflow15 br0 table=$DROPTABLE | grep priority=1000
}

function usage()
{
    echo "Add/Del/List flows into drop table(200), and redirect packets match them into ovs local port 'br0'"
    echo "USAGE"
    echo "    $0 [-p port-id] [-d] [-m conditions] [-l]"
    echo "    -p port-id          add flows match given port with its ofport and mac address"
    echo "    -m conditions       add flows with given match conditions"
    echo "    -l                  list match flows"
    echo "    -d                  clear match flows"
    echo "    -h                  print this usage"

}

while getopts "p:m:dl" arg
do
    case $arg in
        d)
            delete_flows
            ;;
        p)
            filter_port $OPTARG
            ;;
        m)
            filter_match $OPTARG
            ;;
        h)
            usage
            ;;
        l)
            list_flows
            ;;
        *)
            echo "Bad options"
            usage
            exit 1
            ;;
    esac
    exit 0
done

usage
exit 1


