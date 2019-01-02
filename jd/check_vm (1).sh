#!/bin/bash

#NETLIST[MAC]=NAME@MAC@IP1,IP2
declare -A NETLIST=()

MTU=1450

RED='\e[1;31m' 
NC='\e[0m'

DIRNAME=`date +%s`$RANDOM
PATHTMP="/tmp"
PATHINFO="$PATHTMP/tmp-$DIRNAME"

#PATHINFO="."
DEBUG="false"

TMPFILE="$PATHINFO/tmp"
IPINFO="$PATHINFO/ip"
ROUTEINFO="$PATHINFO/route"
FWINFO="$PATHINFO/fw"
DHCPSERVICEINFO="$PATHINFO/dhcpservice"
DHCPPORTINFO="$PATHINFO/dhcpport"
STATS="$PATHINFO/stats"

DEFAULT_LINUX_NIC1_NAME="eth0, eth1"

function clean()
{
    return
}

function perror()
{
        echo -e "${RED} ========================================Error===================================== ${NC}"
        echo -e "${RED} Error: $* ${NC}"
        clean
}

function pinfo()
{
        echo "Info: $*"
}


function check_str_null()
{
        if [ "$2" == "" ];then
              perror "$1"
        fi
}

function check_str_null_exit()
{
        if [ "$2" == "" ];then
              perror "$1"
              exit 1
        fi
}

function ncomparestr()
{
    if [ "$2" != "$3" ];then
        perror "$1"
    fi
}


function help_usage()
{
     echo ""
     echo "input param error:"
     echo ""
     echo "-v:         vm_id of vm"
     echo "-d:         show details info"
     echo "-m:         check mtu ,only linux"
     echo "-n:         network inof of vm, format MAC@IP1@GWIP%MAC2@IP2,IP3@GWIP2"

     echo ""
     echo "example: get a vm info"
     echo "        sh $0 -v i-y8a7358djj -n fa:16:3e:00:01:01@192.168.0.3,192.168.0.4@192.168.0.1 -d"
     echo ""
     exit 1
}



while getopts "v:n:m:hd" arg
do
        case $arg in
             v)
                VMID=$OPTARG
                ;;
             n)
                NETS=$OPTARG
                ;;
             m)
                MTU=$OPTARG
                ;;
             d)
                DEBUG="true"
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

VMCMD="virsh qemu-agent-command ${VMID} "

function check_qga_status(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-ping"}'
    local sanity_result="{return:{}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "check the status of qemu agent failed, ${result}"
        exit 1 
    fi
}

function get_pid(){
echo $1 | awk '
{
    string=$0
    len=length(string)  
    for(i=0; i<=len; i++)  
    {  
        tmp=substr(string,i,1)  
        if(tmp ~ /[0-9]/)  
        {  
            str=tmp  
    	    str1=(str1 str)  
        }  
    }  
    print str1  
}
'
}


function get_qga_stats(){
    local pid=$1
    local exitcode=0
    local return_data=""
    local cmd='{"execute": "guest-exec-status", "arguments": {"pid": '$pid'}}'

    ${VMCMD} ${cmd}  | sed -e "s/out-data/out_data/g" > $STATS
    rcode=$(jq .return.exitcode $STATS)
    if [ "${rcode}" != "0" ];then
	perror "guest-exec-status failed, pid:$pid, `cat $STATS`"
        return 1
    fi
    rcode=$(jq .return.exited $STATS)
    if [ "${rcode}" != "true" ];then
	perror "guest-exec-status failed, pid:$pid, `cat $STATS`"
        return 1
    fi

    jq .return.out_data $STATS | sed "s/\"//g" | base64 -d
    return 0
    
}

function get_linux_vm_ip(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-exec", "arguments": {"path": "/bin/sh",  "capture-output": true, "arg": ["-c", "ip a"]}}'
    local sanity_result="{return:{pid:}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g' -e 's/[0-9]//g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "[ip] get ip info failed, ${result}"
        exit 1 
    fi

    pid=$(get_pid ${result})
    if [ "{$pid}" == "" ];then
        perror "[ip] get pid failed"
    fi

    get_info $pid  $IPINFO

}

function printinfo(){
    if [ "$DEBUG" == "true" ];then
        cat $1
    fi
}

function get_info(){
    local pid=$1
    local file=$2
    local filter=$3
    get_qga_stats $pid > $file
    if [ $? -ne 0 ];then
        perror "get qga stats failed"
        exit 1
    fi
    if [ "$filter" != "" ];then
        cat $file | grep "$filter" | grep -v grep  > $TMPFILE
        cat $TMPFILE > $file
    fi
    printinfo $file
}

function check_mtu(){
     r=$(cat $IPINFO | grep ${mac} -B 1 | head -n 1 | grep "mtu ${MTU}")
     check_str_null "the mtu of $VMID is Error, $r" $r
     pinfo "the mtu of $VMID for ${mac} is $MTU"
}

