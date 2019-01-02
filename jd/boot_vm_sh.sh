#!/bin/bah

sg="sg-b568maon0v"
subnet="subnet-mbhe17ppzn"
vpc="vpc-royn7brl4i"
linux_image="89d5d421-12a5-45d3-af9e-1b7b6cff5fd1"

host="172.19.23.98"
if [ "$host" == "" ];then
    jvirt --debug   instance-create $1 --availability-zone prod_bj02 --count 1 --description test  --image $linux_image    --instance-type T1-1C1G0G  --network subnet-id=$subnet,security-group=$sg --password 1qaz@WSX --system-disk disk-type=local,size=40  --vpc $vpc
else
    jvirt --debug   instance-create $1 --availability-zone prod_bj02 --count 1 --description test  --image  $linux_image    --instance-type T1-1C1G0G  --network subnet-id=$subnet,security-group=$sg --password 1qaz@WSX --system-disk disk-type=local,size=40  --vpc $vpc --include-hosts 172.19.23.98
fi
