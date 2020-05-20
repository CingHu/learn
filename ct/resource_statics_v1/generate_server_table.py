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
resources = json.load(f)

if len(resources) == 0:
    print("file server.json is empty")
    sys.exit(0)

column=resources.keys()

if not column:
    print("can not find key from networks.json")
    sys.exit(0)

column.sort()

#generator network table
server_table = PrettyTable()
server_table.add_column('server 资源', column)
values  = []
for item in column:
    values.append(resources.get(item, None))
server_table.add_column("count", values)
server_table.set_style(DEFAULT)
print server_table
