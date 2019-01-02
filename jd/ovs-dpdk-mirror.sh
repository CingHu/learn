#!/bin/bash

BRIDGE=br0
PORTID=$1
MIRRORNAME=br0
MIRRORPORT=br0

ovs-vsctl clear Bridge br0 mirrors
ovs-vsctl -- set bridge $BRIDGE mirrors=@m -- --id=@$PORTID get Port $PORTID -- --id=@$MIRRORPORT get Port $MIRRORPORT -- --id=@m create Mirror name=$MIRRORNAME select-dst-port=@$PORTID select-src-port=@$PORTID output-port=@$MIRRORPORT
ifconfig br0 up
