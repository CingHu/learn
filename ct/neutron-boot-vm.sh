source ./script.cfg

set -x

create_network(){
    if [ "X$NETZONE" != "X" ];then
        openstack network create \
            --provider-network-type $PROVIDER_NET_TYPE\
            --availability-zone-hint $NETZONE\
            --project $PROJECTID \
        $NETNAME
    else
        openstack network create \
            --provider-network-type $PROVIDER_NET_TYPE\
            --project $PROJECTID \
        $NETNAME
    fi

    openstack subnet create \
        --network $NETNAME \
        --subnet-range ${SUBNET_CIDR} \
        --gateway ${SUBNET_GW} \
        --dhcp \
        --project $PROJECTID \
    $SUBNETNAME

   #ipv6
   #openstack subnet create --subnet-pool IPv6-subnet-pool --dhcp --ip-version 6 --ipv6-ra-mode dhcpv6-stateful --ipv6-address-mode dhcpv6-stateful --network 6579e3a2-060f-4976-b2fb-60408a240b8d hxn-ipv6-subnet
 
   openstack router create  --project $PROJECTID $ROUTERNAME

   #neutron router-interface-add hxn-router-1 hxn-test-subnet-1
   #neutron router-interface-add hxn-router-1 hxn-test-subnet-2
   #ext-net=$(neutron net-list --router:external True -c id -c name | grep ext-net  | cut -d"|" -f2)
   #neutron router-gateway-set hxn-router-1 ext-net

   #openstack router add subnet $ROUTERNAME $SUBNETNAME
   routerid=$(openstack router list --project $PROJECTID -c ID -c Name | grep $ROUTERNAME | cut -d"|" -f2)
   neutron router-interface-add ${routerid} $SUBNETNAME
   
   #ipv6
   #openstack router add subnet   huxining-20201012 hxn-ipv6-subnet

   openstack router set --external-gateway ext-net $routerid

   SGID=$(openstack security group  list --project $PROJECTID | grep default | cut -d"|" -f2 | sed -e 's/\ //g')
   icmp_rule=$(openstack security group rule list $SGID --ingress --protocol icmp | grep "0.0.0.0")
   if [ "$icmp_rule" == "" ];then
       openstack security group rule create --project $PROJECTID  --ingress --protocol icmp ${SGID}
   fi
}

create_networkv6(){
    if [ "X$NETZONE" != "X" ];then
        IF_EXIST=$(openstack network show $V6NETNAME -c name | grep $V6NETNAME)
        if [ "${IF_EXIST}" == "" ];then
            openstack network create \
                --provider-network-type $PROVIDER_NET_TYPE\
                --availability-zone-hint $NETZONE\
                --project $PROJECTID \
            $V6NETNAME
        fi
    else
        IF_EXIST=$(openstack network show $V6NETNAME -c name | grep $V6NETNAME)
        if [ "${IF_EXIST}" == "" ];then
            openstack network create \
                --provider-network-type $PROVIDER_NET_TYPE\
                --project $PROJECTID \
            $V6NETNAME
        fi
    fi
    POOL=$(openstack subnet pool list | grep -i ipv6 |cut -d"|" -f2 | sed -e 's/\ //g')
    if [ "$POOL" == "" ];then
        echo "Error, Not found ipv6 subnet pool"
        exit 1
    fi
    openstack subnet create --subnet-pool $POOL --dhcp --ip-version 6 --ipv6-ra-mode dhcpv6-stateful --ipv6-address-mode dhcpv6-stateful --network $V6NETNAME $V6SUBNETNAME

   routerid=$(openstack router list --project $PROJECTID -c ID -c Name | grep $V6ROUTERNAME | cut -d"|" -f2)
   if [ "$routerid" == "" ];then
       openstack router create  --project $PROJECTID $V6ROUTERNAME
       routerid=$(openstack router list --project $PROJECTID -c ID -c Name | grep $V6ROUTERNAME | cut -d"|" -f2)
   fi

   #neutron router-interface-add ${routerid} $V6SUBNETNAME
   
   openstack router add subnet ${routerid} $V6SUBNETNAME

   openstack router set --external-gateway ext-net $routerid

   SGID=$(openstack security group  list --project $PROJECTID | grep default | cut -d"|" -f2 | sed -e 's/\ //g')
   icmp_rule=$(openstack security group rule list $SGID --ingress --protocol icmpv6 | grep "0.0.0.0")
   if [ "$icmp_rule" == "" ];then
       openstack security group rule create --project $PROJECTID  --ingress --protocol icmpv6 ${SGID}
   fi
}

