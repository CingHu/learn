#ifndef SHELL_H
#define SHELL_H

int ShellConfIPAddr(char* AdapterName, char* IPAddress, char* Netmask, char* Gateway);
int ShellAddIPAddr(char* AdapterName, char* IPAddress, char* Netmask, char* Gateway);
int ShellDelIPAddr(char* AdapterName, char* IPAddress, char* Gateway);
int config_interface();


#endif