#!/bin/bash

MAX_OFPORT="65280"

VSCTL="ovs-vsctl"
DPCTL="ovs-dpctl"
APPCTL="ovs-appctl"
OFCTL="ovs-ofctl -O openflow13"
BRIDGE="br0"
MIRRORNAME=debugmirror
MIRRORPORT=debugport

SliptCapFile="ovsarping"
RCVLOOPNUM=1
SENDLOOPNUM=3
WAITIME=2
FROMPORT=1

HARDTIME=60

ID=$(echo $RANDOM)
SEQ=$(echo $RANDOM)

DEFAULTSMAC="fa:16:3e:00:00:01"

function help_usage()
{
     echo ""
     echo "input param error:"
     echo ""
     echo "-p:         port_id of port"
     echo "-s:         (option) smac of arp request pkt"
     echo "-d:         dmac of arp request pkt"
     echo "-w:         sip of arp request pkt(gw ip)"
     echo "-x:         dip of arp request pkt"
     echo "-e:         namespace of exec tcpdump"

     echo ""
     echo "example1: receive arp reply at local host"
     echo "        sh $0 -p port-7dz4wrpefy -d ff:ff:ff:ff:ff:ff -w 172.16.10.1  -x 172.16.10.3"
     echo "example2: receive arp reply at a namespace"
     echo "        sh $0 -p port-7dz4wrpefy -d ff:ff:ff:ff:ff:ff -w 172.16.10.1  -x 172.16.10.3  -e  port-7dz4wrpefy"
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
function genARPPkt() {
        ARPREQUEST=$(arpping $SMAC $SIP $DMAC $DIP)
}

#tcpdump -c 1 -i port-abx98fm0ec icmp and src host 192.168.1.4 and dst host 192.168.1.5 and icmp[4:2]=100 and 'icmp[icmptype]==0'
function checkRcvARPPkt() {
    if [ "$NS" != "" ];then
        TCPDUMP="ip netns exec $NS tcpdump -i $PORTID"
    else
        TCPDUMP="tcpdump -i $PORTID"
    fi

    local pid=""

    Info "$TCPDUMP -w $PORTID.iLoop.dmp -c 1  arp and ether src host $PORTMAC and ether dst host $SMAC and ether[20:2] == 0x0002"
    for ((iLoop=0; iLoop<$RCVLOOPNUM; iLoop++))
    do
        {
            $TCPDUMP -w $PORTID.$iLoop.dmp -c 1  arp and ether src host $PORTMAC and ether dst host $SMAC and 'ether[20:2] == 0x0002' -q 2> /dev/null &
            pid=$!
            sleep 1
        }
    done 
}

function checkvHostUserRcvICMPPkt() {
    Info "dpdk port rev arp packet"
    ifconfig $BRIDGE up
    Info "ovs-ofctl add-flow -O openflow13 $BRIDGE \"table=0 hard_timeout=5, arp,arp_op=2,priority=20000, reg7=$OFPORT, actions=LOCAL\""
    ovs-ofctl add-flow -O openflow13 $BRIDGE "table=0 hard_timeout=5,in_port=$OFPORT arp,arp_op=2,priority=20000, actions=LOCAL"
    if [ "$NS" != "" ];then
        TCPDUMP="ip netns exec $NS tcpdump -i $PORTID"
    else
        TCPDUMP="tcpdump -i $BRIDGE"
    fi

    local pid=""

    Info "$TCPDUMP -w $PORTID.iLoop.dmp -c 1  arp and ether src host $PORTMAC and ether dst host $SMAC and ether[20:2] == 0x0002"
    for ((iLoop=0; iLoop<$RCVLOOPNUM; iLoop++))
    do
        {
            $TCPDUMP -w $PORTID.$iLoop.dmp -c 1  arp and ether src host $PORTMAC and ether dst host $SMAC and 'ether[20:2] == 0x0002' -q 2> /dev/null &
            pid=$!
            sleep 1
        }
    done 
}

function check_datapath_type()
{
    ovsdpdk=$(ovs-vsctl list open_vswitch | grep "dpdk-init=\"true\"")
    if [ "$ovsdpdk" != "" ];then
        DPTYPE="ovs-dpdk"
    else
        DPTYPE="linux-kernel"
    fi
    Info "type of host is $DPTYPE"
}
function delete_mirror()
{
    #del mirror
    ovs-vsctl clear Bridge $BRIDGE mirrors

    #mirrorids=$(ovs-vsctl list bridge | grep -w mirrors | cut -d":" -f2 | sed -e "s/\]//g" -e "s/\[//g" -e '/^\s*$/d' -e 's/\ //g')
    #for m in `echo $mirrosids | sed "s/,/\ /g"`
    #do
    #    pinfo "remove mirror $m from bridge $BRIDGE"
    #    ovs-vsctl -- remove bridge $BRIDGE mirrors $m
    #done
}


function get_port_mac()
{
        if [ "$SMAC" == "" ];then
            PORTMAC=$($VSCTL list Interface  $PORTID | grep external_ids | awk -F "attached-mac=" '{print $2}' | cut -d"," -f1|sed -e 's/\"//g')
            if [ "$PORTMAC" == "" ];then
                EError "cannot find mac of $PORTID from ovsdb" $PORTMAC
            fi
            Info "mac of $PORTID is $PORTMAC"
            SMAC=$DEFAULTSMAC
        fi
}


function readRcvARPPkt() {
    for ((iLoop=0; iLoop<$RCVLOOPNUM; iLoop++))
    do
        if [ -s $PORTID.$iLoop.dmp ];then
            tcpdump -r $PORTID.$iLoop.dmp -en -q
            return
        fi
        echo "=========================== Error: arp ping $DIP failed ======================================"
    done
}

function clean()
{
    ifconfig $BRIDGE down
    for ((iLoop=0; iLoop<$RCVLOOPNUM; iLoop++))
    do
        if [ -f $PORTID.$iLoop.dmp ];then
            rm -rf $PORTID.$iLoop.dmp
        fi
    done

    pids=$(pidof tcpdump)
    for p in $pids
    do
        kill -9 $p
    done



    #mirrorids=$(ovs-vsctl list bridge | grep -w mirrors | cut -d":" -f2 | sed -e "s/\]//g" -e "s/\[//g" -e '/^\s*$/d' -e 's/\ //g')
    #for m in `echo $mirrosids | sed "s/,/\ /g"`
    #do
    #    pinfo "remove mirror $m"
    #    ovs-vsctl -- remove bridge $BRIDGE mirrors $m
    #done
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
                INPUTSIP=$OPTARG
                SIP="`echo $INPUTSIP|cut -d. -f1`.`echo $INPUTSIP|cut -d. -f2`.`echo $INPUTSIP|cut -d. -f3`.2"
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


function sendARP()
{
      genARPPkt
      Info "arp request pkt: $ARPREQUEST"
      for ((iLoop=0; iLoop<$SENDLOOPNUM; iLoop++))
      do
          ${OFCTL} packet-out $BRIDGE $FROMPORT  "output=$OFPORT" "$ARPREQUEST"
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
    echo "============================= arp ping $DIP result ==========================================="
}


function main()
{
    param_check $*
    check_datapath_type
    get_ofport $PORTID
    get_port_mac
    if [ "$DPTYPE" == "ovs-dpdk" ];then
        checkvHostUserRcvICMPPkt
    else
        checkRcvARPPkt
    fi
    sendARP
    sleeptime
    readRcvARPPkt
    clean
}

main $*


