/*
 * network.c
 *
 *  Created on: 2013-3-1
 *      Author: changqian
 */


#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <net/if.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "network.h"
#include "utils.h"


/* select_fd()
 *
 * Check if a socket is ready to write or read.
 * return the socket if success, 0 if timeout reached,
 * or -1 on error.
 *
 * waitfor should be 'WAIT_FOR_READ' or 'WAIT_FOR_WRITE'
 */
int
select_fd(int fd, double maxtime, int waitfor)
{
     fd_set fdset;
     fd_set *rd = NULL;
     fd_set *wr = NULL;
     struct timeval timeout;
     int ret;

     FD_ZERO(&fdset);
     FD_SET(fd, &fdset);
     if (waitfor & WAIT_FOR_READ)
          rd = &fdset;
     if (waitfor & WAIT_FOR_WRITE)
          wr = &fdset;

     timeout.tv_sec  = (long)maxtime;
     timeout.tv_usec = 1000000 * (maxtime - (long)maxtime);

     do {
          ret = select(fd + 1, rd, wr, NULL, &timeout);
     } while (ret < 0 && errno == EINTR);

     return ret;
}



int
set_non_blocking(int fd)
{
	long arg;

	arg = fcntl(fd, F_GETFL, NULL);
	if (arg == -1) {
		return -1;
	}

	arg |= O_NONBLOCK;

	if (fcntl(fd, F_SETFL, arg) == -1) {
		return -1;
	}

	return 0;
}



int
set_blocking(int fd)
{
	long arg;

	arg = fcntl(fd, F_GETFL, NULL);
	if (arg == -1) {
		return -1;
	}

	arg &= (~O_NONBLOCK);

	if (fcntl(fd, F_SETFL, arg) == -1) {
		return -1;
	}

	return 0;
}



int
select_for_read(int fd, double timeout)
{
	return select_fd(fd, timeout, WAIT_FOR_READ);
}



int
select_for_write(int fd, double timeout)
{
	return select_fd(fd, timeout, WAIT_FOR_WRITE);
}



/* sock_read()
 *
 * Read datas from the socket. Return the number of bytes read if success,
 * 0 if EOF reached (connection closed), or -1 if error.
 *
 * If `timeout` is set with 0 or negetive, the function will
 * work in a block way.
 */

int sock_read(int fd, void *buf, size_t bufsize, double timeout)
{
     int ret;

     if (timeout > 0) {
          ret = select_fd(fd, timeout, WAIT_FOR_READ);
          if (ret == 0)
               errno = ETIMEDOUT;
          if (ret <= 0)
               return -1;
     }

     do {
          ret = read(fd, buf, bufsize);
     } while (ret == -1 && errno == EINTR);

     return ret;
}



/* sock_peek()
 *
 * Like the sock_read() but not really read data.
 */

int sock_peek(int fd, void *buf, int bufsize, double timeout)
{
    int ret, peeklen;

    if (timeout > 0) {
        ret = select_fd(fd, timeout, WAIT_FOR_READ);
        if (ret == 0)
            errno = ETIMEDOUT;
        if (ret <= 0)
            return -1;
    }

    do {
        peeklen = recv(fd, buf, bufsize, MSG_PEEK);
    } while(peeklen == -1 && errno == EINTR);

    if (ret > 0 && peeklen == 0) { /* connection closed */
        errno = 0; /* careful of remaining ETIMEDOUT */
        return -1;}

    return peeklen;
}


/* sock_read_line()
 *
 * Read a line from socket ending with "\r\n".
 * TODO: improve the part of searching "\r\n".
 */
