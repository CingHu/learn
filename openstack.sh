#########################################################################
# File Name: openstack.sh
# Author: huxining
# mail: yige2008123@126.com
# Created Time: 2015年05月28日 星期四 18时54分52秒
#########################################################################
#!/bin/bash 

1. nova vnc config
vncserver_proxyclient_address = 0.0.0.0
vnc_enabled = true
vncserver_listen=0.0.0.0
novncproxy_host=0.0.0.0
novncproxy_port=6080
#xvpvncproxy_base_url = http://192.168.10.8:6081/console
novncproxy_base_url = http://192.168.10.8:6080/vnc_auto.html


