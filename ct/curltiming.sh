#!/bin/bash

"
%{http_code},接口状态码

%{time_total}, 从开始到请求完毕的时间，响应完毕

%{time_namelookup},从开始到dns解析完成的时间

%{time_connect},从开始到链接完成的时间

%{time_pretransfer}, 从开始到请求开始传输的时间

%{time_appconnect}, 从开始到tls，ssl建立链接完毕的时间

%{time_starttransfer}，从开始到第一个字节开始传输的时间

"

set -o errexit
print_header () {
    echo "code,time_total,time_namelookup,time_connect,time_pretransfer,time_appconnect,time_starttransfer"
}

make_request () {
    curl \
        --write-out "code:%{http_code}, total:%{time_total}, namelookup:%{time_namelookup}, connect:%{time_connect}, pretransfer: %{time_pretransfer}, appconnect:%{time_appconnect}, starttransfer:%{time_starttransfer}\n" \
        --silent \
        --output /dev/null \
        "$@"
}

if [[ -z "$@" ]]; then
echo "提示:
URL地址必须提供

使用说明: ./curltiming.sh <url>
例如：./curltiming.sh http://www.baidu.com

"
exit 1
fi

print_header
for i in `seq 1 10000`; do
make_request "$@"
done
