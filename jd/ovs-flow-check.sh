#!/usr/bin/env bash
# Script to diff flow in controller cache and ovs runtime
USAGE="""
\033[1m Tool used to diff flows between cc_controller's cache and ovs runtime\n \033[0m
Usage: ovs-flow-check [-i id[,id[,...]]\n
\n
[Options]
    -i \tID to check, check all flows if no this option
\n
"""
resourceId=""
while getopts "i:h" arg
do
        case $arg in
             i)
                resourceId=$OPTARG
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
CCCOpt=""
if [[ "X$resourceId" != "X" ]];then
    CCCOpt="--ids $resourceId"
fi
# flow must be format like "^cookie=0x[0-9a-f],.*$"
expect_flows=`ccc ovs-flows-detail $CCCOpt | grep "cookie=0x" | sed  's/[ \t]//g' | sed 's/^.*\(cookie=0x[0-9a-f]\+\)\(,.*\)$/\1\2/'`
runtime_flows=`ovs-ofctl dump-flows -O openflow15 br0 | grep "cookie=0x" | sed  's/[ \t]//g' | sed 's/^.*\(cookie=0x[0-9a-f]\+\)\(,.*\)$/\1\2/'`

# map for flows, map[cookie=xxx] = flow
expect_flow_map=()
runtime_flow_map=()
for flow in $expect_flows;
do
    expect_flow_map["${flow%%,*}"]="$flow"
done

for flow in $runtime_flows;
do
    runtime_flow_map["${flow%%,*}"]="$flow"
done

# diff
ret=0
if [[ "X$resourceId" != "X" ]];then
    echo "Expected (`echo ${#expect_flow_map[@]}` flows)"
else
    echo "Different flows between expected (`echo ${#expect_flow_map[@]}` flows) and runtime(`echo ${#runtime_flow_map[@]}` flows)"
fi

for cookie in ${!expect_flow_map[*]};
do
    if [[ "X${runtime_flow_map[$cookie]}" == "X" ]]; then
        echo -e "\e[1;31m> ${expect_flow_map[$cookie]}\e[0m"
        ret=1
    fi
done

if [[ "X$resourceId" == "X" ]];then
    for cookie in ${!runtime_flow_map[@]};
    do
        if [[ "X${expect_flow_map[$cookie]}" == "X" ]]; then
            echo -e "\e[1;31m< ${runtime_flow_map[$cookie]}\e[0m"
            ret=1
        fi
    done
fi

if [[ $ret == 0 ]];then
    echo -e "\e[1;31mNothing different\e[0m"
fi

exit $ret