/*
 * utils.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */


#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <ctype.h>
#include <unistd.h>
#include <assert.h>
#include <stdio.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <openssl/aes.h>
#include <openssl/md5.h>
#include "utils.h"


static const char base64table[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const char base64pad = '=';

char uxdigits[] = "0123456789ABCDEF";
char lxdigits[] = "0123456789abcdef";


bool
string_to_bool(const char *str)
{
    if (0 == strcasecmp(str, "yes")
        || 0 == strcasecmp(str, "true")
        || 0 == strcasecmp(str, "1"))
        return true;
    return false;
}


char *randnums(size_t count)
{
    size_t i;
    time_t seconds;
    char *nums;

    time(&seconds);
    srand((unsigned int)(seconds));
    nums = (char*)malloc(count + 1);
    for (i = 0; i < count; i++)
        nums[i] = '0' + (rand() % 10);

    nums[count] = '\0';

    return nums;
}


char *
md5(const void *data, size_t len)
{
    char *out;
    size_t i;
    MD5_CTX ctx;
    unsigned char md[16];

    MD5_Init(&ctx);
    MD5_Update(&ctx, data, len);
    MD5_Final(md, &ctx);

    out = (char*)malloc(33);
    for (i = 0; i < 16; i++) {
        out[i * 2] = UHHEXDIG(md[i]);
        out[i * 2 + 1] = ULHEXDIG(md[i]);
    }
    out[32] = '\0';

    return out;
}


const void *
bufbuf(const void *buf, size_t bufsize, const void *pattern, size_t ptsize)
{
    if (bufsize < ptsize)
        return NULL;

    const char *s = (const char*)buf;
    const char *t = (const char*)pattern;
    int i, j;

    for (i = 0; i < bufsize; i++) {
        if (t[0] == s[i]) {
            for (j = 1; j < ptsize && (i + j) < bufsize; j++)
                if (t[j] != s[i+j])
                    break;
            if (j == ptsize)
                return (buf + i + ptsize);
        }
    }

    return NULL;
}


char *
str_lower(const char *str)
{
    char *new, *p;
    new = strdup(str);
    for (p = new; *p; p++)
        *p = tolower(*p);
    return new;
}


void
str_replace(char *str, char ch, char replace)
{
    while (*str) {
        if (*str == ch) *str = replace;
        str++;
    }
}


char *
str_strip(char *str)
{
    for (; *str && isspace(*str); str++) ;
    char *retval = str;

    while (*str) str++;
    for (str--; isspace(*str); str--);
    str[1] = '\0';

    return retval;
}


char *
base64_encode(const char *in, size_t srclen)
{
    const unsigned char *src = (const unsigned char*)in;
    unsigned char input[3];
    unsigned char output[4];
    size_t i, srcsize, dstsize, datasize;
    unsigned char *dst;

    datasize = 0;
    srcsize  = srclen;

    dstsize = (srcsize / 3) * 4 + (!!(srcsize % 3)) * 4 + 1;
    dst = (unsigned char*)malloc(dstsize);
    memset(dst, 0, dstsize);

    while (srcsize > 2) {
        input[0] = *src++;
        input[1] = *src++;
        input[2] = *src++;
        srcsize -= 3;

        output[0] = input[0] >> 2;
        output[1] = ((input[0] & 0x03) << 4) + (input[1] >> 4);
        output[2] = ((input[1] & 0x0f) << 2) + (input[2] >> 6);
        output[3] = input[2] & 0x3f;

        assert(output[0] < 64);
        assert(output[1] < 64);
        assert(output[2] < 64);
        assert(output[3] < 64);

        dst[datasize++] = base64table[output[0]];
        dst[datasize++] = base64table[output[1]];
        dst[datasize++] = base64table[output[2]];
        dst[datasize++] = base64table[output[3]];
    }

    // Handle padding.
    if (srcsize) {
        input[0] = input[1] = input[2] = '\0';
        for (i = 0; i < srcsize; i++)
            input[i] = *src++;

        output[0] = input[0] >> 2;
        output[1] = ((input[0] & 0x03) << 4) + (input[1] >> 4);
        output[2] = ((input[1] & 0x0f) << 2) + (input[2] >> 6);
        assert(output[0] < 64);
        assert(output[1] < 64);
        assert(output[2] < 64);

        dst[datasize++] = base64table[output[0]];
        dst[datasize++] = base64table[output[1]];

        dst[datasize++] = (srcsize == 1) ? base64pad : base64table[output[2]];
        dst[datasize++] = base64pad;
    }

    if (datasize >= dstsize) {
        free(dst);
        return NULL;
    }

    return (char*)dst;
}

char *
base64_decode(const char *src, size_t *decsize)
{
    assert(src && decsize);

    int dstindex, state, ch, dstsize;
    char *pos;

    unsigned char *dst;

    state = 0;
    dstindex = 0;

    dstsize = (strlen(src) / 4) * 3 + 1;
    dst = (unsigned char*)malloc(dstsize);
    memset(dst, 0, dstsize);

    while((ch = *src++)) {

        if (ch == base64pad)
            break;

        pos = strchr(base64table, ch);
        if (!pos)
            goto err;

        switch (state) {
        case 0:
            dst[dstindex] = (pos - base64table) << 2;
            state = 1;
            break;
        case 1:
            dst[dstindex]   |=  (pos - base64table) >> 4;
            dst[dstindex+1]  = ((pos - base64table) & 0x0f) << 4;
            dstindex++;
            state = 2;
            break;
        case 2:
            dst[dstindex]   |=  (pos - base64table) >> 2;
            dst[dstindex+1]  = ((pos - base64table) & 0x03) << 6;
            dstindex++;
            state = 3;
            break;
        case 3:
            dst[dstindex] |= (pos - base64table);
            dstindex++;
            state = 0;
            break;
        default:
            return NULL;
        }
    }

    if (ch != base64pad && state != 0)
        goto err;
    // We dont check what is after `='

    *decsize = dstindex;
    return (char*)dst;

 err:
    free(dst);
    return NULL;
}


char *
aes128_cbc_encrypt(const char *str, const char *userKey, const char *userVec,
                   size_t *outlen)
{
    AES_KEY
    key;
    size_t inlen, len, remain;
    char *in, *out, *ivec;

    if (strlen(userKey) != AES_BLOCK_SIZE)
        return NULL;
    if (strlen(userVec) != AES_BLOCK_SIZE)
        return NULL;

    if (AES_set_encrypt_key((unsigned char*)userKey, 128, &key) < 0)
        return NULL;

    ivec = strdup(userVec);
    inlen = strlen(str);

    remain = AES_BLOCK_SIZE - inlen % AES_BLOCK_SIZE;
    len = inlen + remain;

    in = (char*)malloc(len);
    memset(in, remain, len);
    memcpy(in, str, inlen);
    out = (char*)malloc(len);

    AES_cbc_encrypt((unsigned char*)in, (unsigned char*)out,
                    len, &key, (unsigned char*)ivec, AES_ENCRYPT);

    free(in);
    free(ivec);

    *outlen = len;
    return out;
}



char *
aes128_cbc_decrypt(const char *in, size_t len, const char *userKey,
                   const char *userVec)
{
    AES_KEY key;
    size_t remain;
    char *out, *ivec;

    if (strlen(userKey) != AES_BLOCK_SIZE)
        return NULL;
    if (strlen(userVec) != AES_BLOCK_SIZE)
        return NULL;

    if (AES_set_decrypt_key((unsigned char*)userKey, 128, &key) < 0)
        return NULL;

    ivec = strdup(userVec);
    out = (char*)malloc(len);

    AES_cbc_encrypt((unsigned char*)in,
                    (unsigned char*)out,
                    len, &key,
                    (unsigned char*)ivec,
                    AES_DECRYPT);

    remain = out[len - 1];
    out[len - remain] = '\0';

    free(ivec);
    return out;
}


char *
int_to_str(int num)
{
    char buf[64];
    snprintf(buf, sizeof buf, "%d", num);
    return strdup(buf);
}


bool
file_exist(const char *pathname)
{
    return access(pathname, F_OK) >= 0;
}


bool
touch(const char *pathname)
{
    FILE *fp;

    if (!file_exist(pathname)) {
        fp = fopen(pathname, "a");
        if (fp == NULL)
            return false;
        fclose(fp);
    }

    return true;
}


char *
str_print(const char *fmt, ...)
{
    int n, size = 1024;
    char *p, *newp;
    va_list ap;

    p = malloc(size);
    if (p == NULL)
        return NULL;

    while (true) {

        va_start(ap, fmt);
        n = vsnprintf(p, size, fmt, ap);
        va_end(ap);

        if (n > -1 && n < size)
            break;

        size *= 2; /* Always two times... */

        newp = realloc(p, size);

        if (newp == NULL) {
            free(p);
            return NULL;
        }

        p = newp;
    }

    return p;
}


void
extract_filename(char *buf, unsigned long size, const char *pathname)
{
    const char *p;

    p = strrchr(pathname, '/');

    if (!p)
        strcpy(buf, pathname);
    else {
        p++;
        strcpy(buf, p);
    }
}


void
extract_dirpath(char *buf, unsigned long size, const char *pathname)
{
    /* We get the absolute pathname of directory. */
    const char *p;

    p = strrchr(pathname, '/');

    if (p) {
        int dirpath_len = p - pathname;
        strncpy(buf, pathname, dirpath_len);
        buf[dirpath_len] = '\0';
    } else
        getcwd(buf, size);
}


int
fork_to_background(void)
{
    pid_t pid;

    pid = fork();

    if (pid < 0) {
        fprintf(stderr, "fork() failed: %s", strerror(errno));
        return -1;

    } else if (pid != 0)
        return pid;

    setsid();

    freopen("/dev/null", "r", stdin);
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);

    return 0;
}


bool
create_directory(const char *dirpath, mode_t mode)
{
    char tmpchr;
    char *p, *cur;

    int pathlen = strlen(dirpath);
    char buf[pathlen+1];
    strcpy(buf, dirpath);

    cur = buf;
    while (true) {

        p = strchr(cur, '/');

        if (!p) {
            if (!file_exist(buf))
                if (mkdir(buf, mode) == -1)
                    return false;
            break;
        }

        p++;

        tmpchr = *p;
        *p = '\0';

        if (!file_exist(buf))
            if (mkdir(buf, mode) == -1)
                return false;

        *p = tmpchr;
        cur = p;
    }

    return true;
}
