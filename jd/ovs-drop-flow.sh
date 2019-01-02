#!/bin/bash

DROP_TABLE=0
BR_NAME="br0"
PRIORITY=65535
SECOND=1
TIMEOUT=$((60*60*24*30*6*$SECOND))

INIT_COOKIE=20000
OF13="-O openflow13"
#OF13=""
FLOW_FILE="/etc/dropflow.file"

TYPE="cookie"

touch ${FLOW_FILE}

function help_usage()
{
    echo ""
    echo "A script with add ,delete or query a ovs flow"
    echo
    echo "-d: destination ip address or cidr"
    echo "-i: openflow port name"
    echo "-c: openflow cookie value"
    echo "-t: idle timeout for adding flow in second"
    echo "-h: help info"
    echo "-A: add a drop flow"
    echo "-D: delete a drop flow"
    echo "-Q: query all adding drop flow"
    echo
    echo "example1: Add a cidr drop flow"
    echo "        sh $0 -d 192.168.1.0/24 -i port-c85fi11170 -A"
    echo "example2: Add a flow to drop all ip traffic"
    echo "        sh $0 -d 0.0.0.0/0 -i port-c85fi11170 -A"
    echo "example3: Add a ip address drop flow with 10s idle timeout"
    echo "        sh $0 -d 192.168.1.16 -i port-c85fi11170 -A -t 10"
    echo "example4: Delete a drop flow"
    echo "        sh $0 -c 20001  -D"
    echo "example5: Query all adding drop flow "
    echo "        sh $0 -Q"
    echo
    exit 1

}

while getopts "d:i:c:t:hADQ" arg
do
        case $arg in
             d)
                DSTIP=$OPTARG
                ;;
             i)
                INPORT_NAME=$OPTARG
                ;;
             c)
                COOKIE=$OPTARG
                ;;
             t)
                TIMEOUT=$(($OPTARG*$SECOND))
                ;;
             h)
                help_usage
                ;;
             A)
                FLAG="1"
                ;;
             D)
                FLAG="0"
                ;;
             Q)
                FLAG="2"
                ;;
             ?)
                echo "unkonw input argument"
                exit 1
                ;;
        esac
done

function remove_param_check()
{
    echo $COOKIE
    if [ "${COOKIE}" == "" ]; then
        echo "ERROR, input cookie value is null"
        exit 1
    fi
}

function check_params()
{
    if [[ $FLAG == "" ]]; then
        echo "One of -A -D and -Q is required"
        help_usage
    fi
    case $FLAG in
    "0")
        # delete
        if [[ $COOKIE == "" ]]; then
            echo "ERROR: input cookie value is null"
            exit 1
        fi
        ;;
    "1")
        # add
        if [[ $INPORT_NAME == "" || $DSTIP == "" ]]; then
            echo "ERROR: inport($INPORT_NAME) or dest($DSTIP) ip is null"
            exit  1
        fi
        ;;
    "0")
        ;;
    esac

}

function main ()
{
    check_params

    if [ "$FLAG" -eq "0" ]; then
         remove_param_check
         remove_drop_flow_rule
    fi
    if [ "$FLAG" -eq "1" ]; then
         add_drop_flow_rule
    fi
    if [ "$FLAG" -eq "2" ]; then
         get_drop_flow_rule
    fi
}

function get_last_cookie()
{
    #cat ${FLOW_FILE} | grep -i "${DSTIP}"
    #if [ $? == 0 ]; then
    #    echo "flow is exist"
    #    exit 1
    #fi
    count=$(cat ${FLOW_FILE} | grep ^"${TYPE}" | wc -l)
    if [ $count = "0" ];then
        COOKIE=${INIT_COOKIE}
    else
        COOKIE=$(cat ${FLOW_FILE} | grep ^"${TYPE}" | tail -n 1 | cut -d":" -f2)
        let "COOKIE+=1"
    fi
}

function get_inport()
{
    INPORT=$(sudo ovs-vsctl get Interface ${INPORT_NAME} ofport)
    if [ $? != 0 ]; then
        echo "ERROR, in_port name is not exist"
        exit 1
    fi
    if [ "${INPORT}" -le "0" ]; then
        echo "ERROR, in_port num is ${INPORT} <= 0"
        exit 1
    fi
}
function add_drop_flow_rule()
{
    get_inport
    get_last_cookie
    #add drop ip packet
    sudo ovs-ofctl ${OF13} add-flow ${BR_NAME} cookie=$COOKIE,idle_timeout=$TIMEOUT,table=${DROP_TABLE},priority="$PRIORITY",in_port="$INPORT",ip,nw_dst="$DSTIP",actions=drop
    if [ $? = 0 ];then
         echo -e "${TYPE}:${COOKIE}:${DSTIP}" >> ${FLOW_FILE}
         echo "${COOKIE}:${DSTIP}"
    else
         echo "ERROR, ovs cmd exec  Add failed"
		 exit 1
    fi

}

function remove_drop_flow_rule()
{
    sudo ovs-ofctl ${OF13} del-flows ${BR_NAME} "cookie=${COOKIE}/-1"
    if [ $? = 0 ];then
         sed -i "/${COOKIE}/d" ${FLOW_FILE}
    else
         echo "ERROR, ovs cmd exec Remove  failed"
		 exit 1
    fi
}

function get_drop_flow_rule()
{
    cat ${FLOW_FILE}
}

main $*

