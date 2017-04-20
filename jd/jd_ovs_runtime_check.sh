#!/bin/bash

CCC_CONFIG_FILE="/etc/cc_controller/compute.json"
#CCC_CONFIG_FILE="/etc/cc_controller/controller_config.json"

VSCTL="ovs-vsctl"
DPCTL="ovs-dpctl"
APPCTL="ovs-appctl"
OFCTL="ovs-ofctl -O openflow13"
BRIDGE="br0"

CCC="/usr/local/bin/ccc"
#CCC="/home/jstack/src/jd.com/cc/jstack-controller/cli/main"

CCCRUDETAILCMD="$CCC curdetail"

MAX_OFPORT="65280"

CCCURDETAIL="/tmp/curdetail"
DUMPFLOWPATH="/tmp/dumpflows"
DUMPGFLOWPATH="/tmp/dumpgflows"

function init_env()
{
    OFPORT=""
    OFPORTHEX=""
    PORTHOST=""
    UNDERLAYIP=""
    METADATAHEX=""
    VNI=""
    VNIHEX=""
    GWMAC=""
    PORTMAC=""
    PORTIP=""
    VR=()
    PORTINFO="/tmp/$PORTID"
    SUBNETINFO="/tmp/$SUBNETINFO"
}

function help_usage()
{
     echo ""
     echo "input param error:"
     echo ""
     echo "-p:         port_id of port"
     echo "-v:         vm_id of vm"

     echo ""
     echo "example1: checkout a port"
     echo "        sh $0 -p port-y8a7358djj"
     echo ""
     exit 1
}


while getopts "p:v:h" arg
do
        case $arg in
             p)
                PORTID=$OPTARG
                ;;
             v)
                VMID=$OPTARG
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


function clean()
{
        if [ "$PORTID" != "" ];then
            rm -f $PORTINFO >> /dev/null
        fi
        if [ "$SUBNETID" != "" ];then
            rm -f $SUBNETINFO >> /dev/null
        fi
        rm -f $CCCURDETAIL >> /dev/null
        rm -f $DUMPFLOWPATH >> /dev/null
        rm -f $DUMPGFLOWPATH >> /dev/null
}

function init_check()
{
    if [ ! -f $CCC_CONFIG_FILE ];then
          EError "file $CCC_CONFIG_FILE is not exist"
    fi

    if [ ! -f $CCC ];then
          EError "file $CCC is not exist"
    fi
}

function init_cache()
{
        local subnet

        Info "[subnet] get subnet info from cc_controller"
        exec `$CCCRUDETAILCMD > $CCCURDETAIL`
        subnet=$(cat $CCCURDETAIL|grep subnet-| wc -l)
        if [ $subnet == 0 ];then
            EError "get curdetail cache fail from cc_controller"
        fi

        Info "[port] get port info from cc_controller"
        echo > $PORTINFO
        cat $CCCURDETAIL | grep -i $PORTID -A 100 | grep  -E "securitygroupIds" -m1 -B 100 > $PORTINFO
        local count=$(cat $PORTINFO | wc -l)
        if [ $count == 0 ];then
               EError "can not find $PORTID from curdetail cache"
        fi
}

function EError()
{
        echo "========================================Error====================================="
        echo "Error: $*"
        clean
        exit 1
}

function Error()
{
        echo "EError: $*"
}

function Info()
{
        echo "Info: $*"
}

function write_portinfo()
{
        Info "get port info from cc_controller"
        echo > $PORTINFO
        `cat $CCCURDETAIL | grep -i $PORTID -A 100 | grep  -E "securitygroupIds" -m1 -B 100` > $PORTINFO
        local count=$(cat $PORTINFO | wc -l)
        if [ $count == 0 ];then
               EError "can not find $PORTID from cc_controller"
        fi
}

function dumpflows()
{
        $OFCTL dump-flows $BRIDGE > $DUMPFLOWPATH
        $OFCTL dump-groups $BRIDGE  > $DUMPGFLOWPATH
}

function get_subnet_param()
{
        SUBNETID=$(sed -n '0,/'$PORTID'/p' $CCCURDETAIL| grep subnet- | tail -n 1 | sed -e 's/\"//g' -e 's/\,//g' -e 's/\ //g' |cut -d":" -f2)
        exit_str_null "subnet of $SUBNETID cant not find in curdetail" $SUBNETID
        SUBNETINFO="/tmp/$SUBNETID"
        sed -n '/'$SUBNETID'/'',/securitygroups/p' $CCCURDETAIL > $SUBNETINFO

        metadata=$(cat $CCCURDETAIL | grep $SUBNETID -A 20 | grep metadata | cut -d":" -f2 | sed 's/[ ]//g' | sed 's/\,//g')
        VNI=$(cat $CCCURDETAIL | grep $SUBNETID -A 20 | grep -wi vni | cut -d":" -f2 | sed 's/[ ]//g' | sed 's/\,//g')
        VR=$(cat $CCCURDETAIL | grep $SUBNETID -A 20| sed -e "s/\"//g" -e "s/]//g" -e "s/\[//g" -e "s/\ //g" -e "s/\,//g" | sed 's/[[:alpha:]]//g'| grep '^[[:digit:]]*\.')

        METADATAHEX=$(echo "0x"`echo "obase=16;${metadata}"|bc`)
        VNIHEX=$(echo "0x"`echo "obase=16;${VNI}"|bc`)

        GWMAC=$(cat $SUBNETINFO | sed -n '/gatewayPorts/,/securitygroupIds/p' | grep mac | head -n 1 | sed -e "s/\ //g" -e "s/\"//g" -e "s/mac://g")
 
        exit_str_null "vni of $SUBNETID is null" $VNI
        exit_str_null "metadata of $SUBNETID is null" $metadata
        exit_str_null "gwmac of $SUBNETID is null" $GWMAC

        Info "[subnet] vni of subnet $SUBNETID is $VNIHEX"
        Info "[subnet] metadata of subnet $SUBNETID is $METADATAHEX"
        Info "[subnet] gwmac of subnet $SUBNETID is $GWMAC"
        for vr in $VR
        do 
        Info "[subnet] vr of subnet $SUBNETID is $vr"
        done
}

