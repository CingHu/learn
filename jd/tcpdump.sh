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
