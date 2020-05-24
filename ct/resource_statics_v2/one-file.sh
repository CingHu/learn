cat>ansible.cfg<<'EOF'
[defaults]
inventory      = ./hosts
forks          = 50
remote_port    = 10000
gathering = smart
roles_path    = ./roles
host_key_checking = False
log_path = ./ansible.log
bin_ansible_callbacks = True
nocows = 1
fact_caching = jsonfile
fact_caching_connection = ./facts
fact_caching_timeout = 360000000
retry_files_enabled = False
any_errors_fatal = True

EOF

cat>show_table.sh<<'EOF'
#!/bin/bash

server=$(cat hosts | grep kgc_server -A 3|sed -n '2p')
if [ ${server} = "" ];then
    echo "Error: ksc server is NULL"
    exit 1
fi

python generate_network_table.py

#echo "{}" > server.json
ansible $server  -m shell -a 'cat /tmp/server.json' | grep -v SUCCESS>server.json
content=$(cat server.json)
if [ "${content}" = "" ];then
     exit 1
fi


python generate_server_table.py
cp -f server.json server-${RANDOM}.json


EOF

cat>resource-statics-dbhosts.sh<<'EOF'
#!/bin/bash

sh ./generate_network_host.sh

> networks.json
echo "[" >> networks.json
ansible -i dbhosts network  -m copy -a 'src=./network-resource-statics.sh dest=/tmp/network-resource-statics.sh mode=755'
ansible -i dbhosts network  -m shell -a '/tmp/network-resource-statics.sh' |grep -v "SUCCESS"  >> networks.json
sed -i '$s/,//g' networks.json
echo "]" >> networks.json

server=$(cat hosts | grep kgc_server -A 3|sed -n '2p')
if [ ${server} = "" ];then
    echo "Error: ksc server is NULL"
    exit 1
fi

echo "$server">>kgc_server

#echo "{}" > server.json
ansible $server  -m copy  -a 'src=./server-db-statics.py dest=/tmp/server-db-statics.py mode=755'
ansible $server  -m shell -a 'echo {}>/tmp/server.json'
ansible $server -B 36000 -P 0  -m shell -a '/tmp/server-db-statics.py>/tmp/server.json'



EOF



cat>generate_network_host.sh<<'EOF'
#!/bin/bash

server=$(cat hosts | grep kgc_server -A 3|sed -n '2p')
if [ ${server} = "" ];then
    echo "Error: ksc server is NULL"
    exit 1
fi

echo "[all:vars]" > dbhosts
echo "ansible_ssh_user=secure" >> dbhosts
echo "ansible_become=yes">>dbhosts
echo "ansible_become_method=sudo">>dbhosts
echo "ansible_become_user=root">>dbhosts

echo "[network]" >> dbhosts

ansible $server  -m shell -a "source ~/admin-openrc.sh;openstack network agent list | grep '-network-' | cut -d'|' -f4|sed -e 's/\ //g'|awk -F"-" '{print \$NF}'|sed -e 's/e/./g'|sort|uniq" |grep -v "SUCCESS" >> dbhosts


EOF




cat>generate_server_table.py<<'EOF'
#!/usr/bin/python
#**coding:utf-8**
import sys
import json
import os

from prettytable import PrettyTable
from prettytable import MSWORD_FRIENDLY
from prettytable import PLAIN_COLUMNS
from prettytable import RANDOM
from prettytable import DEFAULT

reload(sys)
sys.setdefaultencoding('utf8')

def dict_chunk(dicts,size):
    new_list = []
    dict_len = len(dicts)
    # 获取分组数
    while_count = dict_len // size + 1 if dict_len % size != 0 else dict_len / size
    split_start = 0
    split_end = size
    while(while_count > 0):
    # 把字典的键放到列表中，然后根据偏移量拆分字典
        new_list.append({k: dicts[k] for k in list(dicts.keys())[split_start:split_end]})
        split_start += size
        split_end += size
        while_count -= 1
    return new_list

