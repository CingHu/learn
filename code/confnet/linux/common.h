#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <arpa/inet.h>
#include <assert.h>
#include <crypt.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <net/if.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <sys/un.h>
#include <arpa/inet.h>
#include <assert.h>
#include <crypt.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <netdb.h>
#include <ctype.h>

#include "list.h"
#include "basefunc.h"

#define INVALID  0
#define REDHAT   1
#define SUSE     2
#define DEBAIN   3


#define RT_ERROR   0
#define RT_SUCCESS 1
#define RT_FILE_NULL 2

//#define DEBUG_F

//#define MAC_F

#ifdef MAC_F
#define EXTERNAL_MAC_PREFIX    "fa:16:3e"
#define EXTERNAL_MAC_PREFIX_B  "FA:16:3E"
#else
#define EXTERNAL_MAC_PREFIX    "00:3e"
#define EXTERNAL_MAC_PREFIX_B  "00:3E"
#endif


#define DEFAULT_DNS1           "8.8.8.8"
#define DEFAULT_DNS2           "8.8.4.4"

#define LOG_NAME          "/var/log/confnet.log"
#define INET_PATH         "/etc/qga/userdata/"
#define NET_SUFFIX        ".ipconf"
#define MASTER_SUFFIX     "master_ip"
#define SLAVOR_SUFFIX     "attach_ip"
#define DNS_STR           "DNS"

#define INET_NUM          128
#define IP_ADDR_LEN       16

#define KEY_LEN           64
#define VANLUE_LEN        64
#define DEVICE_NAME_LEN   64

#define BUF_LEN           100

#define MASTER_FLAG       1
#define SLAVOR_FLAG       0

#define MAC_ADDR_LEN      64

#define CENTOS_NETWORK_PATH "/etc/sysconfig/network-scripts/"
#define SUSE_NETWORK_PATH "/etc/sysconfig/network/scripts/"

extern char uxdigits[16];
extern char lxdigits[16];


#define UHHEXDIG(c) uxdigits[(c) >> 4]
#define ULHEXDIG(c) uxdigits[(c) & 0xf]
#define LHHEXDIG(c) lxdigits[(c) >> 4]
#define LLHEXDIG(c) lxdigits[(c) & 0xf]

extern int  g_inet_num;
extern struct inet_t* g_inet_array;

struct pair_t
{
    char key[KEY_LEN];
    char value[VANLUE_LEN];
    struct list_head list;
};

struct inet_t
{
    char name[DEVICE_NAME_LEN];
    int  flag;
    struct pair_t pair;
};

typedef struct inetface_s inetface_t;

struct inetface_s {
    bool up;
    char name[IFNAMSIZ];
    char mac[18];
    char ip[16];
    inetface_t *next;
};


#endif
