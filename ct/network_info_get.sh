source /root/admin-openrc.sh

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'

NC='\e[0m'

function init()
{
    PID=""
    FIXEDIP=""
    MAC=""
    DEVICE_OWNER=""
    DEVICE_ID=""
    BINDING_HOST=""
    FIP=""
    VMID=""
    ROUTERID=""
    GWPORTID=""
    GWIP=""
    GWMAC=""
    SNATPORTID=""
    SNATIP=""
    SNATMAC=""
    SNAT_BINDING_HOST=""
}

function pnerror()
{
    echo -e "${RED}Error: $@ ${NC}"
}


function check_str_null()
{
        if [ "$2" == "" ];then
              pnerror "$1"
        fi
}


function help_usage()
{
     echo ""
     echo "help usage:"
     echo ""
     echo -e "\t-v:         vm id"
     echo -e "\t-p:         port id"
     echo -e "\t-f:         floatingip address"
     echo -e "\t-h:         help info"

     exit 1
}

while getopts "v:p:f:h" arg
do
        case $arg in
             f)
                FLOATINGIP=$OPTARG
                ;;
             v)
                VID=$OPTARG
                ;;
             p)
                PORTID=$OPTARG
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
    if [ "$FLOATINGIP" == "" -a "$VID" == "" -a "$PORTID" == "" ];then
        perror "must special valid port id, vm id or floatingip address"
    fi
}

