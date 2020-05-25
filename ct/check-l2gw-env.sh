#!/bin/bash

#VIP="10.114.209.2"
#VLANNIC="ens6f1"
#VLANNIC="bond1"
#VXLANNIC="eno1"
#NEIGHBOR="10.114.197.254"
#COMPUTEHOSTS="10.114.196.150,10.114.196.151,10.114.196.234"

# 先定义一些颜色:
red='\e[0;41m' # 红色
RED='\e[1;31m'
green='\e[0;32m' # 绿色
GREEN='\e[1;32m'
yellow='\e[5;43m' # 黄色
YELLOW='\e[1;33m'
blue='\e[0;34m' # 蓝色
BLUE='\e[1;34m'
purple='\e[0;35m' # 紫色
PURPLE='\e[1;35m'
cyan='\e[4;36m' # 蓝绿色
CYAN='\e[1;36m'
WHITE='\e[1;37m' # 白色
NC='\e[0m' # 没有颜色

#echo -e "${red}显示红色0 ${NC}"
#echo -e "${RED}显示红色1 ${NC}"
#echo -e "${green}显示绿色0 ${NC}"
#echo -e "${GREEN}显示绿色1 ${NC}"
#echo -e "${yellow}显示黄色0 ${NC}"
#echo -e "${YELLOW}显示黄色1 ${NC}"
#echo -e "${cyan}显示蓝绿色0 ${NC}"
#echo -e "${CYAN}显示蓝绿色1 ${NC}"

ERROR="${red}NOK${NC}"
OK="${GREEN}OK${NC}"

help_info(){
 echo "Usage:"
 echo -e "\tsh $0 -vip 10.114.209.2 -vlanic ens6f1 -vxlanic eno1 -neighbor 10.114.197.254  -computehosts 10.114.196.150,10.114.196.151,10.114.196.234"
 echo ""
 echo -e "\tvip              ospf distribute vip"
 echo -e "\tvlanic           vlan nic name"
 echo -e "\tvxlanic          vxlan nic name"
 echo -e "\tneighbor         switch neighbor ip address"
 echo -e "\tcomputehosts     the ip address of compute nodes, split ",""
 echo ""
 exit 1
}

while [ -n "$1" ]
do
    case "$1" in
        -vip)
            VIP=$2
            shift
            ;;
        -computehosts)
            COMPUTEHOSTS=$2
            shift
            ;;
        -neighbor)
            NEIGHBOR=$2
            shift
            ;;
        -vxlanic)
            VXLANNIC=$2
            shift
            ;;
        -vlanic)
            VLANNIC=$2
            shift
            ;;
           *)
           help_info
          ;;
    esac
    shift
done

function log(){
    echo -e "$@"
}

function log_info (){
    echo -e "${GREEN} $@ ${NC}"
}

function log_error (){
    echo -e "${RED}Error: $@ ${NC}"
}


function check_file(){
    file=$1
    if [ ! -f $file ];then
        log_error "$file is not exist"
    fi
}

function ping_test(){
    local ret=${OK}
    host=$1
    r=$(ping $host -c 3 -i 0.1 -w 2| grep "100% packet loss")
    if [ "${r}" != "" ];then
        log_error "host $host ping Fail" && ret=${ERROR}
    fi
    log "check the ping of $host: ${ret}"
}

function check_service(){
    local ret=${OK}
    #r=$(systemctl status $1 | grep "active (running)")
    r=$(systemctl status $1 | grep -w "active")
    if [ "${r}" == "" ];then
        log_error "service $1 is down" && ret=${ERROR}
    fi
    log "check the state of service $1: ${ret}"
}

