#!/bin/bash -x

#export OS_TENANT_NAME=admin
#export OS_USERNAME=jcloudadmin
#export OS_PASSWORD=B2f0b8f55edd1fd2e505
#export OS_AUTH_URL=http://172.19.4.22:5000/v2.0
#export PS1='[\u@\h \W(keystone_admin)]\$ '
#export OS_REGION_NAME=RegionOne

SAMDUM=/usr/bin/samdump2
HIVEXSH=/usr/bin/hivexsh
SAM_NAME=SAM
SYS_NAME_UPPER=SYSTEM
SYS_NAME_LOWER=system
WIN_2003_PATH=/WINDOWS/system32/config/
WIN_2003_SAM=${WIN_2003_PATH}${SAM_NAME}
WIN_2003_SYS=${WIN_2003_PATH}${SYS_NAME_LOWER}
WIN_2008_2012_PATH=/Windows/System32/config/
WIN_2008_2012_SAM=${WIN_2008_2012_PATH}${SAM_NAME}
WIN_2008_2012_SYS=${WIN_2008_2012_PATH}${SYS_NAME_UPPER}

Usage()
{
    echo "Usage: $0 VM_UUID admin_password"
    exit 1
}

copy_out()
{
    local vm_uuid=$1
    local src_sam_file=$2
    local src_sys_file=$3
    local dst_dir=$4
    local sys_disk_path=`virsh domblklist $vm_uuid | grep vda | awk '{print $2}'`

    virt-copy-out -a $sys_disk_path $src_sam_file $src_sys_file $dst_dir

    if [ $? -eq 0 ];then
        echo "virt-copy-out -a $sys_disk_path $src_sam_file $src_sys_file $dst_dir success!"
        return 0
    else
        echo "virt-copy-out -a $sys_disk_path $src_sam_file $src_sys_file $dst_dir failure!"
        return 1
    fi
}

copy_in()
{
    local vm_uuid=$1
    local src_file_path=$2
    local dst_dir=$3
    local sys_disk_path=`virsh domblklist $vm_uuid | grep vda | awk '{print $2}'`

    virt-copy-in -a $sys_disk_path $src_file_path $dst_dir

    if [ $? -eq 0 ];then
        echo "virt-copy-in -a $sys_disk_path $src_file_path $dst_dir success!"
        return 0
    else
        echo "virt-copy-in -a $sys_disk_path $src_file_path $dst_dir failure!"
        return 1
    fi
}

stop_vm()
{
    local vm_uuid=$1
    local vm_status=`nova show $vm_uuid | grep "OS-EXT-STS:vm_state" | awk -F'|' '{print $3}' | awk '{print $1}'` 
    if [ "$vm_status" = "active" ];then
        nova stop $vm_uuid
    fi

    local count=30
    while [ $count -gt 0 ]
    do
        local vm_status=`nova show $vm_uuid | grep "OS-EXT-STS:vm_state" | awk -F'|' '{print $3}' | awk '{print $1}'` 
        if [ "$vm_status" = "stopped" ];then
            echo "vm $vm_uuid: stopped"
            return 0
        fi 
        sleep 10
        local count=$[count-1]
    done

    return 1
}

start_vm()
{
    local vm_uuid=$1
    local vm_status=`nova show $vm_uuid | grep "OS-EXT-STS:vm_state" | awk -F'|' '{print $3}' | awk '{print $1}'` 
    if [ "$vm_status" = "stopped" ];then
        nova start $vm_uuid
    fi
}

set_windows_admin_password()
{

    local sys_reg_file=$1
    local sam_reg_file=$2
    local set_admin_password=$3

    local sam_info=`$HIVEXSH $sam_reg_file << EOF
cd SAM\Domains\Account\Users\000001F4
lsval
EOF`

    #echo $sam_info

    local admin_password=`${SAMDUM} $sys_reg_file $sam_reg_file -p $set_admin_password -t | grep "Administrator (hivexsh) V=" | awk -F"=" '{print $2}'`

    if [ -z $admin_password ];then
        echo "Administrator password not found!"
        return 1
    fi

    local count=0
    local buf=""

    for line in $sam_info
    do
        local key=`echo $line | awk -F"=" '{print $1}' | awk -F'"' '{print $2}'`
        local value=`echo $line | awk -F"=" '{print $2}' | awk -F':' '{print "hex:3:"$2}'`
        if [ "$key" = "V" ];then
            local buf="${buf}${key}\n${admin_password}\n"
        else
            local buf="$buf$key\n$value\n"
        fi
        local count=$[count+1]
    done

    local all_buf="cd SAM\Domains\Account\Users\\\000001F4\n"
    local all_buf="${all_buf}setval $count\n"
    local all_buf="${all_buf}${buf}"
    local all_buf="${all_buf}commit\n"
    local all_buf="${all_buf}lsval\n"

    #echo -en $all_buf
    echo -en $all_buf | $HIVEXSH -w $sam_reg_file
    if [ $? -eq 0 ];then
        echo "set admin password:$set_admin_password success!"
        return 0
    else
        echo "set admin password:$set_admin_password failure!"
        return 1
    fi
}

if [ $# -ne 2 ];then
    Usage
fi

vm_uuid=$1
admin_password=$2

if ( stop_vm $vm_uuid );then
    vm_image_info=`nova show $vm_uuid | grep image | awk -F"|" '{print $3}'`
    is_win_2003=`echo $vm_image_info | grep -i "windows" | grep "2003"`
    is_win_2008_2012=`echo $vm_image_info | grep -i "windows" | grep -iE "2008|2012"`
    current_time=`date +%s`
    save_dir=${vm_uuid}_$current_time
    mkdir $save_dir
    if ! [ -z "$is_win_2003" ];then
        if ( copy_out $vm_uuid $WIN_2003_SAM $WIN_2003_SYS $save_dir );then
            cp $save_dir/$SAM_NAME $save_dir/${SAM_NAME}.${current_time}
            cp $save_dir/$SYS_NAME_LOWER $save_dir/${SYS_NAME_LOWER}.${current_time}
            if ( set_windows_admin_password $save_dir/$SYS_NAME_LOWER $save_dir/$SAM_NAME $admin_password );then
                if ( copy_in $vm_uuid $save_dir/$SAM_NAME $WIN_2003_PATH );then
                    start_vm $vm_uuid
                fi
            fi
        fi
    elif ! [ -z "$is_win_2008_2012" ];then
        if ( copy_out $vm_uuid $WIN_2008_2012_SAM $WIN_2008_2012_SYS $save_dir );then
            cp $save_dir/$SAM_NAME $save_dir/${SAM_NAME}.${current_time}
            cp $save_dir/$SYS_NAME_UPPER $save_dir/${SYS_NAME_UPPER}.${current_time}
            if ( set_windows_admin_password $save_dir/$SYS_NAME_UPPER $save_dir/$SAM_NAME $admin_password );then
                if ( copy_in $vm_uuid $save_dir/$SAM_NAME $WIN_2008_2012_PATH );then
                    start_vm $vm_uuid
                fi
            fi
        fi
    fi
fi

