#!/bin/bash

DROP_TABLE=0
BR_NAME="br0"

COOKIE=0x20000

OF13="-O openflow13"

function help_usage()
{
    echo ""
    echo "A script with add or delete a ovs flow"
    echo 
    echo "-p: flow priority, [0, 65535]"
    echo "-d: destination ip address or cidr"
    echo "-i: openflow in_port, [1, 65535]"
    echo "-A: add a drop flow"
    echo "-D: delete a drop flow"
    echo "-h: help info"
    echo 
    echo "example1: Add a cidr drop flow"
    echo "        sh $0 -p 65535 -d 192.168.1.0/24 -i 1 -A"
    echo "example2: Add a ip address drop flow"
    echo "        sh $0 -p 65535 -d 192.168.1.16 -i 2 -A"
    echo "example3: Delete a cidr drop flow"
    echo "        sh $0 -p 65535 -d 192.168.1.0/24 -i 1 -D"
    echo "example4: Delete a ip address drop flow"
    echo "        sh $0 -p 65535 -d 192.168.1.16 -i 2 -D"
    echo
    exit

} 

while getopts "d:i:p:hAD" arg
do
        case $arg in
             d)
                DSTIP=$OPTARG
                ;;
             i)
                INPORT=$OPTARG
                ;;
             p)
                PRIORITY=$OPTARG
                ;;
             A)
                FLAG="1"
                ;;
             D)
                FLAG="0"
                ;;
             h)
                help_usage
                ;;
             ?) 
                echo "unkonw input argument"
                exit 1
        ;;
        esac
done

function param_check()
{
    if [ "$PRIORITY" -lt "0" -o "$PRIORITY" -gt "65535" ]; then 
        echo "ERROR: 0 <= priority <= 65535, exit"
        exit 1
    fi
    if [ "$INPORT" -le "0" -o "$INPORT" -gt "65535" ]; then 
        echo "ERROR: 0 < inport <= 65535  exit"
        exit 1
    fi
    if [ "$FLAG" -ne "0" -a "$FLAG" -ne "1" ]; then 
        echo "ERROR: must set add or remove drop flow"
        exit 1
    fi
}

function main ()
{
    if [ $# != 7 ];then
        echo
        echo "input param error,exit"
        help_usage
    fi

    param_check

    if [ "$FLAG" -eq "0" ]; then 
         remove_drop_flow_rule
    fi
    if [ "$FLAG" -eq "1" ]; then 
         add_drop_flow_rule
    fi
}

function add_drop_flow_rule()
{
    #add drop ip packet
    sudo ovs-ofctl ${OF13} add-flow ${BR_NAME} cookie=$COOKIE,table=${DROP_TABLE},priority="$PRIORITY",in_port="$INPORT",ip,nw_dst="$DSTIP",actions=drop

}

function remove_drop_flow_rule()
{
    sudo ovs-ofctl ${OF13} del-flows ${BR_NAME} --strict "table=${DROP_TABLE},priority=$PRIORITY,in_port=$INPORT,ip,nw_dst=$DSTIP"
}

main $*
