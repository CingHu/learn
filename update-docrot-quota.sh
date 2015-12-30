#########################################################################
# File Name: /root/tmp/update-docrot-quota.sh
# Author: huxining
# mail: yige2008123@126.com
# Created Time: 2015年05月22日 星期五 16时35分19秒
#########################################################################
#!/bin/bash 
for cluster in hlgw mm shzh xd hyjt qn sp zhj lg sh zhsh ghxw sjhl; do echo $cluster":"; clush -g $cluster"_api" --copy update-doctor-quota.sh --dest /root/ ;clush -g $cluster"_api" "sh /root/update-doctor-quota.sh && rm /root/update-doctor-quota.sh";done""""""""
