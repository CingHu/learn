#!/bin/bash
if [ $# -eq 2 ];then
    TABLE_ID=$2","
fi

i=1

if [[ $1 == $i ]];then
watch -n 1 -d "ovs-appctl bridge/dump-flows br0 | sed -e 's/duration=[^,]*,//g' | grep goto_table:200"
fi

((i+=1))

if [[ $1 == $i ]];then
watch -n 1 -d "ovs-dpctl dump-flows  | grep drop | grep -v "packets:0"|sed -e 's/used:[^,]*,//g'" 
fi

((i+=1))

if [[ $1 == $i ]];then
watch -n 1 -d "ovs-appctl dpif/dump-flows br0" 
fi

((i+=1))
if [[ $1 == $i ]];then
watch -n 1 -d "ovs-ofctl dump-flows br0 -O openflow13 |grep "table=${TABLE_ID}"| grep -v "n_packets=0" | grep -v "OFPST_FLOW" | sed -e 's/duration=[^,]*,//g'"
fi

((i+=1))
if [[ $1 == $i ]];then
watch -n 1 -d "ovs-appctl bridge/dump-flows br0 |grep "table_id=${TABLE_ID}" | grep -v "n_packets=0" | sed -e 's/duration=[^,]*,//g'"
fi

((i+=1))
if [[ $1 == $i ]];then
watch -n 1 -d "ovs-ofctl dump-flows -O openflow13 br0 | grep "table=${TABLE_ID}" | grep -v "n_packets=0" |grep -v "OFPST_FLOW"| sed -e '/NXST_FLOW/d' -e 's/\(duration\)=[^,]*,//g' -e 's/send_flow_rem//g'"
fi

((i+=1))
if [[ $1 == $i ]];then
watch -n 1 -d "ovs-ofctl dump-group-stats br0 -O openflow13 |  sed -e 's/duration=[^,]*,//g'"
fi

((i+=1))
if [[ $1 == $i ]];then
watch -n 1 -d "ovs-dpctl dump-flows"
fi

((i+=1))
if [[ $1 == $i ]];then
watch -n 1 -d "ovs-ofctl dump-flows -O openflow13 br0 | grep "tp_dst=67" | grep -v "n_packets=0" |grep -v "OFPST_FLOW"| sed -e '/NXST_FLOW/d' -e 's/\(duration\)=[^,]*,//g' -e 's/send_flow_rem//g'"
fi

#ovs-ofctl dump-flows -O openflow13 br0 | sed -e '/NXST_FLOW/d' -e 's/\(idle\|hard\)_age=[^,]*,//g' -e 's/\(duration\|n_packets\|n_bytes\|cookie\)=[^,]*,//g' 

