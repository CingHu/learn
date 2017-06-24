#!/bin/bash

MAX_OFPORT="65280"

VSCTL="ovs-vsctl"
DPCTL="ovs-dpctl"
APPCTL="ovs-appctl"
OFCTL="ovs-ofctl -O openflow13"
BRIDGE="br0"

SliptCapFile="ovsping"
RCVLOOPNUM=1
SENDLOOPNUM=3
WAITIME=3

ID=5000
SEQ=5000

function help_usage()
{
     echo ""
     echo "input param error:"
     echo ""
     echo "-p:         port_id of port"
     echo "-s:         (option) smac of ping request pkt"
     echo "-d:         dmac of ping request pkt"
     echo "-w:         sip of ping request pkt"
     echo "-x:         dip of ping request pkt"
     echo "-e:         namespace of exec tcpdump"

     echo ""
     echo "example1: receive ping reply at local host"
     echo "        sh $0 -p port-ougdw5m7du  -d fa:16:3e:0d:19:a8 -w 192.168.1.3 -x 192.168.1.4"
     echo "example2: receive ping reply at a namespace"
     echo "        sh $0 -p port-ougdw5m7du  -d fa:16:3e:0d:19:a8 -w 192.168.1.3 -x 192.168.1.4 -e port-ougdw5m7du"
     echo ""
     exit 1
}

function param_check()
{
    if [ $# -lt  8 ];then
        help_usage
    fi
}

#tcpdump -c 1 -i port-abx98fm0ec icmp and src host 192.168.1.4 and dst host 192.168.1.5 and icmp[4:2]=100
#ovs-ofctl -O openflow13  packet-out br0 12 "resubmit(12,0)" "$str"

function EError()
{
        echo -e "${RED} ========================================Error===================================== ${NC}"
        echo -e "${RED} Error: $* ${NC}"
        clean
        exit 1
}

function Error()
{
        echo -e "${RED} Error: $* ${NC}"
}

function Info()
{
        echo "Info: $*"
}

function get_ofport_num()
{

        local ofport=""
        local result=0
        local max=0

        ofport=$($VSCTL get Interface $1 ofport)
        if [ $? -ne 0 ];then
                EError "get ofport of $1 fail from ovsdb"
                return 1
        fi

        if [ "${ofport}" == "" ]; then
                EError "ofport of $1 is null"
                return 1
        fi

        result=$(echo $ofport | awk '{print int($0)}')
        max=$(echo $MAX_OFPORT | awk '{print int($0)}')
        if [ $result -le 0 -o $result -ge $max ];then
                EError "ofport of $1 is valid, value:$ofport"
                return 1
        fi


        echo $ofport
        return 0
}

function get_ofport()
{
        ofport=$(get_ofport_num $1)
        if [ $? != 0 ];then
              EError "ofport of $vxlanhost is invalid"
              exit 1
        fi

        Info "ofport of $1 is $ofport"
        OFPORT=$ofport
}

#ovs-ofctl -O openflow13  packet-out br0 12 "resubmit(12,0)" "$str"
function genICMPPkt() {
        ICMPREQUEST=$(ovsdebug $SMAC $SIP $DMAC $DIP $ID $SEQ)
}

#tcpdump -c 1 -i port-abx98fm0ec icmp and src host 192.168.1.4 and dst host 192.168.1.5 and icmp[4:2]=100
function checkRcvICMPPkt() {
    if [ "$NS" != "" ];then
        TCPDUMP="ip netns exec $NS tcpdump -i any"
    else
        TCPDUMP="tcpdump -i $PORTID"
    fi

    declare -a tcpdumppids
    local pid=""

    Info "$TCPDUMP -w $PORTID.iLoop.dmp -c 1  icmp and src host $DIP and dst host $SIP and icmp[4:2]=$ID"
    for ((iLoop=0; iLoop<$RCVLOOPNUM; iLoop++))
    do
        {
            $TCPDUMP -w $PORTID.$iLoop.dmp -c 1 icmp and src host $DIP and dst host $SIP and icmp[4:2]=$ID -q 2> /dev/null &
            pid=$!
            tcpdumppids=(${tcpdumppids[*]}${pid})
            sleep 1
        }
    done 
}

function get_port_mac()
{
        if [ "$SMAC" == "" ];then
            PORTMAC=$($VSCTL list Interface  $PORTID | grep external_ids | awk -F "attached-mac=" '{print $2}' | cut -d"," -f1|sed -e 's/\"//g')
            if [ "$PORTMAC" == "" ];then
                EError "cannot find mac of $PORTID from ovsdb" $PORTMAC
            fi
            Info "mac of $PORTID is $PORTMAC"
            SMAC=$PORTMAC
        fi
}

function readRcvICMPPkt() {
    for ((iLoop=0; iLoop<$RCVLOOPNUM; iLoop++))
    do
        if [ -s $PORTID.$iLoop.dmp ];then
            tcpdump -r $PORTID.$iLoop.dmp -en -q
            return
        fi
       #echo "============================= ping $DIP result ==========================================="
        echo "=========================== Error: ping $DIP failed ======================================"
    done
}

function clean()
{
    for ((iLoop=0; iLoop<$RCVLOOPNUM; iLoop++))
    do
        if [ -f $PORTID.$iLoop.dmp ];then
            rm -rf $PORTID.$iLoop.dmp
        fi
    done
    for pid in ${tcpdumppids[*]}
    do
        kill -9 $pid 2> /dev/null &
    done
}

while getopts "p:s:d:w:x:e:h" arg
do
        case $arg in
             p)
                PORTID=$OPTARG
                ;;
             s)
                SMAC=$OPTARG
                ;;
             d)
                DMAC=$OPTARG
                ;;
             w)
                SIP=$OPTARG
                ;;
             x)
                DIP=$OPTARG
                ;;
             e)
                NS=$OPTARG
                ;;
             h)
                help_usage
                ;;
             ?)
                echo "unkonw input argument"
                help_usage
                exit 1
        ;;
        esac
done

function printdpflows()
{
        echo "===============================datapath output host flow:==========================="
        $DPCTL  -m dump-flows  filter="in_port=$OFPORT,ip,nw_src=$SIP,nw_dst=$DIP"
        echo "===================================================================================="
        echo ""
        echo ""
        echo "================================datapath input host flow:==========================="
        $DPCTL  -m dump-flows  filter="ip,nw_src=$DIP,nw_dst=$SIP"
        echo "===================================================================================="
}


function sendICMP()
{
      genICMPPkt
      Info "icmp request pkt: $ICMPREQUEST"
      for ((iLoop=0; iLoop<$SENDLOOPNUM; iLoop++))
      do
          ${OFCTL} packet-out br0 $OFPORT "resubmit($OFPORT,0)" "$ICMPREQUEST"
      done
}

function sleeptime()
{
    i=1
    while [ $i -lt $WAITIME ]
    do
        Info "sleep $WAITIME, current $i"
        sleep 1
        let i=i+1
    done
    echo "============================= ping $DIP result ==========================================="
}


function main()
{
    param_check $*
    get_ofport $PORTID
    get_port_mac
    checkRcvICMPPkt
    sendICMP
    #printdpflows
    sleeptime
    readRcvICMPPkt
    clean
}

main $*
