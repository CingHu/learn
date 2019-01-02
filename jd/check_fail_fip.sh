failfip=fail_fips
TIMEOUT=3

declare -A HOSTIPS=()

function check_server_floatingip() 
{
    local fip_addr=$1

    ccs floatingip-list  --floatingip_address $fip_addr -a > "$PATHINFO/fiplist"
    local portid=$(cat $PATHINFO/fiplist | grep port- | cut -d"|" -f7 |sed -e "s/\ //g" -e "s/\"//g")
    if [ "$portid" == "" ];then
        echo "Error: $fip_addr can not binding port"
    else
        isup=$(ccs floatingip-list --floatingip_address $fip_addr -c admin_status_up -a | grep true)
        if [ "$isup" == "" ];then
            echo "Error:admin status of floatingip $fip_addr is down"
            return
        fi
        portup=$(ccs port-list --ids  $portid -a -c state | grep up)
        if [ "$portup" == "" ];then
            echo "Error:status of port $portid in $fip_addr is down"
            return
        fi
        echo "OK: $fip_addr port status and fip admin status is ok"
    fi

}

function get_server_floatingip() 
{
    local fip_addr=$1

    ccs floatingip-list  --floatingip_address $fip_addr -a > "$PATHINFO/fiplist"
    local portid=$(cat $PATHINFO/fiplist | grep port- | cut -d"|" -f7 |sed -e "s/\ //g" -e "s/\"//g")
    if [ "$portid" == "" ];then
        echo "Error: $fip_addr can not binding port"
    else
        host=$(ccs port-list -c HostIds --ids $portid -a |  grep host |sed -e "s/\ //g" -e "s/\"//g" -e "s/|//g" -e "s/\]//g" -e "s/\[//g")
        echo "Info: $fip_addr binding port host $host"
        mngip=$(ccs host-show -a $host | grep MgmtAddr | cut -d"|" -f3 |sed -e "s/\ //g")
        HOSTIPS[$host]="$mngip,$portid"
    fi

}

function startcpdump()
{
    for ip_port in `echo ${HOSTIPS[@]}`
    do
        ip=$(echo $ip_port|cut -d"," -f1)
        port=$(echo $ip_port|cut -d"," -f2)
        echo "$ip start tcpdump"
        timeout "${TIMEOUT}s" ssh -o StrictHostKeyChecking=no root@$ip "tcpdump -i $port -c 30 -w $port.pcap"
    done
}

function checktcpdump()
{
    for ip_port in `echo ${HOSTIPS[@]}`
    do
        ip=$(echo $ip_port|cut -d"," -f1)
        port=$(echo $ip_port|cut -d"," -f2)
        echo ""
        echo ""
        echo "=====================$ip check tcpdump start =============="
        ssh -o StrictHostKeyChecking=no root@$ip "tcpdump -r $port.pcap -ennnvvv -P in"
        echo "****************************************************************************"
        ssh -o StrictHostKeyChecking=no root@$ip "tcpdump -r $port.pcap -ennnvvv -P out"
        echo "=====================$ip check tcpdump end =============="
    done
}

function killtcpdump()
{
    for ip_port in `echo ${HOSTIPS[@]}`
    do
        ip=$(echo $ip_port|cut -d"," -f1)
        port=$(echo $ip_port|cut -d"," -f2)
        echo "$ip kill tcpdump"
        ids=$(ssh -o StrictHostKeyChecking=no root@$ip "pidof tcpdump")
        if [ "$ids" != "" ];then
            ssh -o StrictHostKeyChecking=no root@$ip "echo $ids| xargs kill -9"
        fi
    done
}

function exec_check()
{
    while read line
    do
        check_server_floatingip $line
    done < $failfip
}

function exec_tcpdump()
{
    while read line
    do
        get_server_floatingip $line
    done < $failfip
    startcpdump
    sleep 10
    checktcpdump
    killtcpdump
}

while getopts "hft" arg
do
        case $arg in
             f)
                echo "exec check"
                exec_check 
                ;;
             t)
                echo "exec tcpdump"
                exec_tcpdump
                ;;
             ?|h)
                echo "unkonw input argument"
                echo "$0 -f     check fip status"
                echo "$0 -t     check fip port tcpdump"
                exit 1
                ;;
        esac
done

