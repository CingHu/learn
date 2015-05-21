#include "utils.h"

#include "logger.h"


int    g_inet_num = 0;
int    g_inet_max = INET_NUM;
char   g_external_name[MAC_ADDR_LEN]={0};
char   g_internal_name[MAC_ADDR_LEN]={0};

struct inet_t* g_inet_array;

int alloc_mem(void)
{

    int i = 0;

    g_inet_array = (struct inet_t*)malloc(sizeof(struct inet_t)*INET_NUM);
    if(NULL == g_inet_array)
    {
         log_error("alloc mem failed!\n");
         return RT_ERROR;
    }

    memset(g_inet_array, 0, sizeof(struct inet_t)*INET_NUM);

    for(i = 0;i < INET_NUM; i++)
    {
        INIT_LIST_HEAD(&(g_inet_array[i].pair.list));
    }

    return RT_SUCCESS; 
}

void free_mem(void)
{
    int i = 0;

    struct inet_t *ifnet;
    struct pair_t *pos;

    for(;i < g_inet_num; i++)
    {
        ifnet = &g_inet_array[i];
        list_for_each_entry(pos, &(ifnet->pair.list), list)
        {
            list_del(&(pos->list));
            free(pos);
            pos = &(ifnet->pair);
        }
    }

    free(g_inet_array); 
    g_inet_num = 0;
    g_inet_array = NULL;
  
}

int save_pair(struct inet_t* inet, char* key, char* value)
{
    struct pair_t* new;
    
    new = malloc(sizeof(struct pair_t));
    if(NULL == new)
    {
       log_error("alloc pair mem failed \n");
       return RT_ERROR;
    }

    memset(new, 0, sizeof(struct pair_t));

    strcpy(new->key, key);
    strcpy(new->value, value);

    list_add(&(new->list),&(inet->pair.list));

    return RT_SUCCESS;
}

void log_inet_info(void)
{
    struct inet_t* ifnet;
    struct pair_t* pos;

    int i = 0;

    log_info( "external name:%s\n", g_external_name);
    log_info( "internal name:%s\n", g_internal_name);

    for(;i < g_inet_num; i++)
    {
        ifnet = &g_inet_array[i];
        log_info("nic num:%d\n", i);
        log_info("name:%s\n",ifnet->name);
        log_info("flag:%d\n", ifnet->flag);
        list_for_each_entry(pos, &(ifnet->pair.list), list)
        {
            log_info("key:%s, value=%s\n",pos->key, pos->value);
        }
    }
  
    return ;     

}
