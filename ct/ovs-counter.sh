#最终版statistics_counter.sh
if [ $# -ne 2 ];then
    echo ""
    echo "Usage: $0 [bridge] [num]"
    echo ""
    exit 1
fi


BRIDGE=$1
except_value=$2




#statistic-of-counter.sh


pre_file="/tmp/1"
current_file="/tmp/2"




#sample_of_cmd=" -e 's/\ //g' -e '/n_packets=0/d' -e '/OFPST_FLOW/d' -e '/NXST_FLOW/d' -e 's/\(duration\)=[^,]*,//g' -e 's/send_flow_rem//g' -e 's/\(cookie\)=[^,]*,//g' -e 's/\(n_bytes\)=[^,]*,//g' -e 's/\(idle_age\)=[^,]*,//g'"
#sample_of_cmd=" -e s/\ //g -e /n_packets=0/d -e /OFPST_FLOW/d -e /NXST_FLOW/d -e s/\(duration\)=[^,]*,//g -e s/send_flow_rem//g -e s/\(cookie\)=[^,]*,//g -e s/\(n_bytes\)=[^,]*,//g -e s/\(idle_age\)=[^,]*,//g"
#value_cmd="sed ${sample_of_cmd} -e 's/.*n_packets=\(.*\),n_bytes.*/\1/g'"
#key_cmd="sed ${sample_of_cmd}  -e 's/\(n_packets\)=[^,]*,//g'"


echo $sample_of_cmd


function dump_flows()
{
    ovs-ofctl dump-flows $BRIDGE -O openflow13 > $1
    sed -i -e '/n_packets=0/d' -e '/OFPST_FLOW/d' -e '/NXST_FLOW/d' -e 's/\(duration\)=[^,]*,//g' -e 's/send_flow_rem//g' -e 's/\(cookie\)=[^,]*,//g' -e 's/\(n_bytes\)=[^,]*,//g' -e 's/\(idle_age\)=[^,]*,//g' -e 's/reset_counts//g' -e 's/\(hard_timeout\)=[^,]*,//g' -e 's/\ //g' $1
}




function parse_pre_of_counter(){
    file=$1
    for line in `cat $1`
    do
        key=$(echo $line|sed -e 's/\(n_packets\)=[^,]*,//g')
        value=$(echo $line|sed  -e 's/.*n_packets=\(.*\),priority.*/\1/g'|cut -d"," -f1)
        pre_count_array[$key]=$value
    done
}




function parse_current_of_counter(){
    file=$1
    for line in `cat $1`
    do
        key=$(echo $line|sed -e 's/\(n_packets\)=[^,]*,//g')
        value=$(echo $line|sed  -e 's/.*n_packets=\(.*\),priority.*/\1/g'|cut -d"," -f1)
        current_count_array[$key]=$value
    done
}


function reduce_result(){
    for k in ${!pre_count_array[@]}
    do
        pre_v=${pre_count_array[$k]}
        current_v=${current_count_array[$k]}
        r=`expr $current_v - $pre_v`
        if [ $r -gt $except_value ];then
                result[$k]=$r
        fi
    done
}


function print_result(){
    echo -e "\n========= `date`: [$count] ========="
    for k in ${!result[@]}
    do
        echo "$k -- ${result[$k]}"
    done
    ((count+=1))
}


count=1
while ((1))
do
    declare -A pre_count_array
    declare -A current_count_array
    declare -A result
    
    #unset mymap[$findkey]
    #unset mymap[$findkey]
    dump_flows $pre_file
    sleep 1
    dump_flows $current_file
    
    parse_pre_of_counter $pre_file
    parse_current_of_counter $current_file
    
    reduce_result
    print_result


done