clean_network(){
    #neutron floatingip-disassociate
    #neutron router-interface-delete hxn-router-1 hxn-test-subnet-1
    #neutron router-interface-delete hxn-router-1 hxn-test-subnet-2
    #neutron router-gateway-clear hxn-router-1

    #openstack floating ip set --port [port-id] [fip-address]
    #openstack floating ip unset --port [port-id] [fip-address]
    ROUTERIDS=$(openstack router list --project $PROJECTID | grep $ROUTERNAME | cut -d"|" -f2|sed -e 's/\ //g')
    SUBNETIDS=$(openstack subnet list --project $PROJECTID | grep $SUBNETNAME | cut -d"|" -f2|sed -e 's/\ //g')
    for router in `openstack router list --project $PROJECTID | grep $ROUTERNAME | cut -d"|" -f2 | sed -e 's/\ //g'`
    do
        for subnet in `openstack subnet list --project $PROJECTID | grep $SUBNETNAME | cut -d"|" -f2|sed -e 's/\ //g'`
        do
            neutron router-interface-delete  $ROUTERNAME $SUBNETNAME 
        openstack router unset  --external-gateway $ROUTERNAME
        done
    done

    #NETID=$(openstack network show $NETNAME -c id | grep -w id | cut -d"|" -f3|sed -e "s/\ //g")
    #NETID=$(openstack network list --project $PROJECTID | grep $NETNAME | cut -d"|" -f2|sed -e 's/\ //g')
    for net in `openstack network list --project $PROJECTID | grep $NETNAME | cut -d"|" -f2|sed -e 's/\ //g'`
    do
        for pid in `openstack port list --device-owner compute:$NOVAZONE --project $PROJECTID --net $net |grep "fa:16"|cut -d"|" -f2 | sed -e 's/\ //g'`
        do
            openstack port delete  $pid
        done
    done


    openstack subnet list --project $PROJECTID -c ID -c Name | grep $SUBNETNAME | cut -d"|" -f2 | xargs -i  openstack subnet delete {}
    openstack network list --project $PROJECTID -c ID -c Name | grep $NETNAME | cut -d"|" -f2 | xargs -i openstack network delete {}
    openstack router list --project $PROJECTID -c ID -c Name | grep $ROUTERNAME | cut -d"|" -f2 | xargs -i openstack router delete {}
}

clean_sg(){
    sgid=$(openstack security group list  --project $PROJECTID| grep "Default security group" | cut -d"|" -f2|sed -e "s/\ //g")
    sgruleid=$(openstack security group  rule list --protocol icmp --ingress | grep $sgid | cut -d"|" -f2|sed -e "s/\ //g")
    test -z $sgruleid || openstack security group  rule  delete $sgruleid
    sgruleid=$(openstack security group  rule list --protocol icmpv6 --ingress | grep $sgid | cut -d"|" -f2|sed -e "s/\ //g")
    test -z $sgruleid || openstack security group  rule  delete $sgruleid
}

create_fip(){
    for i in $(seq 1 $FIPMINCOUNT)
    do
        neutron floatingip-create --project $PROJECTID ext-net --description $FIPDESCRIPTION
    done

}

clean_fip(){
    neutron floatingip-list -c floating_ip_address -c description --project_id $PROJECTID |grep $FIPDESCRIPTION | cut -d"|" -f2|sed -e "s/\ //g" | xargs -i openstack floating ip delete {}
}

show_fip(){
    neutron floatingip-list  -c floating_ip_address -c port_id  -c description --project_id $PROJECTID |grep $FIPDESCRIPTION 
}


