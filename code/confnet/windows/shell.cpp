#include "StdAfx.h"
#include "shell.h"
#include "manager.h"
#include "iostream"

using namespace std;


extern struct ip_info_t* g_inet_array;
extern int    g_file_num;
//shell 配置device的ip
int ShellConfIPAddr(char* AdapterName, char* IPAddress, char* Netmask, char* Gateway)
{
	char cmd[256];
	sprintf(cmd, "%s name=\"%s\" source=static addr=%s mask=%s gateway=%s gwmetric=2", "netsh interface ip set address",AdapterName,IPAddress, Netmask, Gateway);
	WinShell(cmd);
#ifdef DEBUG_F
	cout<<cmd<<endl;
#endif    
	return WIN_SUCCESS;

}

//shell 添加ip
int ShellAddIPAddr(char* AdapterName, char* IPAddress, char* Netmask, char* Gateway)
{
	char cmd[256];
	sprintf(cmd, "%s name=\"%s\" addr=%s mask=%s gateway=%s gwmetric=2", "netsh interface ip add address",AdapterName,IPAddress, Netmask, Gateway);
	WinShell(cmd);
#ifdef DEBUG_F
	cout<<cmd<<endl;
#endif
    return WIN_SUCCESS;

}


//shell 删除ip
int ShellDelIPAddr(char* AdapterName, char* IPAddress)
{
	char cmd[256];
	sprintf(cmd, "%s name=\"%s\" addr=%s", "netsh interface ip delete address",AdapterName,IPAddress);
	log_info("del ip address:%s", cmd);
	WinShell(cmd);
#ifdef DEBUG_F
	cout<<cmd<<endl;
#endif
    return WIN_SUCCESS;
}

//shell 添加dns
int ShellAddDns(char* AdapterName, char* DNS)
{
	char cmd[256];
	sprintf(cmd, "%s name=\"%s\" addr=%s", "netsh interface ip add dns",AdapterName,DNS);
	log_info("add dns address:%s", cmd);
	WinShell(cmd);
#ifdef DEBUG_F
	cout<<cmd<<endl;
#endif

    return WIN_SUCCESS;
}

//shell删除dns
int ShellDelDNS(char* AdapterName, char* DNS)
{
	char cmd[256];
	sprintf(cmd, "%s name=\"%s\" addr=%s", "netsh interface ip delete dns",AdapterName,DNS);
	log_info("del dns address:%s", cmd);
	WinShell(cmd);
#ifdef DEBUG_F
	cout<<cmd<<endl;
#endif

    return WIN_SUCCESS;
}

int ShellDelDNSAll(char* AdapterName)
{
	char cmd[256];
	sprintf(cmd, "%s name=\"%s\" ", "netsh interface ip delete dns all",AdapterName);
	log_info("del all dns address:%s", cmd);
	WinShell(cmd);
#ifdef DEBUG_F
	cout<<cmd<<endl;
#endif
    return WIN_SUCCESS;
}


//shell 配置默认路由
int ShellAddDefaultGW(char* AdapterName,char* Gateway)
{
	char cmd[256];
	sprintf(cmd, "%s name=\"%s\" gateway=%s gwmetric=2", "netsh interface ip add address",AdapterName,Gateway);
	WinShell(cmd);
#ifdef DEBUG_F
	cout<<cmd<<endl;
#endif    
	return WIN_SUCCESS;

}

//shell 配置默认路由
int ShellDelInvalidGW(char* AdapterName)
{
	char cmd[256];
	sprintf(cmd, "%s name=\"%s\" gateway=%s gwmetric=2", "netsh interface ip delete address",AdapterName,INVALID_GATEWAY);
	WinShell(cmd);
#ifdef DEBUG_F
	cout<<cmd<<endl;
#endif    
	return WIN_SUCCESS;

}

void config_dns(char *name, struct ip_info_t* pt_ip, short *add_ip)
{
	int i = 0;
	char dns1[MAC_ADDR_LEN] = {0};
	char dns2[MAC_ADDR_LEN] = {0};

  	ShellDelDNSAll(name);

	for(i= 0 ; i < IP_NUMBER;i++)
	{
		if(add_ip[i] != 0 && strlen(pt_ip[i].ip) != 0)
		{
#ifdef DEBUG_F
			cout<<"config dns1: "<<pt_ip[i].dns1<<endl;;
			cout<<"config dns2: "<<pt_ip[i].dns2<<endl;;
#endif
			 if(strlen(pt_ip[i].dns1) != 0 )
			 {
			    strcpy(dns1, pt_ip[i].dns1);
			 }

			 if(strlen(pt_ip[i].dns2) != 0 )
			 {
			    strcpy(dns2, pt_ip[i].dns2);
			 }

		}
	}
	if(strlen(dns1) == 0)
		strcpy(dns1, DEFAULT_DNS1);

	if(strlen(dns2) == 0)
		strcpy(dns2, DEFAULT_DNS2);

    ShellAddDns(name,dns1);
    ShellAddDns(name,dns2);

}

