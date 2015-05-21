/*
 * http_response.h
 *
 *  Created on: 2013-3-1
 *      Author: changqian
 */

#ifndef HTTP_RESPONSE_H_
#define HTTP_RESPONSE_H_


#include "header_list.h"


typedef struct http_response_s http_response_t;


struct http_response_s {
    char *head;
    char *body;
    int status;
    const char *msg;
    header_list_t *headers;
};


http_response_t *http_response_new(char *head, char *body);
void http_response_free(http_response_t *resp);
const char *hresp_get_header(http_response_t *resp, const char *name);


#endif /* HTTP_RESPONSE_H_ */
