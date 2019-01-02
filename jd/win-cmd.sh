#!/bin/bash

#set -x

#FILE_PATH="c:\\\\va.ps1"
FILE_PATH="c:\\\\va.bat"
VM=$1
COMMAND=$2

FD=`virsh qemu-agent-command ${VM}  '{"execute":"guest-file-open", "arguments":{"path": "'${FILE_PATH}'", "mode": "a+"}}' | awk -F ":" '{print $2}' | awk -F "}" '{print $1}'`
echo "FD: $FD"

if [ ! $FD ]; then
    echo "[ERROR]  FD IS NULL"
    echo "[ERROR] qemu-ga can not create file in vm!"
    exit 1
fi

virsh qemu-agent-command ${VM} '{"execute": "guest-file-write", "arguments": {"handle": '${FD}', "buf-b64": "'${COMMAND}'"}}'

if [ $? -ne 0 ]; then
    echo "write file error"
    exit 1
fi

virsh qemu-agent-command ${VM} '{"execute":"guest-file-close", "arguments":{"handle":'${FD}'}}'

if [ $? -ne 0 ]; then
    echo "close file error"
    exit 1
fi

PID=`virsh qemu-agent-command ${VM} '{"execute": "guest-exec", "arguments": {"path": "'${FILE_PATH}'", "capture-output": true}}' | awk -F "\"pid\":" '{print $2}' | awk -F "}}" '{print $1}'`

echo "PID: $PID"
if [ ! $PID ]; then
    echo "[ERROR]  PID IS NULL"
    echo "[ERROR] qemu-ga can not exec process in vm!"
    exit 1
fi

MESSAGE=""

for((i=1;i<100;i++))
do
    if [ $i == 99 ]; then
        echo "get exec status timeout"
        RET=`virsh qemu-agent-command ${VM} '{"execute": "guest-exec", "arguments": {"path": "powershell", "capture-output": true, "arg": ["-ExecutionPolicy", "RemoteSigned", "-NonInteractive", "Stop-Process", "-Id", "'${PID}'", "-Confirm", "-PassThru", "-Force"]}}'`
	echo "${RET}"
        exit 1
    fi

    RETURN=`virsh qemu-agent-command ${VM} '{"execute": "guest-exec-status", "arguments": {"pid": '${PID}'}}'`
    if [ $? -ne 0 ]; then
        echo "exec status error"
        exit 1
    fi
    TRUE="true"
    result=$(echo $RETURN | grep "${TRUE}")
    if [  "$result" != "" ]; then
        echo "Script in VM  exit!"
	MESSAGE=${RETURN}
        break;
    fi
    sleep 1s
done

DELPID=`virsh qemu-agent-command ${VM} '{"execute": "guest-exec", "arguments": {"path": "C:\\\\Windows\\\\system32\\\\cmd.exe", "capture-output": true, "arg": ["/C", "del '${FILE_PATH}'"]}}' | awk -F "\"pid\":" '{print $2}' | awk -F "}}" '{print $1}'`

virsh qemu-agent-command ${VM} '{"execute": "guest-exec-status", "arguments": {"pid": '${DELPID}'}}'

echo "finished verify: ${MESSAGE}"

