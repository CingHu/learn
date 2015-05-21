/*
 * config.c
 *
 *  Created on: 2013-3-7
 *      Author: changqian
 */



#include "lib/utils.h"
#include "checkip.h"



#define AESKEY    "gxiao13860420817"
#define AESVECTOR "0102030405060708"
#define MD5KEY    "lanmang1qaz2wsx"

#define HOST "192.168.0.4"
#define PAGE "/server/default.php"
#define PORT 89

#define LOGDIR       "/var/log/checkip"
#define CONFIG_FILE  "/etc/checkip/checkip.conf"
#define PROXY_CONF   "/etc/checkip/proxy.conf"



struct config Config;
static header_list_t *List;



static void
make_logfile_pathname(void)
{
    time_t t;
    struct tm *tm;
    char buf[64];

    t = time(NULL);
    tm = localtime(&t);
    strftime(buf, sizeof buf, "%Y-%m-%d", tm);
    snprintf(Config.logfile, PATH_MAX, LOGDIR "/%s.log", buf);
}



static void
init_default(void)
{
    Config.update_passwd = false;

    Config.background = true;
    Config.debug = true;

    Config.config_file = CONFIG_FILE;

    Config.conn_retry = 5;
    Config.conn_host = HOST;
    Config.conn_port = PORT;
    Config.post_page = PAGE;

    Config.aeskey = AESKEY;
    Config.aesiv = AESVECTOR;
    Config.md5key = MD5KEY;

    Config.proxy_list = string_list_new();

    make_logfile_pathname();
}



bool
load_proxy_config()
{
	if (file_exist(PROXY_CONF)) {

		int i;
		char *line;
		string_list_t *lines;

		lines = sl_load_file(PROXY_CONF);
		if (lines == NULL) {
			fprintf(stderr, "Could not load file %s: %s", PROXY_CONF, strerror(errno));
			return false;
		}

		for (i = 0; i < lines->count; i++) {
			line = str_strip(lines->data[i]);
			if (*line) {
				sl_append(Config.proxy_list, strdup(line));
			}
		}

		string_list_free(lines);

		if (Config.proxy_list->count == 0) {
			fprintf(stderr, "%s has no proxy servers", PROXY_CONF);
			return false;
		}

	} else {
		sl_append(Config.proxy_list, strdup(HOST));
	}

	return true;
}


bool
load_config(const char *pathname)
{
    int i;
    header_t *h;

    List = hl_load_config(pathname); /* Ignore invalid lines */

    if (List == NULL) {
        fprintf(stderr, "Could load configuration file (%d: %s)\n",
                 errno, strerror(errno));
        return false;
    }

    for (i = 0; i < List->count; i++) {
        h = &List->data[i];

        if (0 == strcasecmp(h->name, "DEBUG_MODE"))
            Config.debug = string_to_bool(h->value);

        else if (0 == strcasecmp(h->name, "FORK_BACKGROUND"))
            Config.background = string_to_bool(h->value);

        else if (0 == strcasecmp(h->name, "UPDATE_PASSWORD"))
            Config.update_passwd = string_to_bool(h->value);

        else if (0 == strcasecmp(h->name, "CONNECTION_RETRY"))
            Config.conn_retry = atoi(h->value);

        /* Ignore invalid or unconcerned options */
    }

    return true;
}


static bool
check_logdir(void)
{
    bool ok;
    char logdir[PATH_MAX];

    extract_dirpath(logdir, PATH_MAX, Config.logfile);

    if (!file_exist(logdir)) {
        ok = create_directory(logdir, 0755);

        if (!ok) {
            fprintf(stderr, "Could create directory %s: %s", logdir,
                     strerror(errno));
            return false;
        }
    }

    return true;
}



static bool
check_config_dir(void)
{
    bool ok;
    char configdir[PATH_MAX];

    extract_dirpath(configdir, PATH_MAX, Config.config_file);

    if (!file_exist(configdir)) {
        log_info("Create directory %s", configdir);
        ok = create_directory(configdir, 0755);

        if (!ok) {
            log_error("Could create directory %s: %s", configdir,
                      strerror(errno));
            return false;
        }
    }

    return true;
}



static bool
check_directory(void)
{
    bool ok;

    ok = check_logdir();

    if (!ok)
        return false;

    ok = check_config_dir();

    return ok;
}



bool
initialize(void)
{
    init_default();

    check_directory();

    if (!load_proxy_config())
    	return false;

    if (file_exist(Config.config_file)) {
        return load_config(Config.config_file);
    }

    return true;
}



void
terminate(void)
{
    if (List != NULL)
        header_list_free(List);
    string_list_free(Config.proxy_list);
}



bool
read_inetface_hwaddr(inetface_t *iface, char buf[18])
{
    int fd, ret;
    char pathname[PATH_MAX];

    snprintf(pathname, PATH_MAX, "/etc/checkip/%s.hwaddr", iface->name);

    fd = open(pathname, O_RDONLY);

    if (fd == -1) {
        log_error("Could open file %s (%d: %s)", errno, strerror(errno));
        return false;
    }

    ret = read(fd, buf, 17);

    if (ret != 17) {
        log_error("Could read from hardware address (%d: %s)",
                  errno, strerror(errno));
        close(fd);
        return false;
    }

    buf[17] = '\0';

    close(fd);
    return true;
}



bool
update_inetface_hwaddr(inetface_t *iface)
{
    int fd, ret;
    char pathname[PATH_MAX];

    snprintf(pathname, PATH_MAX, "/etc/checkip/%s.hwaddr", iface->name);

    fd = open(pathname, O_WRONLY | O_CREAT, 0644);

    if (fd == -1) {
        log_error("Could not create/open file %s (%d, %s)",
                  pathname, errno, strerror(errno));
        return false;
    }

    ret = write(fd, iface->mac, strlen(iface->mac));

    if (ret != strlen(iface->mac)) {
        log_error("Could not write hardware address to file (%d: %s)",
                  errno, strerror(errno));
        close(fd);
        return false;
    }

    close(fd);
    return true;
}



bool
update_password_config()
{
    bool ok;
    header_list_t *list;

    log_info("Update password configuration, updating password is done");

    if (file_exist(Config.config_file)) {
        list = hl_load_config(Config.config_file);

        if (list == NULL) {
            log_error("Could not load configuration");
            return false;
        }

    } else {
        list = header_list_new();
    }

    hl_set(list, "update_password", "no", rel_none);

    ok = hl_write_config(Config.config_file, list);

    if (!ok) {
        log_error("Could not write configuration");
        return false;
    }

    header_list_free(list);

    return true;
}
