#!/bin/bash

IP=`echo $VOLUMEIP`
IP=172.19.27.86
if [ "$IP" == "" ];then
    echo "please export VOLUMEIP=1.2.3.4"
    exit 1
fi

if [ "$1" != "" ];then
    file=$1
else
    file="fiplist"
fi

scp -r $file root@$IP:/tmp/

ssh root@$IP 'fping -f '/tmp/$file' -t 50' | tee  "result-host"
cat result-host | grep unreachable | awk '{print $1}' | sort > "fail-after"
num=$(cat fail-after|wc -l)

echo  "==============file============="
echo  "fail-after num: $num"
echo  "==============file============="

sh diff.sh

