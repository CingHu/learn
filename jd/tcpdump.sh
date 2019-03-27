#!/bin/bash

IPS="
172.19.2.97
10.237.81.3
172.19.2.1
10.237.81.34
172.19.2.65
10.237.81.2
172.19.2.33
10.237.81.35
172.19.2.2
"

for ip in $IPS
do
echo $ip
#ssh $ip tcpdump -i kpi5 -w "dr-$ip.pcap" &
#ssh $ip tcpdump -r "dr-$ip.pcap" -c 1 -ennnnvvv
id=$(ssh $ip ps -ef|grep -v grep | grep tcpdump | awk '{print $2}')

ssh $ip kill -9 $id

done
=======
打印TCP会话中的的开始和结束数据包
tcpdump 'tcp[tcpflags] & (tcp-syn|tcp-fin) != 0'

打印数据包的源网络地址为192.168.1.0/24
tcpdump src net 192.168.1.0/24


打印所有源或目的端口是80, 网络层协议为IPv4, 并且含有数据,而不是SYN,FIN以及ACK-only等不含数据的数据包
tcpdump 'tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'

nt: 可理解为, ip[2:2]表示整个ip数据包的长度, (ip[0]&0xf)<<2)表示ip数据包包头的长度(ip[0]&0xf代表包中的IHL域, 而此域的单位为32bit, 要换算
成字节数需要乘以4,　即左移2.　(tcp[12]&0xf0)>>4 表示tcp头的长度, 此域的单位也是32bit,　换算成比特数为 ((tcp[12]&0xf0) >> 4)　<<　２,　
即 ((tcp[12]&0xf0)>>2).　((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0　表示: 整个ip数据包的长度减去ip头的长度,再减去
tcp头的长度不为0, 这就意味着, ip数据包中确实是有数据.对于ipv6版本只需考虑ipv6头中的'Payload Length' 与 'tcp头的长度'的差值, 并且其中表达方式'ip[]'需换成'ip6[]'.)
打印长度超过576字节, 并且网关地址是snup的IP数据包

打印长度超过576字节, 并且网关地址是snup的IP数据包
tcpdump 'gateway snup and ip[2:2] > 576'

打印所有IP层广播或多播的数据包， 但不是物理以太网层的广播或多播数据报
tcpdump 'ether[0] & 1 = 0 and ip[16] >= 224'

打印除'echo request'或者'echo reply'类型以外的ICMP数据包( 比如,需要打印所有非ping 程序产生的数据包时可用到此表达式 .
tcpdump 'icmp[icmptype] != icmp-echo and icmp[icmptype] != icmp-echoreply'


0x4745 为"GET"前两个字母"GE",0x4854 为"HTTP"前两个字母"HT"。
tcpdump  -XvvennSs 0 -i eth0 tcp[20:2]=0x4745 or tcp[20:2]=0x4854



