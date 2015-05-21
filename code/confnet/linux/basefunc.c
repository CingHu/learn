#include "common.h"

#define REDHAT_LEN   7
#define SUSE_LEN     3
#define DEBAIN_LEN   6


#define RED_HAD_CENTOS_FLAG "Red Hat Centos centos CENTOS RedHat"
#define DEBAIN_UBUNTU_FLAG  "DEBAIN debain ubuntu Ubuntu UBUNTU"

const char* redhat_str[REDHAT_LEN] = {
                         "Red Hat",
                         "redhat",
                         "RedHat",
                         "REDHAT",
                         "Centos",
                         "centos",
                         "CENTOS"
                         };

const char* debain_str[DEBAIN_LEN] = {
                          "DEBAIN",
                          "debain",
                          "Debain",
                          "ubuntu",
                          "Ubuntu",
                          "UBUNTU"
                          };


const char* suse_str[SUSE_LEN] = {
                          "SUSE",
                          "suse",
                          "Suse"
                          };


int  get_version(int *version)
{
   FILE *fp;
   int i = 0;
   int file_size;
   char *buf;
    
   system("cp /proc/version /tmp/version");
    
   fp = fopen("/tmp/version","r");
   if(NULL == fp)
   {
       return 0;
   }

   fseek( fp , 0 , SEEK_END);
   file_size = ftell(fp);  
   fseek( fp , 0 , SEEK_SET);
   buf =  (char *)malloc( (file_size+1) * sizeof( char ) );
   fread( buf , sizeof(char),file_size, fp);
   buf[file_size] = '\0';
   fclose(fp);

   for(i = 0; i < REDHAT_LEN;i++)
   {
       if(strstr(buf,redhat_str[i]) != 0)
       {
          *version = REDHAT;
          free(buf);
          return 0;
       }
   }
   for(i = 0; i < DEBAIN_LEN;i++)
   {
       if(strstr(buf,debain_str[i]) != 0)
       {
          *version = DEBAIN;
          free(buf);
          return 0;
       }
   }
   for(i = 0; i < SUSE_LEN;i++)
   {
       if(strstr(buf,suse_str[i]) != 0)
       {
          *version = SUSE;
          free(buf);
          return 0;
       }
   }
 
   free(buf);
   return 1;
}


int stringfind(const char *pSrc, const char *pDst)  
{  
    int i, j;  
    for (i=0; pSrc[i]!='\0'; i++)  
    {  
        if(pSrc[i]!=pDst[0])  
            continue;         
        j = 0;  
        while(pDst[j]!='\0' && pSrc[i+j]!='\0')  
        {  
            j++;  
            if(pDst[j]!=pSrc[i+j])  
            break;  
        }  
        if(pDst[j]=='\0')  
            return i;  
    }  
    return -1;  
}


/*从字符串的左边截取n个字符*/
char * left(char *dst,char *src, int n)
{
    char *p = src;
    char *q = dst;
    int len = strlen(src);
    if(n>len) n = len;
    /*p += (len-n);*/   /*从右边第n个字符开始*/
    while(n--) *(q++) = *(p++);
    *(q++)='\0'; /*有必要吗？很有必要*/
    return dst;
}


char* str_lower(const char *str)
{
    char *new, *p;
    new = strdup(str);
    for (p = new; *p; p++)
        *p = tolower(*p);
    return new;
}

