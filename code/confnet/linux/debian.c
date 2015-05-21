#include "common.h"
#include "interface.h"
#include "logger.h"
#include "utils.h"

#ifdef DEBUG_F
#define INTERFACES  "/tmp/interfaces"
#else
#define INTERFACES  "/etc/network/interfaces"
#endif

#define ADDRESS_S  "address"
#define DNS_S  "dns-nameservers"

extern int    g_dev_counter;
extern char   g_external_name[MAC_ADDR_LEN];
extern char   g_internal_name[MAC_ADDR_LEN];

/*
    restart network
*/
bool debian_restart_network(void)
{
    int ret;

    log_info("Restart network service");

    ret = system("/etc/init.d/networking restart");
    if (ret != 0) {
        log_error("Restarting network service failed");
        return false;
    }

    return true;
}

/*
    config loopback interface
*/
void debain_loopback_if(FILE *fp)
{
    fprintf(fp, "auto lo\n");
    fprintf(fp, "iface lo inet loopback\n");
    fprintf(fp, "\n");
    return;
}


/*
    config ineternal interface
*/
void  debain_internal_if(FILE *fp, const char *name)
{

    fprintf(fp, "auto %s\n", name);
    fprintf(fp, "iface %s inet %s\n", name, "dhcp");
    fprintf(fp, "\n");

    return;
}


void _get_if_name(int flag, const char* name, char* if_name)
{
    if(flag == MASTER_FLAG)
       strcpy(if_name, name);
    else
    {
       g_dev_counter++;
       sprintf(if_name,"%s:%d", name, g_dev_counter);
    }

    return;
}

/*
config dns
*/


/*
    config external interface
*/
void  debain_external_if(FILE *fp, const struct inet_t *inet, const char* name)
{

    struct pair_t* pos;
    bool flag = false;

    fprintf(fp, "auto %s\n", name);
    fprintf(fp, "iface %s inet %s\n", name, "static");

    list_for_each_entry(pos, &(inet->pair.list), list)
    {
        if(stringfind(pos->key,"DNS") != -1)        
        {
           fprintf(fp, "\t%s  %s\n",DNS_S, pos->value);
           flag = true;
        }
        else if(stringfind(pos->key, "IPADDR") != -1)
        {
            fprintf(fp,"\t%s %s\n", ADDRESS_S, pos->value);
        }
        else
        {
            fprintf(fp,"\t%s %s\n", str_lower(pos->key), pos->value);
        }

    }

    if(!flag)
    {
         fprintf(fp, "\tdns-nameservers %s\n", DEFAULT_DNS1);
    }

    fprintf(fp, "\n");
    return;
}


bool debain_config_if_file()
{
    FILE *fp;
    struct inet_t *ifnet;
    int i = 0;
    char name[DEVICE_NAME_LEN] = {0};

    fp = fopen(INTERFACES, "w");
    if (fp == NULL) 
    {
        log_error("Could not open file %s: %s", INTERFACES, strerror(errno));
        return false;
    }

    g_dev_counter = 0;

    //配置loopback与内网interface
    debain_loopback_if(fp);

    if(strlen(g_internal_name) != 0)
        debain_internal_if(fp, g_internal_name);

    for(;i < g_inet_num; i++)
    {
       ifnet = &g_inet_array[i];

       if(strlen(ifnet->name) == 0)
           continue;
         
        _get_if_name(ifnet->flag, ifnet->name, name);
        debain_external_if(fp, ifnet, name);
    }

    g_dev_counter = 0;

    fclose(fp);
    
    return true; 
}




