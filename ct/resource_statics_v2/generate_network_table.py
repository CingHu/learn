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



