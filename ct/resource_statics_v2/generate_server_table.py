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

row_num=0
row=["host/item"]+column
host_table = PrettyTable(row)
for host, states in host_counter.iteritems():
    zone_item=[]
    zone_item.append(host)
    row_num+=1
    for c in column:
        counter=states.get(c, 0)
        zone_item.append(counter)
    if row_num == 20:
        row_num = 0
        host_table.add_row(row)
    host_table.add_row(zone_item)
#print host_table
print host_table.get_string(sortby="Alive State", reversesort=True)



