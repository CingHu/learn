//定义一些常量



#ifndef WIN_COMMON_H
#define WIN_COMMON_H





#include <stdio.h>

#include <string.h>

#include <assert.h>

#include <errno.h>

#include <fcntl.h>

#include <limits.h>

#include <stdlib.h>

#include <string.h>

#include <assert.h>

#include <limits.h>

#include <time.h>









//#define DEBUG_F



//#define MAC_DEBUG



#ifdef MAC_DEBUG 

#define EXTERNAL_MAC_PREFIX    "FA:16:3E:72"

#define EXTERNAL_MAC_PREFIX_B  "fa:16:3e:72"

#else

#define EXTERNAL_MAC_PREFIX    "00:3e"

#define EXTERNAL_MAC_PREFIX_B  "00:3E"

#endif





#define DEFAULT_DNS1           "8.8.8.8"

#define DEFAULT_DNS2           "8.8.4.4"



#define LOG_NAME          "c:\\Program Files\\qga\\confnet.log"

#define INET_PATH         "c:\\Program Files\\qga\\userdata\\"

#define NET_SUFFIX        ".ipconf"

#define MASTER_SUFFIX     "master_ip"

#define SLAVOR_SUFFIX     "attach_ip"

#define DNS_STR           "DNS"



#define INET_NUM          128

#define IP_ADDR_LEN       16



#define KEY_LEN           64

#define VANLUE_LEN        64



#define BUF_LEN           100



#define MASTER_FLAG       1

#define SLAVOR_FLAG       0





#define WIN_ERROR    1

#define WIN_SUCCESS  0

#define WIN_FILE_FULL  2



#define DEVICE_NAME_LEN    128

#define IP_ADDR_LEN        16

#define MAC_ADDR_LEN       18

#define NIC_NUMBER         10

#define IP_SIZE            100



#define IP_NUMBER          10

#define DEFALT_ROUTE_DEST  "0.0.0.0"



#define KEY_IP         "IPADDR"

#define KEY_NETMASK    "NETMASK"

#define KEY_GATEWAY    "GATEWAY"

#define KEY_DNS1         "DNS1"

#define KEY_DNS2         "DNS2"

#define KEY_DNS          "DNS"



#define INVALID_IP        "169.254.169.253"

#define INVALID_NETMASK    "255.255.255.0"

#define INVALID_GATEWAY    "169.254.169.1"







struct ip_info_t

{

	char name[DEVICE_NAME_LEN];

	int  flag;  //1:MASTER_FLAG, 0:SLAVOR_FLAG

    char ip[IP_ADDR_LEN];

	char netmask[IP_ADDR_LEN];

	char gateway[IP_ADDR_LEN];

	char dns1[IP_ADDR_LEN];

	char dns2[IP_ADDR_LEN];

};








#endif
