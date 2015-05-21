/*
 * inetconf.h
 *
 *  Created on: 2013-3-4
 *      Author: changqian
 */

#ifndef INETCONF_H_
#define INETCONF_H_



#include "lib/utils.h"
#include "checkip.h"


void configure_network(inetface_t *, header_list_t *, bool update_hwaddr);
bool switch_to_private_network(inetface_t *);



#endif /* INETCONF_H_ */