f = open('server.json')
resources = json.load(f, encoding='utf-8')

if not resources:
    print("file server.json is empty")
    sys.exit(0)

total_counter= resources['total_counter']
zones=total_counter.keys()
for zone in zones:
    if not total_counter[zone]:
        total_counter.pop(zone)

if not total_counter:
    print("file server.json total_counter is empty")
    sys.exit(0)

column_set=set()
zones=total_counter.keys()
for zone, value in total_counter.iteritems():
    for v in value.keys():
        column_set.add(v)

column=list(column_set)
column.sort()

row=["item/zone"]+zones
server_table = PrettyTable(row)
for c in column:
    zone_item=[]
    zone_item.append(c)
    for zone, value in total_counter.iteritems():
        counter=value.get(c, 0)
        zone_item.append(counter)
    server_table.add_row(zone_item)
print server_table

column_set=set()
host_counter= resources['host_counter']
for host, value in host_counter.iteritems():
    for v in value.keys():
        column_set.add(v)

column=list(column_set)
column.sort()

host_cunter_list=dict_chunk(host_counter, 20)

row=["host/item"]+column
for host_c in host_cunter_list:
    host_table = PrettyTable(row)
    for host, states in host_c.iteritems():
        zone_item=[]
        zone_item.append(host)
        for c in column:
            counter=states.get(c, 0)
            zone_item.append(counter)
        host_table.add_row(zone_item)
    #print host_table
    print host_table.get_string(sortby="Alive State", reversesort=True)



EOF




cat>generate_network_table.py<<'EOF'
#!/usr/bin/python
#**coding:utf-8**
import sys
import json
import os

from prettytable import PrettyTable
from prettytable import MSWORD_FRIENDLY
from prettytable import PLAIN_COLUMNS
from prettytable import RANDOM
from prettytable import DEFAULT

reload(sys)
sys.setdefaultencoding('utf8')


f = open('networks.json')
network_resource_list = json.load(f)

column=None
if network_resource_list:
   column = network_resource_list[0].keys()

if not column:
    print("can not find key from networks.json")
    sys.exit(0)

column.sort()
column.remove("host")

#split list
number=6
small_network_resource=[network_resource_list[i:i+number] for i in range(0, len(network_resource_list), number)]

#generator network table
for network_res in small_network_resource:
    network_table = PrettyTable()
    network_table.add_column('network node', column)
    for resource in network_res:
        host = resource.pop("host", None)
        values  = []
        for item in column:
            values.append(resource.get(item, None))
        network_table.add_column(host, values)
    network_table.set_style(DEFAULT)
    print network_table



EOF




cat>network-resource-statics.sh<<'EOF'
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

ls /var/lib/neutron/ha_confs/>/tmp/ha_confs
cf_count=`cat /tmp/ha_confs|grep -v pid|grep -v vrrp|wc -l`
echo "\"ha-conf\": $cf_count,"

q_count=`ip netns|grep qrouter-|wc -l`
echo "\"qrouter-ns\": $q_count,"

errorcounter=0
ps -ef>/tmp/processes
ip netns |grep snat  | awk '{print $1}'| sed -e 's/\ //g' -e 's/snat-//g'>/tmp/routers
exec 3</tmp/routers
while read -u3 router
do
counter=$(cat /tmp/processes | grep $router|wc -l)
if [ $counter -lt 3 ];then
    ((errorcounter+=1))
fi
done
exec 3<&-
echo "\"error-router\": $errorcounter,"

tail -n 20000 /var/log/neutron/openvswitch-agent.log > /tmp/ovs.log
total_count=$(tail -n 20000 /tmp/ovs.log|grep "Agent rpc_loop - iteration:" | grep "completed"|wc -l)
if [ $total_count -lt 1 ];then
    echo "\"ovs-agent\": \"X\","
