#!/bin/sh
while [ 1 ]
do
  pre_result=(`vrcli getPortStatus 0 | awk -F '[(=,]' '{printf("%s,%s,%s\n", $9, $3, $15)}'`)
  sleep 2
  after_result=(`vrcli getPortStatus 0 | awk -F '[(=,]' '{printf("%s,%s,%s\n", $9, $3, $15)}'`)
  array_size=${#pre_result[@]}
  i=0
  for (( ; $i<$array_size; i=$(($i+1)) ))
  do
    pre_value=(${pre_result[$i]})
    after_value=(${after_result[$i]})
    name=`echo ${pre_value} | awk -F "," '{printf $1}'`
    pre_rcv_packets=`echo ${pre_value} | awk -F "," '{printf $2}'`
    pre_send_packets=`echo ${pre_value} | awk -F "," '{printf $3}'`
    aft_rcv_packets=`echo ${after_value} | awk -F "," '{printf $2}'`
    aft_send_packets=`echo ${after_value} | awk -F "," '{printf $3}'`

    rcv_pps=`echo "scale=2; ($aft_rcv_packets - $pre_rcv_packets)/2" | bc`
    send_pps=`echo "scale=2; ($aft_send_packets - $pre_send_packets)/2" | bc`
    echo "name: $name,  rcv_pps: ${rcv_pps},  send_pps: ${send_pps}"

done
done
