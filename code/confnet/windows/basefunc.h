#ifndef BASEFUNC_H
#define BASEFUNC_H


int stringfind(const char *pSrc, const char *pDst);
char* left(char *dst,char *src, int n);
char* str_lower(const char *str);

int save_pair(struct inet_t *inet, char* key, char* value);
void log_inet_info(void);

int alloc_mem(void);
void free_mem(void);





#endif
