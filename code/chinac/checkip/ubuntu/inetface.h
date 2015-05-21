/*
 * inetface.h
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */

#ifndef INETFACE_H_
#define INETFACE_H_


#include <net/if.h>


typedef struct inetface_s inetface_t;


struct inetface_s {
    bool up;
    char name[IFNAMSIZ];
    char mac[18];
    char ip[16];
    inetface_t *next;
};


bool is_ip_public(const char *ip);
inetface_t *load_if_info(void);
void if_list_free(inetface_t *head);
void log_if_info(inetface_t *ifaces);



#endif /* INETFACE_H_ */
