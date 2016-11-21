#!/bin/bash
su - stack<<EOF
exit;
EOF
cd /opt/stack/devstack
screen -c stack-screenrc
