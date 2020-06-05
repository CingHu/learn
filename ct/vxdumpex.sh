#!/bin/bash

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
    echo "vxlan.smac  MAC              src mac of the overlay packet, ipv4 and ipv6"
    echo "vxlan.dmac  MAC              dst mac of the overlay packet, ipv4 and ipv6"
    echo "vxlan.sip   IP               src or ip of the overlay packet, ipv4 and ipv6"
    echo "vxlan.dip   IP               dst or ip of the overlay packet, ipv4 and ipv6"
    echo "vxlan.sport  PORT            src port of the overlay packet, ipv4 and ipv6"
    echo "vxlan.dport  PORT            dst port of the overlay packet, ipv4 and ipv6"
    echo "vxlan.ping.request           ping request of the overlay packet, ipv4 and ipv6"
    echo "vxlan.ping.reply             ping reply of the overlay packet, ipv4 and ipv6"
    echo "vxlan.ping                   ping of the overlay packet, ipv4 and ipv6"
    echo "vxlan.vni   VNI              the vni of the overlay, ipv4 and ipv6"
    echo "vxlan.arp                    capture the vxlan packets whose overlay protocol is arp, only ipv4"
    echo "vxlan.arp.request            capture the vxlan packets whose overlay protocol is arp request, only ipv4"
    echo "vxlan.arp.reply              capture the vxlan packets whose overlay protocol is arp reply, only ipv4"
    echo "vxlan.tcp                    capture the vxlan packets whose overlay protocol is tcp, ipv4 and ipv6"
    echo "vxlan.udp                    capture the vxlan packets whose overlay protocol is udp, ipv4 and ipv6"
    echo "vxlan.icmp                   capture the vxlan packets whose overlay protocol is icmp, only ipv4"
    echo "vxlan.ipv6                   capture the vxlan packets whose overlay protocol is ipv6, only ipv6"
    echo "vxlan.icmp6                  capture the vxlan packets whose overlay protocol is icmp6, only ipv6"
    echo "vxlan.nd                     capture the vxlan packets whose overlay protocol is nd, only ipv6"
    echo "vxlan.ns                     capture the vxlan packets whose overlay protocol is ns, only ipv6"
    echo "vxlan.na                     capture the vxlan packets whose overlay protocol is na, only ipv6"
    echo "vxlan.redict                 capture the vxlan packets whose overlay protocol is redict, only ipv6"
    echo "vxlan.rs                     capture the vxlan packets whose overlay protocol is rs, only ipv6"
    echo "vxlan.ra                     capture the vxlan packets whose overlay protocol is ra, only ipv6"
    echo ""
    echo "Example:"
    echo " ipv4 example: ./$0 -i bond1 vxlan"
    echo " ipv4 example: ./$0 -i bond1 vxlan.arp"
    echo " ipv4 example: ./$0 -i bond1 vxlan.arp.request"
    echo " ipv4 example: ./$0 -i bond1 vxlan.sip 192.168.10.1"
    echo " ipv4 example: ./$0 -i bond1 vxlan.smac fa:16:3e:2d:1a:f3"
    echo " ipv4 example: ./$0 -i bond1 vxlan and vxlan.vni 100"
    echo " ipv4 example: ./$0 -i bond1 vxlan and vxlan.vni 100 and vxlan.ping"
    echo " ipv4 example: ./$0 -i bond1 vxlan and vxlan.vni 100 -nevvv"
    echo " ipv4 example: ./$0 -i bond1 -nevvv vxlan and vxlan.vni 100 and vxlan.tcp"
    echo " ipv4 example: ./$0 -i bond1 -nevvv vxlan and vxlan.vni 100 and vxlan.tcp and vxlan.sport 80"
    echo " ipv4 example: ./$0 -i bond1 -nevvv src host 10.100.2.1 and vxlan.sip 192.168.10.2 and vxlan.sport 100 and vxlan.vni 368"
    echo "========="
    echo " ipv6 example: ./$0 -i bond1 vxlan.ipv6"
    echo " ipv6 example: ./$0 -i bond1 vxlan.icmp6"
    echo " ipv6 example: ./$0 -i bond1 vxlan.smac fa:16:3e:2d:1a:f3"
    echo " ipv6 example: ./$0 -i bond1 vxlan.ipv6 and vxlan.ping"
    echo " ipv6 example: ./$0 -i bond1 vxlan.nd"
    echo " ipv6 example: ./$0 -i bond1 vxlan.ns"
    echo " ipv6 example: ./$0 -i bond1 vxlan.dport  22"
    echo " ipv6 example: ./$0 -i bond1 vxlan.sip 240e:980:2f00:48::7"
    echo ""
    echo -e "${YELLOW} Warning: Do not support to capture vlan packet!!!${NC}"
    echo ""
    exit 1
}

