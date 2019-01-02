#!/usr/bin/env bash

CC="/usr/local/bin/ccc"
CCC_CONFIG="/etc/cc_controller_vs/cc_controller_vs.json"

function file_check ()
{
    if [ ! -f  "$CCC_CONFIG" ];then
        CCC_CONFIG=`echo $CCC_CONFIG_FILE`
    fi

    if [ ! -f  "$CCC_CONFIG" ];then
        EError "Please define CCC_CONFIG_FILE environment variable, example: export CCC_CONFIG_FILE=/etc/cc_controller_vs/cc_controller_vs.json"
    fi

    if [ ! -f "$CC" ];then
        CC=`echo $CCC`
    fi

    if [ ! -f "$CC" ];then
        EError "Please define CCC environment variable, example: export CCC=/usr/local/bin/ccc"
    fi
}

VSCTL="ovs-vsctl"
DPCTL="ovs-dpctl"
APPCTL="ovs-appctl"
OFCTL="ovs-ofctl --color=auto"
BRIDGE="br0"
BRIDGEPHY="br-phy"

CHECK_SETUP=""
MAX_OFPORT="65280"

DIRNAME=`date +%s`$RANDOM
PATHTMP="/tmp"
PATHINFO="$PATHTMP/tmp-$DIRNAME"

SUBNETDETAIL="$PATHINFO/sndetail"
SUBNETDETAIL2="$PATHINFO/sndetail2"
ROUTERDETAIL="$PATHINFO/rdetail"
ROUTERDETAIL2="$PATHINFO/rdetail2"
HGDETAIL="$PATHINFO/hgdetail"
HGDETAIL2="$PATHINFO/hgdetail2"
DUMPFLOWPATH="$PATHINFO/dumpflows"
DUMPGFLOWPATH="$PATHINFO/dumpgflows"
DUMPPHYFLOWPATH="$PATHINFO/dumphypgflows"

RED='\e[1;31m'
NC='\e[0m'

DPTYPEKERNEL="linux-kernel"
DPTYPEOVSDPDK="ovs-dpdk"
DPTYPEOVSDPDKVIRTIOUSER="ovs-dpdk-virtio-user"

function init_env()
{
    OFPORT=""
    OFPORTHEX=""
    PORTHOST=""
    PORTHOSTOFPORT=""
    PORTHOSTOFPORTHEX=""
    UNDERLAYIP=""
    METADATAHEX=""
    VNI=""
    VNIHEX=""
    GWMAC=""
    GWIP=""
    DHCPMAC=""
    DHCPIP=""
    PORTMAC=""
    PORTIP=""
    INGRESSHOSTS=""
    EGRESSHOSTS=""
    PORTINFO="$PATHINFO/$PORTID"
    SUBNETINFO="$PATHINFO/$SUBNETINFO"
    SUBNETID=""
    #NLBNATINFO="$PATHINFO/$VIP"
    BNLBINFO="$PATHINFO/$VPORT"
    TMP1="$PATHINFO/tmp1"
    TMP2="$PATHINFO/tmp2"
}

function help_usage()
{
     echo ""
     echo "input param error:"
     echo ""
     echo "-p:         port_id of port"
     echo "-v:         vm_id of vm"
     echo '-n:         nlb_id like "nlb-enwj12dt4h"'
     echo "-b:         checkout setup flows" 
     echo "-h:         help infos"

     echo ""
     echo "example1: checkout a port"
     echo "        sh $0 -p port-y8a7358djj"
     echo ""
     exit 1
}


while getopts "p:v:n:h:b" arg
do
        case $arg in
             p)
                PORTID=$OPTARG
                ;;
             v)
                VMID=$OPTARG
                ;;
             n)
                NLBID=$OPTARG
                ;;
             h)
                help_usage
                ;;
             b)
                CHECK_SETUP="true"
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
        #if [ "$NLBNATINFO" != "" ];then
        #   rm -f $NLBNATINFO >> /dev/null
        #fi
        if [ "$SUBNETID" != "" ];then
            rm -f $SUBNETINFO >> /dev/null
        fi
        rm -f $SUBNETDETAIL >> /dev/null
        rm -f $SUBNETDETAIL2 >> /dev/null
        rm -f $ROUTERDETAIL >> /dev/null
        rm -f $ROUTERDETAIL2 >> /dev/null
        rm -f $HGDETAIL >> /dev/null
        rm -f $HGDETAIL2 >> /dev/null
        rm -f $TMP1 >> /dev/null
        rm -f $TMP2 >> /dev/null
        rm -f $DUMPFLOWPATH >> /dev/null
        rm -f $DUMPGFLOWPATH >> /dev/null
        rm -f $DUMPPHYFLOWPATH >> /dev/null
}

function init_cache()
{
    local subnet
    local sn

    targetPort=$(echo ${PORTID/port-/port_})
    Info "[subnet] get subnet info from cc_controller by subnet-detail"
    subnet=$(cat $SUBNETDETAIL|grep subnet-| wc -l)
    if [ $subnet == 0 ];then
        EError "get curdetail cache fail from cc_controller"
    fi

    sed  "s/-/_/g" $SUBNETDETAIL > $SUBNETDETAIL2
    subnetIds=$(cat $SUBNETDETAIL2 | grep subnet_ | sed '/id/d' | sed '/subnetId/d' | sed 's/: {//g' | sed 's/"//g')
    flag=0
    for sn in $subnetIds
    do
        rt=$(cat $SUBNETDETAIL2 | jq .$sn | grep '"id":' | grep $targetPort)
        if [ "$rt" == "" ];then
            continue
        fi
        echo > $TMP1
        #find port in one subnet
        cat $SUBNETDETAIL2 | jq .$sn.ports > $TMP1
        i=0
        portIds=$(jq .$sn.ports[].id $SUBNETDETAIL2)
        for port in $portIds
        do
            result=$(cat $TMP1 | jq .[$i].id | grep $targetPort)
            if [ "$result" == "" ];then
                let i+=1
                continue
            fi
            SUBNETID=$sn
            Info "[port] get port in" $SUBNETID " success"
            cat $TMP1 | jq .[$i] > $PORTINFO
            flag=1
            break
        done
        if [ "1" == "$flag" ];then
            #only find first port
            break
        fi
    done
	if [ "0" == "$flag" ];then
	    EError "can not find the port in subnetDetail"
	fi
}

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

function write_portinfo()
{
        Info "[system] get port info from cc_controller"
        echo > $PORTINFO
        `cat $SUBNETDETAIL | grep -i $PORTID -A 100 | grep  -E "securitygroupIds" -m1 -B 100` > $PORTINFO
        local count=$(cat $PORTINFO | wc -l)
        if [ $count == 0 ];then
               EError "can not find $PORTID from cc_controller"
        fi
}

function dumpflows()
{
        $OFCTL -O openflow15 dump-flows $BRIDGE > $DUMPFLOWPATH
        $OFCTL -O openflow15 dump-groups $BRIDGE  > $DUMPGFLOWPATH
        $OFCTL -O openflow13 dump-flows $BRIDGEPHY  > $DUMPPHYFLOWPATH
}

