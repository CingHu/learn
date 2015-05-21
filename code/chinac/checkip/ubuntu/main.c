/*
 * main.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */



#include "lib/utils.h"
#include "config.h"
#include "inetface.h"
#include "inetconf.h"
#include "passwd.h"
#include "communicate.h"



void
get_ip(inetface_t *iface, bool update_hwaddr)
{
    header_list_t *list;

    if (!iface->up || (iface->up && is_ip_public(iface->ip))) {
        if (!switch_to_private_network(iface)) {
            log_error("Could not switch to private network");
            return;
        }
    }

    list = retrieve_configuration(iface);


    if (list == NULL) {
        log_error("Could not retrieve configuration information");
        return;
    }

    configure_network(iface, list, update_hwaddr);

    if (Config.update_passwd)
        configure_password(list);

    header_list_free(list);
}



void
check_network_interface(inetface_t *iface)
{
    bool ok;
    bool update_hwaddr = false;
    char hwaddr_pathname[PATH_MAX];
    char old_hwaddr[20];

    snprintf(hwaddr_pathname, PATH_MAX, "/etc/checkip/%s.hwaddr", iface->name);

    if (!file_exist(hwaddr_pathname)) {
        log_info("File %s does not exist", hwaddr_pathname);
        update_hwaddr = true;
        get_ip(iface, update_hwaddr);
        return;
    }

    ok = read_inetface_hwaddr(iface, old_hwaddr);

    if (!ok) {
        log_fatal("Could read old NIC hardware address");
        return;
    }

    if (0 == strcasecmp(old_hwaddr, iface->mac) && is_ip_public(iface->ip)) {
        log_info("%s is up and got a public IP, nothing to do", iface->name);
        return;
    }

    if (0 != strcasecmp(old_hwaddr, iface->mac)) {
        log_info("Hardware address changed (%s to %s), this is a new card",
                 old_hwaddr, iface->mac);
        update_hwaddr = true;
    }

    get_ip(iface, update_hwaddr);
}



void
check_all_network_interfaces(void)
{
    inetface_t *ifaces, *i;

    ifaces = load_if_info();

    if (ifaces == NULL) {
        log_fatal("Could not load network interface information");
        exit(1);
    }

    log_if_info(ifaces);

    for (i = ifaces; i; i = i->next)
        check_network_interface(i);

    if_list_free(ifaces);
}



int
main(void)
{
    bool ok;
    int ret;

    ok = initialize();

    if (!ok) {
        terminate();
        return 1;
    }

    ok = log_init(Config.logfile, Config.debug);

    if (!ok) {
        terminate();
        return 1;
    }

    if (Config.background) {

        ret = fork_to_background();

        if (ret == -1) {
            terminate();
            return 1;
        }

        if (ret > 0) {
            terminate();
            return 0;
        }
    }

    log_info("=== IP checking service starts ===");

    check_all_network_interfaces();

    terminate();

    return 0;
}









