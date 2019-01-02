#!/bin/sh
function quit_test()
{
   is_quit=1
}

trap 'quit_test' SIGINT
is_quit=0
url="http://ftp.sjtu.edu.cn/ubuntu-cd/16.04.3/ubuntu-16.04.3-desktop-amd64.iso"
file=`echo $url | awk -F '/' '{printf $6}'`
timeval=2
while [ ${is_quit} -eq 0 ]
do
   wget -o tmp ${url} &
   sleep 5;
   while [ ${is_quit} -eq 0 ]
   do
   size1=`ls -l $file | awk '{printf $5}'`
   sleep $timeval
   size2=`ls -l $file | awk '{printf $5}'`
   if [[ $size2 == $size1 ]] ;
   then
      break;
   fi
   size=`echo "scale=2; $size2 - $size1" | bc`
   speed=`echo "scale=2; $size / ($timeval*1000)" | bc`
   time=`date "+%Y-%m-%d %H:%M:%S"`
   echo "$time size1: $size2 - $size1; speed: $speed KB/s"
   done
   echo "download finished.........."
   rm -rf $file
   pkill wget
done
pkill wget