function get_subnet_hg()
{
        local subnet=""
        subnet=$(echo $SUBNETID | sed s/-/_/g)
        HOSTGROUPIDS=$(jq .$subnet.hostgroupIds $SUBNETDETAIL2 | grep hg_ |sed -e 's/\"//g' -e 's/\,//g' -e 's/\ //g')
        exit_str_null "hostgroup of $SUBNETID is null" $HOSTGROUPIDS
        Info "[subnet] hostgroup of $SUBNETID is $HOSTGROUPIDS"

        ZONE=$(jq .$subnet.zones[0] $SUBNETDETAIL2 | sed -e 's/\"//g' -e 's/\,//g' -e 's/\ //g' | head -n 1)
        exit_str_null "zone of $SUBNETID is null" $ZONE
        Info "[subnet] zone of subnet $SUBNETID is $ZONE"
}


function get_subnet_param()
{
    echo "get subnet param " $SUBNETID
    exit_str_null "subnet of $SUBNETID cant not find in curdetail" $SUBNETID
    SUBNETINFO="$PATHINFO/$SUBNETID"
    jq .$SUBNETID $SUBNETDETAIL2 > $SUBNETINFO
    metadata=$(jq .metadata $SUBNETINFO)
    VNI=$(jq .vni $SUBNETINFO)

    METADATAHEX=$(echo "0x"`echo "obase=16;${metadata}"|bc`)
    VNIHEX=$(echo "0x"`echo "obase=16;${VNI}"|bc`)

    gw=$(jq .gatewayPorts[0].flows[0] $SUBNETINFO)
    GWMAC=$(echo $gw | jq .mac | sed -e "s/\"//g")
    GWIP=$(echo $gw | jq .fixedip | sed -e "s/\"//g")
    #GWMAC=$(cat $SUBNETINFO | sed -n '/gatewayPorts/,/securitygroupIds/p' | grep mac | head -n 1 | sed -e "s/\ //g" -e "s/\"//g" -e "s/mac://g")
    #GWIP=$(cat $SUBNETINFO | sed -n '/gatewayPorts/,/securitygroupIds/p' | grep fixedip | head -n 1 | sed -e "s/\ //g" -e "s/\,//g" -e "s/\"//g" -e "s/fixedip://g")

    dhcp=$(jq .dhcpPort.flows[0] $SUBNETINFO)
    DHCPMAC=$(echo $dhcp | jq .mac | sed -e "s/\"//g")
    DHCPIP=$(echo $dhcp | jq .fixedip | sed -e "s/\"//g")
    #DHCPMAC=$(cat $SUBNETINFO | sed -n '/dhcpPort/,/securitygroupIds/p' | grep mac | head -n 1 | sed -e "s/\ //g" -e "s/\"//g" -e "s/mac://g")
    #DHCPIP=$(cat $SUBNETINFO | sed -n '/dhcpPort/,/securitygroupIds/p' | grep fixedip | head -n 1 | sed -e "s/\ //g" -e "s/\,//g" -e "s/\"//g" -e "s/fixedip://g")

    exit_str_null "vni of $SUBNETID is null" $VNI
    exit_str_null "metadata of $SUBNETID is null" $metadata
    exit_str_null "gwmac of $SUBNETID is null" $GWMAC
    exit_str_null "gwip of $SUBNETID is null" $GWIP
    exit_str_null "dhcpmac of $SUBNETID is null" $DHCPMAC
    exit_str_null "dhcpip of $SUBNETID is null" $DHCPIP

    Info "[subnet] vni of subnet $SUBNETID is $VNIHEX"
    Info "[subnet] vni of subnet $SUBNETID is $VNI"
    Info "[subnet] metadata of subnet $SUBNETID is $METADATAHEX"
    Info "[subnet] gwmac of subnet $SUBNETID is $GWMAC"
    Info "[subnet] gwip of subnet $SUBNETID is $GWIP"
    Info "[subnet] dhcpmac of subnet $SUBNETID is $DHCPMAC"
    Info "[subnet] dhcpip of subnet $SUBNETID is $DHCPIP"
}

function get_hg_host()
{
    local i=0
    local status=0
    local adminstatus=0
    local htype=0
    local zone=""
    local ipaddr=""
    local iptype=""

    sed 's/-/_/g' $HGDETAIL > $HGDETAIL2
    for hg in $HOSTGROUPIDS
    do
        hostids=$(jq .$hg.hosts[].id $HGDETAIL2 | sed -e 's/\"//g' -e 's/\,//g' -e 's/\ //g')
        exit_str_null "hosts of $hg is null" $hostids
        Info "[hostgroup] hosts of $hg is  `echo $hostids|sed s/\n/,/`"
        i=0
        for h in $hostids
        do
            Info "[hostgroup] $h info:"
            status=$(jq .$hg.hosts[$i].status $HGDETAIL2)
            adminstatus=$(jq .$hg.hosts[$i].adminStatus $HGDETAIL2)
            Info "[hostgroup] status of $h in $hg is $status"
            Info "[hostgroup] adminstatus of $h in $hg is $adminstatus"
            zone=$(jq .$hg.hosts[$i].zone $HGDETAIL2 | sed -e 's/\"//g' -e 's/\,//g' -e 's/\ //g')
            htype=$(jq .$hg.hosts[$i].clusterType $HGDETAIL2)
            local k=0
            while [[ $k -lt 3 ]]
            do
                 iptype=$(jq .$hg.hosts[$i].hostIps[$k].type $HGDETAIL2)
                 if [ "$iptype" == "0" ];then
                   ipaddr=$(jq .$hg.hosts[$i].hostIps[$k].ipAddress $HGDETAIL2|sed -e 's/\"//g' -e 's/\,//g' -e 's/\ //g')
                 fi
                ((k++))
            done
            Info "[hostgroup] zone of $h in $hg is $zone"
            Info "[hostgroup] cluster type of $h in $hg is $htype"
            Info "[hostgroup] ip type of $h in $hg is $iptype"
            Info "[hostgroup] underlay ip of $h in $hg is $ipaddr"
            INGRESSHOSTS="$ipaddr $INGRESSHOSTS"
            if [ "$status" == "0" -o "$adminstatus" == "0" ];then
                let i+=1
                continue
            fi
            if [ "$zone" == "$ZONE" ];then
                EGRESSHOSTS="$ipaddr $EGRESSHOSTS"
            fi
            let i+=1
        done

    done
    INGRESSHOSTS=$(echo $INGRESSHOSTS|sed -e "s/[ ]*$//g")
    EGRESSHOSTS=$(echo $EGRESSHOSTS|sed -e "s/[ ]*$//g")

    if [ "$INGRESSHOSTS" == "" ];then
        Error "[subnet] ingress host of subnet $SUBNETID is null"
    fi
    if [ "$EGRESSHOSTS" == "" ];then
        Error "[subnet] egress host of subnet $SUBNETID is null"
    fi
    for h in `echo $INGRESSHOSTS | sed "s/\ /\\n/g"`
    do
        Info "[subnet] ingress host of subnet $SUBNETID is $h"
    done
    for h in `echo $EGRESSHOSTS | sed "s/\ /\\n/g"`
    do
        Info "[subnet] egress host of subnet $SUBNETID is $h"
    done
}

