#!/bin/bash
allfip=$(cat all_vs_node.txt)

for line in $allfip
do
echo $line
all=$(ssh -o StrictHostKeyChecking=no root@${line}  ps -ef|grep -w tcpdump | grep -v grep | awk '{print $2}')
for a in $all
do
echo "kill $a"
ssh -o StrictHostKeyChecking=no root@${line} kill -9 ${a}
done

done
