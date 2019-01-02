#!/bin/bash


declare -A CC_SERVER=()
declare -A DC=()
declare -A VLUMIP=()
declare -A SOURCENAME=()
declare -A VRLIST=()
declare -A DRLIST=()
declare -A IPLIST=()
declare -A INATFIXEDIPLIST=()
declare -A RCMD=()


#nova api 
DC["bj02"]="10.237.37.101"  #华北, 北京
DC["bj03"]="10.237.37.101"  #华北, 北京
DC["sh01"]="10.233.3.208"  #华东, 宿迁
DC["sh02"]="10.233.3.208"  #华东, 宿迁
DC["sq02"]="10.233.3.208"  #华东, 宿迁
#DC["huanan"]="172.27.13.100"  #华南, 广州
#DC["huangcun"]="192.168.187.14"  #黄村,
#DC["huadongtest"]="172.19.53.5"  #华东测试环境
#DC["distribute"]="172.19.53.166"  #华东测试环境


#volume node ping floatingip
VLUMIP["bj02"]="172.19.27.86"  #华北
VLUMIP["bj03"]="10.237.36.134"  #华北
VLUMIP["sq02"]="172.19.41.214" #华东
VLUMIP["sh01"]="10.233.34.41" #华东
VLUMIP["sh02"]="10.233.3.211" #华东
VLUMIP["gz02"]="172.27.13.81"  #华南
VLUMIP["alpha1"]="172.19.53.5"  #华南

#cc server address
#CC_SERVER["huabei"]="http://cc-server.bj02.jcloud.com/cc-server"
#CC_SERVER["huadong"]="http://cc-server.sq02.jcloud.com/cc-server"
#CC_SERVER["huanan"]="http://cc-server.gz02.jcloud.com/cc-server"
#CC_SERVER["huangcun"]="http://192.168.187.14:9698/cc-server"
#CC_SERVER["huadongtest"]="http://172.19.53.5:9698/cc-server"
#CC_SERVER["distribute"]="http://172.19.53.166:9698/cc-server"

#SOURCENAME["bj02"]="/export/Jcloud_UE/env/prod_bj02_jcloud"
#SOURCENAME["sq02"]="/export/Jcloud_UE/env/prod_sq02_jcloud"
#SOURCENAME["gz02"]="/export/Jcloud_UE/env/prod_gz02_jcloud"
#SOURCENAME["sh01"]="/export/Data/env/cn-east-2"
#SOURCENAME["alpha1"]="/home/dev/hu/alpha1"

SOURCENAME["bj02"]="/export/Data/env/cn-north-1"
SOURCENAME["bj03"]="/export/Data/env/cn-north-1"
SOURCENAME["sq02"]="/export/Data/env/cn-east-1"
SOURCENAME["gz02"]="/export/Data/env/cn-south-1"
SOURCENAME["sh01"]="/export/Data/env/cn-east-2"
SOURCENAME["sh02"]="/export/Data/env/cn-east-2"
SOURCENAME["alpha1"]="/home/dev/hu/alpha1"

RCMD["bj02"]="get_user_id_bj"
RCMD["bj03"]="get_user_id_bj"
RCMD["gz02"]="get_user_id_gz"
RCMD["gz03"]="get_user_id_gz"
RCMD["sq02"]="get_user_id_sq"
RCMD["sh01"]="get_user_id_sh"
RCMD["sh02"]="get_user_id_sh"

JVIRTRC="/root/jvirtrc"

DCMSG="bj02,bj03,sq02, gz02, sh01,sh02"

CHECK_VM="false"

DIRNAME=`date +%s`$RANDOM
PATHTMP="./tmp"
PATHINFO="$PATHTMP/tmp-$DIRNAME"

RED='\e[1;31m' 
NC='\e[0m'

PORTPINGLIST="8.8.8.8,114.114.114.114"
DNSSERVERIPS="103.224.222.222,103.224.222.223"
INATPINGLIST=""
PINGCOUNT=1
TIMEOUT=10

CONTROLLER_CONFIG="export CCC_CONFIG_FILE=/etc/cc_controller/controller_compute.json"
INATCONTROLLER_CONFIG="export CCC_CONFIG_FILE=/etc/cc_controller/inat.json"

BOARDCAST="FF:FF:FF:FF:FF:FF"

echo "temp file: $PATHINFO"

function perror()
{
    echo -e "${RED} ===============================Error=================================== \n Error: $@ ${NC}"
    clean
    exit 1
}

function pnerror()
{
    echo -e "${RED} ===============================Error=================================== \n Error: $@ ${NC}"
}

function pinfo()
{
    echo -e "Info: $@"
}

function pcheck()
{
    echo -e "Check: $@"
}

function clean()
{
    if [ "$FLOWSTC" == "2" ];then
         del_flow $FLOWIPS
         FLOWSTC=1
    fi
    alias rm='rm -rf'
    if [ -f $PATHINFO ];then
        rm -f $PATHINFO 2>&1 > /dev/null
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

trap 'printf "\n capture signal\n";clean' INT HUP ABRT QUIT KILL TERM

function help_usage()
{
     echo ""
     echo "help usage:"
     echo ""
     echo -e "\t-d:         dc name, current support: $DCMSG"
     echo -e "\t-v:         vm id"
     echo -e "\t-f:         floatingip address"
     echo -e "\t-p:         special ping ip adddress, example 8.8.8.8,114.114.114.114"
     echo -e "\t-c:         special ping count, default 1"
     echo -e "\t-s:         check vr/dr flow statistics"
     echo -e "\t-o:         check controller runtime data, default not check, current suppport: compute"
     echo -e "\t-t:         tenant id, check all vm in tenant"
     echo -e "\t-i:         check information of internal vm"
     echo -e "\t-P:         ping dns server,$PORTPINGLIST"
     echo -e "\t-h:         help info"

     echo ""
     echo -e "\texample1: 检查floatingip 112.12.5.12的配置和此fip绑定的VM所在的Host的流表信息:\n \t\t sh $0 -d bj02 -f 112.12.5.12 -o compute -p 61.135.169.125,111.206.231.1 -c 5\n"
     echo -e "\texample2: 检查VMID为bb9b8fab-758b-42fc-ad22-a1f98ac80717的网络配置，和此VM所在的Host的流表信息:\n \t\t sh $0 -d bj02 -v bb9b8fab-758b-42fc-ad22-a1f98ac80717 -o compute\n"
     echo -e "\texample3: 检查TENANTID为bb9b8fab-758b-42fc-ad22-a1f98ac80717下的所有VM的网络配置，和这些VM所在Host的流表信息:\n \t\t sh $0 -d bj02 -t bb9b8fab-758b-42fc-ad22-a1f98ac80717 -o compute\n"
     echo ""
     exit 1
}

while getopts "d:o:f:v:p:c:t:hsiP" arg
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
             i)
                CHECK_VM="true"
                ;;
             c)
                PINGCOUNT=$OPTARG
                ;;
             o)
                CHECKOPTION=$OPTARG
                ;;
             s)
                FLOWSTC=1
                ;;
             P)
                PINGFLAG=1
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
    if [ "$DCNAME" == "huangcun" ];then
        CONTROLLER_CONFIG="export CCC_CONFIG_FILE=/etc/cc_controller/compute.json"
    elif [ "$DCNAME" == "huadongtest" ];then
        CONTROLLER_CONFIG="export CCC_CONFIG_FILE=/etc/cc_controller/compute.json"
    fi

    FLOATINGIPPING=${VLUMIP[$DCNAME]}
    SOURCEFILE=${SOURCENAME[${DCNAME}]}

    source $SOURCEFILE
    
    CCSCMD="/home/dev/hu/ccs --server-url $CC_SERVER_URL"

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
function newsshcmd ()
{
    #ssh root@$SERVERIP source '/root/huxining/cc_openrc;'$@''
    #SERVERIP="${DC[$DCNAME]}"
    #timeout "${TIMEOUT}s" ssh -o StrictHostKeyChecking=no root@$SERVERIP source ''$JVIRTRC';'$@''
    bash $@
}


