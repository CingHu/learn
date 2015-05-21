/*
 * header_list.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */


#include <stddef.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "utils.h"
#include "buffer.h"
#include "header_list.h"
#include "string_list.h"


void
header_free(header_t *h)
{
    switch (h->release_policy) {
    case rel_none:
        break;
    case rel_name:
        free_null(h->name);
        break;
    case rel_value:
        free_null(h->value);
        break;
    case rel_both:
        free_null(h->name);
        free_null(h->value);
        break;
    }
}


header_list_t *
header_list_new(void)
{
    header_list_t *l;

    l = malloc(sizeof(header_list_t));
    if (l == NULL)
        return NULL;

    l->count = 0;
    l->maxcount = 256;
    l->data = malloc(l->maxcount * sizeof(header_t *));

    memset(l->data, 0, l->maxcount * sizeof(header_t *));

    return l;
}


void
header_list_free(header_list_t *l)
{
    int i;
    header_t *h;

    for (i = 0; i < l->count; i++) {
        h = &l->data[i];
        header_free(h);
    }

    free_null(l->data);
    free_null(l);
}


void
hl_add(header_list_t *l, const char *name, const char *value,
       enum rp release_policy)
{
    if (value == NULL) {
        if (release_policy == rel_name || release_policy == rel_both)
            free_null(name);
        return;
    }

    if (l->count >= l->maxcount) {
        l->maxcount <<= 1;
        l->data = realloc(l->data, l->maxcount * sizeof(header_t *));
    }

    header_t *h;

    h = &l->data[l->count];

    h->name = name;
    h->value = value;
    h->release_policy = release_policy;

    l->count++;

}


void
hl_set(header_list_t *l, const char *name, const char *value,
       enum rp release_policy)
{
    if (value == NULL) {
        if (release_policy == rel_name || release_policy == rel_both)
            free_null(name);
        return;
    }

    int i;
    header_t *h;

    for (i = 0; i < l->count; i++) {
        h = &l->data[i];
        if (0 == strcasecmp(name, h->name)) {
            header_free(h);
            h->name = name;
            h->value = value;
            h->release_policy = release_policy;
            return;
        }
    }

    hl_add(l, name, value, release_policy);
}


const char *
hl_get(header_list_t *l, const char *name)
{
    int i;
    header_t *h;

    for (i = 0; i < l->count; i++) {
        h = &l->data[i];
        if (0 == strcasecmp(name, h->name))
            return h->value;
    }

    return NULL;
}



bool
hl_del(header_list_t *list, const char *name)
{
    int i;
    header_t *h;

    for (i = 0; i < list->count; i++) {
        h = &list->data[i];
        if (0 == strcasecmp(name, h->name)) {
            header_free(h);
            list->count--;
            if (i < list->count)
                memmove(h, h+1, (list->count - i) * sizeof(header_t));
            return true;
        }
    }

    return false;
}


char *
hl_post_string(header_list_t *l)
{
    int i;
    header_t *h;
    buffer_t buf;

    buf_init(&buf, 2048);

    for (i = 0; i < l->count; i++) {
        h = &l->data[i];
        if (i == l->count - 1)
            buf_append(&buf, "%s=%s", h->name, h->value);
        else
            buf_append(&buf, "%s=%s&", h->name, h->value);
    }

    return buf.data;
}


char *
hl_tokin_string(header_list_t *l)
{
    int i;
    header_t *h;
    buffer_t buf;

    buf_init(&buf, 2048);

    for (i = 0; i < l->count; i++) {
        h = &l->data[i];
        if (i == l->count - 1)
            buf_append(&buf, "%s=%s", h->name, h->value);
        else
            buf_append(&buf, "%s=%s^", h->name, h->value);
    }

    return buf.data;
}

static void
parse_line(char *line, header_list_t *list)
{
    char *p;
    char *name, *value;

    p = strchr(line, '#');
    if (p) *p = '\0';

    p = strchr(line, '=');
    if (p) {
        *p = '\0';
        name = strdup(str_strip(line));
        value = strdup(str_strip(p + 1));
        hl_add(list, name, value, rel_both);
    }
}


header_list_t *
hl_load_config(const char *pathname)
{
    string_list_t *sl;

    sl = sl_load_file(pathname);
    if (sl == NULL)
        return NULL;

    int i;
    char *line;
    header_list_t *hl;

    hl = header_list_new();

    for (i = 0; i < sl->count; i++) {
        line = sl->data[i];
        parse_line(line, hl);
    }

    string_list_free(sl);
    return hl;
}


bool
hl_write_config(const char *pathname, header_list_t *list)
{
    FILE *fp;

    fp = fopen(pathname, "w");
    if (fp == NULL)
        return false;

    int i, ret;
    header_t *h;

    for (i = 0; i < list->count; i++) {
        h = &list->data[i];
        ret = fprintf(fp, "%s=%s\n", h->name, h->value);
        if (ret < 0) {
            fclose(fp);
            return false;
        }
    }

    fclose(fp);
    return true;
}