function ping_check()
{
    local r=""

    r=`ping -i 0.1 -c 5 -W 1 $1 | grep 'packet loss' | awk -F'packet loss' '{ print $1 }' | awk '{ print $NF }' | sed 's/%//g'`
    if [ "${r}" != "0" ];then
         Error "ping $1 failed"
         return
    fi

    Info "can ping $1, result is OK"
}

function checkout_vxlan_host_status()
{
     ping_check $1
}

function check_vr_host()
{
        for vr in $VR
        do
              local ofport=""
              ofport=$(get_vxlan_ofport $vr)
              Info "ofport of vxlan $vr is $ofport"
              checkout_vxlan_host_status $vr
        done
}

function get_vxlan_ofport()
{
        local vxlanhost="vx$1"
        local ofport=""
        ofport=$(get_ofport_num $vxlanhost)
        echo $ofport
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
              echo $ofport
              exit 1
        fi

        Info "[port] ofport of $1 is $ofport"
        OFPORT=$ofport
        OFPORTHEX=$(echo "0x"`echo "obase=16;${ofport}"|bc`)
}

function get_port_host() 
{
        PORTHOST=`cat $PORTINFO | grep host | cut -d ":" -f2 | cut -d"\"" -f2`
        Info "[port] host of $PORTID is $PORTHOST"
}

function get_underlayip()
{
       UNDERLAYIP=`cat $CCC_CONFIG_FILE | grep -i underlay | cut -d ":" -f2 | cut -d"\"" -f2`
       exit_str_null "config file $CCC_CONFIG_FILE is not exist underlayip option" $UNDERLAYIP

       Info "[system] underlayip of cc_controller is $UNDERLAYIP"
       
}

function check_port_host()
{
        get_underlayip
        get_port_host

        if [ "$PORTHOST" == "$UNDERLAYIP" ];then
                TYPE=0 #local port
                Info "[port] type of $PORTID is local_port"
        else
                TYPE=1 #remote port
                Info "[port] type of $PORTID is remote_port"
        fi
}


function exit_str_null()
{
        if [ "$2" == "" ];then
                EError "$1"
        fi
}

function check_str_null()
{
        if [ "$2" == "" ];then
                Error "$1"
        fi
}

function checkout_table_flow()
{
        local tableid=$1
        local match=""
        local r=""
        local flowpath="/tmp/flows"
        local flowpath1="/tmp/flows1"

        echo > $flowpath

        match=$(echo $2 | sed -e 's/\,/\ /g')

        cat $DUMPFLOWPATH | grep "table=$tableid," > $flowpath
        for m in ${match}
        do
                cat $flowpath | grep -i ${m} > "${flowpath1}"
                cat "${flowpath1}" > $flowpath
        done
        r=$(cat $flowpath)
        check_str_null "[flow_table] tableid $tableid, match ${2}: flow is not exist" ${r}
        Info "[flow_table] tableid $tableid, match $match: ${r}"
}

function check_group_flow()
{
        local groupid=$VNI
        local r=""

        r=$(cat $DUMPGFLOWPATH | grep "group_id=$groupid,")
        Info "group $groupid: $r"
        check_str_null "[flow_table] group $groupid: flow is not exist" $r
}

function check_subnet_flow()
{
        #table=0, match=tun_id, ofport
        for vr in $VR
        do
            ofport=$(get_vxlan_ofport $vr)
            checkout_table_flow 0 "tun_id=$VNIHEX,in_port=$ofport"
        done

}


function check_rport_flow()
{
        #table=25, match=mac, ip, metadata
        checkout_table_flow 25 "metadata=$METADATAHEX,arp_tpa=$PORTIP,$PORTMAC"

        #table=45, match=mac, metadata
        checkout_table_flow 45 "metadata=$METADATAHEX,$PORTMAC"
}

