#!/bin/bash

RED='\e[1;31m'
NC='\e[0m'


function perror()
{
	echo -e "${RED} ===============================Error=================================== ${NC}"
	echo -e "${RED} Error: $@ ${NC}"
	exit 1
}

function pnerror()
{
	echo -e "${RED} ===============================Error=================================== ${NC}"
	echo -e "${RED} Error: $@ ${NC}"
}

function pinfo()
{
	echo "Info: $@"
}

function pcheck()
{
	echo "Check: $@"
}

function check_str_null()
{
	if [ "$2" == "" ];then
		pnerror "$1"
	fi
}

function exit_str_null()
{
	if [ "$2" == "" ];then
		perror "$1"
	fi
}

CCC_CONFIG="/etc/cc_controller/bgw.json"
function file_check ()
{
	if [ ! -f "$CCC_CONFIG" ];then
		CCC_CONFIG=`echo $CCC_CONFIG_FILE`
	fi

	if [ ! -f "$CCC_CONFIG" ];then
    	perror "Please define CCC_CONFIG_FILE environment variable, example: export CCC_CONFIG_FILE=/etc/cc_controller/bgw.json"
	fi
}

CC_SERVER_URL="http://cc-server.bj02.jcloud.com/cc-server"

function init_cc_url()
{
	CC_SERVER_URL=`cat $CCC_CONFIG | grep HeartBeatUrl | awk -F '"' '{print $4}' | awk -F '?' '{print $1}' `
	exit_str_null "cc-server not found" $CC_SERVER_URL
}

HOST_UNDERLAY_IP=""
HOST_NAME=`hostname`
function get_cur_host_underlayip()
{
	HOST_UNDERLAY_IP=`curl -s -X POST $CC_SERVER_URL?Action=DescribeHosts -H 'Content-Type: application/json' -H 'User-Agent: CcClient' -H 'Trace-Id: 5b393xnf8b' -H 'Secret-Id: CcClientSecretId' -d "{\"filter\":[{\"field\":\"name\",\"value\":\"$HOST_NAME\"}],\"orders\":null,\"desc_offset\":0,\"desc_limit\":-1}" 2>/dev/null | jq .data.elements[0].ip.underlay | awk -F'"' '{print $2}'`
	exit_str_null "underlay ip cannot find" $HOST_UNDERLAY_IP
	if [ "$HOST_UNDERLAY_IP" == "null" ]; then
	    perror "cannot get underlay ip"
	fi
}

declare -A VR_DR_IPS=()

function get_all_vr_dv_ip()
{
	resp=`curl -s -X POST $CC_SERVER_URL?Action=DescribeHosts -H 'Content-Type: application/json' -H 'User-Agent: CcClient' -H 'Trace-Id: wmbcl3hoaa' -H 'Secret-Id: CcClientSecretId' -d '{"filter":[{"field":"type","value":1}],"orders":null,"desc_offset":0,"desc_limit":-1}'`
	data=`echo $resp | jq .data.elements`
	length_ret=`echo $resp | jq '.data.elements|length'`
	for index in `seq 0 $length_ret`
		do
		item=`echo $data | jq .[$index]`
	    if [ "$item" != "null" ]; then
		    VR_DR_IPS[`echo $item | jq .name`]=`echo $data | jq .[$index].ip.dv | awk -F'"' '{print $2}'`;
		fi
	done
}

function ping_vr_dv()
{
	for key in ${!VR_DR_IPS[@]}
	do
		ret=`vrcli ping 1115 0 $HOST_UNDERLAY_IP ${VR_DR_IPS[$key]}` 
	done
	sleep 1
	for key in ${!VR_DR_IPS[@]}
	do
	    ret=`vrcli ping_rcv 1115 0 $HOST_UNDERLAY_IP ${VR_DR_IPS[$key]}`
		if [ "''" == "$ret" ]; then
		    pnerror "ping ${VR_DR_IPS[$key]} fail, cmd: vrcli ping 1115 0 $HOST_UNDERLAY_IP ${VR_DR_IPS[$key]}"
		else
		    pinfo "ping ${VR_DR_IPS[$key]} succ"
		fi
	done
}

declare	-A BGW_DLR_TUNS
declare	-A DLR_BGW_TUNS

function get_bgw_dlr_gre()
{
	gre_ret=`vrcli gre_tun_list | sed -e 's/\[//g' | sed -e 's/\]//g' | sed -e 's/ //g'`
	for line in $gre_ret
	do
		idxx=`echo $line | awk -F "'" '{print $6}'`
		localIp=`echo $line | awk -F "'" '{print $2}'`
		dlrIp=`echo $line | awk -F "'" '{print $4}'`
		BGW_DLR_TUNS[`echo $idxx`]=$localIp
		DLR_BGW_TUNS[`echo $idxx`]=$dlrIp
	done
}

function check_bgw_dlr_gre()
{
	get_bgw_dlr_gre
	for key in ${!BGW_DLR_TUNS[@]}
	do
		ret=`vrcli ping 1115 0 ${BGW_DLR_TUNS[$key]} ${DLR_BGW_TUNS[$key]}`
	done
	sleep 1
	for key in ${!BGW_DLR_TUNS[@]}
	do
		ret=`vrcli ping_rcv 1115 0 ${BGW_DLR_TUNS[$key]} ${DLR_BGW_TUNS[$key]}`
		if [ "''" == "$ret" ]; then
			pnerror "ping ${BGW_DLR_TUNS[$key]} fail, cmd: vrcli ping 1115 0 ${BGW_DLR_TUNS[$key]} ${DLR_BGW_TUNS[$key]}"
		else
			pinfo "ping ${BGW_DLR_TUNS[$key]} succ"
		fi
	done
}

function main()
{
	file_check
	init_cc_url
	get_cur_host_underlayip
	get_all_vr_dv_ip
	ping_vr_dv
	check_bgw_dlr_gre
}

main
