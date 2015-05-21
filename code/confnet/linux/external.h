#ifndef EXTERNAL_H
#define EXTERNAL_H

bool ex_get_name_by_mac(const char *mac, char* if_name);
bool ex_get_ip_by_name(const char* if_name, char* ipaddress);
bool config_if(void);
bool ex_restart_network(void);
bool ex_restart_interface(const char *name);

#endif
