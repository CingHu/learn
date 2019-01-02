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
    echo "vxlan.host  IP      src or dst ip of the overlay packet"
    echo "vxlan.port  IP      src or dst port of the overlay packet"
    echo "vxlan.tcp           capture the vxlan packets whose overlay protocol is tcp"
    echo "vxlan.udp           capture the vxlan packets whose overlay protocol is udp"
    echo "vxlan.icmp          capture the vxlan packets whose overlay protocol is icmp"
    echo "vxlan.vni   VNI     the vni of the overlay"
    echo ""
    echo ""
    echo " example: ./vxdump vxlan"
    echo " example: ./vxdump -i eth1 host 192.168.10.1"
    echo " example: ./vxdump -i eth1 vxlan and vxlan.vni 100"
    echo " example: ./vxdump -i eth1 vxlan and vxlan.vni 100 - nevvv"
    echo " example: ./vxdump -i eth1 -nevvv vxlan and vxlan.vni 100 and vxlan.tcp"
    echo " example: ./vxdump -i eth1 -nevvv src host 10.100.2.1 and vxlan.host 192.168.10.2 and vxlan.port 100 and vxlan.vni 368"
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
        if [[ ${ARGS_ARRAY[$j]} == "vxlan" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.tcp" ]]  || [[ ${ARGS_ARRAY[$j]} == "vxlan.udp" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.icmp" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.host" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.port" ]] || [[ ${ARGS_ARRAY[$j]} == "vxlan.vni" ]]; then
#            echo ${ARGS_ARRAY[$j]} ${ARGS_ARRAY[`expr $j + 1`]}
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

function replace_host() {
    #过滤overlay  host
    local host=$1
    if [ $host ]; then
        A=$(echo $host | cut -d '.' -f1)
        B=$(echo $host | cut -d '.' -f2)
        C=$(echo $host | cut -d '.' -f3)
        D=$(echo $host | cut -d '.' -f4)
        _host=$(($A<<24|$B<<16|$C<<8|$D))
        _host=$(echo "obase=16;$_host"|bc)
        if [[ $_host != 0  ]]; then
            local host_expr=" udp[42:4] = 0x"${_host}" or udp[46:4] = 0x"${_host}
            ARGS=${ARGS/vxlan.host*$host/$host_expr}
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

function replace_port() {
    local port=$1
    if [ $port ]; then
        local np=" udp[50:2] = "${port}" or udp[52:2] = "${port}
        ARGS=${ARGS/vxlan.port*$port/$np}
    fi
}


function resolve_one() {
    if [ $1 ]; then
        local param=$1
        local value=$2
#        echo $param $value
        if [ $param = "vxlan.host" ] && [ $value ]; then
            replace_host $value
        elif [ $param = "vxlan.port" ] && [ $value ]; then
            replace_port $value
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
    ARGS="tcpdump ${ARGS}"
    echo "exec $ARGS"
    $ARGS
}

main $*