function check_nic_status(){
     r=$(cat $IPINFO | grep ${mac} -B 1 | head -n 1 | grep "state UP")
     check_str_null "the nic status is Error" ${r}
     pinfo "the status of $VMID for ${mac} is UP"
}

function check_nic_name(){
     r=$(cat $IPINFO | grep ${mac} -B 1 | head -n 1 | cut -d":" -f2 | sed -e "s/\ //g")
     check_str_null "the nic name is null" ${r}
     pinfo "the name of $VMID for ${mac} is ${r}"
     NIC_NAME=${r}
}

function check_ip_address(){
    count=0
    for net in `echo $NETS | sed -e "s/%/\ /g"`
    do
        pinfo "[check_ip_address] $net"
        local mac=$(echo $net|cut -d@ -f1)
        local ips=$(echo $net|cut -d@ -f2)
        local rip=""
        rmac=$(cat $IPINFO | grep ${mac}) 
        check_str_null_exit "It can not find mac $mac" ${rmac}
        pinfo "mac of $VMID is ok"
        
        for i in `echo $ips | sed -e "s/,/\ /g"`
        do
            rip=$(cat $IPINFO | grep ${mac} -A 5 | grep ${i}) 
            check_str_null "It can not find ip $i in mac $mac" ${rip}
            pinfo "ip of $VMID is $i"
        done

        check_mtu
        check_nic_status
        check_nic_name

        new_net="$NIC_NAME@$net"
        NETLIST[$count]=${new_net}
        let count++
    done
}

function check_linux_ip(){
    get_linux_vm_ip
    check_ip_address
}

function get_linux_vm_route(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-exec", "arguments": {"path": "/bin/sh",  "capture-output": true, "arg": ["-c", "route -n"]}}'
    local sanity_result="{return:{pid:}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g' -e 's/[0-9]//g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "[ip] get ip info failed, ${result}"
        exit 1 
    fi

    pid=$(get_pid ${result})
    if [ "{$pid}" == "" ];then
        perror "[ip] get pid failed"
    fi

    local ipinfo=""

    get_info $pid  $ROUTEINFO
}

function check_linux_route_table(){
    for net in `echo ${NETLIST[@]}`
    do
        pinfo "[check_route] $net"
        local nic_name=$(echo $net|cut -d@ -f1)
        local mac=$(echo $net|cut -d@ -f2)
        local ips=$(echo $net|cut -d@ -f3)
        local default_route=$(echo $net|cut -d@ -f4)

        if [ "$default_route" != "" ];then
            r=$(cat $ROUTEINFO | grep "^0.0.0.0" | grep $default_route)
        else
            r=$(cat $ROUTEINFO | grep "^0.0.0.0")
        fi 

       check_str_null "It can not find default route for $VMID" ${r}
       pinfo "default route of vm $VMID is `echo ${r}|awk '{print $2}'`"

    done
}

function check_linux_route(){
    get_linux_vm_route
    check_linux_route_table
}

function get_linux_vm_dhcp_service(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-exec", "arguments": {"path": "/bin/sh",  "capture-output": true, "arg": ["-c", "ps", "-ef"]}}'
    local sanity_result="{return:{pid:}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g' -e 's/[0-9]//g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "[ip] get ip info failed, ${result}"
        exit 1 
    fi

    pid=$(get_pid ${result})
    if [ "{$pid}" == "" ];then
        perror "[ip] get pid failed"
    fi

    get_info $pid  $DHCPSERVICEINFO "dhclient"
}

function check_linux_dhcp_service(){
    r=$(cat $DHCPSERVICEINFO)
    if [ "${r}" == "" ];then
        perror "the thread of dhclient is not running"
        exit 1
    fi
    pinfo "check the thread of dhclient is running"
}

function get_linux_vm_dhcp_port(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-exec", "arguments": {"path": "/bin/sh",  "capture-output": true, "arg": ["-c", "netstat", "-natu"]}}'
    local sanity_result="{return:{pid:}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g' -e 's/[0-9]//g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "[ip] get ip info failed, ${result}"
        exit 1 
    fi

    pid=$(get_pid ${result})
    if [ "{$pid}" == "" ];then
        perror "[ip] get pid failed"
    fi

    local ipinfo=""

    get_info $pid  $DHCPPORTINFO ":68 "

}

function check_linux_dhcp_port(){
    r=$(cat $DHCPPORTINFO)
    if [ "${r}" == "" ];then
        perror "the dhcp thread do not listen to port 68"
        exit 1
    fi
    pinfo "dhcp service is listening to port 68"
}

function check_dhcp(){
    pinfo "[check_dhcp] $VMID"
    get_linux_vm_dhcp_service
    check_linux_dhcp_service
#    get_linux_vm_dhcp_port
#    check_linux_dhcp_port
}

function get_linux_vm_iptables(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-exec", "arguments": {"path": "/bin/sh",  "capture-output": true, "arg": ["-c", "iptables-save"]}}'
    local sanity_result="{return:{pid:}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g' -e 's/[0-9]//g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "[ip] get ip info failed, ${result}"
        exit 1 
    fi

    pid=$(get_pid ${result})
    if [ "{$pid}" == "" ];then
        perror "[ip] get pid failed"
    fi

    get_info $pid  $FWINFO
}

