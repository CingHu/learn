#include "common.h"
#include "logger.h"
#include "interface.h"
#include "utils.h"

extern int  g_inet_num;
extern struct inet_t* g_inet_array;
extern char   g_external_name[MAC_ADDR_LEN];
extern char   g_internal_name[MAC_ADDR_LEN];

char uxdigits[] = "0123456789ABCDEF";
char lxdigits[] = "0123456789abcdef";

int g_dev_counter = 0;

void _get_file_path_name(const char *name, char* path_name)
{
    strcat(path_name, INET_PATH);
    strcat(path_name, name);
    return;
}

void _get_line_key_value(char *buf, char* key, char* value)
{
    int pos = 0;
    int len = 0;

    len = strlen(buf);
    pos  = stringfind(buf, "=");

    memcpy(key, buf, pos);
    key[pos] = '\0';

    memcpy(value, &buf[pos+1], (len-pos));
   
    log_info("key:%s\n",key); 
    log_info("value:%s\n",value); 
    
    return ;
}

bool _push_param(struct inet_t* inet, int flag)
{

    if(!get_nic_name())
        return  false;

    strcpy(inet->name,g_external_name);
    inet->flag = flag;

    return true;
}

bool _is_valid_file(const char* name, int* flag)
{

    //find master file
    if(strstr(name,MASTER_SUFFIX) != 0)
    {
         log_info("master:%s\n", name);                        
         *flag = MASTER_FLAG;
    }
    //find slavor file
    else if (strstr(name,SLAVOR_SUFFIX) != 0)
    {
         log_info("slavor:%s\n", name);                        
         *flag = SLAVOR_FLAG;
    }
    else
    {
        log_error("inet config file name is error, name:%s\n", name); 
        return false;
    }

    return true;
}

int parase_file(const char *name, struct inet_t* inet)
{
    FILE *fp;
    char buf[BUF_LEN] = {0};  
    char key[KEY_LEN] = {0};
    char value[VANLUE_LEN] = {0};
    char path_name[DEVICE_NAME_LEN]={0};
    char ch;
    int  flag = -1;

    if(NULL == inet)
        return RT_ERROR;

    log_info("parase file name:%s\n", name);

    _get_file_path_name(name, path_name); 
 
    if(!_is_valid_file(name, &flag))
    {
        log_error("file is invalid\n");
        return RT_ERROR;
    }
    
    fp = fopen(path_name, "r"); 
    if(NULL == fp)
        return RT_ERROR;

    ch = fgetc(fp);
    if(EOF == ch)
    {
        log_error("the content of file is NULL\n");
        fclose(fp);  
        return RT_SUCCESS;
    }
    else
    {   
       fseek( fp , 0 , SEEK_SET);
    }

    if( !_push_param(inet, flag))
     {
        fclose(fp);  
        return RT_ERROR;
     }
       
      
    while(!feof(fp))  
    {  
     
        /*如果没有下面这个判断，那么程序会多读一行，错误！诡异的feof! */ 
        if(NULL == fgets(buf, sizeof(buf), fp))  
        {  
            continue;  
        }  
  
        /* 
        下面语句的作用是过滤掉空行,当然，如果你不想滤掉空行，那也不是去掉下面这个部分那么简单 
        设文本文件的3行为： 
        如果仅仅把下面这部分去掉，那么最后的空行也不会显示，因为上面的if中有continue 
        */  
        if(0 == strcmp(buf, "\n"))  
        {  
            continue;  
        }  
  
        /* 
        设文本文件有3行，记为 
        1行 a 
        2行 b 
        3行 c 
        那么读取第1、2行的时候，字符串带了换行符，读取第三行的时候，没有换行符，所以要分别进行处理 
        */  
        int len = strlen(buf);  
        if('\n' == buf[len - 1])  
        {  
            buf[len - 1] = '\0'; // 去掉'\n'字符  
            len--;  
        }  
     
        _get_line_key_value(buf, key, value);
    
        save_pair(inet, key, value);
    }  
  
    fclose(fp);  
  
    g_inet_num++;

    return RT_SUCCESS;
}


int parase_dir_file(void)
{
     DIR         *dp;
     struct dirent   *dirp;

     if((dp=opendir(INET_PATH))== NULL)
     {
         log_error("can't open dir %s",INET_PATH);
         return RT_ERROR;
     }
   
     if(RT_SUCCESS != alloc_mem())
     {
         log_error("allocate mem failed\n");
         goto end;
     }

     while((dirp=readdir(dp))!=NULL)
     {
         //find inet config file
         if(strstr(dirp->d_name,NET_SUFFIX)==0)
             continue;

         if(g_inet_num >= INET_NUM) 
         {
             log_error("num of ineterface > %s\n", INET_NUM);
             goto end;
         }

         if(RT_SUCCESS != parase_file(dirp->d_name, &g_inet_array[g_inet_num]))
         {
             log_error("parase file failed,name:%s\n", dirp->d_name);
             goto end;
         }
     }

end:
   closedir(dp);
   return RT_SUCCESS; 
}



