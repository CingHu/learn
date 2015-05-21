/*
 * httt_response.c
 *
 *  Created on: 2013-3-1
 *      Author: changqian
 */


#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include "logger.h"
#include "utils.h"
#include "buffer.h"
#include "network.h"
#include "header_list.h"
#include "http_response.h"


static void
parse_head(http_response_t *resp)
{
    char *p;
    char *sep;
    char *status;

    log_debug("parse_head()");

    /* status-line */

    p = strchr(resp->head, ' ');
    status = p + 1;
    p = strchr(status, ' ');
    *p = '\0';

    resp->status = atoi(status);

    /* find beginning line of headers */

    p++;
    p = strchr(p, '\n');
    p++;

    /* parse headers */

    char *name, *value;

    while (true) {
        sep = strchr(p, ':');
        if (sep == NULL)
            break;

        *sep = '\0';

        name = p;
        value = sep + 2;

        p = strchr(value, '\r');
        *p = '\0';

        hl_add(resp->headers, name, value, rel_none);

        p++;
        p = strchr(p, '\n');
        p++;
    }
}


http_response_t *
http_response_new(char *head, char *body)
{
    http_response_t *resp;

    resp = malloc(sizeof(http_response_t));

    resp->head = head;
    resp->body = body;
    resp->headers = header_list_new();

    parse_head(resp);

    return resp;
}


void
http_response_free(http_response_t *resp)
{
    header_list_free(resp->headers);
    free_null(resp->head);
    free_null(resp->body);
    free(resp);
}


const char *
hresp_get_header(http_response_t *resp, const char *name)
{
    return hl_get(resp->headers, name);
}



