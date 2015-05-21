/*
 * utils.h
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */

#ifndef UTILS_H_
#define UTILS_H_

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
#include <unistd.h>

#include "buffer.h"
#include "header_list.h"
#include "http_request.h"
#include "http_response.h"
#include "logger.h"
#include "network.h"
#include "string_list.h"


extern char uxdigits[16];
extern char lxdigits[16];

#define DEBUG true

#define UHHEXDIG(c) uxdigits[(c) >> 4]
#define ULHEXDIG(c) uxdigits[(c) & 0xf]
#define LHHEXDIG(c) lxdigits[(c) >> 4]
#define LLHEXDIG(c) lxdigits[(c) & 0xf]


#define free_null(p)                                                 \
    do {                                                             \
        if (p) free((void *)(p));                                    \
    } while (0)



char *int_to_str(int num);
char *str_lower(const char *str);
char *str_strip(char *str);
char *str_print(const char *fmt, ...);
void str_replace(char *str, char ch, char replace);
char *randnums(size_t count);
char *md5(const void *data, size_t len);
char *base64_encode(const char *in, size_t srclen);
char *base64_decode(const char *src, size_t *decsize);
char *aes128_cbc_encrypt(const char *str, const char *userKey,
                         const char *userVec, size_t *outlen);
char *aes128_cbc_decrypt(const char *in, size_t len,
                         const char *userKey, const char *userVec);
const void *bufbuf(const void *buf, size_t bufsize,
                   const void *pattern, size_t ptsize);
bool file_exist(const char *pathname);
void extract_filename(char *buf, unsigned long size, const char *filepath);
void extract_dirpath(char *buf, unsigned long size, const char *pathname);
int fork_to_background(void);
bool touch(const char *pathname);
const void *bufbuf(const void *buf, size_t bufsize, const void *pattern, size_t ptsize);
bool create_directory(const char *dirpath, mode_t mode);
bool string_to_bool(const char*);



#endif /* UTILS_H_ */
