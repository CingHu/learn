#!/bin/bash

FILE="flow.save"

ovs-ofctl dump-flows -O openflow13 br0 | sed -e '/NXST_FLOW/d' -e 's/\(idle\|hard\)_age=[^,]*,//g' -e 's/\(duration\|n_packets\|n_bytes\|cookie\)=[^,]*,//g' > $FILE

while read LINE
do
sudo ovs-ofctl add-flow -O openflow13 br0 "$LINE"
done  < $FILE