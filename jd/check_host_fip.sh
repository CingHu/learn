#!/bin/bash
>  vmlist
IP=`echo $VOLUMEIP`
if [ "$IP" == "" ];then
    echo "please export VOLUMEIP=1.2.3.4"
    exit 1
fi
while read line
do
echo $line
#jvirt instance-list --host-ip $line  -a  | grep kvm | grep running | cut -d"|" -f2 >> vmlist
jvirt instance-list --host-ip $line  -a  | grep kvm | cut -d"|" -f2 >> vmlist
done < $1
sh get_ip.sh vmlist
num=$(cat fiplist | wc -l)
echo "======================="
echo "fip num is $num"
echo "======================="

#华南
#volumeip=172.27.13.81

#宿迁
#volumeip=172.19.41.214

#上海
#volumeip=10.233.34.67

#华北bj02
#volumeip=172.19.27.86
#华北bj03
#volumeip=10.237.36.36


scp -r fiplist root@$IP:/tmp/

failfip="result-$1"
ssh root@$IP 'fping -f /tmp/fiplist -t 50' | tee  "$failfip"

#cat $failfip | grep unreachable | awk '{print $1}'|sort > "fail-$failfip"
cat $failfip | grep unreachable | awk '{print $1}'|sort > "fail-before"

num=$(cat fail-before | wc -l)
echo  "==============file============="
echo  "fail-before num :$num"
echo  "==============file============="

