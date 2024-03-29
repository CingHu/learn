#!/bin/bash
iptohex() {
    printf "0x"
    IFS=.
    for str in $1
    do
        printf "%02X" $str
    done
}

BRIDGE="br-ls"
BASEBRIDGE="br-192.186"
TUNBRIDGE="br-tun"

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

patchp="$vlan-ens6f1-p"
patchl="$vlan-ens6f1-l"
patchtunp="$vni-ens6f1-p"
patchtunl="$vni-ens6f1-l"

ovs-vsctl del-br $BRIDGE
ovs-vsctl del-br $BASEBRIDGE
ovs-vsctl del-br $TUNBRIDGE

ovs-vsctl add-br $BRIDGE
ovs-vsctl add-br $BASEBRIDGE
ovs-vsctl add-br $TUNBRIDGE

ovs-vsctl add-port $BASEBRIDGE ens6f1



ovs-vsctl -- --if-exists del-port $patchp -- add-port $BASEBRIDGE $patchp -- set Interface $patchp type=patch -- set Interface $patchp options:peer=$patchl
ovs-vsctl -- --if-exists del-port $patchl -- add-port $BRIDGE $patchl -- set Interface $patchl type=patch -- set Interface $patchl options:peer=$patchp

ovs-vsctl -- --if-exists del-port $patchtunp -- add-port $TUNBRIDGE $patchtunp -- set Interface $patchtunp type=patch -- set Interface $patchtunp options:peer=$patchtunl
ovs-vsctl -- --if-exists del-port $patchtunl -- add-port $BRIDGE $patchtunl -- set Interface $patchtunl type=patch -- set Interface $patchtunl options:peer=$patchtunp

ovs-vsctl add-port $TUNBRIDGE vxlan0  -- set interface vxlan0 type=vxlan option:key=flow option:remote_ip=flow option:local_ip=flow
ADDFLOW="ovs-ofctl add-flow $BRIDGE "

ovs-ofctl del-flows $BASEBRIDGE
ovs-ofctl del-flows $BRIDGE
ovs-ofctl del-flows $TUNBRIDGE

#dispatch
ovs-ofctl add-flow $TUNBRIDGE  "table=0,  priority=100,in_port=vxlan0, tun_id=$vni actions=output:${patchtunp}"
ovs-ofctl add-flow $TUNBRIDGE  "table=0,  priority=100 in_port=$patchtunp actions=resubmit(,1)"
ovs-ofctl add-flow $TUNBRIDGE  "table=0,  priority=1 actions=mod_vlan_vid:1,resubmit(,100)"

#encap vni, local ip
ovs-ofctl add-flow $TUNBRIDGE  "table=1,  priority=100,dl_vlan=$vlan actions=strip_vlan,set_field:$localip->tun_src,set_field:$vni->tun_id,resubmit(,2)"

#l2 switch
ovs-ofctl add-flow $TUNBRIDGE  "table=2,  priority=100,dl_dst=$vmmac actions=set_field:$tunnelip->tun_dst,resubmit(,4)"
ovs-ofctl add-flow $TUNBRIDGE  "table=2,  priority=100,dl_dst=$gwmac actions=set_field:$tunnelip->tun_dst,resubmit(,4)"
ovs-ofctl add-flow $TUNBRIDGE  "table=2,  priority=1 actions=mod_vlan_vid:2,resubmit(,100)"
 

#output
ovs-ofctl add-flow $TUNBRIDGE  "table=4,  priority=100 actions=output:vxlan0"

ovs-ofctl add-flow $TUNBRIDGE  "table=100, priority=1 actions=drop"

ovs-ofctl add-flow $BASEBRIDGE  "table=0, priority=100, in_port=ens6f1,dl_vlan=$vlan actions=output:${patchp}"
ovs-ofctl add-flow $BASEBRIDGE  "table=0, priority=100,in_port=$patchp actions=mod_vlan_vid:$vlan,output:ens6f1"
ovs-ofctl add-flow $BASEBRIDGE  "table=0, priority=1 actions=drop"



