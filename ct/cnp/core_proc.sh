INT_IFNAME=""
EXT_IFNAME=""

ENABLE_PHY_SRIOV_TRACE="false"
TEMP_DIR=$(mktemp -d /tmp/mktemp.XXXX)
cd "$TEMP_DIR"

ARG_OPT="$1"
ARG_TYPE="$2"
ARG_VAL="$3"
ARG_EXT="$4"

FILENAME=$(basename $0)
if [[ $FILENAME == "smart_scan" ]];then
    DEPLOY_PATH="/mnt/deploy/openstack-ansible/hosts"
    ODL_DB="odl_db"
    ODL_CTRL="odl_ctrl"
    NFVM_CTRL="nfvm_ctrl"
else
    DNS_SUFFIX=${FILENAME//smart_scan/}
    DIR_SUFFIX=${FILENAME//smart_scan_/}
    DEPLOY_PATH="/mnt/deploy/$DIR_SUFFIX/openstack-ansible/hosts"
    ODL_DB="odl_db${DNS_SUFFIX}"
    ODL_CTRL="odl_ctrl${DNS_SUFFIX}"
    NFVM_CTRL="nfvm_ctrl${DNS_SUFFIX}"
fi

PKT_NUM=2
IP6_SRC="240e:980:2000:2:8206:5810:a4e7:1a97"
IP6_CLIENT=113.59.224.28
IP6_PASSWD=$(echo bUg1fmRiaHh2dQo= | base64 -d)
SERVER_SSH_PORT=10000
HR=$(tr -cd '=' </dev/urandom  | head -c 112)
release_res(){
    echo "release resource"
    rm -rf $TEMP_DIR
}
trap "release_res" INT

print_prompt(){
    STR="$1"
    FLAG="$2"
    #0 warn_line 
    #1 error
    #2 error_line
    if [[ "$FLAG" -eq 2 ]]; then
        echo -e "\033[43;30m$STR\033[0m"
        echo "$HR"
    elif [[ "$FLAG" -eq 0 ]]; then
        echo -e "\033[41m$STR\033[0m"
    elif [[ "$FLAG" -eq 1 ]]; then
        echo -e "\033[41m$STR\033[0m"
        echo "$HR"
    fi
    rm -rf $TEMP_DIR
    exit 1
}

check_user(){
    if [[ $(whoami) != "root" ]];then
        print_prompt "Please switch root user before operation."
    fi
}
check_user


format_uuid(){
    BRIF_UUID=$1
    STR_NUM=$(echo -n "$BRIF_UUID" | wc -c)
    if [[ $STR_NUM -eq 32 ]]; then
        echo -n "$BRIF_UUID" | grep -qP '^[0-9a-z]{32}$'
        if [[ $? -eq 0 ]]; then
            python -c "import uuid;print uuid.UUID('$BRIF_UUID')"
        else
            echo "$ARG_TYPE"
        fi
    else
        echo "$ARG_TYPE"
    fi
}

declare -A IP2STAT
declare -A IP2USER
fast_ssh(){
    local CMD_STR=$*
    local HOSTIP="$1"
    
    ssh -n -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p${SERVER_SSH_PORT} $HOSTIP : 2>/dev/null
    if [[ $? -eq 0 ]]; then
        IP2USER["$HOSTIP"]='root'
    else
        IP2USER["$HOSTIP"]='secure'
    fi

    local CMD_STR_ROOT=$CMD_STR
    local CMD_STR_SECURE=$(echo $CMD_STR | sed 's/^/secure@/g;s/ / sudo /')

    if [[ "${IP2USER[$HOSTIP]}" == 'root' ]]; then
        ssh -n -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_ROOT 2>/dev/null

    elif [[ "${IP2USER[$HOSTIP]}" == 'secure' ]]; then
        ssh -n -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_SECURE 2>/dev/null
    fi
}

fast_ssh_bg(){
    local CMD_STR=$*
    local HOSTIP="$1"
    
    ssh -n -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p${SERVER_SSH_PORT} $HOSTIP : 2>/dev/null
    if [[ $? -eq 0 ]]; then
        IP2USER["$HOSTIP"]='root'
    else
        IP2USER["$HOSTIP"]='secure'
    fi

    local CMD_STR_ROOT=$CMD_STR
    local CMD_STR_SECURE=$(echo $CMD_STR | sed 's/^/secure@/g;s/ / sudo /')

    if [[ "${IP2USER[$HOSTIP]}" == 'root' ]]; then
        nohup ssh -n -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_ROOT &> auto_install_deploy_${HOSTIP}.log & 

    elif [[ "${IP2USER[$HOSTIP]}" == 'secure' ]]; then
        nohup ssh -n -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_SECURE &> auto_install_deploy_${HOSTIP}.log & 
    fi
}


fast_login(){
    local CMD_STR=$*
    local HOSTIP="$1"

    ssh -n -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p${SERVER_SSH_PORT} $HOSTIP : 2>/dev/null
    if [[ $? -eq 0 ]]; then
        IP2USER["$HOSTIP"]='root'
    else
        IP2USER["$HOSTIP"]='secure'
    fi

    local CMD_STR_ROOT=$CMD_STR
    local CMD_STR_SECURE=$(echo $CMD_STR | sed 's/^/secure@/g;s/ / sudo /')

    if [[ "${IP2USER[$HOSTIP]}" == 'root' ]]; then
        ssh -tt -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_ROOT 2>/dev/null

        if [[ $? -eq 255 ]]; then
            echo $CMD_STR_SECURE | grep -q 'sshpass\|console' 
            if [[ $? -eq 0 ]]; then
                ssh -tt -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_SECURE 2>/dev/null
            else
                ssh -tt -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_SECURE sudo su 2>/dev/null
            fi
        fi
    elif [[ "${IP2USER[$HOSTIP]}" == 'secure' ]]; then
        echo $CMD_STR_SECURE | grep -q 'sshpass\|console' 
        if [[ $? -eq 0 ]]; then
            ssh -tt -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_SECURE 2>/dev/null
        else
            ssh -tt -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_SECURE sudo su 2>/dev/null
        fi
        if [[ $? -eq 255 ]]; then
            echo $CMD_STR_ROOT | grep -q 'sshpass\|console' 
            if [[ $? -eq 0 ]]; then
                ssh -tt -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_ROOT 2>/dev/null
            else
                ssh -tt -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $CMD_STR_ROOT sudo su 2>/dev/null
            fi
        fi
    fi
}

get_odl_prop(){
    CONF_PATH=$1
    FIELD=$2
    fast_ssh "$ODL_CTRL" grep $FIELD= $CONF_PATH | awk -F= '{print $NF}' | xargs | sed 's/\r//g'
}

SQL_STR_ALL="select A.vm_stat,A.vm_ip,A.fip,A.vm_link_if,A.vm_host_ip,B.vpp_ip,B.ver,B.type,A.device,A.tenant_id,A.vm_port_id from (select A.device,A.tenant_id,B.port_id as vm_port_id,A.ip as vm_ip,B.floating_ip as fip,A.name as vm_link_if,A.host_ip as vm_host_ip,A.status as vm_stat from (select device,tenant_id,id,case when ip is null then substring(fix_ips from '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') else ip end as ip,name,host_ip,status from port where is_deleted is null and (device_owner like 'compute:%' or device_owner='baremetal:none')) A right join (select port_id,floating_ip from floatingip where is_deleted is null and port_id <>'') B on A.id = B.port_id ) A inner join (select A.vpp_ip,A.type,B.ver,A.id from (select manage_ip as vpp_ip,gate_way_type as type,image_ref,json_object_keys(tenant_infos::json) as id from vpp where is_deleted is null) A left join (select name as ver,id from nfv_image where is_deleted is null) B on A.image_ref=B.id) B on A.tenant_id = B.id;"
SQL_STR_FILTER="select A.vm_stat,A.vm_ip,A.fip,B.ver,A.vm_host_ip,B.vpp_ip,B.type,A.vm_type,A.tenant_id from (select A.tenant_id,A.vm_type,A.ip as vm_ip,B.floating_ip as fip,A.name as vm_link_if,A.host_ip as vm_host_ip,A.status as vm_stat from (select tenant_id,id,case when ip is null then substring(fix_ips from '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') else ip end as ip,name,host_ip,status,device_owner as vm_type from port where is_deleted is null and host_ip <>'' and (device_owner like 'compute:%' or device_owner='baremetal:none')) A right join (select port_id,floating_ip from floatingip where is_deleted is null and port_id <>'') B on A.id = B.port_id ) A inner join (select A.vpp_ip,A.type,B.ver,A.id from (select manage_ip as vpp_ip,gate_way_type as type,image_ref,json_object_keys(tenant_infos::json) as id from vpp where is_deleted is null) A left join (select name as ver,id from nfv_image where is_deleted is null) B on A.image_ref=B.id) B on A.tenant_id = B.id order by fip;"
SQL_IP6_STR_ALL="select A.status,A.ip_address,A.name as tap,A.host_ip,B.type,B.vpp_ip,B.ver,A.bd_id,A.vrf_id,A.device,A.tenant_id,A.port_id from (select A.device,A.status,A.ip_address,A.name,A.host_ip,A.tenant_id,A.port_id,B.vrf_id,A.bd_id from (select A.device,A.status,A.ip_address,A.name,A.host_ip,A.tenant_id,A.port_id,A.router_id,B.bd_id from (select B.device,B.status,A.ip_address,B.name,B.host_ip,A.tenant_id,A.port_id,A.router_id,B.network_id from (select ip_address,port_id,router_id,tenant_id from ipv6ndproxy where is_deleted is null) A inner join (select device,status,host_ip,id,name,network_id from port where is_deleted is null and host_ip<>'') B on A.port_id=B.id) A left join (select id,segmentation_id as bd_id from network where is_deleted is null) B on A.network_id=B.id) A left join (select id,vrf_table_id as vrf_id from router where is_deleted is null) B on A.router_id=B.id) A left join (select A.vpp_ip,A.type,B.ver,A.id from (select manage_ip as vpp_ip,gate_way_type as type,image_ref,json_object_keys(tenant_infos::json) as id from vpp where is_deleted is null) A left join (select name as ver,id from nfv_image where is_deleted is null) B on A.image_ref=B.id) B on A.tenant_id=B.id;"
SQL_IP6_STR_FILTER="select A.status,A.ip_address,A.name as tap,A.host_ip,B.vpp_ip,B.type,B.ver,A.vm_type,A.tenant_id from (select A.status,A.ip_address,A.name,A.host_ip,A.tenant_id,A.vm_type,B.vrf_id,A.bd_id from (select A.status,A.ip_address,A.name,A.host_ip,A.tenant_id,A.vm_type,A.router_id,B.bd_id from (select B.status,A.ip_address,B.name,B.host_ip,A.tenant_id,B.vm_type,A.router_id,B.network_id from (select ip_address,port_id,router_id,tenant_id from ipv6ndproxy where is_deleted is null) A inner join (select status,host_ip,id,device_owner as vm_type,name,network_id from port where is_deleted is null and host_ip<>'') B on A.port_id=B.id) A left join ( select id,segmentation_id as bd_id from network where is_deleted is null) B on A.network_id=B.id) A left join (select id,vrf_table_id as vrf_id from router where is_deleted is null) B on A.router_id=B.id) A left join (select A.vpp_ip,A.type,B.ver,A.id from (select manage_ip as vpp_ip,gate_way_type as type,image_ref,json_object_keys(tenant_infos::json) as id from vpp where is_deleted is null) A left join (select name as ver,id from nfv_image where is_deleted is null) B on A.image_ref=B.id) B on A.tenant_id=B.id order by ip_address;"
SQL_DCI_STR_ALL="select tenant_id,(select network_id from subnet where id=A.subnet_id) as vpc_id,type,(select vrf_table_id from router where subnets like concat('%',A.subnet_id,'%')) as vrf_id,regexp_split_to_table(json_array_elements_text(dst_cidr::json),',') as dst_cidr,out_if,next_hop from (select tenant_id,dst_subnet_cidr_members as dst_cidr,case when service_type is null then 'dci' else 'vpn' end as type,json_object_keys(src_subnet_members::json) as subnet_id,src_subnet_members::json->json_object_keys(src_subnet_members::json)->>'gatewayIp' as next_hop,concat('loop',src_subnet_members::json->json_object_keys(src_subnet_members::json)->>'vni') as out_if from clouddcpeer where is_deleted is null) A;"
SQL_DCI_STR_FILTER="select (select network_id from subnet where id=A.subnet_id) as vpc_id,type,(select vrf_table_id from router where subnets like concat('%',A.subnet_id,'%')) as vrf_id,regexp_split_to_table(json_array_elements_text(dst_cidr::json),',') as dst_cidr,out_if,next_hop,tenant_id from (select tenant_id,dst_subnet_cidr_members as dst_cidr,case when service_type is null then 'dci' else 'vpn' end as type,json_object_keys(src_subnet_members::json) as subnet_id,src_subnet_members::json->json_object_keys(src_subnet_members::json)->>'gatewayIp' as next_hop,concat('loop',src_subnet_members::json->json_object_keys(src_subnet_members::json)->>'vni') as out_if from clouddcpeer where is_deleted is null) A;"
SQL_VPC_PEER_STR_ALL='select id,case when l_loop_ip=next_hop then local_cip else remote_cip end as src_vtep,case when l_loop_ip=next_hop then remote_cip else local_cip end as dst_vtep,vni,B.loop,B.vrf_id,B.second_vrf_id as s_vrf,case when l_loop_ip=next_hop then r_loop_ip else l_loop_ip end as loop_ip,B.dst_cidr,B.next_hop from (select id,request_tenant_id,accept_tenant_id,request_network_id,accept_network_id,(select vpp_cluster_ip from tenant where id=request_tenant_id) as local_cip,(select vpp_cluster_ip from tenant where id=accept_tenant_id) as remote_cip ,segmentation_id as vni,request_loop_ip as l_loop_ip,accept_loop_ip as r_loop_ip from vpcpeer where is_deleted is null ) A right join (select out_interface as loop,vrf_id,second_vrf_id,destination as dst_cidr,next_hop,vpc_peer_id from vpcpeerroute where is_deleted is null) B on A.id=B.vpc_peer_id;'
SQL_VPC_PEER_STR_FILTER='select id,case when l_loop_ip=next_hop then request_tenant_id else accept_tenant_id end as tenant_id,case when l_loop_ip=next_hop then local_cip else remote_cip end as src_vtep,case when l_loop_ip=next_hop then remote_cip else local_cip end as dst_vtep,vni,B.loop,B.vrf_id,B.second_vrf_id as s_vrf,case when l_loop_ip=next_hop then r_loop_ip else l_loop_ip end as loop_ip,B.dst_cidr,B.next_hop from (select id,request_tenant_id,accept_tenant_id,request_network_id,accept_network_id,(select vpp_cluster_ip from tenant where id=request_tenant_id) as local_cip,(select vpp_cluster_ip from tenant where id=accept_tenant_id) as remote_cip ,segmentation_id as vni,request_loop_ip as l_loop_ip,accept_loop_ip as r_loop_ip from vpcpeer where is_deleted is null ) A right join (select out_interface as loop,vrf_id,second_vrf_id,destination as dst_cidr,next_hop,vpc_peer_id from vpcpeerroute where is_deleted is null) B on A.id=B.vpc_peer_id;'

var_init(){
    fast_ssh "$ODL_CTRL" systemctl list-units --type service | grep -q taitan.service
    if [[ $? -eq 0 ]]; then
        TAITAN_RUN_FILE=$(fast_ssh "$ODL_CTRL" systemctl cat taitan.service  | grep ExecStart | awk -F= '{print $2}')
        TAITAN_PATH=$(dirname $TAITAN_RUN_FILE)
        ODL_VERSION=$(get_odl_prop "$TAITAN_PATH/configuration/etc/vtn_config.properties" 'version' | grep -Po '(\d+\.){2}\d+' | xargs)
        POSTGRSQL_PASSWD=$(get_odl_prop "$TAITAN_PATH/config/application-db.properties" 'spring.datasource.password')
        REDIS_PASSWD=$(get_odl_prop "$TAITAN_PATH/configuration/etc/RedisStore.properties" 'password')
        VPN_GWIP=$(get_odl_prop "$TAITAN_PATH/configuration/etc/vtn_config.properties" 'specialLineSwitchIp')
        DCI_GWIP=$(get_odl_prop "$TAITAN_PATH/configuration/etc/vtn_config.properties" 'enterpriseGatewayIp')

    else
        ODL_VERSION=$(get_odl_prop '/root/distribution-karaf-0.6.0-Carbon/etc/vtn_config.properties' 'version' | grep -Po '(\d+\.){2}\d+' | xargs)
        POSTGRSQL_PASSWD=$(get_odl_prop '/root/distribution-karaf-0.6.0-Carbon/etc/DataSource.properties' 'password')
        REDIS_PASSWD=$(get_odl_prop '/root/distribution-karaf-0.6.0-Carbon/etc/RedisStore.properties' 'password')
        VPN_GWIP=$(get_odl_prop '/root/distribution-karaf-0.6.0-Carbon/etc/vtn_config.properties' 'specialLineSwitchIp')
        DCI_GWIP=$(get_odl_prop '/root/distribution-karaf-0.6.0-Carbon/etc/vtn_config.properties' 'enterpriseGatewayIp')
    fi
}

var_init
export PGPASSWORD=$POSTGRSQL_PASSWD

left_align_print(){
    printf "%-50s %0s\n" "$1" "$2"
}

run_odl_sql(){
    SQL_STR="$1"
    SQL_KEY="$2"
    SQL_STR=$(echo "$SQL_STR" | sed "s#@@@#$SQL_KEY#g")
    psql -h $ODL_DB -U postgres -d postgres -t -c "$SQL_STR" 2>/dev/null | awk '{print $NF}'
}

run_vpp_cmd(){
    VPP_CMD="$*"
    fast_ssh $EXT_ARGS $VPP_IP vppctl "$VPP_CMD"   
}


check_reach(){
    IP="$1"
    ping -w 1 -c 1 "$IP" &>/dev/null
    if [[ $? -ne 0 ]]; then
       ping -w 2 -c 2 "$IP" &>/dev/null
       if [[ $? -ne 0 ]]; then
           print_prompt "The $IP address unreachable."
       fi
    fi
}

check_env_reach(){
    check_reach "$ODL_DB"
    check_reach "$ODL_CTRL"
    check_reach "$NFVM_CTRL"
}

yum_install(){
    local PKG_NAME="$1"
    rpm -q $PKG_NAME &>/dev/null || yum install -y $PKG_NAME
}

check_env_software(){
    yum_install mariadb
    yum_install nmap-ncat
    yum_install postgresql
    yum_install redis
    fast_ssh $ODL_CTRL rm /root/.ssh/known_hosts &>/dev/null
    fast_ssh $ODL_CTRL sshpass -v &>/dev/null || fast_ssh $ODL_CTRL yum install -y sshpass
}

check_db_table(){
    DB_TB_SIZE=$(psql -h $ODL_DB -U postgres -d postgres -c "\dt" | grep -c " port \| floatingip \| vpp \| nfv_image \| tenant ")
    if [[ "$DB_TB_SIZE" -lt 5 ]]; then
        DB_TB=$(psql -h $ODL_DB -U postgres -d postgres -c "\dt" | grep -o " port \| floatingip \| vpp \| nfv_image \| tenant " | xargs )
        print_prompt "Database tables need (port floatingip vpp nfv_image tenant), The normal table has ($DB_TB)"
    fi
}

check_install_tcpdump(){
    HOST_IP="$1"
    TIP="$2"
    if [[ -z "$HOST_IP" ]]; then
        print_prompt "Physical tenants gateway does not exist the host machine."
    fi
    ping -c 1 -w 1 "$HOST_IP" &> /dev/null
    if [[ $? -ne 0 ]]; then
        print_prompt "The $TIP Host($HOST_IP) address entered incorrectly or unreachable."
    else
        fast_ssh "$HOST_IP" tcpdump --version &>/dev/null
        if [[ $? -ne 0 ]]; then
            fast_ssh "$HOST_IP" yum install -y tcpdump
        fi 
    fi
}

check_vpp_coredump(){
    if [[ -z "$ARG_TYPE" ]];then
        VPP_LIST=($(run_odl_sql "select @@@ from vpp where is_deleted is null order by id desc;" "id"))
    else
        VPP_LIST=($(run_odl_sql "select manage_ip from (select (select name from nfv_image where id=image_ref and is_deleted is null),manage_ip from vpp where is_deleted is null) A where A.name='@@@' order by manage_ip desc ;" "$ARG_TYPE"))
    fi
    TOTAL_NUM=${#VPP_LIST[*]}
    echo "$HR"
    echo -e "When the /tmp/vpp_coredump file exists, please use the command (\033[41msmart_scan -e <vpp_ip> \033[0m) to login to verify."
    COUNT=0
    for (( i = 0; i < $TOTAL_NUM; i++ )); do
        if nc -w 0.2 -z ${VPP_LIST[$i]} $SERVER_SSH_PORT &>/dev/null ; then
            EXT_ARGS=""
            ping -w 1 -c 1 ${VPP_LIST[$i]} &> /dev/null
        else
            EXT_ARGS="$ODL_CTRL sshpass -pfd10_VNF ssh -o StrictHostKeyChecking=no"
            fast_ssh $ODL_CTRL ping -w 1 -c 1 ${VPP_LIST[$i]} &> /dev/null
        fi
        if [[ $? -eq 0 ]]; then
            fast_ssh $EXT_ARGS ${VPP_LIST[$i]} ls /tmp/ 2>/dev/null | grep -q vpp_coredump
            if [[ $? -eq 0 ]]; then
                echo -e "\033[41m$[i+1]/$TOTAL_NUM) ${VPP_LIST[$i]} Coredump file exists.\033[0m"
                VPP_VER_TAG=$(fast_ssh $EXT_ARGS ${VPP_LIST[$i]} vppctl sh version verbose 2>/dev/null | grep location | awk '{print $NF}' | sed 's/\r//g')
                CORE_DUMP_VPPS[$[COUNT++]]=${VPP_LIST[$i]}@${VPP_VER_TAG}
            else
                echo "$[i+1]/$TOTAL_NUM) ${VPP_LIST[$i]} No Coredump file exists."
            fi
        else
            echo -e "$[i+1]/$TOTAL_NUM) ${VPP_LIST[$i]} The address is not accessible."
        fi
    done
    COREDUMP_NUM=${#CORE_DUMP_VPPS[*]}
    if [[ $COREDUMP_NUM -ne 0 ]]; then
        echo "${HR//=/-}"
        for (( j = 0; j <$COREDUMP_NUM; j++ )); do
            echo "smart_scan -e ${CORE_DUMP_VPPS[$j]%@*}     ${CORE_DUMP_VPPS[$j]#*@}"
        done
    fi
    echo "$HR"
}

get_vm_vnc_url(){
    VM_DEVICE_ID=$1
    if [[ -e $DEPLOY_PATH ]]; then
        cat $DEPLOY_PATH | grep "^\[\|^[0-9]" | sed 's/\[/\n\[/g;s/\r//g' > /tmp/openstack-ansible-host.tmp
        OS_CTRL=$( grep -A 1 os-controller /tmp/openstack-ansible-host.tmp | tail -1 | awk '{print $1}' | xargs)
        ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p${SERVER_SSH_PORT} $OS_CTRL : &>/dev/null
        if [[ $? -eq 255 ]]; then
            ssh -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} secure@$OS_CTRL sudo -su root <<EOF
source /root/admin-openrc.sh;
nova get-vnc-console $VM_DEVICE_ID novnc
EOF
        else
            ssh -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $OS_CTRL "( source /root/admin-openrc.sh; nova get-vnc-console $VM_DEVICE_ID novnc )"
        fi
         
    else
        echo -e "\033[5;41mThe deployment file($DEPLOY_PATH) does not exist...\033[0m\a"
    fi
}

get_vpp_host_ip_by_device(){
    local DEVICE_ID=$1
    MYSQL_STR="select node from instances where vm_state = 'active' and @@@;"
    MYSQL_STR=$(echo "$MYSQL_STR" | sed "s/@@@/uuid='$DEVICE_ID'/g")
    MYSQL_PASSWD=$(fast_ssh "$NFVM_CTRL" grep connection /etc/neutron/neutron.conf  | grep -Po '(?<=openstack:).*(?=@)')
    MYSQL_RS=$(mysql -h $NFVM_CTRL -P23306 -u openstack -p$MYSQL_PASSWD nova -N -e "$MYSQL_STR")
    echo ${MYSQL_RS##*-} | sed 's/e/./g'
}


remote_enter(){
    if [[ -z "$ARG_TYPE" ]]; then
        echo "$HR"
        echo '1) enter odl postgresql database'
        echo '2) enter odl redis database'
        echo "$HR"
        read -p 'Please enter a valid database number: ' DB_NO
        case $DB_NO in
            2 )
                if [[ -e $DEPLOY_PATH ]]; then
                    cat $DEPLOY_PATH | grep "^\[\|^[0-9]" | sed 's/\[/\n\[/g;s/\r//g'  > /tmp/openstack-ansible-host.tmp
                    ODL_REDIS=$( grep -A 1 odl_redis /tmp/openstack-ansible-host.tmp | tail -1 | awk '{print $1}' | xargs)
                    redis-cli -c -h $ODL_REDIS -p 7000 -a $REDIS_PASSWD
                else
                    echo -e "\033[5;41mThe deployment file($DEPLOY_PATH) does not exist...\033[0m\a"
                fi
                ;;
            * )
                psql -h $ODL_DB -U postgres -d postgres
                ;;

        esac
        
    else
        format_dns(){
            DNS_STR=$1
            echo "$DNS_STR" | grep -qP '^odl_ctrl$|^odl_db$|^nfvm_ctrl$'
            if [[ $? -eq 0 ]]; then
                echo "$DNS_STR$DNS_SUFFIX"
            else
                echo "$DNS_STR"
            fi
        }
        VPP_IP=$(format_dns $ARG_TYPE)
        VPP_TYPE=$(run_odl_sql "select gate_way_type from vpp where manage_ip='@@@';" "$VPP_IP")
        if [[ $ARG_VAL == "host" ]];then
            VPP_DEVICE_ID=$(run_odl_sql "select vpp_id from vpp where manage_ip='@@@';" "$VPP_IP")
            if [[ $VPP_DEVICE_ID ]]; then
                VPP_HOST_IP=$(get_vpp_host_ip_by_device $VPP_DEVICE_ID)
                login_vpp_host
            else
                print_prompt "The corresponding host was not found..." 
            fi
        else
            CLUSTER_STR="select concat(A.manage_ip,'  ',B.manage_ip) as manage_ip from (select manage_ip,cluster_ip from vpp where is_deleted is null order by manage_ip desc) A left join (select manage_ip,cluster_ip from vpp where is_deleted is null order by manage_ip asc) B on A.cluster_ip=B.cluster_ip and A.manage_ip<>B.manage_ip;"
            VPP_CLUSTER=($(psql -h $ODL_DB -U postgres -d postgres -c "$CLUSTER_STR" 2>/dev/null | grep "^\s\+$VPP_IP "))
            
            shift

            get_vpp_role_by_clusters
            
            if [[ ${#VPP_CLUSTER[*]} -ne 0 ]]; then
                VPP_PROMPT="The current login type is ( $VPP_TYPE ) address ${VPP_CLUSTER[0]} ( $VPP_A_ROLE ),Another is ${VPP_CLUSTER[1]} ( $VPP_B_ROLE )."
                echo -e $VPP_PROMPT
            fi

            if nc -w 0.2 -z $VPP_IP $SERVER_SSH_PORT &>/dev/null ; then
                fast_login $VPP_IP
            else
                if ping -w 1 -c 1 $ODL_CTRL &>/dev/null; then
                    if fast_ssh $ODL_CTRL ping -c 1 -w 1 $VPP_IP &>/dev/null; then
                        fast_login $ODL_CTRL sshpass -pfd10_VNF ssh -o StrictHostKeyChecking=no $VPP_IP
                    else
                        print_prompt "VPP Address entered incorrectly or unreachable."
                    fi
                else
                    print_prompt "The $ODL_CTRL address unreachable."
                fi
            fi
        fi
        
    fi
}

usage(){
cat > usage.tmp <<\EOF
smart_scan [OPTIONS...] {COMMAND} ...
  -e --enter      Enter the VPP virtual machine or controller database
        
        ps:
           smart_scan -e 
           smart_scan -e <$ip_address>
           smart_scan -e <$vpp_ip> host



  -b --batch       Execute remote commands on each VPP machine

        ps:
           smart_scan -b 
           smart_scan -b master
           smart_scan -b backup

  -f --filter         According to the conditions specified query information of fip and verify whether can reach

        ps:
            smart_scan -f
            smart_scan -f <$fip> 
            smart_scan -f <$ver>
            smart_scan -f <$filter_str>
            smart_scan -f <$nd_address>

  -g --get            Get VPP network resources and their corresponding relationship with the host.

        note:         ucp (Unified Cloud Platform).
        
        ps:
            smart_scan -g 
            smart_scan -g <$vpp_ip>
            smart_scan -g <$tenant_id>
            smart_scan -g <$filter_str>
            smart_scan -g <$fip>
            smart_scan -g <$ucp_vpc_id>
            smart_scan -g <$ucp_port_id>
            smart_scan -g <$host_addreess> lldp


  -t --trace           Gets interface information on the host or executes commands

        ps:
            smart_scan -t <$fip>
            smart_scan -t <$fip> <$port>
            smart_scan -t <$nd_address>
            smart_scan -t <$nd_address> <$port>

  -c --config           Remote execution of VPP virtual machine commands

        ps:
            smart_scan -c <$fip>
            smart_scan -c <$nd_address>
            smart_scan -c <$ucp_vpc_id> 


  -l --login         Remote login specifies IP address

        < vm | vpp | vm_host | vpp_host >

        ps:
            smart_scan -l [<$fip> | <$nd> | $<vm_device_id>] vm
            smart_scan -l [<$fip> | <$nd> | $<vm_device_id>] vm_vnc
            smart_scan -l [<$fip> | <$nd>] vpp
            smart_scan -l [<$fip> | <$nd>] vm_host
            smart_scan -l [<$fip> | <$nd>] vpp_host


  -cd --coredump      Check the VPP that generated the coredump file
  
        ps:
            smart_scan -cd 
            smart_scan -cd <$vpp_ver>

  -el --enter-list  Quick login from the deployment file ($DEPLOY_PATH)
          
        ps:
            smart_scan -el
 
EOF
more -45 usage.tmp
}

filter_data(){
    SQL_STR="$1"
    TABLE_NAME=$2
    FILTER="$ARG_TYPE"
    check_db_table
    TABLE_NUM=$(run_odl_sql "select count(*) from pg_class where relname = '@@@';" "$TABLE_NAME" )
    if [[ $TABLE_NUM -ge 1 ]]; then
        TABLE_INS=$(run_odl_sql "select count(*) from @@@ where is_deleted is null;" "$TABLE_NAME")
        if [[ $TABLE_INS -gt 0 ]]; then
            psql -h $ODL_DB -U postgres -d postgres -c "$SQL_STR" > vpp_temp.dat
            ARG_TYPE=$(format_uuid $ARG_TYPE)
            FILTER="$ARG_TYPE"
            grep \| vpp_temp.dat | sed -n '2,$p' > vpp.dat

            grep "$FILTER" vpp.dat > vpp_filter_s.dat
            LINE_TOTAL=$(grep "$FILTER" vpp.dat | wc -l)
            
            echo -e "According to the filter information, a total of \033[41m($(echo $LINE_TOTAL))\033[0m pieces of \033[41m$TABLE_NAME\033[0m data were searched:"
            grep '+' vpp_temp.dat | sed 's/-\|+/=/g;s/\(.*\)/========\1/g'
            head -1 vpp_temp.dat | sed 's/\(.*\)/        \1/g'
            head -2 vpp_temp.dat | tail -1  | sed 's/\(.*\)/--------\1/g'
            nl -n rz vpp_filter_s.dat | grep "$FILTER" --color=always  | more -20 
            grep '+' vpp_temp.dat | sed 's/-\|+/=/g;s/\(.*\)/========\1/g'
            echo 
        fi
    fi
}

proc_filter_data(){
    filter_data "$SQL_STR_FILTER" 'floatingip'
    filter_data "$SQL_IP6_STR_FILTER" 'ipv6ndproxy'
    filter_data "$SQL_DCI_STR_FILTER" 'clouddcpeer'
    filter_data "$SQL_VPC_PEER_STR_FILTER" 'vpcpeer'

}

get_fip_gw_ip_by_fip(){
    FIP="$1"
    FIP_SUBNET_ID=$(run_odl_sql "select subnet_id from port where is_deleted is null and ip='@@@';" ""$FIP"")
    FIP_GW_IP=$(run_odl_sql "select gw_ip from subnet where is_deleted is null and id='@@@';" "$FIP_SUBNET_ID")
    if [[ -z "$FIP_GW_IP" ]]; then
        FIP_GW_IP=$(run_odl_sql "select gw_ip from subnet where id in (select json_object_keys(fix_ips::json) from port where is_deleted is null and fix_ips like '%@@@%' ) and ip_version='4'" "$FIP")
    fi
    echo "$FIP_GW_IP"
}

format_ipv6(){
   local ADDRESS="$1"
   local L=$(echo $ADDRESS | grep -Po '[0-9a-f]{1,4}' | wc -l)
   local R=$[8-L]
   local RSTR=$(tr -cd '0-9' </dev/urandom | head -c $R | sed 's/./ 0000 /g')
   local ADDRESS=$(echo $ADDRESS | sed "s/::/$RSTR/g;s/:/ /g")
   for A in $(echo $ADDRESS);do
       printf "%4s" $A|sed 's/ /0/g'; 
   done 
}

split_ipv6_exp(){
    local HEX_IPV6=$1
    local S=$2
    local R=""
    for ADDR in $(echo "$HEX_IPV6" | grep -Po '[0-9a-f]{8}');do 
        R=$R" ether[$S:4]=0x$ADDR ";
        S=$[S+4]
    done
    echo "$R" | xargs | sed 's/ / and /g'
}

get_vpp_host_if_info(){

    if [[ $VPP_TYPE =~ "physical" ]] ;then
        print_prompt "The physical VPP has no host..."
    else
        if [[ -n "$VPP_HOST_IP" ]]; then
            if [[ $VPP_TYPE =~ "sriov" ]]; then
                VPP_KID=$(fast_ssh $VPP_HOST_IP virsh list | grep  $VPP_DEVICE_ID | awk '{print $1}')
            else
                check_install_tcpdump "$VPP_HOST_IP" "VPP"
                VPP_KID=$(fast_ssh $VPP_HOST_IP virsh list | grep  $VPP_DEVICE_ID | awk '{print $1}')
                VPP_HOST_ETH_INFO=$(fast_ssh $VPP_HOST_IP virsh domiflist $VPP_DEVICE_ID | grep tap | tail -2  | awk '{print $1,$3}')
                VPP_INT_TAP=$(echo $VPP_HOST_ETH_INFO | xargs | awk '{print $1}')
                VPP_INT_BRD=$(echo $VPP_HOST_ETH_INFO | xargs | awk '{print $2}')
                VPP_EXT_TAP=$(echo $VPP_HOST_ETH_INFO | xargs | awk '{print $3}')
                VPP_EXT_BRD=$(echo $VPP_HOST_ETH_INFO | xargs | awk '{print $4}')
                if [[ $VPP_INT_BRD ]]; then
                    VPP_HOST_INT_BOND=$(fast_ssh $VPP_HOST_IP brctl show | grep $VPP_INT_BRD | xargs | awk '{print $NF}')
                fi
                if [[ $VPP_EXT_BRD ]]; then
                    VPP_HOST_EXT_BOND=$(fast_ssh $VPP_HOST_IP brctl show | grep $VPP_EXT_BRD | xargs | awk '{print $NF}')
                fi
            fi
        fi   
    fi
}

login_vpp_host(){
    get_vpp_host_if_info
    
    echo "$HR"
    echo "VPP_HOST_IP:$VPP_HOST_IP (kid: $VPP_KID)"
    echo "VPP_TYPE: $VPP_TYPE"
    echo "$VPP_TYPE" | grep -q sriov
    if [[ $? -ne 0 ]];then 
        left_align_print "VPP_HOST_EXT_BOND: $VPP_HOST_EXT_BOND" "VPP_EXT_TAP: $VPP_EXT_TAP"
        left_align_print "VPP_HOST_INT_BOND: $VPP_HOST_INT_BOND" "VPP_INT_TAP: $VPP_INT_TAP"
    fi
    echo "$HR"

    fast_login $VPP_HOST_IP
}

get_vm_host_if_info(){
    if [[ $VM_TYPE == "normal" ]]; then
        if [[ -n "$VM_HOST_IP" ]]; then
            check_install_tcpdump "$VM_HOST_IP" "VM"
            VM_HOST_INT_BOND=$(fast_ssh $VM_HOST_IP ip a | grep "$OVS_VTEP/" | awk '{print $NF}')
            VM_KID=$(fast_ssh $VM_HOST_IP virsh list | grep  $VM_DEVICE_ID | awk '{print $1}')
        fi
    else
        print_prompt "Bare-metal format virtual machines are not supported..."
    fi
}


login_vm_host(){
    get_vm_host_if_info

    echo "$HR" 
    left_align_print "VM_HOST_IP:$VM_HOST_IP (kid: $VM_KID)" "VM_IP: $VM_IP"
    left_align_print "VM_HOST_INT_BOND: $VM_HOST_INT_BOND" "VM_TAP_IF: $VM_TAP_IF"
    left_align_print "VPP_VTEP: $VPP_VTEP" "OVS_VTEP: $OVS_VTEP"
    echo "$HR"

    fast_login "$VM_HOST_IP"
}

get_vpp_role_by_clusters(){
    if [[ ${#VPP_CLUSTER[*]} -ne 0 ]]; then
        if nc -w 0.2 -z ${VPP_CLUSTER[0]} $SERVER_SSH_PORT &>/dev/null; then
            IS_PHY=0
            EXT_ARGS=""
        else            
            IS_PHY=1
            EXT_ARGS="$ODL_CTRL sshpass -pfd10_VNF ssh -o StrictHostKeyChecking=no"
        fi

        VPP_A_ROLE=$(fast_ssh $EXT_ARGS ${VPP_CLUSTER[0]} vppctl sh vrrp 2>/dev/null |  grep "State Machine" | awk '{print $NF}' | sed 's/\r//g')
        VPP_B_ROLE=$(fast_ssh $EXT_ARGS ${VPP_CLUSTER[1]} vppctl sh vrrp 2>/dev/null |  grep "State Machine" | awk '{print $NF}' | sed 's/\r//g')
        if [[ -z "$VPP_A_ROLE" ]]; then
            VPP_A_ROLE="\033[31mAbnormal VRRP\033[0m"
        fi
        if [[ -z "$VPP_B_ROLE" ]]; then
            VPP_B_ROLE="\033[31mAbnormal VRRP\033[0m"
        fi
    fi
}


args_init(){
    local IP_VER=$1
    local IS_CAPTURE=$2

    if [[ $IP_VER == "ipv4" ]]; then
        DATA_FILE="vpp_all.dat"
    elif [[ $IP_VER == "ipv6" ]]; then
        DATA_FILE="vpp_ip6_all.dat"
    fi

    if [[ $(grep -c "$FILTER\ " $DATA_FILE) -eq 1 ]];then
        VPP_DAT=$(grep "$FILTER\ " $DATA_FILE)
    else

        VPP_CLUSTER=($(grep "$FILTER\ " $DATA_FILE | awk -F\| '{print $6}'))
        get_vpp_role_by_clusters

        if [[ "$VPP_A_ROLE" == "Master" ]]; then
            VPP_DAT=$(grep "$FILTER\ " $DATA_FILE | grep -v "${VPP_CLUSTER[1]} ")
            VPP_IP=${VPP_CLUSTER[0]}
            VPP_TYPE=$(run_odl_sql "select gate_way_type from vpp where manage_ip='@@@';" "$VPP_IP")
            VPP_PROMPT="${VPP_CLUSTER[0]}-$VPP_A_ROLE / ${VPP_CLUSTER[1]}-$VPP_B_ROLE"
            VPP_LOGIN_PROMPT="The current login type is ( $VPP_TYPE ) address ${VPP_CLUSTER[0]} ( $VPP_A_ROLE ), Another is ${VPP_CLUSTER[1]} ( $VPP_B_ROLE )."

        else
            VPP_DAT=$(grep "$FILTER\ " $DATA_FILE | grep -v "${VPP_CLUSTER[0]} ")
            VPP_IP=${VPP_CLUSTER[1]}
            VPP_TYPE=$(run_odl_sql "select gate_way_type from vpp where manage_ip='@@@';" "$VPP_IP")
            VPP_PROMPT="${VPP_CLUSTER[1]}-$VPP_B_ROLE / ${VPP_CLUSTER[0]}-$VPP_A_ROLE"
            VPP_LOGIN_PROMPT="The current login type is ( $VPP_TYPE ) address ${VPP_CLUSTER[1]} ( $VPP_B_ROLE ), Another is ${VPP_CLUSTER[0]} ( $VPP_A_ROLE )."
        fi
    fi

    VM_PORT_ID=$(echo $VPP_DAT| awk -F\| '{print $NF}' | xargs)
    TENANT_ID=$(echo $VPP_DAT| awk -F\| '{print $(NF-1)}' | xargs)
    VM_DEVICE_ID=$(echo $VPP_DAT| awk -F\| '{print $(NF-2)}' | xargs)
    VM_STAT=$(echo $VPP_DAT| awk -F\| '{print $1}' | xargs)
    VM_IP=$(echo $VPP_DAT| awk -F\| '{print $2}' | xargs)

    if [[ $IP_VER == "ipv4" ]]; then
        FIP=$(echo $VPP_DAT| awk -F\| '{print $3}' | xargs)
        VM_TAP_IF=$(echo $VPP_DAT| awk -F\| '{print $4}' | xargs)
        VM_HOST_IP=$(echo $VPP_DAT| awk -F\| '{print $5}' | xargs)
        DST_IP=$FIP
        ROUTER_ID=$(run_odl_sql "select router_id from floatingip where floating_ip = '@@@' and is_deleted is null;" $FIP)
        LOOP_VRF=$(run_odl_sql "select vrf_table_id from router where id = '@@@' and is_deleted is null ;" $ROUTER_ID)
        SQL_SG_STR="select * from(select distinct B.name,B.ver,case when B.remote_cidr is null then A.remote_cidr else B.remote_cidr end,B.port_range,B.type,B.direction,A.device from (select distinct AA.remote_security_group,BB.remote_cidr,BB.device from (select remote_security_group from securityrule where is_deleted is null and remote_security_group<>'') AA inner join (select json_object_keys(security_groups::json) as security_groups,concat(fix_ips::json->json_object_keys(fix_ips::json)->>'ip','/32') as remote_cidr,device  from port where is_deleted is null and security_groups is not null and security_groups<>'' and device <>'') BB on AA.remote_security_group=BB.security_groups) A right join (select B.name,A.ether_type as ver,A.remote_security_group,case when A.remote_cidr is null and remote_security_group is null then '0.0.0.0/0' else remote_cidr end,A.port_range,A.ip_protocol as type,A.direction from (select group_id,ether_type,remote_security_group,remote_cidr, case when port_min<>'' then concat(port_min,'-',port_max) else '1-65535' end as port_range,case when ip_protocol<>'' then ip_protocol else 'all' end as ip_protocol,direction from securityrule where  is_deleted is null and group_id in (select id from securitygroup where id in (select json_object_keys(security_groups::json) from port where id='@@@'))) A left join (select id,name from securitygroup where is_deleted is null) B on A.group_id=B.id) B on A.remote_security_group=B.remote_security_group)A where ver='IPv4' and family(remote_cidr::inet)='4';"
        DST_QOS_SQL="select floating_ip,speed_limit from (select A.floating_ip,case when A.speed_limit is null then '1Kbit' else concat(A.speed_limit,'Mb') end as speed_limit,'private' as type from ( select  floating_ip,substring(qos_policy_id from '[0-9]+$')::int as speed_limit  from floatingip where   is_deleted is null and qos_policy_id<>'')A union all select public_ip_infos::json->json_object_keys(public_ip_infos::json)->>'ip' as floating_ip,concat(substring(qos_policy_id from '[0-9]+$')::int,'Mb') as speed_limit,'public' as type from ippool where is_deleted is null) B  where floating_ip='@@@';"
        DST_QOS=$(run_odl_sql "$DST_QOS_SQL" "$DST_IP")
        DST_QOS_TYPE_SQL="select floating_ip,type from (select A.floating_ip,case when A.speed_limit is null then '1Kbit' else concat(A.speed_limit,'Mb') end as speed_limit,'private' as type from ( select  floating_ip,substring(qos_policy_id from '[0-9]+$')::int as speed_limit  from floatingip where   is_deleted is null and qos_policy_id<>'')A union all select public_ip_infos::json->json_object_keys(public_ip_infos::json)->>'ip' as floating_ip,concat(substring(qos_policy_id from '[0-9]+$')::int,'Mb') as speed_limit,'public' as type from ippool where is_deleted is null) B  where floating_ip='@@@';"
        DST_QOS_TYPE=$(run_odl_sql "$DST_QOS_TYPE_SQL" "$DST_IP")
        PROTOCOL_STR="and icmp"
    elif [[ $IP_VER == "ipv6" ]]; then
        VM_TAP_IF=$(echo $VPP_DAT| awk -F\| '{print $3}' | xargs)
        VM_HOST_IP=$(echo $VPP_DAT| awk -F\| '{print $4}' | xargs)
        LOOP_INS=$(echo $VPP_DAT| awk -F\| '{print $8}' | xargs)
        LOOP_VRF=$(echo $VPP_DAT| awk -F\| '{print $9}' | xargs)
        DST_IP=$VM_IP
        SQL_SG_STR="select * from(select distinct B.name,B.ver,case when B.remote_cidr is null then A.remote_cidr else B.remote_cidr end,B.port_range,B.type,B.direction,A.device from (select distinct AA.remote_security_group,BB.remote_cidr,BB.device from (select remote_security_group from securityrule where is_deleted is null and remote_security_group<>'') AA inner join (select json_object_keys(security_groups::json) as security_groups,concat(fix_ips::json->json_object_keys(fix_ips::json)->>'ip','/32') as remote_cidr,device  from port where is_deleted is null and security_groups is not null and security_groups<>'' and device <>'') BB on AA.remote_security_group=BB.security_groups) A right join (select B.name,A.ether_type as ver,A.remote_security_group,case when A.remote_cidr is null and remote_security_group is null then '::/0' else remote_cidr end,A.port_range,A.ip_protocol as type,A.direction from (select group_id,ether_type,remote_security_group,remote_cidr, case when port_min<>'' then concat(port_min,'-',port_max) else '1-65535' end as port_range,case when ip_protocol<>'' then ip_protocol else 'all' end as ip_protocol,direction from securityrule where  is_deleted is null and group_id in (select id from securitygroup where id in (select json_object_keys(security_groups::json) from port where id='@@@'))) A left join (select id,name from securitygroup where is_deleted is null) B on A.group_id=B.id) B on A.remote_security_group=B.remote_security_group)A where ver='IPv6' and family(remote_cidr::inet)='6';"
        DST_QOS_SQL="select case when A.speed_limit is null then '1Kbit' else concat(A.speed_limit,'Mb') end as speed_limit from (select substring(qos_policy_id from '[0-9]+$')::int as speed_limit from ipv6ndproxy where is_deleted is null and ip_address ='@@@') A; "
        DST_QOS=$(run_odl_sql "$DST_QOS_SQL" "$DST_IP")
        PROTOCOL_STR="and ip6 proto 58"
    fi

    SQL_SG_STR=$(echo "$SQL_SG_STR" | sed "s#@@@#$VM_PORT_ID#g")
    psql -h $ODL_DB -U postgres -d postgres -c "$SQL_SG_STR" 2>/dev/null > vpp_sg.dat
    if [[ $IP_VER == "ipv4" ]]; then
        grep -P '.*(all|icmp).*ingress' vpp_sg.dat > vpp_sg_proc.dat
        SUBNET_CIDR=$(run_odl_sql "select A.cidr from (select id,concat(gw_ip,substring(cidr from '/\d+')) as cidr from subnet where is_deleted is null) A left join (select id,fix_ips from port where is_deleted is null) B on position(A.id in B.fix_ips)!=0 where B.id='@@@' order by cidr limit 1;" "$VM_PORT_ID")


    elif [[ $IP_VER == "ipv6" ]]; then
        grep -P '.*(all|icmp).*ingress' vpp_sg.dat > vpp_sg_proc.dat
        SUBNET_CIDR=$(run_odl_sql "select concat(gw_ip,substring(cidr from '/.*')) from subnet where id in (select json_object_keys(fix_ips::json) from port where id='@@@') and ip_version='6';" "$VM_PORT_ID")
    fi

    EW_ENABLE_PING=1
    for SG_CIDR in $(cat vpp_sg_proc.dat | awk -F'|' '{print $3}'); do
        EW_ENABLE_PING_SQL="select network('${SUBNET_CIDR%/*}'::inet) && '@@@'::inet;"
        EW_PING_FLAG=$(run_odl_sql "$EW_ENABLE_PING_SQL" "$SG_CIDR")
        if [[ $EW_PING_FLAG == 't' ]]; then
            EW_ENABLE_PING=0
            break
        fi
    done

    VPP_SERVICE_IF=$(run_odl_sql "select interfaces::json->'service'->>'name' as service from vpp where is_deleted is null and manage_ip='@@@';" "$VPP_IP")
    VPP_EXTERNAL_IF=$(run_odl_sql "select interfaces::json->'external'->>'name' as external from vpp where is_deleted is null and manage_ip='@@@';" "$VPP_IP")

    VM_TYPE=$(run_odl_sql "select binding_vnic_type from port where is_deleted is null and id='@@@';" "$VM_PORT_ID")
    VPP_VTEP=$(run_odl_sql "select cluster_ip from vpp where manage_ip='@@@'" "$VPP_IP")
    if [[ $VM_TYPE == "baremetal" ]]; then
        OVS_VTEP=$(run_odl_sql "select cluster_ip from vpp where gate_way_type='@@@' and is_available='true' limit 1" "vxlanGw")
    else
        OVS_VTEP=$(run_odl_sql "select local_ip from host where is_deleted is null and host_ip='@@@';" "$VM_HOST_IP")
    fi
    VPP_DEVICE_ID=$(run_odl_sql "select vpp_id from vpp where manage_ip='@@@';" "$VPP_IP")
    VPP_HOST_IP=$(get_vpp_host_ip_by_device $VPP_DEVICE_ID)
    VPP_VERSION=$(fast_ssh $EXT_ARGS $VPP_IP vppctl sh version verbose | grep location | awk '{print $NF}' | sed 's/\r//g')

    if [[ $IS_CAPTURE ]]; then

        if [[ "$VM_TYPE" == "baremetal" ]]; then
            print_prompt "Bare-metal format virtual machines are not supported..."

        fi

        if [[ "$VM_STAT" == "offline" ]]; then
            print_prompt "The corresponding KVM virtual machine for vm is shutdown or does not exist."
        fi

        if [[ "$DST_QOS" == "1Kbit" ]] && [[ "$DST_QOS" != "0Mb" ]]; then
            echo "$HR"
            echo -e "\033[43;30mThe bandwidth of the address ($DST_IP) is ${DST_QOS}/s and has expired. The ping message will lose packets...\033[0m"
        fi

        if [[ $ENABLE_PHY_SRIOV_TRACE == "false" ]]; then
            if [[ $VPP_TYPE =~ "physical" ]] || [[ $VPP_TYPE =~ "sriov" ]]; then
                print_prompt "Physical and SR-IOV types do not currently support packet tracing..."
            fi
        fi
        
        kill_tty_all_tcpdump(){
            TTY_ID=$(who am i | awk '{print $2}'| awk -F/ '{print $2}') 
            ps -ef | grep pts/$TTY_ID.*tcpdump | awk '{print $2}'| xargs kill -9 &>/dev/null
        }
        kill_tty_all_tcpdump

        if [[ $IP_VER == "ipv4" ]]; then

            if [[ -e /tmp/vpp_client_ip_${XDG_SESSION_ID}.dat ]]; then
                SRC_IP=$(cat /tmp/vpp_client_ip_${XDG_SESSION_ID}.dat)
            else
                if [[ -z "$SRC_IP" ]]; then
                    
                    read -p "Please enter a ping client public export address: " SRC_IP 
                    echo $SRC_IP |  grep -qP '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
                    if [[ $? -ne 0 ]]; then
                        print_prompt "The address format you entered is incorrect..."
                    else
                        echo $SRC_IP > /tmp/vpp_client_ip_${XDG_SESSION_ID}.dat
                    fi
                fi
            fi

            SRC_IP_HEX=$(echo $SRC_IP | awk -F\. '{printf("0x%02x%02x%02x%02x",$1,$2,$3,$4)}')
            DST_IP_HEX=$(echo $VM_IP | awk -F\. '{printf("0x%02x%02x%02x%02x",$1,$2,$3,$4)}')
            PORT_HEX=$(echo "$PORT" | awk '{printf("0x%04x",$1)}')

            INNER_PORT_STR="\(ether[76:4] = $SRC_IP_HEX and ether[80:4] = $DST_IP_HEX and ether[86:2]=$PORT_HEX \) or \(ether[76:4] = $DST_IP_HEX and ether[80:4] = $SRC_IP_HEX and ether[84:2]=$PORT_HEX\)"
            INNER_ICMP_STR="\(ether[76:4] = $SRC_IP_HEX and ether[80:4] = $DST_IP_HEX and ether[73:1]=0x01\) or \(ether[76:4] = $DST_IP_HEX and ether[80:4] = $SRC_IP_HEX and ether[73:1]=0x01 \)"

        elif [[ $IP_VER == "ipv6" ]]; then
            SRC_IP=$IP6_SRC

            SRC_IP_HEX=$(format_ipv6 $SRC_IP)
            DST_IP_HEX=$(format_ipv6 $VM_IP)

            SRC_IP_EXP=$(split_ipv6_exp $SRC_IP_HEX 72)
            SRC_IP_BACK_EXP=$(split_ipv6_exp $SRC_IP_HEX 88)
            DST_IP_EXP=$(split_ipv6_exp $DST_IP_HEX 88)
            DST_IP_BACK_EXP=$(split_ipv6_exp $DST_IP_HEX 72)
            PORT_HEX=$(echo "$PORT" | awk '{printf("0x%04x",$1)}')

            INNER_PORT_STR="\($SRC_IP_EXP and $DST_IP_EXP and ether[106:2]=$PORT_HEX \) or \($SRC_IP_BACK_EXP and $DST_IP_BACK_EXP and ether[104:2]=$PORT_HEX\)"
            INNER_ICMP_STR="\($SRC_IP_EXP and $DST_IP_EXP and ether[70:1]=0x3a\) or \($SRC_IP_BACK_EXP and $DST_IP_BACK_EXP and ether[70:1]=0x3a \)"
        fi

        NS_ENABLE_PING=1
        for SG_CIDR in $(cat vpp_sg_proc.dat |  awk -F'|' '{print $3}'); do
            NS_ENABLE_PING_SQL="select network('${SRC_IP}'::inet) && '@@@'::inet;"
            NS_PING_FLAG=$(run_odl_sql "$NS_ENABLE_PING_SQL" "$SG_CIDR")
            if [[ $NS_PING_FLAG == 't' ]]; then
                NS_ENABLE_PING=0
                break
            fi
        done

        get_vm_host_if_info

        if [[ $VPP_TYPE =~ "physical" ]] || [[ $VPP_TYPE =~ "sriov" ]]; then
            VPP_VERSION_TIME=$(fast_ssh $EXT_ARGS $VPP_IP vppctl sh version verbose | grep "Compile date" |awk -F"date:" '{print $NF}' | xargs -i date -d {} +%s)
            VPP_VERSION_NO=$(fast_ssh $EXT_ARGS $VPP_IP vppctl sh version verbose | grep location | awk -F/ '{print $5}' | awk -F. '{print $NF}')
            VPP_VERSION_NUM=$(echo $VPP_VERSION_NO | awk -F. '{print $NF}')
            if [[ $VPP_VERSION_NUM -ge 111 ]] || [[ $VPP_VERSION_TIME -ge 1605054234 ]]; then
                fast_ssh $EXT_ARGS $VPP_IP vppctl sh int | grep -q tapcli
                if [[ $? -ne 0 ]]; then
                    fast_ssh $EXT_ARGS $VPP_IP vppctl tap connect vpp_int &>/dev/null
                    fast_ssh $EXT_ARGS $VPP_IP vppctl set interface state tapcli-0 up
                    fast_ssh $EXT_ARGS $VPP_IP vppctl tap connect vpp_ext &>/dev/null
                    fast_ssh $EXT_ARGS $VPP_IP vppctl set interface state tapcli-1 up
                fi
                PROC_PID=$$
                echo "$PROC_PID $DST_IP $IP_VER" >> /tmp/vpp_gen_tap.dat

                VPP_EXT_TAP='vpp_ext'
                VPP_INT_TAP='vpp_int'

            else

                print_prompt "This version is ($VPP_VERSION), and packet tracking for the $VPP_TYPE tenant gateway is enabled at 0.2.111..."
                
            fi

        fi

        if [[ ! $VPP_TYPE =~ "physical" ]];then
            get_vpp_host_if_info
        fi
    fi 
}


show_title(){
    local STR="$1"
    echo -e "\n\033[42;30m$STR:\033[0m\n$HR"
}

display_tcp_packet(){
    local IF_NAME=$1
    local CMD_STR=$2
    show_title $IF_NAME
    echo $CMD_STR
    echo "${HR//=/-}"
    cat ${IF_NAME}.dat  |  sed 's/options.*, //g' | grep -B1 -P '\[.*](?=,)' --color=auto
    echo "$HR"
}


display_icmp_packet(){
    local IF_NAME=$1
    local CMD_STR=$2
    show_title $IF_NAME
    echo $CMD_STR
    echo "${HR//=/-}"
    cat ${IF_NAME}.dat  | grep -B1 "request\|reply" --color=auto
    echo "$HR"
}

gen_topo_head(){
    if [[ "$IS_IPv6" -eq 0 ]]; then
        DST_DESC="ND_ADDR"
    else
        DST_DESC="FIP_ADDR"
    fi

    sleep 1
    echo
    echo "$HR"
    echo "Tenant Gateway Network topology and Packet tracking:"
    echo "${HR//=/-}"
    left_align_print "VPP_TYPE:  $VPP_TYPE" "$DST_DESC: $DST_IP"
    left_align_print "LOCAL_VM:  $VM_IP" "REMOTE_VM: $SRC_IP"
    echo "$HR"
}

gen_virtio_topo(){
cat > virtio_topo.dat <<EOF
      +-------------------+ 
      |    REMOTE_VM      |   
      |                   |   
      +---+----------+----+   
    +-----${L[0]}----------${L[1]}----------------------------------------+
    | +---+----------+----+ ${L[3]} +-----------------------+ |
    | | VPP_HOST_EXT_BOND |         |      VPP_EXT_TAP      | |
    | | $EXT_BOND         |         |    $VPP_OUT_TAP_IF    | |
    | +-------------------+ ${L[2]} +-----+-----------+-----+ |
    |                                     ${L[4]}           ${L[6]}       |
    |                               +-----+-----------+-----+ |
    |  VPP_KID   $PK                |          VPP          | |
    |  VPP_HOST  $VPP_HOST_ADDRS    |  MNG $VPP_VMMNG_ADDR  | |
    |                               |  INT $VPP_VTEP_ADDRS  | |
    |                               +-----+-----------+-----+ |
    |                                     ${L[5]}           ${L[7]}       |
    | +-------------------+ ${L[8]} +-----+-----------+-----+ |
    | | VPP_HOST_INT_BOND |         |      VPP_INT_TAP      | |
    | | $INT_BOND         |         |   $VPP_INT_TAP_IF     | |
    | +---+-----------+---+ ${L[9]} +-----------------------+ |
    +-----${L[10]}-----------${L[13]}---------------------------------------+
          ${L[11]}           ${L[14]}
    +-----${L[12]}-----------${L[15]}---------------------------------------+
    | +---+-----------+---+ ${L[18]} +-----------------------+ |
    | | VM_HOST_INT_BOND  |         |     OVS_VXLAN_SYS     | |
    | | $OVS_BOND         |         |    $OVS_VTEP_ADDRS    | |
    | +-------------------+ ${L[16]} +-----+-----------+-----+ |
    |                                     ${L[17]}           ${L[19]}       |
    |                               +-----+-----------+-----+ |
    |                               |      VM_INT_TAP       | |
    |                               |    $VM_TAP_IF_NAME    | |
    |                               +-----+-----------+-----+ |
    |                                     ${L[20]}           ${L[21]}       |
    |                               +-----+-----------+-----+ |
    |  VM_KID   $MK                 |       LOCAL_VM        | |
    |  VM_HOST  $VM_HOSTMNGADDR     |                       | |
    |                               +-----------------------+ |
    +---------------------------------------------------------+
 
$HR
EOF
}

gen_sriov_topo(){
cat > sriov_topo.dat <<EOF
      +---------------------+
      |    REMOTE_VM        |
      |                     |
      +----+-----------+----+
    +------${L[0]}----------${L[2]}--------------------------------------+
    | +----+-----------+----+ ${L[3]} +-----------------------+ |
    | |     VPP_EXT_TAP     |       |                       | |
    | |      vpp_ext        |       |                       | |
    | +---------------------+ ${L[1]} |                       | |
    |                               |                       | |
    |                               |                       | |
    |                               |       SRIOV_VPP       | |
    |                               |                       | |
    |  VPP_KID   $PK                |  MNG: $VPP_VMMNG_ADDR | |
    |  VPP_HOST  $VPP_HOST_ADDRS    |  INT: $VPP_VTEP_ADDRS | |
    |                               |                       | |
    | +---------------------+ ${L[4]} |                       | |
    | |     VPP_INT_TAP     |       |                       | |
    | |      vpp_int        |       |                       | |
    | +----+-----------+----+ ${L[5]} +-----------------------+ |
    +------${L[6]}-----------${L[9]}--------------------------------------+
           ${L[7]}           ${L[10]}
    +------${L[8]}-----------${L[11]}--------------------------------------+
    | +----+-----------+----+ ${L[13]} +-----------------------+ |
    | |   VM_HOST_INT_BOND  |       |     OVS_VXLAN_SYS     | |
    | |      $OVS_BOND      |       |    $OVS_VTEP_ADDRS    | |
    | +---------------------+ ${L[12]} +-----+-----------+-----+ |
    |                                     ${L[14]}           ${L[15]}       |
    |                               +-----+-----------+-----+ |
    |                               |      VM_INT_TAP       | |
    |                               |    $VM_TAP_IF_NAME    | |
    |                               +-----+-----------+-----+ |
    |                                     ${L[16]}           ${L[17]}       |
    |                               +-----+-----------+-----+ |
    |  VM_KID   $MK                 |        LOCAL_VM       | |
    |  VM_HOST  $VM_HOSTMNGADDR     |                       | |
    |                               +-----------------------+ |
    +---------------------------------------------------------+

$HR
EOF
}

gen_physical_topo(){
cat > physical_topo.dat <<EOF
      +---------------------+
      |    REMOTE_VM        |
      |                     |
      +----+-----------+----+
    +------${L[0]}-----------${L[2]}--------------------------------------+
    | +----+-----------+----+ ${L[3]} +-----------------------+ |
    | |     VPP_EXT_TAP     |       |                       | |
    | |      vpp_ext        |       |                       | |
    | +---------------------+ ${L[1]} |                       | |
    |                               |                       | |
    |                               |                       | |
    |                               |     PHYSICAL_VPP      | |
    |                               |                       | |
    |                               |  INT: $VPP_VTEP_ADDRS | |
    |  VPP_MNG   $VPP_VMMNG_ADDR    |                       | |
    |                               |                       | |
    | +---------------------+ ${L[4]} |                       | |
    | |     VPP_INT_TAP     |       |                       | |
    | |      vpp_int        |       |                       | |
    | +----+-----------+----+ ${L[5]} +-----------------------+ |
    +------${L[6]}-----------${L[9]}--------------------------------------+
           ${L[7]}           ${L[10]}
    +------${L[8]}-----------${L[11]}--------------------------------------+
    | +----+-----------+----+ ${L[13]} +-----------------------+ |
    | |   VM_HOST_INT_BOND  |       |     OVS_VXLAN_SYS     | |
    | |      $OVS_BOND      |       |    $OVS_VTEP_ADDRS    | |
    | +---------------------+ ${L[12]} +-----+-----------+-----+ |
    |                                     ${L[14]}           ${L[15]}       |
    |                               +-----+-----------+-----+ |
    |                               |      VM_INT_TAP       | |
    |                               |    $VM_TAP_IF_NAME    | |
    |                               +-----+-----------+-----+ |
    |                                     ${L[16]}           ${L[17]}       |
    |                               +-----+-----------+-----+ |
    |  VM_KID   $MK                 |        LOCAL_VM       | |
    |  VM_HOST  $VM_HOSTMNGADDR     |                       | |
    |                               +-----------------------+ |
    +---------------------------------------------------------+

$HR
EOF
}


draw_packet_topo(){
    format_len(){
        local ADDR=$1
        local NUM=$2
        local LEN=$[$2-${#ADDR}]
        echo "$ADDR$(tr -cd ' ' < /dev/urandom | head -c $LEN )"
    }

    VPP_VMMNG_ADDR=$(format_len ${VPP_IP:-xxx.xxx.xxx.xxx} 15)
    VPP_HOST_ADDRS=$(format_len ${VPP_HOST_IP:-xxx.xxx.xxx.xxx} 15)
    VM_HOSTMNGADDR=$(format_len ${VM_HOST_IP:-xxx.xxx.xxx.xxx} 15)
    VPP_VTEP_ADDRS=$(format_len ${VPP_VTEP:-xxx.xxx.xxx.xxx} 15)
    OVS_VTEP_ADDRS=$(format_len ${OVS_VTEP:-xxx.xxx.xxx.xxx} 15)

    EXT_BOND=$(format_len ${VPP_HOST_EXT_BOND:-bondx.xxx} 9)
    INT_BOND=$(format_len ${VPP_HOST_INT_BOND:-bondx.xxx} 9)
    OVS_BOND=$(format_len ${VM_HOST_INT_BOND:-bondx.xxx} 9)

    VPP_INT_TAP_IF=$(format_len ${VPP_INT_TAP:-tapxxxxxxxx-xx} 15)
    VPP_OUT_TAP_IF=$(format_len ${VPP_EXT_TAP:-tapxxxxxxxx-xx} 15)
    VM_TAP_IF_NAME=$(format_len ${VM_TAP_IF:-tapxxxxxxxx-xx} 15)

    PK=$(format_len ${VPP_KID:-xxx} 3)
    MK=$(format_len ${VM_KID:-xxx} 3)

    if [[ $VPP_TYPE =~ "physical" ]]; then
        gen_physical_topo
        TOPO_FILE="physical_topo.dat"
    elif [[ $VPP_TYPE =~ "sriov" ]]; then
        gen_sriov_topo
        TOPO_FILE="sriov_topo.dat"
    else
        gen_virtio_topo
        TOPO_FILE="virtio_topo.dat"
    fi

    gen_topo_head
    OLD_IFS=$IFS
    IFS=''
    while read -r line;do
        printf "$line\n"
    done < $TOPO_FILE
    IFS=$OLD_IFS 
}

enable_interface_span(){
    fast_ssh $EXT_ARGS $VPP_IP vppctl show interface span | grep -q tapcli-0
    if [[ $? -ne 0 ]]; then
        fast_ssh $EXT_ARGS $VPP_IP vppctl set interface span $VPP_SERVICE_IF destination tapcli-0 both
    fi
    fast_ssh $EXT_ARGS $VPP_IP vppctl show interface span | grep -q tapcli-1
    if [[ $? -ne 0 ]]; then
        fast_ssh $EXT_ARGS $VPP_IP vppctl set interface span $VPP_EXTERNAL_IF destination tapcli-1 both
    fi
}

disable_interfaces_span(){
    sed -i "/$PROC_PID $DST_IP /d" /tmp/vpp_gen_tap.dat
    grep -q "$DST_IP" /tmp/vpp_gen_tap.dat
    IS_CAP_PKG=$?
    fast_ssh $EXT_ARGS $VPP_IP vppctl show interface span | grep -q tapcli-0
    if [[ $? -eq 0 ]] && [[ $IS_CAP_PKG -eq 1 ]]; then
        fast_ssh $EXT_ARGS $VPP_IP vppctl set interface span $VPP_SERVICE_IF disable
    fi
    fast_ssh $EXT_ARGS $VPP_IP vppctl show interface span | grep -q tapcli-1
    if [[ $? -eq 0 ]] && [[ $IS_CAP_PKG -eq 1 ]]; then
        fast_ssh $EXT_ARGS $VPP_IP vppctl set interface span $VPP_EXTERNAL_IF disable
    fi
}

render_line(){
    local INDEX=$1
    local TYPE=$2
    if [[ $VPP_TYPE =~ "physical" ]] || [[ $VPP_TYPE =~ "sriov" ]]; then
        R=('|' '>--->' '|'  '<---<'  '<---<' '>--->' '|' '|' '|' '|' '|' '|' '>--->' '<---<' '|' '|' '|' '|')
    else
        R=("|" "|" ">-->-->" "<--<--<" "|" "|" "|" "|" "<--<--<" ">-->-->"   "|" "|" "|" "|" "|" "|" ">-->-->" "|" "<--<--<"  "|"  "|" "|" )
    fi
    case "$TYPE" in
        WHITE ) # white
            STYLE="\033[40m"
            ;;
        RED ) # red
            STYLE="\033[31;1m"
            ;;
        GREEN ) # green sparkle
            STYLE="\033[32;1;5m"
            ;;
    esac
    L[$INDEX]="${STYLE}${R[$INDEX]}\033[0m"
}

batch_render(){
    local LINE_STR=$1
    local COLOR=$2
    for I in $(echo "$LINE_STR" | tr ',' '\n'); do
        render_line "$I" "$COLOR"
    done
}

coloring_line(){
    FILE=$1
    TYPE=$2
    REQ_L=$3
    RESP_L=$4


    if [[ $TYPE == "icmp" ]]; then
       REQ="request"
       RESP="reply"
    else
        REQ='\[S\]'
        RESP='\[[^R]*\.\]'
    fi

    grep -q "$REQ" $FILE
    if [[ $? -eq 0 ]]; then
        batch_render $REQ_L "GREEN"
    else
        batch_render $REQ_L "RED"
    fi

    grep -q "$RESP" $FILE
    if [[ $? -eq 0 ]]; then
        batch_render $RESP_L "GREEN"
    else
        batch_render $RESP_L "RED"
    fi
}


proc_phy_sriov_packet(){

    enable_interface_span

    L=('|' '>--->' '|' '<---<'  '<---<' '>--->' '|' '|' '|' '|' '|' '|' '>--->' '<---<' '|' '|' '|' '|' )
    

    if [[ "$PORT" ]]; then

        if [[ $VPP_TYPE =~ "physical" ]]; then
            fast_ssh "$VPP_IP" tcpdump --version &>/dev/null || fast_ssh "$VPP_IP" yum install -y tcpdump
            TCPDUMP_CMD_STR=$INNER_PORT_STR
        elif [[ $VPP_TYPE =~ "sriov" ]]; then
            TCPDUMP_CMD_STR="\"$INNER_PORT_STR\""
        fi

        fast_ssh $EXT_ARGS $VPP_IP tcpdump -i "$VPP_EXT_TAP" -nnl host $DST_IP and host $SRC_IP and port $PORT -c $PKT_NUM > VPP_EXT_TAP.dat 2>/dev/null &
        fast_ssh $EXT_ARGS $VPP_IP tcpdump -i $VPP_INT_TAP -nnl host $OVS_VTEP and udp and "$TCPDUMP_CMD_STR" -c $PKT_NUM  > VPP_INT_TAP.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i $VM_HOST_INT_BOND -nnl host $VPP_VTEP and udp and "$INNER_PORT_STR" -c $PKT_NUM >  VM_HOST_INT_BOND.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i vxlan_sys_4789 -nnl host $SRC_IP and port $PORT -c $PKT_NUM > OVS_VXLAN_SYS.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i "$VM_TAP_IF" -nnl host $SRC_IP and port $PORT -c $PKT_NUM > VM_INT_TAP.dat 2>/dev/null &        

        
        show_title "VPP_EXT_TAP"
        echo -e "tcpdump -i $VPP_EXT_TAP -nnl host $DST_IP and host $SRC_IP and port $PORT -c $PKT_NUM"
        echo "${HR//=/-}"
        fast_ssh $EXT_ARGS $VPP_IP tcpdump -i "$VPP_EXT_TAP" -nnl host $DST_IP and host $SRC_IP and port $PORT -c $PKT_NUM 2>/dev/null |  sed 's/options.*, //g' | grep -B1 -P '\[.*](?=,)' --color=auto
        echo "$HR"

        coloring_line VPP_EXT_TAP.dat tcp "0,1" "2,3,5"
        coloring_line VPP_INT_TAP.dat tcp "4" "9,10,11"
        coloring_line VM_HOST_INT_BOND.dat tcp "6,7,8" "13"
        coloring_line OVS_VXLAN_SYS.dat tcp "12" "15"
        coloring_line VM_INT_TAP.dat tcp "14,16" "17"


        display_tcp_packet "VPP_INT_TAP" "tcpdump -i $VPP_INT_TAP -nnl host $OVS_VTEP and udp | grep -B1 $SRC_IP"
        display_tcp_packet "VM_HOST_INT_BOND" "tcpdump -i $VM_HOST_INT_BOND -nnl host $VPP_VTEP and udp | grep -B1 $SRC_IP"
        display_tcp_packet "OVS_VXLAN_SYS" "tcpdump -i vxlan_sys_4789 -nnl host $SRC_IP and port $PORT -c $PKT_NUM"
        display_tcp_packet "VM_INT_TAP" "tcpdump -i $VM_TAP_IF -nnl host $SRC_IP and port $PORT -c $PKT_NUM"

        draw_packet_topo
    else

        if [[ $VPP_TYPE =~ "physical" ]]; then
            fast_ssh "$VPP_IP" tcpdump --version &>/dev/null || fast_ssh "$VPP_IP" yum install -y tcpdump
            TCPDUMP_CMD_STR=$INNER_ICMP_STR
        elif [[ $VPP_TYPE =~ "sriov" ]]; then
            TCPDUMP_CMD_STR="\"$INNER_ICMP_STR\""
        fi

        fast_ssh $EXT_ARGS $VPP_IP tcpdump -i "$VPP_EXT_TAP" -nnl host $DST_IP and host $SRC_IP $PROTOCOL_STR -c $PKT_NUM > VPP_EXT_TAP.dat 2>/dev/null &
        fast_ssh $EXT_ARGS $VPP_IP tcpdump -i $VPP_INT_TAP -nnl host $OVS_VTEP and udp and "$TCPDUMP_CMD_STR" -c $PKT_NUM  > VPP_INT_TAP.dat 2>/dev/null &
        fast_ssh $VM_HOST_IP tcpdump -i $VM_HOST_INT_BOND -nnl host $VPP_VTEP and udp and  "$INNER_ICMP_STR" -c $PKT_NUM >  VM_HOST_INT_BOND.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i vxlan_sys_4789 -nnl host $SRC_IP $PROTOCOL_STR -c $PKT_NUM > OVS_VXLAN_SYS.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i "$VM_TAP_IF" -nnl host $SRC_IP $PROTOCOL_STR -c $PKT_NUM > VM_INT_TAP.dat 2>/dev/null &

        show_title "VPP_EXT_TAP"
        echo -e "tcpdump -i $VPP_EXT_TAP -nnl host $DST_IP and host $SRC_IP $PROTOCOL_STR -c $PKT_NUM"
        echo "${HR//=/-}"
        fast_ssh $EXT_ARGS $VPP_IP tcpdump -i "$VPP_EXT_TAP" -nnl host $DST_IP and host $SRC_IP $PROTOCOL_STR -c $PKT_NUM 2>/dev/null | grep -B1 "request\|reply" --color=auto
        echo "$HR"

        coloring_line VPP_EXT_TAP.dat icmp "0,1" "2,3,5"
        coloring_line VPP_INT_TAP.dat icmp "4" "9,10,11"
        coloring_line VM_HOST_INT_BOND.dat icmp "6,7,8" "13"
        coloring_line OVS_VXLAN_SYS.dat icmp "12" "15"
        coloring_line VM_INT_TAP.dat icmp "14,16" "17"

        display_icmp_packet "VPP_INT_TAP" "tcpdump -i $VPP_INT_TAP -nnl host $OVS_VTEP and udp | grep -B1 $SRC_IP"
        display_icmp_packet "VM_HOST_INT_BOND" "tcpdump -i $VM_HOST_INT_BOND -nnl host $VPP_VTEP and udp | grep -B1 $SRC_IP"
        display_icmp_packet "OVS_VXLAN_SYS" "tcpdump -i vxlan_sys_4789 -nnl host $SRC_IP -c $PKT_NUM"
        display_icmp_packet "VM_INT_TAP" "tcpdump -i $VM_TAP_IF -nnl host $SRC_IP -c $PKT_NUM"

        draw_packet_topo
    fi

    disable_interfaces_span
}

proc_virtio_packet(){


    L=("|" "|" ">-->-->" "<--<--<" "|" "|" "|" "|" "<--<--<" ">-->-->"   "|" "|" "|" "|" "|" "|" ">-->-->" "|" "<--<--<"  "|"  "|" "|" )


    if [[ "$PORT" ]]; then

        fast_ssh "$VPP_HOST_IP" tcpdump -i "$VPP_HOST_EXT_BOND" -nnl host $DST_IP and host $SRC_IP and port $PORT -c $PKT_NUM > VPP_HOST_EXT_BOND.dat 2>/dev/null &
        fast_ssh "$VPP_HOST_IP" tcpdump -i "$VPP_EXT_TAP" -nnl host $DST_IP and host $SRC_IP and port $PORT -c $PKT_NUM > VPP_EXT_TAP.dat 2>/dev/null &
        fast_ssh "$VPP_HOST_IP" tcpdump -i "$VPP_INT_TAP" -nnl host $OVS_VTEP and udp and "$INNER_PORT_STR" -c $PKT_NUM  > VPP_INT_TAP.dat 2>/dev/null &
        fast_ssh "$VPP_HOST_IP" tcpdump -i "$VPP_HOST_INT_BOND" -nnl host $OVS_VTEP and udp and "$INNER_PORT_STR" -c $PKT_NUM >  VPP_HOST_INT_BOND.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i "$VM_HOST_INT_BOND" -nnl host $VPP_VTEP and udp and "$INNER_PORT_STR" -c $PKT_NUM >  VM_HOST_INT_BOND.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i vxlan_sys_4789 -nnl host $SRC_IP and port $PORT -c $PKT_NUM > OVS_VXLAN_SYS.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i "$VM_TAP_IF" -nnl host $SRC_IP and port $PORT -c $PKT_NUM > VM_INT_TAP.dat 2>/dev/null &

        show_title "VPP_HOST_EXT_BOND"
        echo -e "tcpdump -i $VPP_HOST_EXT_BOND -nnl host $DST_IP and host $SRC_IP and port $PORT -c $PKT_NUM"
        echo "${HR//=/-}"
        fast_ssh $VPP_HOST_IP tcpdump -i "$VPP_HOST_EXT_BOND" -nnl host $DST_IP and host $SRC_IP and port $PORT -c $PKT_NUM 2>/dev/null |  sed 's/options.*, //g' | grep -B1 -P '\[.*](?=,)' --color=auto
        echo "$HR"

        coloring_line VPP_HOST_EXT_BOND.dat tcp "0" "1,3"
        coloring_line VPP_EXT_TAP.dat tcp "2,4" "6,7"
        coloring_line VPP_INT_TAP.dat tcp "5" "9"
        coloring_line VPP_HOST_INT_BOND.dat tcp "8" "13,14,15"
        coloring_line VM_HOST_INT_BOND.dat tcp "10,11,12" "18"
        coloring_line OVS_VXLAN_SYS.dat tcp "16" "19"
        coloring_line VM_INT_TAP.dat tcp "17,20" "21"

        display_tcp_packet "VPP_EXT_TAP" "tcpdump -i $VPP_EXT_TAP -nnl host $DST_IP and host $SRC_IP and port $PORT -c $PKT_NUM"
        display_tcp_packet "VPP_INT_TAP" "tcpdump -i $VPP_INT_TAP -nnl host $OVS_VTEP and udp | grep -B1 $SRC_IP"
        display_tcp_packet "VPP_HOST_INT_BOND" "tcpdump -i $VPP_HOST_INT_BOND -nnl host $OVS_VTEP and udp | grep -B1 $SRC_IP"
        display_tcp_packet "VM_HOST_INT_BOND" "tcpdump -i $VM_HOST_INT_BOND -nnl host $VPP_VTEP and udp | grep -B1 $SRC_IP"
        display_tcp_packet "OVS_VXLAN_SYS" "tcpdump -i vxlan_sys_4789 -nnl host $SRC_IP and port $PORT -c $PKT_NUM"
        display_tcp_packet "VM_INT_TAP" "tcpdump -i $VM_TAP_IF -nnl host $SRC_IP and port $PORT -c $PKT_NUM"

        draw_packet_topo
    else
        fast_ssh "$VPP_HOST_IP" tcpdump -i "$VPP_HOST_EXT_BOND" -nnl host $DST_IP and host $SRC_IP $PROTOCOL_STR -c $PKT_NUM > VPP_HOST_EXT_BOND.dat 2>/dev/null &
        fast_ssh "$VPP_HOST_IP" tcpdump -i "$VPP_EXT_TAP" -nnl host $DST_IP and host $SRC_IP $PROTOCOL_STR -c $PKT_NUM > VPP_EXT_TAP.dat 2>/dev/null &
        fast_ssh "$VPP_HOST_IP" tcpdump -i "$VPP_INT_TAP" -nnl host $OVS_VTEP and udp and "$INNER_ICMP_STR" -c $PKT_NUM  > VPP_INT_TAP.dat 2>/dev/null &
        fast_ssh "$VPP_HOST_IP" tcpdump -i "$VPP_HOST_INT_BOND" -nnl host $OVS_VTEP and udp and "$INNER_ICMP_STR" -c $PKT_NUM >  VPP_HOST_INT_BOND.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i "$VM_HOST_INT_BOND" -nnl host $VPP_VTEP and udp and "$INNER_ICMP_STR"  -c $PKT_NUM >  VM_HOST_INT_BOND.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i vxlan_sys_4789 -nnl host $SRC_IP $PROTOCOL_STR -c $PKT_NUM > OVS_VXLAN_SYS.dat 2>/dev/null &
        fast_ssh "$VM_HOST_IP" tcpdump -i "$VM_TAP_IF" -nnl host $SRC_IP $PROTOCOL_STR -c $PKT_NUM > VM_INT_TAP.dat 2>/dev/null &


        show_title "VPP_HOST_EXT_BOND"
        echo -e "tcpdump -i $VPP_HOST_EXT_BOND -nnl host $DST_IP and host $SRC_IP $PROTOCOL_STR -c $PKT_NUM"
        echo "${HR//=/-}"
        fast_ssh $VPP_HOST_IP tcpdump -i "$VPP_HOST_EXT_BOND" -nnl host $DST_IP and host $SRC_IP $PROTOCOL_STR -c $PKT_NUM 2>/dev/null | grep -B1 "request\|reply" --color=auto
        echo "$HR"

        coloring_line VPP_HOST_EXT_BOND.dat icmp "0" "1,3"
        coloring_line VPP_EXT_TAP.dat icmp "2,4" "6,7"
        coloring_line VPP_INT_TAP.dat icmp "5" "9"
        coloring_line VPP_HOST_INT_BOND.dat icmp "8" "13,14,15"
        coloring_line VM_HOST_INT_BOND.dat icmp "10,11,12" "18"
        coloring_line OVS_VXLAN_SYS.dat icmp "16" "19"
        coloring_line VM_INT_TAP.dat icmp "17,20" "21"

        display_icmp_packet "VPP_EXT_TAP" "tcpdump -i $VPP_EXT_TAP -nnl host $DST_IP and host $SRC_IP $PROTOCOL_STR -c $PKT_NUM"
        display_icmp_packet "VPP_INT_TAP" "tcpdump -i $VPP_INT_TAP -nnl host $OVS_VTEP and udp | grep -B1 $SRC_IP"
        display_icmp_packet "VPP_HOST_INT_BOND" "tcpdump -i $VPP_HOST_INT_BOND -nnl host $OVS_VTEP and udp | grep -B1 $SRC_IP"
        display_icmp_packet "VM_HOST_INT_BOND" "tcpdump -i $VM_HOST_INT_BOND -nnl host $VPP_VTEP and udp | grep -B1 $SRC_IP"
        display_icmp_packet "OVS_VXLAN_SYS" "tcpdump -i vxlan_sys_4789 -nnl host $SRC_IP -c $PKT_NUM"
        display_icmp_packet "VM_INT_TAP" "tcpdump -i $VM_TAP_IF -nnl host $SRC_IP $PROTOCOL_STR -c $PKT_NUM"
        
        draw_packet_topo
    fi

}


capture_packet_or_exec(){
    FILTER="$1"
    PORT="$2"

    check_db_table

    ipcalc -4c $FILTER 2>/dev/null
    if [[ $? -eq 0 ]]; then
        IS_IPv6=1
        psql -h $ODL_DB -U postgres -d postgres -c "$SQL_STR_ALL" > vpp_all_temp.dat
        grep \| vpp_all_temp.dat | grep -v "vm_host_ip" > vpp_all.dat

        SEARCH_NUM=$(grep -c "$FILTER\ " vpp_all.dat)
        if [[ "$SEARCH_NUM" -eq 0 ]]; then
            print_prompt "No results found or not unique."
        elif [[ "$SEARCH_NUM" -gt 2 ]]; then
            TB_HR=$(head -2 vpp_all_temp.dat | tail -1)
            echo ${TB_HR//+/-}
            head -2 vpp_all_temp.dat
            grep "$FILTER\ " vpp_all.dat
            echo 
            print_prompt "No results found or not unique."
        else
            args_init ipv4 true

            echo "$HR"
            if [[ $PORT ]]; then
                echo -e "Please the local execute the \033[42;30mtcping -t $DST_IP $PORT\033[0m trigger request..."
            else
                if [[ $NS_ENABLE_PING -ne 0 ]]; then
                    print_prompt "The virtual machine( $SRC_IP ) is not open global ICMP access functions..." 2
                fi
                echo -e "Please the local execute the \033[42;30mping -t $DST_IP\033[0m trigger request..."
            fi
            echo "$HR"

            if [[ $VPP_TYPE =~ "physical" ]] || [[ $VPP_TYPE =~ "sriov" ]]; then
                proc_phy_sriov_packet
            else
                proc_virtio_packet
            fi
        fi
    fi
    
    ipcalc -6c $FILTER 2>/dev/null
    if [[ $? -eq 0 ]]; then
        IS_IPv6=0
        psql -h $ODL_DB -U postgres -d postgres -c "$SQL_IP6_STR_ALL" > vpp_ip6_all_temp.dat
        grep \| vpp_ip6_all_temp.dat | grep -v "host_ip" > vpp_ip6_all.dat
        SEARCH_NUM=$(grep -c "$FILTER\ " vpp_ip6_all.dat)
        if [[ "$SEARCH_NUM" -eq 0 ]]; then
            print_prompt "No results found or not unique."
        elif [[ "$SEARCH_NUM" -gt 2 ]]; then
            TB_HR=$(head -2 vpp_ip6_all_temp.dat | tail -1)
            echo ${TB_HR//+/-}
            head -2 vpp_ip6_all_temp.dat
            grep "$FILTER\ " vpp_ip6_all.dat
            echo 
            print_prompt "No results found or not unique."
        else
            args_init ipv6 true

            echo "$HR"
            if [[ $PORT ]]; then
                echo -e "Please Login \033[42;30m$IP6_CLIENT (root/$IP6_PASSWD)\033[0m to execute the \033[42;30mtelnet $DST_IP $PORT\033[0m trigger request..."
            else
                if [[ $NS_ENABLE_PING -ne 0 ]]; then
                    print_prompt "The virtual machine( $SRC_IP ) is not open global ICMP access functions..." 2
                fi
                echo -e "Please Login \033[42;30m$IP6_CLIENT (root/$IP6_PASSWD)\033[0m to execute the \033[42;30mping6 $DST_IP\033[0m trigger request..."
            fi
            echo "$HR"

            if [[ $VPP_TYPE =~ "physical" ]] || [[ $VPP_TYPE =~ "sriov" ]]; then
                proc_phy_sriov_packet
            else
                proc_virtio_packet
            fi

        fi
    fi
}

show_cmd_rs(){
    CMD_STR="$1"
    fast_ssh $EXT_ARGS "$VPP_IP" "$CMD_STR" 
    if [[ $? -eq 0 ]]; then

        echo "$CMD_STR & [ OK ]" | awk -F"&" '{printf "%-104s\033[42;30m%0s \033[0m\n",$1,$2}'

    else
        if [[ ! "$CMD_STR" =~ "ping" ]]; then
            IS_CHECK_PACKET=1
        fi

        echo "$CMD_STR & [ FAIL ]" | awk -F"&" '{printf "%-102s\033[41m%0s \033[0m\n",$1,$2}'

    fi
    echo "$HR" 
}

remote_batch_exec(){
    local TYPE="$ARG_TYPE" 
   
    echo "$HR"
    echo "1). Memory leak (vppctl show dpdk buffer)"
    echo "2). Cluster abnormal (vppctl show vrrp | grep 'Count')"
    echo "3). Cluster abnormal run on backup (vppctl show int \$<VPP_EXTERNAL_IF> | grep \$VPP_EXTERNAL_IF)"
    echo "4). Custom command (Self input command..)"
    echo "${HR//=/-}"
    echo -n "Select a common command number or a custom command"
    read -p ": " CMD_NO

    if [[ -z "$TYPE" ]]; then
        VPP_ROLE="All"
        M_TYPE="All"
    else
        if [[ $TYPE == "master" ]]; then
            M_TYPE="Master"
        elif [[ $TYPE == "backup" ]]; then
            M_TYPE="Backup"
        else
            print_prompt "Illegal cluster type[ master | backup ]..."
        fi
    fi

    case $CMD_NO in
        1 )
            CMD_STR="vppctl sh dpdk buffer" 
            ;;
        2 )
            CMD_STR="vppctl show vrrp | grep 'Count'" 
            ;;
        3 )
            ;;
        4 )
            read -p "Please enter the command to be executed in batches: " CMD_STR
            if [[ -z $CMD_STR ]]; then
                print_prompt "Please enter the correct custom command..."
            fi

            echo >&2 -ne "Are you sure you want to execute ( \033[41m$CMD_STR\033[0m ) "
            read -p "on $M_TYPE machine [yes/no]? " JUDGE
            if [[ $JUDGE != "yes" ]]; then
                exit 0
            fi
            ;;
        * )
            print_prompt "Illegal number..."
            ;;
    esac

    VPP_LIST=($(psql -h $ODL_DB -U postgres -d postgres -t -c "select id from vpp where is_deleted is null;" | xargs ))
    TOTAL_NUM=${#VPP_LIST[*]}
    
    j=0
    for (( i = 0; i < $TOTAL_NUM; i++ )); do
        IS_PHY=1
        nc -w 0.2 -z ${VPP_LIST[$i]} $SERVER_SSH_PORT
        if [[ $? -eq 0 ]]; then
            EXT_ARGS=""
            IS_PHY=0
        else
            EXT_ARGS="$ODL_CTRL sshpass -pfd10_VNF ssh -o StrictHostKeyChecking=no"
        fi

        if [[ "$TYPE" ]]; then
            VPP_ROLE=$(fast_ssh $EXT_ARGS ${VPP_LIST[$i]} vppctl sh vrrp 2>/dev/null |  grep "State Machine" | awk '{print $NF}' | sed 's/\r//g')
        fi

        if [[ $CMD_NO -eq 3 ]]; then
            VPP_EXTERNAL_IF=$(run_odl_sql "select interfaces::json->'external'->>'name' as external from vpp where is_deleted is null and manage_ip='@@@';" "${VPP_LIST[$i]}")
            if [[ -z "$VPP_EXTERNAL_IF" ]]; then
                continue
            fi
            CMD_STR="vppctl sh int $VPP_EXTERNAL_IF | grep $VPP_EXTERNAL_IF"
        fi
        
        if [[ "$VPP_ROLE" == "$M_TYPE" ]]; then
            echo >&2 $HR
            if [[ $IS_PHY -eq 0 ]]; then
                EXT_ARGS=""
                echo -e >&2 "($((j+1))) \033[41mPhysical\033[0m VPP: ${VPP_LIST[$i]} $CMD_STR"
                echo >&2 ${HR//=/-}
                ping -w 1 -c 1 ${VPP_LIST[$i]} &> /dev/null
            else
                EXT_ARGS="$ODL_CTRL sshpass -pfd10_VNF ssh -o StrictHostKeyChecking=no"
                echo >&2 "($((j+1))) VPP: ${VPP_LIST[$i]} $CMD_STR"
                echo >&2 ${HR//=/-}
                fast_ssh $ODL_CTRL ping -w 1 -c 1 ${VPP_LIST[$i]} &> /dev/null
            fi
            if [[ $? -eq 0 ]]; then
                fast_ssh $EXT_ARGS ${VPP_LIST[$i]} "$CMD_STR" 2>/dev/null
            else
                echo >&2 "\033[41mThe address is not reachable..\033[0m"
                echo >&2
            fi
            j=$[j+1]
            echo >&2
        fi
    done 
}

remote_login(){
    FILTER="$1"

    check_db_table

    IS_IPv6=1
    ipcalc -4c $FILTER 2>/dev/null
    if [[ $? -eq 0 ]]; then
        psql -h $ODL_DB -U postgres -d postgres -c "$SQL_STR_ALL" > vpp_all_temp.dat
        grep \| vpp_all_temp.dat | grep -v "vm_host_ip" > vpp_all.dat
        SEARCH_NUM=$(grep -c "$FILTER\ " vpp_all.dat)
    else
        ipcalc -6c $FILTER 2>/dev/null
        if [[ $? -eq 0 ]]; then
            IS_IPv6=0
            psql -h $ODL_DB -U postgres -d postgres -c "$SQL_IP6_STR_ALL" > vpp_ip6_all_temp.dat
            grep \| vpp_ip6_all_temp.dat | grep -v "host_ip" > vpp_ip6_all.dat
            SEARCH_NUM=$(grep -c "$FILTER\ " vpp_ip6_all.dat)
        else
            VM_DEVICE_ID=$FILTER
            VM_HOST_IP=$(run_odl_sql "select host_ip from port where device<>'' and host_ip  is not  null and device_owner<>'network:dhcp' and device='@@@';" "$FILTER")
            if [[ $VM_HOST_IP ]]; then
                if [[ $ARG_VAL == 'vm'  ]]; then
                    if nc -w 0.2 -z $VM_HOST_IP $SERVER_SSH_PORT &>/dev/null;then
                        fast_login "$VM_HOST_IP" virsh console $VM_DEVICE_ID --force
                    else
                        print_prompt "The host address($VM_HOST_IP) of the virtual machine is not available..."
                    fi 
                elif [[ $ARG_VAL == 'vm_vnc' ]]; then
                    get_vm_vnc_url $VM_DEVICE_ID
                else
                    print_prompt "The type of illegal, support for vm and vm_vnc only..."
                fi
                exit 1
            else
                print_prompt "No results found or not unique."
            fi
            
        fi
    fi
    
    if [[ "$SEARCH_NUM" -eq 0 ]]; then
        print_prompt "No results found or not unique."
    elif [[ "$SEARCH_NUM" -gt 2 ]]; then
        if [[ $IS_IPv6 -eq 0 ]]; then
            TB_HR=$(head -2 vpp_ip6_all_temp.dat | tail -1)
            echo ${TB_HR//+/-}
            head -2 vpp_ip6_all_temp.dat
            grep "$FILTER\ " vpp_ip6_all.dat
        else
            TB_HR=$(head -2 vpp_all_temp.dat | tail -1)
            echo ${TB_HR//+/-}
            head -2 vpp_all_temp.dat
            grep "$FILTER\ " vpp_all.dat
        fi
        echo 
        print_prompt "No results found or not unique."
    else
        if [[ $IS_IPv6 -eq 0 ]]; then
            args_init ipv6 
        else
            args_init ipv4
        fi

        if [[ "$ARG_VAL"X == "vm"X ]]; then

            if nc -w 0.2 -z $VM_HOST_IP $SERVER_SSH_PORT &>/dev/null;then
                fast_login "$VM_HOST_IP" virsh console $VM_DEVICE_ID --force
            else
                print_prompt "The host address($VM_HOST_IP) of the virtual machine is not available..."
            fi

        elif [[ "$ARG_VAL"X == "vm_vnc"X ]]; then

            get_vm_vnc_url $VM_DEVICE_ID
        
        elif [[ "$ARG_VAL"X == "vpp"X ]]; then

            echo "$VPP_LOGIN_PROMPT"
            fast_login $EXT_ARGS $VPP_IP

        elif [[ "$ARG_VAL"X == "vm_host"X ]]; then

            login_vm_host

        elif [[ "$ARG_VAL"X == "vpp_host"X ]]; then

           login_vpp_host
        
        else
            usage
            print_prompt "The wrong type, please see the help information."
        fi
    fi
}

compare_version(){
    #BY_PASS_VER="3.4.3"
    local F=$(echo $ODL_VERSION | awk -F. '{print $1}' | xargs)
    local S=$(echo $ODL_VERSION | awk -F. '{print $2}' | xargs)
    local C=$(echo $ODL_VERSION | awk -F. '{print $3}' | xargs)
    IS_BYPASS=1
    if [[ $F -gt 3 ]]; then
        IS_BYPASS=0
    else
        if [[ $S -gt 4 ]]; then
            IS_BYPASS=0
        else
            if [[ $S -ge 3 ]]; then
                IS_BYPASS=0
            fi
        fi
    fi
}


get_about_vxlan_dst_vtep(){
    FIP_ADDR="$1"
    FIP_LOCAL_VM_PORT_ID=$(run_odl_sql "select port_id from floatingip where floating_ip='@@@' and is_deleted is null;" "$FIP_ADDR")
    LOCAL_VM_TYPE=$(run_odl_sql "select binding_vnic_type from port where is_deleted is null and id='@@@';" "$FIP_LOCAL_VM_PORT_ID")
    if [[ "$LOCAL_VM_TYPE" == "normal" ]]; then
        LOCAL_VM_HOST=$(run_odl_sql "select host_ip from port where is_deleted is null and id='@@@';" "$FIP_LOCAL_VM_PORT_ID")
        DST_VTEP=$(run_odl_sql "select local_ip from host where is_deleted is null and host_ip='@@@';" "$LOCAL_VM_HOST")
    elif [[ "$LOCAL_VM_TYPE" == "baremetal" ]]; then
        compare_version
        if [[ $VPP_TYPE =~ "physical" ]] && [[ "$IS_BYPASS" -eq 0 ]]; then
            DST_VTEP=""
        else
            DST_VTEP=$(run_odl_sql "select cluster_ip from vpp where gate_way_type ='@@@' and is_deleted is null and is_available='t' limit 1;" "vxlanGw")
        fi
    fi
}

get_about_ip6_vxlan_dst_vtep(){
    ND_ADDR="$1"
    FIP_LOCAL_VM_PORT_ID=$(run_odl_sql "select port_id from ipv6ndproxy where ip_address='@@@' and is_deleted is null;" "$ND_ADDR")
    LOCAL_VM_TYPE=$(run_odl_sql "select binding_vnic_type from port where is_deleted is null and id='@@@';" "$FIP_LOCAL_VM_PORT_ID")
    if [[ "$LOCAL_VM_TYPE" == "normal" ]]; then
        LOCAL_VM_HOST=$(run_odl_sql "select host_ip from port where is_deleted is null and id='@@@';" "$FIP_LOCAL_VM_PORT_ID")
        DST_VTEP=$(run_odl_sql "select local_ip from host where is_deleted is null and host_ip='@@@';" "$LOCAL_VM_HOST")
    elif [[ "$LOCAL_VM_TYPE" == "baremetal" ]]; then
        compare_version
        if [[ $VPP_TYPE =~ "physical" ]] && [[ "$IS_BYPASS" -eq 0 ]]; then
            DST_VTEP=""
        else
            DST_VTEP=$(run_odl_sql "select cluster_ip from vpp where gate_way_type ='@@@' and is_deleted is null and is_available='t' limit 1;" "vxlanGw")
        fi
    fi
}

remote_exec_cmd(){
    IS_CHECK_PACKET=0
    FILTER="$1"
    if [[ -z "$FILTER" ]]; then
        usage
        exit 1
    fi
    shift 1
    check_db_table
    echo $FILTER | grep -qP '^[0-9a-f]{8}(-[0-9a-f]{4}){4}[0-9a-f]{8}$'
    if  [[ $? -eq 0 ]]; then
        TABLE_NUM=$(run_odl_sql "select count(*) from pg_class where relname = '@@@';" "clouddcpeer" )
        if [[ $TABLE_NUM -ge 1 ]]; then
           
            psql -h $ODL_DB -U postgres -d postgres -c "$SQL_DCI_STR_ALL" > vpp_dci_temp.dat
            grep \| vpp_dci_temp.dat | grep -v "tenant_id" > vpp_dci_all.dat
            SEARCH_NUM=$(grep -c "$FILTER\ " vpp_dci_all.dat)
            if [[ "$SEARCH_NUM" -eq 0 ]]; then
                print_prompt "No results found or not unique."
            else
                grep "$FILTER\ " vpp_dci_all.dat > vpp_dci.dat
                ARG_TYPE=$FILTER
                filter_data "$SQL_DCI_STR_FILTER" 'clouddcpeer'
                IS_RUN=1
                IS_AUTO_RUN=0
                DATA_SIZE=$(cat vpp_dci.dat | wc -l )
                read -p "Do you do a step-by-step (${DATA_SIZE} item) configuration check?(Y/N)  " YESORNO
                if [[ "$YESORNO" == "Y" ]] || [[ "$YESORNO" == "y" ]]; then
                    IS_AUTO_RUN=1
                    echo
                fi

                while read LINE;do
                    SERVICE_TYPE=$(echo "$LINE"| awk -F\| '{print $3}' | xargs)

                    if [[ $IS_RUN -ne 0 ]]; then
                        TENANT_ID=$(echo "$LINE"| awk -F\| '{print $1}' | xargs)
                        VPP_CLUSTER=($(run_odl_sql "select manage_ip from vpp where tenant_infos like '%@@@%';" "$TENANT_ID"))
                        get_vpp_role_by_clusters
                        if [[ "$VPP_A_ROLE" == "Master" ]]; then
                            VPP_IP=${VPP_CLUSTER[0]}
                            VPP_PROMPT="${VPP_CLUSTER[0]}-$VPP_A_ROLE / ${VPP_CLUSTER[1]}-$VPP_B_ROLE"
                        else
                            VPP_IP=${VPP_CLUSTER[1]}
                            VPP_PROMPT="${VPP_CLUSTER[1]}-$VPP_B_ROLE / ${VPP_CLUSTER[0]}-$VPP_A_ROLE"
                        fi

                        echo >&2 "$HR"
                        echo >&2 -e "Remote execution of VPP( $VPP_PROMPT ) virtual machine commands"
                        echo >&2 "$HR"

                        VPP_SERVICE_CIDR=$(run_odl_sql "select concat(service_ip,(select substring(value::json->>'cidr' from '/.*') from pool where id='vppServiceIp')) from vpp where id='@@@';" "$VPP_IP")
                        VPP_SERVICE_IF=$(run_odl_sql "select interfaces::json->'service'->>'name' as service from vpp where is_deleted is null and manage_ip='@@@';" "$VPP_IP")

                        show_cmd_rs "vppctl sh int addr $VPP_SERVICE_IF | grep up"
                        show_cmd_rs "vppctl sh int addr $VPP_SERVICE_IF | grep $VPP_SERVICE_CIDR -B5"

                        VPP_VTEP=$(run_odl_sql "select cluster_ip from vpp where manage_ip='@@@'" "$VPP_IP")
                        
                        IS_RUN=0
                    fi

                    VRF_ID=$(echo "$LINE" | awk -F\| '{print $4}' | xargs)
                    DST_CIDR=$(echo "$LINE" | awk -F\| '{print $5}' | xargs)
                    OUT_IF=$(echo "$LINE" | awk -F\| '{print $6}' | xargs)
                    NEXT_HOP=$(echo "$LINE" | awk -F\| '{print $7}' | xargs)

                    if [[ "$SERVICE_TYPE" == "dci" ]]; then
                        DST_VTEP=$DCI_GWIP
                    elif [[ "$SERVICE_TYPE" == "vpn" ]]; then
                        DST_VTEP=$VPN_GWIP
                    fi
                    echo -e "\033[42;30mDST_CIDR: ($DST_CIDR)\033[0m"
                    echo "$HR"
                    show_cmd_rs "vppctl sh vxlan t | grep '$DST_VTEP vni '"
                    show_cmd_rs "vppctl ping $DST_VTEP repeat 2 | grep '2 sent, 2 received'"
                    show_cmd_rs "vppctl ping ${NEXT_HOP} source ${OUT_IF} repeat 2 | grep '2 sent, 2 received'"

                    if ipcalc -4c $NEXT_HOP 2>/dev/null; then
                        show_cmd_rs "vppctl sh ip fib table $VRF_ID $DST_CIDR | grep '${NEXT_HOP} ${OUT_IF}'"
                    fi

                    if ipcalc -6c $NEXT_HOP 2>/dev/null; then
                        show_cmd_rs "vppctl sh ip6 fib table $VRF_ID $DST_CIDR | grep '${NEXT_HOP} ${OUT_IF}'"
                    fi

                    if [[ $IS_AUTO_RUN -ne 0 ]]; then
                        read -p "Do you want to the next part of the configuration check (Y/N)?  " YORN  </dev/tty
                        if [[ "$YORN" == 'N' ]] || [[ "$YORN" == 'n' ]]; then
                            break
                        fi
                    fi
                done < vpp_dci.dat
        
            fi
        fi


        TABLE_NUM=$(run_odl_sql "select count(*) from pg_class where relname = '@@@';" "vpcpeer" )
        if [[ $TABLE_NUM -ge 1 ]]; then
            psql -h $ODL_DB -U postgres -d postgres -c "$SQL_VPC_PEER_STR_ALL" > vpp_vpc_peer_temp.dat
            grep \| vpp_vpc_peer_temp.dat | grep -v "tenant_id" > vpp_vpc_peer_all.dat
            SEARCH_NUM=$(grep -c "$FILTER\ " vpp_dci_all.dat)
            if [[ "$SEARCH_NUM" -eq 0 ]]; then
                print_prompt "No results found or not unique."
            fi
        fi

        
    fi

    ipcalc -4c $FILTER 2>/dev/null
    if [[ $? -eq 0 ]]; then
        psql -h $ODL_DB -U postgres -d postgres -c "$SQL_STR_ALL" > vpp_all_temp.dat
        grep \| vpp_all_temp.dat | grep -v "vm_host_ip" > vpp_all.dat
        SEARCH_NUM=$(grep -c "$FILTER\ " vpp_all.dat)
        if [[ "$SEARCH_NUM" -eq 0 ]]; then
            print_prompt "No results found or not unique."
        elif [[ "$SEARCH_NUM" -gt 2 ]]; then
            TB_HR=$(head -2 vpp_all_temp.dat | tail -1)
            echo ${TB_HR//+/-}
            head -2 vpp_all_temp.dat
            grep "$FILTER\ " vpp_all.dat
            echo 
            print_prompt "No results found or not unique."
        else
            args_init ipv4
            get_about_vxlan_dst_vtep "$FIP"
            if [[ $IS_PHY -eq 0 ]]; then
                ping -c 1 -w 1 "$VPP_IP" &>/dev/null
            else
                fast_ssh $ODL_CTRL ping -c 1 -w 1 "$VPP_IP" &>/dev/null
            fi
            if [[ $? -eq 0 ]]; then
                echo >&2 "$HR"
                if [[ -z "$CMD_STR" ]]; then
                    echo >&2 -e "Remote execution of VPP( $VPP_PROMPT ) virtual machine commands"
                    echo >&2 -e "${HR//=/-}"

                    if [[ $IS_BYPASS -eq 0 ]]; then
                        BYPASS_STR="(enable bypass)"
                    else
                        BYPASS_STR=""
                    fi

                    echo >&2 -e "VPP version: \033[42;30m$VPP_VERSION\033[0m"
                    echo >&2 -e "ODL version: \033[42;30mv$ODL_VERSION $BYPASS_STR\033[0m"
                   
                    echo >&2 -e "VPP type: \033[42;30m$VPP_TYPE\033[0m"
                    if [[ $IS_PHY -eq 1 ]]; then
                        echo >&2 -e "VPP device ID: \033[42;30m$VPP_DEVICE_ID\033[0m"
                    fi
                    echo >&2 -e "Virtual machine port ID: \033[42;30m$VM_PORT_ID\033[0m  Type: \033[42;30m$LOCAL_VM_TYPE\033[0m"
                    if [[ $DST_QOS != "1Kbit" ]] && [[ $DST_QOS != "0Mb" ]] ; then
                        echo >&2 -e "FIP binding bandwidth value: \033[42;30m$DST_QOS\033[0m Type: \033[42;30m$DST_QOS_TYPE\033[0m"
                    else
                        echo >&2 -e "FIP binding bandwidth value: \033[41;30m${DST_QOS}/s\033[0m  Type: \033[42;30m$DST_QOS_TYPE\033[0m"
                    fi
                    echo >&2 -e "FIP corresponds to tenant ID: \033[42;30m$TENANT_ID\033[0m"
                    
                    if [[ $(cat vpp_sg.dat | wc -l ) -gt 4 ]]; then
                        echo >&2 "$HR"
                        grep "device" vpp_sg.dat
                        echo >&2 "$HR"
                        grep " IPv4 " vpp_sg.dat
                    fi
                    echo >&2 "$HR"

                    VPP_SERVICE_CIDR=$(run_odl_sql "select concat(service_ip,(select substring(value::json->>'cidr' from '/.*') from pool where id='vppServiceIp')) from vpp where id='@@@';" "$VPP_IP")
                    show_cmd_rs "vppctl sh int addr $VPP_SERVICE_IF | grep up"
                    show_cmd_rs "vppctl sh int addr $VPP_SERVICE_IF | grep $VPP_SERVICE_CIDR -B5"
                    
                    

                    show_cmd_rs "vppctl sh int addr $VPP_EXTERNAL_IF | grep up"

                    EXT_CIDR_SQL="select cidr from (select concat(data::json->>'iFaceIp','/',data::json->>'mask') as cidr,data::json->>'isIpSet' as config from (select data::json->json_object_keys(data::json) as data from (select data::json->json_object_keys(data::json)->'ips' as data from (select iface_ips::json->'externalInterface'->'cidrs' as data from config where vpp_manage_ip='@@@') A ) A ) A )A where config='true' and '&&&'::inet && cidr::inet;"
                    EXT_CIDR_SQL=$(echo "$EXT_CIDR_SQL" | sed "s#&&&#$FIP#g")
                    EXT_CIDR=$(run_odl_sql "$EXT_CIDR_SQL" "$VPP_IP")
                    if [[ "$EXT_CIDR" ]]; then
                        show_cmd_rs "vppctl sh int addr $VPP_EXTERNAL_IF | grep $EXT_CIDR"
                    fi

                    show_cmd_rs "vppctl sh nat44 sta m | grep -q '$VM_IP external $FIP vrf $LOOP_VRF'"
                    if [[ $? -eq 0 ]]; then
                        FIP_GW_IP=$(get_fip_gw_ip_by_fip "$FIP") 

                        if [[  -z "$FIP_GW_IP" ]]; then
                            print_prompt "The port table has no floatingip ($FIP) information." 1
                        fi

                        show_cmd_rs "vppctl sh ip arp | grep $FIP_GW_IP\ "
                        show_cmd_rs "vppctl sh adj n | grep $FIP_GW_IP\ "


                        show_cmd_rs "vppctl sh ip fib table 0 0.0.0.0/0 | grep '${FIP_GW_IP} ${VPP_EXTERNAL_IF}'"

                        VPP_VERSION_NO=$(fast_ssh $EXT_ARGS $VPP_IP vppctl sh version verbose | grep location | awk -F/ '{print $5}' | awk -F. '{print $NF}' | sed 's/\r//g')
                        VPP_VERSION_NUM=$(echo $VPP_VERSION_NO | awk -F. '{print $NF}'  | sed 's/\r//g')
                        if [[ $VPP_VERSION_NUM -ge 119 ]]; then
                            show_cmd_rs "vppctl ping $FIP_GW_IP repeat 2 | grep '2 sent, 2 received'"
                        fi

                        LOOP_INS=$(run_odl_sql "select segmentation_id from network where id=(select network_id from port where id='@@@')" "$VM_PORT_ID")
                        if [[ "$LOOP_INS" ]]; then
                            LOOP_IF=$(echo "loop$LOOP_INS")
                            LOOP_IF_INDEX=$(run_vpp_cmd sh int $LOOP_IF | grep "$LOOP_IF\ " | awk '{print $2}' | xargs)
                            if [[ -z $LOOP_IF_INDEX ]]; then
                                print_prompt "The $LOOP_IF does not exist." 1
                            fi
                            echo "Acl apply in $LOOP_IF($LOOP_IF_INDEX):" 
                            CMD_STR="vppctl sh acl interface | grep -A2 'sw_if_index $LOOP_IF_INDEX:' | grep 'input\|output'"
                            fast_ssh $EXT_ARGS "$VPP_IP" "$CMD_STR" 
                            if [[ $? -eq 0 ]]; then
                                IS_CHECK_PACKET=2
                                echo "$CMD_STR & [ CHECK ]" | awk -F"&" '{printf "%-101s\033[43;30m%0s \033[0m\n",$1,$2}'

                                for ACL_INDEX in $(fast_ssh $EXT_ARGS "$VPP_IP" "$CMD_STR" | awk -F: '{print $NF}' | grep -Po '[0-9]+');do
                                    echo "$HR"
                                    run_vpp_cmd sh acl acl index $ACL_INDEX
                                done

                            else
                                echo "$CMD_STR & [ OK ]" | awk -F"&" '{printf "%-104s\033[42;30m%0s \033[0m\n",$1,$2}'
                            fi
                            echo "$HR"
                            show_cmd_rs "vppctl sh int addr $LOOP_IF | grep '$SUBNET_CIDR ip4 table-id $LOOP_VRF '"

                            BD_ID=$LOOP_INS
                            if [[ "$BD_ID" ]]; then
                                
                                if [[ $DST_VTEP ]]; then
                                    
                                    show_cmd_rs "vppctl sh vxlan t | grep '$DST_VTEP vni $BD_ID '"
                                    VXLAN_INS=$(run_vpp_cmd sh vxlan t | grep "$DST_VTEP vni $BD_ID\ " | sed 's/.*instance //g;s/ src.*//g')
                                    if [[ "$VXLAN_INS" ]]; then
                                        show_cmd_rs "vppctl sh mode vxlan_tunnel$VXLAN_INS | grep 'l2 bridge vxlan_tunnel$VXLAN_INS bd_id $BD_ID '"
                                        OVS_VTEP=$(run_vpp_cmd sh vxlan t | grep "instance $VXLAN_INS\ " | awk '{print $7}' | xargs)
                                        show_cmd_rs "vppctl ping $DST_VTEP repeat 2 | grep '2 sent, 2 received'"
                                    else
                                        print_prompt "Vxlan tunnel does not exist." 1
                                    fi
                                else
                                    

                                    SQL_VIP_STR="select local_ip,vni,A.host_ip,type,device,vm_ip,vip from (select ( select segmentation_id as vni from network where id=network_id),host_ip,binding_vnic_type as type,device,substring(fix_ips from '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') as vm_ip,json_object_keys(allow_ips::json) as vip from port where is_deleted is null and allow_ips <>'') A left join (select local_ip,host_ip from host where is_deleted is null ) B on A.host_ip=B.host_ip where vip = '@@@';"
                                    SQL_VIP_STR=$(echo "$SQL_VIP_STR" | sed "s#@@@#$VM_IP#g")
                                    psql -t -h $ODL_DB -U postgres -d postgres -c "$SQL_VIP_STR" | grep \|  > vpp_vip_proc.dat
                                    SQL_VIP_FILTER_STR="select local_ip,A.host_ip,type,vm_ip,vip,device from (select ( select segmentation_id as vni from network where id=network_id),host_ip,binding_vnic_type as type,device,substring(fix_ips from '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') as vm_ip,json_object_keys(allow_ips::json) as vip from port where is_deleted is null and allow_ips <>'') A left join (select local_ip,host_ip from host where is_deleted is null ) B on A.host_ip=B.host_ip where vip = '@@@';"
                                    SQL_VIP_FILTER_STR=$(echo "$SQL_VIP_FILTER_STR" | sed "s#@@@#$VM_IP#g")
                                    psql -h $ODL_DB -U postgres -d postgres -c "$SQL_VIP_FILTER_STR" > vpp_vip_filter.dat

                                    cat vpp_vip_filter.dat | grep \| | grep local_ip 
                                    echo "${HR//=/-}"
                                    cat vpp_vip_filter.dat | grep \| | grep -v local_ip
                                    echo "$HR"
                                    
                                    while read LINE;do
                                        VIP_VM_VTEP=$(echo "$LINE" | awk -F \| '{print $1}'|xargs)
                                        VIP_VNI=$(echo "$LINE" | awk -F \| '{print $2}'|xargs)
                                        VIP_VM_TYPE=$(echo "$LINE" | awk -F \| '{print $4}'|xargs)
                                        VIP_VM_DEVICE_ID=$(echo "$LINE" | awk  -F \|  '{print $5}'|xargs)
                                        VIP_VM_IP=$(echo "$LINE" | awk  -F \|  '{print $6}'|xargs)
                                        VIP_IP=$(echo "$LINE" | awk  -F \|  '{print $7}'|xargs)
                                        
                                        if [[ $VIP_VM_DEVICE_ID ]] && [[ $VIP_VM_VTEP ]]; then
                                            echo -e "\033[42;30m$VIP_VM_IP ($VIP_VM_TYPE)\033[0m"
                                            echo "$HR"
                                        else
                                            echo -e "\033[42;30m$VIP_VM_IP ($VIP_VM_TYPE)\033[0m"
                                            echo "$HR"
                                            if [[ $VPP_TYPE =~ "physical" ]] && [[ "$IS_BYPASS" -eq 0 ]]; then
                                                VIP_VM_VTEP=""
                                                
                                            else
                                                VIP_VM_VTEP=$(run_odl_sql "select cluster_ip from vpp where gate_way_type ='@@@' and is_deleted is null and is_available='t' limit 1;" "vxlanGw")
                                            fi
                                        fi

                                        VIP_VLAN=$(run_odl_sql "select vlan from port where is_deleted  is null and device='@@@';" "$VIP_VM_DEVICE_ID")
                                        show_cmd_rs "vppctl sh ip arp | grep '$VIP_IP .\+$LOOP_IF'"
                                        show_cmd_rs "vppctl sh mode | grep 'l2 bridge BondEthernet0.$VIP_VLAN bd_id $VIP_VNI shg 2'"

                                        if [[ "$VIP_VM_VTEP" ]]; then
                                            show_cmd_rs "vppctl sh vxlan t | grep '$VIP_VM_VTEP vni $VIP_VNI\ '"
                                            VXLAN_INS=$(run_vpp_cmd sh vxlan t | grep "$VIP_VM_VTEP vni $VIP_VNI\ " | sed 's/.*instance //g;s/ src.*//g')
                                            if [[ "$VXLAN_INS" ]] ; then
                                                show_cmd_rs "vppctl sh mode vxlan_tunnel$VXLAN_INS | grep 'l2 bridge vxlan_tunnel$VXLAN_INS'"
                                                OVS_VTEP=$(run_vpp_cmd sh vxlan t | grep "instance $VXLAN_INS\ " | awk '{print $7}' | xargs)
                                                show_cmd_rs "vppctl ping $VIP_VM_VTEP repeat 2 | grep '2 sent, 2 received'"
                                                show_cmd_rs "vppctl sh ip arp | grep '$VIP_VM_IP .\+$LOOP_IF'"
                                                show_cmd_rs "vppctl sh adj n | grep '$VIP_VM_IP $LOOP_IF'"
                                                show_cmd_rs "vppctl ping $VIP_VM_IP source $LOOP_IF repeat 2 | grep '2 sent, 2 received'"
                                            else
                                                print_prompt "Vxlan tunnel does not exist." 1
                                            fi
                                        else

                                            show_cmd_rs "vppctl sh ip arp | grep '$VIP_VM_IP .\+$LOOP_IF'"
                                            show_cmd_rs "vppctl sh adj n | grep '$VIP_VM_IP $LOOP_IF'"
                                            show_cmd_rs "vppctl ping $VIP_VM_IP source $LOOP_IF repeat 2 | grep '2 sent, 2 received'"
                                        fi


                                    done <  vpp_vip_proc.dat
                                fi

                                
                            else
                                print_prompt "The loop does not join bridge-domian." 1
                            fi

                            fast_ssh $EXT_ARGS "$VPP_IP" ss -ant | grep -q ':8183\ '
                            if [[ $? -eq 0 ]]; then
                                DEFAULT_ACL_INDEX=$(fast_ssh $EXT_ARGS "$VPP_IP" get_hc_config context | grep "default-deny-port-acl" -B 1 | head -1 | awk '{print int($NF)}')
                                MIIT_ACL_INDEX=$(fast_ssh $EXT_ARGS "$VPP_IP" get_hc_config context | grep "miit-record-acl" -B 1 | head -1 | awk '{print int($NF)}')
                                EXT_IF_INDEX=$(fast_ssh $EXT_ARGS "$VPP_IP" get_hc_config context | grep "$VPP_EXTERNAL_IF\"" -B 1 | head -1 | awk '{print int($NF)}')
                                if [[ "$DEFAULT_ACL_INDEX" ]]; then
                                    ACL_APPLY="${MIIT_ACL_INDEX}, ${DEFAULT_ACL_INDEX}"
                                    show_cmd_rs "vppctl sh acl interface sw_if_index $EXT_IF_INDEX | grep -B1 '$ACL_APPLY'"
                                    CMD_STR="vppctl sh acl interface | grep -A2 'sw_if_index $EXT_IF_INDEX:' | grep 'input\|output'"
                                    for ACL_INDEX in $(fast_ssh $EXT_ARGS "$VPP_IP" "$CMD_STR" | awk -F: '{print $NF}' | grep -Po '[0-9]+');do
                                        run_vpp_cmd sh acl acl index $ACL_INDEX
                                        echo "$HR"
                                    done
                                fi
                            else
                                print_prompt "The Tenant Gateway Agent software (Honeycomb) service is not available..." 1
                            fi
                            
                            show_cmd_rs "vppctl sh nat44 interfaces | grep $VPP_EXTERNAL_IF"
                            show_cmd_rs "vppctl sh nat44 interfaces | grep $LOOP_IF\ "
                            show_cmd_rs "vppctl sh ip fib table 0 '$FIP/32' | grep  '$FIP/32'"

                            if [[ $DST_VTEP ]]; then
                                show_cmd_rs "vppctl sh ip arp | grep '$VM_IP .\+$LOOP_IF'"
                                show_cmd_rs "vppctl sh adj n | grep '$VM_IP $LOOP_IF'"
                                show_cmd_rs "vppctl ping $VM_IP source $LOOP_IF repeat 2 | grep '2 sent, 2 received'"
                                if [[ $EW_ENABLE_PING -ne 0 ]]; then
                                    print_prompt "The virtual machine( ${SUBNET_CIDR%/*} ) is not open global ICMP access functions..." 2
                                fi
                            fi
                        else
                            print_prompt "The loop interface does not exist or does not specify VRF" 1
                        fi
                    else
                        print_prompt "NAT mapping does not exist." 1
                    fi
                fi
            else
                print_prompt "VPP Address entered incorrectly or unreachable."
            fi
        fi
    fi

    ipcalc -6c $FILTER 2>/dev/null
    if [[ $? -eq 0 ]]; then
        psql -h $ODL_DB -U postgres -d postgres -c "$SQL_IP6_STR_ALL" > vpp_ip6_all_temp.dat
        grep \| vpp_ip6_all_temp.dat | grep -v "host_ip" > vpp_ip6_all.dat
        SEARCH_NUM=$(grep -c "$FILTER\ " vpp_ip6_all.dat)
        if [[ "$SEARCH_NUM" -eq 0 ]]; then
            print_prompt "No results found or not unique."
        elif [[ "$SEARCH_NUM" -gt 2 ]]; then
            TB_HR=$(head -2 vpp_ip6_all_temp.dat | tail -1)
            echo ${TB_HR//+/-}
            head -2 vpp_ip6_all_temp.dat
            grep "$FILTER\ " vpp_ip6_all.dat
            echo 
            print_prompt "No results found or not unique."
        else
            args_init ipv6 
            get_about_ip6_vxlan_dst_vtep $VM_IP
            if [[ $IS_PHY -eq 0 ]]; then
                ping -c 1 -w 1 "$VPP_IP" &>/dev/null
            else
                fast_ssh $ODL_CTRL ping -c 1 -w 1 "$VPP_IP" &>/dev/null
            fi
            if [[ $? -eq 0 ]]; then
                echo >&2 "$HR"
                if [[ -z "$CMD_STR" ]]; then
                    VPP_DEVICE_ID=$(run_odl_sql "select vpp_id from vpp where manage_ip='@@@';" "$VPP_IP")
                    echo >&2 -e "Remote execution of VPP( $VPP_PROMPT ) virtual machine commands"
                    echo >&2 -e "${HR//=/-}"

                    if [[ $IS_BYPASS -eq 0 ]]; then
                        BYPASS_STR="(enable bypass)"
                    else
                        BYPASS_STR=""
                    fi
                    echo >&2 -e "VPP version: \033[42;30mv$VPP_VERSION\033[0m"
                    echo >&2 -e "ODL version: \033[42;30mv$ODL_VERSION $BYPASS_STR\033[0m"

                    echo >&2 -e "VPP type: \033[42;30m$VPP_TYPE\033[0m"
                    if [[ $IS_PHY -eq 1 ]]; then
                        echo >&2 -e "VPP device ID: \033[42;30m$VPP_DEVICE_ID\033[0m"
                    fi
                    echo >&2 -e "Virtual machine port ID: \033[42;30m$VM_PORT_ID\033[0m  Type: \033[42;30m$LOCAL_VM_TYPE\033[0m"
                    if [[ $DST_QOS != "1Kbit" ]] && [[ $DST_QOS != "0Mb" ]]; then
                        echo >&2 -e "FIP binding bandwidth value: \033[42;30m$DST_QOS/s\033[0m  Type: \033[42;30m$DST_QOS_TYPE\033[0m"
                    else
                        echo >&2 -e "FIP binding bandwidth value: \033[41;30m${DST_QOS}/s\033[0m  Type: \033[42;30m$DST_QOS_TYPE\033[0m"

                    fi
                    echo >&2 -e "FIP corresponds to tenant ID: \033[42;30m$TENANT_ID\033[0m"
                    
                    if [[ $(cat vpp_sg.dat | wc -l ) -gt 4 ]]; then
                        echo >&2 "$HR"
                        grep "device" vpp_sg.dat
                        echo >&2 "$HR"
                        grep " IPv6 " vpp_sg.dat
                    fi
                    echo >&2 "$HR"

                    VPP_SERVICE_IF=$(run_odl_sql "select interfaces::json->'service'->>'name' as service from vpp where is_deleted is null and manage_ip='@@@';" "$VPP_IP")
                    VPP_EXTERNAL_IF=$(run_odl_sql "select interfaces::json->'external'->>'name' as external from vpp where is_deleted is null and manage_ip='@@@';" "$VPP_IP")
                    VPP_SERVICE_CIDR=$(run_odl_sql "select concat(service_ip,(select substring(value::json->>'cidr' from '/.*') from pool where id='vppServiceIp')) from vpp where id='@@@';" "$VPP_IP")
                    VPP_EXTERNAL_CIDRS=$(run_odl_sql "select cidr from (select concat(data::json->>'iFaceIp','/',data::json->>'mask') as cidr,data::json->>'isIpSet' as config from (select data::json->json_object_keys(data::json) as data from (select data::json->json_object_keys(data::json)->'ips' as data from (select iface_ips::json->'externalInterface'->'cidrs' as data from config where vpp_manage_ip='@@@') A ) A ) A )A where config='true';" "$VPP_IP")
                    
                    show_cmd_rs "vppctl sh int addr $VPP_SERVICE_IF | grep up -A5 | grep $VPP_SERVICE_CIDR -B5"
                    show_cmd_rs "vppctl sh int addr $VPP_EXTERNAL_IF | grep up"
                    
                    for EXT_CIDR in $(echo $VPP_EXTERNAL_CIDRS); do
                        ipcalc -4c $EXT_CIDR 2>/dev/null && continue
                        show_cmd_rs "vppctl sh int addr $VPP_EXTERNAL_IF | grep $EXT_CIDR"
                    done

                    EXT_GW_ADDR=$(run_odl_sql "select gw_ip from subnet where id =(select external_fixed_ips::json->json_object_keys(external_fixed_ips::json)->>'subnetId' from router where id=(select router_id from ipv6ndproxy where ip_address ='@@@' and is_deleted is null));" "$VM_IP")
                    if [[ -z "$EXT_GW_ADDR" ]]; then
                        print_prompt "The external_fixed_ips of Router tables corresponding to ND Address ($VM_IP) do not exist.." 1
                    fi
                    if [[ -z $LOOP_INS ]] || [[ -z $LOOP_VRF ]]; then
                        print_prompt "The port ID and Router ID tables corresponding to ND Address ($VM_IP) do not exist.." 1
                    fi

                    BD_ID=$LOOP_INS
                    LOOP_IF=loop$LOOP_INS
                    show_cmd_rs "vppctl sh ip6 neighbors | grep $VM_IP\ "
                    show_cmd_rs "vppctl sh int addr $LOOP_IF | grep '$SUBNET_CIDR ip6 table-id $LOOP_VRF '"
                   
                    show_cmd_rs "vppctl sh ip6 fib table 0 ::/0 | grep $EXT_GW_ADDR ${VPP_EXTERNAL_IF}"
                    show_cmd_rs "vppctl ping $EXT_GW_ADDR repeat 2 | grep '2 sent, 2 received'"

                    LOOP_IF_INDEX=$(run_vpp_cmd sh int $LOOP_IF | grep "$LOOP_IF\ " | awk '{print $2}' | xargs)
                    
                    echo "Acl apply in $LOOP_IF($LOOP_IF_INDEX):" 
                    CMD_STR="vppctl sh acl interface | grep -A2 'sw_if_index $LOOP_IF_INDEX:' | grep 'input\|output'"
                    fast_ssh $EXT_ARGS "$VPP_IP" "$CMD_STR" 
                    if [[ $? -eq 0 ]]; then
                        IS_CHECK_PACKET=2
                        echo "$CMD_STR & [ CHECK ]" | awk -F"&" '{printf "%-101s\033[43;30m%0s \033[0m\n",$1,$2}'
                        for ACL_INDEX in $(fast_ssh $EXT_ARGS "$VPP_IP" "$CMD_STR" | awk -F: '{print $NF}' | grep -Po '[0-9]+');do
                            echo "$HR"
                            run_vpp_cmd sh acl acl index $ACL_INDEX
                        done
                    else
                        echo "$CMD_STR & [ OK ]" | awk -F"&" '{printf "%-104s\033[42;30m%0s \033[0m\n",$1,$2}'
                    fi
                    echo "$HR"

                    show_cmd_rs "vppctl sh vxlan t | grep '$DST_VTEP vni $BD_ID '"

                    VXLAN_INS=$(run_vpp_cmd sh vxlan t | grep "$DST_VTEP vni $BD_ID " | sed 's/.*instance //g;s/ src.*//g')
                    if [[ "$VXLAN_INS" ]]; then
                        show_cmd_rs "vppctl sh mode vxlan_tunnel$VXLAN_INS | grep 'l2 bridge vxlan_tunnel$VXLAN_INS bd_id $BD_ID '"
                        OVS_VTEP=$(run_vpp_cmd sh vxlan t | grep "instance $VXLAN_INS\ " | awk '{print $7}' | xargs)
                        show_cmd_rs "vppctl ping $DST_VTEP repeat 2 | grep '2 sent, 2 received'"
                    else
                        print_prompt "Vxlan tunnel does not exist." 1
                    fi
                    
                    DEFAULT_ACL_INDEX=$(fast_ssh $EXT_ARGS "$VPP_IP" get_hc_config context | grep "default-deny-port-acl" -B 1 | head -1 | awk '{print int($NF)}')
                    MIIT_ACL_INDEX=$(fast_ssh $EXT_ARGS "$VPP_IP" get_hc_config context | grep "miit-record-acl" -B 1 | head -1 | awk '{print int($NF)}')
                    EXT_IF_INDEX=$(fast_ssh $EXT_ARGS "$VPP_IP" get_hc_config context | grep "$VPP_EXTERNAL_IF\"" -B 1 | head -1 | awk '{print int($NF)}')
                    ACL_APPLY="${MIIT_ACL_INDEX}, ${DEFAULT_ACL_INDEX}"
                    show_cmd_rs "vppctl sh acl interface sw_if_index $EXT_IF_INDEX | grep -B1 '$ACL_APPLY'"
                    CMD_STR="vppctl sh acl interface | grep -A2 'sw_if_index $EXT_IF_INDEX:' | grep 'input\|output'"
                    for ACL_INDEX in $(fast_ssh $EXT_ARGS "$VPP_IP" "$CMD_STR" | awk -F: '{print $NF}' | grep -Po '[0-9]+');do
                        run_vpp_cmd sh acl acl index $ACL_INDEX
                        echo "$HR"
                    done
                    
                    show_cmd_rs "vppctl sh ip6 nd proxy | grep $VM_IP\ "
                    show_cmd_rs "vppctl sh ip6 fib table $LOOP_VRF ::/0 | grep ipv6-VRF:0"
                    show_cmd_rs "vppctl sh ip6 fib table 0 $VM_IP/128 | grep ipv6-VRF:$LOOP_VRF"
                    show_cmd_rs "vppctl ping $VM_IP source loop$LOOP_INS repeat 2 | grep '2 sent, 2 received'"
                    if [[ $EW_ENABLE_PING -ne 0 ]]; then
                        print_prompt "The virtual machine( ${SUBNET_CIDR%/*} ) is not open global ICMP access functions..." 2
                    fi
                
                fi
            else
                print_prompt "VPP Address entered incorrectly or unreachable."
            fi
        fi
    fi
}

gen_get_lldp(){
    TYPE=$1
    if [[ $TYPE == "ALL" ]]; then
cat > /tmp/get_lldp.sh <<\EOF
rpm -q lldpd &>/dev/null || yum install -y lldpd
for NIC_PCI in $(ls /sys/kernel/debug/i40e/ 2>/dev/null);do
    echo 'lldp stop' > /sys/kernel/debug/i40e/$NIC_PCI/command
done
pidof lldpd &>/dev/null || service lldpd start

sleep 3

echo $HR
INT_BOND_MEMBERS=($(grep -li master=bond1 /etc/sysconfig/network-scripts/* | xargs grep -h DEVICE= | awk -F= '{print $2}'))
for MEMBER in ${INT_BOND_MEMBERS[*]};do
    SW_MNG_IP=$(lldpctl -f xml | sed -n "/${MEMBER}/,/\/interface/p" | grep mgmt-ip | grep -Po '(?<=>).*(?=<)')
    SW_IFNAME=$(lldpctl -f xml | sed -n "/${MEMBER}/,/\/interface/p" | grep ifname | grep -Po '(?<=>).*(?=<)')
    echo "MEMBER: ${MEMBER} SW_MNG_IP: ${SW_MNG_IP} SW_IFNAME: ${SW_IFNAME}" 
done
echo $HR
EXT_BOND_MEMBERS=($(grep -li master=bond2 /etc/sysconfig/network-scripts/* | xargs grep -h DEVICE= | awk -F= '{print $2}'))
for MEMBER in ${EXT_BOND_MEMBERS[*]};do
    SW_MNG_IP=$(lldpctl -f xml | sed -n "/${MEMBER}/,/\/interface/p" | grep mgmt-ip | grep -Po '(?<=>).*(?=<)')
    SW_IFNAME=$(lldpctl -f xml | sed -n "/${MEMBER}/,/\/interface/p" | grep ifname | grep -Po '(?<=>).*(?=<)')
    echo "MEMBER: ${MEMBER} SW_MNG_IP: ${SW_MNG_IP} SW_IFNAME: ${SW_IFNAME}" 
done
echo $HR
EOF
    else
cat > /tmp/get_lldp.sh <<\EOF
rpm -q lldpd &>/dev/null || yum install -y lldpd &>/dev/null
for NIC_PCI in $(ls /sys/kernel/debug/i40e/ 2>/dev/null);do
    echo 'lldp stop' > /sys/kernel/debug/i40e/$NIC_PCI/command
done
pidof lldpd &>/dev/null || service lldpd start

sleep 3
echo $HR
INT_BOND_MEMBERS=($(grep -li master=bond1 /etc/sysconfig/network-scripts/* | xargs grep -h DEVICE= | awk -F= '{print $2}'))
for MEMBER in ${INT_BOND_MEMBERS[*]};do
    SW_MNG_IP=$(lldpctl -f xml | sed -n "/${MEMBER}/,/\/interface/p" | grep mgmt-ip | grep -Po '(?<=>).*(?=<)')
    SW_IFNAME=$(lldpctl -f xml | sed -n "/${MEMBER}/,/\/interface/p" | grep ifname | grep -Po '(?<=>).*(?=<)')
    echo "MEMBER: ${MEMBER} SW_MNG_IP: ${SW_MNG_IP} SW_IFNAME: ${SW_IFNAME}" 
done
echo $HR
EOF
    fi

}


run_get_lldp(){
    HOST_ADDR=$1
    TYPE=$2
    CHASSIS=$(fast_ssh $HOST_ADDR hostnamectl | grep Chassis | awk '{print $NF}' | xargs)
    if [[ $CHASSIS == "server" ]]; then
        gen_get_lldp $TYPE
        ssh -n -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p${SERVER_SSH_PORT} $HOST_ADDR : &>/dev/null
        if [[ $? -eq 255 ]]; then
            scp -P${SERVER_SSH_PORT} /tmp/get_lldp.sh secure@$HOST_ADDR:/tmp &>/dev/null
        else
            scp -P${SERVER_SSH_PORT} /tmp/get_lldp.sh $HOST_ADDR:/tmp &>/dev/null
        fi
        fast_ssh $HOST_ADDR sh /tmp/get_lldp.sh
    else
        print_prompt "Non-server($CHASSIS) is not currently supported..."
    fi
}

get_vpp_host_info(){

    ARG_TYPE=$(format_uuid $ARG_TYPE)
    local HOST_ADDR="$ARG_TYPE"
    local SIGNAL="$ARG_VAL"


    if [[ "$SIGNAL" == "lldp" ]]; then

        run_get_lldp $HOST_ADDR ALL
        exit 0

    fi


    check_db_table(){
        DB_TB_SIZE=$(psql -h $ODL_DB -U postgres -d postgres -c "\dt" | grep -c " vpp \| tenant \| router \| network \| subnet \| port \| floatingip \| nfv_image ")
        if [[ $DB_TB_SIZE -lt 8 ]]; then
            DB_TB=$(psql -h $ODL_DB -U postgres -d postgres -c "\dt" | grep -o " vpp \| tenant \| router \| network \| subnet \| port \| floatingip \| nfv_image " | xargs )
            echo "Database tables need (vpp tenant router network subnet port floatingip nfv_image), The normal table has ($DB_TB)"
            exit 1
        fi
    }

    pull_db_data(){
        echo "Data is loading, please wait..."
        echo  
        if [[ -n $FILTER ]]; then
            FILTER_SQL_STR="select '@@@' as k_id,A.vpp_id,A.tenant_id,A.type,B.image,A.manage_ip,'%%%' as cluster_role from (select manage_ip,vpp_id,image_ref,gate_way_type as type,json_object_keys(tenant_infos::json) as tenant_id from vpp where is_deleted is null) A left join (select name as image,id from nfv_image where is_deleted is null) B on A.image_ref=B.id;"
            TENANT_SQL_STR="select A.manage_ip,A.tenant_id,A.rs,A.srs,B.ns,B.ss,B.ps,B.fs from (select distinct A.manage_ip,A.tenant_id,B.rs,B.srs from (select concat(vpp_manage_ip,' - ',vpp_manage_ip_slave) as manage_ip,id as tenant_id from tenant where is_deleted is null and vpp_manage_ip is not null ) A left join (select A.tenant_id,A.rs,B.srs from (select tenant_id,count(*) as rs from router where is_deleted is null group by tenant_id) A left join (select tenant_id,sum(array_length(regexp_split_to_array(subnets,'key'),1)-1) as srs from router where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id ) B on A.tenant_id=B.tenant_id ) A left join (select distinct A.tenant_id,A.ns,A.ss,B.ps,B.fs from (select A.tenant_id,A.ns,B.ss from (select tenant_id,count(*) as ns from network where is_deleted is null group by tenant_id) A left join (select tenant_id,count(*) as ss from subnet where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id) A left join (select A.tenant_id,A.ps,B.fs from (select tenant_id,count(*) as ps from port where is_deleted is null and (device_owner like 'compute:%' or device_owner='baremetal:none') group by tenant_id) A left join (select tenant_id,count(*) as fs from floatingip where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id ) B on A.tenant_id=B.tenant_id ) B on A.tenant_id=B.tenant_id;"
            ROUTER_SQL_STR="select concat(B.vpp_manage_ip,' - ',B.vpp_manage_ip_slave) as manage_ip,A.tenant_id,A.router_id,A.snat,cast(A.vrf_id as integer) from (select tenant_id,enable_snat as snat,id as router_id,vrf_table_id as vrf_id from router where is_deleted is null ) A left join ( select vpp_manage_ip,vpp_manage_ip_slave,id as tenant_id from tenant where is_deleted is null and vpp_manage_ip is not null) B on A.tenant_id = B.tenant_id order by vrf_id;"
            NETWORK_SQL_STR="select concat(B.vpp_manage_ip,' - ',B.vpp_manage_ip_slave) as manage_ip,A.tenant_id,A.network_id,cast(A.bd_id as integer) from (select tenant_id,id as network_id,segmentation_id as bd_id from network where is_deleted is null and segmentation_id is not null ) A left join ( select vpp_manage_ip,vpp_manage_ip_slave,id as tenant_id from tenant where is_deleted is null and vpp_manage_ip is not null) B on A.tenant_id = B.tenant_id order by bd_id;"
            SUBNET_SQL_STR="select concat(B.vpp_manage_ip,' - ',B.vpp_manage_ip_slave) as manage_ip,A.tenant_id,A.subnet_id,A.cidr,A.loop from (select tenant_id,id as subnet_id,concat(gw_ip,substring(cidr from '/\d+')) as cidr,concat('loop',(select segmentation_id from network where id=network_id)::integer) as loop from subnet where is_deleted is null ) A left join ( select vpp_manage_ip,vpp_manage_ip_slave,id as tenant_id from tenant where is_deleted is null and vpp_manage_ip is not null) B on A.tenant_id = B.tenant_id order by cidr;"
            SUBNET_IN_ROUTER_SQL_STR="select concat(B.vpp_manage_ip,' - ',B.vpp_manage_ip_slave) as manage_ip,A.tenant_id,A.subnet_id,A.loop,A.vrf_id,A.cidr from (select A.tenant_id,B.loop,A.vrf_id,B.cidr,A.subnet_id from (select tenant_id,vrf_table_id as vrf_id,json_object_keys(subnets::json) as subnet_id from router where is_deleted is null and subnets::text <> 'null') A inner join (select subnet_id,concat('loop',ins) as loop,cidr from (select id as subnet_id,network_id,concat(gw_ip,substring(cidr from '/\d+')) as cidr from subnet where is_deleted is null and router_id is not null) A left join (select segmentation_id as ins,id from network where is_deleted is null ) B on A.network_id=B.id) B on A.subnet_id=B.subnet_id) A left join (select vpp_manage_ip,vpp_manage_ip_slave,id as tenant_id from tenant where is_deleted is null and vpp_manage_ip is not null) B on A.tenant_id = B.tenant_id order by vrf_id;"
            PORT_SQL_STR="select concat(B.vpp_manage_ip,' - ',B.vpp_manage_ip_slave) as manage_ip,A.tenant_id,A.id as port_id,A.device,A.host_ip,A.status,A.fix_ips from (select status,tenant_id,device,host_ip,concat(substring(fix_ips from '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'),'  ', substring(fix_ips from '[0-9a-fA-F]{1,4}:.+(?=::)::[0-9a-fA-F]{1,4}')) as fix_ips,id from port where is_deleted is null and (device_owner like 'compute:%' or device_owner='baremetal:none')) A left join (select vpp_manage_ip,vpp_manage_ip_slave,id as tenant_id from tenant where is_deleted is null and vpp_manage_ip is not null) B on A.tenant_id = B.tenant_id order by host_ip,device;"
            FIP_SQL_STR="select A.manage_ip,A.tenant_id,A.device_owner,A.floating_ip,A.fixed_ip,B.speed_limit,B.type from (select concat(B.vpp_manage_ip,' - ',B.vpp_manage_ip_slave) as manage_ip,A.tenant_id,A.port_id,A.device_owner,A.floating_ip,A.fixed_ip from (select tenant_id,port_id,(select device_owner from port where id=port_id) as device_owner,floating_ip,fixed_ip from floatingip where is_deleted is null ) A left join (select vpp_manage_ip,vpp_manage_ip_slave,id as tenant_id from tenant where is_deleted is null and vpp_manage_ip is not null) B on A.tenant_id = B.tenant_id ) A left join (select A.floating_ip,case when A.speed_limit is null then '1Kbit' else concat(A.speed_limit,'Mb') end as speed_limit,'private' as type from ( select  floating_ip,substring(qos_policy_id from '[0-9]+$')::int as speed_limit  from floatingip where   is_deleted is null and qos_policy_id<>'')A union all select public_ip_infos::json->json_object_keys(public_ip_infos::json)->>'ip' as floating_ip,concat(substring(qos_policy_id from '[0-9]+$')::int,'Mb') as speed_limit,'public' as type from ippool where is_deleted is null) B on A.floating_ip=B.floating_ip order by device_owner;"
            
            PORT_DEVICE_TID_STR="select tenant_id,device from port where is_deleted is null and length(device::text)=36;"
            NETWORK_ID_TID_STR="select tenant_id,id from network where is_deleted is null;"
            FLOATINGIP_FIP_TID_STR="select tenant_id,floating_ip from floatingip where is_deleted is null;"
            IPV6_ADDR_TID_STR="select tenant_id,ip from (select tenant_id,family(cast(fix_ips::json->json_object_keys(fix_ips::json)->>'ip' as inet)), fix_ips::json->json_object_keys(fix_ips::json)->>'ip' as ip from port where is_deleted is null) A where A.family='6';"

            psql -h $ODL_DB -U postgres -d postgres -c "$FILTER_SQL_STR" > vpp_filter.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$TENANT_SQL_STR" > vpp_tenant.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$ROUTER_SQL_STR" > vpp_router.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$NETWORK_SQL_STR" > vpp_network.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$SUBNET_SQL_STR" > vpp_subnet.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$SUBNET_IN_ROUTER_SQL_STR" > vpp_subnet_in_router.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$PORT_SQL_STR" > vpp_port.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$FIP_SQL_STR" > vpp_fip.dat

            psql -h $ODL_DB -U postgres -d postgres -c "$PORT_DEVICE_TID_STR" > vpp_portid_tid.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$NETWORK_ID_TID_STR" > vpp_vpcid_tid.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$FLOATINGIP_FIP_TID_STR" > vpp_fip_tid.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$IPV6_ADDR_TID_STR" > vpp_ipv6_tid.dat

            PHYGW_SQL_STR="select case when tenant_id='' or tenant_id='{}' or tenant_id is null then '' else json_object_keys(tenant_id::json) end as tenant_id,type,cluster,manage_ip,build_path_version from (select tenant_infos as tenant_id,gate_way_type as type ,'GGG' as build_path_version,manage_ip,'@@@@@@' as cluster from vpp where gate_way_type like 'physical%')A;"
            psql -h $ODL_DB -U postgres -d postgres -c "$PHYGW_SQL_STR" > vpp_phygw.dat
        else
            USAGE_SQL_STR="select A.type,A.vpp_number,A.tenant_number,A.tenant_maximum,concat(cast(round(A.tenant_number::numeric/A.tenant_maximum::numeric,4)*100 as char(5)),'%' ) as usage_rate from (select A.type,B.vpp_num as vpp_number,A.used as tenant_number, case when A.type like '%small_cluster%' then B.vpp_num/2 else B.vpp_num*50 end as tenant_maximum from (select gate_way_type as type,count(*) as used from tenant where is_deleted is null and vpp_manage_ip is not null group by type) A left join (select gate_way_type as type,count(*) as vpp_num from vpp where is_deleted is null group by type) B on A.type=B.type) A;"
            PHYSICAL_SQL_STR="select AA.type,BB.manage_ip,AA.ts,AA.rs,AA.srs,AA.ns,AA.ss,AA.ps,AA.fs,'@@@' as build_path_version from (select AA.type,AA.cluster_ip,AA.manage_ip,AA.ts,AA.rs,AA.srs,AA.ns,AA.ss,AA.ps,BB.fs from (select AA.type,AA.cluster_ip,AA.manage_ip,AA.ts,AA.rs,AA.srs,AA.ns,AA.ss,BB.ps from (select AA.type,AA.cluster_ip,AA.manage_ip,AA.ts,AA.rs,AA.srs,AA.ns,BB.ss from (select AA.type,AA.cluster_ip,AA.manage_ip,AA.ts,AA.rs,AA.srs,BB.ns from (select AA.type,AA.cluster_ip,AA.manage_ip,AA.ts,AA.rs,BB.srs from (select AA.type,AA.cluster_ip,AA.manage_ip,AA.ts,BB.rs from (select B.type,B.cluster_ip,B.manage_ip,A.ts from (select manage_ip,sum(array_length(regexp_split_to_array(tenant_infos,'T'),1)-1) as ts from vpp  where is_deleted is null group by manage_ip) A right join (select manage_ip,cluster_ip,gate_way_type as type from vpp where is_deleted is null and vpp_id is null) B on A.manage_ip = B.manage_ip) AA left join (select A.manage_ip,sum(B.rs) as rs from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is null) A left join (select tenant_id,count(*) as rs from router where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip) BB on AA.manage_ip = BB.manage_ip) AA left join (select A.manage_ip,sum(B.srs) as srs from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is null) A left join (select tenant_id,sum(array_length(regexp_split_to_array(subnets,'key'),1)-1) as srs from router where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip) BB on AA.manage_ip = BB.manage_ip) AA left join (select A.manage_ip,sum(B.ns) as ns from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is null) A left join (select tenant_id,count(*) as ns from network where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip) BB on AA.manage_ip = BB.manage_ip) AA left join (select A.manage_ip,sum(B.ss) as ss from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is null) A left join (select tenant_id,count(*) as ss from subnet where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip ) BB on AA.manage_ip = BB.manage_ip) AA left join (select A.manage_ip,sum(B.ps) as ps from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is null) A left join (select tenant_id,count(*) as ps from port where is_deleted is null  group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip ) BB on AA.manage_ip = BB.manage_ip  )AA left join (select A.manage_ip,sum(B.fs) as fs from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is null) A left join (select tenant_id,count(*) as fs from floatingip where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip )  BB on AA.manage_ip = BB.manage_ip order by cluster_ip) AA left join (select A.cluster_ip,A.manage_ip as id,concat(A.manage_ip,' - ',B.manage_ip) as manage_ip from (select manage_ip,cluster_ip from vpp where is_deleted is null and vpp_id is null order by manage_ip desc) A left join (select manage_ip,cluster_ip from vpp where is_deleted is null and vpp_id is null  order by manage_ip asc) B on A.cluster_ip=B.cluster_ip and A.manage_ip<>B.manage_ip  order by cluster_ip)BB on BB.id=AA.manage_ip;"
            SQL_STR="select '@@@' as k_id,AA.vpp_id,AA.type,AA.image,BB.manage_ip,AA.ts,AA.rs,AA.srs,AA.ns,AA.ss,AA.ps,AA.fs from (select AA.vpp_id,AA.type,BB.image,AA.manage_ip,AA.ts,AA.rs,AA.srs,AA.ns,AA.ss,AA.ps,AA.fs from (select AA.vpp_id,AA.type,AA.image_id,AA.manage_ip,AA.ts,AA.rs,AA.srs,AA.ns,AA.ss,AA.ps,BB.fs from (select AA.vpp_id,AA.type,AA.image_id,AA.manage_ip,AA.ts,AA.rs,AA.srs,AA.ns,AA.ss,BB.ps from (select AA.vpp_id,AA.type,AA.image_id,AA.manage_ip,AA.ts,AA.rs,AA.srs,AA.ns,BB.ss from (select AA.vpp_id,AA.type,AA.image_id,AA.manage_ip,AA.ts,AA.rs,AA.srs,BB.ns from (select AA.vpp_id,AA.type,AA.image_id,AA.manage_ip,AA.ts,AA.rs,BB.srs from (select AA.vpp_id,AA.type,AA.image_id,AA.manage_ip,AA.ts,BB.rs from (select B.vpp_id,B.type,B.image_id,B.manage_ip,A.ts from (select manage_ip,sum(array_length(regexp_split_to_array(tenant_infos,'T'),1)-1) as ts from vpp  where is_deleted is null and vpp_id is not null group by manage_ip) A right join (select vpp_id,manage_ip,image_ref as image_id,gate_way_type as type from vpp where is_deleted is null and image_ref is not null) B on A.manage_ip = B.manage_ip) AA left join (select A.manage_ip,sum(B.rs) as rs from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is not null) A left join (select tenant_id,count(*) as rs from router where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip) BB on AA.manage_ip = BB.manage_ip) AA left join (select A.manage_ip,sum(B.srs) as srs from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is not null) A left join (select tenant_id,sum(array_length(regexp_split_to_array(subnets,'key'),1)-1) as srs from router where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip) BB on AA.manage_ip = BB.manage_ip) AA left join (select A.manage_ip,sum(B.ns) as ns from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is not null) A left join (select tenant_id,count(*) as ns from network where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip) BB on AA.manage_ip = BB.manage_ip) AA left join (select A.manage_ip,sum(B.ss) as ss from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is not null) A left join (select tenant_id,count(*) as ss from subnet where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip ) BB on AA.manage_ip = BB.manage_ip) AA left join (select A.manage_ip,sum(B.ps) as ps from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is not null) A left join (select tenant_id,count(*) as ps from port where is_deleted is null and (device_owner like 'compute:%' or device_owner='baremetal:none') group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip ) BB on AA.manage_ip = BB.manage_ip ) AA left join (select A.manage_ip,sum(B.fs) as fs from (select json_object_keys(tenant_infos::json) as tenant_id,manage_ip from vpp where is_deleted is null and char_length(tenant_infos)>5 and vpp_id is not null) A left join (select tenant_id,count(*) as fs from floatingip where is_deleted is null group by tenant_id) B on A.tenant_id=B.tenant_id group by manage_ip ) BB on AA.manage_ip = BB.manage_ip) AA left join (select id,name as image from nfv_image where is_deleted is null) BB on AA.image_id = BB.id )AA left join (select A.manage_ip as id,concat(A.manage_ip,' - ',B.manage_ip) as manage_ip from (select manage_ip,cluster_ip from vpp where is_deleted is null and vpp_id  is not null order by manage_ip desc) A left join (select manage_ip,cluster_ip from vpp where is_deleted is null and vpp_id  is not null  order by manage_ip asc) B on A.cluster_ip=B.cluster_ip and A.manage_ip<>B.manage_ip) BB on AA.manage_ip=BB.id;"
            COUNT_STR="select count(*) from vpp where is_deleted is null union all select count(*) from tenant where is_deleted is null and vpp_manage_ip is not null union all select count(*) from router where is_deleted is null union all select sum(array_length(regexp_split_to_array(subnets,'key'),1)-1) from router where is_deleted is null union all select count(*) from network where is_deleted is null union all select count(*) from subnet where is_deleted is null union all select count(*) from port where is_deleted is null and (device_owner like 'compute:%' or device_owner='baremetal:none') union all select count(*) from floatingip where is_deleted is null;"
            VNE_SQL_STR="select '@@@' as k_id,A.vne_id,A.type,A.image,B.manage_ip from (select vne_id,vne_type as type,(select name from nfv_image where image_ref=id) as image,manage_ip from vne where is_deleted is null ) A left join (select A.manage_ip as id,concat(A.manage_ip,' - ',B.manage_ip) as manage_ip from (select manage_ip,service_gw_ip from vne where is_deleted is null order by manage_ip desc) A left join (select manage_ip,service_gw_ip from vne where is_deleted is null  order by manage_ip asc) B on A.service_gw_ip=B.service_gw_ip and A.manage_ip<>B.manage_ip ) B on A.manage_ip=B.id;"

            psql -h $ODL_DB -U postgres -d postgres -c "$SQL_STR" > vpp.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$PHYSICAL_SQL_STR" > vpp_physical.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$USAGE_SQL_STR" > vpp_usage.dat
            psql -h $ODL_DB -U postgres -d postgres -c "$VNE_SQL_STR" 2>/dev/null > vpp_vne.dat
            psql -t -h $ODL_DB -U postgres -d postgres -c "$COUNT_STR" | xargs > vpp_count.dat
        fi
    }
    proc_draw_table(){
        DATA_FILE="vpp.dat"
        if [[ -n $FILTER ]]; then
            DATA_FILE="vpp_filter.dat"
        fi
        tb_head=$(cat $DATA_FILE | head -1)
        tb_ij=$(grep + $DATA_FILE )
        tb_i=$(grep + $DATA_FILE | sed 's/+/-/g')
        tb_ii=$(grep + $DATA_FILE | sed 's/+\|-/=/g')
        MYSQL_STR="select replace(regexp_substr(A.host,'([0-9]{1,3}e){3}[0-9]{1,3}'),'e','.') as host_ip from ( select host,aggregate_id from aggregate_hosts) A left join  (select id,name from aggregates) B on A.aggregate_id=B.id where name like 'vpp%';"
        MYSQL_PASSWD=$(fast_ssh "$NFVM_CTRL" grep connection /etc/neutron/neutron.conf  | grep -Po '(?<=openstack:).*(?=@)')
        HOST_ARR=($(mysql -h $NFVM_CTRL -P23306 -u openstack -p$MYSQL_PASSWD nova_api -N -e "$MYSQL_STR" | xargs))
        
        for (( s = 0; s < ${#HOST_ARR[*]}; s++ )); do
            ( CURRENT_HOST=${HOST_ARR[s]}
            echo "$tb_ii" > vpp_info_$CURRENT_HOST.tmp
            vpp_size=$(fast_ssh $CURRENT_HOST virsh list --all 2>/dev/null | grep -c instance)
            ping -w 1 -c 1 $CURRENT_HOST &>/dev/null
            if [[ $? -ne 0 ]]; then
                echo -e "\033[31m$CURRENT_HOST\033[0m vpp size : $vpp_size" >> vpp_info_$CURRENT_HOST.tmp
            else
                echo "$CURRENT_HOST vpp size : $vpp_size" >> vpp_info_$CURRENT_HOST.tmp
            fi
            if [[ $vpp_size -ne 0 ]]; then
                echo "$tb_i" >> vpp_info_$CURRENT_HOST.tmp
                echo "$tb_head" >> vpp_info_$CURRENT_HOST.tmp
                echo "$tb_ij" >> vpp_info_$CURRENT_HOST.tmp
                for i in $(fast_ssh $CURRENT_HOST virsh list --all 2>/dev/null | grep instance | sed 's/\s\+instance-/_/g;' | awk '{print $1}');do
                    uuid=${i#*_}
                    ins=${i%_*}               
                    ins=$(printf  "%03d" $ins 2>/dev/null)
                    test "$ins" == "000" && ins="---"
                    grep -qs $uuid $DATA_FILE
                    if [[ $? -eq 0 ]]; then
                        grep $uuid $DATA_FILE | sed "s/@@@/${ins}/g" >> vpp_info_$CURRENT_HOST.tmp
                    else
                        echo "$tb_head" | sed "s/k_id/$ins /g;
                                               s/               vpp_id               /$uuid/g;
                                               s/manage_ip\|tenant_id/         /g;
                                               s/srs/   /g;
                                               s/ts\|rs\|ns\|ss\|ps\|fs/  /g;
                                               s/cluster_role/            /g;
                                               s/image/     /g;
                                               s/type/    /g" >> vpp_info_$CURRENT_HOST.tmp
                    fi
                done
            fi
            echo "$tb_ii" >> vpp_info_$CURRENT_HOST.tmp ) &
        done

        t=0
        host_sum=${#HOST_ARR[*]}
        while true; do
            sleep 0.5
            create_size=$(grep -c "=" vpp_info_* | grep :2 -c)
            if [[ $create_size -eq $host_sum ]] || [[ $t -gt 20 ]]; then
                break
            fi
            t=$((t+1))
        done
    }

    show_result_data(){
        FILTER_STR="$FILTER"
        HL_STR="$FILTER_STR\ "

        if [[ $FILTER_STR ]]; then
            FIND_TYPE=""
            FIND_TENANTID=$(grep "$FILTER_STR$" vpp_portid_tid.dat | awk '{print $1}' | head -1)
            if [[ $FIND_TENANTID ]]; then
                FIND_TYPE="PORT ID"
            else
                FIND_TENANTID=$(grep "$FILTER_STR$" vpp_vpcid_tid.dat | awk '{print $1}' | head -1)
                if [[ $FIND_TENANTID ]]; then
                    FIND_TYPE="VPC ID"
                else
                    FIND_TENANTID=$(grep "$FILTER_STR$" vpp_fip_tid.dat | awk '{print $1}'| head -1)
                    if [[ $FIND_TENANTID ]]; then
                        FIND_TYPE="FIP"
                    else
                        FIND_TENANTID=$(grep "$FILTER_STR$" vpp_ipv6_tid.dat | awk '{print $1}'| head -1)
                        if [[ $FIND_TENANTID ]]; then
                            FIND_TYPE="IPv6"
                        fi
                    fi
                fi 
            fi
            if [[ $FIND_TYPE ]]; then
                FILTER_STR=$FIND_TENANTID
            fi
        fi

        if [[ -n "$FILTER_STR" ]]; then
            FILTER_STR="$FILTER_STR\ "
            FILTER_RS_NUM=$(grep -c "$FILTER_STR" vpp_filter.dat)
            if [[ "$FILTER_RS_NUM" -eq 0 ]]; then
                echo "No relevant information was found."
            else
                SEARCH_NUM=$(grep -c "$FILTER_STR" vpp_filter.dat)
                if [[ "$SEARCH_NUM" -eq 0 ]]; then
                    echo "No relevant information was found."
                    exit 1
                else
                    echo -e "According to the retrieval information you provided, a total of ( \033[41m $SEARCH_NUM \033[0m ) results were queried"
                    if [[ $FIND_TYPE ]]; then
                        echo -e "The original input is automatically identified as \033[41m $FIND_TYPE \033[0m and converted to tenant ID \033[41m $FILTER_STR \033[0m"
                    fi

                    SEARCH_RS=($(grep -l "$FILTER_STR" vpp_info_*.tmp ))
                    > vpp_search.tmp
                    for (( i = 0; i < ${#SEARCH_RS[*]}; i++ )); do
                        MATCH_SIZE=$(grep -hv "vpp size" "${SEARCH_RS[$i]}" | grep -c "$FILTER_STR")
                        head -5 "${SEARCH_RS[$i]}" | sed "s/vpp size : .\+/match size : $MATCH_SIZE/g" >>  vpp_search.tmp
                        grep -hv "vpp size" "${SEARCH_RS[$i]}" | grep -F "$(echo $FILTER_STR | xargs)" >>  vpp_search.tmp   
                        if [[ $i -le ${#SEARCH_RS[*]} ]]; then
                            tail -1 "${SEARCH_RS[$i]}" >> vpp_search.tmp
                        fi
                    done
                    >  vpp_search.dat
                    declare -A MNGIP2ROLE
                    while read LINE; do
                        VPP_IP=$(echo "$LINE" | awk -F\| '{print $6}' | awk -F\- '{print $1}' | xargs)
                        VPPID=$(echo "$LINE" | awk -F\| '{print $2}' | xargs)
                        echo "$VPP_IP" | grep -Pq "(\d{1,3}\.){3}\d{1,3}"
                        if [[ $? -eq 0 ]] ; then
                            TENANT_ID=$(echo "$LINE" | awk -F\| '{print $3}' | xargs)
                            if [[ -z "${MNGIP2ROLE[$VPP_IP]}" ]] && [[ "$TENANT_ID" ]] ; then
                                if [[ "$VPPID" ]]; then
                                    EXT_ARGS="$ODL_CTRL sshpass -pfd10_VNF ssh -o StrictHostKeyChecking=no"
                                else
                                    EXT_ARGS=""
                                fi
                                MNGIP2ROLE["$VPP_IP"]=$(fast_ssh $EXT_ARGS $VPP_IP vppctl sh vrrp  2>/dev/null  |  grep "State Machine" | awk '{print $NF}' | sed 's/\r//g')
                            fi
                            MATCH_RS=$(echo "$LINE" | sed "s/$HL_STR/\\\033[31m$HL_STR\\\033[0m/g;s/%%%/${MNGIP2ROLE[$VPP_IP]}/g")
                            echo -e "$MATCH_RS" >>  vpp_search.dat
                        else
                            echo -e "$LINE" >>  vpp_search.dat
                        fi
                    done < vpp_search.tmp


                    grep -q "$FILTER_STR" vpp_phygw.dat
                    if [[ $? -eq 0 ]]; then
                        echo "$tb_ii"
                        head -1 vpp_phygw.dat 
                        echo "$tb_i"
                        grep "$FILTER_STR" vpp_phygw.dat > vpp_phygw_search.tmp
                        declare -A MNGIP2ROLE
                        declare -A MNGIP2PATH
                        while read LINE; do
                            VPP_IP=$(echo "$LINE" | awk -F\| '{print $4}' | xargs)
                            if [[ -z "${MNGIP2ROLE[$VPP_IP]}" ]]; then
                                MNGIP2ROLE["$VPP_IP"]=$(fast_ssh $VPP_IP vppctl sh vrrp  2>/dev/null  |  grep "State Machine" | awk '{print $NF}' | sed 's/\r//g')
                            fi
                            if [[ -z "${MNGIP2PATH[$VPP_IP]}" ]]; then
                                MNGIP2PATH["$VPP_IP"]=$(fast_ssh $VPP_IP vppctl sh version verbose 2>/dev/null | grep "Compile location" | awk '{print $NF}' | sed 's/\r//g')
                            fi
                            printf " $LINE\n" | sed "s/@@@@@@/${MNGIP2ROLE[$VPP_IP]}/g" | sed "s#GGG#${MNGIP2PATH[$VPP_IP]}#g"
                        done < vpp_phygw_search.tmp
                        echo "$tb_i"
                        echo
                    fi
                    
                    display_info(){
                        FILE="$1"
                        MATCH_ENTITY_NUM=$(grep "$FILTER_STR" "$FILE" | wc -l)
                        if [[ "$MATCH_ENTITY_NUM" -gt 0 ]]; then
                            echo -e "\nEntity number $MATCH_ENTITY_NUM , $FILE" | sed 's/\.dat/ info:/g' >>  vpp_search.dat
                            echo "$tb_ii" >>  vpp_search.dat
                            head -1 "$FILE" | awk -F \|  '{for (i=2;i<=NF;i++){if (i!=NF){printf("%s |", $i)}else{printf("%s", $i)}} print ""}' >>  vpp_search.dat
                            echo "$tb_i" >>  vpp_search.dat
                            FILTER_MATCH_RS=$(grep "$FILTER_STR" "$FILE" | sed "s/$HL_STR/\\\033[31m$HL_STR\\\033[0m/g" | awk -F \|  '{for (i=2;i<=NF;i++){if (i!=NF){printf("%s |", $i)}else{printf("%s", $i)}} print ""}')
                            echo -e "$FILTER_MATCH_RS" >>  vpp_search.dat
                            echo "$tb_i" >>  vpp_search.dat
                        fi
                    }
                    display_info vpp_tenant.dat
                    display_info vpp_router.dat
                    display_info vpp_subnet_in_router.dat
                    display_info vpp_network.dat
                    display_info vpp_subnet.dat
                    display_info vpp_port.dat
                    display_info vpp_fip.dat
                    cat  vpp_search.dat | more -20

                fi
            fi
        else

            cat vpp_info_*.tmp > vpp_server_info.dat

            TABLE_NUM=$(run_odl_sql "select count(*) from pg_class where relname = '@@@';" "vne" )
            
            echo "$tb_ii"
            awk -v host_sum=$host_sum '{
                printf "%-24s %-24s %-24s %-24s %-24s\n","host_sum:"host_sum,"vpp_sum:"$1,"tenant_sum:"$2,"router_sum:"$3,"subnet_in_router_sum:"$4
                printf "%-24s %-24s %-24s %-24s\n","network_sum:"$5,"subnet_sum:"$6,"port_sum:"$7,"fip_sum:"$8
            }' vpp_count.dat
            echo "$tb_ii"
            grep "|\|-" vpp_usage.dat  | sed "s/.\+--.\+/$tb_i/g"
            echo "$tb_ii"
            echo 
            echo "The following is the VPP and host information:"
            PHYSICAL_DATA_NUM=$(($(cat vpp_physical.dat | grep -c \|)-1))
            if [[ $PHYSICAL_DATA_NUM -gt 0 ]]; then
                echo "$tb_ii"
                head -1 vpp_physical.dat
                echo "${tb_ii//=/-}" 
                grep "@@@" vpp_physical.dat > vpp_physical.tmp
                COUNT=0
                while read LINE;do
                    COUNT=$[COUNT+1]
                    MNGIP=$(echo "$LINE" | awk -F\| '{print $2}' | awk -F\- '{print $1}' | xargs)
                    echo "$MNGIP" | grep -Pq "(\d{1,3}\.){3}\d{1,3}"

                    if [[ $? -eq 0 ]] ; then
                        if nc -w 0.2 -z $MNGIP $SERVER_SSH_PORT &>/dev/null ; then
                            EXT_ARGS=""
                            ping -w 1 -c 1 $MNGIP &> /dev/null
                        else
                            EXT_ARGS="$ODL_CTRL sshpass -pfd10_VNF ssh -o StrictHostKeyChecking=no"
                            fast_ssh $ODL_CTRL ping -w 1 -c 1 $MNGIP &> /dev/null
                        fi
                        if [[ $? -eq 0 ]]; then
                            VERSION_PATH=$(fast_ssh $EXT_ARGS $MNGIP vppctl sh version verbose 2>/dev/null | grep "Compile location" | awk '{print $NF}' | sed 's/\r//g')
                        fi
                        printf " ${LINE/@@@/$VERSION_PATH/}\n"
                        if [[ $[COUNT%2] -eq 0 ]] && [[ $PHYSICAL_DATA_NUM -ne $COUNT ]]; then
                            echo "${tb_ii//=/-}"
                        fi
                    fi
                done < vpp_physical.tmp
                echo "$tb_ii"
                echo 
            fi
            cat vpp_server_info.dat | more -20

        fi
    }

    main(){

        check_db_table

        pull_db_data

        proc_draw_table

        show_result_data

    }
    FILTER="$ARG_TYPE"
    main
}

remote_enter_list(){
    if [[ ! -e $DEPLOY_PATH ]]; then
        echo -e "\033[5;41mThe deployment file($DEPLOY_PATH) does not exist...\033[0m\a"
        exit 1
    else
        cat $DEPLOY_PATH | grep "^\[\|^[0-9]" | sed 's/\[/\n\[/g;s/\r//g' > /tmp/openstack-ansible-host.tmp
    fi
    MENUS=($(cat /tmp/openstack-ansible-host.tmp | grep -Po "[a-z:_\-]+(?=])" | grep -v "all\|:"  | sort -u | awk '{print length($1),$1}'| sort -nk 1 | awk '{print $2}'))
    MENUS_MAX=${#MENUS[*]}
    COUNT=1
    echo ${HR}
    echo "[ deploy hosts list ]  ( $DEPLOY_PATH )"
    echo ${HR//=/-}
    for MENU in ${MENUS[*]};do
        printf "     %-2d  %s\n" "$COUNT" "$MENU"
        COUNT=$[COUNT+1]
    done
    echo $HR
    while true; do
        read -p "Please enter a number to login? " NUMBER_ID
        
        echo "$NUMBER_ID" | grep -qPo "[0-9]+"
        IS_NUM=$?
        if [[ $IS_NUM -eq 0 ]]; then
            if [[ $NUMBER_ID -lt 1 ]] || [[ $NUMBER_ID -gt $MENUS_MAX ]]; then
                echo "The input number does not exist..."
            else
                RS_STR=${MENUS[$[NUMBER_ID-1]]}
                break
            fi
        else
            echo "Please enter a valid number..."
        fi
    done
    cat /tmp/openstack-ansible-host.tmp | sed -n "/\[$RS_STR\]/,/^$/p;" | grep -P "([0-9]{1,3}\.){3}[0-9]{1,3}" > vpp_enter_list.tmp
    echo "$HR"
    echo "[ $RS_STR ]"
    echo "${HR//=/-}"
    cat -n vpp_enter_list.tmp | more -10 
    echo "$HR"

    MATCH_MAX=$(cat vpp_enter_list.tmp | wc -l)
    if [[ $MATCH_MAX -eq 1 ]]; then

        MNG_IP=$(head -1 vpp_enter_list.tmp | awk '{print $1}' | sed 's/\r\|#//g' | xargs)
        ping -w 1 -c 1 $MNG_IP &>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "Login to $RS_STR($MNG_IP) successfully..."
            fast_login $MNG_IP 2>/dev/null
        else
            echo -e "\033[5;41mThe $RS_STR($MNG_IP) address is not reachable.\033[0m\a"
            exit 1
        fi
        
    else

        while true ; do
            read -p "Please enter a number to login? " NUMBER_ID
            echo "$NUMBER_ID" | grep -qPo "[0-9]+"
            IS_NUM=$?
            if [[ $IS_NUM -eq 0 ]]; then
                if [[ $NUMBER_ID -lt 1 ]] || [[ $NUMBER_ID -gt $MATCH_MAX ]]; then
                    echo "The input number does not exist..."
                else
                    MNG_IP=$(head -$NUMBER_ID vpp_enter_list.tmp | tail -1 | awk '{print $1}' | sed 's/\r\|#//g' | xargs ) 
                    break
                fi
            else
                echo "Please enter a valid number..."
            fi
        done

        ping -w 1 -c 1 $MNG_IP &>/dev/null
        if [[ $? -eq 0 ]]; then
            echo $HR
            echo "Login to $RS_STR($MNG_IP) successfully..."
            fast_login $MNG_IP 2>/dev/null
        else
            echo -e "\033[5;41mThe $RS_STR($MNG_IP) address is not reachable.\033[0m\a"
            exit 1
        fi
    fi
}

get_securitygroup_by_port_id(){
    PORT_ID=$ARG_TYPE
    STR_NUM=$(echo -n "$PORT_ID" | wc -c)
    if [[ $STR_NUM -eq 32 ]]; then
        echo -n "$PORT_ID" | grep -qP '^[0-9a-z]{32}$'
        if [[ $? -eq 0 ]]; then
            PORT_ID=$(python -c "import uuid;print uuid.UUID('$PORT_ID')")
        fi        
    fi
    
    SQL_SG_STR="select * from(select distinct B.name,B.ver,case when B.remote_cidr is null then A.remote_cidr else B.remote_cidr end,B.port_range,B.type,B.direction,A.device from (select distinct AA.remote_security_group,BB.remote_cidr,BB.device from (select remote_security_group from securityrule where is_deleted is null and remote_security_group<>'') AA inner join (select json_object_keys(security_groups::json) as security_groups,concat(fix_ips::json->json_object_keys(fix_ips::json)->>'ip','/32') as remote_cidr,device  from port where is_deleted is null and security_groups is not null and security_groups<>'' and device <>'') BB on AA.remote_security_group=BB.security_groups) A right join (select B.name,A.ether_type as ver,A.remote_security_group,case when A.remote_cidr is null and remote_security_group is null then '0.0.0.0/0' else remote_cidr end,A.port_range,A.ip_protocol as type,A.direction from (select group_id,ether_type,remote_security_group,remote_cidr, case when port_min<>'' then concat(port_min,'-',port_max) else '1-65535' end as port_range,case when ip_protocol<>'' then ip_protocol else 'all' end as ip_protocol,direction from securityrule where  is_deleted is null and group_id in (select id from securitygroup where id in (select json_object_keys(security_groups::json) from port where id='@@@'))) A left join (select id,name from securitygroup where is_deleted is null) B on A.group_id=B.id) B on A.remote_security_group=B.remote_security_group)A where ver='IPv4' and family(remote_cidr::inet)='4';"
    SQL_SG_STR=$(echo "$SQL_SG_STR" | sed "s#@@@#$PORT_ID#g")
    psql -h $ODL_DB -U postgres -d postgres -c "$SQL_SG_STR"

    SQL_SG_STR="select * from(select distinct B.name,B.ver,case when B.remote_cidr is null then A.remote_cidr else B.remote_cidr end,B.port_range,B.type,B.direction,A.device from (select distinct AA.remote_security_group,BB.remote_cidr,BB.device from (select remote_security_group from securityrule where is_deleted is null and remote_security_group<>'') AA inner join (select json_object_keys(security_groups::json) as security_groups,concat(fix_ips::json->json_object_keys(fix_ips::json)->>'ip','/32') as remote_cidr,device  from port where is_deleted is null and security_groups is not null and security_groups<>'' and device <>'') BB on AA.remote_security_group=BB.security_groups) A right join (select B.name,A.ether_type as ver,A.remote_security_group,case when A.remote_cidr is null and remote_security_group is null then '::/0' else remote_cidr end,A.port_range,A.ip_protocol as type,A.direction from (select group_id,ether_type,remote_security_group,remote_cidr, case when port_min<>'' then concat(port_min,'-',port_max) else '1-65535' end as port_range,case when ip_protocol<>'' then ip_protocol else 'all' end as ip_protocol,direction from securityrule where  is_deleted is null and group_id in (select id from securitygroup where id in (select json_object_keys(security_groups::json) from port where id='@@@'))) A left join (select id,name from securitygroup where is_deleted is null) B on A.group_id=B.id) B on A.remote_security_group=B.remote_security_group)A where ver='IPv6' and family(remote_cidr::inet)='6';"

    SQL_SG_STR=$(echo "$SQL_SG_STR" | sed "s#@@@#$PORT_ID#g")
    psql -h $ODL_DB -U postgres -d postgres -c "$SQL_SG_STR"

}


remote_batch_deploy(){
    cd - &>/dev/null

    VER_PATH=$(realpath $ARG_TYPE)
    DEPLOY_HOST=$(realpath $ARG_VAL)
    OPT_TYPE=$ARG_EXT

    if [[ -z $VER_PATH ]] || [[ -z $DEPLOY_HOST ]]; then
        print_prompt "error arguments"
    else
        if [[ ! -d $VER_PATH ]] || [[ ! -e $DEPLOY_HOST ]]; then
            print_prompt "The deploy_path or deploy_host is not exist."
        fi
    fi
    DEPLOY_DIR=$(basename $VER_PATH)

    MYSQL_STR="select replace(regexp_substr(A.host,'([0-9]{1,3}e){3}[0-9]{1,3}'),'e','.') as host_ip from ( select host,aggregate_id from aggregate_hosts) A left join  (select id,name from aggregates) B on A.aggregate_id=B.id where name like 'vpp-virtio%' limit 1;"
    MYSQL_PASSWD=$(fast_ssh $NFVM_CTRL grep connection /etc/neutron/neutron.conf  | grep -Po '(?<=openstack:).*(?=@)')
    HOST_ARR=($(mysql -h $NFVM_CTRL -P23306 -u openstack -p$MYSQL_PASSWD nova_api -N -e "$MYSQL_STR" | xargs))
    
    if [[ -z $HOST_ARR ]]; then
        if [[ -z "$INT_IFNAME" ]] || [[ -z "$EXT_IFNAME" ]]; then
            print_prompt "Failed to get card name automatically, please open the smart_scan manually(INT_IFNAME/EXT_IFNAME)..."
        fi
    else
        PHYSICAL_INTERFACE_MAPPINGS=$(fast_ssh $HOST_ARR grep physical_interface_mappings /etc/neutron/plugins/ml2/linuxbridge_agent.ini | awk -F= '{print $NF}' | xargs)
        INT_IFNAME=$(echo $PHYSICAL_INTERFACE_MAPPINGS | awk -F, '{print $2}' | awk -F: '{print $NF}')
        EXT_IFNAME=$(echo $PHYSICAL_INTERFACE_MAPPINGS | awk -F, '{print $3}' | awk -F: '{print $NF}')
    fi

    INT_BOND=${INT_IFNAME%.*}
    INT_VLAN=${INT_IFNAME#*.}

    EXT_BOND=${EXT_IFNAME%.*}
    EXT_VLAN=${EXT_IFNAME#*.}

    sed -i "s/INT_BOND=.*/INT_BOND=${INT_BOND}/g" "${VER_PATH}/init_vpp_conf.sh"
    sed -i "s/INT_VLAN=.*/INT_VLAN=${INT_VLAN}/g" "${VER_PATH}/init_vpp_conf.sh"
    sed -i "s/EXT_BOND=.*/EXT_BOND=${EXT_BOND}/g" "${VER_PATH}/init_vpp_conf.sh"
    sed -i "s/EXT_VLAN=.*/EXT_VLAN=${EXT_VLAN}/g" "${VER_PATH}/init_vpp_conf.sh"

    cp -f $DEPLOY_HOST ${DEPLOY_HOST}.tmp
    
    cat ${DEPLOY_HOST}.tmp

    sed -i '/^$/d;/^#/d' $DEPLOY_HOST

    case $OPT_TYPE in
        get_lldp )
            while read LINE;do
                GW_IP=$(echo "$LINE" | awk '{print $1}' | xargs)
                GW_TYPE=$(echo "$LINE" | awk '{print $2}' | xargs)
                nc -zv $GW_IP $SERVER_SSH_PORT &>/dev/null
                if [[ $? -eq 0 ]]; then
                    IS_MNG=$(run_odl_sql "select id from vpp where manage_ip='@@@' and is_deleted is null;" $GW_IP)
                    if [[ -z "$IS_MNG" ]]; then
                        echo $HR 
                        echo -e "GW_IP: \033[31m$GW_IP\033[0m       GW_TYPE: \033[31m$GW_TYPE\033[0m" 
                        echo $HR 
                        run_get_lldp $GW_IP 
                        echo $HR
                    fi
                else
                    echo "The address $GW_IP is not reachable..."
                    continue
                fi
            done < $DEPLOY_HOST
            ;;
        set_hugesize )
    while read LINE;do
        GW_IP=$(echo "$LINE" | awk '{print $1}' | xargs)
        nc -zv $GW_IP $SERVER_SSH_PORT &>/dev/null
        if [[ $? -ne 0 ]]; then
            echo -e "\033[41mThe address $GW_IP is not reachable\033[0m"
            continue
        fi
        
        CUR_HUGESIZE=$(fast_ssh $GW_IP cat /proc/meminfo  | grep Hugepagesize | awk '{print $2}')
        if [[ $CUR_HUGESIZE -ne 1048576 ]];then
            ssh -n -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p${SERVER_SSH_PORT} $GW_IP : &>/dev/null
            if [[ $? -eq 255 ]]; then
                ssh -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} secure@$GW_IP sudo -su root <<\EOF
                    if ! grep -q 3.10.0-957.el7.x86_64 /proc/cmdline ; then
                        grub2-set-default 'CentOS Linux (3.10.0-957.el7.x86_64) 7 (Core)'
                    fi
                    GRUB_CMDLINE_LINUX_VALUE=$(grep GRUB_CMDLINE_LINUX /etc/default/grub | grep -o '".*"' | xargs )
                    if ! grep -q default_hugepagesz /etc/default/grub; then
                        GRUB_CMDLINE_LINUX_VALUE="$GRUB_CMDLINE_LINUX_VALUE default_hugepagesz=1G hugepagesz=1G hugepages=16"
                        sed -i "s@GRUB_CMDLINE_LINUX=.*@GRUB_CMDLINE_LINUX=\"$GRUB_CMDLINE_LINUX_VALUE\"@g" /etc/default/grub
                        cat /etc/default/grub
                        if [[ -d /sys/firmware/efi ]]; then
                            grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
                        else
                            grub2-mkconfig -o /boot/grub2/grub.cfg
                        fi
                    fi
EOF
                GW_HGSZ=$(ssh -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} secure@$GW_IP sudo grep Hugepagesize  /proc/meminfo | awk '{print $2}')
                ssh -n -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} secure@$GW_IP sudo grep -q hugepagesz=1G /etc/default/grub
            else
                ssh -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $GW_IP <<\EOF
                    if ! grep -q 3.10.0-957.el7.x86_64 /proc/cmdline ; then
                        grub2-set-default 'CentOS Linux (3.10.0-957.el7.x86_64) 7 (Core)'
                    fi
                    GRUB_CMDLINE_LINUX_VALUE=$(grep GRUB_CMDLINE_LINUX /etc/default/grub | grep -o '".*"' | xargs )
                    if ! grep -q default_hugepagesz /etc/default/grub; then
                        GRUB_CMDLINE_LINUX_VALUE="$GRUB_CMDLINE_LINUX_VALUE default_hugepagesz=1G hugepagesz=1G hugepages=16"
                        sed -i "s@GRUB_CMDLINE_LINUX=.*@GRUB_CMDLINE_LINUX=\"$GRUB_CMDLINE_LINUX_VALUE\"@g" /etc/default/grub
                        cat /etc/default/grub
                        if [[ -d /sys/firmware/efi ]]; then
                            grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
                        else
                            grub2-mkconfig -o /boot/grub2/grub.cfg
                        fi
                    fi
EOF
                GW_HGSZ=$(ssh -n -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $GW_IP grep Hugepagesize  /proc/meminfo | awk '{print $2}')
                ssh -n -o StrictHostKeyChecking=no -p${SERVER_SSH_PORT} $GW_IP grep -q hugepagesz=1G /etc/default/grub
            fi
            IS_SET_HUGE=$?
            if [[ $GW_HGSZ -ne 1048576 ]]; then
                if [[ $IS_SET_HUGE -eq 0 ]]; then
                    fast_ssh $GW_IP reboot
                fi
            fi
        fi
    done < $DEPLOY_HOST

    sleep 5
    
    I=0
    HOST_NUM=$(cat $DEPLOY_HOST | wc -l )
    (while [[ $(cat $DEPLOY_HOST | wc -l ) -ne 0 ]]; do
        GW_IP=$(cat $DEPLOY_HOST | sed -n "$[I+1]p" | awk '{print $1}')
        NOW_L=$(cat $DEPLOY_HOST | wc -l )
        ping -w 1 -c 1 $GW_IP &>/dev/null
        if [[ $? -eq 0 ]]; then
            HOST_UP_NUM=$[HOST_UP_NUM+1]
            sed -i "/$GW_IP/d" $DEPLOY_HOST
        else
            if [[ $I -lt  $[NOW_L-1] ]]; then
                I=$[I+1]
            fi
        fi
    done) &
    watch "cat -n $DEPLOY_HOST" 
            ;;
        auto_install )
            while read LINE;do
                GW_IP=$(echo "$LINE" | awk '{print $1}' | xargs)
                GW_TYPE=$(echo "$LINE" | awk '{print $2}' | xargs)

                nc -zv $GW_IP $SERVER_SSH_PORT &>/dev/null
                if [[ $? -eq 0 ]]; then

                    fast_ssh $GW_IP rpm -q pciutils &> /dev/null
                    if [[ $? -ne 0 ]]; then
                        fast_ssh $GW_IP yum install -y pciutils
                    fi
                    fast_ssh $GW_IP lspci | grep Eth | grep -q Mellanox
                    HAS_MLX_NIC=$?
                    fast_ssh $GW_IP systemctl -l | grep -q openibd
                    INSTALL_MLX_DRV=$?
                    if [[ $HAS_MLX_NIC -eq 0 ]] && [[ $INSTALL_MLX_DRV -ne 0 ]] ; then
                        if [[ ! -e ${DEPLOY_PATH}/MLNX_OFED_LINUX-5.0-2.1.8.0-rhel7.6-x86_64.tgz ]]; then
                            print_prompt "Mellanox is missing driver file mlnx_ofed_linux-5.0-2.1.8.0-rhel7.6-x86_64.tgz"
                        fi
                    fi

                    fast_ssh $GW_IP ls /home/secure/$DEPLOY_DIR &>/dev/null
                    if [[ $? -eq 0 ]]; then
                        fast_ssh $GW_IP rm -rf /home/secure/$DEPLOY_DIR
                    fi

                    ssh -n -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p${SERVER_SSH_PORT} $GW_IP : &>/dev/null
                    if [[ $? -eq 255 ]]; then
                        scp -rP ${SERVER_SSH_PORT}  $VER_PATH secure@$GW_IP:/home/secure
                    else
                        scp -rP ${SERVER_SSH_PORT}  $VER_PATH $GW_IP:/home/secure
                    fi
                    echo -e "\033[42;30mCopy completed, $VER_PATH to specified server ($GW_IP)...\033[0m"
                    echo 
                    if [[ $GW_TYPE == "tgw" ]]; then
                        fast_ssh_bg $GW_IP /home/secure/$DEPLOY_DIR/install_all.sh
                    elif [[ $GW_TYPE == "vgw" ]]; then
                        fast_ssh $GW_IP sed -i "/haproxy_api/d" /home/secure/$DEPLOY_DIR/install_all.sh
                        fast_ssh_bg $GW_IP /home/secure/$DEPLOY_DIR/install_all.sh vgw
                    elif [[ $GW_TYPE == "igw" ]]; then
                        STORAGE_VLAN=$(echo "$LINE" | awk '{print $3}' | xargs)
                        STORAGE_CIDR=$(echo "$LINE" | awk '{print $4}' | xargs)

                        fast_ssh $GW_IP sed -i "s/EXT_VLAN=.*/EXT_VLAN=${STORAGE_VLAN}/g" /home/secure/$DEPLOY_DIR/init_vpp_conf.sh
                        fast_ssh $GW_IP sed -i "s@EXT_CIDR=.*@EXT_CIDR=${STORAGE_CIDR}@g" /home/secure/$DEPLOY_DIR/init_vpp_conf.sh
                        fast_ssh $GW_IP sed -i "/haproxy_api/d" /home/secure/$DEPLOY_DIR/install_all.sh
        
                        fast_ssh_bg $GW_IP /home/secure/$DEPLOY_DIR/install_all.sh igw

                    fi
                else
                      echo -e "\033[41mThe address $GW_IP is not reachable\033[0m"
                fi
            done < $DEPLOY_HOST
            watch "ps -ef | grep install_all.s[h]"
            ;;
        get_info )
            while read LINE;do
                GW_IP=$(echo "$LINE" | awk '{print $1}' | xargs)
                GW_TYPE=$(echo "$LINE" | awk '{print $2}' | xargs)
                STORAGE_VLAN=$(echo "$LINE" | awk '{print $3}' | xargs)
                STORAGE_CIDR=$(echo "$LINE" | awk '{print $4}' | xargs)
                while true; do
                    nc -zv $GW_IP $SERVER_SSH_PORT &>/dev/null
                    if [[ $? -eq 0 ]]; then
                        display_vpp_info(){
                            if [[ $INT_BOND == "bond1" ]]; then
                                INT_MAC=$(fast_ssh $GW_IP vppctl sh h BondEthernet0  | tail -1 | awk '{print $NF}' | sed 's/\r//g')
                                INT_IF="BondEthernet0.${INT_VLAN}"
                            fi
                            INT_ADDR=$(fast_ssh $GW_IP grep 'address' /etc/vpp/init.cfg | awk '{print $NF}' | awk -F/ '{print $1}')
                            if [[ $GW_TYPE != "vgw" ]]; then
                                if [[ "$STORAGE_CIDR" ]]; then
                                    EXT_VLAN=$STORAGE_VLAN
                                fi
                                if [[ $EXT_BOND == "bond1" ]]; then
                                    EXT_MAC=$INT_MAC
                                    EXT_IF="BondEthernet0.${EXT_VLAN}"
                                else
                                    EXT_MAC=$(fast_ssh $GW_IP vppctl sh h BondEthernet1  | tail -1 | awk '{print $NF}' | sed 's/\r//g')
                                    EXT_IF="BondEthernet1.${EXT_VLAN}"
                                fi
                                if [[ "$STORAGE_CIDR" ]]; then
                                    echo "GW_TYPE: ${GW_TYPE} MNG_ADDR: ${GW_IP} INT_ADDR: ${INT_ADDR} INT_IF: ${INT_IF} INT_MAC: ${INT_MAC} EXT_IF: ${EXT_IF} EXT_MAC: ${EXT_MAC} EXT_ADDR: ${STORAGE_CIDR%/*}"
                                else
                                    echo "GW_TYPE: ${GW_TYPE} MNG_ADDR: ${GW_IP} INT_ADDR: ${INT_ADDR} INT_IF: ${INT_IF} INT_MAC: ${INT_MAC} EXT_IF: ${EXT_IF} EXT_MAC: ${EXT_MAC}"
                                fi
                            else
                                echo "GW_TYPE: ${GW_TYPE} MNG_ADDR: ${GW_IP} INT_ADDR: ${INT_ADDR} INT_IF: ${INT_IF} INT_MAC: ${INT_MAC}"
                            fi
                        }

                        echo $HR 
                        display_vpp_info 
                        echo $HR 
                        break
                    else
                        echo "The address $GW_IP is not reachable..."
                    fi
                done
                
            done < $DEPLOY_HOST
            ;;
        * )
            mv -f ${DEPLOY_HOST}.tmp ${DEPLOY_HOST}
            print_prompt "At this stage only supports get_lldp, set_hugesize, auto_install and get_info option;"
            ;;
    esac
    mv -f ${DEPLOY_HOST}.tmp ${DEPLOY_HOST}

}

check_env_reach
check_env_software
case $ARG_OPT in
    -e | --enter )
       shift 1
       remote_enter $*
       ;;
    -b | --batch )     
        shift 1
        remote_batch_exec $*
        ;;
    -d | --deploy ) 
        shift 1
        remote_batch_deploy $*
        ;;
    -f | --filter )
        proc_filter_data
        ;;
    -g | --get )
        shift 1
        get_vpp_host_info $*
        ;;
    -t | --trace | -h | --host )
        shift 1
        capture_packet_or_exec $*
        ;;
    -c | --config | -v | --vpp )
        shift 1
        remote_exec_cmd $*
        ;;
    -l | --login )
        shift 1
        remote_login $*
        ;;
    -sg | --securitygroup)
        shift 1
        get_securitygroup_by_port_id $*
        ;;
    -cd | --coredump )
        shift 1
        check_vpp_coredump $*
        ;;
    -el | --enter-list )
       shift 1
       remote_enter_list $*
       ;;
    -V | --version)
        stat $(realpath $0) | grep Change
        ;;
    --help | * )
        usage
        ;;
esac
rm -rf $TEMP_DIR
