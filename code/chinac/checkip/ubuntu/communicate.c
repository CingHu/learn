/*
 * communicate.c
 *
 *  Created on: 2013-3-7
 *      Author: changqian
 */



#include "lib/utils.h"
#include "inetface.h"
#include "config.h"
#include "request.h"
#include "response.h"



static char *
read_response_head(int fd, double timeout)
{
    int ret;
    size_t size;
    char *buf;

    size = 512;
    buf = malloc(size);

    ret = sock_read_head(fd, &buf, &size, timeout);

    if (ret < 0) {
        log_error("sock_read_head() failed: %s", strerror(errno));
        free(buf);
        return NULL;
    }

    if (ret == 0)
        buf[0] = '\0';

    log_debug("Response head:\n%s", buf);

    return buf;
}



static bool
read_response_content_close(int fd, double timeout, http_response_t *resp)
{
    int ret;
    size_t size;
    char *buf;

    size = 512;
    buf = malloc(size);

    ret = sock_read_until_closed(fd, &buf, &size, timeout);

    if (ret < 0) {
        log_error("sock_read_until_closed() failed: %s", strerror(errno));
        free(buf);
        return false;
    }

    resp->body = buf;

    log_debug("Response body content:\n%s", resp->body);

    return true;
}



static bool
read_response_content_keepalive(int fd, double timeout, http_response_t *resp)
{
    int ret, len;
    char *buf;
    const char *contlen;

    contlen = hresp_get_header(resp, "Content-Length");

    if (contlen == NULL) {
        log_error("Header \"Content-Length\" not found");
        return false;
    }

    len = atoi(contlen);

    if (len == 0) {
        resp->body = strdup("");
        return true;
    }

    buf = malloc(len + 1);

    ret = sock_read_data(fd, buf, len, timeout);

    if (ret < 0) {
        log_error("sock_read_data() failed: %s", strerror(errno));
        return false;

    }

    buf[len] = '\0';
    resp->body = buf;

    log_debug("Response body content:\n%s", resp->body);

    return true;
}



static bool
read_response_content(int fd, http_response_t *resp, double timeout)
{
    const char *conn;

    conn = hresp_get_header(resp, "Connection");

    if (conn == NULL) {
        log_error("Header \"Connection\" not found");
        return false;
    }

    if (0 == strcasecmp(conn, "close"))
        return read_response_content_close(fd, timeout, resp);

    if (0 == strcasecmp(conn, "Keep-Alive"))
        return read_response_content_keepalive(fd, timeout, resp);

    log_error("Header \"Connection\" has invalid value: %s", conn);

    return false;
}



static http_response_t *
read_response(int fd, double timeout)
{
    char *head = NULL;
    http_response_t *resp = NULL;

    head = read_response_head(fd, timeout);

    if (head == NULL) {
        log_error("Could not read response head");
        return NULL;
    }

    resp = http_response_new(head, NULL);

    read_response_content(fd, resp, timeout);

    if (resp->body == NULL) {
        log_error("Could not read response content");
        http_response_free(resp);
        return NULL;
    }

    return resp;
}



header_list_t *
talk_to_server(int sock, inetface_t *iface)
{
    int ret = -1;
    http_request_t *req;
    http_response_t *resp;
    header_list_t *list;

    log_info("Sending request...");

    req = make_request(iface->mac);

    ret = send_request(sock, req);

    if (ret == -1) {
        log_error("Sending request failed");
        http_request_free(req);
        return NULL;
    }

    resp = read_response(sock, 5);

    if (resp == NULL) {
        log_error("Reading response failed");
        http_request_free(req);
        return NULL;
    }

    list = handle_response(resp);

    http_request_free(req);
    http_response_free(resp);

    return list;
}




int
connect_ip_with_timeout(int sock, char *ipaddr, int port, double timeout)
{
	int ret;
	struct sockaddr_in addr;

	if (set_non_blocking(sock) == -1) {
		log_error("Set non-blocking failed: %s", strerror(errno));
		return -1;
	}

	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);
	if (inet_pton(AF_INET, ipaddr, &addr.sin_addr) == -1) {
		log_error("inet_pton(%s) failed: %s", ipaddr, strerror(errno));
		return -1;
	}

	ret = connect(sock, (struct sockaddr *) &addr, sizeof(addr));

	if (ret == -1) {
		if (errno != EINPROGRESS) {
			log_error("connect() failed: %s", strerror(errno));
			return -1;
		}

		ret = select_for_write(sock, timeout);

		if (ret == 0) {
			log_error("Connection timeout");
			return -1;
		}

		if (ret == -1) {
			log_error("select() error: %s", strerror(errno));
			return -1;
		}

		int optval;
		socklen_t optlen;

		if (getsockopt(sock, SOL_SOCKET, SO_ERROR, (void*)(&optval), &optlen) == -1) {
			log_error("getsockopt() error: %s", strerror(errno));
			return -1;
		}

		if (optval != 0) {
			log_error("Connection error: %s", strerror(optval));
			return -1;
		}

	}

	if (set_blocking(sock) == -1) {
		log_error("Set blocking failed: %s", strerror(errno));
		return -1;
	}

	return 0;
}



int
connect_to_server_with_timeout(double timeout)
{
	int try, i, ret, sock;

	for (try = 0; try < Config.conn_retry; try++) {
		for (i = 0; i < Config.proxy_list->count; i++) {

			sock = socket(AF_INET, SOCK_STREAM, 0);

			if (sock == -1) {
				log_error("socket() failed: %s", strerror(errno));
				break;
			}

			log_info("Connecting to proxy server %s", Config.proxy_list->data[i]);
			ret = connect_ip_with_timeout(sock, Config.proxy_list->data[i], Config.conn_port, timeout);

			if (ret == 0) {
				log_info("Connected to proxy server %s", Config.proxy_list->data[i]);
				Config.conn_host = Config.proxy_list->data[i];
				return sock;
			}
		}

		sleep(5);
	}

	return -1;
}



int
connect_to_server(void)
{
    int i, ret, sock;

    sock = socket(AF_INET, SOCK_STREAM, 0);

    if (sock == -1) {
        log_error("socket() failed: %s", strerror(errno));
        return -1;
    }

    for (i = 0; i < Config.conn_retry; i++) {
        log_info("Connect to server %s:%d (try num = %d)", Config.conn_host,
                 Config.conn_port, i + 1);

        ret = connect_to_ip(sock, Config.conn_host, Config.conn_port);

        if (ret == 0)
            return sock;

        log_error("connect_to_ip() failed: %s", strerror(errno));
    }

    close(sock);

    return -1;
}



header_list_t *
retrieve_configuration(inetface_t *iface)
{
    int sock;
    header_list_t *list;

    sock = connect_to_server_with_timeout(3);

    if (sock == -1) {
        log_error("Could not connect to server");
        return NULL;
    }

    list = talk_to_server(sock, iface);

    close(sock);

    return list;
}




