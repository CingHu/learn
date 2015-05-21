/*
 * inetconf.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */



#include "lib/utils.h"
#include "inetconf.h"
#include "config.h"



#define RESOLV_CONF "/etc/resolv.conf"
#define INTERFACES  "/etc/network/interfaces"



bool
debian_restart_network(void)
{
    int ret;

    log_info("Restart network service");

    ret = system("/etc/init.d/networking restart");

    if (ret != 0 && errno == 0) {
        log_error("Restarting network service failed");
        return false;
    }

    return true;
}



bool
debian_configure_if(const char *ifname, const char *ipaddr,
                       const char *gateway, const char *netmask,
                       const char *dns)
{
    FILE *fp;

    fp = fopen(INTERFACES, "w");

    if (fp == NULL) {
        log_error("Could not open file %s: %s", INTERFACES, strerror(errno));
        return false;
    }

    // TODO: overwriting may not work well with multiple card
    // TODO: need error checking!

    fprintf(fp, "auto lo\n");
    fprintf(fp, "iface lo inet loopback\n");
    fprintf(fp, "auto %s\n", ifname);
    fprintf(fp, "iface %s inet static\n", ifname);
    fprintf(fp, "\taddress %s\n", ipaddr);
    fprintf(fp, "\tnetmask %s\n", netmask);
    fprintf(fp, "\tgateway %s\n", gateway);
    fprintf(fp, "\tdns-nameservers %s\n", dns);

    fclose(fp);

    return true;
}



bool
debian_configure_dns(const char *dns)
{
    int ret;
    FILE *fp;

    log_info("Update DNS configuration");

    fp = fopen(RESOLV_CONF, "w");

    if (fp == NULL) {
        log_error("Could not open file %s: %s", RESOLV_CONF, strerror(errno));
        return false;
    }

    ret = fprintf(fp, "nameserver %s\n", dns);

    if (ret < 0) {
        log_error("Could not write to file %s: %s", RESOLV_CONF,
                  strerror(errno));
        fclose(fp);
        return false;
    }

    fclose(fp);

    return true;
}



bool
switch_to_private_network(inetface_t *iface)
{
    bool ok;
    FILE *fp;

    fp = fopen(INTERFACES, "w");

    if (fp == NULL) {
        log_error("Could not open file %s: %s", INTERFACES, strerror(errno));
        return false;
    }

    fprintf(fp, "auto lo\n");
    fprintf(fp, "iface lo inet loopback\n");
    fprintf(fp, "auto %s\n", iface->name);
    fprintf(fp, "iface %s inet dhcp\n", iface->name);

    fclose(fp);

    ok = debian_restart_network();

    return ok;
}



bool
debian_configure_network(const char *ifname, const char *ipaddr,
                             const char *gateway, const char *netmask,
                             const char *dns)
{
    bool ok;

    ok = debian_configure_if(ifname, ipaddr, gateway, netmask, dns);

    if (!ok)
        return false;

    ok = debian_configure_dns(dns);

    if (!ok) {
        log_error("Could not update DNS configuration file");
        return false;
    }

    ok = debian_restart_network();

    if (!ok)
        return false;

    return true;
}



#define CHECKVAR(var)                                                   \
    do {                                                                \
        if (var == NULL) {                                              \
            log_error("Variable $" #var "is empty");                    \
            return;                                                     \
        } else {                                                        \
            log_debug("Value of variable: " #var " = %s", var);         \
        }                                                               \
    } while (0)

void
configure_network(inetface_t *iface, header_list_t *list, bool update_hwaddr)
{
    bool ok;
    const char *ipaddr, *gateway, *netmask, *dns;

    ipaddr = hl_get(list, "Ip");
    gateway = hl_get(list, "Gateway");
    netmask = hl_get(list, "Netmask");
    dns = hl_get(list, "Dns");

    CHECKVAR(ipaddr);
    CHECKVAR(gateway);
    CHECKVAR(netmask);
    CHECKVAR(dns);

    ok = debian_configure_network(iface->name, ipaddr, gateway, netmask, dns);

    if (ok && update_hwaddr) {
        ok = update_inetface_hwaddr(iface);
        if (!ok)
            log_error("Could not update hardware address in configuration file");
    }
}


#undef CHECKVAR
