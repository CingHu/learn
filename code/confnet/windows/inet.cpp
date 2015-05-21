#include "StdAfx.h"

struct ip_info_t* g_inet_array;
char   g_external_name[MAC_ADDR_LEN];
int    g_file_num = 0;

char uxdigits[] = "0123456789ABCDEF";
char lxdigits[] = "0123456789abcdef";

int g_dev_counter = 0;

void _get_file_path_name(const char *name, char* path_name)
{
    strcat(path_name, INET_PATH);
    strcat(path_name, name);
    return;
}

void _get_value(char *key, char *input_value, struct ip_info_t *p_ip_info)
{
	if(stringfind(KEY_IP, key) != -1)
	{
	    strcpy(p_ip_info->ip, input_value);
	}
	else if(stringfind(KEY_NETMASK, key) != -1)
	{
	    strcpy(p_ip_info->netmask, input_value);
	}
	else if(stringfind(KEY_GATEWAY, key) != -1)
	{
	    strcpy(p_ip_info->gateway, input_value);
	}
	else if(stringfind(KEY_DNS1, key) != -1)
	{
	    strcpy(p_ip_info->dns1, input_value);
	}
	else if(stringfind(KEY_DNS2, key) != -1)
	{
	    strcpy(p_ip_info->dns2, input_value);
	}
	else if(stringfind(KEY_DNS, key) != -1)
	{
	    strcpy(p_ip_info->dns1, input_value);
	}
	else
	{
	    log_error("key is error, %s\n", key);
	}


    return;
}

void _get_line_key_value(char *buf, struct ip_info_t *p_ip_info)
{
    int pos = 0;
    int len = 0;

	char key[128] = {0};
    char value[IP_ADDR_LEN]  = {0};

    len = strlen(buf);
    pos  = stringfind(buf, "=");

    memcpy(key, buf, pos);
    key[pos] = '\0';

    memcpy(value, &buf[pos+1], (len-pos));
   
    log_info("key:%s\n",key); 
    log_info("value:%s\n",value); 

	_get_value(key, value, p_ip_info);
    
    return ;
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

int parase_file(const char *name ,struct ip_info_t *p_ip_info)
{
    FILE *fp;
    char buf[BUF_LEN] = {0};  
    char key[KEY_LEN] = {0};
    char value[VANLUE_LEN] = {0};
    char path_name[DEVICE_NAME_LEN]={0};
    char ch;
    int  flag = -1;

    log_info("parase file name:%s\n", name);

    _get_file_path_name(name, path_name); 
 
    if(!_is_valid_file(name, &flag))
    {
        log_error("file is invalid\n");
        return WIN_ERROR;
    }
    
	p_ip_info->flag = flag;

    fp = fopen(path_name, "r"); 
    if(NULL == fp)
        return WIN_ERROR;

    ch = fgetc(fp);
    if(EOF == ch)
    {
        log_error("the content of file is NULL\n");
        fclose(fp);  
        return WIN_SUCCESS;
    }
    else
    {   
       fseek( fp , 0 , SEEK_SET);
    }
       
      
    while(!feof(fp))  
    {  
     
        if(NULL == fgets(buf, sizeof(buf), fp))  
        {  
            continue;  
        }  
   
        if(0 == strcmp(buf, "\n"))  
        {  
            continue;  
        }  
  

        int len = strlen(buf);  
        if('\n' == buf[len - 1])  
        {  
            buf[len - 1] = '\0';   
            len--;  
        }  
     
        _get_line_key_value(buf, p_ip_info);
    
        
    }  

    fclose(fp);  

    g_file_num++;

    return WIN_SUCCESS;
}


int parase_dir_file(void)
{
     WIN32_FIND_DATA find_file;
	 HANDLE hfind;
     char pattern[MAX_PATH];
	 int i = 0;

	 struct ip_info_t* p_ip_info;


	p_ip_info = (struct ip_info_t*)malloc(sizeof(struct ip_info_t)*IP_NUMBER);
	if(NULL == p_ip_info)
	{
	    log_error("allocate mem failed");
		return WIN_ERROR;
	}

	memset(p_ip_info, 0, sizeof(struct ip_info_t) * IP_NUMBER);

	 g_inet_array = p_ip_info;

	 strcpy(pattern, INET_PATH);
	 strcat(pattern,"\\*.*");

	 hfind = FindFirstFile(pattern, &find_file);

	 if(hfind == INVALID_HANDLE_VALUE)
	 {
	     return WIN_SUCCESS;
	 }
	 else
	 {
	      do
		  {
			  if(i >= IP_NUMBER)
			  {
			      log_error("ip num exceed %d\n", IP_NUMBER);
				  return WIN_ERROR;
			  }
	           //find inet config file
              if(strstr(find_file.cFileName,NET_SUFFIX)==0)
                  continue;

			  if(WIN_SUCCESS != parase_file(find_file.cFileName, &p_ip_info[i]))
			  {
			       log_error("parase file failed,name:%s\n", find_file.cFileName);
				   goto end;
			  }

              i++;
		  }while(FindNextFile(hfind, &find_file)!=0);
	 }

 

end:
   FindClose(hfind);
   return WIN_SUCCESS; 
}



