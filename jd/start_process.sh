#!/bin/bash
env GOTRACEBACK=crash nohup /usr/local/bin/cc_controller /etc/cc_controller/vrouter.json >/var/log/cc_controller/app.log 2>&1 &