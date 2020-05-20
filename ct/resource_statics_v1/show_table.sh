#!/bin/bash

sh resource-statics-dbhosts.sh

python generate_server_table.py
python generate_network_table.py

