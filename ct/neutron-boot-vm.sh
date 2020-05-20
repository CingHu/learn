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


   openstack router create  --project $PROJECTID $ROUTERNAME

   #neutron router-interface-add hxn-router-1 hxn-test-subnet-1
   #neutron router-interface-add hxn-router-1 hxn-test-subnet-2
   #ext-net=$(neutron net-list --router:external True -c id -c name | grep ext-net  | cut -d"|" -f2)
   #neutron router-gateway-set hxn-router-1 ext-net

   #openstack router add subnet $ROUTERNAME $SUBNETNAME
   routerid=$(openstack router list --project $PROJECTID -c ID -c Name | grep $ROUTERNAME | cut -d"|" -f2)
   neutron router-interface-add ${routerid} $SUBNETNAME

   openstack router set --external-gateway ext-net $routerid

   SGID=$(openstack security group  list --project $PROJECTID | grep default | cut -d"|" -f2 | sed -e 's/\ //g')
   openstack security group rule create --project $PROJECTID  --ingress --protocol icmp ${SGID}
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
   #source  ./hxnrc
   SGID=$(openstack security group  list --project $PROJECTID | grep default | cut -d"|" -f2 |sed -e 's/\ //g')
   #NETID=$(openstack network show $NETNAME -c id | grep -w id | cut -d"|" -f3|sed -e "s/\ //g"| sed -e 's/\ //g')
   for net in `openstack network list --project $PROJECTID | grep $NETNAME | cut -d"|" -f2|sed -e 's/\ //g'`
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
    echo -e "$0 all         \t create network and vm"
    echo -e "$0 all_fip     \t create network, vm and fip"
    echo -e "$0 clean       \t delete network, vm"
    echo -e "$0 clean_fip   \t delete network, vm and fip"
    echo -e "$0 net         \t only create network"
    echo -e "$0 vm          \t only create vm"
}
if [ "$1" == "all" ];then
    create_network
    create_vm
elif [ "$1" == "all_fip" ];then
    create
elif [ "$1" == "clean" ];then
   clean_vm
   clean_network
   clean_sg
elif [ "$1" == "clean_fip" ];then
    clean
elif [ "$1" == "net" ];then
    create_network
elif [ "$1" == "vm" ];then
    create_vm
else
    help
fi