ARGS=$*
ARGS_NUM=$#
ARGS_ARRAY=$@
IS_IPV6=false

function handle_params() {
    ARGS=${ARGS}" "
    local j=0
    while [ $j -lt `expr $ARGS_NUM + 1` ]
    do
        if [[ ${ARGS_ARRAY[$j]} == "vxlan.ipv6" ]];then
            IS_IPV6=true
        fi
        if [[ ${ARGS_ARRAY[$j]} == "vxlan" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.tcp" ]]  ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.udp" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.icmp" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.smac" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.dmac" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.sip" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.dip" ]]  ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.sport" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.dport" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.vni" ]]||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.ping.request" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.ping.reply" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.ping" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.arp" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.arp.request" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.arp.reply" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.icmp6" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.nd" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.ns" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.na" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.redict" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.rs" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.ra" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.icmp6.ping.request" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.icmp6.ping.reply" ]] ||\
           [[ ${ARGS_ARRAY[$j]} == "vxlan.ipv6" ]];\
           then
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
        ARGS=${ARGS/vxlan.vni[[:space:]]$vni/$cmd}
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
        ARGS=${ARGS/vxlan.smac[[:space:]]${mac}/$np}
    fi
}

function replace_dmac() {
    local mac=$1
    if [ $mac ]; then
	    local formatmac=$(echo $mac|awk -F":" '{print $3$4$5$6}')
        local np=" udp[18:4] = 0x"${formatmac}
        ARGS=${ARGS/vxlan.dmac[[:space:]]$mac/$np}
    fi
}


function replace_sip() {
    #过滤overlay  sip
    local host=$1
    if [ $host ]; then
        if [ "$IS_IPV6" = false ]; then
            A=$(echo $host | cut -d '.' -f1)
            B=$(echo $host | cut -d '.' -f2)
            C=$(echo $host | cut -d '.' -f3)
            D=$(echo $host | cut -d '.' -f4)
            _host=$(($A<<24|$B<<16|$C<<8|$D))
            _host=$(echo "obase=16;$_host"|bc)
            if [[ $_host != 0  ]]; then
                local host_expr=" udp[42:4] = 0x"${_host}
                ARGS=${ARGS/vxlan.sip[[:space:]]$host/$host_expr}
            fi
        else
            complete_ipv6=$(echo $host | awk  -f complete_ipv6.awk)
            local host1=$(echo "$complete_ipv6" | awk -F":" '{print $1$2}')
            local host2=$(echo "$complete_ipv6" | awk -F":" '{print $3$4}')
            local host3=$(echo "$complete_ipv6" | awk -F":" '{print $5$6}')
            local host4=$(echo "$complete_ipv6" | awk -F":" '{print $7$8}')
            local host_expr=" udp[38:4] = 0x${host1} and udp[42:4] = 0x${host2} and udp[46:4] = 0x${host3} and  udp[50:4] = 0x${host4}"
            ARGS=${ARGS/vxlan.sip[[:space:]]$host/$host_expr}
        fi
    fi
    return
}

