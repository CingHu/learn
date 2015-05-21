/*
 * config.h
 *
 *  Created on: 2013-3-7
 *      Author: changqian
 */

#ifndef CONFIG_H_
#define CONFIG_H_



#include "lib/utils.h"
#include "inetface.h"


struct config {
    bool debug;

    bool update_passwd;
    bool background;

    const char *config_file;
    char logfile[PATH_MAX];

    int conn_retry;
    int conn_port;
    const char *conn_host;
    const char *post_page;

    const char *aeskey;
    const char *aesiv;
    const char *md5key;

    string_list_t *proxy_list;
};



extern struct config Config;



bool read_inetface_hwaddr(inetface_t *iface, char buf[18]);
bool update_inetface_hwaddr(inetface_t *iface);
bool update_password_config(void);
bool initialize(void);
void terminate(void);


#endif /* CONFIG_H_ */