function ping_check()
{
    local r=""

    r=`ping -i 0.1 -c 5 -W 1 -I $UNDERLAYIP $1 | grep 'packet loss' | awk -F'packet loss' '{ print $1 }' | awk '{ print $NF }' | sed 's/%//g'`
    if [ "${r}" != "0" ];then
         Error "[port] ping $1 failed"
         return
    fi

    Info "[port] can ping $1, result is OK"
}

function checkout_vxlan_host_status()
{
     ping_check $1
}

function check_host()
{
        for h in `echo $INGRESSHOSTS $EGRESSHOSTS | sed "s/\ /\\n/g"`
        do
              local ofport=""
              ofport=$(get_vxlan_ofport $h)
              Info "[port] ofport of host tunnel vx$h is $ofport"
              checkout_vxlan_host_status $h
        done
}

function get_vxlan_ofport()
{
        local vxlanhost="vx$1"
        local ofport=""
        ofport=$(get_ofport_num $vxlanhost)
        if [ $? != 0 ];then
              EError "ofport of $vxlanhost is invalid"
              exit 1
        fi
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
              EError "ofport of $vxlanhost is invalid"
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
       UNDERLAYIP=$(cat $CCC_CONFIG | jq '.Underlay' | sed 's/"//g')
       exit_str_null "config file $CCC_CONFIG is not exist underlayip option" $UNDERLAYIP

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
        if [ "$TYPE" == "1" ];then
            PORTHOSTOFPORT=$(get_vxlan_ofport $PORTHOST)
            PORTHOSTOFPORTHEX=$(echo "0x"`echo "obase=16;${PORTHOSTOFPORT}"|bc`)
            Info "[port] ofport of compute tunnel vx$PORTHOST is $PORTHOSTOFPORT"
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
        local flowpath="$PATHINFO/flows"
        local flowpath1="$PATHINFO/flows1"

        echo > $flowpath

        match=$(echo $2 | sed -e 's/\,/\ /g')

        cat $DUMPFLOWPATH | grep "table=$tableid, n" > $flowpath
        for m in ${match}
        do
                cat $flowpath | grep -wi ${m} > "${flowpath1}"
                cat "${flowpath1}" > $flowpath
        done
        r=$(cat $flowpath)
        check_str_null "[flowtable] tableid $tableid, match ${2}: flow is not exist" ${r}
        Info "[flowtable] tableid $tableid, match $match: ${r}"
}

function checkout_phy_table_flow()
{
        local tableid=$1
        local match=""
        local r=""
        local flowpath="$PATHINFO/flows"
        local flowpath1="$PATHINFO/flows1"

        echo > $flowpath

        match=$(echo $2 | sed -e 's/\,/\ /g')

        cat $DUMPPHYFLOWPATH | grep "table=$tableid, n" > $flowpath
        for m in ${match}
        do
                cat $flowpath | grep -wi ${m} > "${flowpath1}"
                cat "${flowpath1}" > $flowpath
        done
        r=$(cat $flowpath)
        check_str_null "[phy-flowtable] tableid $tableid, match ${2}: flow is not exist" ${r}
        Info "[phy-flowtable] tableid $tableid, match $match: ${r}"
}

function check_drop_flow()
{
        r=$(cat $DUMPGFLOWPATH | grep -e "in_port=$ofport," -e "in_port=$ofport " |grep "drop")
        if [ "${r}" != "" ];then
            Error "[flowtable] port $PORTID have drop flow: ${r}"
        fi
        r=$(cat $DUMPGFLOWPATH | grep -e "$PORTMAC" |grep "drop")
        if [ "${r}" != "" ];then
            Error "[flowtable] port $PORTID have drop flow: ${r}"
        fi
}

function check_group_flow()
{
        local groupid=$1
        local r=""

        r=$(cat $DUMPGFLOWPATH | grep $groupid | grep $2)
        Info "[check-group] group $groupid: $r"
        check_str_null "[flowtable] group $groupid: flow is not exist" $r
}

