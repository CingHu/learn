#!/usr/bin/env bash

# Script to dump recent N flows
USAGE="""
\033[1m Tool used to to dump recent N flows in ovs runtime\n \033[0m
Usage: ovs-recent-flows [-n NUM]\n
\n
[Options]
    -n \tCount of flows to dump, dump all flows if no this option
\n
"""
Count=0
while getopts "n:h" arg
do
        case $arg in
             n)
                Count=$OPTARG
                ;;
             h)
                echo -e $USAGE
                exit 0
                ;;
             ?)
                echo "unkonw option '-$arg'"
                echo -e $USAGE
                exit 1
        ;;
        esac
done

command="ovs-ofctl dump-flows -O openflow13 br0 | grep "cookie=0x" | sed  's/[ \t]//g' | sed 's/^.*duration=\([0-9\.]\+\)s,.*$/\1 \0/' | sort -n  | awk '{print \$2}'"

if [[ $Count -eq 0 ]];then
    eval $command
else
    eval $command | head -n $Count
fi