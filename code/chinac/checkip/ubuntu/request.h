/*
 * request.h
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */

#ifndef REQUEST_H_
#define REQUEST_H_



#include "lib/utils.h"
#include "config.h"



http_request_t *make_request(const char *mac);
int send_request(int fd, http_request_t *req);



#endif /* REQUEST_H_ */