int get_device_info(char *name, char ip[][IP_ADDR_LEN])
{
	int rt = 0;
	int index = 0;
	char mac[MAC_ADDR_LEN] = {0};


	rt = GetExternalDeviceMac(mac);
	if(WIN_SUCCESS != rt)
	{
	    log_error("get exernal  mac failed");
		return WIN_ERROR;	
	}

    rt = GetDeviceCHName(mac, name);
	if(WIN_SUCCESS != rt)
	{
	    log_error("get device chname fail, mac:%s", mac);
		return WIN_ERROR;
	
	}

    index = GetDeviceIndex(mac);
    if( 0 == index)
	{
	    log_error("get device index fail, mac:%s", mac);
		return WIN_ERROR;
	}

	rt = GetDeviceIPAddress(index, ip);
	if(WIN_SUCCESS != rt)
	{
	    log_error("get device ip arrary fail, index:%d", index);
		return WIN_ERROR;
	
	}

	return WIN_SUCCESS;
}

#if 1

bool del_all_ip(char *name, char ip[][IP_ADDR_LEN])
{
	int i = 0;

    log_info("file num:%d", g_file_num);

#ifdef DEBUG_F
	cout<<"del all ip,file num:"<<g_file_num<<endl;
#endif


	if( g_file_num == 0)
	{
	    log_info("it can not find any valid file, del all ip");		
	}
	else
		return false;

	/*for windows, device must be have a ip address*/
	ShellAddIPAddr(name, INVALID_IP, INVALID_NETMASK, INVALID_GATEWAY);


	for(i; i < IP_NUMBER; i++)
	{
		if(strlen(ip[i]) != 0)
		{
#ifdef DEBUG_F
		   cout<<"del ip: "<<ip[i]<<endl;
#endif
		   log_info("del ip :%s", ip[i]);
           ShellDelIPAddr(name, ip[i]);
		}
	}

	return true;
}

#endif

int config_interface()
{
	int i = 0, j = 0;
	char name[DEVICE_NAME_LEN]={0};
	char ip[IP_NUMBER][IP_ADDR_LEN]={0};
	char exist_ip[IP_NUMBER][IP_ADDR_LEN]={0};
	short add_ip[IP_NUMBER]={0};
	char del_ip[IP_NUMBER]={0};
	int flag = 0;
	int exist_ip_num = 0;
	char gateway[IP_ADDR_LEN]={0};

	struct ip_info_t* pt_ip = g_inet_array;


	memset(add_ip, 1, sizeof(char)*IP_NUMBER);
	memset(del_ip, 1, sizeof(char)*IP_NUMBER);

    if(WIN_SUCCESS != get_device_info(name, ip))
	{
	    log_error("get device info failed");
		return WIN_ERROR;
	}

	if(del_all_ip(name, ip))
	{
	    return WIN_SUCCESS;
	}


	for(i; i < IP_NUMBER; i++)
	{
	    for(j=0; j < IP_NUMBER; j++)
		{
		    if(strcmp(pt_ip[i].ip, ip[j]) == 0 &&
				strlen(pt_ip[i].ip)!=0)
			{
			   exist_ip_num++;
			   strcpy(exist_ip[i], ip[j]);
			   log_info("exist ip:%s", exist_ip[i]);
			}
		}
	}

	for(i=0; i < IP_NUMBER; i++)
	{
		for(j = 0; j < IP_NUMBER; j++)
		{
		    if(strcmp(pt_ip[i].ip, exist_ip[j]) == 0 &&
				strlen(pt_ip[i].ip) != 0)
			{
			   add_ip[i] = 0;
			   log_info("not add ip:%s", exist_ip[j]);
			}
		}
	}
	for(i=0; i < IP_NUMBER; i++)
	{
		for(j = 0; j < IP_NUMBER; j++)
		{
			if(strcmp(ip[i], exist_ip[j]) == 0)
			{
				del_ip[i] = 0;
			}
		}
	}

#ifdef DEBUG_F
	cout<<"exist ip num: "<<exist_ip_num<<endl;
#endif
    config_dns(name, pt_ip, add_ip);

	for(i= 0 ; i < IP_NUMBER;i++)
	{
		if(add_ip[i] != 0 && strlen(pt_ip[i].ip) != 0)
		{
#ifdef DEBUG_F
			cout<<"add_ip: "<<pt_ip[i].ip<<endl;;
#endif
		    ShellAddIPAddr(name, pt_ip[i].ip, pt_ip[i].netmask,pt_ip[i].gateway);			
			strcpy(gateway, pt_ip[i].gateway);
		}
	}

	for(i=0; i < IP_NUMBER; i++)
	{
		if(del_ip[i] != 0)
		{
#ifdef DEBUG_F
		   cout<<"del ip: "<<ip[i]<<endl;
#endif
		   log_info("del ip :%s", ip[i]);
           ShellDelIPAddr(name, ip[i]);
		}
	}

	if(strlen(gateway) != 0)
	{
		ShellDelInvalidGW(name);
	    ShellAddDefaultGW(name, gateway);
	}




    return WIN_SUCCESS;
}




