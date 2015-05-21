/*
 * buffer.h
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */

#ifndef BUFFER_H_
#define BUFFER_H_


struct buffer_s {
    char *data;
    int offset;
    size_t size;
};


typedef struct buffer_s buffer_t;


void buf_init(buffer_t *, size_t );
void buf_free(buffer_t *);
void buf_extend(buffer_t *);
void buf_append(buffer_t *, const char *fmt, ...);


#endif /* BUFFER_H_ */