function check_quagga(){
    local ret=${OK}
    file="/etc/quagga/ospfd.conf"
    check_file $file
    r=$(sudo ls -l $file | grep "quagga quagga" | awk '{print $2}')
    if test -z ${r}
    then
        log_error "the limits of $file Error" && ret=${ERROR}
    fi
    log "check the limits of $file: ${ret}"

    check_service ospfd.service

    local ret=${OK}
    file="/etc/quagga/zebra.conf"
    check_file $file
    r=$(sudo ls -l $file | grep "quagga quagga" | awk '{print $2}')
    if test -z ${r}
    then
        log_error "the limits of $file Error" && ret=${ERROR}
    fi
    log "check the limits of $file: ${ret}"

    local ret=${OK}
    check_service zebra.service

    local ret=${OK}
    r=$(vtysh -d ospfd -c "show ip ospf neighbor" |  grep -i "full" | grep ${NEIGHBOR})
    if [ "${r}" = "" ];then
        log_error "the ospf neighbor of switch do not estableshed" && ret=${ERROR}
    fi
    log "check the neighbor ${NEIGHBOR} of switch: ${ret}"

    local ret=${OK}
    r=$(vtysh -d ospfd -c "show ip ospf route" |  grep ${VIP})
    if [ "${r}" = "" ];then
        log_error "vip $VIP not is distributed by ospf" && ret=${ERROR}
    fi

    local ret=${OK}
    r=$(vtysh -d zebra -c 'show ip route ospf' |  grep ${VIP})
    if [ "${r}" = "" ];then
        log_error "vip $VIP not is distributed by ospf" && ret=${ERROR}
    fi
    log "check the distribution route of ${VIP}: ${ret}"
}


function check_compute_host(){
    local ret=${OK}
    hosts=${COMPUTEHOSTS}
    IFS=","
    for host in ${hosts}
    do
        ping_test $host
        r=$(ssh -o StrictHostKeyChecking=no  -v -p10000 $host 2>&1 | grep established)
        if [ "${r}" = "" ];then
            log_error "the host can not connect $host:10000" && ret=${ERROR}
        fi
        log "check the network reachble for $host 10000: ${ret}"
    done
}

function check_host_config(){
    local ret=${OK}
    file="/proc/sys/net/ipv4/conf/$VLANNIC/rp_filter"
    check_file $file
    r=$(cat $file)
    if [ "${r}" != "0" ];then
        log_error "rp_filter config of $VLANNIC Error" && ret=${ERROR}
    fi
    log "check the  rp_filter of $VLANNIC : ${ret}"

    local ret=${OK}
    file="/proc/sys/net/ipv4/conf/$VXLANNIC/rp_filter"
    check_file $file
    r=$(cat $file)
    if [ "${r}" != "0" ];then
        log_error "rp_filter config of $VXLANNIC Error" && ret=${ERROR}
    fi
    log "check the  rp_filter of $VXLANNIC : ${ret}"

    local ret=${OK}
    file="/proc/sys/net/ipv4/conf/all/rp_filter"
    check_file $file
    r=$(cat $file)
    if [ "${r}" != "0" ];then
        log_error "rp_filter config of all nic Error" && ret=${ERROR}
    fi
    log "check the  rp_filter of all nic : ${ret}"
}

function check_vip(){
    local ret=${OK}
    r=$(ip addr show dev lo | grep $VIP)
    if [ "${r}" = "" ];then
        log_error "the addr of vip $VIP not exist in lo" && ret=${ERROR}
    fi
    log "check exist of VIP $VIP in lo : ${ret}"

}

function check_nic_default_state(){
    local ret=${OK}
    r=$(cat /etc/sysconfig/network-scripts/ifcfg-$VLANNIC | grep "onboot=no")
    if [ "${r}" != "" ];then
        log_error "the init state of vlan nic $VLANNIC onboot=yes" && ret=${ERROR}
    fi
    log "check the init state of vlan nic $VLANNIC : ${ret}"

}