function check_lport_flow()
{
        #table=0, match=ofport
        checkout_table_flow 0 "in_port=$OFPORT"

        #table=5, match=ofport
        checkout_table_flow 5 "in_port=$OFPORT"

        #table=10, match=ofport
        checkout_table_flow 10 "reg6=$OFPORTHEX"

        #table=15, match=ofport
        checkout_table_flow 15 "reg6=$OFPORTHEX"

        #table=20, match=ofport
        checkout_table_flow 20 "reg6=$OFPORTHEX"

        #table=25, match=mac, ip, metadata
        checkout_table_flow 25 "metadata=$METADATAHEX,arp_tpa=$PORTIP,$PORTMAC"

        #table=30, match=metadata
        checkout_table_flow 30 "metadata=$METADATAHEX, udp"

        #table=40, match=vni,mac, metadata
        checkout_table_flow 40 "write_metadata:$METADATAHEX,$PORTMAC,tun_id=$VNIHEX"

        #table=45, match=vni,mac, ofport
        checkout_table_flow 45 "metadata=$METADATAHEX,$PORTMAC"

        #vr, table=45, match=metadata, gwmac
        checkout_table_flow 45 "metadata=$METADATAHEX $GWMAC"

        #table=50, match=ofport
        checkout_table_flow 50 "reg7=$OFPORTHEX"

        #table=55, match=ofport
        checkout_table_flow 55 "reg7=$OFPORTHEX"

        #table=60, match=ofport,metadata
        checkout_table_flow 60 "reg7=$OFPORTHEX,metadata=$METADATAHEX"

        #vr, table=60, match=gwmac,metadata
        checkout_table_flow 60 "metadata=$METADATAHEX,$GWMAC"
}

function get_lport_info()
{
        PORTMAC=$($VSCTL list Interface  $1 | grep external_ids | awk -F "attached-mac=" '{print $2}' | cut -d"," -f1|sed -e 's/\"//g')
        if [ "$PORTMAC" == "" ];then
            Info "cannot find mac of $1 from ovsdb" $PORTMAC
            PORTMAC=$(cat $PORTINFO|grep mac| head -n 1 | sed -e "s/\"//g" -e "s/\ //g" -e "s/mac://g")
        fi
        exit_str_null "cannot find mac of $1 from curdetail cache or ovsdb" $PORTMAC
        Info "[port] mac of $1 is $PORTMAC"

        PORTIP=`cat $PORTINFO | grep $PORTMAC -B 1 | grep fixedip | sed -e "s/\"//g" -e "s/\,//g" -e "s/\ //g" | cut -d ":" -f2`
        exit_str_null "cannot find ip of $1 from curdetail cache" $PORTIP
        Info "[port] ip of $1 is $PORTIP"
        
}

function get_rport_info()
{
        PORTMAC=$(cat $PORTINFO|grep mac| head -n 1 | sed -e "s/\"//g" -e "s/\ //g" -e "s/mac://g")
        exit_str_null "cannot find mac of $1 from curdetail cache" $PORTMAC
        Info "[port] mac of $1 is $PORTMAC"

        PORTIP=`cat $PORTINFO | grep $PORTMAC -B 1 | grep fixedip | sed -e "s/\"//g" -e "s/\,//g" -e "s/\ //g" | cut -d ":" -f2`
        exit_str_null "cannot find ip of $1 from curdetail cache" $PORTIP
        Info "[port] ip of $1 is $PORTIP"
        
}

function check_vm_ports()
{
    local port_names=""
    local vm=""

    vm=$(ps -ef|grep -w $VMID | grep qemu-kvm)
    exit_str_null "vm $VMID is not exist" $vm

    port_names=$(virsh domiflist $VMID | grep "port-" | awk -F" " '{print $1}')
    Info "ports of $VMID are: $port_names"
    for port in  $port_names
    do
        Info "check port: $port"
        PORTID=$port
        check_port $port
        init_env 
    done
}

function check_port_cache()
{

        portinfo=`cat $PORTINFO`

        local portnum=`cat $PORTINFO | grep $1 | wc -l` 
        if [ $portnum -ne 1 ];then
                EError "the num of $1 is not correct, num: $portnum"
        fi

        local macnum=`cat $PORTINFO | grep $PORTMAC | wc -l`
        if [ $macnum -ne 1 ];then
                EError "the num of $1 mac $PORTMAC is not correct, num: $macnum"
        fi

        local ipnum=`cat $PORTINFO | grep ${PORTIP} | wc -l`
        if [ $ipnum -ne 1 ];then
                EError "the num of $1 ip $PORTIP is not correct, num: $ipnum"
        fi
        
}

check_port()
{
        init_env
        init_check
        init_cache
        dumpflows
        check_port_host
        get_subnet_param
        check_subnet_flow
        if [ $TYPE -eq 0 ];then
            get_lport_info $1
            check_port_cache $1
            get_ofport $PORTID
            check_vr_host
            check_lport_flow
            check_group_flow
        fi
        if [ $TYPE -eq 1 ];then
            get_rport_info $1
            check_port_cache $1
            check_vr_host
            check_rport_flow
        fi
        clean
}

main()
{
    if [ "$PORTID" != "" ];then
        check_port $PORTID
    fi

    if [ "$VMID" != "" ];then
        check_vm_ports
    fi
}

main

