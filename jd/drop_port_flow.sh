#!/bin/bash

DROP_TABLE=0
BR_NAME="br0"
PRIORITY="65535"
MAX_OFPORT="65280"
IN_PORT=""
PORTID=""

OF13="-O openflow13"

function help_usage()
{
    echo ""
    echo "A script with add or delete a ovs drop flow, only match in_port"
    echo 
    echo "-p: port_id of vm or dockor"
    echo "-A: add a drop flow"
    echo "-D: delete a drop flow"
    echo "-h: help info"
    echo 
    echo "example1: Add a drop flow"
    echo "        sh $0 -p port-1lwhykixw2 -A"
    echo "example2: Delete a drop flow"
    echo "        sh $0 -p port-1lwhykixw2 -D"
    exit

} 

while getopts "p:hAD" arg
do
        case $arg in
             p)
                PORTID=$OPTARG
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

function get_ofport_num()
{

        local ofport=""
        local result=0
        local max=0

        ofport=$(ovs-vsctl get Interface $1 ofport)
        if [ $? -ne 0 ];then
                echo "Error: get ofport of $1 fail from ovsdb"
                return 1
        fi

        if [ "${ofport}" == "" ]; then
                echo "Error: ofport of $1 is null"
                return 1
        fi

        result=$(echo $ofport | awk '{print int($0)}')
        max=$(echo $MAX_OFPORT | awk '{print int($0)}')
        if [ $result -le 0 -o $result -ge $max ];then
                echo "Error: ofport of $1 is valid, value:$ofport"
                return 1
        fi


        echo $ofport
        return 0
}

function param_check()
{

    IN_PORT=$(get_ofport_num ${PORTID})
	
    if [ "$FLAG" -ne "0" -a "$FLAG" -ne "1" ]; then 
        echo "Error: must set add or remove drop flow"
        exit 1
    fi
}

function main ()
{
    if [ $# != 3 ];then
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
    ovs-ofctl ${OF13} add-flow ${BR_NAME} "table=${DROP_TABLE},priority=$PRIORITY,in_port=$IN_PORT actions=drop"
    if [ $? -ne 0 ]; then
        echo "add in_port=$IN_PORT failed"
        exit 1
    fi

}

function remove_drop_flow_rule()
{
    ovs-ofctl ${OF13} del-flows ${BR_NAME} --strict "table=${DROP_TABLE},priority=$PRIORITY,in_port=$IN_PORT"
    if [ $? -ne 0 ];then
        echo "delete in_port=$IN_PORT failed"
        exit 1
    fi
}

main $*