function check_nic_current_state(){
    local ret=${OK}
    r=$(sudo ip link show dev $VLANNIC | grep "state UP")
    if [ "${r}" = "" ];then
        log_error "the admin state of vlan nic $VLANNIC Down" && ret=${ERROR}
    fi
    log "check the admin state of vlan nic $VLANNIC : ${ret}"

    local ret=${OK}
    r=$(sudo ethtool $VLANNIC | grep "Link detected: yes")
    if [ "${r}" = "" ];then
        log_error "the link state of vlan nic $VLANNIC Link detected: no" && ret=${ERROR}
    fi
    log "check the link state of vlan nic $VLANNIC : ${ret}"

    local ret=${OK}
    r=$(sudo ip link show dev $VXLANNIC | grep "state UP")
    if [ "${r}" = "" ];then
        log_error "the admin state of vxlan nic $VXLANNIC Down" && ret=${ERROR}
    fi
    log "check the admin state of vxlan nic $VXLANNIC : ${ret}"

    local ret=${OK}
    r=$(sudo ethtool $VXLANNIC | grep "Link detected: yes")
    if [ "${r}" = "" ];then
        log_error "the link state of vxlan nic $VXLANNIC Link detected: no" && ret=${ERROR}
    fi
    log "check the link state of vxlan nic $VXLANNIC : ${ret}"

}

function check_nic_default_state(){
    local ret=${OK}
    r=$(cat /etc/sysconfig/network-scripts/ifcfg-$VLANNIC | grep "onboot=no")
    if [ "${r}" != "" ];then
        log_error "the init state of vlan nic $VLANNIC onboot=yes" && ret=${ERROR}
    fi
    log "check the init state of vlan nic $VLANNIC : ${ret}"

}

function check_ovs(){
    local ret=${OK}
    file="/etc/openvswitch/vtep.db"
    check_file $file
    r=$(sudo ls -l $file | grep "openvswitch openvswitch" | awk '{print $2}')
    if test -z ${r}
    then
        log_error "the limits of $file Error" && ret=${ERROR}
    fi
    log "check the limits of $file: ${ret}"

    local ret=${OK}
    file="/etc/openvswitch/conf.db"
    check_file $file
    r=$(sudo ls -l $file | grep "openvswitch openvswitch" | awk '{print $2}')
    if test -z ${r}
    then
        log_error "the limits of $file Error" && ret=${ERROR}
    fi
    log "check the limits of $file: ${ret}"

    check_service openvswitch.service

    local ret=${OK}
    r=$(ovs-vsctl get-manager | grep "ptcp:6632")
    if [ "${r}" = "" ];then
        log_error "the configuration of manager port  not 6632" && ret=${ERROR}
    fi
    log "check the configuration of  port 6632: ${ret}"

    local ret=${OK}
    r=$(netstat -nat | grep 6632 | grep LISTEN| head -n 1)
    if [ "${r}" = "" ];then
        log_error "the LISTEN of state for port 6632"  && ret=${ERROR}
    fi
    log "check the LISTEN of state for port 6632: ${ret}"

    local ret=${OK}
    r=$(netstat -nat | grep 6632 | grep ESTABLISHED | head -n 1)
    if [ "${r}" = "" ];then
        log_error "the ESTABLISHED of state for port 6632"  && ret=${ERROR}
    fi
    log "check the ESTABLISHED of state for port 6632: ${ret}"
}

function check_vtep(){
    local ret=${OK}
    bridge_name=$(echo br-$(hostname | awk -F"-" '{print $NF}'|awk -F"e" '{print $(NF-1)"."$NF}'))
    r=$(vtep-ctl list-ps | grep "$bridge_name")
    if [ "${r}" = "" ];then
        log_error "the bridge of vtep not $bridge_name" && ret=${ERROR}
    fi
    log "check the bridge name $bridge_name of vtep : ${ret}"

    local ret=${OK}
    r=$(ovs-vsctl show | grep "$bridge_name")
    if [ "${r}" = "" ];then
        log_error "the bridge $bridge_name of ovs not exist" && ret=${ERROR}
    fi
    log "check the bridge $bridge_name in ovs : ${ret}"

    local ret=${OK}
    r=$(vtep-ctl list Physical_Switch | grep ${VIP})
    if [ "${r}" = "" ];then
        log_error "the tunnel ip $VIP not exist in Physical_Switch" && ret=${ERROR}
    fi
    log "check the tunnel ip $VIP of Physical_Switch : ${ret}"

    local ret=${OK}
    r=$(vtep-ctl list-ports $bridge_name | grep "$VLANNIC")
    if [ "${r}" = "" ];then
        log_error "the port $VLANNIC is not exist in $bridge_name for vtepdb" && ret=${ERROR}
    fi
    log "check the port $VLANNIC config in vtep bridge: ${ret}"

    local ret=${OK}
    r=$(ovs-vsctl list-ports $bridge_name | grep "$VLANNIC")
    if [ "${r}" = "" ];then
        log_error "the port $VLANNIC is not exist in $bridge_name for ovsdb" && ret=${ERROR}
    fi
    log "check the port $VLANNIC config in ovs bridge: ${ret}"

    local ret=${OK}
    file="/etc/openvswitch/vtep.conf"
    check_file $file
    r=$(sudo ls -l $file | grep "openvswitch openvswitch" | awk '{print $2}')
    if test -z ${r}
    then
        log_error "the limits of $file not openvswitch:openvswitch" && ret=${ERROR}
    fi
    log "check the limits of $file: ${ret}"

    check_service vtep.service
}