function checkSetupFlow()
{
        dumpflows
        tap_mofport=$(get_ofport_num tap_metadata)
        checkout_table_flow 0 "in_port=$tap_mofport,actions=goto_table:37"
        #table=classifier, priority=1 actions=set_field:0->reg8,goto_table:drop
        checkout_table_flow 0 "priority=1,set_field:0->reg8,goto_table:200"
        
        #table=port_security priority=1000 tcp, nw_dst=169.254.169.254, tp_dst=80 action=goto_table:dispatcher
        #table=port_security priority=1000 tcp, nw_dst=169.254.169.250, tp_dst=1688 action=goto_table:dispatcher
        #table=port_security priority=1000 tcp, nw_dst=169.254.169.250, tp_dst=nlbctlport action=goto_table:dispatcher
        #table=port_security priority=1000 tcp, nw_dst=169.254.169.250, tp_dst=redisctlport action=goto_table:dispatcher
        checkout_table_flow 5 "tcp,nw_dst=169.254.169.254,tp_dst=1600"
        checkout_table_flow 5 "tcp,nw_dst=169.254.169.254,tp_dst=80"
        checkout_table_flow 5 "tcp,nw_dst=169.254.169.254,tp_dst=1608"
        checkout_table_flow 5 "tcp,nw_dst=169.254.169.250,tp_dst=1688"
        #table=port_security, drop flow
        checkout_table_flow 5 "priority=1,actions=set_field:0x5->reg8,goto_table:200"
        
        #table=FLOW_TABLE_EGRESSCT,actions=set_field:0xa->reg8,goto_table:200
        checkout_table_flow 10 "priority=1,actions=set_field:0xa->reg8,goto_table:200"
        #table=egressct, priority=2000, icmp, action=ct(table=egress_sg, zone=OXM_OF_METADATA[0..15])
        #table=egressct, priority=2000, udp, action=ct(table=egress_sg, zone=OXM_OF_METADATA[0..15])
        #table=egressct, priority=2000, tcp, action=ct(table=egress_sg, zone=OXM_OF_METADATA[0..15])
        checkout_table_flow 10 "icmp,actions=ct"
        checkout_table_flow 10 "udp,actions=ct"
        checkout_table_flow 10 "tcp,actions=ct"
        
        #table=FLOW_TABLE_EGRESSCTSG
        checkout_table_flow 15 "priority=1,actions=set_field:0xf->reg8,goto_table:200"
        #table=egress_sg, priority=2000,ct_state=-new+est-rel-inv+trk actions=move:NXM_NX_CT_MARK[]->NXM_NX_REG11[],move:NXM_NX_CT_LABEL[]->NXM_NX_XXREG0[],goto_table:20
        #table=egress_sg, priority=2000,ct_state=-new+rel-inv+trk actions=goto_table:20
        #table=egress_sg, priority=2000,ct_state=+new+rel-inv+trk,ip actions=ct(commit,table=20,zone=NXM_NX_CT_ZONE[])
        #table=egress_sg, priority=2000,ct_state=+inv+trk actions=set_field:0x96->reg8,goto_table:200
        checkout_table_flow 15 "ct_state=-new+est-rel-inv+trk"
        checkout_table_flow 15 "ct_state=-new+rel-inv+trk"
        checkout_table_flow 15 "ct_state=+new+rel-inv+trk,ip"
        checkout_table_flow 15 "ct_state=+inv+trk"
        
        #table=dispatcher, priority=50 actions=goto_table:43
        checkout_table_flow 20 "priority=50,goto_table:43"
        #table=dispatcher, priority=100,arp actions=goto_table:25
        checkout_table_flow 20 "priority=100,arp"
        #table=dispatcher priority=100,udp,tp_src=68,tp_dst=67 actions=goto_table:30
        checkout_table_flow 20 "priority=100,udp,tp_src=68,tp_dst=67"
        #table=dispatcher priority=1000,tcp,nw_dst=169.254.169.254,tp_dst=80 actions=goto_table:metadata
        #table=dispatcher priority=1000,tcp,nw_dst=169.254.169.250,tp_dst=1688 actions=goto_table:metadata
        #table=dispatcher priority=1000,tcp,nw_dst=169.254.169.254,tp_dst=nlbctlport actions=goto_table:metadata
        #table=dispatcher priority=1000,tcp,nw_dst=169.254.169.254,tp_dst=redisctlport actions=goto_table:metadata
        checkout_table_flow 20 "tcp,nw_dst=169.254.169.254,tp_dst=1600"
        checkout_table_flow 20 "tcp,nw_dst=169.254.169.254,tp_dst=80"
        checkout_table_flow 20 "tcp,nw_dst=169.254.169.254,tp_dst=1608"
        checkout_table_flow 20 "tcp,nw_dst=169.254.169.250,tp_dst=1688"
        
        #table=arp_resp, priority=1 actions=set_field:0x19->reg8,goto_table:drop
        checkout_table_flow 25 "priority=1,set_field:0x19->reg8,goto_table:200"
        #table=arp resp, priority=100,arp,arp_tpa=169.254.169.254,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],set_field:fa:16:3e:25:fd:7e->eth_src,set_field:2->arp_op,set_field:169.254.169.254->arp_spa,set_field:fa:16:3e:25:fd:7e->arp_sha,IN_PORT
        #table=arp_resp, priority=100,arp,arp_tpa=169.254.169.250,arp_op=1 actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],set_field:fa:16:3e:25:fd:7e->eth_src,set_field:2->arp_op,set_field:169.254.169.250->arp_spa,set_field:fa:16:3e:25:fd:7e->arp_sha,IN_PORT
        checkout_table_flow 25 "arp,arp_tpa=169.254.169.254,arp_op=1"
        checkout_table_flow 25 "arp,arp_tpa=169.254.169.250,arp_op=1"
        
        #table=ping_resp, priority=100,icmp,icmp_type=8,icmp_code=0 actions=move:NXM_OF_ETH_SRC[0..31]->NXM_NX_REG8[],move:NXM_OF_ETH_SRC[32..47]->NXM_NX_REG9[0..15],move:NXM_OF_ETH_DST[]->NXM_OF_ETH_SRC[],move:NXM_NX_REG8[]->NXM_OF_ETH_DST[0..31],move:NXM_NX_REG9[0..15]->NXM_OF_ETH_DST[32..47],move:NXM_OF_IP_SRC[]->NXM_NX_REG8[],move:NXM_OF_IP_DST[]->NXM_OF_IP_SRC[],move:NXM_NX_REG8[]->NXM_OF_IP_DST[],set_field:0->icmp_type,mod_nw_ttl:64,IN_PORT
        checkout_table_flow 26 "priority=100,icmp,icmp_type=8,icmp_code=0"
        
        #table=dhcp_resp, priority=1 actions=set_field:0->reg8,goto_table:drop
        checkout_table_flow 30 "priority=1,set_field:0x1e->reg8,goto_table:200"
        
        checkout_table_flow 35 "goto_table:200"
        #table=metadataProxy priority=100,tcp,nw_dst=169.254.169.254,tp_dst=80 actions=set_field:8848->tcp_dst,set_field:fa:16:3e:25:fd:7e->eth_dst,goto_table:36
        #table=metadataProxy priority=100,tcp,nw_dst=169.254.169.250,tp_dst=1688 actions=set_field:9090->tcp_dst,set_field:fa:16:3e:25:fd:7e->eth_dst,goto_table:36
        #table=metadataProxy priority=100,tcp,nw_dst=169.254.169.254,tp_dst=1600 actions=set_field:8800->tcp_dst,set_field:fa:16:3e:25:fd:7e->eth_dst,goto_table:36
        #table=metadataProxy priority=100,tcp,nw_dst=169.254.169.254,tp_dst=1608 actions=set_field:8808->tcp_dst,set_field:fa:16:3e:25:fd:7e->eth_dst,goto_table:36
        checkout_table_flow 35 "tcp,nw_dst=169.254.169.254,tp_dst=1600"
        checkout_table_flow 35 "tcp,nw_dst=169.254.169.254,tp_dst=80"
        checkout_table_flow 35 "tcp,nw_dst=169.254.169.254,tp_dst=1608"
        checkout_table_flow 35 "priority=100,tcp,nw_dst=169.254.169.250,tp_dst=1688"
        
        #table=metadata_learn priority=2000,tcp,nw_dst=169.254.169.254 actions=move:NXM_NX_REG6[]->NXM_OF_IP_SRC[],load:0x1->NXM_OF_IP_SRC[31],output:1
        #table=metadata_learn priority=2000,tcp,nw_dst=169.254.169.250 actions=move:NXM_NX_REG6[]->NXM_OF_IP_SRC[],load:0x1->NXM_OF_IP_SRC[31],output:1
        checkout_table_flow 36 "tcp,nw_dst=169.254.169.250,actions=move:NXM_NX_REG6[]->NXM_OF_IP_SRC[],set_field:128.0.0.0/1->ip_src,output:$tap_ofport"
        checkout_table_flow 36 "tcp,nw_dst=169.254.169.254,actions=move:NXM_NX_REG6[]->NXM_OF_IP_SRC[],set_field:128.0.0.0/1->ip_src,output:$tap_ofport"
        
        #table=l3_lookup, priority=1 actions=drop
        checkout_table_flow 40 "goto_table:200"
        
        #table=nlb_nat,priority=50 actions=goto_table:45
        checkout_table_flow 43 "priority=50,actions=goto_table:45"
        
        #table=l2_lookup, priority=1 actions=set_field:0->reg8,goto_table:drop
        checkout_table_flow 45 "priority=1,goto_table:200"
        
        #table=bnlb, drop flow
        checkout_table_flow 47 "priority=1,actions=set_field:0x2f->reg8,goto_table:200"
        
        #table=FLOW_TABLE_INGRESSCT
        checkout_table_flow 50 "priority=1,actions=set_field:0x32->reg8,goto_table:200"
        #table=50, priority=2000,udp actions=ct(table=55,zone=NXM_NX_REG7[0..15])
        #table=50, priority=2000,icmp actions=ct(table=55,zone=NXM_NX_REG7[0..15])
        #table=50, priority=2000,tcp actions=ct(table=55,zone=NXM_NX_REG7[0..15])
        checkout_table_flow 50 "priority=2000,udp"
        checkout_table_flow 50 "priority=2000,icmp"
        checkout_table_flow 50 "priority=2000,tcp"
        
        #table=ingress_sg, priority=2000,ct_state=-new+est-rel-inv+trk actions=goto_table:60
        #table=ingress_sg, priority=2000,ct_state=-new+rel-inv+trk actions=goto_table:60
        #table=ingress_sg, priority=2000,ct_state=+new+rel-inv+trk,ip actions=ct(commit,table=60,zone=NXM_NX_CT_ZONE[])
        #table=ingress_sg, priority=2000,ct_state=+inv+trk actions=set_field:0x226->reg8,goto_table:200
        checkout_table_flow 55 "priority=2000,ct_state=-new+est-rel-inv+trk"
        checkout_table_flow 55 "priority=2000,ct_state=-new+rel-inv+trk"
        checkout_table_flow 55 "priority=2000,ct_state=+new+rel-inv+trk,ip"
        checkout_table_flow 55 "priority=2000,ct_state=+inv+trk"
        #table=55,priority=1,actions=set_field:0x37->reg8,goto_table:200",
        checkout_table_flow 55 "priority=1,actions=set_field:0x37->reg8"
        #table=output, drop flow
        checkout_table_flow 60 "priority=1,actions=set_field:0x3c->reg8,goto_table:200"
        
        #table=l3_input priority=50 actions=goto_table:l3_check
        checkout_table_flow 70 "priority=50,goto_table:80"
        
        #table=75, priority=50,ip actions=resubmit(,60)
        checkout_table_flow 75 "priority=50,ip,actions=resubmit(,60)"
        #table=l3_local, priority=1 actions=set_field:0x4b->reg8,goto_table:200
        checkout_table_flow 75 "priority=1 actions=set_field:0x4b->reg8,goto_table:200"
        
        #table=l3_check, priority=1000,ip,nw_ttl=0 actions=drop
        #table=l3_check, priority=1000,ip,nw_ttl=1 actions=drop
        #table=l3_check, priority=100 actions=goto_table:egress_acl
        checkout_table_flow 80 "priority=1000,ip,nw_ttl=0"
        checkout_table_flow 80 "priority=1000,ip,nw_ttl=1"
        checkout_table_flow 80 "priority=100,actions=goto_table:90"
        
        #table=egress_acl, priority=50, action=goto_table:flow_table
        checkout_table_flow 90 "priority=50,actions=goto_table:100"
        
        #table=flow_table priority=50, action=goto_table:fib
        checkout_table_flow 100 "priority=50,actions=goto_table:110"
        
        #table=fib priority=100, action=goto_table 60
        checkout_table_flow 110 "priority=50,actions=resubmit(,60)"
        
        #table=rt_end, priority=50, action=goto_table:ingress_acl
        checkout_table_flow 120 "priority=50,actions=resubmit(,130)"
        
        #table=ingress_acl, priority=50, action=goto_table:dispatcher
        checkout_table_flow 130 "priority=50,resubmit(,20)"
                
        #table=drop, priority=1 actions=drop
        checkout_table_flow 200 "priority=1,actions=drop"
}

