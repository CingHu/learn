/*
 * http_request.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */


#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include "utils.h"
#include "http_request.h"



http_request_t *
http_request_new(void)
{
    http_request_t *req;

    req = malloc(sizeof(http_request_t));
    memset(req, 0, sizeof(http_request_t));
    req->headers = header_list_new();

    return req;
}


void
http_request_free(http_request_t *req)
{
    header_list_free(req->headers);
    free_null(req->method);
    free_null(req->arg);
    free_null(req->content);
    free(req);
}


void
hreq_set_method(http_request_t *req, const char *method, const char *arg)
{
    req->method = strdup(method);
    req->arg = strdup(arg);
}


void
hreq_set_header(http_request_t *req, const char *name, const char *value,
                enum rp release_policy)
{
    hl_set(req->headers, name, value, release_policy);
}


bool
hreq_del_header(http_request_t *req, const char *name)
{
    return hl_del(req->headers, name);
}


const char *
hreq_get_header(http_request_t *req, const char *name)
{
    return hl_get(req->headers, name);
}


void
hreq_set_content(http_request_t *req, char *content)
{
    req->content = content;
}

