#!/bin/bash


DC[1]="172.19.27.84"  #华北
DC[2]="172.19.43.77"  #华东
DC[3]="172.27.13.100"  #华南
DC[4]="192.168.187.14"  #黄村

VLUMIP[1]="172.19.27.86"  #华北
VLUMIP[2]="172.19.41.214" #华东
VLUMIP[3]="172.27.13.81"  #华南
VLUMIP[4]="192.168.187.14" #黄村


PATHINFO="/tmp/cc-check"
VMFLAG=0

RED='\e[1;31m' 
NC='\e[0m'

PORTPINGLIST="8.8.8.8,114.114.114.114"
INATPINGLIST=""
PINGCOUNT=1
TIMEOUT=10

OPENRC="/root/huxining/cc_openrc"
CONTROLLER_CONFIG="export CCC_CONFIG_FILE=/etc/cc_controller/controller_config.json"
INATCONTROLLER_CONFIG="export CCC_CONFIG_FILE=/etc/cc_controller/inat.json"
#CHECKOPTION="compute"

ERRORS=""


function perror()
{
    echo -e "${RED} ===============================Error=================================== \n Error: $@ ${NC}"
#    echo -e "${RED} Error: $@ ${NC}"
    ERRORS="${ERRORS}\n ${RED} Error: $@ ${NC}\n"
    exit 1
}

function pnerror()
{
    echo -e "${RED} ===============================Error=================================== \n Error: $@ ${NC}"
    #echo -e "${RED} Error: $@ ${NC}"
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
    if [ -d $PATHINFO ];then
        rm -rf $PATHINFO
    fi
}

function comparestr()
{
    if [ "$2" == "$3" ];then
        perror "$1"
    fi
}

function ncomparestr()
{
    if [ "$2" != "$3" ];then
        perror "$1"
    fi
}

function encomparestr()
{
    if [ "$2" != "$3" ];then
        pnerror "$1"
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

function help_usage()
{
     echo ""
     echo "help usage:"
     echo ""
     echo -e "\t-d:         dc name, current support: huabei, huanan, huadong, huangcun"
     echo -e "\t-v:         vm id"
     echo -e "\t-f:         floatingip address"
     echo -e "\t-p:         special ping ip adddress, example 8.8.8.8,114.114.114.114"
     echo -e "\t-c:         special ping count, default 1"
     echo -e "\t-o:         check controller runtime data, default none, current suppport, compute, inat, all"
     echo -e "\t-t:         tenant id, check all vm in tenant"
     echo -e "\t-h:         help info"

     echo ""
     echo -e "\texample1: sh $0 -d huabei -f 112.12.5.12 -o compute -p 61.135.169.125,111.206.231.1 -c 5"
     echo -e "\texample2: sh $0 -d huabei -v bb9b8fab-758b-42fc-ad22-a1f98ac80717 -o compute"
     echo ""
     exit 1
}

while getopts "d:o:f:v:p:c:t:h" arg
do
        case $arg in
             d)
                DCNAME=$OPTARG
                ;;
             f)
                FLOATINGIP=$OPTARG
                ;;
             v)
                VMID=$OPTARG
                VMFLAG=1
                ;;
             p)
                PINGLIST=$OPTARG
                ;;
             c)
                PINGCOUNT=$OPTARG
                ;;
             o)
                CHECKOPTION=$OPTARG
                ;;
             t)
                TENANTS=$OPTARG
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

function paraseargs()
{
    if [ "$DCNAME" == "huabei" ];then
        SERVERIP=${DC[1]}
        FLOATINGIPPING=${VLUMIP[1]}
        export CC_SERVER_URL="http://cc-server.bj02.jcloud.com/cc-server"
    elif [ "$DCNAME" == "huadong" ];then
        SERVERIP=${DC[2]}
        FLOATINGIPPING=${VLUMIP[2]}
        export CC_SERVER_URL="http://cc-server.sq02.jcloud.com/cc-server"
    elif [ "$DCNAME" == "huanan" ];then
        SERVERIP=${DC[3]}
        FLOATINGIPPING=${VLUMIP[3]}
        export CC_SERVER_URL="http://cc-server.gz02.jcloud.com/cc-server"
    elif [ "$DCNAME" == "huangcun" ];then
        SERVERIP=${DC[4]}
        FLOATINGIPPING=${VLUMIP[4]}
        export CC_SERVER_URL="http://192.168.187.14:9698/cc-server"
    else
        perror "must special valid DCNAME, example: huabei, huadong, huanan, huangcun"
    fi

    if [ "$FLOATINGIP" == "" -a "$VMID" == "" -a "$TENANTS" == "" ];then
        perror "must special valid tenant id, vm id or floatingip"
    fi

    if [ "$CHECKOPTION" == "compute" -o "$CHECKOPTION" == "all" -a "${PINGLIST}" != "" ];then
        if [ "${PINGLIST}" != "" ];then
            PORTPINGLIST=${PINGLIST}
        fi
    fi
    if [ "$CHECKOPTION" == "inat" -o "$CHECKOPTION" == "all" -a "${PINGLIST}" != "" ];then
        if [ "${PINGLIST}" != "" ];then
            INATPINGLIST=${PINGLIST}
        fi
    fi
}

