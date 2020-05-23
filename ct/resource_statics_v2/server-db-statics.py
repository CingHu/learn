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
            if not tmp_host_counter.get(host, None):
                agent_type = agent.get("Agent Type", "NULL")
                tmp_host_counter[host] = {'Alive State':":-)", 'Admin State':":-)", "Host Type":agent["Type"]}
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


