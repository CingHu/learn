#!/bin/bash 
ip=10.3.0.0/16
address=${ip%/*}
mlen=${ip#*/}
declare -i FULL_MASK_INT=4294967295 
declare -i MASK_LEN=$mlen
declare -i LEFT_MOVE="32 - ${MASK_LEN}" 
declare -i N="${FULL_MASK_INT} << ${LEFT_MOVE}" 
declare -i H1="$N & 0x000000ff" 
declare -i H2="($N & 0x0000ff00) >> 8" 
declare -i L1="($N & 0x00ff0000) >> 16" 
declare -i L2="($N & 0xff000000) >> 24" 
mask="$L2.$L1.$H2.$H1"
ip="$address $mask"
all=(${ip//[!0-9]/ })  
get_addr () {         
    op='&'         
    unset net          
    while [ "$5" ]; do                
    num=$(( $1 $op ($5 $op1 $arg) ))               
    shift               
    net="$net.$num"                             
    done
}
get_addr ${all[@]}                  
all=(${net//./ })
n=$((2**(32-$mlen)))
n1=${all[0]}
n2=${all[1]}
n3=${all[2]}
n4=${all[3]}
for((i=0;i<n;i++))
do
    if [ $n4 -eq 256 ];then
        n4=0
        ((n3++))
        if [ $n3 -eq 256 ];then
            n3=0
            ((n2++))
                if [ $n2 -eq 256 ];then
                        n2=0
                        ((n1++))
            fi
        fi    
    fi
    echo "$n1.$n2.$n3.$n4"
        ((n4++))
done