function sshcmd ()
{
    #ssh root@$SERVERIP source '/root/huxining/cc_openrc;'$@''
    timeout "${TIMEOUT}s" ssh -o StrictHostKeyChecking=no root@$SERVERIP source ''$OPENRC';'$@''
}

function scmd ()
{
    timeout "${TIMEOUT}s" ssh -o StrictHostKeyChecking=no root@$HOSTIP ''$CONTROLLER_CONFIG';'$@''
}

function sshvcmd ()
{
    timeout "${TIMEOUT}s" ssh -o StrictHostKeyChecking=no root@$FLOATINGIPPING $@
}

function sinatcmd ()
{
    timeout "${TIMEOUT}s" ssh -o StrictHostKeyChecking=no root@$INATMNGIP ''$CONTROLLER_CONFIG';'$@''
}

function init_env()
{
    clean
    mkdir $PATHINFO 2> /dev/null
}

function ping_check()
{
    local r=""

    r=$(ssh -o StrictHostKeyChecking=no root@$FLOATINGIPPING ping -i 0.1 -c 5 -W 1 $1 | grep 'packet loss' | awk -F'packet loss' '{ print $1 }' | awk '{ print $NF }' | sed 's/%//g')
    if [ "${r}" != "0" ];then
         pnerror "ping $1 failed"
         return
    fi

    pinfo "can ping $1, result is OK"
}