else
#iteration_count=$(awk '{lines[NR]=$0} END{i=NR;while(i>0){print lines[i];-i} }' /tmp/ovs.log | grep "Agent rpc_loop - iteration:" | grep "completed" | head -n 1 | sed "s/.*iteration:\(.*\)\ completed.*/\1/")
iteration_count=$(cat /tmp/ovs.log | grep "Agent rpc_loop - iteration:" | grep "completed" | tail -n 1 | sed "s/.*iteration:\(.*\)\ completed.*/\1/")
if [ $iteration_count -lt 5 ];then
    echo "\"ovs-agent\": \"X\","
else
    echo "\"ovs-agent\": \":-)\","
fi
fi

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

#echo "\"time\":\"`date '+%Y-%m-%d %H:%M:%S'`\"},"
echo "\"ztime\":\"`date '+%Y-%m-%d'`\"},"


EOF



cat>server-db-statics.py<<'EOF'
#!/usr/bin/python2
# -*- coding: utf-8 -*-

import os
import json
import re
import subprocess

result_counter={}
tmp_host_counter={}
result_host_counter={}
host_agent={}

#return zone_routers[zone_name]=[agent]
def get_agents():
    #get all agents
    zone_agents={}
    cmd='source ~/admin-openrc.sh;openstack network agent list -f json'
    result=os.popen(cmd).read()
    try:
        agents=json.loads(result)
    except:
        #print("Error: %s" % cmd)
        return
    for agent in agents:
        host = agent.get("Host")
        if not host:
            continue
        if len(host.split("-")) < 3:
            agent["Type"]="Unknown"
        else:
            agent["Type"]=host.split("-")[1]

        zone = agent.get('Availability Zone', "Default")
        if zone not in zone_agents.keys():
            zone_agents[zone] = []
            result_counter[zone]={}
        else:
            zone_agents[zone].append(agent)
    return zone_agents

def get_agent_counter(zone_agents):
    for zone, agents in zone_agents.iteritems():
        zone_counter=result_counter[zone]
        for agent in agents:
            host = agent.get("Host")
            if not host:
                continue
            zone = agent.get('Availability Zone', "Default")
            if not tmp_host_counter.get(host, None):
                agent_type = agent.get("Agent Type", "NULL")
                tmp_host_counter[host] = {'Alive State':":-)", 'Admin State':":-)", "Host Type":agent["Type"], "Zone":zone}
            if agent.get("Binary") == "neutron-l3-agent":
                tmp_host_counter[host]["Zone"]=zone
            host_info = tmp_host_counter[host]
            if agent['Alive'] != ":-)":
                agent_type = agent.get("Agent Type", "NULL")
                agent_type += " Alive Down"
                if agent_type not in zone_counter.keys():
                    zone_counter[agent_type] = 0
                else:
                    zone_counter[agent_type]+=1
                host_info['Alive State'] = "X"
            if agent['State'] != "UP":
                agent_type = agent.get("Agent Type", "NULL")
                agent_type += " Admin Down"
                if agent_type not in zone_counter.keys():
                    zone_counter[agent_type] = 0
                else:
                    zone_counter[agent_type]+=1
                host_info['Admin State'] = "X"
        result_counter[zone]=zone_counter

def get_routers(zone_agents):
    #all routers of l3-agent
    zone_routers={}
    for zone, agents in zone_agents.iteritems():
        if zone not in zone_routers.keys():
            zone_routers[zone] = []
        for agent in agents:
            host = agent.get("Host")
            if not host:
                continue

            host_info = tmp_host_counter[host]
            if agent.get("Binary") != "neutron-l3-agent":
                continue

            if "network" not in host:
                continue

            cmd='source ~/admin-openrc.sh;neutron router-list-on-l3-agent %s -f json' % agent['ID']
            result=os.popen(cmd).read()
            try:
                r=json.loads(result)
            except:
                #print("Error: %s" % cmd)
                continue
            #result=subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            #r=json.loads(result.stdout.read())
            #result.wait()
            #if result.returncode != 0:
            #    continue
            host_info['Router Number']=len(r)
            zone_routers[zone]=zone_routers[zone]+r
            continue
            if agent.get("Binary") != "neutron-l3-agent":
                continue
            cmd='source ~/admin-openrc.sh;openstack agent show %s -f json' % agent['ID']
            result=os.popen(cmd).read()
            try:
                agent=json.loads(result)
            except:
                #print("Error: %s" % cmd)
                continue

            host={}
            host['host'] = agent.get('host', "ERROR NULL HOST")
            host['availability_zone'] = agent.get('availability_zone', "NULL")
            host['alive'] = agent.get('alive')
            host['admin_state_up'] = agent.get('admin_state_up')
            host_list.append(host)
    return zone_routers