function replace_dip() {
    #过滤overlay  dip
    local host=$1
    if [ $host ]; then
        if [ "$IS_IPV6" = false ]; then
            A=$(echo $host | cut -d '.' -f1)
            B=$(echo $host | cut -d '.' -f2)
            C=$(echo $host | cut -d '.' -f3)
            D=$(echo $host | cut -d '.' -f4)
            _host=$(($A<<24|$B<<16|$C<<8|$D))
            _host=$(echo "obase=16;$_host"|bc)
            if [[ $_host != 0  ]]; then
                local host_expr=" udp[46:4] = 0x"${_host}
                ARGS=${ARGS/vxlan.dip[[:space:]]$host/$host_expr}
            fi
        else
            complete_ipv6=$(echo $host | awk  -f complete_ipv6.awk)
            local host1=$(echo "$complete_ipv6" | awk -F":" '{print $1$2}')
            local host2=$(echo "$complete_ipv6" | awk -F":" '{print $3$4}')
            local host3=$(echo "$complete_ipv6" | awk -F":" '{print $5$6}')
            local host4=$(echo "$complete_ipv6" | awk -F":" '{print $7$8}')
            local host_expr=" udp[54:4] = 0x${host1} and udp[58:4] = 0x${host2} and udp[62:4] = 0x${host3} and  udp[66:4] = 0x${host4}"
            ARGS=${ARGS/vxlan.dip[[:space:]]$host/$host_expr}
        fi
    fi
    return
}


function replace_pro() {
    local proto=$1
    if [ $proto ]; then
        if [ $proto = "vxlan.tcp" ]; then
            if [ "$IS_IPV6" = false ]; then
                local vpn=" udp[39] = 0x06"
            else
                local vpn=" udp[36] = 0x06"
            fi
            ARGS=${ARGS/$proto/$vpn}
        elif [ $proto = "vxlan.udp" ]; then
            if [ "$IS_IPV6" = false ]; then
                local vpn=" udp[39]=0x11"
            else
                local vpn=" udp[36]=17"
            fi
            ARGS=${ARGS/$proto/$vpn}
        elif [ $proto = "vxlan.icmp" ]; then
            if [ "$IS_IPV6" = false ]; then
                local vpn=" udp[39]=0x01"
            else
                local vpn=" udp[36]=0x3a"
            fi
            ARGS=${ARGS/$proto/$vpn}
        elif [ $proto = "vxlan.ns" ]; then
            local vpn=" udp[70]=0x87 and udp[36]=0x3a and udp[28:2] = 0x86dd"
            ARGS=${ARGS/$proto/$vpn}
        elif [ $proto = "vxlan.na" ]; then
            local vpn=" udp[70]=0x86 and udp[36]=0x3a and udp[28:2] = 0x86dd"
            ARGS=${ARGS/$proto/$vpn}
        elif [ $proto = "vxlan.rs" ]; then
            local vpn=" udp[70]=0x85 and udp[36]=0x3a and udp[28:2] = 0x86dd"
            ARGS=${ARGS/$proto/$vpn}
        elif [ $proto = "vxlan.redict" ]; then
            local vpn=" udp[70]=0x88 and udp[36]=0x3a and udp[28:2] = 0x86dd"
            ARGS=${ARGS/$proto/$vpn}
        elif [ $proto = "vxlan.nd" ]; then
            local vpn=" udp[36]=0x3a and udp[28:2]=0x86dd and (udp[70]=0x87 or udp[70]=0x88)"
            ARGS=${ARGS/$proto/$vpn}
        fi
    fi
    return
}

function replace_sport() {
    local port=$1
    if [ $port ]; then
       if [ "$IS_IPV6" = false ]; then
            local np=" udp[50:2] = "${port}
       else 
            local np=" udp[70:2] = "${port}
       fi
       ARGS=${ARGS/vxlan.sport[[:space:]]$port/$np}
    fi
}

function replace_dport() {
    local port=$1
    if [ $port ]; then
       if [ "$IS_IPV6" = false ]; then
            local np=" udp[52:2] = "${port}
       else 
            local np=" udp[72:2] = "${port}
       fi
       ARGS=${ARGS/vxlan.dport[[:space:]]$port/$np}
    fi
}

function replace_ping() {
    local ping=$1
    if [ $ping ]; then
        if [ $ping = "vxlan.ping.request" ]; then
            if [ "$IS_IPV6" = false ]; then
                local cmd="  udp[39] = 0x01 and udp[50:1] = 0x08"
            else
                local cmd="  udp[36] = 0x3a and udp[70] = 0x80"
            fi
            ARGS=${ARGS/$ping/$cmd}
        elif [ $ping = "vxlan.ping.reply" ]; then
            if [ "$IS_IPV6" = false ]; then
                local cmd="  udp[39] = 0x01 and udp[50:1] = 0x0"
            else
                local cmd="  udp[36] = 0x3a and udp[70] = 0x81"
            fi
            ARGS=${ARGS/$ping/$cmd}
        elif [ $ping = "vxlan.ping" ]; then
            if [ "$IS_IPV6" = false ]; then
                local cmd="  udp[39] = 0x01 and (udp[50:1] = 0x0 or udp[50:1] = 0x08)"
            else
                local cmd="  udp[36] = 0x3a and (udp[70] = 0x81 or udp[70] = 0x80)"
            fi
            ARGS=${ARGS/$ping/$cmd}
        fi
    fi
    return
}

