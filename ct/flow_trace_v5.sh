#!/bin/bash
#参数检查函数
para_check(){
if  ([ ! -z "$2" ]&&[ -z "$3"  ]) ;then
        echo "开始追踪流表："
else
        echo "输入参数错误！！！"
		echo "$1"
        exit 1
fi
}

#ARP流表追踪
arp_trace(){
tar1=$(cat /etc/hosts |grep odl_db | cut -d ' '  -f 1)
pgdb=$(cat /etc/hosts |grep odl_db | cut -d ' '  -f 1)

#虚机到网关ARP追踪
if  [ $3 == "gw" ] ;then
src_fix_ips=$(psql -t  --command "select fix_ips from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_network_id=$(psql -t  --command "select network_id from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_network_id=$(echo $(echo $src_network_id))
src_server_ip1=$(echo $src_fix_ips |cut -d '"' -f 6)
src_server_ip2=$(echo $src_fix_ips |cut -d '"' -f 20)
src_subnet1=$(echo $src_fix_ips |cut -d '"' -f 2)
src_subnet2=$(echo $src_fix_ips |cut -d '"' -f 16)
if [ "$src_server_ip1" == "$2" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet1))
elif [ "$src_server_ip2" == "$2" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet2))
else 
	echo "no right IP"
	exit 1
