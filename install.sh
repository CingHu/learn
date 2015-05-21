#!/bin/bash

tools=apt-get\ install\ -y


#test loss packet
$tools mtr

#test nic rate
$tools iftop

#hping3, much process
$tools hping3
