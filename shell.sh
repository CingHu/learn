* 判断文件非空*
if [[ -s $file ]]; then
        echo "not empty"
fi

*获取文件大小*
stat -c %s $file
stat --printf='%s\n' $file
wc -c $file

*字符串替换*
${string//pattern/replacement}
a='a,b,c'
echo ${a//,/ /}

* Contains 子字符串*
string="My string"
if [[ $string == *My* ]]; then
        echo "It's there!"
fi

*rsync备份*
rsync -r -t -v /source_folder /destination_folder
rsync -r -t -v /source_folder [user@host:/destination_folder]

*为所有txt文件加上.bak 后缀*
rename '.txt' '.txt.bak' *.txt

*去掉所有的bak后缀*
rename '*.bak' '' *.bak

*把所有的空格改成下划线*
find path -type f -exec rename 's/ /_/g' {} \;

*把文件名都改成大写*
find path -type f -exec rename 'y/a-z/A-Z/' {} \;

*for/while 循环*
for ((i=0; i < 10; i++)); do echo $i; done
for line in $(cat a.txt); do echo $line; done
for f in *.txt; do echo $f; done
while read line ; do echo $line; done < a.txt
cat a.txt | while read line; do echo $line; done

*删除空行*
cat a.txt | sed -e '/^$/d'
(echo "abc"; echo ""; echo "ddd";) | awk '{if (0 != NF) print $0;}'

*比较文件的修改时间*
[[ file1.txt -nt file2.txt ]] && echo true || echo false
[[ file1.txt -ot file2.txt ]] && echo true || echo false

*把stderr输出保存到变量*
$ a=$( (echo 'out'; echo 'error' 1>&2) 2>&1 1>/dev/null) 
$ echo $a
error

*删除前3行*
$ cat a.txt | sed 1,3d

*读取多个域到变量*
read a b c <<< "xxx yyy zzz"

*遍历数组*
array=( one two three )
for i in ${array[@]}
do
   echo $i
done


*查看目录大小*
du –sh ~/apps

*获取路径名和文件名*
$ dirname ‘/home/lalor/a.txt'
/home/lalor
$ basename ‘/home/lalor/a.txt'
a.txt

*awk复杂分隔符*
echo "a||b||c||d" | awk -F '[|][|]' '{print $3}'

*多种分隔符1*
echo "a||b,#c d" | awk -F '[| ,#]+' '{print $4}'

*多种分隔符2*
echo "a||b##c|#d" | awk -F '([|][|])|([#][#])' '{print $NF}'

*产生一个随机数*
echo $RANDOM

*获取文件名或者扩展名*
var=hack.fun.book.txt
echo ${var%.*}
hack.fun.book
echo ${var%%.*}
hack
echo ${var#.*}
fun.book.txt
echo ${var##.*}
txt

*删除0 字节文件或垃圾文件*
find . -type f -size 0 -delete
find . -type f -exec rm -rf {} \;
find . -type f -name "a.out" -exec rm -rf {} \;
find . type f -name "a.out" -delete
find . type f -name "*.txt" -print0 | xargs -0 rm -f

*获取IP地址*
ifconfig eth0 |grep "inet addr:" |awk '{print $2}'|cut -c 6-

*清除僵尸进程*
ps -eal | awk '{ if ($2 == "Z"){ print $4}}' | kill -9

*打印某行后后面的10行*
cat file | grep -A100 string
cat file | grep -B100 string #前面
cat file | grep -C100 string #前后
sed -n '/string/,+100p'
awk '/string/{f=100}--f>=0'

*获取命令行最后一个参数*
echo ${!#}
echo ${$#} #错误的尝试


*输出重定向*
&>/dev/null


*打印一些头信息*
echo << something_message
**********************
hello, welcome to use my shell script
**********************
something_message

*正则表达式*
匹配中文字符的正则表达式：[u4e00-u9fa5]
评注：匹配中文还真是个头疼的事，有了这个表达式就好办了
匹配双字节字符(包括汉字在内)：[^x00-xff]
评注：可以用来计算字符串的长度（一个双字节字符长度计2，ASCII字符计1）
匹配空白行的正则表达式：^ *$
评注：可以用来删除空白行
匹配HTML标记的正则表达式：<(S*?)[^>]*>.*?1>|<.*? />
评注：网上流传的版本太糟糕，上面这个也仅仅能匹配部分，对于复杂的嵌套标记依旧无能为力
匹配首尾空白字符的正则表达式：^s*|s*$
评注：可以用来删除行首行尾的空白字符(包括空格、制表符、换页符等等)，非常有用的表达式
匹配Email地址的正则表达式：w+([-+.]w+)*@w+([-.]w+)*.w+([-.]w+)*
评注：表单验证时很实用
匹配网址URL的正则表达式：[a-zA-z]+://[^s]*
评注：网上流传的版本功能很有限，上面这个基本可以满足需求
匹配帐号是否合法(字母开头，允许5-16字节，允许字母数字下划线)：^[a-zA-Z][a-zA-Z0-9_]{4,15}$
评注：表单验证时很实用
匹配国内电话号码：d{3}-d{8}|d{4}-d{7}
评注：匹配形式如0511-4405222或021-87888822
匹配腾讯QQ号：[1-9][0-9]{4,}
评注：腾讯QQ号从10000开始
匹配中国邮政编码：[1-9]d{5}(?!d)
评注：中国邮政编码为6位数字
匹配身份证：d{15}|d{18}
评注：中国的身份证为15位或18位
匹配ip地址：d+.d+.d+.d+
评注：提取ip地址时有用
匹配特定数字：
^[1-9]d*$　　//匹配正整数
^-[1-9]d*$　//匹配负整数
^-?[1-9]d*$　　//匹配整数
^[1-9]d*|0$　//匹配非负整数（正整数+ 0）
^-[1-9]d*|0$　　//匹配非正整数（负整数+ 0）
^[1-9]d*.d*|0.d*[1-9]d*$　　//匹配正浮点数
^-([1-9]d*.d*|0.d*[1-9]d*)$　//匹配负浮点数
^-?([1-9]d*.d*|0.d*[1-9]d*|0?.0+|0)$　//匹配浮点数
^[1-9]d*.d*|0.d*[1-9]d*|0?.0+|0$　　//匹配非负浮点数（正浮点数+ 0）
^(-([1-9]d*.d*|0.d*[1-9]d*))|0?.0+|0$　　//匹配非正浮点数（负浮点数+ 0）
评注：处理大量数据时有用，具体应用时注意修正
匹配特定字符串：
^[A-Za-z]+$　　//匹配由26个英文字母组成的字符串
^[A-Z]+$　　//匹配由26个英文字母的大写组成的字符串
^[a-z]+$　　//匹配由26个英文字母的小写组成的字符串
^[A-Za-z0-9]+$　　//匹配由数字和26个英文字母组成的字符串
^w+$　　//匹配由数字、26个英文字母或者下划线组成的字符串



