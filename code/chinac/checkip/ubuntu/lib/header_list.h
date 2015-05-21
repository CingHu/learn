/*
 * header_list.h
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */

#ifndef HEADER_LIST_H_
#define HEADER_LIST_H_


#include <stdbool.h>


enum rp {
    rel_none,
    rel_name,
    rel_value,
    rel_both
};


struct header {
    const char *name;
    const char *value;
    enum rp release_policy;
};


typedef struct header header_t;


struct header_list {
    header_t *data;
    int count;
    int maxcount;
};


typedef struct header_list header_list_t;


header_list_t *header_list_new(void);
void header_list_free(header_list_t *);
void hl_add(header_list_t *, const char *name, const char *value, enum rp);
void hl_set(header_list_t *, const char *name, const char *value, enum rp);
bool hl_del(header_list_t *, const char *name);
const char *hl_get(header_list_t *, const char *name);

char *hl_post_string(header_list_t *);
char *hl_tokin_string(header_list_t *);
char *hl_request_string(header_list_t *);

header_list_t *hl_load_config(const char *pathname);
bool hl_write_config(const char *pathname, header_list_t *list);


#endif /* HEADER_LIST_H_ */
