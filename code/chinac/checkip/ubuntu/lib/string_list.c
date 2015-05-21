/*
 * string_list.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */



#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <stdbool.h>
#include "string_list.h"



string_list_t *
string_list_new(void)
{
    string_list_t *l;

    l = malloc(sizeof(string_list_t));
    if (l == NULL)
        return NULL;

    l->count = 0;
    l->maxcount = 256;

    l->data = malloc(l->maxcount * sizeof(char *));
    if (l->data == NULL) {
        free(l);
        return NULL;
    }

    return l;
}


void
string_list_free(string_list_t *l)
{
    if (l) {
        int i;

        for (i = 0; i < l->count; i++)
            free(l->data[i]);

        free(l->data);
        free(l);
    }
}


void
sl_append(string_list_t *l, char *str)
{
    if (l->count >= l->maxcount) {
        l->maxcount <<= 1;
        l->data = realloc(l->data, l->maxcount * sizeof(char *));
    }

    l->data[l->count] = str;
    l->count++;
}


void
sl_set(string_list_t *l, int i, char *str)
{
    if (i < l->count && l->data[i]) {
        free(l->data[i]);
        l->data[i] = str;
    }
}


string_list_t *
sl_load_file(const char *pathname)
{
    FILE *fp;

    fp = fopen(pathname, "r");
    if (fp == NULL)
        return NULL;

    char *line;
    size_t size;
    string_list_t *list;

    size = 1024;
    line = malloc(size);
    list = string_list_new();

    while (getline(&line, &size, fp) != -1)
        sl_append(list, strdup(line));

    free(line);
    fclose(fp);
    return list;
}



bool
sl_write_file(const char *pathname, string_list_t *list)
{
    FILE *fp;

    fp = fopen(pathname,  "w");

    if (fp == NULL)
        return false;

    int i;

    for (i = 0; i < list->count; i++)
        fprintf(fp, "%s", list->data[i]);

    fclose(fp);
    return true;
}

