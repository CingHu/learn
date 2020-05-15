#!/bin/bash
iptohex() {
    printf "0x"
    IFS=.
    for str in $1
    do
        printf "%02X" $str
    done
}

BRIDGE="br-192.185"

vlan=3220
vmip="192.168.10.27"
vmiphex=$(iptohex $vmip)
vmmac="fa:16:3e:eb:d9:1b"
vmmachex="0xfa163eebd91b"
hostmac="fa:16:3d:00:00:01"
hostmachex="0xfa163d000001"
vmtunnel="vx196e150"
tunnelip="10.114.196.150"
localip="10.114.209.2"
vni=329

gwip="192.168.10.1"
giphex=$(iptohex $gwip)
gwmac="fa:16:3e:e7:9e:31"
gwmachex="0xfa163ee79e31"
computehostmac="fa:16:3f:3a:6c:09"
computehostmachex="0xfa163f3a6c09"

patchp="vlan-ens6f1-p"
patchl="vlan-ens6f1-l"
patchtunp="vxlan-ens6f1-p"
patchtunl="vxlan-ens6f1-l"

ovs-vsctl del-br $BRIDGE

ovs-vsctl add-br $BRIDGE

ovs-vsctl add-port $BRIDGE ens6f1

ovs-vsctl add-port $BRIDGE vxlan0  -- set interface vxlan0 type=vxlan option:key=flow option:remote_ip=flow option:local_ip=flow

ADDFLOW="ovs-ofctl add-flow $BRIDGE -O openflow13 "

ovs-ofctl del-flows $BRIDGE

#port dispatch
$ADDFLOW "table=0, priority=100, in_port=vxlan0, tun_id=$vni actions=write_metadata:$vni/0xffffffff, goto_table:60"
$ADDFLOW "table=0, priority=100, in_port=ens6f1 ,dl_vlan=$vlan actions=strip_vlan,write_metadata:$vni/0xffffffff, goto_table:10"
$ADDFLOW "table=0, priority=1 actions=mod_vlan_vid:1,resubmit(,100)"


#prototol dispatch
$ADDFLOW "table=10, priority=200,arp actions=resubmit(,13)"
$ADDFLOW "table=10, priority=100,ip, actions=resubmit(,20)"
$ADDFLOW "table=10, priority=1 actions=mod_vlan_vid:10,resubmit(,100)"

$ADDFLOW "table=13, priority=200,dl_dst=$computehostmac,arp,arp_op=2 actions=set_field:$tunnelip->tun_dst,resubmit(,15)"
$ADDFLOW "table=13, priority=100,arp actions=resubmit(,15)"

#arp process
$ADDFLOW "table=15,priority=100,metadata=$vni,arp,arp_op=1, arp_tpa=$vmip actions=load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$computehostmachex->NXM_NX_ARP_SHA[],load:$vmiphex->NXM_OF_ARP_SPA[],move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:$computehostmac,resubmit(,20)"
$ADDFLOW "table=15,priority=100,metadata=$vni,arp,arp_op=1, arp_tpa=$gwip actions=load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$hostmachex->NXM_NX_ARP_SHA[],load:$giphex->NXM_OF_ARP_SPA[],move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:$hostmac,resubmit(,20)"
$ADDFLOW "table=15,priority=100,metadata=$vni,arp,arp_op=2, arp_tpa=$vmip actions=load:$vmmachex->NXM_NX_ARP_THA[], mod_dl_dst:$vmmac, resubmit(,30)"
$ADDFLOW "table=15,priority=100,metadata=$vni,arp,arp_op=2, arp_tpa=$gwip actions=load:$gwmachex->NXM_NX_ARP_THA[], mod_dl_dst:$gwmac, resubmit(,30)"
$ADDFLOW "table=15, priority=1 actions=mod_vlan_vid:15,resubmit(,100)"

#l3 lookup
$ADDFLOW "table=20, priority=100,metadata=$vni,ip, nw_dst=$vmip  actions=mod_dl_dst:$vmmac,resubmit(,30)"
$ADDFLOW "table=20, priority=100,metadata=$vni,icmp, nw_dst=$gwip  actions=resubmit(,23)"
$ADDFLOW "table=20, priority=100,metadata=$vni actions=resubmit(,25)"
$ADDFLOW "table=20, priority=1 actions=mod_vlan_vid:20,resubmit(,100)"

#vlan pkt process, gwip icmp
$ADDFLOW "table=23, icmp,icmp_type=8,icmp_code=0 actions=push:NXM_OF_ETH_SRC[],push:NXM_OF_ETH_DST[],pop:NXM_OF_ETH_SRC[],pop:NXM_OF_ETH_DST[],push:NXM_OF_IP_SRC[],push:NXM_OF_IP_DST[],pop:NXM_OF_IP_SRC[],pop:NXM_OF_IP_DST[],set_field:255->nw_ttl,set_field:0->icmp_type,load:0x1->NXM_NX_REG10[0],resubmit(,25)"
$ADDFLOW "table=23, priority=1 actions=mod_vlan_vid:23,resubmit(,100)"

#reverse output
$ADDFLOW "table=25,  priority=100,metadata=$vni actions=mod_vlan_vid:$vlan,IN_PORT"
$ADDFLOW "table=25, priority=1 actions=mod_vlan_vid:25,resubmit(,100)"

#vxlan encap local_ip
$ADDFLOW "table=30,  priority=100,metadata=$vni actions=set_field:$localip->tun_src,set_field:$vni->tun_id,resubmit(,35)"
$ADDFLOW "table=30,  priority=1 actions=mod_vlan_vid:30,resubmit(,100)"


#output#l2 switch
$ADDFLOW   "table=35,  priority=100,metadata=$vni,dl_dst=$vmmac actions=set_field:$tunnelip->tun_dst,resubmit(,40)"
$ADDFLOW   "table=35,  priority=1 actions=resubmit(,40)"

$ADDFLOW "table=40, priority=100, actions=output:vxlan0"
$ADDFLOW "table=40, priority=1 actions=mod_vlan_vid:40,resubmit(,100)"

#vxlan pkt dispatch
$ADDFLOW "table=60, priority=200,ip actions=resubmit(,70)"
$ADDFLOW "table=60, priority=100,arp actions=resubmit(,65)"
$ADDFLOW "table=60, priority=1 actions=mod_vlan_vid:60,resubmit(,100)"

#arp process for vxlan
$ADDFLOW "table=65,  priority=100,metadata=$vni,arp,arp_op=1,arp_spa=$vmip actions=mod_dl_src:$computehostmac,load:$computehostmachex->NXM_NX_ARP_SHA[], resubmit(,75)"
$ADDFLOW "table=65,  priority=100,metadata=$vni,arp,arp_op=1,arp_spa=$gwip actions=move:NXM_OF_ETH_SRC[]->NXM_NX_ARP_SHA[], resubmit(,75)"
$ADDFLOW "table=65,  priority=1 actions=mod_vlan_vid:45,resubmit(,100)"

#smac update
$ADDFLOW "table=70, priority=100,metadata=$vni,ip,nw_src=$vmip actions=mod_dl_src:$computehostmac,resubmit(,75)"

#output
$ADDFLOW "table=75, priority=100,metadata=$vni actions=mod_vlan_vid:$vlan,output:ens6f1"
$ADDFLOW "table=75, priority=1 actions=mod_vlan_vid:75,resubmit(,100)"

#drop table
$ADDFLOW "table=100, priority=0 actions=drop"


