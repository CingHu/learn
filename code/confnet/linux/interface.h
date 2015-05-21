/*
 * inetface.h
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */

#ifndef INETFACE_H_
#define INETFACE_H_

#include <net/if.h>
#include "common.h"



bool is_ip_public(const char *ip);
inetface_t *load_if_info(void);
void if_list_free(inetface_t *head);
void log_if_info(inetface_t *ifaces);

bool restart_interface(const char* mac);
bool get_ip_by_name(const char* if_name, char* ipaddress);
bool get_nic_name(void);
bool get_name_by_mac(const char* mac, char* if_name);



#endif /* INETFACE_H_ */

