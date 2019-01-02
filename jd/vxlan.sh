#iptables -F     
#iptables -t nat -F     
#add a vxlan port
    ip link del vxlan17
    ip link add vxlan17 type vxlan id 1017 local 10.12.209.161 remote 10.12.164.92  dstport 4789
    ip addr add 19.88.10.17/24 dev vxlan17
    ip link set vxlan17 up
	ifconfig vxlan17 mtu 1450
	echo 1 > /proc/sys/net/ipv4/conf/vxlan17/proxy_arp
    
    route add -net 19.88.10.200 netmask 255.255.255.255 dev vxlan17

	route add default gw 19.88.10.200

    echo 1 >/proc/sys/net/ipv4/ip_forward
    
	#set the route and arp
	route add -net 10.237.164.92  netmask 255.255.255.255 dev eth3
   	arp -s 10.237.164.92 ea:5d:89:6d:0b:e8 

    #set iptables to permit
	#iptables -t nat -A POSTROUTING -o vxlan17 -j MASQUERADE

	#set output port nat
	#iptables -t nat -I POSTROUTING -o eth2 -j MASQUERADE
	#iptables -t nat -I POSTROUTING -o eth3 -j MASQUERADE
    iptables-restore <  vxlan17.iptables	
