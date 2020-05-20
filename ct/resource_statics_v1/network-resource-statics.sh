#!/bin/bash

host=`hostname|awk -F"-" '{print $NF}'|sed -e 's/e/./g'`
echo "{\"host\": \"$host\","

zone=`cat /etc/neutron/l3_agent.ini | grep availability_zone|cut -d"=" -f2|sed -e "s/\ //g"`
if [ "${zone}" = "" ];then
    zone="nova"
fi
echo "\"zone\": \"$zone\","

s_count=`ps -ef|grep neutron-keepalived-state-chang|grep -v grep|wc -l`
echo "\"keealived-state\": $s_count,"

m_count=`ps -ef|grep "ip -o monitor"|grep -v grep|wc -l`
echo "\"ip-monitor\": $m_count,"

cf_count=`ls /var/lib/neutron/ha_confs/|grep -v pid|grep -v vrrp|wc -l`
echo "\"ha-conf\": $cf_count,"

q_count=`ip netns|grep qrouter-|wc -l`
echo "\"qrouter-ns\": $q_count,"

n_count=`ip netns|grep snat|wc -l`
echo "\"snat-ns\": $n_count,"

fip_ns_count=`ip netns|grep fip|wc -l`
echo "\"fip-ns\": $fip_ns_count,"

proxy_count=`ps -ef|grep ns-metadata-proxy|grep -v grep|wc -l`
echo "\"meta-proxy\": $proxy_count,"

radvd_count=`ps -ef|grep radvd|grep -v grep|wc -l`
echo "\"radvd\": $radvd_count,"

master=`grep master -R /var/lib/neutron/ha_confs/|grep -v change |grep -v keepalived|wc -l`
echo "\"master\": $master,"

backup=`grep backup -R /var/lib/neutron/ha_confs/|grep -v change |grep -v keepalived|wc -l`
echo "\"backup\": $backup,"

k_count=`ps -ef|grep keepalived|grep -v grep|grep -v change|wc -l`
echo "\"keepalived\": $k_count,"

ng_count=`ps -ef|grep " nginx -c"|grep -v grep |wc -l`
echo "\"nginx\": $ng_count,"

ip netns |grep snat  | awk '{print $1}'| xargs -i ip netns exec {} ip a > /tmp/result.log
fip_count=$(cat /tmp/result.log|grep qg- | grep inet | grep -v "inet 10" | awk '{print $2}'|wc -l)
echo "\"floatingip\": $fip_count,"

echo "\"ztime\":\"`date '+%Y-%m-%d'`\"},"

