#include "common.h"
#include "interface.h"
#include "logger.h"

extern bool debain_config_if_file();
extern bool debian_restart_network(void);
extern bool centos_config_if_file();
extern bool centos_restart_network(void);
extern bool suse_config_if_file();
extern bool suse_restart_network(void);

extern char g_net_file_path[50];

int    g_version = INVALID;



/*
    get name of interface by mac address
*/
bool ex_get_name_by_mac(const char *mac, char* if_name)
{
    char name[DEVICE_NAME_LEN];
    bool rt = false;
    int pos = 0;
  
    rt = get_name_by_mac(mac, name);
    if(!rt)
    {
       log_error("get name failed\n");
       return false;
    }
 
    pos = stringfind(name, ":"); 
    if(pos > 0)
    {
        left(if_name, name, pos);
    }
    else
    {
        strcpy(if_name, name);
    }
   
    
    return true;
}


/*
    get ip of interface by name
*/

bool ex_get_ip_by_name(const char* if_name, char* ipaddress)
{
    return get_ip_by_name(if_name, ipaddress);
}



bool config_if(void)
{
   bool  rt = false;

   switch(g_version)
   {
       case DEBAIN:
       {
           rt = debain_config_if_file();
           return rt;
       }
   
       case REDHAT:
       {
             strcpy(g_net_file_path, CENTOS_NETWORK_PATH);
             rt = centos_config_if_file();
             return rt;
       }
       case SUSE:
       {
           strcpy(g_net_file_path, SUSE_NETWORK_PATH);
           rt = suse_config_if_file();
           return rt;
       }
       default:
       {
           log_error("the value of version is invalid\n");
       }


   }

   return false;
}

/*
    restart network
*/
bool  ex_restart_network(void)
{
   bool  rt = false;

   switch(g_version)
   {
       case DEBAIN:
       {
           rt = debian_restart_network();
           return rt;
       }
   
       case REDHAT:
       {
           rt = centos_restart_network();
           return rt;
       }
       case SUSE:
       {
           rt = suse_restart_network();
           return rt;
       }
       default:
       {
           log_error("the value of version is invalid\n");
       }


   }
 
   return false;
}

bool ex_restart_interface(const char *name)
{
    return restart_interface(name);
}