function check_bridge_phy_flow()
{
        local num=0
        num=$(cat $DUMPPHYFLOWPATH | grep "cookie" | wc -l)
        if [ "$num" != "1" ];then
            EError "flow num of $BRIDGEPHY is not 1, current is $num, `cat $DUMPPHYFLOWPATH`"
        fi
        checkout_phy_table_flow 0 "table=0,priority=0,actions=NORMAL"
}

function check_subnet_flow()
{
        #table=0, match=tun_id, ofport
        for h in `echo $INGRESSHOSTS | sed "s/\ /\\n/g"`
        do
            ofport=$(get_vxlan_ofport $h)
            checkout_table_flow 0 "in_port=$ofport,goto_table:40"
        done

        #table=25, match=dhcpmac, dhcpip, metadata
        checkout_table_flow 25 "metadata=$METADATAHEX,arp_tpa=$DHCPIP,$DHCPMAC"

        #table=30, match=metadata,dhcpmac
        checkout_table_flow 30 "metadata=$METADATAHEX, udp, $DHCPMAC"

        #table=30, match=metadata, broadcast
        checkout_table_flow 30 "metadata=$METADATAHEX, udp, ff:ff:ff:ff:ff:ff"

        #table=45, match=metadata, dl_dst goto_table:70
        checkout_table_flow 45 "metadata=$METADATAHEX, dl_dst=$GWMAC, goto_table:70"

        #table=70, match goto_table:80
        checkout_table_flow 70 "goto_table:80"

        #table=70, match metadata, nw_dst, goto_table:75
        checkout_table_flow 70 "metadata=$METADATAHEX, nw_dst=$GWIP, goto_table:75"

        #table=75 match icmp
        checkout_table_flow 75 "resubmit(,60)"

        #table=80, match goto_table:90
        checkout_table_flow 80 "goto_table:90"

        #table=90, match goto_table:100
        checkout_table_flow 90 "goto_table:100"

        #table=100, match goto_table:110
        checkout_table_flow 100 "goto_table:110"

        #table=110, match resubmit(,60)
        checkout_table_flow 110 "resubmit(,60)"

        #table=120, match goto_table:130
        checkout_table_flow 120 "resubmit(,130)"

        #table=130, match resubmit(,20)
        checkout_table_flow 130 "priority=50, resubmit(,20)"

        #table=60, match=metadata,gwmac,group
        checkout_table_flow 60 "metadata=$METADATAHEX, dl_dst=$GWMAC,group:$VNI"

}

function check_rport_flow()
{
        #table=25, match=mac, ip, metadata
        checkout_table_flow 25 "metadata=$METADATAHEX,arp_tpa=$PORTIP,$PORTMAC"

        #table=45, match=mac, metadata
        checkout_table_flow 45 "metadata=$METADATAHEX,$PORTMAC"

        #table=60, match=mac, metadata
        checkout_table_flow 60 "reg7=$PORTHOSTOFPORTHEX"

        # table=100, vni, nw_dst, goto_table:120
        checkout_table_flow 100 "$VNIHEX, nw_dst=$PORTIP, goto_table:120"
}

function check_dpdk_lport_flow()
{
        #table=10, match=ofport,nw_frag
        checkout_table_flow 10 "ip,nw_frag=later"

        #table=50, match=ofport,nw_frag
        checkout_table_flow 50 "ip,nw_frag=later"

        check_sport_flow
}

function check_lport_flow()
{
        check_sport_flow
}
function check_sport_flow()
{
        #table=0, match=ofport
        checkout_table_flow 0 "in_port=$OFPORT"

        #table=5, match=ofport
        checkout_table_flow 5 "in_port=$OFPORT"

        #table=15, match=ofport
        checkout_table_flow 15 "reg6=$OFPORTHEX"

        #table=25, match=mac, ip, metadata
        checkout_table_flow 25 "metadata=$METADATAHEX,arp_tpa=$PORTIP,$PORTMAC"

        #table=40, match=vni,mac, metadata
        checkout_table_flow 40 "$METADATAHEX,$PORTMAC,tun_id=$VNIHEX"

        #table=45, match=vni,mac, ofport
        checkout_table_flow 45 "metadata=$METADATAHEX,$PORTMAC"

        #vr, table=45, match=metadata, gwmac
        checkout_table_flow 45 "metadata=$METADATAHEX $GWMAC"

        #table=55, match=ofport
        checkout_table_flow 55 "reg7=$OFPORTHEX"

        #table=60, match=ofport,metadata
        checkout_table_flow 60 "reg7=$OFPORTHEX,metadata=$METADATAHEX"

        #vr, table=60, match=gwmac,metadata
        checkout_table_flow 60 "metadata=$METADATAHEX,$GWMAC"

        # table=100, vni, nw_dst, goto_table:120
        checkout_table_flow 100 "$VNIHEX, nw_dst=$PORTIP, goto_table:120"
}

