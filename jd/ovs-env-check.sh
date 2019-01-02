#!/bin/bash

BRIDGE="br0"
BRIDGEPHY="br-phy"
MAX_OFPORT="65280"
METADATANAME="tap_metadata"

DPTYPEKERNEL="linux-kernel"
DPTYPEOVSDPDK="ovs-dpdk"

RED='\e[1;31m'
NC='\e[0m'

INTERFACE_INFO="/tmp/interfaces"
ETHRTABLE="/etc/sysconfig/network-scripts/route-eth1"
DPDKETHRTABLE="/etc/sysconfig/network-scripts/route-br-phy"


function perror()
{
    echo -e "${RED} ===============================Error=================================== ${NC}"
    echo -e "${RED} Error: $@ ${NC}"
    clean
    exit 1
}

function pnerror()
{
    echo -e "${RED} ===============================Error=================================== ${NC}"
    echo -e "${RED} Error: $@ ${NC}"
    clean
}

function pinfo()
{
    echo "Info: $@"
}

function pcheck()
{
    echo "Check: $@"
}

function clean()
{
    if [ -f $INTERFACE_INFO ];then
        rm -f $INTERFACE_INFO
    fi
}

function check_str_null()
{
        if [ "$2" == "" ];then
                pnerror "$1"
        fi
}

function exit_str_null()
{
        if [ "$2" == "" ];then
                perror "$1"
        fi
}

CCC_CONFIG="/etc/cc_controller_vs/cc_controller_vs.json"
function file_check ()
{
    if [ ! -f "$CCC_CONFIG" ];then
        CCC_CONFIG=`echo $CCC_CONFIG_FILE`
    fi

    if [ ! -f "$CCC_CONFIG" ];then
        perror "Please define CCC_CONFIG_FILE environment variable, example: export CCC_CONFIG_FILE=/etc/cc_controller_vs/cc_controller_vs.json"
    fi
}


function check_dpdk_ovs_underlayip()
{
       underlayip=`cat $CCC_CONFIG | grep -i underlay | cut -d ":" -f2 | cut -d"\"" -f2`
       pinfo "underlayip of cc_controller config is $underlayip"
       result=$(ip a  | grep $BRIDGEPHY | grep "inet" | awk '{print $2}' | sed -e 's/\ //g')
       exit_str_null "local host is not exist underlayip $underlayip" $result
       pcheck "ip address of $underlayip exist in local host, result is OK"
       #ipmask=`(echo $underlayip|cut -d. -f1)`"."`(echo $underlayip|cut -d. -f2)`"."`(echo $underlayip|cut -d. -f3)`".0"
       ipmask=$(ipcalc -n $result | cut -d"=" -f2)
       result=$(ip route | grep $ipmask | grep $BRIDGEPHY)
       exit_str_null "route of $result is not exist" ${result}
       pcheck "route of underlayip is: $result"
       pcheck "route of $underlayip exist in route table, result is OK"
}

function check_underlayip()
{
       underlayip=`cat $CCC_CONFIG | grep -i underlay | cut -d ":" -f2 | cut -d"\"" -f2`
       pinfo "underlayip of cc_controller config is $underlayip"
       result=$(ip a  | grep $underlayip| grep "inet" | awk '{print $2}' | sed -e 's/\ //g')
       exit_str_null "local host is not exist underlayip $underlayip" $result
       pcheck "ip address of $underlayip exist in local host, result is OK"
       #ipmask=`(echo $underlayip|cut -d. -f1)`"."`(echo $underlayip|cut -d. -f2)`"."`(echo $underlayip|cut -d. -f3)`".0"
       ipmask=$(ipcalc -n $result | cut -d"=" -f2)
       result=$(ip route | grep $ipmask)
       exit_str_null "route of $result is not exist" ${result}
       pinfo "route of underlayip is: $result"
       pcheck "route of $underlayip exist in route table, result is OK"
}

function check_route()
{
    RTABLE=$1
    if [ -f $RTABLE ];then
        while read line
        do
            gw=$(echo $line  | awk '{print $3}')
            cidr=$(echo $line  | awk '{print $1}')
            exit_str_null "gw of $cidr is not exist" ${cidr}
            pinfo "gw of $cidr is: $gw"
            pcheck "route of $underlayip exist in route table, result is OK"
            ping_check $gw  $underlayip
        done < $RTABLE
    fi
}



function check_ovs_version()
{
   OVS_VERION=$1
   cur_ver=$(ovs-vsctl --version | grep ovs-vsctl | cut -d" " -f4)
   if [ $cur_ver != $OVS_VERION ];then
       pnerror "ovs version is not $OVS_VERION"
   else
       pcheck "openvsiwth version is $OVS_VERION, result is OK"
   fi
}


function check_ovs_mode()
{
    EXIST_STRING="vport_vxlan nf_nat_ipv6 nf_nat_ipv4 libcrc32c gre nf_nat nf_conntrack nf_defrag_ipv6 nf_defrag_ipv4"
    modstr=$(lsmod | grep openvswitch | xargs echo)
    for str in $EXIST_STRING
    do
        isNull=$(echo $modstr | grep $str | cut -d" " -f1)
        if [ -z ${isNull} ];then
            pnerror "$str is not exist in kernel"
        fi
    done
    pcheck "load mode of openvswith is exist, result is OK"
}

