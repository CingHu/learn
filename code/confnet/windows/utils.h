#ifndef UTILS_H
#define UTILS_H

#include "common.h"


int alloc_mem(void);
void free_mem(void);

int save_pair(struct inet_t *inet, char* key, char* value);
void log_inet_info(void);


#endif
