#!/bin/bash

#help info
function help() {
    echo "it\`s a tool used to filter the overlay packets of vxlan based on tcpdump, "
    echo "on the other side, it can be used as a origin tcpdump tool"
    echo "Usage: tcpdump [-aAbdDefhHIJKlLnNOpqRStuUvxX] [ -B size ] [ -c count ]"
	echo "	[ -C file_size ] [ -E algo:secret ] [ -F file ] [ -G seconds ]"
	echo "	[ -i interface ] [ -j tstamptype ] [ -M secret ]"
	echo "	[ -P in|out|inout ]"
	echo "	[ -r file ] [ -s snaplen ] [ -T type ] [ -V file ] [ -w file ]"
	echo "	[ -W filecount ] [ -y datalinktype ] [ -z command ]"
	echo "	[ -Z user ] [ expression ]"
    echo ""
    echo "Expression:"
    echo "vxlan.smac  MAC     src mac of the overlay packet"
    echo "vxlan.dmac  MAC     dst mac of the overlay packet"
    echo "vxlan.sip   IP      src or ip of the overlay packet"
    echo "vxlan.dip   IP      dst or ip of the overlay packet"
    echo "vxlan.sport  IP     src port of the overlay packet"
    echo "vxlan.dport  IP     dst port of the overlay packet"
    echo "vxlan.ping.request  ping request of the overlay packet"
    echo "vxlan.ping.reply    ping reply of the overlay packet"
    echo "vxlan.dport  IP     dst port of the overlay packet"	
    echo "vxlan.arp           capture the vxlan packets whose overlay protocol is arp"
    echo "vxlan.arp.request   capture the vxlan packets whose overlay protocol is arp request"
    echo "vxlan.arp.reply     capture the vxlan packets whose overlay protocol is arp reply"
    echo "vxlan.tcp           capture the vxlan packets whose overlay protocol is tcp"
    echo "vxlan.udp           capture the vxlan packets whose overlay protocol is udp"
    echo "vxlan.icmp          capture the vxlan packets whose overlay protocol is icmp"
    echo "vxlan.vni   VNI     the vni of the overlay"
    echo ""
    echo ""
    echo " example: ./$0 vxlan"
    echo " example: ./$0 vxlan.arp"
    echo " example: ./$0 vxlan.arp.request"
    echo " example: ./$0 -i bond1 sip 192.168.10.1"
    echo " example: ./$0 -i bond1 smac fa:16:3e:2d:1a:f3"
    echo " example: ./$0 -i bond1 vxlan and vxlan.vni 100"
    echo " example: ./$0 -i bond1 vxlan and vxlan.vni 100 and vxlan.ping.request"
    echo " example: ./$0 -i bond1 vxlan and vxlan.vni 100 -nevvv"
    echo " example: ./$0 -i bond1 -nevvv vxlan and vxlan.vni 100 and vxlan.tcp"
    echo " example: ./$0 -i bond1 -nevvv vxlan and vxlan.vni 100 and vxlan.tcp and vxlan.sport 80"
    echo " example: ./$0 -i bond1 -nevvv src host 10.100.2.1 and vxlan.sip 192.168.10.2 and vxlan.sport 100 and vxlan.vni 368"
    echo ""
    exit 1
}

ARGS=$*
ARGS_NUM=$#
ARGS_ARRAY=$@

function handle_params() {
    ARGS=${ARGS}" "
    local j=0
    while [ $j -lt `expr $ARGS_NUM + 1` ]
    do
        if [[ ${ARGS_ARRAY[$j]} == "vxlan" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.tcp" ]]  || [[ ${ARGS_ARRAY[$j]} == "vxlan.udp" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.icmp" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.smac" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.dmac" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.sip" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.dip" ]]  || [[ ${ARGS_ARRAY[$j]} == "vxlan.sport" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.dport" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.vni" ]]|| [[ ${ARGS_ARRAY[$j]} == "vxlan.ping.request" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.ping.reply" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.arp" ]] ||  [[ ${ARGS_ARRAY[$j]} == "vxlan.arp.request" ]] ||  [[ ${ARGS_ARRAY[$j]} == "vxlan.arp.reply" ]] ; then
            #echo ${ARGS_ARRAY[$j]} ${ARGS_ARRAY[`expr $j + 1`]}
            resolve_one ${ARGS_ARRAY[$j]} ${ARGS_ARRAY[`expr $j + 1`]}
        fi
        j=`expr $j + 1`
    done
}

function replace_vxlan() {
    local vxlan="vxlan "
    local str=" udp and port 4789 "
    ARGS=${ARGS/$vxlan/$str}
    return
}

function replace_vni() {
    local vni=$1
    local cmd=" udp[11:4] = "${vni}
    if [ $vni ]; then
        ARGS=${ARGS/vxlan.vni*$vni/$cmd}
    fi
    return
}

function replace_arp() {
    local proto=$1
    if [ $proto ]; then
        if [ $proto = "vxlan.arp" ]; then
            local value=" udp[28:2]=0x0806"
            ARGS=${ARGS/$proto/$value}
        elif [ $proto = "vxlan.arp.request" ]; then
            local value=" udp[28:2]=0x0806 and udp[36:2]=0x0001 "
            ARGS=${ARGS/$proto/$value}
        elif [ $proto = "vxlan.arp.reply" ]; then
            local value=" udp[28:2]=0x0806 and udp[36:2]=0x0002 "
            ARGS=${ARGS/$proto/$value}
        fi
    fi
}

