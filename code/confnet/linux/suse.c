#include "common.h"
#include "interface.h"
#include "logger.h"
#include "utils.h"


extern char g_net_file_path[50];

#ifdef DEBUG_F
#define NETWORK_PATH "/tmp/"
#else
#define NETWORK_PATH g_net_file_path
#endif

#define ROUTE_PATH "/etc/sysconfig/network/routes"

extern int    g_dev_counter;
extern char   g_external_name[MAC_ADDR_LEN];

/*
    restart network
*/
bool suse_restart_network(void)
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

void _suse_get_key_name(const char* key, int flag, int num, char *key_name)
{
    if(flag == MASTER_FLAG)
       sprintf(key_name, "%s",key);
    else
    {
       sprintf(key_name, "%s_%d",key, num);
    }

    return; 
}

void _suse_get_if_file_name(const char* name, char *if_name)
{
   
    sprintf(if_name, "%s%s%s",NETWORK_PATH, "ifcfg-",name);

    return; 
}



void suse_external_if(FILE* fp, struct inet_t *inet, int *num)
{
    struct pair_t* pos;
    bool flag = false;

    char key_name[KEY_LEN]={0};
    char route_name[KEY_LEN]={0};
    FILE *fp_r;

    if(inet->flag == MASTER_FLAG)
    {
        fprintf(fp, "DEVICE=%s\n", g_external_name);
        fprintf(fp, "ONBOOT=YES\n");
        fprintf(fp, "BOOTPROTO=static\n");
        fprintf(fp, "STARTMODE=auto\n");
    }
    else
    {
        (*num)++;
        fprintf(fp, "LABEL_%d=%d\n", *num, *num);
    }

    list_for_each_entry(pos, &(inet->pair.list), list)
    {
        if(stringfind(pos->key,"DNS") != -1)        
        {
           flag = true;
        }

      _suse_get_key_name(pos->key, inet->flag, *num, key_name);
      fprintf(fp,"%s=%s\n", key_name, pos->value);
      memset(key_name,0, sizeof(char)*KEY_LEN);
      if(stringfind(pos->key, "GATEWAY") != -1)
      {
          fp_r = fopen(ROUTE_PATH, "w");
          if (fp_r == NULL) 
          {
              log_error("Could not open file %s: %s", ROUTE_PATH, strerror(errno));
              return false;
          }

          fprintf(fp_r,"%s%s\n", "default ",pos->value);

          fclose(fp_r);
      }

    }

    if(!flag&&inet->flag == MASTER_FLAG)
    {
         fprintf(fp, "DNS1 = %s\n", DEFAULT_DNS1);
         fprintf(fp, "DNS2 = %s\n", DEFAULT_DNS2);
         flag = false;
    }

   return;
}

bool suse_config_if_file()
{
    FILE *fp;
    struct inet_t *inet;
    int i = 0;
    char name[DEVICE_NAME_LEN] = {0};
    int num = 0;


    _suse_get_if_file_name(g_external_name, name);

    fp = fopen(name, "w");
    if (fp == NULL) 
    {
        log_error("Could not open file %s: %s", name, strerror(errno));
        return false;
    }
   
    for(;i < g_inet_num; i++)
    {
       inet = &g_inet_array[i];

       if(strlen(inet->name) == 0)
           continue;

        suse_external_if(fp, inet, &num);
    }

    fclose(fp);
    
    return true; 
}

