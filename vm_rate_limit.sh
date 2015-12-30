#!/bin/bash


URL="127.0.0.1:9696"
TIME_OUT=5
FAIL_PORT=""

#export PS4='+{$LINENO:${FUNCNAME[0]}}'
#set -x

remove_vm_rate_limte() 
{
  if [ $# -ne 1 ];then
      echo "WARN: remove rate limte inpute param error"
      return
  fi
  
  if [ -z $1 ];then
      echo "WARN: inpute param is NULL"
      return
  fi

  echo "remove rate limit, port is "$1

  curl --connect-timeout $TIME_OUT  -i 'http://'${URL}'/v2.0/ports/'${port}'.json' -X PUT -H "X-Auth-Token: $token" -H "Content-Type: application/json" -H "Accept: application/json" -H "User-Agent: python-neutronclient" -d '{"port": {"binding:profile": {"uos_pps_limits":[]}}}'
  if [ $? -ne 0 ];then
      echo "<<<<<ERROR: remove port "$1" fail"
      FAIL_PORT=$FIAL_PORT" "$1
      return
  fi
}

add_vm_rate_limte() 
{
  if [ $# -ne 1 ];then
      echo "WARN: remove rate limte inpute param error"
      return
  fi
  
  if [ -z $1 ];then
      echo "WARN: inpute param is NULL"
      return
  fi

  echo "add rate limit, port is "$1

  curl --connect-timeout $TIME_OUT -i 'http://'${URL}'/v2.0/ports/'${port}'.json' -X PUT -H "X-Auth-Token: $token" -H "Content-Type: application/json" -H "Accept: application/json" -H "User-Agent: python-neutronclient" -d '{"port": {"binding:profile": {"uos_pps_limits":["tcp:syn:80:10000", "udp::53:10000"]}}}'

  if [ $? -ne 0 ];then
      echo "<<<<<ERROR: add port "$1" fail"
      FAIL_PORT=$FIAL_PORT" "$1
      return
  fi
}


result_check()
{
    if [ -z $FAIL_PORT ];then 
        echo
        echo "=========all port execute sucess============"
    else
        echo
        echo "<<<<<<<ERROR: execute error port:"
        echo $FIAL_PORT 
    fi
    
}

usage()
{
   echo "usage: $0 <action> [port]" 
   echo 
   echo "ACTION: <add|remove>"
   echo 
   echo "PORT: <all|port_id|port_name>"
   echo "Example: $0 add f8db72f1-5afd-41cc-a388-3f5df30e842c"
   echo "Example: $0 add all"
}


process_port()
{
   port=$2
   method=$1
   echo "process port: " $port
   $method $port
}


main()
{
    if [ $# -ne 2 ];then
        usage;exit 0
    fi

    token=$(keystone token-get | grep -w id  | awk -F"|" '{print $3}')
    if [ -z $token ];then
       echo "============================="
       echo "ERROR: can not get token, exit"
       exit 0
       echo "============================="
    fi
    case $1 in
        "add")
            case $2 in
                "all")
                  port_list=$(neutron port-list --device-owner=compute:None |grep -vw id|awk -F "|" '{print $2}'|sort -n)
                  for port in $port_list;do
                     process_port add_vm_rate_limte $port
                  done
                  ;;
                *)
                  process_port add_vm_rate_limte $2
                  ;;
             esac
           ;;
        "remove")
            case $2 in
                "all")
                  port_list=$(neutron port-list --device-owner=compute:None |grep -vw id|awk -F "|" '{print $2}'|sort -n)
                  for port in $port_list;do
                     process_port remove_vm_rate_limte $port
                  done
                  ;;
                *)
                  process_port remove_vm_rate_limte $2
                  ;;
             esac
           ;;
        esac
    
    #outpute result
    result_check
}

main $1 $2




eeeeee