int
sock_read_line(int fd, char **line, size_t *size, double timeout)
{
     const size_t origsize = *size;
     char *buf = (char*)(*line);
     char *current;
     size_t bufsize, readsum, remain;
     int ret;
     const char *crlf;

     crlf = NULL;
     bufsize = origsize;
     remain  = bufsize;
     current = buf;
     readsum = 0;

     while (1) {
          if (crlf == NULL) {
               ret = sock_peek(fd, current, remain, timeout);
               if (ret <= 0)
                    break;

               crlf = (const char*)bufbuf(buf, readsum + ret, "\r\n", 2);
               if (crlf)
                    remain = crlf - current;
          }

          ret = sock_read(fd, current, remain, timeout);

          if (ret <= 0)
               break;
          current += ret;
          remain  -= ret;
          readsum += ret;
          if (remain == 0) {
               if (crlf) {
                    ret = 1;
                    break;
               } else {
                    bufsize += origsize;
                    buf = (char*)realloc(buf, bufsize);
                    current = buf + readsum;
                    remain = origsize;
               }
          }
     }

    if (readsum == bufsize) {
          bufsize++;
          buf = (char*)realloc(buf, bufsize);
     }

     *line = buf;
     *size = readsum;
     *(*line + readsum) = '\0';


     return ret;
}


/* sock_read_head()
 *
 * Used to read http request or response head.
 * TODO: change the part for searching "\r\n\r\n".
 */

int sock_read_head(int fd, char **head, size_t *size, double timeout)
{
     const size_t origsize = *size;
     char *buf = (char*)(*head);
     char *current;
     size_t bufsize, readsum, remain;
     int ret;
     const char *crlf;

     crlf = NULL;
     bufsize = origsize;
     remain  = bufsize;
     current = buf;
     readsum = 0;

     while (1) {
          if (crlf == NULL) {
               ret = sock_peek(fd, current, remain, timeout);
               if (ret <= 0)
                    break;
               crlf = (const char*)bufbuf(buf, readsum + ret, "\r\n\r\n", 4);
               if (crlf)
                    remain = crlf - current;
          }
          ret = sock_read(fd, current, remain, timeout);
          if (ret <= 0)
               break;
          current += ret;
          remain  -= ret;
          readsum += ret;
          if (remain == 0) {
               if (crlf) {
                    ret = 1;
                    break;
               } else {
                    bufsize += origsize;
                    buf = (char*)realloc(buf, bufsize);
                    current = buf + readsum;
                    remain = origsize;
               }
          }
     }

     if (readsum == bufsize) {
          bufsize++;
          buf = (char*)realloc(buf, bufsize);
     }

     *head = buf;
     *size = readsum;
     *(*head + readsum) = '\0';

     return ret;
}


/* Read given mount of bytes from socket, succeed only when
 * the exact mount of bytes has been received. */

int
sock_read_data(int fd, char *buf, size_t nbytes, double timeout)
{
    int ret;
    size_t remain;
    char *curptr;

    remain = nbytes;
    curptr = buf;
    while (remain > 0) {
        ret = sock_read(fd, curptr, remain, timeout);
        if (ret <= 0)
            break;
        remain -= ret;
        curptr += ret;
    }

    return (remain == 0) ? 0 : -1;
}


int
connect_to_ip(int sock, const char *ip, int port)
{
    int ret;
    struct sockaddr_in sin;

    memset(&sin, 0, sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_port = htons(port);
    ret = inet_pton(AF_INET, ip, &sin.sin_addr);
    if (ret != 1)
        return -1;

    return connect(sock, (struct sockaddr *) &sin, sizeof sin);
}


int
sock_read_until_closed(int fd, char **body, size_t *size, double timeout)
{
     const size_t origsize = *size;
     char *buf = (char*)(*body);
     char *current;
     size_t readsum, remain, bufsize;
     int ret;

     current = buf;
     bufsize = origsize;
     readsum = 0;
     remain  = bufsize;

     while (1) {

          ret = sock_read(fd, current, remain, timeout);

          if (ret <= 0)
               break;

          current += ret;
          remain  -= ret;
          readsum += ret;

          if (remain == 0) {
               bufsize += origsize;
               buf      = (char*)realloc(buf, bufsize);
               current  = buf + readsum;
               remain   = origsize;
          }
     }

     if (bufsize == readsum) {
          bufsize++;
          buf = (char*)realloc(buf, bufsize);
     }

     *body = buf;
     *size = readsum;
     *(*body + readsum) = '\0';

     return ret;
}