function replace_smac() {
    local mac=$1
    if [ $mac ]; then
	    local formatmac=$(echo $mac|awk -F":" '{print $3$4$5$6}')
        local np=" udp[24:4] = 0x"${formatmac}
        ARGS=${ARGS/vxlan.smac*${mac}/$np}
    fi
}

function replace_dmac() {
    local mac=$1
    if [ $mac ]; then
	    local formatmac=$(echo $mac|awk -F":" '{print $3$4$5$6}')
        local np=" udp[18:4] = 0x"${formatmac}
        ARGS=${ARGS/vxlan.dmac*$mac/$np}
    fi
}


function replace_sip() {
    #过滤overlay  sip
    local host=$1
    if [ $host ]; then
        A=$(echo $host | cut -d '.' -f1)
        B=$(echo $host | cut -d '.' -f2)
        C=$(echo $host | cut -d '.' -f3)
        D=$(echo $host | cut -d '.' -f4)
        _host=$(($A<<24|$B<<16|$C<<8|$D))
        _host=$(echo "obase=16;$_host"|bc)
        if [[ $_host != 0  ]]; then
            local host_expr=" udp[42:4] = 0x"${_host}
            ARGS=${ARGS/vxlan.sip*$host/$host_expr}
        fi
    fi
    return
}

function replace_dip() {
    #过滤overlay  dip
    local host=$1
    if [ $host ]; then
        A=$(echo $host | cut -d '.' -f1)
        B=$(echo $host | cut -d '.' -f2)
        C=$(echo $host | cut -d '.' -f3)
        D=$(echo $host | cut -d '.' -f4)
        _host=$(($A<<24|$B<<16|$C<<8|$D))
        _host=$(echo "obase=16;$_host"|bc)
        if [[ $_host != 0  ]]; then
            local host_expr=" udp[46:4] = 0x"${_host}
            ARGS=${ARGS/vxlan.dip*$host/$host_expr}
        fi
    fi
    return
}


function replace_pro() {
    local proto=$1
    if [ $proto ]; then
        if [ $proto = "vxlan.tcp" ]; then
            local vpn=" udp[39] = 0x06"
            ARGS=${ARGS/$proto/$vpn}
        elif [ $proto = "vxlan.udp" ]; then
            local vpn=" udp[39] = 0x11"
            ARGS=${ARGS/$proto/$vpn}
        elif [ $proto = "vxlan.icmp" ]; then
            local vpn=" udp[39] = 0x01"
            ARGS=${ARGS/$proto/$vpn}
        fi
    fi
    return
}

function replace_sport() {
    local port=$1
    if [ $port ]; then
        local np=" udp[50:2] = "${port}
        ARGS=${ARGS/vxlan.sport*$port/$np}
    fi
}

function replace_dport() {
    local port=$1
    if [ $port ]; then
        local np=" udp[52:2] = "${port}
        ARGS=${ARGS/vxlan.dport*$port/$np}
    fi
}

function replace_ping() {
    local ping=$1
    if [ $ping ]; then
        if [ $ping = "vxlan.ping.request" ]; then
            local cmd=" udp[50:1] = 0x08"
            ARGS=${ARGS/$ping/$cmd}
        elif [ $ping = "vxlan.ping.reply" ]; then
            local cmd=" udp[50:1] = 0x0"
            ARGS=${ARGS/$ping/$cmd}
        fi
    fi
    return
}


function resolve_one() {
    if [ $1 ]; then
        local param=$1
        local value=$2
#        echo $param $value
        if [ $param = "vxlan.smac" ] && [ $value ]; then
            replace_smac $value
        elif [ $param = "vxlan.dmac" ] && [ $value ]; then
            replace_dmac $value			
        elif [ $param = "vxlan.sip" ] && [ $value ]; then
            replace_sip $value
        elif [ $param = "vxlan.dip" ] && [ $value ]; then
            replace_dip $value
        elif [ $param = "vxlan.sport" ] && [ $value ]; then
            replace_sport $value
        elif [ $param = "vxlan.dport" ] && [ $value ]; then
            replace_dport $value	
        elif [[ $param == "vxlan.ping.request" ]] || [[ $param == "vxlan.ping.reply" ]]; then
            replace_ping $param
        elif [[ $param == "vxlan.arp" ]] || [[ $param == "vxlan.arp.request" ]] || [[ $param == "vxlan.arp.reply" ]]; then
            replace_arp $param
        elif [ $param = "vxlan.vni" ] && [ $value ]; then
            replace_vni $value
        elif [ $param = "vxlan" ]; then
            replace_vxlan
        elif [[ $param == "vxlan.tcp" ]] || [[ $param == "vxlan.udp" ]] || [[ $param == "vxlan.icmp" ]]; then
            replace_pro $param
        fi
    fi
    return
}

for arg in "$@"
do
    if [ $arg = "-h" -o $arg = "--help" ]; then
        help
        exit
    fi
    ARGS_ARRAY[$i]=$arg
    i=`expr $i + 1`
done

function main() {
    ## 参数个数少于一个  报错
    if [ $# -lt 1 ];then
        help
        exit
    fi
    handle_params
    ARGS="tcpdump -ennvv ${ARGS}"
    echo "exec $ARGS"
    $ARGS
}

main $*


