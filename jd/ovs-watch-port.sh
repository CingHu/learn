#!/bin/bash

ofport=$(ovs-vsctl get interface $1 ofport)

interval=1
while [[ 1 ]]
do
txlast=$(ovs-ofctl -O openflow13 dump-ports br0 $ofport | grep tx | cut -d"=" -f2 | cut -d"," -f 1)
rxlast=$(ovs-ofctl -O openflow13 dump-ports br0 $ofport | grep rx | cut -d"=" -f2 | cut -d"," -f 1)
txlastdrop=$(ovs-ofctl -O openflow13 dump-ports br0 $ofport | grep tx | cut -d"=" -f4|cut -d"," -f1)
rxlastdrop=$(ovs-ofctl -O openflow13 dump-ports br0 $ofport | grep rx | cut -d"=" -f4|cut -d"," -f1)
sleep $interval
txcur=$(ovs-ofctl -O openflow13 dump-ports br0 $ofport | grep tx | cut -d"=" -f2 | cut -d"," -f 1)
rxcur=$(ovs-ofctl -O openflow13 dump-ports br0 $ofport | grep rx | cut -d"=" -f2 | cut -d"," -f 1)
txcurdrop=$(ovs-ofctl -O openflow13 dump-ports br0 $ofport | grep tx | cut -d"=" -f4|cut -d"," -f1)
rxcurdrop=$(ovs-ofctl -O openflow13 dump-ports br0 $ofport | grep rx | cut -d"=" -f4|cut -d"," -f1)
((txvalue=$txcur-$txlast))
((rxvalue=$rxcur-$rxlast))
((txvalued=$txcurdrop-$txlastdrop))
((rxvalued=$rxcurdrop-$rxlastdrop))
echo "=============================="
echo "tx:$txvalue, txdrop:$txvalued"
echo "rx:$rxvalue, rxdop:$rxvalued"
done