function get_lport_info()
{
        PORTMAC=$($VSCTL list Interface  $1 | grep external_ids | awk -F "attached-mac=" '{print $2}' | cut -d"," -f1|sed -e 's/\"//g')
        if [ "$PORTMAC" == "" ];then
            Info "[port] cannot find mac of $1 from ovsdb" $PORTMAC
            PORTMAC=$(cat $PORTINFO|grep mac| head -n 1 | sed -e "s/\"//g" -e "s/\ //g" -e "s/mac://g" -e "s/\,//g")
        fi
        exit_str_null "cannot find mac of $1 from curdetail cache or ovsdb" $PORTMAC
        Info "[port] mac of $1 is $PORTMAC"

        PORTIP=`cat $PORTINFO | grep $PORTMAC -B 1 | grep fixedip | sed -e "s/\"//g" -e "s/\,//g" -e "s/\ //g" -e "s/\,//g" | cut -d ":" -f2`
        PORTIP=$(echo $PORTIP | awk '{print $1}')
        exit_str_null "cannot find ip of $1 from curdetail cache" $PORTIP
        Info "[port] ip of $1 is $PORTIP"
        DEVICEID=`cat $PORTINFO | grep deviceId | sed -e "s/\"//g" -e "s/\,//g" -e "s/\ //g" | cut -d ":" -f2`
        Info "[port] deviceid of $1 is $DEVICEID"

}

function get_rport_info()
{
        PORTMAC=$(cat $PORTINFO|grep mac| head -n 1 | sed -e "s/\"//g" -e "s/\ //g" -e "s/mac://g" -e "s/\,//g")
        exit_str_null "cannot find mac of $1 from curdetail cache" $PORTMAC
        Info "[port] mac of $1 is $PORTMAC"

        PORTIP=`cat $PORTINFO | grep $PORTMAC -B 1 | grep fixedip | sed -e "s/\"//g" -e "s/\,//g" -e "s/\ //g" -e "s/\,//g" | cut -d ":" -f2`
        PORTIP=$(echo $PORTIP | awk '{print $1}')
        exit_str_null "cannot find ip of $1 from curdetail cache" $PORTIP
        Info "[port] ip of $1 is $PORTIP"

}

function check_vm_ports()
{
    local port_names=""
    local vm=""

    port_names=$(cat $SUBNETDETAIL | grep $VMID -A 10 | grep -wi id | awk '{print $2}' | sed -e "s/\"//g" -e "s/\,//g")
    exit_str_null "[port] device $VMID is not exist" $port_names

    Info "[port] ports of $VMID are: $port_names"
    for port in  $port_names
    do
        Info "[port] check port: $port"
        PORTID=$port
        check_port $port
        init_env
    done
}

function check_port_socket()
{
    state=$(ss | grep $PORTID | awk '{print $2}')
    if [ "$state" != "ESTAB" ];then
        Error "port $PORTID sock stat is not establish, state: $state"
    fi
}

function check_port_cache()
{

        portinfo=`cat $PORTINFO`
        targetPort=$(echo ${1/port-/port_})

        local portnum=`cat $PORTINFO | grep $targetPort | wc -l`
        if [ $portnum -ne 1 ];then
                EError "the num of $1 is not correct, num: $portnum"
        fi

        #local macnum=`cat $PORTINFO | grep $PORTMAC | wc -l`
        #if [ $macnum -ne 1 ];then
        #        EError "the num of $1 mac $PORTMAC is not correct, num: $macnum"
        #fi

        #local ipnum=`cat $PORTINFO | grep ${PORTIP} | wc -l`
        #if [ $ipnum -ne 1 ];then
        #        EError "the num of $1 ip $PORTIP is not correct, num: $ipnum"
        #fi
}

# diff flow in cache and runtime
function check_port_flow_cache()
{
        local expect_flows=`ccc ovs-flows-detail --ids $1 | grep "cookie=0x" | sed  's/[ \t]//g' | sed 's/^.*\(cookie=0x[0-9a-f]\+\)\(,.*\)$/\1\2/'`
        local runtime_flows=`cat $DUMPFLOWPATH | grep "cookie=0x" | sed  's/[ \t]//g' | sed 's/^.*\(cookie=0x[0-9a-f]\+\)\(,.*\)$/\1\2/'`
        # map for flows, map[cookie=xxx] = flow
        local runtime_flow_map=()

        for flow in $runtime_flows;
        do
            runtime_flow_map["${flow%%,*}"]="$flow"
        done

        Info "expect `echo $expect_flows | wc -w` flows"
        for flow in $expect_flows;
        do
            local cookie="${flow%%,*}"
            if [[ "X${runtime_flow_map[$cookie]}" == "X" ]]; then
                Error "'$flow' not exist"
            fi
        done
}

function printinfo()
{
        echo ""
        echo "================================= PortInfo ======================================="
        echo "MAC of $PORTID         : $PORTMAC"
        echo "IP of $PORTID          : $PORTIP"
        echo "Gateway MAC of $PORTID : $GWMAC"
        echo "Gateway IP of $PORTID  : $GWIP"
        echo "================================= PortInfo ======================================="
        echo ""
}
check_dpdk_port_virtio_user()
{
        init_env
        init_cache
        dumpflows
        check_port_host
        get_subnet_param
        check_bridge_phy_flow
        check_subnet_flow
        if [ $TYPE -eq 0 ];then
            get_lport_info $1
            check_port_cache $1
            get_ofport $PORTID
            check_host
            check_drop_flow
            check_dpdk_lport_flow
            check_group_flow $VNI "output"
            printinfo
        fi
        if [ $TYPE -eq 1 ];then
            get_rport_info $1
            check_port_cache $1
            check_host
            check_rport_flow
        fi
        clean
}

check_dpdk_port()
{
        init_env
        init_cache
        dumpflows
        check_port_host
        get_subnet_param
        check_bridge_phy_flow
        check_subnet_flow
        if [ $TYPE -eq 0 ];then
            get_lport_info $1
            check_port_cache $1
            get_ofport $PORTID
            check_host
            check_port_socket
            check_drop_flow
            check_dpdk_lport_flow
            check_group_flow $VNI "output"
            printinfo
        fi
        if [ $TYPE -eq 1 ];then
            get_rport_info $1
            check_port_cache $1
            check_host
            check_rport_flow
        fi
        clean
}

check_kernel_port()
{
        init_env
        init_cache
        dumpflows
        check_port_host
        get_subnet_param
        get_subnet_hg
        get_hg_host
        check_subnet_flow
        if [ $TYPE -eq 0 ];then
            get_lport_info $1
            check_port_cache $1
            check_port_flow_cache $1
            get_ofport $PORTID
            check_host
            check_drop_flow
            check_lport_flow
            check_group_flow $VNI "output"
            printinfo
        fi
        if [ $TYPE -eq 1 ];then
            get_rport_info $1
            check_port_cache $1
            check_port_flow_cache $1
            check_host
            check_rport_flow
        fi
        #clean
}