def get_router_state_count(zone_routers):
    #ha_state and zone
    for zone, routers in zone_routers.iteritems():
        zone_counter=result_counter[zone]
        alive_error=0
        admin_state_up_error = 0
        router_number_error = 0
        router_ha_state_error = 0
        total_router = 0
        for router in routers:
            total_router+=1
            #if total_router > 5:
            #    break
            #print("list router :%s " % router["id"])
            cmd='source ~/admin-openrc.sh;openstack network agent list --router %s --long -f json' % router["id"]
            result=os.popen(cmd).read()
            try:
                router_info=json.loads(result)
            except:
                #print("Error: %s" % cmd)
                continue
            if len(router_info) != 2:
                router_number_error+=1
            ha_state=[]
            ha_state=[r.get('HA State', None) for r in router_info]
            ha_state.sort()
            if cmp(ha_state, ["active", "standby"]) != 0:
                router_ha_state_error+=1

            for r in router_info:
                if r.get("Alive",None) != ":-)":
                    alive_error+=1
            for r in router_info:
                if r.get("State", "DOWN") != "UP":
                    admin_state_up_error+=1
        if len(routers) != 0:
            zone_counter['Router Alive Down'] = alive_error
            zone_counter['Router Admin State Down'] = admin_state_up_error
            zone_counter['Router Number Error'] = router_number_error
            zone_counter['Router HA State Error'] = router_ha_state_error
            zone_counter['Router Total Counter'] = total_router

        result_counter[zone]=zone_counter

def handler_host_couter():
    for host, states in tmp_host_counter.items():
        if 'network' in host:
            tmp_host=host.split('-')[-1].replace("e",".")
            result_host_counter[tmp_host]=states
        if re.findall(r'(\w){8}-(\w){4}-(\w){4}-(\w){4}-(\w){12}', host):
            tmp_host=host.split("-")[-1]
            result_host_counter[tmp_host]=states

def handler_total_counter():
    total_counter= result_counter
    zones=total_counter.keys()
    total={}
    for zone in zones:
        if not total_counter[zone]:
            total_counter.pop(zone)
    for zone, states_dict in total_counter.iteritems():
        for item, counter in states_dict.iteritems():
            if item not in total.keys():
                total[item] = counter
            else:
                total[item]+=counter
    total_counter["total"]=total

def get_fip_counter():
    cmd='source ~/admin-openrc.sh;openstack port list --network ext-net --device-owner network:floatingip -f json'
    result=os.popen(cmd).read()
    try:
        fips=json.loads(result)
    except:
        #print("Error: %s" % cmd)
        return
    result_counter["total"]["Fip Counter"] = len(fips)

def main():
    zone_agents = get_agents()
    get_agent_counter(zone_agents)
    zone_routers = get_routers(zone_agents)
    get_router_state_count(zone_routers)
    handler_host_couter()
    handler_total_counter()
    get_fip_counter()
    result={'total_counter':result_counter, 'host_counter':result_host_counter}
    print(json.dumps(result))

if __name__ == '__main__':
    main()


EOF

chmod +x generate_network_table.py network-resource-statics.sh server-db-statics.py show_table.sh resource-statics-dbhosts.sh generate_server_table.py generate_network_host.sh

echo "finished"