function replace_ipv6() {
    local np=" udp[28:2] = 0x86dd"
    ARGS=${ARGS/vxlan.ipv6/$np}
}

function replace_icmp6() {
    local np=" udp[36] = 0x3a"
    ARGS=${ARGS/vxlan.icmp6/$np}
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
        elif [[ $param == "vxlan.ping.request" ]] || \
             [[ $param = "vxlan.ping" ]] ||\
             [[ $param == "vxlan.ping.reply" ]]; then
            replace_ping $param
        elif [[ $param == "vxlan.arp" ]] ||\
             [[ $param == "vxlan.arp.request" ]] ||\
             [[ $param == "vxlan.arp.reply" ]]; then
            replace_arp $param
        elif [ $param = "vxlan.vni" ] && [ $value ]; then
            replace_vni $value
        elif [ $param = "vxlan" ]; then
            replace_vxlan
        elif [[ $param == "vxlan.tcp" ]] ||\
             [[ $param == "vxlan.udp" ]] ||\
             [[ $param == "vxlan.icmp" ]]; then
            replace_pro $param
        elif [ $param = "vxlan.ipv6" ]; then
            replace_ipv6 $param
        elif [[ $param = "vxlan.nd" ]] ||\
             [[ $param = "vxlan.ns" ]] ||\
             [[ $param = "vxlan.na" ]] ||\
             [[ $param = "vxlan.redict" ]] ||\
             [[ $param = "vxlan.rs" ]] ||\
             [[ $param = "vxlan.ra" ]]; then
            replace_pro $param
        elif [ $param = "vxlan.icmp6" ]; then
            replace_icmp6 $param
        fi
    fi
    return
}

function generate_ipv6_complete_file(){
cat>complete_ipv6.awk<<'EOF'
# ipv6地址补全函数
function compipv6(orig_address){
    # 分割IPV6地址
    split(orig_address, ipv6_addr, "/")
    n = split(ipv6_addr[1], ip_field, ":")
    full_addr=""
    # 切割简化的地址
    split(ipv6_addr[1], ip_field, ":")
    # 每个字段不足4位则高位补0
    for ( i=1; i<=n; i++){
        if ( length(ip_field[i]) == 0 ){
            ip_field[i] = "0000"
        }
        else if ( length(ip_field[i]) == 1 ){
            ip_field[i] = "000"ip_field[i]
        }
        else if ( length(ip_field[i]) == 2 ){
            ip_field[i] = "00"ip_field[i]
        }
        else if ( length(ip_field[i]) == 3 ){
            ip_field[i] = "0"ip_field[i]
        }
        # 组合临时简化的IPV6地址
        if ( i==1 ){
            full_addr = ip_field[i]
        }else{
            full_addr = full_addr":"ip_field[i]
        }
    }
    # 循环补全32位
    do{
        FS = ":"
        $0 = full_addr
        if( $(NF-1) == "0000" && $NF == "0000" ){
            n1 = 8-NF
            for ( i=1; i<=n1; i++ ){
                full_addr=full_addr":0000"
            }
        }
        else if( $NF != "0000" ){
            n1 = 8-NF
            for ( i=1; i<=n1; i++ ){
                full_addr=gensub(/0000/,"0000:0000",1,full_addr)
            }
        }
        FS=" "
    }while(0)
    # 判断原始数据是否有掩码位，有则需要返回掩码位
    if (orig_address !~ /\//){
        print full_addr
    }
    else{
        print full_addr"/"ipv6_addr[2]
    }
}

compipv6($1)
EOF
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
    generate_ipv6_complete_file
    ARGS="tcpdump -ennvv ${ARGS}"
    echo "exec $ARGS"
    $ARGS
}

main $*