associate_fip_to_port(){
    #get first unassociate fip addresses
    fip=$(neutron floatingip-list -c floating_ip_address -c description -c fixed_ip_address --project_id $PROJECTID |grep $FIPDESCRIPTION |sed -e "s/\ //g"| awk -F"|" '{if ($4!="") print $2}'| head -n 1)

    #get all vm ports
    #NETID=$(openstack network show $NETNAME -c id | grep -w id | cut -d"|" -f3|sed -e "s/\ //g")
    for net in `openstack network list --project $PROJECTID | grep $NETNAME | cut -d"|" -f2|sed -e 's/\ //g'`
    do
        for pid in `openstack port list --device-owner compute:$NOVAZONE --net $net --project $PROJECTID -c id  -c 'MAC Address'|grep "fa:16"|cut -d"|" -f2 | sed -e 's/\ //g'`
        do
            #get first unassociate port
            port=$(neutron floatingip-list -c floating_ip_address -c description -c fixed_ip_address --project_id $PROJECTID | grep $FIPDESCRIPTION | grep -v $pid)
            if [ "X$port" == "X" -a "X$fip" != "X" ];then
                openstack floating ip  set --project $PROJECTID  --port $pid  $fip
            fi
        done
    done
}

create_vm(){
   if [ "$1" == "v4" ];then
       name="$NETNAME"
   else
       name="$V6NETNAME"
   fi
   #source  ./hxnrc
   SGID=$(openstack security group  list --project $PROJECTID | grep default | cut -d"|" -f2 |sed -e 's/\ //g')
   for net in `openstack network list --project $PROJECTID | grep $name | cut -d"|" -f2|sed -e 's/\ //g'`
   do
   id=$(nova boot --flavor $FLAVORID   --image $IMAGEID --nic net-id=$net --min-count $VMMINCOUNT  --security-group  $SGID --meta admin_pass='Y788^%#23YYYu' --availability-zone $NOVAZONE $VMNAME | grep -wi -e id | sed -e 's/\ //g'|cut -d"|" -f3)
   echo "openstack server show ${id}"
   openstack server show ${id}
   done
}

clean_vm(){
    for vm in `openstack server list --all --project $PROJECTID|grep ${VMNAME}|cut -d"|" -f2 |sed -e 's/\ //g'`
    do
        test -z $vm || nova force-delete "$vm"
    done
}

create() {
    create_network
    create_vm
    create_fip
    associate_fip_to_port
    show_fip
}


clean(){
   clean_fip
   clean_vm
   clean_network
   clean_sg
}

PROJECTID=$(openstack token issue | grep project_id | cut -d"|" -f3 | sed -e "s/\ //g")
if [ "X$PROJECTID" == "X" ];then
    echo "Error: please source adminrc"
    exit 1
fi

function help() {
    set +x
    echo -e "$0 all         \t create network v4 && v6 and vm in v4 && v6"
    echo -e "$0 all_fip     \t create network, vm and fip"
    echo -e "$0 clean       \t delete network, vm"
    echo -e "$0 clean_fip   \t delete network, vm and fip"
    echo -e "$0 netv4       \t only create ipv4 network" 
    echo -e "$0 netv6       \t only create ipv6 network" 
    echo -e "$0 vmv4        \t only create vm in ipv4 network" 
    echo -e "$0 vmv6        \t only create vm in ipv6 network" 
    echo -e "$0 clean_vm    \t only clean vm" 
}
if [ "$1" == "all" ];then
    create_network
    create_networkv6
    create_vm "v4"
    create_vm "v6"
elif [ "$1" == "all_fip" ];then
    create
elif [ "$1" == "clean" ];then
   clean_vm
   clean_network
   clean_sg
elif [ "$1" == "clean_vm" ];then
   clean_vm
elif [ "$1" == "clean_fip" ];then
    clean
elif [ "$1" == "netv4" ];then
    create_network
elif [ "$1" == "netv6" ];then
    create_networkv6
elif [ "$1" == "vmv4" ];then
    create_vm "v4"
elif [ "$1" == "vmv6" ];then
    create_vm "v6"
else
    help
fi