function check_nlb_flow()
{
    Info "[check_nlb_flow] check_nlb_flow by subnet-detail"
    #echo "NlbMetadata=     " $NlbMetadata
    #echo "TargetMetadata=  " $TargetMetadata
    #echo "TargetIp=        " $TargetIp
    #echo "TargetPort=      " $TargetPort
    #echo "TargetMac=       " $TargetMac
    #echo "VIPUINT32=       " $VIPUINT32
    #echo "NlbProStr=       " $NlbProStr
    
    tmHex=$(echo "0x"`echo "obase=16;${TargetMetadata}"|bc`)
    vmHex=$(echo "0x"`echo "obase=16;${NlbMetadata}"|bc`)
    #echo "TargetMetadataHex=  " $tmHex
    #echo "NlbMetadataHex=     " $vmHex

    #DNAT flow
    # table=43, priority=100,tcp,reg11=0,metadata=0x67,dl_src=00:00:60:00:00:00/00:ff:ff:00:00:00,dl_dst=fa:16:3e:01:03:04,nw_dst=192.168.2.5,tp_dst=80 actions=set_field:fa:16:3e:00:00:00/ff:ff:ff:00:00:00->eth_src,move:NXM_OF_ETH_SRC[]->NXM_NX_XXREG0[64..111],move:NXM_OF_IP_DST[]->NXM_NX_XXREG0[0..31],move:NXM_OF_TCP_DST[]->NXM_NX_XXREG0[32..47],set_field:0x66->metadata,set_field:fa:16:3e:01:02:00->eth_dst,set_field:192.168.3.4->ip_dst,set_field:96->tcp_dst,set_field:0x1->reg11,goto_table:45
    checkout_table_flow 43 "tcp,reg11=0,metadata=$tmHex,nw_dst=$VIP,tp_dst=$VPORT"

    if [ "$TargetMetadata" == "$NlbMetadata" ];then
                #SNAT flow
                # table=43, priority=100,tcp,reg2=0x50,reg3=0xc0a80205,reg11=0x1,metadata=0x67,nw_src=192.168.3.4,tp_src=96 actions=move:NXM_NX_XXREG0[0..31]->NXM_OF_IP_SRC[],move:NXM_NX_XXREG0[32..47]->NXM_OF_TCP_SRC[],set_field:fa:16:3e:00:03:00->eth_dst,set_field:0x2->reg11,goto_table:45
                checkout_table_flow 43 "tcp,reg11=0x1,metadata=$tmHex,nw_src=$TargetIp,tp_src=$TargetPort"
    else
        #SNAT flow
        # priority=100, metadata=0x0000000003, reg3=uint32(vip), reg2=vport, reg6=0x10, nw_src=TargetIp, tcp, tp_src=targetPort, reg11=0x1,
        # action=set_field:00:check ping vip flow by subnet detail00:00:03:01->dl_dst,set_field:0x2->reg11,goto_table:l2_lookup
        checkout_table_flow 43 "tcp,reg11=0x1,metadata=$tmHex,nw_src=$TargetIp,tp_src=$TargetPort"
        #priority=100, metadata=0x0000000003, reg3=uint32(vip), reg2=vport, reg6=0x10, nw_src=TargetIp, tcp, tp_src=targetPort, reg11=0x1,
        #action=set_field:00:00:00:00:03:01->dl_dst,move:NXM_NX_XXREG0[0..31]->NXM_OF_IP_SRC[], move:NXM_NX_XXREG0[32..47]->NXM_OF_TCP_SRC[], set_field:0x2->reg11,goto_table:l2_lookup
        checkout_table_flow 43 "tcp,reg11=0x3,nw_src=$TargetIp"
    fi

        #special route item
        #table=100, priority=1000,ip,reg3=0xc0a80121,reg5=0x260,reg11=0x2 actions=set_field:fa:16:3e:a1:61:56->eth_dst,set_field:fa:16:3e:08:85:db->eth_src,set_field:0x3->reg11,write_metadata:0x26000000001,goto_table:120

        checkout_table_flow 100 "reg11=0x2,$VMAC"
}

function check_bnlb_flow()
{

    Info "[check_bnlb_flow] check_bnlb_flow by router-detail"
    #echo "********************************************************"
    #echo "NlbMetadata=" $NlbMetadata
    #echo "VIP=        " $VIP
    #echo "VPORT=      " $VPORT
    #echo "VMAC=       " $VMAC
    #echo "NlbProStr=  " $NlbProStr
   
    mHex=$(echo "0x"`echo "obase=16;${NlbMetadata}"|bc`) 
    # table=45, metadata=0x2a2300000002,dl_dst=fa:16:3e:48:a5:70 actions=resubmit(,47)
    checkout_table_flow 45 "metadata=$mHex,dl_dst=$VMAC"
    
    # table=47,tcp,metadata=0x67800000001,nw_dst=192.168.111.3,tp_dst=12345 actions=group:31128387
    checkout_table_flow 47 "$NlbProStr,metadata=$mHex,nw_dst=$VIP,tp_dst=$VPORT"
}