function check_dpdk_ovs_bridge()
{
    local flag=0
    bridges=$(ovs-vsctl list-br)
    for b in $bridges
    do
        if [ "$b" == "$BRIDGE" ];then
            pinfo "$BRIDGE is exist"
            flag=`expr $flag + 1`
        fi
        if [ "$b" == "$BRIDGEPHY" ];then
            pinfo "$BRIDGEPHY is exist"
            flag=`expr $flag + 1`
        fi
    done
    if [ $flag == 2  ];then
        pcheck "bridge $BRIDGE and $BRIDGEPHY is exist in ovs, result is OK"
    else
        perror "bridge $BRIDGE or $BRIDGEPHY is not exist in $bridges"
    fi

}

function check_bridge()
{
    local flag=0
    bridges=$(ovs-vsctl list-br)
    for b in $bridges
    do
        if [ "$b" == "$BRIDGE" ];then
            flag=1
        fi
    done
    if [ $flag == 1  ];then
        pcheck "bridge $BRIDGE is exist in ovs, result is OK"
    else
        perror "bridge $BRIDGE is not exist in $bridges"
    fi
}

function get_process_id()
{
    pid=$(ps -ef |grep -v 'grep '| grep $1 | awk '$2 ~ /[0-9]+/ {print $2}' | while read s; do echo $s; done)
    echo $pid
}

function check_ovs_process()
{
    pid=$(get_process_id "ovs-vswitchd")
    exit_str_null "ovs-vswitchd is not running" $pid
    pcheck "process_id of ovs-vswitchd is $pid, result is OK"

    pid=$(get_process_id "ovsdb-server")
    exit_str_null "ovsdb-server is not running" $pid
    pcheck "process_id of ovsdb-server is $pid, result is OK"
}

function check_cc_controller_process()
{
    pid=$(get_process_id "cc_controller")
    exit_str_null "cc_controller is not running" $pid
    pcheck "process_id of cc_controller is $pid, result is OK"
}

function check_ovs_connected()
{
    result=$(ovs-vsctl show | grep -w "br0" -A 10 | grep is_connected | cut -d":" -f2 | sed -e 's/\ //g')
    if [ "$result" != "true" ];then
         pnerror "ovs can not connect cc_controller"
    fi
    pcheck "ovs have connected cc_controller, result is OK"
}

function check_ovs_fail_mode()
{

    result=$(ovs-vsctl show | grep -w "br0" -A 10 | grep fail_mode|sed -e 's/\ //g' | cut -d":" -f2)
    if [ "$result" != "secure" ];then
         pnerror "fail_mode of ovs is not secure"
    fi

    pcheck "fail_mode of ovs is $result, result is OK"
}

function ping_check()
{
    local r=""

    r=`ping -i 0.1 -c 5 -W 1 -I $2 $1 | grep 'packet loss' | awk -F'packet loss' '{ print $1 }' | awk '{ print $NF }' | sed 's/%//g'`
    if [ "${r}" != "0" ];then
         pnerror "$2 ping $1 failed"
         return
    fi
    pcheck "$2 can ping $1, result is OK"
}

function check_vxlan_status()
{
     local ip=$(echo $1 | sed 's/vx//g')
     ping_check $ip  $underlayip
}

function check_ofport()
{
        local portid=$1
        local ofport=""

        ofport=$(ovs-vsctl get interface $portid ofport)
        if [ $? != 0 ];then
               pnerror "interface $portid is not exist in ovsdb"
        fi
        check_str_null "ofport $ofport of $portid is null" $ofport

        result=$(echo $ofport | awk '{print int($0)}')
        max=$(echo $MAX_OFPORT | awk '{print int($0)}')
        if [ $result -le 0 -o $result -ge $max ];then
            pnerror "ofport $ofport is invalid"
        fi
        pcheck "ofport of $portid is $ofport, result is OK"
}

function check_vxlan_tunnel()
{
    vxports=$(ovs-vsctl list-ports $BRIDGE | grep ^vx)
    for h in $vxports
    do
        check_ofport $h
        check_vxlan_status $h
    done
}

function check_metadata_ofport()
{
    check_ofport $METADATANAME
}

function check_metadata_ip()
{
    metadata_name=$(ip a | grep "169.254.169.254/32" | awk -F" " '{print $5}')
    check_str_null "ip address 169.254.169.254/32 is not exist in kernel " ${metadata_name}
    if [ "${metadata_name}" != "${METADATANAME}" ];then
        pnerror "ip address 169.254.169.254/32 is not at ${METADATANAME}, is at ${metadata_name}"
    fi
    pcheck "ip of tap_metadata is 169.254.169.254/32, result is OK"
}

function dpdkovscheck()
{
    check_ovs_version "2.7.0"
    check_dpdk_ovs_bridge
    check_cc_controller_process
    check_ovs_process
    check_ovs_connected
    check_ovs_fail_mode
    check_metadata_ofport
    check_metadata_ip
    check_dpdk_ovs_underlayip
    check_route $DPDKETHRTABLE
    check_vxlan_tunnel
    clean
}

function linuxkernelcheck()
{
    check_ovs_version "2.6.0"
    check_ovs_mode
    check_bridge
    check_cc_controller_process
    check_ovs_process
    check_ovs_connected
    check_ovs_fail_mode
    check_metadata_ofport
    check_metadata_ip
    check_underlayip
    check_route $ETHRTABLE
    check_vxlan_tunnel
    clean
}

function main()
{
       file_check
       dptype=`cat $CCC_CONFIG | grep -i DatapathType| cut -d ":" -f2 | cut -d"\"" -f2`
       if [ "$dptype" == ${DPTYPEOVSDPDK} ];then
           dpdkovscheck
       elif [ "$dptype" == ${DPTYPEKERNEL} ];then
           linuxkernelcheck
       else
           perror "datapath type $dptype is error for config"
       fi
}

main


