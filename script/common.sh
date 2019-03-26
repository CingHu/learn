#create file

#check if file exists, create a new file name if it does
function createFile {
if [ ! -d "$dir" ]; then
mkdir $dir
fi

COUNT=1
file=$1
fileName=$file".txt"
until [ ! -e "$dir/$fileName" ]; do
#echo "$fileName"
fileName=$file"("$COUNT").txt"
let COUNT++
#echo "$fileName"
done
echo "final : $fileName"
currentFile=$fileName
}

#array

#Read values into array
declare -a content
declare -a sortedContent
cat $dir/$currentFile | awk '{print $3"."$5}' | cut -d "." -f 5,10 | sed 's/[.]/\ /g' | sed 's/[:]/\n/g' > $dir/temp.txt
readarray content < $dir/temp.txt
rm $dir/temp.txt

let count=0
for i in "${content[@]}"
do
#swap ports if the first one is 80 and delete 
if [[  $(echo "$i" | cut -d " " -f 1) -eq 80 ]]; then
sortedContent[$count]=$(echo $i | awk ' { print $2 } ' )
else
sortedContent[$count]=$(echo $i | awk ' { print $1 } ' )
fi
let count++
done
#length of original
#echo "CONTENT is ${#content[@]}"
#length of sorted
#echo "SORTEDCONTENT is ${#sortedContent[@]}"

sortedContent=($(printf '%s\n' "${sortedContent[@]}" | sort | uniq -c | sort -n -r | awk '{ print $1","$2 }'))
#echo "SORTEDCONTENT is ${#sortedContent[@]}"
echo "${sortedContent[@]}"

#p1 is the # of connections needed in this case, save it
numConnections=$p1

#set real ports based on sorted array and pass them as arguments
let i=0
let pair=0
while [ $i -lt $numConnections ]
do
#echo $(printf '%s' "${sortedContent[$pair]}" | cut -d "," -f 2)
#skip whitespace
if [ -z "$(printf '%s' "${sortedContent[$pair]}" | cut -d "," -f 2)" ]; then
let pair++
fi

#set ports
p1="$(printf '%s' "${sortedContent[$pair]}" | cut -d "," -f 2)"
p2=80
#echo "p1 is $p1............p2 is $p2"

#find all connections and flows
connection $p1 $p2
flow $p1 $p2
let i++
let pair++


#tcpdump
( tcpdump -e -s 0 -i wlan0 2> /dev/null ) & pid=$!
( sleep $time_per_chan && kill -HUP $pid ) 2> /dev/null & watchdog=$!
if wait $pid 2> /dev/null; then
        kill -HUP -P $watchdog
        wait $watchdog
fi
