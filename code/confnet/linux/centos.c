#include "common.h"
#include "interface.h"
#include "logger.h"
#include "utils.h"


char g_net_file_path[50] = {0};

#ifdef DEBUG_F
#define NETWORK_PATH "/tmp/"
#else
#define NETWORK_PATH g_net_file_path
#endif

extern int    g_dev_counter;
extern char   g_external_name[MAC_ADDR_LEN];

/*
    restart network
*/
bool centos_restart_network(void)
{
    int ret;

    log_info("Restart network service");

    ret = system("/etc/init.d/network restart");
    if (ret != 0) {
        log_error("Restarting network service failed");
        return false;
    }

    return true;
}

void _centos_get_if_file_name(const char* name, int flag, char *if_name)
{
   
    if(flag == MASTER_FLAG)
       sprintf(if_name, "%s%s%s",NETWORK_PATH, "ifcfg-",name);
    else
    {
       g_dev_counter++;
       sprintf(if_name, "%s%s%s:%d",NETWORK_PATH, "ifcfg-",name, g_dev_counter);
    }

    return; 
}

void _centos_get_if_file_name2(const char* name, int flag, char *if_name)
{
   
    if(flag == MASTER_FLAG)
       sprintf(if_name, "%s",name);
    else
    {
       sprintf(if_name, "%s:%d", name, g_dev_counter);
    }

    return; 
}



void centos_external_if(FILE* fp, struct inet_t *inet, const char* name)
{
    struct pair_t* pos;
    bool flag = false;

    fprintf(fp, "DEVICE=%s\n", name);
    fprintf(fp, "ONBOOT=YES\n");
    fprintf(fp, "BOOTPROTO=static\n");

    list_for_each_entry(pos, &(inet->pair.list), list)
    {
        if(stringfind(pos->key,"DNS") != -1)        
        {
           flag = true;
        }

        fprintf(fp,"%s=%s\n", pos->key, pos->value);

    }

    if(!flag)
    {
         fprintf(fp, "DNS1 = %s\n", DEFAULT_DNS1);
         fprintf(fp, "DNS2 = %s\n", DEFAULT_DNS2);
         flag = false;
    }

   return;
}

bool centos_config_if_file()
{
    FILE *fp;
    struct inet_t *inet;
    int i = 0;
    char name[DEVICE_NAME_LEN] = {0};
    char cmd[128]={0};

    g_dev_counter = 0;

    sprintf(cmd, "rm -f %s%s%s%s", NETWORK_PATH, "ifcfg-", g_external_name,"*");

    system(cmd);

    for(;i < g_inet_num; i++)
    {
       inet = &g_inet_array[i];

       if(strlen(inet->name) == 0)
           continue;

        _centos_get_if_file_name(inet->name, inet->flag, name);

        fp = fopen(name, "w");
        if (fp == NULL) 
        {
            log_error("Could not open file %s: %s", name, strerror(errno));
            return false;
        }
  
        memset(name, 0, DEVICE_NAME_LEN);         

        _centos_get_if_file_name2(inet->name, inet->flag, name);

        centos_external_if(fp, inet, name);

        memset(name, 0, DEVICE_NAME_LEN);         
        fclose(fp);
    }

    g_dev_counter = 0;
    
    return true; 
}

