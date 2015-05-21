#include "win_common.h"
#include "basefunc.h"
#include "logger.h"
#include "iostream.h"

struct ip_info_t* g_inet_arrary;

int    g_inet_num = 0;
int    g_inet_max = INET_NUM;

extern char   g_external_name[MAC_ADDR_LEN];



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


char * left(char *dst,char *src, int n)
{
    char *p = src;
    char *q = dst;
    int len = strlen(src);
    if(n>len) n = len;
    while(n--) *(q++) = *(p++);
    *(q++)='\0'; 
    return dst;
}


char* str_lower(const char *str)
{
    char *pnew, *p;
    pnew = strdup(str);
    for (p = pnew; *p; p++)
        *p = tolower(*p);
    return pnew;
}


void log_in_info()
{
    int i = 0;
	
	for(i;i < IP_NUMBER; i++)
	{
		cout<<"ip info:"<<i<<endl;
	    cout<<g_inet_arrary[i].name<<endl;
	    cout<<g_inet_arrary[i].flag<<endl;
	    cout<<g_inet_arrary[i].ip<<endl;
	    cout<<g_inet_arrary[i].netmask<<endl;
	    cout<<g_inet_arrary[i].gateway<<endl;
	    cout<<g_inet_arrary[i].dns1<<endl;
	    cout<<g_inet_arrary[i].dns2<<endl;
	}
}