function check_bnlb_group()
{
    Info "[check_bnlb_group] check_bnlb_group by router-detail"
    BnlbTarIps=$(jq .nlbRules[$1].ips $TMP2 | sed 's/\[//g' | sed 's/\]//g')
    ipArray=(${BnlbTarIps//,/ })
    for BnlbTargetIp in ${ipArray[@]}
    do
        # ip is exclusive in one vpc
        #echo "BnlbTargetIp=" $BnlbTargetIp
        bm=$(cat $TMP1 | jq .subnets| grep $BnlbTargetIp -A1 )
        #echo "=================bm = " $bm
        
        BnlbMac=$(echo ${bm#*,} | cut -d \" -f 4)
        #echo "GROUPID=    " $GROUPID
        #echo "BnlbMac=    " $BnlbMac    
        # group_id=27304765,type=select,selection_method=hash,fields=ip_src,bucket=bucket_id:1,actions=set_field:fa:16:3e:73:83:1b->eth_dst,resubmit(,45)
        check_group_flow $GROUPID $BnlbMac

        #m=$(jq .subnets $TMP1 | grep $BnlbSUBNETID -A1 | grep '"metadata":')
        #BnlbMetadata=$(echo m | jq .metadata)
        #echo "BnlbMetadata" BnlbMetadata   
        #check_group_flow $GROUPID $BnlbMetadata
   done 
}

function check_ping_vip_flow()
{
    Info "[nlb] check ping vip flow by subnet detail"
    # table=47,icmp,metadata=0x3f200000003,nw_dst=172.18.2.5 actions=resubmit(,26)
    vmHex=$(echo "0x"`echo "obase=16;${NlbMetadata}"|bc`)
    checkout_table_flow 47 "icmp,metadata=$vmHex,nw_dst=$VIP"
}

function check_nlb_by_router()
{
    Info "[nlb] get nlb info from cc_controller router detail"
    flag=0
    sed  "s/-/_/g" $ROUTERDETAIL > $ROUTERDETAIL2
    routerIds=$(cat $ROUTERDETAIL2 | grep router_ | sed '/id/d' | sed '/deviceId/d' | sed 's/: {//g' | sed 's/"//g')
    nlbId=(${NLBID/nlb-/nlb_})
    for r in $routerIds
    do
        result=$(cat $ROUTERDETAIL2 | jq .$r | grep $nlbId)
        if [ "$result" == "" ];then
            continue
        fi
        echo > $TMP1
        cat $ROUTERDETAIL2 | jq .$r > $TMP1
        ROUTERID=$(echo $r)
        #load target router ==> $TMP1
        nlbs=$(jq .nlbs $TMP1)
        i=0
        for nlb in ${nlbs[*]}
        do
            #find target nlb 
            result2=$(jq .nlbs[$i] $TMP1 | grep $nlbId)
            if [ "$result2" == "" ];then
                let i+=1
                continue
            fi
            #load target nlb ==> $TMP2
            echo > $TMP2
            cat $TMP1 | jq .nlbs[$i] > $TMP2
            VIP=$(jq .ip $TMP2 | sed 's/"//g')
            VMAC=$(jq .mac $TMP2 | sed 's/"//g')
            NlbSUBNETID=$(jq .subnetId $TMP2 | sed 's/"//g')
            m=$(jq .subnets $TMP1 | grep $NlbSUBNETID -A1 | grep '"metadata":')
            NlbMetadata=$(echo ${m#*:} | sed 's/,//g')
            #echo "m=" $m
            #echo "NlbMetadata=" $NlbMetadata
            nlbRules=$(jq .nlbRules $TMP2)
            j=0
            for rule in $nlbRules
            do
                # handle rules one by one
                result3=$(jq .nlbRules[$j] $TMP2 | grep "port")
                if [ "$result3" == "" ];then
                    break
                fi
                VPORT=$(jq .nlbRules[$j].port $TMP2)
                GROUPID=$(jq .nlbRules[$j].groupId $TMP2)
                NlbProNum=$(jq .nlbRules[$j].protocol $TMP2)
                if [ "$NlbProNum" == "17" ];then
                    NlbProStr="udp"
                else
                    NlbProStr="tcp"
                fi
                check_bnlb_group $j
                check_bnlb_flow

                flag=1
                break
            done
            
            # only handle first match target nlb
            if [ "$flag" == "1" ];then
                break   
            fi
        done
        if [ "$flag" == "1" ];then
            break
        fi
    done
    if [ "$flag" == "0" ];then
        echo "nlb-id=" $NLBID
        EError "Can not found vip in router detail"
    fi
}

function ipV4ToUint32BigEndian()
{
        array=(${VIP//./ })
        echo "begin convert ipV4ToUint32BigEndian"
        for var in ${array[@]}
        do
           echo $var
        done 
}

function check_nlb_by_subnet()
{
    Info "[nlb] get nlb info from cc_controller by subnet detail"
    sed  "s/-/_/g" $SUBNETDETAIL > $SUBNETDETAIL2
    subnetIds=$(cat $SUBNETDETAIL2 | grep subnet_ | sed '/id/d' | sed '/subnetId/d' | sed 's/: {//g' | sed 's/"//g')
    flag=0
    get_underlayip
    for sn in ${subnetIds}
    do
        result=$(cat $SUBNETDETAIL2 | jq .$sn.nlbNats | grep $VIP)
        if [[ $result == "" ]];then
            continue
        fi
        TSUBNETID=$sn
        #load nlbNats array of target subnet ==> $TMP1
        echo > $TMP1
        cat $SUBNETDETAIL2 | jq .$TSUBNETID.nlbNats > $TMP1
        nlbNats=$(jq . $TMP1)
        i=0
        #foreach nlbnat
        for nlb in ${nlbNats[*]}
        do

        result0=$(jq .[$i] $TMP1 | grep '"nlbIp":')
        if [ "$result0" == "" ];then
            break
        fi
            result=$(jq .[$i] $TMP1 | grep "nlbIp" | grep $VIP)
            if [ "$result" == "" ];then
                let i+=1
                continue
            fi
            result1=$(jq .[$i] $TMP1 | grep "nlbPort" | grep $VPORT)
            if [ "$result1" == "" ];then
                let i+=1
                continue
            fi
            # load target nlbNat ==> $TMP2
            echo > $TMP2
            cat $TMP1 | jq .[$i] > $TMP2
            result2=$(cat $TMP2 | grep '"nlbPort":' | grep $VPORT)
            if [ "$result2" == "" ];then
                let i+=1
                continue
            fi
            result3=$(cat $TMP2 | grep '"protocol":' | grep $NlbProNum)
            if [ "$result3" == "" ];then
                let i+=1
                continue
            fi
            
            TargetIp=$(jq .targetIp $TMP2 | cut -d \" -f 2)
            flag=1
            #if not local port continue
            portHost=$(cat $SUBNETDETAIL2 | jq .$sn.ports| grep $TargetIp -A100 | grep 'host' -m1 | cut -d \" -f 4)
            if [ "$portHost"x != "$UNDERLAYIP"x ];then
                let i+=1
                continue
            fi
            TargetPort=$(jq .targetPort $TMP2 | cut -d \" -f 2)
            TargetMetadata=$(jq .targetMetadata $TMP2 | cut -d \" -f 2)
            TargetMac=$(jq .targetMac $TMP2 | cut -d \" -f 2)
            if [ "$flag" == "0" ];then
                ipV4ToUint32BigEndian
                check_ping_vip_flow
            fi
        echo "============ check nlbnat by subnetdetail =============="
        cat $TMP2
        check_nlb_flow
        let i+=1
        done
    done
    if [ "$flag" == "0" ];then
        echo "vip=" $VIP
        Error "can not find vip in subnet-detail "
    fi
}

function check_nlb()
{
    init_env
    dumpflows
    check_nlb_by_router
    check_nlb_by_subnet
}

check_port()
{
     dptype=`cat $CCC_CONFIG | grep -i DatapathType| cut -d ":" -f2 | cut -d"\"" -f2`
     Info "[system] type of datapath type is $dptype"
     if [ "$dptype" == ${DPTYPEOVSDPDK} ];then
         check_dpdk_port $PORTID
     elif [ "$dptype" == ${DPTYPEKERNEL} ];then
         check_kernel_port $PORTID
     elif [ "$dptype" == ${DPTYPEOVSDPDKVIRTIOUSER} ];then
         check_dpdk_port_virtio_user $PORTID
     else
         EError "datapath type $dptype is error in config file"
     fi
}

main()
{
    file_check

    mkdir -p $PATHINFO
    $CC subnet-detail > $SUBNETDETAIL
    $CC router-detail > $ROUTERDETAIL
    $CC hostgroup-detail > $HGDETAIL

    if [ $# -ne 2 -a $# -ne 1 ];then
         help_usage
         exit
    fi
    if [ "$PORTID" != "" ];then
        check_port $PORTID
    fi

    if [ "$VMID" != "" ];then
        check_vm_ports
    fi

    if [ "$NLBID" != "" ];then
        check_nlb
    fi
    if [ "$CHECK_SETUP" != "" ];then
        checkSetupFlow
    fi
}

main $*