$ADDFLOW "table=0, priority=100 in_port=$patchl actions=resubmit(,10)"
$ADDFLOW "table=0, priority=100,in_port=$patchtunl actions=resubmit(,40)"
$ADDFLOW "table=0, priority=1 actions=mod_vlan_vid:1,resubmit(,100)"


#L3 lookup for vlan
$ADDFLOW "table=10, priority=200,arp actions=resubmit(,15)"
$ADDFLOW "table=10, priority=100,ip, actions=resubmit(,20)"
$ADDFLOW "table=20, priority=1 actions=mod_vlan_vid:10,resubmit(,100)"

#arp process for vlan
$ADDFLOW "table=15,priority=100,arp,arp_op=1, arp_tpa=$vmip actions=load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$computehostmachex->NXM_NX_ARP_SHA[],load:$vmiphex->NXM_OF_ARP_SPA[],move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:$computehostmac,IN_PORT"
$ADDFLOW "table=15,priority=100,arp,arp_op=1, arp_tpa=$gwip actions=load:0x2->NXM_OF_ARP_OP[],move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],load:$hostmachex->NXM_NX_ARP_SHA[],load:$gipex->NXM_OF_ARP_SPA[],move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],mod_dl_src:$hostmac,IN_PORT"
$ADDFLOW "table=15,priority=100,arp,arp_op=2, arp_tpa=$vmip actions=load:$vmmachex->NXM_NX_ARP_THA[], mod_dl_dst:$vmmac, resubmit(,25)"
$ADDFLOW "table=15,priority=100,arp,arp_op=2, arp_tpa=$gwip actions=load:$gwmachex->NXM_NX_ARP_THA[], mod_dl_dst:$gwmac, resubmit(,25)"

#ip pkt process from vlan direct
$ADDFLOW "table=20, priority=100,ip, nw_dst=$vmip  actions=mod_dl_dst:$vmmac,resubmit(,25)"
$ADDFLOW "table=20, priority=100,icmp, nw_dst=$gwip  actions=resubmit(,26)"
$ADDFLOW "table=20, priority=1 actions=mod_vlan_vid:20,resubmit(,100)"

#vlan pkt process, gwip icmp
$ADDFLOW "table=26, icmp,icmp_type=8,icmp_code=0 actions=push:NXM_OF_IP_SRC[],push:NXM_OF_IP_DST[],pop:NXM_OF_IP_SRC[],pop:NXM_OF_IP_DST[],set_field:255->nw_ttl,set_field:0->icmp_type,load:0x1->NXM_NX_REG10[0],resubmit(,18)"
$ADDFLOW "table=26, priority=1 actions=mod_vlan_vid:26,resubmit(,100)"

#vlan pkt process, include arp and ip
$ADDFLOW "table=25, priority=100 actions=output:$patchtunl"
$ADDFLOW "table=25, priority=1 actions=mod_vlan_vid:30,resubmit(,100)"

#vxlan pkt dispatch
$ADDFLOW "table=40, priority=100,arp actions=resubmit(,45)"
$ADDFLOW "table=40, priority=10,ip actions=resubmit(,60)"
$ADDFLOW "table=40, priority=1 actions=mod_vlan_vid:40,resubmit(,100)"

#arp process for vxlan
$ADDFLOW "table=45,  priority=100,arp,arp_op=1,arp_spa=$vmip actions=load:$computehostmachex->NXM_NX_ARP_SHA[], output:$patchl"
$ADDFLOW "table=45,  priority=100,arp,arp_op=1,arp_spa=$gwip actions=load:$computehostmachex->NXM_NX_ARP_SHA[], output:$patchl"
$ADDFLOW "table=45,  priority=1 actions=mod_vlan_vid:45,resubmit(,100)"
$ADDFLOW "table=60, priority=10,ip,nw_src=$vmip actions=mod_dl_src:$computehostmac,output:$patchl"
$ADDFLOW "table=60, priority=1 actions=mod_vlan_vid:60,resubmit(,100)"

#drop table
$ADDFLOW "table=100, priority=0 actions=drop"