function scmd ()
{
    timeout "${TIMEOUT}s" ssh -o StrictHostKeyChecking=no root@$HOSTIP ''$CONTROLLER_CONFIG';'$@''
}

function sshexec()
{
    timeout "${TIMEOUT}s" ssh -o StrictHostKeyChecking=no root@$DPDKIP $@
}

function sinatcmd ()
{
    timeout "${TIMEOUT}s" ssh -o StrictHostKeyChecking=no root@$INATMNGIP ''$CONTROLLER_CONFIG';'$@''
}

function init_env()
{
    mkdir -p $PATHINFO 2> /dev/null
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
    local floatingip=$1
    pcheck "================ cc-server floatingip $floatingip info ============"
    ${CCSCMD} floatingip-list -a --floatingip_address=$floatingip | grep fip  > "$PATHINFO/fiplist"
    local count=$(cat $PATHINFO/fiplist | wc -l)
    ncomparestr "floatingip $floatingip is not exist or more floatingip binding " $count "1"

    local fipid=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $2}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "id of fip $floatingip is $fipid"

    local fiprovider=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $4}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "provider of fip $floatingip is $fiprovider"

    local portid=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $7}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "floatingip $floatingip may not bind port" $portid
    pinfo "binding port of fip $floatingip is $portid"

    local fixedip=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $6}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "floatingip $floatingip may not bind fixedip" $fixedip
    pinfo "binding fixedip of fip $floatingip is $fixedip"

    local bwin=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $8}' | sed -e "s/\ //g" -e "s/\"//g")
    check_str_null "floatingip $floatingip bandwidth in is null" $bwin
    comparestr "bwin of floatingip $floatingip is zero" $bwin 0
    pinfo "bandwidthin of fip $floatingip is ${bwin} Mb"

    local bwout=$(cat $PATHINFO/fiplist | awk -F"|"  '{print $9}' | sed -e "s/\ //g" -e "s/\"//g")
    check_str_null "floatingip $floatingip bandwidth out is null" $bwout
    comparestr "bwout of floatingip $floatingip is zero" $bwout 0
    pinfo "bandwidthout of fip $floatingip is ${bwout} Mb"

    ${CCSCMD} floatingip-show -a $fipid > "$PATHINFO/fip"
    local adminstatus=$(cat $PATHINFO/fip | grep admin_status_up | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    ncomparestr "admin status of floatingip $floatingip is $adminstatus" $adminstatus "true"
    pinfo "admin status of fip $floatingip is $adminstatus"

    local subnetid=$(cat $PATHINFO/fip | grep -w subnet_id | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "subnet of $portid is null" $subnetid
    pinfo "subnet of $portid is $subnetid"
    echo -e "\n\n"

    PORTID=$portid
}

function check_server_sg()
{
    local fip=$1
    local tid=$2
    local pid=$3
    if [ "$fip" != "" ];then
        python /home/dev/sdn_net_tool/sdn_check/main.py security-check --tenant_id $tid --floatingip $fip
    else
        pinfo "port $pid may not bind floatingip"
    fi
}

function check_server_inat_sg()
{
    return
    pcheck "================== cc-server inat floatingip security group ========================"
    if [ "$INATINTIP" != "" ];then
        python /home/dev/sdn_net_tool/sdn_check/main.py security-check --tenant_id $TENANTID --floatingip $INATINTIP
        echo -e "\n\n"
        echo "================== cc-server inat floatingip vr check ========================"
        python /home/dev/sdn_net_tool/sdn_check/main.py vr-check --tenant_id $TENANTID --floatingip $INATINTIP
    else
        pinfo "port $INATPORTID may not bind floatingip"
    fi
}

function show_server_port_sgs()
{
    for sg in $*
    do
          local rules=""
          local d=""
          local l=""

          pinfo "sg $sg rules: ICMP(1), TCP(6), UDP(17), ALL(300)"  
          ${CCSCMD} security-group-rule-list -a --securitygroup-id $sg > "$PATHINFO/$sg"
          while read line
          do
              d=$(echo $line | grep $sg | cut -d "|" -f12|sed -e "s/|/\ /g"  | sed -e 's/\ //g')
              l=$(echo $line | grep $sg | sed -e "s/|/\ /g"  | sed -e 's/  \+/ /g')
              if [ "$d" == "1" ];then
                  echo "** Direction:Egress  ** ${l}"
              elif [ "$d" == "0" ];then
                  echo "** Direction:Ingress ** ${l}"
              fi
          done < "$PATHINFO/$sg"
    done
}

function check_server_port()
{
    local portid=$1 

    pcheck "================ cc-server port $portid info ============"
    ${CCSCMD} port-show -a $portid > "$PATHINFO/port"

    local portstatus=$(cat $PATHINFO/port | grep -w State | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "state of port $portid is null" $portstatus
    ncomparestr "state of port $portid is down" $portstatus "up"
    pinfo "state of port $portid is $portstatus"


    local fixedip=$(cat $PATHINFO/port | grep -w FixedIps | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\]//g" -e "s/\[//g" -e "s/\"//g")
    exit_str_null "ip of port $portid is null" $fixedip
    pinfo "ip of port $portid is $fixedip"

    local tid=$(cat $PATHINFO/port | grep -w TenantId | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "tenant of port $portid is null" $tid
    pinfo "tenant of port $portid is $tid"

    local hostid=$(cat $PATHINFO/port | grep -w HostIds -B 3 | grep host-| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\]//g" -e "s/\[//g" -e "s/\"//g")
    if [ "$hostid" == "" ];then
        pinfo "floatingip may not bind vm $portid, test lb"
        lb_check $FLOATINGIP
        exit 1
    fi
   
    local portmac=$(cat $PATHINFO/port | grep -w MacAddress | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "mac of port $portid is null" $portmac
    pinfo "mac of port $portid is $portmac"

    local subnetid=$(cat $PATHINFO/port | grep -w SubnetId | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "subnet of port $portid is null" $subnetid
    pinfo "subnet of port $portid is $subnetid"

    local vpcid=$(cat $PATHINFO/port | grep -w VpcId | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "vpc of port $portid is null" $vpcid
    pinfo "vpc of port $portid is $vpcid"

    local portype=$(cat $PATHINFO/port | grep -w Type | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "type of port $portid is null" $portype
    pinfo "type of port $portid is $portype"

    if [ "$portype" != "inat" ];then
        local vmid=$(cat $PATHINFO/port | grep -w DeviceId | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
        if [ "$vmid" == "" ];then
            pinfo "floatingip may not bind vm $portid, test lb"
            lb_check $FLOATINGIP
            exit 1
        fi
        exit_str_null "vmid of port $portid is null" $vmid
        pinfo "vmid of port $portid is $vmid"
    fi

    local sgs=$(cat $PATHINFO/port | grep -w SecuritygroupIds -C 3 | grep sg- | cut -d"|" -f3 | sed -e "s/\"//g" -e "s/\]//g" -e "s/\[//g")
    exit_str_null "security group of port $portid is null" ${sgs}
    pinfo "security group of port $portid is ${sgs}"
    show_server_port_sgs ${sgs}
    echo -e "\n\n"

    if [ "$FLOATINGIP" != "" ];then
    check_server_sg $FLOATINGIP $tid $portid
    echo -e "\n\n"
    fi

    if [ "$portype" == "inat" ]; then
        INATHOSTID=$hostid
        INATFIXEDIPLIST[$hostid]=$fixedip
        VPCID=$vpcid
    else
        SUBNETID=$subnetid
        VPCID=$vpcid
        TENANTID=$tid
        HOSTID=$hostid
        DEVICEID=$vmid
        FIXEDIP=$fixedip
        PORTMAC=$portmac
        VMID=$vmid
    fi
}


function check_server_host()
{
    local hostid=$1
    local hostype=$2
    local portid=$3

    pcheck "=================== cc-serever $hostype port $hostid host info ================"
    ${CCSCMD} host-show -a $hostid > "$PATHINFO/host"

    local hostmngip=$(cat $PATHINFO/host | grep -w MgmtAddr| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "manager ip of $hostype  host $hostid for $portid is null" $hostmngip
    pinfo "managet ip of $hostype host $hostid for $portid is $hostmngip"

    local hostunip=$(cat $PATHINFO/host | grep -w Underlay | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "underlay ip of $hostype host $hostid for portid $portid is null" $hostunip
    pinfo "underlay ip of $hostype host $hostid for $portid is $hostunip"

    local zone=$(cat $PATHINFO/host | grep -w Zone| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "zone of $hostype host $hostid for $portid is $zone"


    local adminstatus=$(cat $PATHINFO/host | grep -w AdminStatus | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "admin status of $hostype host $hostid is null" $adminstatus
    ncomparestr "admin status of $hostype host $hostid is $adminstatus" $adminstatus "up"
    pinfo "admin status of $hostype host $hostid for $portid is $adminstatus"

    local status=$(cat $PATHINFO/host | grep -w Status | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "status of $hostype host $hostid is null" $status
    ncomparestr "status of $hostype host $hostid is $status" $status "up"
    pinfo "status of $hostype host $hostid for $portid is $status"
    echo -e "\n\n"

    if [ "$hostype" == "compute" ];then
        HOSTMNGIP=$hostmngip
        HOSTUNDERLAYIP=$hostunip
    elif [ "$hostype" == "inat" ];then
        INATHOSTMNGIP=$hostmngip
    fi
}

function check_server_subnet_acl()
{
    local aclid=$1
    local subnetid=$2
    pcheck "================ cc-server acl $aclid of $subnetid ============"
    ${CCSCMD} acl-rule list -a $aclid > "$PATHINFO/acl"
    cat $PATHINFO/acl
}

function check_server_subnet_rtabble()
{
    local rtid=$1
    local subnetid=$2

    pcheck "================ cc-server router table $rtid info ============"
    ${CCSCMD} route-list -a $rtid > "$PATHINFO/rtable"

    cat $PATHINFO/rtable |grep "rt-" |sed -e "s/|//g" 

    local rtdetail=$(cat $PATHINFO/rtable| grep "0.0.0.0" | grep -w internet | sed -e "s/|//g" -e 's/  \+/ /g' )
    check_str_null "internet route table of subnet $subnetid is null" $rtdetail
    pinfo "internet route table of $subnetid : $rtdetail"
    echo -e "\n\n"
    
}

function check_dr_host()
{

    pcheck "================ cc-server  dr host info ============"
    ${CCSCMD} host-list --type DR -a | grep "host-" > "$PATHINFO/drhost"

    while read h
    do
        echo ""
        local hostid=$(echo $h| cut -d"|" -f2 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "dr hostid is $hostid"

        local mngip=$(echo $h | cut -d"|" -f4 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "manager ip of $hostid is $mngip"

        local dvip=$(echo $h| cut -d"|" -f5 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "dv ip ip of $hostid is $dvip"

        local uip=$(echo $h| cut -d"|" -f6 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "underlay ip of $hostid is $uip"

        local htype=$(echo $h | cut -d"|" -f9 | sed -e "s/\ //g" -e "s/\"//g")
        encomparestr "type of $hostid is $htype" $htype "DR"
        pinfo "type of $hostid is $htype"

        local adminstatus=$(echo $h| cut -d"|" -f12 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "admin status of $hostid is $adminstatus"

        local status=$(echo $h | cut -d"|" -f13 | sed -e "s/\ //g" -e "s/\"//g")
        encomparestr "status of $hostid is $status" $status "UP"
        pinfo "status of $hostid is $status"

        if [ "$adminstatus" != "DOWN" -a "$status" != "DOWN" ];then
            DRLIST[$hostid]=$mngip","$dvip","$uip
        fi
    done < $PATHINFO/drhost
    echo -e "\n\n"
}

function check_vr_host()
{
    local vpcid=$1
    local zone=""

    pcheck "================ cc-server vr host $vpc info ============"
    ${CCSCMD} vpc-show -a $vpcid > "$PATHINFO/vpc"
    ${CCSCMD} host-list-binding-router -a $vpcid | grep "host-" > "$PATHINFO/brouter"

    local vni=$(cat $PATHINFO/vpc| grep -w vni| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "vni of $vpcid is null" $vni
    pinfo "vni of $vpcid is $vni"

    while read h
    do
        echo ""
        local hostid=$(echo $h| cut -d"|" -f2 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "hostid of $vpcid is $hostid"

        local mngip=$(echo $h | cut -d"|" -f4 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "manager ip of $hostid is $mngip"

        local dvip=$(echo $h| cut -d"|" -f5 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "dv ip ip of $hostid is $dvip"

        local uip=$(echo $h| cut -d"|" -f6 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "underlay ip of $hostid is $uip"

        local zone=$(echo $h| cut -d"|" -f14 | sed -e "s/\ //g" -e "s/\"//g")
        pinfo "zone of $hostid is $zone"

        local htype=$(echo $h | cut -d"|" -f7 | sed -e "s/\ //g" -e "s/\"//g")
        ncomparestr "type of $hostid is $htype" $htype "VR"
        pinfo "type of $hostid is $htype"

        local adminstatus=$(echo $h| cut -d"|" -f10 | sed -e "s/\ //g" -e "s/\"//g")
        encomparestr "admin status of $hostid is $adminstatus" $adminstatus "UP"
        pinfo "admin status of $hostid is $adminstatus"

        local status=$(echo $h | cut -d"|" -f11 | sed -e "s/\ //g" -e "s/\"//g")
        encomparestr "status of $hostid is $status" $status "UP"
        pinfo "status of $hostid is $status"

        if [ "$adminstatus" != "DOWN" -a "$status" != "DOWN" ];then
            VRLIST[$hostid]=$mngip","$dvip","$uip","$zone
        fi
        
    done < $PATHINFO/brouter

    VNI=$vni
    echo -e "\n\n"
}

function check_server_subnet()
{
    local subnetid=$1
    local portid=$2

    pcheck "================ cc-server subnet $subnetid info ============"
    ${CCSCMD} subnet-show -a $subnetid > "$PATHINFO/subnet"

    local gwip=$(cat $PATHINFO/subnet| grep -w gateway_ip| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "gwip of subnet $subnetid for $portid is null" $gwip
    pinfo "gwip of subnet $subnetid for $portid is $gwip"

    local gwmac=$(cat $PATHINFO/subnet| grep -w gateway_mac| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "gwmac of subnet $subnetid for $portid is null" $gwmac
    pinfo "gwmac of subnet $subnetid for $portid is $gwmac"


    local acl=$(cat $PATHINFO/subnet| grep -w acl_id| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    if [ "$acl" == "" ];then
        pinfo "acl of subnet $subnetid for $portid is null"
    else
        pinfo "acl of subnet $subnetid for $portid is $acl"
        check_server_subnet_acl $acl $subnetid
    fi

    local rtable=$(cat $PATHINFO/subnet| grep -w route_table_id | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "router table id of subnet $subnetid for $portid is null" $rtable
    pinfo "router table id of subnet $subnetid for $portid is $rtable"

    echo -e "\n\n"
    check_server_subnet_rtabble $rtable $subnetid

    GWMAC=$gwmac
    GWIP=$gwip
    RTABLE=$rtable

}

function check_server_inatport()
{
    local vpcid=$1
    local tid=$2

    pcheck "================ cc-server inatport $vpcid info ============"
    ${CCSCMD} natport-list -a --vpc-id=$vpcid | grep $vpcid > "$PATHINFO/inatlist"

    local count=$(cat $PATHINFO/inatlist | wc -l)
    comparestr "inat port of $vpcid is not exist or more floatingip binding " $count "0"

    local portid=$(cat $PATHINFO/inatlist | awk -F"|"  '{print $6}')
    pinfo "inat portid of $vpcid is : \n ${portid}"

    for p in ${portid}
    do
        check_server_port $p
        check_server_host $INATHOSTID "inat" $p
        check_server_inatport_floatingip $tid $p

        #if [ "$CHECKOPTION" == "inat" -o "$CHECKOPTION" == "all" ];then
        #     show_route $p $INATHOSTMNGIP
        #     show_iptables_rule $p
        #     check_inat_controller $p $INATHOSTMNGIP $INATFIXEDIP
        #fi
    done
}

function check_server_inatport_floatingip()
{
    local tid=$1
    local portid=$2
    pcheck "================ cc-server inatport internal ip $portid info ============"
    ${CCSCMD} floatingip-list -a --tenant-id $tid | grep $portid > "$PATHINFO/inatintlist"

    count=$(cat $PATHINFO/inatintlist | wc -l)
    if [ "$count" != "1" ];then
         pnerror "internal ip of inat port $portid is not exist or more internal ip binding "
         return
    fi

    ins=$(cat $PATHINFO/inatintlist | awk -F"|"  '{print $2}'| sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "fip id of inat port $portid is null" $ins
    pinfo "fip id of inat port $portid is $ins"

    provider=$(cat $PATHINFO/inatintlist| awk -F"|"  '{print $4}')
    exit_str_null "provider of inat port $portid is null " $provider
    pinfo "provider of inat port $portid is $provider"

    ip=$(cat $PATHINFO/inatintlist | awk -F"|"  '{print $5}'| sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "fip of inat port $portid is null" $ip
    pinfo "fip of inat port $portid is $ip"

    bwin=$(cat $PATHINFO/inatintlist | awk -F"|"  '{print $8}'| sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "bandwidthin of inat port $portid is null" $bwin
    comparestr "bandwidthin of inat port $portid is  zero" $bwin 0
    pinfo "bandwidthin of inat port $portid is ${bwin} Mb"

    bwout=$(cat $PATHINFO/inatintlist | awk -F"|"  '{print $9}'| sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    exit_str_null "bandwidthout of inat port $portid is null" $bwout
    comparestr "bandwidthout of inat port $portid is  zero" $bwout 0
    pinfo "bandwidthout of inat port $portid is ${bwout} Mb"
    echo -e "\n\n"

}

function check_server_new_compute()
{
    local vmid=$1
    pcheck "================ vm $vmid info ============"
    #newsshcmd jvirt instance-show $vmid -a > "$PATHINFO/vm"
    execRC=${RCMD[${DCNAME}]}
    tnid=`$execRC $vmid | grep -v "+"`
    exit_str_null "vm $vmid is not exist" ${tnid}
    jvirt instance-show $vmid --user-id $tnid > "$PATHINFO/vm"

    local vmexist=$(cat $PATHINFO/vm | grep -w image)
    exit_str_null "vm $vmid is not exist" ${vmexist}


    local data_disks=$(cat $PATHINFO/vm| grep -w data_disks| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "data_disks of vm $vmid is $data_disks"

    local count=0
    while [[ $count -le 3 ]]
    do
        #newsshcmd jvirt get-vnc-console $vmid -a > "$PATHINFO/vnc"
        jvirt get-vnc-console $vmid --user-id $tnid > "$PATHINFO/vnc"
        local vnc=$(cat "$PATHINFO/vnc" | grep -iw Url | cut -d"|" -f3)
        pinfo "vnc of vm $vmid: $vnc"
        let count+=1
    done

    local image=$(cat $PATHINFO/vm| grep -w image| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "image of vm $vmid is $image"

    local image_id=$(cat $PATHINFO/vm| grep -w image_id| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "image id of vm $vmid is null" $image_id
    pinfo "image id of vm $vmid is $image_id"

    local instance_type=$(cat $PATHINFO/vm| grep -w instance_type| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "instance_type of vm $vmid is null" $instance_type
    pinfo "instance_type of vm $vmid is $instance_type"

    local launch_time=$(cat $PATHINFO/vm| grep -w launch_time| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "launch_time of vm $vmid is null" $launch_time
    pinfo "launch_time of vm $vmid is $launch_time"

    local name=$(cat $PATHINFO/vm| grep -w name| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "name of vm $vmid is null" $name
    pinfo "name of vm $vmid is $name"

    local placement=$(cat $PATHINFO/vm| grep -w placement| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "placement of vm $vmid is null" $placement
    pinfo "placement of vm $vmid is $placement"

    local source_type=$(cat $PATHINFO/vm| grep -w source_type| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "source_type of vm $vmid is null" $source_type
    pinfo "source_type of vm $vmid is $source_type"

    local state=$(cat $PATHINFO/vm| grep -w state| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "state of vm $vmid is null" $state
    encomparestr "state of vm $vmid is $state" $state "running" "cat $PATHINFO/vm"
    pinfo "state of vm $vmid is $state"

    local vtype=$(cat $PATHINFO/vm| grep -w " type "| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "type of vm $vmid is null" $vtype
    pinfo "type of vm $vmid is $vtype"

    local user_id=$(cat $PATHINFO/vm| grep -w user_id| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "user_id of vm $vmid is null" $user_id
    pinfo "user_id of vm $vmid is $user_id"

    local vpc_id=$(cat $PATHINFO/vm| grep -w vpc_id| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "vpc id of vm $vmid is null" $vpc_id
    pinfo "vpc id of vm $vmid is $vpc_id"

    local networks=$(cat $PATHINFO/vm| grep -w networks| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "network of vm $vmid is null" $networks
    pinfo "network of vm $vmid is $networks"

    cat $PATHINFO/vm| grep -w networks| awk -F"|" '{print $3}' > $PATHINFO/vmnetwork
    local fixedip=$(cat $PATHINFO/vmnetwork| jq .[0].fixed_ip| sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "fixed ip of vm $vmid is null" $fixedip
    pinfo "fixed ip of vm $vmid is $fixedip"

    local port_id=$(cat $PATHINFO/vmnetwork| jq .[0].port_id| sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "port_id of vm $vmid is null" $port_id
    pinfo "port_id of vm $vmid is $port_id"

    local security_groups=$(cat $PATHINFO/vmnetwork| jq .[0].security_groups| sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "security_groups of vm $vmid is null" $security_groups
    pinfo "security_groups of vm $vmid is $security_groups"

    get_server_floatingip $user_id $port_id $fixedip

    PORTID=$port_id
}

function get_server_floatingip() 
{
    local tenantid=$1
    local portid=$2
    local fixedip=$3

    ${CCSCMD} floatingip-list  --tenant-id $tenantid > "$PATHINFO/fiplist"
    local fip=$(cat "$PATHINFO/fiplist" | grep $portid | grep $fixedip | cut -d"|" -f5 |sed -e "s/\ //g" -e "s/\"//g")
    if [ "$fip" == "" ];then
        pinfo "fixedip $fixedip of $portid can not binding floatingip"
    else
        FLOATINGIP=$fip
    fi
}
function check_server_vminfo()
{
    local vmid=$1

    check_server_new_compute $vmid
    return

    if [[ "$vmid" =~ "i-" || $DCNAME == "bj02" ]];then
        pinfo "$vmid is in new compute cluster"
        check_server_new_compute $vmid
    else
        pinfo "$vmid is in old compute cluster"
        check_server_nova $vmid
    fi
}

function check_server_nova()
{
    local vmid=$1
    pcheck "================ nova vm $vmid info ============"
    nova show $vmid > "$PATHINFO/vm"

    local vmexist=$(cat $PATHINFO/vm | grep -w image)
    exit_str_null "vm $vmid is not exist" ${vmexist}

    local vpcid=$(cat $PATHINFO/vm | grep -w vpc_id | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    check_str_null "vpc id of vm $vmid is null" $vpcid
    pinfo "vpc of vm $vmid is $vpcid"

    local vnc=$(nova get-vnc-console $vmid novnc | grep -w novnc | cut -d"|" -f3)
    if [ "$vnc" != "" ];then
        pinfo "vnc of vm $vmid is $vnc"
    fi

    local name=$(cat $PATHINFO/vm | grep -w name | awk -F"|" '{print $3}')
    pinfo "name of vm $vmid is ${name}"

    local flavor=$(cat $PATHINFO/vm | grep -w flavor | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    pinfo "flavor of vm $vmid is $flavor"

    local metadata=$(cat $PATHINFO/vm | grep -w metadata| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    pinfo "metadata of vm $vmid is $metadata"

    local zone=$(cat $PATHINFO/vm | grep -w availability_zone | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    pinfo "availability zone of vm $vmid is $zone"

    local status=$(cat $PATHINFO/vm | grep -w status | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    check_str_null "status of vm $vmid is null" $status
    encomparestr "status of vm $vmid is $status" $status "active" "cat $PATHINFO/vm"
    pinfo "status of vm $vmid is $status"

    local tstatus=$(cat $PATHINFO/vm | grep -w task_state | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    check_str_null "task status of vm $vmid is null" $tstatus
    encomparestr "task status of vm $vmid is $tstatus" $tstatus "-"
    pinfo "task status of vm $vmid is $tstatus"

    local pstatus=$(cat $PATHINFO/vm | grep -w power_state | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g"| tr '[A-Z]' '[a-z]')
    check_str_null "power status of vm $vmid is null" $pstatus
    encomparestr "power status of vm $vmid is $tstatus" $pstatus "1"
    pinfo "power status of vm $vmid is $pstatus"

    local portid=$(cat $PATHINFO/vm | grep -w port_id| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "portid of vm $vmid is null" $portid
    pinfo "port_id of vm is $portid"

    local tid=$(cat $PATHINFO/vm | grep -w tenant_id | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "tenant of vm $vmid is $tid"

    local hostip=$(cat $PATHINFO/vm | grep -w host_ip | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "manager ip of vm $vmid is null" $hostip
    pinfo "manager ip of vm is $hostip"

    local ips=$(cat $PATHINFO/vm | grep -w network| awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    exit_str_null "ips of vm $vmid is null" $ips

    local image=$(cat $PATHINFO/vm | grep -w image | awk -F"|" '{print $3}' | sed -e "s/\ //g" -e "s/\"//g")
    pinfo "image of vm $vmid is $image"

    local vlum=$(cat $PATHINFO/vm | grep volumes_attached | cut -d"|" -f3 | sed -e "s/\[//g" -e "s/\]//g" -e "s/\"//g" -e "s/}//g" -e "s/{//g" -e "s/id://g" -e "s/\ //g")
    pinfo "attached volumes of vm $vmid is $vlum"

    local fixedip=$(echo $ips | cut -d"," -f1)
    exit_str_null "fixed ip of vm $vmid is null" $fixedip
    pinfo "fixedip of vm $vmid is $fixedip" 


    ${CCSCMD} floatingip-list --tenant-id $tid -a > "$PATHINFO/novatenantfip"
    local fip=$(cat "$PATHINFO/novatenantfip" | grep "$portid" | cut -d"|" -f5 | sed -e "s/\ //g" -e "s/\"//g")
    if [ "$fip" != "" ];then
        pinfo "floatingip of vm $vmid is $fip" 
    else
        pinfo "vm $vmid is not floatingip" 
    fi

    PORTID=$portid
    FLOATINGIP=$fip

    echo -e "\n\n"
}

function check_compute_host()
{
    local hostid=$1
    local portid=$2
    check_server_host $hostid "compute" $portid
}

function add_check_flow()
{
    local match="$3 $4"
    local tunmatch=$3
    local ipmatch=$4
    local cmd=$2
    DPDKIP=$1

    pinfo "$cmd host $DPDKIP add match: $match"

    sshexec "$cmd flow_pat_add ${match}"
    sshexec ''$cmd' flow_pat_dump'
}

function clean_check_flow()
{
    local cmd=$2
    DPDKIP=$1

    pinfo "$cmd host $DPDKIP clean flow"

    sshexec "$cmd flow_pat_clean"
}

function del_check_flow()
{
    local match="$3 $4"
    local tunmatch=$3
    local ipmatch=$4
    local cmd=$2
    DPDKIP=$1

    pinfo "$cmd host $DPDKIP del match: $match"

    sshexec ''$cmd' flow_pat_dump' > "$PATHINFO/flowdump"
    #cat $PATHINFO/flowdump
    flowid=$(cat "$PATHINFO/flowdump" | sed "s/\ \ /\ /g" | grep $tunmatch | grep $ipmatch | cut -d, -f1 | cut -d"=" -f2 | sed "s/\ //g")
    if [ "$flowid" == "" ];then
        pnerror "$match is not exit in $cmd host $DPDKIP"
        return
    fi
    sshexec ''$cmd' flow_pat_dump | grep "flowid='${flowid}'"' > "$PATHINFO/flowresult"
    isdrop=$(cat "$PATHINFO/flowresult" | grep -v "drop: 0")
    if [ "$isdrop" != "" ];then
        pnerror `cat $PATHINFO/flowresult`
    else
        cat "$PATHINFO/flowresult" | grep -v "rx: 0; tx: 0; drop: 0(null)"
    fi
    sshexec ''$cmd' flow_pat_enable '${flowid}' 0' > /dev/null
    sshexec ''$cmd' flow_pat_del '${flowid}'' > /dev/null
}

function add_check_vr_flow()
{
    local porthostip=$HOSTUNDERLAYIP
    local portfixedip=$FIXEDIP
    local dip=$1
    local vrmngip=""
    local vrdvip=""
    local vrunip=""
    local tunmatch=""
    local rtunmatch=""
    local location=""
    local zone=""
    local ip=""
    local fip=$FLOATINGIP

    if [ "$fip" == "" ];then
        return
    fi

    location=$(echo $dip | cut -d"-" -f2) 
    ip=$(echo $dip | cut -d"-" -f1) 

    for ips in `echo ${VRLIST[@]}`
    do
        vrmngip=$(echo $ips|cut -d"," -f1) 
        vrdvip=$(echo $ips|cut -d"," -f2) 
        vrunip=$(echo $ips|cut -d"," -f3) 
        zone=$(echo $ips|cut -d"," -f4) 
        if [ $vrunip != "" ];then
           tunmatch="sip:$porthostip:dip:$vrunip" 
           rtunmatch="sip:$vrunip:dip:$porthostip" 
        else
           tunmatch="sip:$porthostip" 
           rtunmatch="dip$porthostip" 
        fi

        if [ "$location" == "vr" ];then
            add_check_flow  $vrmngip "vrcli" "$tunmatch" "sip:$portfixedip:dip:$ip"
            add_check_flow  $vrmngip "vrcli" 0 "sip:$ip:dip:$fip"
        fi

        if [ "$location" == "vrdr" ];then
            add_check_flow  $vrmngip "vrcli" "$tunmatch" "sip:$portfixedip:dip:$ip"
            add_check_flow  $vrmngip "vrcli" 0 "sip:$ip:dip:$fip"
        fi
            
    done
}

function del_check_vr_flow()
{
    local porthostip=$HOSTUNDERLAYIP
    local portfixedip=$FIXEDIP
    local dip=$1
    local vrmngip=""
    local vrdvip=""
    local vrunip=""
    local tunmatch=""
    local rtunmatch=""
    local zone=""
    local location=""
    local ip=""
    local fip=$FLOATINGIP

    if [ "$fip" == "" ];then
        return
    fi

    location=$(echo $dip | cut -d"-" -f2) 
    ip=$(echo $dip | cut -d"-" -f1) 

    for ips in `echo ${VRLIST[@]}`
    do
        vrmngip=$(echo $ips|cut -d"," -f1) 
        vrdvip=$(echo $ips|cut -d"," -f2) 
        vrunip=$(echo $ips|cut -d"," -f3) 
        zone=$(echo $ips|cut -d"," -f4) 
        if [ $vrunip != "" ];then
           tunmatch="sip:$porthostip:dip:$vrunip" 
           rtunmatch="sip:$vrunip:dip:$porthostip" 
        else
           tunmatch="sip:$porthostip" 
           rtunmatch="dip$porthostip" 
        fi

        if [ "$location" == "vr" ];then
            del_check_flow  $vrmngip "vrcli" "$tunmatch" "sip:$portfixedip:dip:$ip"
            del_check_flow  $vrmngip "vrcli" 0 "sip:$ip:dip:$fip"
        fi

        if [ "$location" == "vrdr" ];then
            del_check_flow  $vrmngip "vrcli" "$tunmatch" "sip:$portfixedip:dip:$ip"
            del_check_flow  $vrmngip "vrcli" 0 "sip:$ip:dip:$fip"
        fi

    done
}

function check_vr_nat()
{
    local fip=$1
    local mngip=""
    local dnatrule=""
    local zone=""

    pcheck "================ cc-router vr fip $fip info ============"

    for ips in `echo ${VRLIST[@]}`
    do
        echo ""
        DPDKIP=$(echo $ips|cut -d"," -f1) 
        zone=$(echo $ips|cut -d"," -f4) 
        sshexec 'vrcli dnat_dump' > "$PATHINFO/dnat"
        sshexec 'vrcli snat_dump '$VNI'' > "$PATHINFO/snat"
        dnatrule=$(cat $PATHINFO/dnat | grep $fip)
        check_str_null "dnat rule is exist in vr host $DPDKIP in $zone" $dnatrule
        pinfo "vr host $DPDKIP dnat rule in $zone"
        echo $dnatrule
        snatrule=$(cat $PATHINFO/snat | grep $fip)
        check_str_null "snat rule is exist in vr host $DPDKIP in $zone" $snatrule
        pinfo "vr host $DPDKIP snat rule in $zone"
        echo $snatrule
    done
    echo -e "\n\n"
}

function check_vr_route()
{

    local rtable=$1
    local mngip=""
    local dnatrule=""
    local zone=""

    pcheck "================ cc-router vr route $rtable info ============"

    for ips in `echo ${VRLIST[@]}`
    do
        echo ""
        DPDKIP=$(echo $ips|cut -d"," -f1) 
        zone=$(echo $ips|cut -d"," -f4) 
        pinfo "vr host $DPDKIP router table in $zone:"
        sshexec 'vrcli route_list '$VNI' '$rtable'' > "$PATHINFO/vrouter"
        while read line
        do
            nh_type=$(echo $line | sed "s/\ //g"| sed "s/.*\(nh_type=.*\),l4_proto.*/\1/g")
            nh_ip=$(echo $line | sed "s/\ //g"| sed "s/.*\(nh_ip=.*\),if_idx.*/\1/g")
            mask=$(echo $line | sed "s/\ //g"| sed "s/.*\(mask=.*\),flag.*/\1/g") 
            prefix=$(echo $line | sed "s/\ //g"| sed "s/.*\(prefix=.*\),nh_type.*/\1/g")
            priority=$(echo $line |  sed "s/\ //g"| sed "s/.*\(priority=.*\),prefix.*/\1/g") 
            printf "%s,%s,%s,%s,%s\n" $priority $prefix $mask $nh_ip $nh_type 
        done < "$PATHINFO/vrouter"
    done
    echo -e "\n\n"
}

function add_check_dr_flow()
{
    local porthostip=$HOSTUNDERLAYIP
    local portfixedip=$FIXEDIP
    local dip=$1
    local drmngip=""
    local drdvip=""
    local drunip=""
    local location=""
    local ip=""
    local isdns=""
    local fip=$FLOATINGIP

    if [ "$fip" == "" ];then
        return
    fi

    location=$(echo $dip | cut -d"-" -f2) 
    ip=$(echo $dip | cut -d"-" -f1) 
    isdns=$(echo $dip | cut -d"-" -f3) 

    for ips in `echo ${DRLIST[@]}`
    do
        drmngip=$(echo $ips|cut -d"," -f1) 
        drdvip=$(echo $ips|cut -d"," -f2) 
        drunip=$(echo $ips|cut -d"," -f3) 

        if [ "$location" == "dr" -o "$location" == "vrdr" ];then
             add_check_flow  $drmngip "drcli" 0 "sip:$ip:dip:$fip"
         #   if [ "$isdns" == "dns" ];then
         #       add_check_flow  $drmngip "drcli" 0 "dip:$fip"
         #   else
         #       add_check_flow  $drmngip "drcli" 0 "sip:$ip:dip:$fip"
         #   fi
        fi

    done
}

function del_check_dr_flow()
{
    local porthostip=$HOSTUNDERLAYIP
    local portfixedip=$FIXEDIP
    local dip=$1
    local drmngip=""
    local drdvip=""
    local drunip=""
    local location=""
    local ip=""
    local isdns=""
    local fip=$FLOATINGIP

    if [ "$fip" == "" ];then
        return
    fi

    location=$(echo $dip | cut -d"-" -f2) 
    ip=$(echo $dip | cut -d"-" -f1) 
    isdns=$(echo $dip | cut -d"-" -f3) 

    for ips in `echo ${DRLIST[@]}`
    do
        drmngip=$(echo $ips|cut -d"," -f1) 
        drdvip=$(echo $ips|cut -d"," -f2) 
        drunip=$(echo $ips|cut -d"," -f3) 

        if [ "$location" == "dr" -o "$location" == "vrdr" ];then
                del_check_flow  $drmngip "drcli" 0 "sip:$ip:dip:$fip"
         #   if [ "$isdns" == "dns" ];then
         #       del_check_flow  $drmngip "drcli" 0 "dip:$fip"
         #   else
         #       del_check_flow  $drmngip "drcli" 0 "sip:$ip:dip:$fip"
         #   fi
        fi
    done
}

function check_dr_fip_route()
{
    local fip=$1
    local count=100
    local content=""
    
    pcheck "================ cc-router dr fip $fip info ============"

    for ips in `echo ${DRLIST[@]}`
    do
        echo ""
        drmngip=$(echo $ips|cut -d"," -f1) 
        DPDKIP=$drmngip
        sshexec 'drcli  flowtable_list 0 '$fip'' > "$PATHINFO/drfip"
        isexist=$(cat $PATHINFO/drfip)
        #comparestr "fip route $fip is not exist in dr host $drmngip" $count "0"
        check_str_null "fip route $fip is not exist in dr host $drmngip" $isexist
        pinfo "dr host $DPDKIP"
        content=$(cat "$PATHINFO/drfip" | sed -e "s/\ //g")
        if [ "$content" ==  "[]" ];then
            pnerror "No floatingip route table"
            continue
        fi
        cat "$PATHINFO/drfip"
        
    done

    echo -e "\n\n"
}

function clean_flow()
{
    for ips in `echo ${VRLIST[@]}`
    do
        vrmngip=$(echo $ips|cut -d"," -f1) 
        clean_check_flow  $vrmngip "vrcli"
    done
    for ips in `echo ${DRLIST[@]}`
    do
        drmngip=$(echo $ips|cut -d"," -f1) 
        clean_check_flow  $drmngip "drcli"
    done
}

function add_flow()
{

    local flowips=$1
    local location=""
    local ip=""
    local isdns=""

    pinfo "add flow $flowips"

    for iplocation in `echo $flowips | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
    do
        location=$(echo $iplocation | cut -d"-" -f2) 
        ip=$(echo $iplocation | cut -d"-" -f1) 
        isdns=$(echo $iplocation | cut -d"-" -f3) 

        echo -e "\n\n ============= add $location flow for $ip $isdns ===================="
        add_check_vr_flow $iplocation
        add_check_dr_flow $iplocation
    done
}

function del_flow()
{

    local flowips=$1
    local location=""
    local ip=""
    local isdns=""

    pinfo "del flow $flowips"

    for iplocation in `echo $flowips | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
    do
        location=$(echo $iplocation | cut -d"-" -f2) 
        ip=$(echo $iplocation | cut -d"-" -f1) 
        isdns=$(echo $iplocation | cut -d"-" -f3) 

        echo -e "\n\n ============= del $location flow for $ip $isdns===================="
        del_check_vr_flow $iplocation
        del_check_dr_flow $iplocation
    done
}

function check_floatingip()
{
   #check server
   check_server_floatingip $FLOATINGIP
   check_server_port $PORTID
   check_compute_host $HOSTID $PORTID
   check_server_subnet $SUBNETID $PORTID
   check_server_inatport $VPCID $TENANTID
   check_dr_host
   check_vr_host $VPCID
   if [ "$FLOATINGIP" != "" ];then
       check_vr_nat $FLOATINGIP
   fi
   check_vr_route $RTABLE
   if [ "$FLOATINGIP" != "" ];then
       check_dr_fip_route $FLOATINGIP
   fi
   check_server_vminfo $DEVICEID
   #check controller runtime data
   if [ "$CHECKOPTION" == "compute" -o "$CHECKOPTION" == "all" ];then
       check_compute_controller $HOSTMNGIP $PORTID $FIXEDIP $GWMAC $GWIP $FLOATINGIP
   fi

   if [ "$CHECK_VM" == "true" ];then
       check_compute_vm $HOSTMNGIP $PORTID $FIXEDIP $GWMAC $GWIP $PORTMAC $VMID
   fi
}

function check_vm()
{
   check_server_vminfo $VMID
   #check server
   if [ "$FLOATINGIP" != "" ];then
       check_server_floatingip $FLOATINGIP
   else
        pinfo "vm $VMID may not bind floatingip"
   fi

   check_server_port $PORTID
   check_compute_host $HOSTID $PORTID
   check_server_subnet $SUBNETID $PORTID
   check_server_inatport $VPCID $TENANTID
   check_dr_host
   check_vr_host $VPCID
   if [ "$FLOATINGIP" != "" ];then
       check_vr_nat $FLOATINGIP
   fi
   check_vr_route $RTABLE
   if [ "$FLOATINGIP" != "" ];then
       check_dr_fip_route $FLOATINGIP
   fi

   #check controller runtime data
   if [ "$CHECKOPTION" == "compute" -o "$CHECKOPTION" == "all" ];then
       check_compute_controller $HOSTMNGIP $PORTID $FIXEDIP $GWMAC $GWIP $FLOATINGIP
   fi
}

function show_iptables_rule()
{
    local portid=$1
    pcheck "================ cc-controller inat $portid host - iptable rules ============"
    sinatcmd ip netns exec $portid iptables-save
    echo -e "\n\n"
}

function show_route()
{
    local portid=$1
    local hostip=$2
    pcheck "================ cc-controller inat  $hostip $portid - route table ============"
    sinatcmd ip netns exec $portid ip a
    echo -e "\n"
    sinatcmd ip netns exec $portid route  -n
    echo -e "\n\n"
}

function kill_tcpdump()
{
    local ip=""
    local all=""
    ip=$1
    all=$(ssh -o StrictHostKeyChecking=no root@${ip}  ps -ef|grep -w tcpdump | grep -v grep | awk '{print $2}')
    for a in $all
    do
        echo "kill $a"
        ssh -o StrictHostKeyChecking=no root@${ip} kill -9 ${a}
    done

}

function check_inat_controller()
{
    local portid=$1
    local hostip=$2

    pcheck "================ cc-controller inat $hostip $portid host============"
    #check flow table
    sinatcmd "yum install jq -y"
    sinatcmd ovs-runtime-check -p $portid
    echo -e "\n\n"


    #pinfo "********************************** $INATFIXEDIP ping inatport gatewap ip $INATGWIP from inat host *************************************" 
    ##ping inat port gateway ip
    #sinatcmd ovs-ping-check -p $INATPORTID -d $INATGWMAC -w $INATFIXEDIP -x $INATGWIP -e $INATPORTID
    #echo -e "\n\n"

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
               sinatcmd ovs-ping-check -p $INATPORTID -d $INATGWMAC -w $INATFIXEDIP -x $IP -e $INATPORTID
           done
           ((++i)) 
        done
    fi

    pinfo "*****************************************kill tcpdump*******************************"
    kill_tcpdump $INATMNGIP
}


function check_compute_vm(){
    local hostip=$1
    local portid=$2
    local fixedip=$3
    local gwmac=$4
    local gwip=$5
    local portmac=$6
    local vmid=$7

    HOSTIP=$hostip
    scp -r check_vm.sh root@$hostip:/usr/local/bin/
    echo "-d -v $vmid -n $portmac@$fixedip@$gwip"
    scmd sh /usr/local/bin/check_vm.sh -d -v $vmid -n $portmac@$fixedip@$gwip
}

function check_compute_controller()
{
    local hostip=$1
    local portid=$2
    local fixedip=$3
    local gwmac=$4
    local gwip=$5
    local fip=$6
    local inatfixedip=$7

    if [ "$FLOWSTC" == "1" -a "$fip" != "" ];then
        FLOWIPS="$gwip-vr-all,$fip-vrdr-all"
        for ip in `echo $DNSSERVERIPS | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
        do
            FLOWIPS=$FLOWIPS",$ip-vrdr-dns"
        done
        for ip in `echo $PORTPINGLIST | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
        do
            FLOWIPS=$FLOWIPS",$ip-vrdr-all"
        done

        FLOWSTC=2
        add_flow $FLOWIPS
    fi

    HOSTIP=$hostip

    pcheck "================ cc-controller host $hostip compute  ============"
    #check flow table
    scmd "yum install jq -y"
    scmd ovs-runtime-check -p $portid

    pinfo "************************************* arping $fixedip  *************************************" 
    #arping self
    scmd ovs-arping-check -p $portid -d $BOARDCAST -x $fixedip -w $gwip
    echo -e "\n\n"

    pinfo "************************************* $fixedip ping gateway ip $gwip *************************************" 
    #ping gateway ip
    scmd ovs-ping-check -p $portid -d $gwmac -w $fixedip -x $gwip
    echo -e "\n\n"

    if [ "$PINGFLAG" != "1" ];then
        return
    fi

    for ip in `echo ${INATFIXEDIPLIST[@]}`
    do
        pinfo "************************************* $fixedip ping inat ip $ip *************************************" 
        #ping inat fixed ip
        scmd ovs-ping-check -p $portid -d $gwmac -w $fixedip -x $ip
        echo -e "\n\n"
    done


    for ip in `echo $DNSSERVERIPS | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
    do
        echo -e "\n\n"
        pinfo "*********************** $fixedip ping dns server ip $ip ********************************"
        scmd ovs-ping-check -p $portid -d $gwmac -w $fixedip -x $ip
    done
    echo -e "\n"

    #ping pubnet network
    if [ "$fip" != "" ];then
        echo -e "\n\n"
        pinfo "***************************** $fip ping floatingip from volume node: $FLOATINGIPPING ***********************************" 
        #ping self floatingip 
        ping_check $fip

        echo -e "\n\n"
        pinfo "***************************** $fip ping self floatingip $fip ***********************************" 
        #ping self floatingip 
        scmd ovs-ping-check -p $portid -d $gwmac -w $fixedip -x $fip


        local i=1
        local IP=""
        while true
        do 
           if [ $i -gt  $PINGCOUNT ];then
               break
           fi
           echo -e "\n"
           pinfo "current count $i of $PINGCOUNT"
           for ip in `echo $PORTPINGLIST | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
           do
               echo -e "\n\n"
               pinfo "*********************** $fip ping public ip $ip ********************************"
               scmd ovs-ping-check -p $portid -d $gwmac -w $fixedip -x $ip
           done
           ((++i)) 
        done
    else
        pinfo "port $portid may not bind floatingip"
    fi

    pinfo "*****************************************kill tcpdump*******************************"
    kill_tcpdump $hostip

    if [ "$FLOWSTC" == "1" ];then
        dumpcounter
    fi
}

function get_tenant_vm()
{
    sshcmd nova list --tenant $1 > "$PATHINFO/vmlist"
    local errorvms=$(cat $PATHINFO/vmlist | grep -wi "active")
    if [ "$errorvms" == "" ];then
         perror "not active status vm for tenant $1, $errorvms"
    fi

    local exist=$(cat $PATHINFO/vmlist | grep -wi "active")
    exit_str_null "vm is not exist for active status" ${exist}

    local vmlist=$(cat $PATHINFO/vmlist | grep -wi "active" | cut -d"|" -f2 | sed -e "s/\ //g")
    pinfo "vm list of tenant $1:"
    echo -e "$vmlist"

    VMLIST=$vmlist
}

function check_tenant()
{
        for t in `echo $TENANTS | sed -e "s/\ //g" | sed -e "s/\,/ /g"`
        do
            pcheck "===============================tenant $t============================="
            get_tenant_vm $t
            for V in $VMLIST;do echo -e "\n\n";check_vm $V;done
            echo -e "\n\n"
        done
}

function lb_check()
{
    sh lb_check.sh -d ${DCNAME} -f $1
}

main()
{

    if [ $# -lt 4 ];then
         help_usage
         exit
    fi

    echo `date "+%Y-%m-%d %H:%M:%S"`" check start"
    echo ""

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
    clean
    echo `date "+%Y-%m-%d %H:%M:%S"`" check end"
    echo ""
    echo ""
}

main $*

#tcpdump -i any -nnvv 'icmp[icmptype]==0'

