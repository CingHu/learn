#!/bin/bash

LOGDIR=/var/log/tcpdumpd
SIZE=1G
COUNT=4
FILTER="host $(/bin/hostname)"
IFACE=eth0
PIDFILE=/var/run/tcpdumpd.pid
LOCKFILE=/var/lock/subsys/tcpdumpd

if [ -f /etc/sysconfig/tcpdumpd ]; then
. /etc/sysconfig/tcpdumpd
fi

TIMESTAMP=$(
/bin/date '+%Y%m%d%H%M%S-'
)

RETVAL=1

start(){
/bin/mkdir -p "${LOGDIR}"
/bin/chown pcap:pcap "${LOGDIR}"
/usr/sbin/tcpdump\
-C "${SIZE}"\
-W "${COUNT}"\
-w "${LOGDIR}/${TIMESTAMP}"\
-i "${IFACE}"\
${FILTER}\
&
echo $! >"${PIDFILE}"
touch "${LOCKFILE}"
return 0
}

stop(){
/bin/kill -TERM $(cat "${PIDFILE}") 2>/dev/null
/bin/rm "${PIDFILE}" "${LOCKFILE}" 2>/dev/null
return 0
}

case "${1}" in
start )
start
RETVAL=$?
;;
stop )
stop
RETVAL=$?
;;
restart )
stop
sleep 2
start
RETVAL=$?
;;
status )
if [ ! -f "${LOCKFILE}" ]; then
echo 'tcpdumpd is not running.'
else
thePid=$(cat "${PIDFILE}")
/bin/kill -s 0 "${thePid}"
case "$?" in
1 )
echo "Lockfile exists, but tcpdumpd is dead."
stop
;;
0 )
echo "tcpdumpd is running on PID ${thePid}."
RETVAL=0
esac
fi
;;
condrestart )
if [ -f "${LOCKFILE}" ]; then
restart
RETVAL=0
fi
;;
* )
echo "usage: $0 start|stop|status|restart|condrestart" >&2
;;
esac
exit ${RETVAL}
