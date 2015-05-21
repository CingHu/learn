/*
 * network.h
 *
 *  Created on: 2013-3-1
 *      Author: changqian
 */


#ifndef NETWORK_H_
#define NETWORK_H_


#include <stdlib.h>


enum {
    WAIT_FOR_READ  = 1,
    WAIT_FOR_WRITE = 2
};


int connect_to_ip(int sock, const char *ip, int port);
int sock_read(int fd, void *buf, size_t bufsize, double timeout);
int sock_read_line(int fd, char **lien, size_t *size, double timeout);
int sock_read_head(int fd, char **head, size_t *size, double timeout);
int sock_read_data(int fd, char *buf, size_t nbytes, double timeout);
int sock_read_until_closed(int fd, char **body, size_t *size, double timeout);
int set_non_blocking(int fd);
int set_blocking(int fd);
int select_for_read(int fd, double timeout);
int select_for_write(int fd, double timeout);


#endif /* NETWORK_H_ */
