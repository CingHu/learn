/*
 * string_list.h
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */

#ifndef STRING_LIST_H_
#define STRING_LIST_H_


struct string_list_s {
    int count;
    int maxcount;
    char **data;
};


typedef struct string_list_s string_list_t;


string_list_t *string_list_new(void);
void string_list_free(string_list_t *);
void sl_append(string_list_t *, char *);
void sl_set(string_list_t *, int, char *);

string_list_t *sl_load_file(const char *pathname);
bool sl_write_file(const char *pathname, string_list_t *);


#endif /* STRING_LIST_H_ */
