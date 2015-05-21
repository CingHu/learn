/*
 * buffer.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */


#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdbool.h>
#include "buffer.h"


void
buf_init(buffer_t *buf, size_t size)
{
    buf->data = malloc(size);
    buf->size = size;
    buf->offset = 0;
}


void
buf_free(buffer_t *buf)
{
    if (buf->data) {
        free(buf->data);
        buf->data = NULL;
    }
}


void
buf_extend(buffer_t *buf)
{
    buf->size *= 2;
    buf->data = realloc(buf->data, buf->size);
}


void
buf_append(buffer_t *buf, const char *fmt, ...)
{
    int ret;
    va_list ap;
    char *cur;
    size_t remain;

    while (true) {
        cur = &buf->data[buf->offset];
        remain = buf->size - buf->offset;

        va_start(ap, fmt);
        ret = vsnprintf(cur, remain, fmt, ap);
        va_end(ap);

        if (ret >= 0 && ret < remain) {
            buf->offset += ret;
            return;
        }

        buf_extend(buf);
    }
}
