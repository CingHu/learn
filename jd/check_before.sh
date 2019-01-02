#!/bin/bash
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

IP=`echo $VOLUMEIP`
if [ "$IP" == "" ];then
    echo "please export VOLUMEIP=1.2.3.4"
    exit 1
fi

DIRNAME=`date +%s`$RANDOM
PATHTMP="./tmp"
PATHINFO="$PATHTMP/tmp_$DIRNAME"

mkdir -p $PATHINFO > /dev/null
echo "temp file: $PATHINFO"

sh get_host_fip.sh all_huabei_fip host $PATHINFO/fiplist


scp -r $PATHINFO/fiplist root@$IP:/tmp/

failfip="result-host"
ssh root@$IP 'fping -f /tmp/fiplist -t 50' | tee  "$PATHINFO/$failfip"

cat $PATHINFO/$failfip | grep unreachable | awk '{print $1}'|sort > "$PATHINFO/fail-before"

cp -f check_after.sh $PATHINFO/
cp -f diff.sh $PATHINFO/
cp -f check_fail_fip.sh $PATHINFO/


num=$(cat $PATHINFO/fiplist | wc -l)
echo "======================="
echo "all fip num is $num"
echo "======================="

num=$(cat $PATHINFO/fail-before | wc -l)
echo  "============== before fail ============="
echo  "fail-before num: $num"
echo  "fail-before dir: $PATHINFO"
echo  "============== before fail ============="

