#include "common.h"

#include "logger.h"
#include "inet.h"
#include "interface.h"
#include "utils.h"
#include "external.h"
#include "basefunc.h"

extern int    g_version;


void print_func()
{
    printf("input param error, please check input param!\n");
    printf("help:\n");
    printf("\tget_name_by_mac mac\n");
    printf("\tinterface\n");
    printf("\treset_interface mac\n");
    printf("\treset_all_interface\n");
}

int return_error(void)
{
    printf("%d\n",0);
    return -1;
}

int return_ok(void)
{
    printf("%d\n",1);
    return 0;
}

int return_value(bool rt)
{
   if(!rt)
   {
       return return_error();
   }
   else
   {
       return return_ok();
   }
}

int main(int argc, char *argv[])
{

    bool rt = false;
    char name[DEVICE_NAME_LEN];
    char mac[MAC_ADDR_LEN];
    char func[128];

    if(argc < 2)
    {
#ifdef DEBUG_F
        print_func();
#endif
        return return_error();
    }
   
    strcpy(func, argv[1]);

    log_init(LOG_NAME, true);

    log_info("recevie msg, func:%s\n", func);

    if(get_version(&g_version))
    {
        log_error("get version failed\n");
        return return_error();
    }

    get_nic_name();

    if(strcmp(func, "get_name_by_mac") == 0 && argc == 3)
    {
        strcpy(mac, argv[2]);
        rt = ex_get_name_by_mac(mac, name);
        if(rt)
        {
            printf("%s\n",name);
            return 0;
        }
        else
            return return_error();
    }

    if( RT_SUCCESS != parase_dir_file())
    {
       rt = log_info("parase dif faild \n"); 
       goto end;
    }

    if(strcmp(func, "interface") == 0 && argc == 2)
    {
       rt = config_if();
       goto end;
    }
    else if(strcmp(func, "reset_interface") == 0 && argc == 3)
    {
        strcpy(mac, argv[2]);
        rt = ex_restart_interface(mac);
        goto end;
    }
    else if(strcmp(func, "reset_all_interface") == 0 && argc == 2)
    {
        rt = ex_restart_network();
        goto end;
    }
    else
    {
#ifdef DEBUG_F
        print_func();
#endif
        rt = false;
        goto end;
    }


end:

    log_inet_info();
    free_mem();
      
    return return_value(rt);
}