function check_config()
{
    local resource_infos=$1
    local var=$(declare -p "$2")
    local result=""
    local header=""
    local header_line=0

    eval "declare -A local resource_map"=${var#*=}


    #line_num=$(cat "$resource_infos" | wc -l)
    line_num=$(echo "$resource_infos" | wc -l)
    for ((i=1; i<=$line_num; i++))
    do
        if [[ $i == 1 || $i == 3 || $i == $line_num ]];then
            continue
        fi
        action=$(echo $i"p")
        #line=$(cat "$resource_infos" | sed -n $action)
        line=$(echo "$resource_infos" | sed -n $action)
        key=$(echo $line | sed -e "s/\ //g" | cut -d"|" -f2)
        value=$(echo $line | sed -e "s/\ //g" -e "s/None//g" | cut -d"|" -f3)
        if [ "X$key" == "X" ];then
           continue
        fi
        item=${resource_map[${key}]}
        if [ "X$item" == "X" ];then
           continue
        fi
        except_value=$(echo "$item"| cut -d"," -f1)
        color=$(echo "$item"| cut -d"," -f2)
        len=$(echo "$item"| cut -d"," -f3)

        f_value=$(printf "%-${len}s" $value|sed "s/\ /*/g")
        f_key=$(printf "%-${len}s" $key|sed "s/\ /*/g")
        header_line=$(expr $header_line + 1)
        header_line=$(expr $header_line + $len)
        new_len=$(expr $len + 13)
        
        if [ "$except_value" == "!null" ];then
            if [ "X$value" == "X" ];then
                if [ "$color" == "error" ];then
                    f_value=$(printf "%-${new_len}s" "${RED}& Error${NC}"|sed "s/\ /*/g")
                elif [ "$color" == "warn" ];then
                    f_value=$(printf "%-${new_len}s" "${YELLOW}& Warn${NC}" |sed "s/\ /*/g")
                fi
            fi
        elif [ "$except_value" != "$value" ];then
            if [ "$color" == "error" ];then
                f_value=$(printf "%-${new_len}s" "${RED}& $value${NC}"|sed "s/\ /*/g")
            elif [ "$color" == "warn" ];then
                f_value=$(printf "%-${new_len}s" "${YELLOW}& $value${NC}"|sed "s/\ /*/g")
            fi
        fi
        info[$key]=$value
        result=${result}"| ${f_value}" 
        header=${header}"+ ${f_key}" 
    done

    printf "%-${header_line}s\n" "="|sed "s/\ /=/g"
    echo -e "${header}"|sed "s/\*/\ /g"
    printf "%-${header_line}s\n" "-"|sed "s/\ /-/g"
    echo -e "${result}"|sed "s/\*/\ /g"
    printf "%-${header_line}s\n" "-"|sed "s/\ /-/g"
}

declare -A port_map=()


function port_info(){
    declare -A port1_visibility=(
        ["admin_state_up"]="UP,error,15"
        ["binding_host_id"]="!null,warn,38"
        ["device_id"]="!null,warn,38"
        ["device_owner"]="!null,error,15"
        ["fixed_ips"]="!null,error,85"
    )
    
    declare -A port2_visibility=(
        ["id"]="!null,error,38"
        ["mac_address"]="!null,error,20"
        ["network_id"]="!null,error,38"
        ["project_id"]="!null,error,35"
        ["security_group_ids"]="!null,warn,38"
        ["status"]="ACTIVE,error,15"
    )

    portid=$1

    local ports=$(openstack port show $portid)

    echo -e "${GREEN}port $portid:${NC}"
    check_config "${ports}"  port1_visibility
    check_config "${ports}"  port2_visibility
    echo -e "\n"

    for key in ${!info[@]}
    do
        port[$key]=${info[${key}]}
        if [ "$key" == "fixed_ips" ];then
            ip=$(echo ${info[${key}]}|sed "s/.*ip_address='\(.*\)',subnet_id.*/\1/g")
            subnet_id=$(echo ${info[${key}]}|sed "s/.*subnet_id='\(.*\)'.*/\1/g")
            port["ip_address"]=${ip}
            port["subnet_id"]=${subnet_id}
        fi
    done
    info=()
}

function subnet_info(){
    declare -A subnet1_visibility=(
        ["cidr"]="!null,error,20"
        ["dns_nameservers"]="!null,warn,38"
        ["enable_dhcp"]="True,warn,15"
        ["gateway_ip"]="!null,error,15"
        ["host_routes"]="!null,warn,55"
    )
    
    declare -A subnet2_visibility=(
        ["id"]="!null,error,38"
        ["network_id"]="!null,error,38"
        ["project_id"]="!null,error,35"
        ["service_types"]="null,warn,20"
        ["status"]="ACTIVE,error,15"
    )

    subnetid=$1

    local subnets=$(openstack subnet show $subnetid)

    echo -e "${GREEN}subnet: $subnetid${NC}"
    check_config "${subnets}"  subnet1_visibility
    check_config "${subnets}"  subnet2_visibility
    echo -e "\n"
}

function network_info(){
    declare -A net1_visibility=(
        ["admin_state_up"]="UP,error,15"
        ["availability_zones"]="!null,error,20"
        ["id"]="!null,error,38"
        ["mtu"]="!null,error,15"
        ["port_security_enabled"]="True,warn,25"
        ["provider:network_type"]="!null,error,40"
    )
    
    declare -A net2_visibility=(
        ["provider:segmentation_id"]="!null,error,30"
        ["router:external"]="Internal,error,20"
        ["shared"]="False,warn,15"
        ["status"]="ACTIVE,error,15"
        ["subnets"]="!null,warn,50"
    )

    networkid=$1

    local nets=$(openstack network show $networkid)

    echo -e "${GREEN}networkid: $networkid${NC}"
    check_config "${nets}"  net1_visibility
    check_config "${nets}"  net2_visibility
    echo -e "\n"
}

function dhcp_agent_info(){
    declare -A dhcp_visibility=(
        ["admin_state_up"]="UP,warn,20"
        ["agent_type"]="!null,error,20"
        ["alive"]=":-),error,10"
        ["host"]="!null,error,30"
        ["last_heartbeat_at"]="!null,error,25"
    )
    
    dhcp_agent_id=$1

    local agents=$(openstack network agent show $dhcp_agent_id)

    echo -e "${GREEN}dhcp agent: ${NC}"
    check_config "${agents}"  dhcp_visibility
    info=()
}

function dhcp_agent_infos(){
    network_id=$1
    for id in `openstack network agent list --network ${network_id} | grep neutron-dhcp-agent | cut -d"|" -f2`
    do
        dhcp_agent_info $id
    done
    echo -e "\n"
}

function router_info(){
    declare -A router_visibility=(
        ["admin_state_up"]="UP,warn,15"
        ["distributed"]="True,error,15"
        ["ha"]="True,error,15"
        ["id"]="!null,error,38"
        ["status"]="ACTIVE,error,30"
    )
    router_id=$(openstack port find router $1)
    check_str_null "subnet ${port["subnet_id"]} not binding router" ${router_id}
    if [ ${router_id} != "" ];then
       local routers=$( openstack router show $router_id) 
       echo -e "${GREEN}router $router_id: ${NC}"
       check_config "${routers}"  router_visibility
       echo -e "\n"
       for key in ${!info[@]}
       do
           router[$key]=${info[${key}]}
       done

       external_gateway_network=$(echo "${routers}" | grep -w external_gateway_info |cut -d"|" -f3)
       check_str_null "router $router_id not set external network" ${external_gateway_network}
       if [ "X$external_gateway_network" != "X" ];then
           router["external_gateway_network"]=${external_gateway_network}
           router["network_id"]=$(echo ${external_gateway_network} | sed "s/.*network_id:\(.*\),\ ena.*/\1/g")
       fi

       interfaces_info=$(echo "${routers}" | grep -w interfaces_info |cut -d"|" -f3| sed -e "s/\"//g" -e "s/\ //g" -e "s/\]//g" -e "s/\[//g")
       check_str_null "router $router_id not set subnet" ${interfaces_info}
       if [ "X$interfaces_info" != "X" ];then
           router["interfaces_info"]=${interfaces_info}
           echo -e "${GREEN}router $router_id interfaces info:${NC}"
           printf "%-120s\n" " "|sed "s/\ /=/g"
           echo ${interfaces_info}| sed -e "s/}\,{/\n/g" -e "s/}//g" -e "s/{//g" -e "s/\,/\  /g"
           echo -e "\n"
       fi
    fi
    ROUTERID=${router_id}
}

function l3_agent_info(){
    declare -A l3_visibility=(
        ["admin_state_up"]="UP,warn,20"
        ["agent_type"]="!null,error,20"
        ["alive"]=":-),error,10"
        ["host"]="!null,error,30"
        ["last_heartbeat_at"]="!null,error,25"
    )
    
    l3_agent_id=$1

    local agents=$(openstack network agent show $l3_agent_id)

    echo -e "${GREEN}snat l3 agent: ${NC}"
    check_config "${agents}"  l3_visibility
    info=()
}
function l3_agent_infos(){
    router_id=$1
    echo -e "${GREEN}snat l3 agent ha state:${NC}"
    printf "%-40s\n" " "|sed "s/\ /=/g"
    openstack network agent list --router ${router_id}  --long | grep neutron-l3-agent | awk -F"|" '{print "|"$4"|"$9"|"}'
    printf "%-40s\n" " "|sed "s/\ /-/g"
    for id in `openstack network agent list --router ${router_id} | grep neutron-l3-agent | cut -d"|" -f2`
    do
        l3_agent_info $id
    done
    echo -e "\n"
}

function sg_rule_info(){
    local rules=$1
    line_num=$(echo "$rules" | wc -l)
    for ((i=1; i<=$line_num; i++))
    do
         declare -A local_sg=(["direction"]="" ["ethertype"]="" ["port_range_max"]="" ["port_range_min"]="" ["protocol"]="" ["remote_ip_prefix"]="" ["remote_group_id"]="")
         action=$(echo $i"p")
         rule=$(echo "$rules" | sed -n $action)
         f_rule=$(echo $rule | sed -e "s/\'//g" -e "s/\ //g" -e "s/'//g" -e "s/\,/\ /g")
         for colume in $f_rule
         do
             local key=$(echo $colume | cut -d"=" -f1)
             local value=$(echo $colume | cut -d"=" -f2)
             if [[ "$key" == "created_at" || "$key" == "id" || "$key" == "updated_at" ]];then
                 continue
             fi
             local_sg[$key]=$value
         done
         printf "%-20s%-15s%-15s%-20s%-20s%-30s%-50s\n" "direction=${local_sg['direction']}" "ethertype=${local_sg['ethertype']}" "protocol=${local_sg['protocol']}" "port_range_max=${local_sg['port_range_max']}" "port_range_min=${local_sg['port_range_min']}"  "remote_ip_prefix=${local_sg['remote_ip_prefix']}"  "remote_group_id=${local_sg['remote_group_id']}"
    done
}

function sg_infos(){
    sg_id=$1
    local rules=$(openstack security group show $sg_id -f json | python -c "import sys, json; obj=json.load(sys.stdin); print obj['rules']")
    echo -e "${GREEN}security group rules $sg_id:${NC}"
    printf "%-180s\n" " "|sed "s/\ /=/g"
    sg_rule_info "$rules"
    echo -e "\n"
}

function fip_info(){
    declare -A fip_visibility=(
        ["fixed_ip_address"]="!null,warn,25"
        ["floating_ip_address"]="!null,error,25"
        ["id"]="!null,error,38"
        ["port_id"]="!null,warn,38"
        ["router_id"]="!null,warn,38"
        ["status"]="ACTIVE,error,15"
    )

    ip=$1

    local results=$(openstack floating ip show $ip)

    echo -e "${GREEN}floatig ip: $ip${NC}"
    check_config "${results}"  fip_visibility

    for key in ${!info[@]}
    do
        fip[$key]=${info[${key}]}
    done
    info=()
    echo -e "\n"

    FIP=$ip
}

function server_info(){
    declare -A server1_visibility=(
        ["OS-EXT-AZ:availability_zone"]="!null,error,30"
        ["OS-EXT-SRV-ATTR:host "]="!null,error,35"
        ["OS-EXT-STS:power_state"]="Running,error,25"
        ["OS-EXT-STS:task_state"]=""",error,25"
        ["OS-EXT-STS:vm_state"]="active,error,25"
        ["config_drive"]="True,error,15"
    )
    
    declare -A server2_visibility=(
        ["flavor"]="!null,error,50"
        ["id"]="!null,error,38"
        ["image"]="!null,error,45"
        ["network_id"]="!null,error,38"
    )
    declare -A server3_visibility=(
        ["name"]="!null,warn,40"
        ["security_groups"]="!null,warn,70"
        ["status"]="ACTIVE,error,15"
    )

    vmid=$1

    local vms=$(openstack server show $vmid)

    echo -e "${GREEN}vm id: $vmid ${NC}"
    check_config "${vms}"  server1_visibility
    check_config "${vms}"  server2_visibility
    check_config "${vms}"  server3_visibility
    echo -e "\n"

    VMID=$vmid

}

function ports_info()
{
    #network:router_centralized_snat, network:dhcp, network:router_interface_distributed, network:router_gateway
    #network:router_ha_interface,network:ha_router_replicated_interface, network:floatingip,compute:private_line
    #compute:pass-pro,compute:pass-mgmt,compute:yidun, compute:public
    local portid=""
    local netid=$1
    for device_owner in network:router_gateway network:router_interface_distributed network:router_centralized_snat network:dhcp compute:private_line
    do
        portids=$(openstack port list --network $netid --device-owner $device_owner -c ID | sed "s/\ //g"|sed -n '/|[0-9a-z]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}|/p' | cut -d"|" -f2)
        for portid in ${portids}
        do
            echo -e "${GREEN}$device_owner port info: $portid ${NC}"
            port_info $portid
            if [ "$device_owner" == "network:router_interface_distributed" ];then
                GWPORTID=${port["id"]}
                GWIP=${port["ip_address"]}
                GWMAC=${port["mac_address"]}
            fi
            if [ "$device_owner" == "network:router_centralized_snat" ];then
                SNATPORTID=${port["id"]}
                SNATIP=${port["ip_address"]}
                SNATMAC=${port["mac_address"]}
                SNAT_BINDING_HOST=${port["binding_host_id"]}
            fi
        done
    done
}

function save_port()
{
    PID=${port["id"]}
    FIXEDIP=${port["ip_address"]}
    MAC=${port["mac_address"]}
    DEVICE_OWNER=${port["device_owner"]}
    DEVICE_ID=${port["device_id"]}
    BINDING_HOST=${port["binding_host_id"]}

}
function vpc_info()
{
    local portid=$1

    port_info "$portid"
    save_port

    if [ "X${port["subnet_id"]}" != "X" ];then
        subnet_info ${port["subnet_id"]}
    fi

    if [ "X${port["network_id"]}" != "X" ];then
        network_info ${port["network_id"]}
        dhcp_agent_infos ${port["network_id"]}
        ports_info ${port["network_id"]}
    fi

    router_info "$portid"

    if [ "X${router["id"]}" != "X" ];then
        l3_agent_infos ${router['id']}
    fi

    if [ "X${port["security_group_ids"]}" != "X" ];then
       sg_infos  ${port["security_group_ids"]}
    fi

}

function baisc_info()
{
    echo -e "${GREEN}basic info:${NC}"
    printf "%65s\n" " "|sed "s/\ /=/g"
    printf "%-15s%10s%-50s\n" "VMId" "| " "$VMID"
    printf "%-15s%10s%-50s\n" "FloatingIP" "| " "$FIP"
    printf "%-15s%10s%-50s\n" "PortId" "| " "$PID"
    printf "%-15s%10s%-50s\n" "FixedIp" "| " "$FIXEDIP"
    printf "%-15s%10s%-50s\n" "MAC" "| " "$MAC"
    printf "%-15s%10s%-50s\n" "DevOwner" "| " "$DEVICE_OWNER"
    printf "%-15s%10s%-50s\n" "BindHost" "| " "$BINDING_HOST"
    printf "%-15s%10s%-50s\n" "RouterId" "| " "$ROUTERID"
    printf "%-15s%10s%-50s\n" "GWPortId" "| " "$GWPORTID"
    printf "%-15s%10s%-50s\n" "GWIp" "| " "$GWIP"
    printf "%-15s%10s%-50s\n" "GWMac" "| " "$GWMAC"
    printf "%-15s%10s%-50s\n" "SNatPortId"  "| " "$SNATPORTID"
    printf "%-15s%10s%-50s\n" "SNatIP" "| " "$SNATIP"
    printf "%-15s%10s%-50s\n" "SNatMAC" "| " "$SNATMAC"
    printf "%-15s%10s%-50s\n" "BindHost" "| " "$SNAT_BINDING_HOST"
    echo -e "\n"
}

function check_floatingip()
{
    local fipid=$FLOATINGIP

    fip_info  $fipid
    if [ "X${fip["port_id"]}" != "X" ];then
        vpc_info ${fip["port_id"]}
    fi
    local device_id=$(echo $DEVICE_ID|sed "s/\ //g"|sed -n '/^[0-9a-z]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}$/p')
    if [ "X$device_id" != "X" ];then
        server_info $device_id
    fi
}

function check_vm()
{
    local vmid=$VID
    server_info  $vmid
    for p in `openstack port list --device-id $vmid -c ID | sed "s/\ //g"|sed -n '/|[0-9a-z]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}|/p' | cut -d"|" -f2`
    do
        vpc_info $p
        for f in `openstack floating ip list --port $p -c "Floating IP Address" -c Port | grep $p | cut -d'|' -f2`
        do
            fip_info  $f
        done
    done
}

function check_port()
{
    local portid=$PORTID

    vpc_info $portid

    for f in `openstack floating ip list --port $portid  -c "Floating IP Address" -c Port | grep $portid | cut -d"|" -f2`
    do
        fip_info  $f
    done

    local did=$(echo $DEVICE_ID | sed "s/\ //g"|sed -n '/^[0-9a-z]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}$/p')
    if [[ "X$did" != "X" ]];then
        server_info $did
    fi
}

declare -A info=()
declare -A port=()
declare -A dhcp=()
declare -A router=()
declare -A subnet=()
declare -A network=()
declare -A server=()
declare -A fip=()


if [ "X$OS_AUTH_URL" == "X" ];then
    echo -e "\n\tplease source rc file\n\n"
    exit 1
fi


main()
{

    if [ $# -lt 2 ];then
         help_usage
         exit
    fi

    echo `date "+%Y-%m-%d %H:%M:%S"`" check start"
    echo ""

    paraseargs

    if [ "$FLOATINGIP" != "" ];then
        check_floatingip
    fi

    if [ "$VID" != "" ];then
        check_vm
    fi

    if [ "$PORTID" != "" ];then
        check_port
    fi

    baisc_info
    echo `date "+%Y-%m-%d %H:%M:%S"`" check end"
}

main $*

