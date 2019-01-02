#!/bin/bah

#huabei
sg="sg-w6p6iv7514"
subnet="subnet-53l9z1vt9q"
vpc="vpc-p7c75bzuf6"
linux_image="37a8c8e7-b9fc-4b02-97bb-4eabb77ec5a4"
userid="421660a9e5f84a91968a5b43a9faab7e"
az="prod_bj02"

image=$win_image

#shanghai
#subnet="subnet-n3xskw6h8m"
#sg="sg-cz7vcn2mkm"
#vpc="vpc-kythrx7r6s"
#userid="926c6fe8e423410a9f6117025d22d983"
#linux_image="8989b9bf-8f8e-41aa-962e-ff9ea4f0a248"

#jcs dpdk
#host="172.19.24.114"
if [ "$host" == "" ];then
    jvirt  instance-create $1 --availability-zone $az --count 1 --description test  --image $image    --instance-type c.n1.xlarge   --network subnet-id=$subnet,security-group=$sg --password 1qaz@WSX --system-disk disk-type=local,size=30  --vpc $vpc --user-id $userid
else
    jvirt instance-create $1 --availability-zone $az --count 1 --description test  --image  $image    --instance-type c.n1.xlarge  --network subnet-id=$subnet,security-group=$sg --password 1qaz@WSX --system-disk disk-type=local,size=30  --vpc $vpc --include-hosts $host --user-id $userid
fi