function check_ovs_flow(){
    local ret=${OK}
    bridge_name=$(echo br-$(hostname | awk -F"-" '{print $NF}'|awk -F"e" '{print $(NF-1)"."$NF}'))
    count=$(ovs-ofctl dump-flows $bridge_name -O openflow13 |wc -l)
    if [ ${count} -lt 20 ];then
        log_error "flow count of bridge $bridge_name is $count" && ret=${ERROR}
    fi
    log "check the flow count of bridge $bridge_name is $count: ${ret}"
}

function check_l2gw_agent(){
    check_service neutron-l2gw-agent

    file="/etc/neutron/l2gateway_agent.ini"
    check_file $file

    local ret=${OK}
    zone=$(cat $file | grep availability_zone | cut -d"=" -f2 | sed -e "s/\ //g")
    if [ "${zone}" = "" ];then
        log_error "the availabilitty_zone option of $file not exist" && ret=${ERROR}
    fi
    log "check the availabilitty_zone $zone of $file: ${ret}"

    ovsdb_hosts=$(cat /etc/neutron/l2gateway_agent.ini | grep ovsdb_hosts | grep ${zone}| cut -d"=" -f2 | sed -e "s/'//g" | sed -e 's/\ //g')
    local ret=${OK}
    if [ "${ovsdb_hosts}" = "" ];then
        log_error "the device of zone $zone not exist" && ret=${ERROR}
    fi
    echo ${ovsdb_hosts} |sed -e "s/${zone}@//g" | sed -e "s/,/\ /g"| awk '{for(i=1;i<=NF;i++) print $i}' > /tmp/ovsdb_hosts
    while read host_port
    do
        host=$(echo ${host_port} | cut -d":" -f2)
        port=$(echo ${host_port} | cut -d":" -f3)
        local ret=${OK}
        ssh -o StrictHostKeyChecking=no $host -p $port > /tmp/l2gw 2>&1
        r=$(cat /tmp/l2gw| grep ssh_exchange_identification)
        if [ "${r}"  = "" ];then
            log_error "the host can not connect $host:$port" && ret=${ERROR}
        fi
        log "check the service reachble for ${host_port}: ${ret}"
    done</tmp/ovsdb_hosts

}

function check_vtep_monitor(){
    local ret=${OK}
    r=$(sudo crontab -l | grep -e ${VIP}|grep   -e ${VLANNIC}|grep -e ${NEIGHBOR})
    if [ "${r}" = "" ];then
        log_error "vtep monitor configurage error" && ret=${ERROR}
    fi
    log "check the vtep monitor: ${ret}"

    check_service crond
}

function check_input(){
    if [ "${VIP}" == "" -o  "${VLANNIC}" == "" -o "${VXLANNIC}" == "" -o  "${NEIGHBOR}" == "" ];then
        help_info
    fi
}

function main(){
    #input param check
    check_input

    #item check
    check_quagga
    check_compute_host
    check_host_config
    check_vip
    check_nic_default_state
    check_nic_current_state
    check_ovs
    check_vtep
    check_l2gw_agent
    check_ovs_flow
    check_vtep_monitor
}

main


