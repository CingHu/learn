/*
 * http_request.h
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */

#ifndef HTTP_REQUEST_H_
#define HTTP_REQUEST_H_


#include <stdbool.h>
#include "header_list.h"


typedef struct http_request_s http_request_t;


struct http_request_s {
    char *method;
    char *arg;
    char *content;
    header_list_t *headers;
};


http_request_t *http_request_new(void);
void http_request_free(http_request_t *req);

void hreq_set_method(http_request_t *, const char *method, const char *arg);
void hreq_set_header(http_request_t *, const char *name, const char *value, enum rp);
bool hreq_del_header(http_request_t *, const char *name);
const char *hreq_get_header(http_request_t *, const char *name);
void hreq_set_content(http_request_t *req, char *content);

#endif /* HTTP_REQUEST_H_ */