function check_fw(){
    pinfo "[check_iptables] $VMID"
    get_linux_vm_iptables
}

function get_linux_vm_arp(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-exec", "arguments": {"path": "/bin/sh",  "capture-output": true, "arg": ["-c", "arp", "-an"]}}'
    local sanity_result="{return:{pid:}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g' -e 's/[0-9]//g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "[ip] get ip info failed, ${result}"
        exit 1 
    fi

    pid=$(get_pid ${result})
    if [ "{$pid}" == "" ];then
        perror "[ip] get pid failed"
    fi

    get_info $pid  $FWINFO
}

function check_fw(){
    pinfo "[check_iptables] $VMID"
    get_linux_vm_iptables
}
function init(){
    mkdir -p $PATHINFO
    > $IPINFO
}

function linux() 
{
    pinfo "check linux $VMID start"
    init
    check_qga_status
    check_linux_ip
    check_linux_route
    check_dhcp
    check_fw
    get_linux_vm_arp
    pinfo "check linux $VMID end"

}


function get_win_vm_ip(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-exec", "arguments": {"path": "C:\\Windows\\system32\\cmd.exe", "capture-output": true, "arg": ["/C", "ipconfig /all > COM1"]}}'
    local sanity_result="{return:{pid:}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g' -e 's/[0-9]//g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "[ip] get ip info failed, ${result}"
        exit 1 
    fi

    pid=$(get_pid ${result})
    if [ "{$pid}" == "" ];then
        perror "[ip] get pid failed"
    fi

    get_win_info $IPINFO
}

function get_win_info(){
    sleep 3
    local savefile=$1
    local file="/export/jvirt/jcs-agent/instances/$VMID/console.log"
    iconv -f gbk -t utf-8 $file > $savefile
    > $file
    printinfo $savefile
}

function check_win_ip_address(){
    for net in `echo $NETS | sed -e "s/%/\ /g"`
    do
        pinfo "[check_ip_address] $net"
        local mac=$(echo $net|cut -d@ -f1)
        local ips=$(echo $net|cut -d@ -f2)
        local droute=$(echo $net|cut -d@ -f3)
        local rip=""

        local MAC=$(echo $mac| tr '[a-z]' '[A-Z]'|sed -e 's/:/-/g')  
        rmac=$(cat $IPINFO | grep -ai ${MAC}) 
        check_str_null_exit "It can not find mac $mac" ${rmac}
        pinfo "mac of $VMID is ok"

        defaultr=$(cat $IPINFO | grep -ai ${droute}) 
        check_str_null_exit "It can not find default route $defaultr" ${defaultr}
        pinfo "default route of $VMID is ok"
        
        for i in `echo $ips | sed -e "s/,/\ /g"`
        do
            rip=$(cat $IPINFO | grep -ai ${MAC} -A 10 | grep -ai ${i}) 
            check_str_null "It can not find ip $i in mac $mac" ${rip}
            pinfo "ip of $VMID is $i"
        done
    done
}
function check_win_ip(){
    get_win_vm_ip
    check_win_ip_address
}

function get_win_vm_route(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-exec", "arguments": {"path": "C:\\Windows\\system32\\cmd.exe", "capture-output": true, "arg": ["/C", "route print> COM1"]}}'
    local sanity_result="{return:{pid:}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g' -e 's/[0-9]//g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "[ip] get ip info failed, ${result}"
        exit 1 
    fi

    pid=$(get_pid ${result})
    if [ "{$pid}" == "" ];then
        perror "[ip] get pid failed"
    fi

    get_win_info $ROUTEINFO
}

function check_win_route(){
    get_win_vm_route
}

function get_win_vm_firewall(){
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-exec", "arguments": {"path": "C:\\Windows\\system32\\cmd.exe", "capture-output": true, "arg": ["/C", "netsh firewall dump|netsh advfirewall dump> COM1"]}}'
    local sanity_result="{return:{pid:}}"

    result=$(${VMCMD} ${cmd})
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g' -e 's/[0-9]//g')
    if [ ${sanity_result} != ${real_result} ];then
        perror "[ip] get ip info failed, ${result}"
        exit 1 
    fi

    pid=$(get_pid ${result})
    if [ "{$pid}" == "" ];then
        perror "[ip] get pid failed"
    fi

    get_win_info $FWINFO
}

function check_win_firewall(){
    get_win_vm_firewall
}

function windows() 
{
    pinfo "check windows $VMID start"
    init
    check_qga_status
    check_win_firewall
    check_win_ip
    check_win_route
    pinfo "check windows $VMID end"

}


function run(){
    islinux=$(virsh dumpxml $VMID | grep -i linux | grep os_type)
    if [ "${islinux}" != "" ];then
        linux $*
    else
        windows $*
    fi
}

function main(){
    run $*
}

main $*

