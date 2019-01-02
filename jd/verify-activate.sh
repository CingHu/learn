#!/bin/bash

#set -x

FILE_PATH="c:\\\\va.ps1"
VM=$1

FD=`virsh qemu-agent-command ${VM}  '{"execute":"guest-file-open", "arguments":{"path": "'${FILE_PATH}'", "mode": "a+"}}' | awk -F ":" '{print $2}' | awk -F "}" '{print $1}'`
echo "FD: $FD"

if [ ! $FD ]; then
    echo "[ERROR]  FD IS NULL"
    echo "[ERROR] qemu-ga can not create file in vm!"
    exit 1
fi

virsh qemu-agent-command ${VM} '{"execute": "guest-file-write", "arguments": {"handle": '${FD}', "buf-b64": "dHJ5IHsNCiAgICAkc2xtZ3Jfc3RhdHVzID0gJiBjc2NyaXB0IC8vbm9sb2dvIEM6L1dpbmRvd3Mvc3lzdGVtMzIvc2xtZ3IudmJzIC9kbGkNCn0NCmNhdGNoIHsNCiAgICBXcml0ZS1Ib3N0ICgiRXhjZXB0aW9uIGhlcmUgd2hlbiB2ZXJpZnkgYWN0aXZhdGVkIHN0YXR1cywgezB9IiAtZiAkXy5FeGNlcHRpb24uTWVzc2FnZSkNCiAgICBFeGl0IDINCn0NCg0KIyB1c2UgdG1wIGZpbGUgdG8gc3RvcmUgb3V0cHV0IG9mIHJlZ2lzdGVyIGluZm8NCiR0bXA9ICgiezB9c2xtZ3Jfc3RhdHVzLnR4dCIgLWYgJGVudjpURU1QKQ0KDQojIHVzZSB1dGYtOCBlbmNvZGluZyBmb3JtYXQgaXMgbmVjZXNzYXJ5DQokc2xtZ3Jfc3RhdHVzIHwgT3V0LUZpbGUgJHRtcCAtRW5jb2RpbmcgdXRmOA0KDQokc3RhdHVzX2NoID0gU2VsZWN0LVN0cmluZyAtUGF0aCAkdG1wIC1QYXR0ZXJuICLQ7b/JIg0KJHN0YXR1c19lbmcgPSBTZWxlY3QtU3RyaW5nIC1QYXRoICR0bXAgLVBhdHRlcm4gIkxpY2Vuc2UiDQoNCiRtc2cgPSAoIkNoaW5lc2UgbGljZW5zZSBzdGF0dXM6IHswfSIgLWYgJHN0YXR1c19jaCkNCldyaXRlLUhvc3QgJG1zZw0KJG1zZyA9ICgiRW5nbGlzaCBsaWNlbnNlIHN0YXR1czogezB9IiAtZiAkc3RhdHVzX2VuZykNCldyaXRlLUhvc3QgJG1zZw0KDQpSZW1vdmUtSXRlbSAtcGF0aCAkdG1wDQoNCiMgZm9yIGNoaW5lc2UgZWRpdGlvbg0KaWYgKCRzdGF0dXNfY2ggLW1hdGNoICLS0crayKgiKSB7DQogICAgV3JpdGUtSG9zdCAoIkFjdGl2YXRlZCIpDQogICAgRXhpdCAwDQp9DQoNCiMgZm9yIGVuZ2xpc2ggZWRpdGlvbg0KaWYgKCRzdGF0dXNfZW5nIC1tYXRjaCAiTGljZW5zZWQiKSB7DQogICAgV3JpdGUtSG9zdCAoIkFjdGl2YXRlZCIpDQogICAgRXhpdCAwDQp9DQoNCldyaXRlLUhvc3QgKCJJbmFjdGl2YXRlZCIpDQpFeGl0IDE="}}'

if [ $? -ne 0 ]; then
    echo "write file error"
    exit 1
fi

virsh qemu-agent-command ${VM} '{"execute":"guest-file-close", "arguments":{"handle":'${FD}'}}'

if [ $? -ne 0 ]; then
    echo "close file error"
    exit 1
fi

PID=`virsh qemu-agent-command ${VM} '{"execute": "guest-exec", "arguments": {"path": "powershell", "capture-output": true, "arg": ["-ExecutionPolicy", "RemoteSigned", "-NonInteractive", "-File", "'${FILE_PATH}'"]}}' | awk -F "\"pid\":" '{print $2}' | awk -F "}}" '{print $1}'`

echo "PID: $PID"
if [ ! $PID ]; then
    echo "[ERROR]  PID IS NULL"
    echo "[ERROR] qemu-ga can not exec process in vm!"
    exit 1
fi

ACTIVATED=""

for((i=1;i<5;i++))
do
    if [ $i == 4 ]; then
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
	ACTIVATED=${RETURN}
        break;
    fi
    sleep 3s
done


DELPID=`virsh qemu-agent-command ${VM} '{"execute": "guest-exec", "arguments": {"path": "C:\\\\Windows\\\\system32\\\\cmd.exe", "capture-output": true, "arg": ["/C", "del '${FILE_PATH}'"]}}' | awk -F "\"pid\":" '{print $2}' | awk -F "}}" '{print $1}'`

virsh qemu-agent-command ${VM} '{"execute": "guest-exec-status", "arguments": {"pid": '${DELPID}'}}'

echo "finished verify: ${ACTIVATED}"