fi
gw_mac=$(psql -t  --command "select gw_mac from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_ip=$(psql -t  --command "select gw_ip from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
dl_dst=$(echo $(echo $gw_mac))
src_tun_id=$(psql -t  --command "select segmentation_id from network where id='$src_network_id' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tun_id=$(echo $(echo $src_tun_id))
tar2=$(psql -t  --command "select port_num from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar3=$(psql -t  --command "select mac from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(psql -t  --command "select host_ip from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))

src_in_port=$(echo $(echo $tar2))
dl_src=$(echo $(echo $tar3))
arp_spa=$2
arp_tpa=$(echo $(echo $gw_ip))

ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip"  <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机发起的ARP-request<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=ff:ff:ff:ff:ff:ff,arp,arp_spa=$arp_spa,arp_tpa=$arp_tpa,arp_op=1,arp_sha=$dl_src,arp_tha=00:00:00:00:00:00 -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机收到的ARP-reply<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,tun_id=$tun_id,nw_ttl=64,dl_src=$dl_dst,dl_dst=$dl_src,arp,arp_spa=$arp_tpa,arp_tpa=$arp_spa,arp_op=2,arp_sha=$dl_dst,arp_tha=$dl_src -generate
echo "           "
echo "           "
exit
EOF
rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

#虚机到专线ARP追踪
elif  [ $3 == "sl" ] ;then
src_fix_ips=$(psql -t  --command "select fix_ips from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_network_id=$(psql -t  --command "select network_id from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_network_id=$(echo $(echo $src_network_id))
src_server_ip1=$(echo $src_fix_ips |cut -d '"' -f 6)
src_server_ip2=$(echo $src_fix_ips |cut -d '"' -f 20)
src_subnet1=$(echo $src_fix_ips |cut -d '"' -f 2)
src_subnet2=$(echo $src_fix_ips |cut -d '"' -f 16)
if [ "$src_server_ip1" == "$2" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet1))
elif [ "$src_server_ip2" == "$2" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet2))
else 
	echo "no right IP"
	exit 1
fi
gw_mac=$(psql -t  --command "select gw_mac from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
subnets=$(psql -t  --command "select src_subnet_members from clouddcpeer where src_subnet_members like '%$gw_subnet%' and is_deleted is null limit 1" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_ip=$(echo $subnets |cut -d '"' -f 10)
dl_dst=$(echo $(echo $gw_mac))
src_tun_id=$(psql -t  --command "select segmentation_id from network where id='$src_network_id' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tun_id=$(echo $(echo $src_tun_id))
tar2=$(psql -t  --command "select port_num from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar3=$(psql -t  --command "select mac from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(psql -t  --command "select host_ip from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))

src_in_port=$(echo $(echo $tar2))
dl_src=$(echo $(echo $tar3))
arp_spa=$2
arp_tpa=$(echo $(echo $gw_ip))

ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip"  <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机发送的ARP-request<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=ff:ff:ff:ff:ff:ff,arp,arp_spa=$arp_spa,arp_tpa=$arp_tpa,arp_op=1,arp_sha=$dl_src,arp_tha=00:00:00:00:00:00 -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机收到的ARP-reply<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,nw_ttl=64,tun_id=$tun_id,dl_src=$dl_dst,dl_dst=$dl_src,arp,arp_spa=$arp_tpa,arp_tpa=$arp_spa,arp_op=2,arp_sha=$dl_dst,arp_tha=$dl_src -generate
echo "           "
echo "           "
exit
EOF
rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

#专线网关到虚机ARP追踪
elif  [ $1 == "sl" ] ;then
src_fix_ips=$(psql -t  --command "select fix_ips from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_network_id=$(psql -t  --command "select network_id from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_network_id=$(echo $(echo $src_network_id))
src_server_ip1=$(echo $src_fix_ips |cut -d '"' -f 6)
src_server_ip2=$(echo $src_fix_ips |cut -d '"' -f 20)
src_subnet1=$(echo $src_fix_ips |cut -d '"' -f 2)
src_subnet2=$(echo $src_fix_ips |cut -d '"' -f 16)
if [ "$src_server_ip1" == "$4" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet1))
elif [ "$src_server_ip2" == "$4" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet2))
else 
	echo "no right IP"
	exit 1
fi
gw_mac=$(psql -t  --command "select gw_mac from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
subnets=$(psql -t  --command "select src_subnet_members from clouddcpeer where src_subnet_members like '%$gw_subnet%' and is_deleted is null limit 1" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_ip=$(echo $subnets |cut -d '"' -f 10)
dl_dst=$(echo $(echo $gw_mac))
src_tun_id=$(psql -t  --command "select segmentation_id from network where id='$src_network_id' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tun_id=$(echo $(echo $src_tun_id))
tar2=$(psql -t  --command "select port_num from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar3=$(psql -t  --command "select mac from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(psql -t  --command "select host_ip from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))

src_in_port=$(echo $(echo $tar2))
dl_src=$(echo $(echo $tar3))
arp_spa=$4
arp_tpa=$(echo $(echo $gw_ip))

ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip"  <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机收到专线的ARP-request<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,nw_ttl=64,tun_id=$tun_id,dl_src=$dl_src,dl_dst=ff:ff:ff:ff:ff:ff,arp,arp_spa=$arp_tpa,arp_tpa=$arp_spa,arp_op=1,arp_sha=$dl_src,arp_tha=00:00:00:00:00:00 -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机回复专线的ARP-reply<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_dst,dl_dst=$dl_src,arp,arp_spa=$arp_spa,arp_tpa=$arp_tpa,arp_op=2,arp_sha=$dl_dst,arp_tha=$dl_src -generate
echo "           "
echo "           "
exit
EOF
rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

else
tar2=$(psql -t  --command "select port_num from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar3=$(psql -t  --command "select mac from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar4=$(psql -t  --command "select port_num from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar5=$(psql -t  --command "select mac from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")

src_network_id=$(psql -t  --command "select network_id from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
dst_network_id=$(psql -t  --command "select network_id from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_network_id=$(echo $(echo $src_network_id))
dst_network_id=$(echo $(echo $dst_network_id))
src_tun_id=$(psql -t  --command "select segmentation_id from network where id='$src_network_id' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
dst_tun_id=$(psql -t  --command "select segmentation_id from network where id='$dst_network_id' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
s_tun_id=$(echo $(echo $src_tun_id))
d_tun_id=$(echo $(echo $dst_tun_id))

src_host_ip=$(psql -t  --command "select host_ip from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
dst_host_ip=$(psql -t  --command "select host_ip from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))
dst_host_ip=$(echo $(echo $dst_host_ip))
src_in_port=$(echo $(echo $tar2))
dst_in_port=$(echo $(echo $tar4))
dl_src=$(echo $(echo $tar3))
dl_dst=$(echo $(echo $tar5))
arp_spa=$2
arp_tpa=$4

ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip"  <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>源虚机发起的ARP-request<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=ff:ff:ff:ff:ff:ff,arp,arp_spa=$arp_spa,arp_tpa=$arp_tpa,arp_op=1,arp_sha=$dl_src,arp_tha=00:00:00:00:00:00 -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>源虚机收到的ARP-reply<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,nw_ttl=64,tun_id=$s_tun_id,dl_src=$dl_dst,dl_dst=$dl_src,arp,arp_spa=$arp_tpa,arp_tpa=$arp_spa,arp_op=2,arp_sha=$dl_dst,arp_tha=$dl_src -generate
echo "           "
echo "           "
exit
EOF

ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$dst_host_ip"  <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>目的虚机收到的ARP-request<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,nw_ttl=64,tun_id=$d_tun_id,dl_src=$dl_src,dl_dst=ff:ff:ff:ff:ff:ff,arp,arp_spa=$arp_spa,arp_tpa=$arp_tpa,arp_op=1,arp_sha=$dl_src,arp_tha=00:00:00:00:00:00 -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>目的虚机回复的ARP-reply<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$dst_in_port,nw_ttl=64,dl_src=$dl_dst,dl_dst=$dl_src,arp,arp_spa=$arp_tpa,arp_tpa=$arp_spa,arp_op=2,arp_sha=$dl_dst,arp_tha=$dl_src -generate
echo "           "
echo "           "
exit
EOF
rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$dst_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

fi
}
#ICMP流表追踪
icmp_trace(){

#虚机到网关的ICMP流表追踪
if  [ $3 == "gw" ] ;then
pgdb=$(cat /etc/hosts |grep odl_db | cut -d ' '  -f 1)
if [  -z "$2" ];
then
echo "输入参数错误"
exit 1
fi
src_fix_ips=$(psql -t  --command "select fix_ips from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_server_ip1=$(echo $src_fix_ips |cut -d '"' -f 6)
src_server_ip2=$(echo $src_fix_ips |cut -d '"' -f 20)
src_subnet1=$(echo $src_fix_ips |cut -d '"' -f 2)
src_subnet2=$(echo $src_fix_ips |cut -d '"' -f 16)
if [ "$src_server_ip1" == "$2" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet1))
elif [ "$src_server_ip2" == "$2" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet2))
else 
	echo "no right IP"
	exit 1
fi
src_host_ip=$(psql -t  --command "select host_ip from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))
src_port=$(psql -t  --command "select port_num from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_mac=$(psql -t  --command "select mac from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_mac=$(psql -t  --command "select gw_mac from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_ip=$(psql -t  --command "select gw_ip from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_in_port=$(echo $(echo $src_port))
dl_src=$(echo $(echo $src_mac))
dl_dst=$(echo $(echo $gw_mac))
nw_src=$2
nw_dst=$(echo $(echo $gw_ip))
ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip" <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机发起的ICMP-request包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=$dl_dst,ip,nw_src=$nw_src,nw_dst=$nw_dst,nw_proto=1 -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机收到的ICMP-reply包<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,dl_src=$dl_dst,nw_ttl=64,dl_dst=$dl_src,ip,nw_src=$nw_dst,nw_dst=$nw_src,nw_proto=1 -generate
echo "           "
echo "           "
exit
EOF

rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

#网关/公网到虚机的ICMP流表追踪
elif [ $1 == "gw" ] ;then
pgdb=$(cat /etc/hosts |grep odl_db | cut -d ' '  -f 1)
src_fix_ips=$(psql -t  --command "select fix_ips from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_server_ip1=$(echo $src_fix_ips |cut -d '"' -f 6)
src_server_ip2=$(echo $src_fix_ips |cut -d '"' -f 20)
src_subnet1=$(echo $src_fix_ips |cut -d '"' -f 2)
src_subnet2=$(echo $src_fix_ips |cut -d '"' -f 16)
if [ "$src_server_ip1" == "$4" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet1))
elif [ "$src_server_ip2" == "$4" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet2))
else 
	echo "no right IP"
	exit 1
fi
src_host_ip=$(psql -t  --command "select host_ip from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))
src_port=$(psql -t  --command "select port_num from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_mac=$(psql -t  --command "select mac from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_mac=$(psql -t  --command "select gw_mac from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_ip=$(psql -t  --command "select gw_ip from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_in_port=$(echo $(echo $src_port))
dl_src=$(echo $(echo $src_mac))
dl_dst=$(echo $(echo $gw_mac))
nw_src=$2
nw_dst=$4
ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip" <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机收到的ICMP-request包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,dl_src=$dl_dst,nw_ttl=64,dl_dst=$dl_src,ip,nw_src=$nw_src,nw_dst=$nw_dst,nw_proto=1 -generate

echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机回复的ICMP-reply包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=$dl_dst,ip,nw_src=$nw_dst,nw_dst=$nw_src,nw_proto=1 -generate
echo "           "
echo "           "
exit
EOF

rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

#虚机之间的ICMP流表追踪
else
tar1=$(cat /etc/hosts |grep odl_db | cut -d ' '  -f 1)
tar2=$(psql -t  --command "select port_num from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar3=$(psql -t  --command "select mac from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar4=$(psql -t  --command "select port_num from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar5=$(psql -t  --command "select mac from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")

src_host_ip=$(psql -t  --command "select host_ip from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
dst_host_ip=$(psql -t  --command "select host_ip from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))
dst_host_ip=$(echo $(echo $dst_host_ip))
src_in_port=$(echo $(echo $tar2))
dst_in_port=$(echo $(echo $tar4))
dl_src=$(echo $(echo $tar3))
dl_dst=$(echo $(echo $tar5))
nw_src=$2
nw_dst=$4
ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip"  <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>源虚机发起的ICMP-request包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=$dl_dst,ip,nw_src=$nw_src,nw_dst=$nw_dst,nw_proto=1 -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>源虚机收到的ICMP-reply包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,dl_src=$dl_dst,nw_ttl=64,dl_dst=$dl_src,ip,nw_src=$nw_dst,nw_dst=$nw_src,nw_proto=1 -generate
echo "           "
echo "           "
exit
EOF

rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$dst_host_ip"  <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>目的虚机收到的ICMP-request包<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,dl_src=$dl_src,nw_ttl=64,dl_dst=$dl_dst,ip,nw_src=$nw_src,nw_dst=$nw_dst,nw_proto=1 -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>目的虚机回复的ICMP-reply包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$dst_in_port,nw_ttl=64,dl_src=$dl_dst,dl_dst=$dl_src,ip,nw_src=$nw_dst,nw_dst=$nw_src,nw_proto=1 -generate
echo "           "
echo "           "
exit
EOF
fi

rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$dst_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

}
#TCP流表追踪
tcp_trace(){
#虚机到公网的TCP流表追踪
if  [ $3 == "gw" ] ;then
pgdb=$(cat /etc/hosts |grep odl_db | cut -d ' '  -f 1)

src_fix_ips=$(psql -t  --command "select fix_ips from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_server_ip1=$(echo $src_fix_ips |cut -d '"' -f 6)
src_server_ip2=$(echo $src_fix_ips |cut -d '"' -f 20)
src_subnet1=$(echo $src_fix_ips |cut -d '"' -f 2)
src_subnet2=$(echo $src_fix_ips |cut -d '"' -f 16)
if [ "$src_server_ip1" == "$2" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet1))
elif [ "$src_server_ip2" == "$2" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet2))
else 
	echo "no right IP"
	exit 1
fi
src_host_ip=$(psql -t  --command "select host_ip from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))
src_port=$(psql -t  --command "select port_num from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_mac=$(psql -t  --command "select mac from port where device='$1'  and fix_ips like '%$2%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_mac=$(psql -t  --command "select gw_mac from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_ip=$(psql -t  --command "select gw_ip from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_in_port=$(echo $(echo $src_port))
dl_src=$(echo $(echo $src_mac))
dl_dst=$(echo $(echo $gw_mac))
nw_src=$2
nw_dst=$4
dst_port=$5
ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip" <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机发起的TCP-request包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=$dl_dst,ip,nw_src=$nw_src,nw_dst=$nw_dst,nw_proto=6,tcp_src=2050,tcp_dst=$dst_port -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机收到的TCP-reply包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,dl_src=$dl_dst,nw_ttl=64,dl_dst=$dl_src,ip,nw_src=$nw_dst,nw_dst=$nw_src,nw_proto=6,tcp_src=$dst_port,tcp_dst=2050 -generate
echo "           "
echo "           "
exit
EOF

rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

#公网到虚机的TCP流表追踪
elif  [ $1 == "gw" ] ;then
pgdb=$(cat /etc/hosts |grep odl_db | cut -d ' '  -f 1)
src_fix_ips=$(psql -t  --command "select fix_ips from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_server_ip1=$(echo $src_fix_ips |cut -d '"' -f 6)
src_server_ip2=$(echo $src_fix_ips |cut -d '"' -f 20)
src_subnet1=$(echo $src_fix_ips |cut -d '"' -f 2)
src_subnet2=$(echo $src_fix_ips |cut -d '"' -f 16)
if [ "$src_server_ip1" == "$4" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet1))
elif [ "$src_server_ip2" == "$4" ] ;
then
	gw_subnet=$(echo $(echo $src_subnet2))
else 
	echo "no right IP"
	exit 1
fi
src_host_ip=$(psql -t  --command "select host_ip from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))
src_port=$(psql -t  --command "select port_num from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_mac=$(psql -t  --command "select mac from port where device='$3'  and fix_ips like '%$4%' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_mac=$(psql -t  --command "select gw_mac from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
gw_ip=$(psql -t  --command "select gw_ip from subnet where id ='$gw_subnet' and is_deleted is null;" "host=$pgdb hostaddr=$pgdb port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_in_port=$(echo $(echo $src_port))
dl_src=$(echo $(echo $src_mac))
dl_dst=$(echo $(echo $gw_mac))
nw_src=$2
nw_dst=$4
dst_port=$5

ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip" <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机收到的TCP-request包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,dl_src=$dl_dst,nw_ttl=64,dl_dst=$dl_src,ip,nw_src=$nw_src,nw_dst=$nw_dst,nw_proto=6,tcp_src=2050,tcp_dst=$dst_port -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机回复的TCP-reply包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=$dl_dst,ip,nw_src=$nw_dst,nw_dst=$nw_src,nw_proto=6,tcp_src=$dst_port,tcp_dst=2050 -generate
echo "           "
echo "           "
exit
EOF

rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

#虚机之间的TCP流表追踪
else
tar1=$(cat /etc/hosts |grep odl_db | cut -d ' '  -f 1)
tar2=$(psql -t  --command "select port_num from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar3=$(psql -t  --command "select mac from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar4=$(psql -t  --command "select port_num from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar5=$(psql -t  --command "select mac from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")

src_host_ip=$(psql -t  --command "select host_ip from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
dst_host_ip=$(psql -t  --command "select host_ip from port where device='$3' and fix_ips like '%$4%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))
dst_host_ip=$(echo $(echo $dst_host_ip))
src_in_port=$(echo $(echo $tar2))
dst_in_port=$(echo $(echo $tar4))
dl_src=$(echo $(echo $tar3))
dl_dst=$(echo $(echo $tar5))
nw_src=$2
nw_dst=$4
tcp_dst_port=$5

ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip" <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>源虚机发起的TCP-request包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=$dl_dst,ip,nw_src=$nw_src,nw_dst=$nw_dst,nw_proto=6,tcp_src=2050,tcp_dst=$tcp_dst_port -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>源虚机收到的TCP-reply包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,dl_src=$dl_dst,nw_ttl=64,dl_dst=$dl_src,ip,nw_src=$nw_dst,nw_dst=$nw_src,nw_proto=6,tcp_src=$tcp_dst_port,tcp_dst=2050 -generate
echo "           "
echo "           "
exit
EOF

rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$dst_host_ip"  <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>目的虚机收到的TCP-request包<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=1,dl_src=$dl_src,nw_ttl=64,dl_dst=$dl_dst,ip,nw_src=$nw_src,nw_dst=$nw_dst,nw_proto=6,tcp_src=2050,tcp_dst=$tcp_dst_port -generate
echo "           "
echo "           "
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>目的虚机回复的TCP-reply包<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$dst_in_port,nw_ttl=64,dl_src=$dl_dst,dl_dst=$dl_src,ip,nw_src=$nw_dst,nw_dst=$nw_src,nw_proto=6,tcp_src=$tcp_dst_port,tcp_dst=2050 -generate
echo "           "
echo "           "
exit
EOF
fi
}

rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$dst_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

#DHCP流表追踪
dhcp_trace(){
tar1=$(cat /etc/hosts |grep odl_db | cut -d ' '  -f 1)
tar2=$(psql -t  --command "select port_num from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
tar3=$(psql -t  --command "select mac from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(psql -t  --command "select host_ip from port where device='$1' and fix_ips like '%$2%' and is_deleted is null;" "host=$tar1 hostaddr=$tar1 port=5432 user=postgres password=ZjM2MjQ5MT dbname=postgres")
src_host_ip=$(echo $(echo $src_host_ip))
src_in_port=$(echo $(echo $tar2))
dl_src=$(echo $(echo $tar3))
nw_src=$2
ssh -p 10000 -o "StrictHostKeyChecking no" secure@"$src_host_ip" <<EOF
sudo -i
echo "           "
echo "           "
hname=$(hostname)
ovs-ofctl dump-flows br-int -O openflow13 > /home/secure/$hname-flow-result.txt
echo "***************************************************************"
echo ">>>>>>>>>>>>>>>>>>>>>>>虚机发起的DHCP-request包<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "***************************************************************"
ovs-appctl ofproto/trace br-int in_port=$src_in_port,nw_ttl=64,dl_src=$dl_src,dl_dst=ff:ff:ff:ff:ff:ff,ip,nw_src=0.0.0.0,nw_dst=255.255.255.255,nw_proto=17,udp_src=68,udp_dst=67 -generate
echo "           "
echo "           "
exit
EOF

rm -rf /home/secure/flow-result
mkdir /home/secure/flow-result
scp -P 10000 secure@$src_host_ip:/home/secure/*-flow-result.txt /home/secure/flow-result

}
#协议判断
case $1 in
	"arp" )
	para_check "sh flow-trace.sh arp vm1-id vm1-ip vm2-id/gw vm2-ip/gw-ip" $5 $6
	arp_trace $2 $3 $4 $5 
	;;
	"icmp" )
	para_check "sh flow-trace.sh icmp vm1-id vm1-ip vm2-id/gw vm2-ip/gw-ip/internet-ip" $5 $6
	icmp_trace $2 $3 $4 $5 
	;;
	"tcp" )
	para_check "sh flow-trace.sh tcp  vm1-id vm1-ip vm2-id/gw vm2-ip/internet-ip tcp-dst-port" $6 $7
	tcp_trace $2 $3 $4 $5 $6
	;;
	"dhcp" )
	para_check "sh flow-trace.sh dhcp vm1-id" $2 $3
	dhcp_trace $2
	;;
	*) 
	echo "第一个参数错误！！！"
	echo "arp/icmp/tcp/dhcp";;
esac