function check_server_floatingip()
{
    pcheck "================ cc-server floatingip $FLOATINGIP info ============"
    #sshcmd ccs floatingip-list -a --floatingip_address=$FLOATINGIP | grep fip  > "$PATHINFO/fiplist"
    ccs floatingip-list -a --floatingip_address=$FLOATINGIP | grep fip  > "$PATHINFO/fiplist"
    COUNT=$(cat $PATHINFO/fiplist | wc -l)
    ncomparestr "floatingip $FLOATINGIP is not exist or more floatingip binding " $COUNT "1"

    FIPID=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $2}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "id of fip $FLOATINGIP is $FIPID"

    FIPROVIDER=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $4}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "provider of fip $FLOATINGIP is $FIPROVIDER"

    FIP=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $5}' | sed -e "s/\ //g" -e "s/\"//g")

    PORTID=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $7}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "floatingip $FLOATINGIP may not bind port" $PORTID
    pinfo "binding port of fip $FLOATINGIP is $PORTID"

    FIPFIXEDIP=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $6}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "floatingip $FLOATINGIP may not bind fixedip" $FIPFIXEDIP
    pinfo "binding fixedip of fip $FLOATINGIP is $FIPFIXEDIP"

    BWIN=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $8}' | sed -e "s/\ //g" -e "s/\"//g")
    check_str_null "floatingip $FLOATINGIP bandwidth in is null" $BWIN
    comparestr "bwin of floatingip $FLOATINGIP is zero" $BWIN 0
    pinfo "bandwidthin of fip $FLOATINGIP is ${BWIN} Mb"

    BWOUT=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $9}' | sed -e "s/\ //g" -e "s/\"//g")
    check_str_null "floatingip $FLOATINGIP bandwidth out is null" $BWOUT
    comparestr "bwout of floatingip $FLOATINGIP is zero" $BWOUT 0
    pinfo "bandwidthout of fip $FLOATINGIP is ${BWOUT} Mb"

    #sshcmd ccs floatingip-show -a $FIPID > "$PATHINFO/fip"
    ccs floatingip-show -a $FIPID > "$PATHINFO/fip"
    ADMINSTATUS=$(cat $PATHINFO/fip | grep admin_status_up | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    ncomparestr "admin status of floatingip $FLOATINGIP is $ADMINSTATUS" $ADMINSTATUS "true"
    pinfo "admin status of fip $FLOATINGIP is $ADMINSTATUS"

    SUBNETID=$(cat $PATHINFO/fip | grep -w subnet_id | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "subnet of $PORTID is null" $SUBNETID
    pinfo "subnet of $PORTID is $SUBNETID"
    echo -e "\n\n"
}

function check_server_sg()
{
    if [ "$FLOATINGIP" != "" ];then
        python /home/dev/sdn_net_tool/sdn_check/main.py security-check --tenant_id $TENANTID --floatingip $FLOATINGIP
        python /home/dev/sdn_net_tool/sdn_check/main.py vr-check --tenant_id $TENANTID --floatingip $FLOATINGIP
    else
        pinfo "port $PORTID or vm $VMID may not bind floatingip"
    fi
}

function check_server_inat_sg()
{
    pcheck "================== cc-server inat floatingip security group ========================"
    if [ "$INATINTIP" != "" ];then
        python /home/dev/sdn_net_tool/sdn_check/main.py security-check --tenant_id $TENANTID --floatingip $INATINTIP
        python /home/dev/sdn_net_tool/sdn_check/main.py vr-check --tenant_id $TENANTID --floatingip $INATINTIP
    else
        pinfo "port $INATPORTID may not bind floatingip"
    fi
}
function show_server_port_sgs()
{
    for sg in `echo $1 | sed -e "s/\,/\ /g"`
    do
          pinfo "sg $sg rules:"  
          #sshcmd ccs security-group-rule-list -a --securitygroup-id $sg > "$PATHINFO/$sg"
          ccs security-group-rule-list -a --securitygroup-id $sg > "$PATHINFO/$sg"
          cat $PATHINFO/$sg| grep $sg | sed -e "s/|/\ /g"  | sed -e 's/  \+/ /g'
    done
}

function check_server_port()
{
    pcheck "================ cc-server port $PORTID info ============"
    #sshcmd ccs port-show -a $PORTID > "$PATHINFO/port"
    ccs port-show -a $PORTID > "$PATHINFO/port"
    PORTSTATUS=$(cat $PATHINFO/port | grep -w State | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "state of port $PORTID is null" $PORTSTATUS
    ncomparestr "state of port $PORTID is down" $PORTSTATUS "up"
    pinfo "state of port $PORTID is $PORTSTATUS"

    VMID=$(cat $PATHINFO/port | grep -w DeviceId | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "vmid of port $PORTID is null" $VMID
    pinfo "vmid of port $PORTID is $VMID"

    FIXEDIP=$(cat $PATHINFO/port | grep -w FixedIps | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\]//g" -e "s/\[//g" -e "s/\"//g")
    exit_str_null "ip of port $PORTID is null" $FIXEDIP
    pinfo "ip of port $PORTID is $FIXEDIP"

    TENANTID=$(cat $PATHINFO/port | grep -w TenantId | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "tenant of port $PORTID is null" $TENANTID
    pinfo "tenant of port $PORTID is $TENANTID"

    HOSTID=$(cat $PATHINFO/port | grep -w HostIds | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\]//g" -e "s/\[//g" -e "s/\"//g")
    exit_str_null "host of port $PORTID is null" $HOSTID
   
    PORTMAC=$(cat $PATHINFO/port | grep -w MacAddress | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "mac of port $PORTID is null" $PORTMAC
    pinfo "mac of port $PORTID is $PORTMAC"

    VPCID=$(cat $PATHINFO/port | grep -w VpcId | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "vpc of port $PORTID is null" $VPCID
    pinfo "vpc of port $PORTID is $VPCID"

    PORTYPE=$(cat $PATHINFO/port | grep -w Type | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "type of port $PORTID is null" $PORTYPE
    pinfo "type of port $PORTID is $PORTYPE"

    SGS=$(cat $PATHINFO/port | grep -w SecuritygroupIds | cut -d"|" -f3 | sed -e "s/\ //g" -e "s/\"//g" -e "s/\]//g" -e "s/\[//g")
    exit_str_null "security group of port $PORTID is null" $SGS
    pinfo "security group of port $PORTID is $SGS"
    show_server_port_sgs $SGS
    echo -e "\n\n"

    check_server_sg
    echo -e "\n\n"
}


function check_server_host()
{
    CHECKHOSTID=$1
    HOSTTYPE=$2
    #sshcmd ccs host-show -a $CHECKHOSTID > "$PATHINFO/host"
    ccs host-show -a $CHECKHOSTID > "$PATHINFO/host"

    HOSTMNGIP=$(cat $PATHINFO/host | grep -w MgmtAddr| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "manager ip of $HOSTTYPE  host $CHECKHOSTID for $PORTID is null" $HOSTMNGIP
    pinfo "managet ip of $HOSTTYPE host $CHECKHOSTID for $PORTID is $HOSTMNGIP"
    if [ "$HOSTTYPE" == "inat"  ];then
        INATMNGIP=$HOSTMNGIP
    fi

    HOSTUNIP=$(cat $PATHINFO/host | grep -w Underlay | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "underlay ip of $HOSTTYPE host $CHECKHOSTID for $PORTID is null" $HOSTUNIP
    pinfo "underlay ip of $HOSTTYPE host $CHECKHOSTID for $PORTID is $HOSTUNIP"


    HOSTADMINSTATUS=$(cat $PATHINFO/host | grep -w AdminStatus | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "admin status of $HOSTTYPE host $CHECKHOSTID is null" $HOSTADMINSTATUS
    ncomparestr "admin status of $HOSTTYPE host $CHECKHOSTID is $HOSTADMINSTATUS" $HOSTADMINSTATUS "up"
    pinfo "admin status of $HOSTTYPE host $CHECKHOSTID for $PORTID is $HOSTADMINSTATUS"

    HOSTSTATUS=$(cat $PATHINFO/host | grep -w Status | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "status of $HOSTTYPE host $CHECKHOSTID is null" $HOSTSTATUS
    ncomparestr "status of $HOSTTYPE host $CHECKHOSTID is $HOSTSTATUS" $HOSTSTATUS "up"
    pinfo "status of $HOSTTYPE host $CHECKHOSTID for $PORTID is $HOSTSTATUS"
    echo -e "\n\n"
}
function check_server_subnet_acl()
{
    pcheck "================ cc-server acl $ACL for subnet $SUBNETID info ============"
    #sshcmd ccs acl-rule list -a $ACL > "$PATHINFO/acl"
    ccs acl-rule list -a $ACL > "$PATHINFO/acl"
    cat $PATHINFO/acl
}

function check_server_subnet_rtabble()
{
    local RTID=$1
    local SUBNET=$2
    pcheck "================ cc-server router table $RTID info ============"
    ccs route-list -a $RTID > "$PATHINFO/rtable"
    cat $PATHINFO/rtable |grep "rt-" |sed -e "s/|//g" 

    RTDETAIL=$(cat $PATHINFO/rtable| grep "0.0.0.0/0" | grep -w internet | sed -e "s/|//g" -e 's/  \+/ /g' )
    check_str_null "internet route table of subnet $SUBNET is null" $RTDETAIL
    pinfo "internet route table of $SUBNET : $RTDETAIL"
    echo -e "\n\n"
    
}
function check_server_subnet()
{
    pcheck "================ cc-server subnet $SUBNETID info ============"
    #sshcmd ccs subnet-show -a $SUBNETID > "$PATHINFO/subnet"
    ccs subnet-show -a $SUBNETID > "$PATHINFO/subnet"

    GWIP=$(cat $PATHINFO/subnet| grep -w gateway_ip| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "gwip of subnet $SUBNETID for $PORTID is null" $GWIP
    pinfo "gwip of subnet $SUBNETID for $PORTID is $GWIP"

    GWMAC=$(cat $PATHINFO/subnet| grep -w gateway_mac| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "gwmac of subnet $SUBNETID for $PORTID is null" $GWMAC
    pinfo "gwmac of subnet $SUBNETID for $PORTID is $GWMAC"


    ACL=$(cat $PATHINFO/subnet| grep -w acl_id| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    if [ "$ACL" == "" ];then
        pinfo "acl of subnet $SUBNETID for $PORTID is null"
    else
        pinfo "acl of subnet $SUBNETID for $PORTID is $ACL"
        check_server_subnet_acl
    fi

    RTABLE=$(cat $PATHINFO/subnet| grep -w route_table_id | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "router table id of subnet $SUBNETID for $PORTID is null" $RTABLE
    pinfo "router table id of subnet $SUBNETID for $PORTID is $RTABLE"

    echo -e "\n\n"
    check_server_subnet_rtabble $RTABLE $SUBNETID

}

function check_server_inatport()
{
    pcheck "================ cc-server inatport $VPCID info ============"
    #sshcmd ccs natport-list -a --vpc-id=$VPCID | grep $VPCID  > "$PATHINFO/inatlist"
    ccs natport-list -a --vpc-id=$VPCID | grep $VPCID  > "$PATHINFO/inatlist"

    INATCOUNT=$(cat $PATHINFO/inatlist | wc -l)
    ncomparestr "inat port of $VPCID is not exist or more floatingip binding " $INATCOUNT "1"

    INATPORTID=$(cat $PATHINFO/inatlist | awk -F"|"  '{print $6}')
    pinfo "inat portid of $VPCID is $INATPORTID"

    #sshcmd ccs port-show -a $INATPORTID  > "$PATHINFO/inatport"
    ccs port-show -a $INATPORTID  > "$PATHINFO/inatport"
    INATPORTSTATUS=$(cat $PATHINFO/inatport | grep -w State | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "status of inatport $INATPORTID is null" $INATPORTSTATUS
    ncomparestr "status of inatport $INATPORTID is false" $INATPORTSTATUS "up"
    pinfo "status of inatport $INATPORTID is $INATPORTSTATUS"

    INATFIXEDIP=$(cat $PATHINFO/inatport | grep -w FixedIps | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\]//g" -e "s/\[//g" -e "s/\"//g")
    exit_str_null "fixedip of inatport $INATPORTID is null" $INATFIXEDIP
    pinfo "fixedip of inatport $INATPORTID is $INATFIXEDIP"

    INATHOSTID=$(cat $PATHINFO/inatport | grep -w HostIds | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\]//g" -e "s/\[//g" -e "s/\"//g")
    exit_str_null "host of inatport $INATPORTID is null" $INATHOSTID
    pinfo "host of inatport $INATPORTID is $INATHOSTID"

    INATSUBNETID=$(cat $PATHINFO/inatport | grep -w SubnetId | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\]//g" -e "s/\[//g" -e "s/\"//g")
    exit_str_null "subnet of inatport $INATPORTID is null" $INATSUBNETID
    pinfo "subnet of inatport $INATPORTID is $INATSUBNETID"
   
    INATPORTMAC=$(cat $PATHINFO/inatport | grep -w MacAddress | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "mac of inatport $INATPORTID is null" $INATPORTMAC
    pinfo "mac of inatport $INATPORTID is $INATPORTMAC"

    INATPORTYPE=$(cat $PATHINFO/inatport | grep -w Type | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "type of inatport $INATPORTID is null" $INATPORTYPE
    pinfo "type of inatport $INATPORTID is $INATPORTYPE"

    INATSGS=$(cat $PATHINFO/inatport | grep -w SecuritygroupIds | cut -d"|" -f3 | sed -e "s/\ //g" -e "s/\"//g" -e "s/\]//g" -e "s/\[//g")
    exit_str_null "security group of inatport $INATPORTID is null" $INATSGS
    pinfo "security group of inatport $INATPORTID is $INATSGS"
    show_server_port_sgs $INATSGS
    echo -e "\n\n"

    echo "=================== cc-serever inat port $INATPORTID host info ================"
    check_server_host $INATHOSTID "inat"
}

function check_server_inat_subnet()
{
    pcheck "================ cc-server inat subnet $INATSUBNETID info ============"
    #sshcmd ccs subnet-show -a $SUBNETID > "$PATHINFO/subnet"
    ccs subnet-show -a $INATSUBNETID > "$PATHINFO/inatsubnet"

    INATGWIP=$(cat $PATHINFO/inatsubnet| grep -w gateway_ip| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "gwip of inat subnet $INATSUBNETID for $INATPORTID is null" $INATGWIP
    pinfo "gwip of inat subnet $INATSUBNETID for $INATPORTID is $INATGWIP"

    INATGWMAC=$(cat $PATHINFO/inatsubnet| grep -w gateway_mac| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "gwmac of inat subnet $INATSUBNETID for $INATPORTID is null" $INATGWMAC
    pinfo "gwmac of inat subnet $INATSUBNETID for $INATPORTID is $INATGWMAC"

    echo -e "\n\n"
}

function check_server_inatport_floatingip()
{
    
    pcheck "================ cc-server inatport internal ip $INATPORTID info ============"
    ccs floatingip-list -a --tenant-id=$TENANTID | grep $INATPORTID > "$PATHINFO/inatintlist"

    INATINTCOUNT=$(cat $PATHINFO/inatintlist | wc -l)
    if [ "$INATINTCOUNT" != "1" ];then
         pnerror "internal ip of inat port $INATPORTID is not exist or more internal ip binding "
         return
    fi

    INATINT=$(cat $PATHINFO/inatintlist | awk -F"|"  '{print $2}'| sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "fip id of inat port $INATPORTID is null" $INATINT
    pinfo "fip id of inat port $INATPORTID is $INATINT"

    INATINTROVIDER=$(cat $PATHINFO/inatintlist| awk -F"|"  '{print $4}')
    exit_str_null "provider of inat port $INATPORTID is null " $INATINTROVIDER
    pinfo "provider of inat port $INATPORTID is $INATINTROVIDER"

    INATINTIP=$(cat $PATHINFO/inatintlist | awk -F"|"  '{print $5}'| sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "fip of inat port $INATPORTID is null" $INATINTIP
    pinfo "fip of inat port $INATPORTID is $INATINTIP"

    INATINTBWIN=$(cat $PATHINFO/inatintlist | awk -F"|"  '{print $8}'| sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "bandwidthin of inat port $INATPORTID is null" $INATINTBWIN
    comparestr "bandwidthin of inat port $INATPORTID is  zero" $INATINTBWIN 0
    pinfo "bandwidthin of inat port $INATPORTID is ${INATINTBWIN} Mb"

    INATINTBWOUT=$(cat $PATHINFO/inatintlist | awk -F"|"  '{print $9}'| sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "bandwidthout of inat port $INATPORTID is null" $INATINTBWOUT
    comparestr "bandwidthout of inat port $INATPORTID is  zero" $INATINTBWOUT 0
    pinfo "bandwidthout of inat port $INATPORTID is ${INATINTBWOUT} Mb"
    echo -e "\n\n"

}

function compare_port()
{

    ncomparestr "nova hostip is $NOVAHOSTIP, but hostip of cc-server is $HOSTMNGIP" $NOVAHOSTIP $HOSTMNGIP

    ncomparestr "nova portid is $NOVAPORTID, but port id of cc-server is $PORTID" $NOVAPORTID $PORTID

    ncomparestr "nova ip is $NOVAFIXEDIP, but ip of cc-server is $FIXEDIP for $PORTID" $NOVAFIXEDIP $FIXEDIP

}

function check_server_nova()
{
    pcheck "================ nova vm $VMID info ============"
    sshcmd nova show $VMID > "$PATHINFO/vm"
    VMEXIST=$(cat $PATHINFO/vm | grep -w port_id)
    exit_str_null "vm $VMID is not exist" ${VMEXIST}

    VMVPCID=$(cat $PATHINFO/vm | grep -w vpc_id | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    check_str_null "vpc id of vm $VMID is null" $VMVPCID
    pinfo "vpc of vm $VMID is $VMVPCID"

    VMNAME=$(cat $PATHINFO/vm | grep -w name | awk -F"|" '{print $3}')
    pinfo "name of vm $VMID is ${VMNAME}"

    VMFLAVOR=$(cat $PATHINFO/vm | grep -w flavor | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    pinfo "flavor of vm $VMID is $VMFLAVOR"

    VMMETADATA=$(cat $PATHINFO/vm | grep -w metadata| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    pinfo "metadata of vm $VMID is $VMMETADATA"

    VMZONE=$(cat $PATHINFO/vm | grep -w availability_zone | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    pinfo "availability zone of vm $VMID is $VMZONE"

    VMSTATUS=$(cat $PATHINFO/vm | grep -w status | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    check_str_null "status of vm $VMID is null" $VMSTATUS
    ncomparestr "status of vm $VMID is $VMSTATUS" $VMSTATUS "active" "cat $PATHINFO/vm"
    pinfo "status of vm $VMID is $VMSTATUS"

    VMTASKSTATUS=$(cat $PATHINFO/vm | grep -w task_state | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    check_str_null "task status of vm $VMID is null" $VMTASKSTATUS
    encomparestr "task status of vm $VMID is $VMTASKSTATUS" $VMTASKSTATUS "-"
    pinfo "task status of vm $VMID is $VMTASKSTATUS"

    VMPOWERSTATUS=$(cat $PATHINFO/vm | grep -w power_state | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    check_str_null "power status of vm $VMID is null" $VMPOWERSTATUS
    encomparestr "power status of vm $VMID is $VMTASKSTATUS" $VMPOWERSTATUS "1"
    pinfo "power status of vm $VMID is $VMPOWERSTATUS"

    NOVAPORTID=$(cat $PATHINFO/vm | grep -w port_id| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "portid of vm $VMID is null" $NOVAPORTID
    pinfo "port_id of vm is $NOVAPORTID"

    NOVAHOSTIP=$(cat $PATHINFO/vm | grep -w host_ip | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "hostip of vm $VMID is null" $NOVAHOSTIP
    pinfo "hostip of vm is $NOVAHOSTIP"

    NOVAIPS=$(cat $PATHINFO/vm | grep -w network| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "ips of vm $VMID is null" $NOVAIPS

    VMIMAGE=$(cat $PATHINFO/vm | grep -w image | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "image of vm $VMID is $VMIMAGE"

    VMVOLUMES=$(cat $PATHINFO/vm | grep volumes_attached | cut -d"|" -f3 | sed -e "s/\[//g" -e "s/\]//g" -e "s/\"//g" -e "s/}//g" -e "s/{//g" -e "s/id://g" -e "s/\ //g")
    pinfo "attached volumes of vm $VMID is $VMVOLUMES"

    NOVAFIXEDIP=$(echo $NOVAIPS | cut -d"," -f1)
    NOVAFLOATINGIP=$(echo $NOVAIPS | cut -d"," -f2)
    
    exit_str_null "fixed ip of vm $VMID is null" $NOVAFIXEDIP
    pinfo "fixedip of vm $VMID is $NOVAFIXEDIP" 

    if [ "$NOVAFLOATINGIP" != "" ];then
        pinfo "floatingip of vm $VMID is $NOVAFLOATINGIP" 
    fi

    echo -e "\n\n"
}

function check_compute_host()
{

    echo "============== cc-serever compute port $PORTID host info ================"
    check_server_host $HOSTID "compute"
}

function check_floatingip()
{
    #check server
    check_server_floatingip
    check_server_port
    check_server_inatport
    check_server_inatport_floatingip
    check_server_inat_subnet
    check_compute_host
    check_server_subnet
    check_server_nova
    compare_port

    #check controller runtime data
   if [ "$CHECKOPTION" == "compute" -o "$CHECKOPTION" == "all" ];then
       check_compute_controller
   fi
   if [ "$CHECKOPTION" == "inat" -o "$CHECKOPTION" == "all" ];then
        show_route
        show_iptables_rule
        check_inat_controller
   fi
}

function check_vm()
{
   #check server
   check_server_nova
   PORTID=$NOVAPORTID 
   if [ "$NOVAFLOATINGIP" != "" ];then
       FLOATINGIP=$NOVAFLOATINGIP
       check_server_floatingip
   else
        pinfo "vm $VMID may not bind floatingip"
   fi
   check_server_port
   check_server_inatport
   check_server_inatport_floatingip
   check_server_inat_subnet
   check_compute_host
   check_server_subnet
   compare_port

   #check controller runtime data
   if [ "$CHECKOPTION" == "compute" -o "$CHECKOPTION" == "all" ];then
       check_compute_controller
   fi
   if [ "$CHECKOPTION" == "inat" -o "$CHECKOPTION" == "all" ];then
        show_route
        show_iptables_rule
        check_inat_controller
   fi
}

function show_iptables_rule()
{

    pcheck "================ cc-controller inat $INATPORTID host - iptable rules ============"
    sinatcmd ip netns exec $INATPORTID iptables-save
    echo -e "\n\n"
}

function show_route()
{

    pcheck "================ cc-controller inat $INATPORTID host - route table ============"
    sinatcmd ip netns exec $INATPORTID ip a
    echo -e "\n"
    sinatcmd ip netns exec $INATPORTID route  -n
    echo -e "\n\n"
}

function check_inat_controller()
{
    pcheck "================ cc-controller inat $INATPORTID host============"
    #check flow table
    sinatcmd ovs-runtime-check -p $INATPORTID
    echo -e "\n\n"

    pinfo "********************************** $INATFIXEDIP ping inatport gatewap ip $INATGWIP from inat host *************************************" 
    #ping inat port gateway ip
    sinatcmd ovs-ping-check -p $INATPORTID -d $INATGWMAC -w $INATFIXEDIP -x $INATGWIP -e $INATPORTID
    echo -e "\n\n"

    pinfo "********************************** $INATFIXEDIP ping inatport self floatingip $INATINTIP from inat host *************************************" 
    #ping inat port floatingip 
    sinatcmd ovs-ping-check -p $INATPORTID -d $INATGWMAC -w $INATFIXEDIP -x $INATINTIP -e $INATPORTID

    if [ "0" == "0" ];then
        local i=1
        local IP=""
        while true
        do 
           if [ $i -gt  $PINGCOUNT ];then
               break
           fi
           pinfo "current count $i of $PINGCOUNT"
           for IP in `echo $INATPINGLIST | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
           do
               echo -e "\n\n"
               pinfo "************************* $INATINTIP ping public ip: $IP ***********************************"
               sinatcmd ovs-ping-check -p $INATPORTID -d $INATGWMAC -w $INATFIXEDIP -x $IP
           done
           ((++i)) 
        done
    fi

}

function check_compute_controller()
{
    HOSTIP=$HOSTMNGIP
    pcheck "================ cc-controller host $HOSTIP compute  ============"
    #check flow table
    scmd ovs-runtime-check -p $PORTID

    pinfo "************************************* $FIXEDIP ping gateway ip $GWIP *************************************" 
    #ping gateway ip
    scmd ovs-ping-check -p $PORTID -d $GWMAC -w $FIXEDIP -x $GWIP

    echo -e "\n\n"
    pinfo "************************************* $FIXEDIP ping inatport ip $INATFIXEDIP *************************************" 
    #ping inat port fixed ip
    scmd ovs-ping-check -p $PORTID -d $GWMAC -w $FIXEDIP -x $INATFIXEDIP

    #ping pubnet network
    if [ "$FLOATINGIP" != "" ];then
        echo -e "\n\n"
        pinfo "***************************** $FLOATINGIP ping floatingip from volume node ***********************************" 
        #ping self floatingip 
        ping_check $FLOATINGIP

        echo -e "\n\n"
        pinfo "***************************** $FLOATINGIP ping self floatingip $FLOATINGIP ***********************************" 
        #ping self floatingip 
        scmd ovs-ping-check -p $PORTID -d $GWMAC -w $FIXEDIP -x $FLOATINGIP

        local i=1
        local IP=""
        while true
        do 
           if [ $i -gt  $PINGCOUNT ];then
               break
           fi
           echo -e "\n"
           pinfo "current count $i of $PINGCOUNT"
           for IP in `echo $PORTPINGLIST | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
           do
               echo -e "\n\n"
               pinfo "*********************** $FLOATINGIP  ping public ip $IP ********************************"
               scmd ovs-ping-check -p $PORTID -d $GWMAC -w $FIXEDIP -x $IP
           done
           ((++i)) 
        done
    else
        pinfo "port $PORTID or vm $VMID may not bind floatingip"
    fi

}

function get_tenant_vm()
{
    sshcmd nova list --tenant $1 > "$PATHINFO/vmlist"
    ERRORVMS=$(cat $PATHINFO/vmlist | grep -wi "active")
    if [ "$ERRORVMS" == "" ];then
         perror "not active status vm for tenant $1, $ERRORVMS"
    fi

    VMEXIST=$(cat $PATHINFO/vmlist | grep -wi "active")
    exit_str_null "vm $VMID is not exist for active status" ${VMEXIST}

    VMLIST=$(cat $PATHINFO/vmlist | grep -wi "active" | cut -d"|" -f2 | sed -e "s/\ //g")
    pinfo "vm list of tenant $1:"
    echo -e "$VMLIST"
}

function check_tenant()
{
        for t in `echo $TENANTS | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
        do
            pcheck "===============================tenant $t============================="
            get_tenant_vm $t
            echo $VMLIST | while read line;do echo -e "\n\n"; VMID=$line;check_vm;done
            echo -e "\n\n"
        done
}

main()
{

    if [ $# -lt 4 ];then
         help_usage
         exit
    fi

    paraseargs
    init_env

    if [ "$FLOATINGIP" != "" ];then
        check_floatingip
    fi

    if [ "$VMID" != "" -a "$VMFLAG" == "1" ];then
        check_vm
    fi

    if [ "$TENANTS" != "" ];then
        check_tenant
    fi
    echo -e "\n\n"
    echo -e ${ERRORS}
}

main $*

#tcpdump -i any -nnvv 'icmp[icmptype]==0'
