#!/bin/bash


if [ $# -ne 1 ];then
    echo "Error: must special underlay ip nic name, example: sh $0 eth2"
    exit
fi

#special for user
UNDERLAY_NIC_NAME=$1


NIC_PATH="/etc/sysconfig/network-scripts/ifcfg-$UNDERLAY_NIC_NAME"
CONTRACK_CONF_FILE="/etc/modprobe.d/nf_conntrack.conf"


#not modify
OVS_CORE_BINGDING=4
START_CPU=4


HANDLER_NUM=1
REVALIDATOR_NUM=1


#stop irq service
systemctl stop irqbalance.service
systemctl disable irqbalance.service

# warning: restart host, config loss
# NIC RSS, update underlay nic vxlan hash policy, 4 tuple hash, include sip, dip, sport and dport for flow
#check
ethtool -N ${UNDERLAY_NIC_NAME} rx-flow-hash udp4
#tmp set
ethtool -N ${UNDERLAY_NIC_NAME} rx-flow-hash udp4 sfdn

#save set
sed -i "/rx-flow-hash/d" $NIC_PATH
echo "ETHTOOL_OPTS=\"-N $UNDERLAY_NIC_NAME rx-flow-hash udp4 sfdn\"" >> $NIC_PATH

#ring buffer
#warning increase delay
ethtool -G $UNDERLAY_NIC_NAME rx 2048
sed -i "/-G $UNDERLAY_NIC_NAME rx/d" $NIC_PATH
echo "ETHTOOL_OPTS=\"-G $UNDERLAY_NIC_NAME rx 2048\"" >> $NIC_PATH

#interrupt aggregation
ethtool -C $UNDERLAY_NIC_NAME rx-usecs 50
sed -i "/rx-usecs/d" $NIC_PATH
echo "ETHTOOL_OPTS=\"-c $UNDERLAY_NIC_NAME rx-usecs 50\"" >> $NIC_PATH

#close gso gro lro
ethtool -K $UNDERLAY_NIC_NAME gso off gro off lro off
sed -i "/gso/d" $NIC_PATH
sed -i "/gro/d" $NIC_PATH
sed -i "/lro/d" $NIC_PATH
echo "ETHTOOL_OPTS=\"-K $UNDERLAY_NIC_NAME gso off gro off lro off\"" >> $NIC_PATH


#warning: can not consider numa
#irq binding cpu 
cat > set_irq_affinity.sh<<'EOF'
#!/bin/bash
set_affinity()
{
    let "LOOP = $VEC / $CORE_NUM"
    let "NUM = $CORE_NUM * $LOOP"
    let "TMP_VEC = $VEC - $NUM"
    MASK_TMP=$((1<<(`expr $TMP_VEC + $CORE`)))
    MASK=`printf "%X" $MASK_TMP`
 
    printf "%s mask=%s for /proc/irq/%d/smp_affinity\n" $DEV $MASK $IRQ
    printf "%s" $MASK > /proc/irq/$IRQ/smp_affinity
}
 
if [ $# -ne 3 ] ; then
        echo "Description:"
        echo "    This script attempts to bind each queue of a multi-queue NIC"
        echo "    to the same numbered core, ie tx0|rx0 --> cpu0, tx1|rx1 --> cpu1"
        echo "usage:"
        echo "    $0 core eth0 [eth1 eth2 eth3] core_num"
        exit
fi
 
CORE=$1
CORE_NUM=$3
 
# check for irqbalance running
IRQBALANCE_ON=`ps ax | grep -v grep | grep -q irqbalance; echo $?`
if [ "$IRQBALANCE_ON" == "0" ] ; then
        echo " WARNING: irqbalance is running and will"
        echo "          likely override this script's affinitization."
        echo "          Please stop the irqbalance service and/or execute"
        echo "          'killall irqbalance'"
fi
 
#
# Set up the desired devices.
#
shift 1
 
for DEV in $*
do
  for DIR in rx tx TxRx
  do
     MAX=`grep $DEV-$DIR /proc/interrupts | wc -l`
     if [ "$MAX" == "0" ] ; then
       MAX=`egrep -i "$DEV:.*$DIR" /proc/interrupts | wc -l`
     fi
     if [ "$MAX" == "0" ] ; then
       echo no $DIR vectors found on $DEV
       continue
     fi
     for VEC in `seq 0 1 $MAX`
     do
        IRQ=`cat /proc/interrupts | grep -i $DEV-$DIR-$VEC"$"  | cut  -d:  -f1 | sed "s/ //g"`
        if [ -n  "$IRQ" ]; then
          set_affinity
        else
           IRQ=`cat /proc/interrupts | egrep -i $DEV:v$VEC-$DIR"$"  | cut  -d:  -f1 | sed "s/ //g"`
           if [ -n  "$IRQ" ]; then
             set_affinity
           fi
        fi
     done
  done
done

EOF

cat > show_irq_affinity.sh<<'EOF'
#!/bin/bash

show_affinity()
{
 
    echo "$IRQ: " && cat  /proc/irq/$IRQ/smp_affinity
}
 
if [ $# -ne 1 ] ; then
        echo "Description:"
        echo "    This script attempts to bind each queue of a multi-queue NIC"
        echo "    to the same numbered core, ie tx0|rx0 --> cpu0, tx1|rx1 --> cpu1"
        echo "usage:"
        echo "    $0 eth0"
        exit
fi
 

echo $1

for DEV in $1
do
  for DIR in rx tx TxRx
  do
     MAX=`grep $DEV-$DIR /proc/interrupts | wc -l`
     if [ "$MAX" == "0" ] ; then
       MAX=`egrep -i "$DEV:.*$DIR" /proc/interrupts | wc -l`
     fi
     if [ "$MAX" == "0" ] ; then
       echo no $DIR vectors found on $DEV
       continue
     fi
     for VEC in `seq 0 1 $MAX`
     do
        IRQ=`cat /proc/interrupts | grep -i $DEV-$DIR-$VEC"$"  | cut  -d:  -f1 | sed "s/ //g"`
        if [ -n  "$IRQ" ]; then
          show_affinity 
        else
           IRQ=`cat /proc/interrupts | egrep -i $DEV:v$VEC-$DIR"$"  | cut  -d:  -f1 | sed "s/ //g"`
           if [ -n  "$IRQ" ]; then
             show_affinity
           fi
        fi
     done
  done
done

EOF

sh set_irq_affinity.sh $START_CPU $UNDERLAY_NIC_NAME $OVS_CORE_BINGDING
sh show_irq_affinity.sh $UNDERLAY_NIC_NAME
rm -f set_irq_affinity.sh
rm -f show_irq_affinity.sh

#update connection track hash size
sed -i "/file-max/d" /etc/sysctl.conf
sed -i "/nr_open/d" /etc/sysctl.conf
sed -i "/nf_conntrack_max/d" /etc/sysctl.conf
sed -i "/ip_conntrack_tcp_timeout_established/d" /etc/sysctl.conf
sed -i "/sysctl -w net.ipv4.netfilter.ip_conntrack_generic_timeout=120/d" /etc/sysctl.conf
echo "fs.file-max = 10000000" >> /etc/sysctl.conf
echo "fs.nr_open = 10000000">> /etc/sysctl.conf
echo "net.netfilter.nf_conntrack_max = 2000000">>/etc/sysctl.conf
echo "sysctl -w net.ipv4.netfilter.ip_conntrack_tcp_timeout_established=600">>/etc/sysctl.conf
echo "sysctl -w net.ipv4.netfilter.ip_conntrack_generic_timeout=120">>/etc/sysctl.conf
sysctl -p

# warning: restart host, config loss
echo "500224" > /sys/module/nf_conntrack/parameters/hashsize
mkdir /etc/modprobe.d
if [ ! -f  $CONTRACK_CONF_FILE ];then
    echo "" > $CONTRACK_CONF_FILE
else
    sed -i "/hashsize/d" $CONTRACK_CONF_FILE
	echo "options nf_conntrack hashsize=500224" >> $CONTRACK_CONF_FILE
fi




#udpate systemd-journald config
journald_status=$(systemctl status systemd-journald | grep -wi dead | cut -d":" -f1)
if [ ${journald_status}=="" ];then
mkdir /etc/systemd/
if [ ! -f "/etc/systemd/journald.conf" ];then
echo > /etc/systemd/journald.conf
fi
sed -i "/Storage=/d" /etc/systemd/journald.conf
sed -i "/RuntimeMaxUse=/d" /etc/systemd/journald.conf
sed -i "/MaxLevelStore=/d" /etc/systemd/journald.conf
echo "Storage=volatile" >> /etc/systemd/journald.conf
echo "RuntimeMaxUse=648K" >> /etc/systemd/journald.conf
echo "MaxLevelStore=err">> /etc/systemd/journald.conf
systemctl restart systemd-journald
fi

#start the mode of ovs match flow, ovs default enable megaflows
#warning: restart ovs, config loss
#vs-appctl upcall/disable-megaflows
#vs-appctl upcall/enable-megaflows

#set upcall pps limit, default 200000
#ovs-appctl upcall/set-flow-limit 200000

#the num of cpu for ovs-vswitchd, include handler thread and revalidator thread
uuid=$(ovs-vsctl list Open_Vswitch | grep -w _uuid | cut -d":" -f2)
ovs-vsctl set Open_Vswitch $uuid other_config:n-handler-threads=$HANDLER_NUM
ovs-vsctl set Open_Vswitch $uuid other_config:n-revalidator-threads=$REVALIDATOR_NUM
ovs-vsctl list Open_Vswitch
ovs-appctl upcall/show

#config netdev_max_backlog
sed -i "/net.core.netdev_max_backlog/d" /etc/sysctl.conf
sed -i "/net.core.rmem_max/d" /etc/sysctl.conf
sed -i "/net.core.wmem_max/d" /etc/sysctl.conf
sed -i "/net.core.rmem_default/d" /etc/sysctl.conf
sed -i "/net.core.wmem_default/d" /etc/sysctl.conf

echo "net.core.netdev_max_backlog" >> /etc/sysctl.conf
echo "net.core.rmem_max" >> /etc/sysctl.conf
echo "net.core.wmem_max" >> /etc/sysctl.conf
echo "net.core.rmem_default" >> /etc/sysctl.conf
echo "net.core.wmem_default" >> /etc/sysctl.conf


