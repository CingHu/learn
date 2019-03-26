#!/usr/bin/env bash

DEBUG=0

# functions for log
function Error()
{
    RED='\e[1;31m'
    NC='\e[0m'
    echo -e "${RED} Error: $* ${NC}" >& 2
}
function Debug()
{
    [[ $DEBUG -eq 0 ]] && return 0
    echo "Debug: $*" >& 2
}
function Info()
{
    echo "Info: $*" >& 2

}
# function to get console file path on host
# need VMID as parameter
function console_log_file() {
    [[ $# -ne 1 ]] && Error "[console_log_file] [Miss parameter]" && exit 1
    echo "/export/jvirt/jcs-agent/instances/$1/console.log"
}

# function to get os type of given VM ID
# need VMID as parameter
function __get_os_type() {
    [[ $# -ne 1 ]] && Error "[get_os_type] [Miss parameter]" && return 1
    local vmid=$1
    res=$(virsh dumpxml $vmid | grep "<os_type>.*</os_type>")
    [[ $? -ne 0 ]] && Error "[get_od_type] [Failed: $res]" && return 1
    local os_type=""
    os_type=$(echo $res | sed 's/^.*<os_type>\([^<]\+\)<\/os_type>.*$/\1/g')
    [[ $? -ne 0 || "X$os_type" == "X" ]] && Error "[get_os_type] [Failed]" && return 1

    case $os_type in
    "windows")
            ;;
    "linux")
            ;;
    *)
            Error "[get_os_type] [Unknown OS Type '$os_type']"
            return 1
    esac

    echo $os_type
    return 0
}

function __get_linux_dist()
{
    [[ $# -ne 1 ]] && Error "Miss parameter VMID" && return 1
    local vmid=$1
    local result=$(qga_exec $vmid "cat /etc/os-release  | grep -E '^ID=.*'")
    [[ $? -ne 0 ]] && Error $result && return 1
    echo $result | awk -F '=' '{print $2}' | sed 's/\"//g'
}

# function to execute qga command for given vm
# Need VMID [command...] as parameters
function __qga_exec(){
    [[ $# -lt 2 ]] && Error "[check_qga_status] [Miss parameter]" && return 1
    local QGACMD="virsh qemu-agent-command"
    local vmid=$1
    shift 1
    local command=$*
    Debug "[__qga_exec] [~# $QGACMD $vmid '$command']"
    $QGACMD $vmid $cmd
    [[ $? -ne 0 ]] && Error "[__qga_exec] [Failed to exec $command on $vmid]" && return 1
    return 0
}

# function to check qga availability
# Need VMID as parameter
function __check_qga_status(){
    [[ $# -ne 1 ]] && Error "[check_qga_status] [Miss parameter]" && return 1
    local vmid=$1
    local result=""
    local real_result=""
    local cmd='{"execute": "guest-ping"}'
    local sanity_result="{return:{}}"

    result=$(__qga_exec $vmid $cmd)
    real_result=$(echo ${result}| sed -e 's/\"//g' -e 's/\ //g')
    [[ ${sanity_result} != ${real_result} ]] && Error "check the status of qemu agent failed, ${result}" && return 1
    return 0
}

function __guest_exec_status()
{
    [[ $# -ne 2 ]] && Error "[waiting_process_exited] [Miss parameter vmid, pid]" && return 1
    local vmid=$1
    local pid=$2
    local cmd="{\"execute\": \"guest-exec-status\", \"arguments\": {\"pid\": $pid}}"
    __qga_exec $vmid $cmd
    return $?
}

# function to waiting for process exited for given vm and pid
function __guest_exec_status_on_exited()
{
    [[ $# -ne 2 ]] && Error "[waiting_process_exited] [Miss parameter vmid, pid]" && return 1
    local vmid=$1
    local pid=$2
    local result=""
    for i in `seq 15`;do
        result=$(__guest_exec_status $vmid $pid)
        [[ $? -ne 0 ]] && return 1
        local exited=$(echo $result | jq -r .return.exited)
        [[ "$exited" == "true" ]] && echo $result && return 0
        Debug "[qga_exec] [Not exited, sleep 2s and try again, output: '$result']"
        sleep 2
    done
    Error "[__waiting_exec_exited] [Not exited, after waiting 30s output: '$result']"
    return 1
}

# function to get command output for given vm and pid
# Need VMID and PID as parameters
function __qga_exec_output() {
    [[ $# -ne 2 ]] && Error "[check_qga_status] [Miss parameter vmid, pid]" && return 1
    local vmid=$1
    local pid=$2
    # get os type
    local os_type=""
    os_type=$(__get_os_type $vmid)
    [[ $? -ne 0 || "X$os_type" == "X" ]] && Error "[qga_exec] [Failed to get os type of '$vmid']" && return 1
    # waiting for process exited and get output
    local result=""
    result=$(__guest_exec_status_on_exited $vmid $pid)
    [[ $? -ne 0 ]] && return 1
    # parse output
    local exitcode=$(echo $result | jq -r .return.exitcode)
    local outdata=$(echo $result | sed 's/-/_/g' | jq -r .return.out_data)
    local errdata=$(echo $result | sed 's/-/_/g' | jq -r .return.err_data)
    #[[ $exitcode == "null" || $outdata == "null" || $errdata == "null" ]] && Error "[qga_exec] [Bad result]" && return 1
    outdata=$(echo $outdata | base64 -d | while read line;do echo "$line\n"; done)
    errdata=$(echo $errdata | base64 -d | while read line;do echo "$line\n"; done)
    case $os_type in
    "linux")
        echo $outdata
        ;;
    "windows")
        echo $outdata | iconv -f gbk -t utf-8
        local console_out=$(iconv -f gbk -t utf-8 $(console_log_file $vmid) | while read line;do echo "$line\n"; done)
        echo  $console_out
        errdata=$(echo $errdata | iconv -f gbk -t utf-8)
        ;;
    *)
        "Unsupport os $os_type"
        return 1
    ;;
    esac
    [[ "$exitcode" -ne "0" ]] && Error "[qga_exec] [Exit with error code '"$exitcode"\n$errdata]" && return 1
    return 0
}

function qga_exec() {
    [[ $# -lt 2 ]] && Error "[qga_exec] [Miss parameter]" && return 1
    local vmid=$1
    __check_qga_status $vmid
    [[ $? -ne 0 ]] && Error "[qga_exec] [Failed to check qga status]" && return 1
    shift 1
    local command=$*
    # get vm os type
    local os_type=""
    os_type=$(__get_os_type $vmid)
    [[ $? -ne 0 || "X$os_type" == "X" ]] && Error "[qga_exec] [Failed to get os type of '$vmid']" && return 1
    # generate qga command
    local cmd=""
    case $os_type in
    "linux")
         cmd="{\"execute\": \"guest-exec\", \"arguments\": {\"path\": \"/bin/sh\",  \"capture-output\": true, \"arg\": [\"-c\", \"$command\"]}}"
         ;;
    "windows")
         # clear console log
         > `console_log_file $vmid`
         cmd="{\"execute\": \"guest-exec\", \"arguments\": {\"path\": \"C:\\\\Windows\\\\system32\\\\cmd.exe\",  \"capture-output\": true, \"arg\": [\"/C\", \"$command > COM1\"]}}"
         ;;
    *)
         return 1
         ;;
    esac
    # exec
    local result=""
    result=$(__qga_exec $vmid $cmd)
    [[ $? -ne 0 ]] && return 1
    # get pid in result
    local pid=$(echo $result | jq -r .return.pid)
    [[ $pid == "null" ]] && Error "[qga_exec] [Failed to parse pid, output: '$result']" && return 1
    # Get output
    local output=""
    output=$(__qga_exec_output $vmid $pid)
    [[ $? -ne 0 ]]  && Error "[qga_exec] [Failed to parse output, pid: '$pid', $output]" && return 1
    echo -e $output
    return 0
}

[[ $# -gt 1 ]] && qga_exec $*
[[ $# -le 1 ]] && Info "Source vm_qga_exec.sh"

