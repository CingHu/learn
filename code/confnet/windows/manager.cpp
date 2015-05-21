#include "StdAfx.h"
#include "manager.h"

using namespace std;

#pragma comment(lib,"ws2_32.lib") 
#pragma comment(lib,"setupapi.lib") 
#pragma comment(lib, "iphlpapi.lib")


#define MALLOC(x) HeapAlloc(GetProcessHeap(), 0, (x))
#define FREE(x) HeapFree(GetProcessHeap(), 0, (x))

typedef int (CALLBACK* DHCPNOTIFYPROC)(LPWSTR, LPWSTR, BOOL, DWORD, DWORD, DWORD, int); 


INFO_ADAPTER AdapterList[NIC_NUMBER];

void FormatMACToStr(LPSTR lpHWAddrStr,const unsigned char *HWAddr)
{
    int i;
    short temp;
    char szStr[3];
    strcpy(lpHWAddrStr, "");
	for (i=0; i<6; ++i)
	{
	    temp = (short)(*(HWAddr + i));
		_itoa(temp, szStr, 16);
       if(strlen(szStr) == 1)
            strcat(lpHWAddrStr, "0");

		strcat(lpHWAddrStr, szStr);   

		if ( i < 5 ) 
			strcat(lpHWAddrStr, ":");
	}
}


//获取所有设备的hw信息
void GetAdapterInfo()
{
    char tempChar;
    ULONG uListSize = 1;
	PIP_ADAPTER_INFO pIpAdapterInfo;   // 定义PIP_ADAPTER_INFO结构存储网卡信息
	int nAdapterIndex = 0;
	int nIpNum = 0;

    DWORD dwRet = GetAdaptersInfo((PIP_ADAPTER_INFO)&tempChar, &uListSize); // 关键函数
	if (dwRet == ERROR_BUFFER_OVERFLOW)
	{
	    PIP_ADAPTER_INFO pAdapterListBuffer = (PIP_ADAPTER_INFO)new(char[uListSize]);
		dwRet = GetAdaptersInfo(pAdapterListBuffer, &uListSize);
        if (dwRet == ERROR_SUCCESS)
		{
		    pIpAdapterInfo = pAdapterListBuffer;
			while(pIpAdapterInfo)
			{
				//cout<<"网卡名称："<<pIpAdapterInfo->AdapterName<<endl;
				//cout<<"网卡描述："<<pIpAdapterInfo->Description<<endl;
				//cout<<"网卡类型："<<pIpAdapterInfo->Type<<endl;
				//cout<<"网卡编号："<<pIpAdapterInfo->Index<<endl;
				//cout<<"网卡MAC地址：";

				strcpy(AdapterList[nAdapterIndex].szDeviceName,pIpAdapterInfo->AdapterName);
				AdapterList[nAdapterIndex].dwIndex = pIpAdapterInfo->Index;
				AdapterList[nAdapterIndex].nType = pIpAdapterInfo->Type;
				AdapterList[nAdapterIndex].filled = true;

				FormatMACToStr(AdapterList[nAdapterIndex].szHWAddrStr,pIpAdapterInfo->Address ); // MAC

		        //cout<<"网卡IP地址如下："<<endl;
				IP_ADDR_STRING *pIpAddrString =&(pIpAdapterInfo->IpAddressList);
				do
				{
                   if( nIpNum >= IP_NUMBER)
				   {
				   		cout<<"ip address num > 10,break"<<endl;
					    break;

				   }

					//cout<<"IP 地址："<<pIpAddrString->IpAddress.String<<endl;
					//cout<<"子网地址："<<pIpAddrString->IpMask.String<<endl;
					//cout<<"网关地址："<<pIpAdapterInfo->GatewayList.IpAddress.String<<endl;
 
                  
				    strcpy(AdapterList[nAdapterIndex].IPInfo[nIpNum].szIPAddrStr, pIpAddrString->IpAddress.String);
					strcpy(AdapterList[nAdapterIndex].IPInfo[nIpNum].szNetmaskStr, pIpAddrString->IpMask.String);
					strcpy(AdapterList[nAdapterIndex].IPInfo[nIpNum].szGatewagStr, pIpAdapterInfo->GatewayList.IpAddress.String);
                    AdapterList[nAdapterIndex].IPInfo[nIpNum].filled = true;
					nIpNum++;

					pIpAddrString=pIpAddrString->Next;
				}while (pIpAddrString);

                nAdapterIndex++;

				pIpAdapterInfo = pIpAdapterInfo->Next;
			}
		}
	}   
  
}


/*根据MAC获取index*/
DWORD  GetDeviceIndex(char* szDeviceMac)
{
	char mac[MAC_ADDR_LEN];

	strcpy(mac,str_lower(szDeviceMac));

    GetAdapterInfo();
	for(int i = 0; i < NIC_NUMBER; i++)
	{	

		if(AdapterList[i].filled && strcmp(mac,AdapterList[i].szHWAddrStr) == 0)
		{   
		    return AdapterList[i].dwIndex;
		}
	}

	return 0;
	
}

/*根据index获取adapter name*/
DWORD  GetDeviceNameByIndex(DWORD ifIndex, char* DeviceName)
{
    GetAdapterInfo();
	for(int i = 0; i < NIC_NUMBER; i++)
	{	

		if(AdapterList[i].dwIndex  == ifIndex)
		{   
		    strcpy(DeviceName,AdapterList[i].szDeviceName);
			return WIN_SUCCESS;
		}
	}

	return WIN_ERROR;
	
}

/*获取device name 根据mac*/
DWORD  GetDeviceNameByMac(char* szDeviceMac, char* DeviceName)
{
	char mac[MAC_ADDR_LEN];
	strcpy(mac,str_lower(szDeviceMac));

    GetAdapterInfo();
	for(int i = 0; i < NIC_NUMBER; i++)
	{	

		if(AdapterList[i].filled && strcmp(mac,AdapterList[i].szHWAddrStr) == 0)
		{   
			#ifdef DEBUG_F
			cout<<"MAC："<<AdapterList[i].szHWAddrStr<<endl;
            #endif
		    strcpy(DeviceName,AdapterList[i].szDeviceName);
			return WIN_SUCCESS;
		}
	}

    return WIN_ERROR;
}

/*获取device name 根据mac*/
DWORD  GetExternalDeviceMac(char *mac)
{
    GetAdapterInfo();
	for(int i = 0; i < NIC_NUMBER; i++)
	{	
	    log_info("MAC：%s",AdapterList[i].szHWAddrStr);
		log_info("%s",EXTERNAL_MAC_PREFIX);

		if(stringfind(AdapterList[i].szHWAddrStr, EXTERNAL_MAC_PREFIX) != -1 ||
		stringfind(AdapterList[i].szHWAddrStr, EXTERNAL_MAC_PREFIX_B) != -1 )
		{
		    strcpy(mac, AdapterList[i].szHWAddrStr);
			log_info("exernal mac:%s", mac);
			return WIN_SUCCESS;

		}

	}

    return WIN_ERROR;
}

//获取device的ip地址数目
int GetDeviceIPNum(DWORD Index)
{
	int num = 0;

    GetAdapterInfo();
	for(int i = 0; i < NIC_NUMBER; i++)
	{	

		if(AdapterList[i].filled && AdapterList[i].dwIndex == Index)
		{   
			for(int j = 0; j < IP_NUMBER; j++)
			{
				//cout<<AdapterList[i].IPInfo[j].szIPAddrStr[0]<<endl;
				num++;
			}
		}
	} 

	return num;
}

//获取device的ip地址
int GetDeviceIPAddress(DWORD Index, char IPAddrArr[][IP_ADDR_LEN])
{
    if(NULL == IPAddrArr)
	{
		cout<<"ERROR:input param IP Addr array is NULL"<<endl;
		return WIN_ERROR;
	}

    GetAdapterInfo();
	for(int i = 0; i < NIC_NUMBER; i++)
	{	
		if(AdapterList[i].filled && AdapterList[i].dwIndex == Index)
		{   
			for(int j = 0; j < IP_NUMBER; j++)
			{
				strcpy(IPAddrArr[j], AdapterList[i].IPInfo[j].szIPAddrStr);
				log_info("ip :%s",IPAddrArr[j]);
				#ifdef DEBUG_F
				cout<<IPAddrArr[j]<<endl;
                #endif
			}
			break;
		}
	} 


	return WIN_SUCCESS;
}

//配置路由
static DWORD SetDeviceRoute(const DWORD& dwDestAddr, const DWORD& dwMask, const DWORD& dwNextHop, const DWORD& dwInterfaceIndex)
{
    MIB_IPFORWARDROW row;
	OSVERSIONINFO ver;

	//兼容WIN7，VISTA
	ver.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);

	if(0 == ::GetVersionEx(&ver))
	{
	    return WIN_ERROR;
	}
#if 0
	if(ver.dwMajorVersion > 5)
	{
//typedef DWORD(__stdcall *IPINTENTRY)(PMIB_IPINTERFACE_ROW);

        MIB_IPINTERFACE_ROW info;

        info.InterfaceIndex = dwInterfaceIndex;
        memset(&(info.InterfaceLuid),0,sizeof(info.InterfaceLuid));
		info.Family = AF_INET;

		HINSTANCE hInst = LoadLibrary(TEXT("Iphlpapi.dll"));

		if(NULL == hInst)
			return WIN_ERROR;

     	IPINTENTRY pFunGetInfEntry = (IPINTENTRY)GetProcAddress(hInst,"GetIpInterfaceEntry");

		DWORD dwRet = pFunGetInfEntry(&info);
		FreeLibrary(hInst);

		if(NO_ERROR != dwRet)
			return dwRet;

		row.dwForwardMetric1 = info.Metric;
	}
#endif
	
	row.dwForwardDest      = dwDestAddr;
    row.dwForwardMask      = dwMask;
	row.dwForwardNextHop   = dwNextHop;

    row.dwForwardIfIndex = dwInterfaceIndex;

	row.dwForwardNextHopAS = 0;
	row.dwForwardAge       = 0;
	

    //row.dwForwardMetric1   = 21;
    row.dwForwardMetric2   = -1;
	row.dwForwardMetric3   = -1;
	row.dwForwardMetric4   = -1;
	row.dwForwardMetric5   = -1;

	row.dwForwardPolicy    = 0;
	row.dwForwardProto     = MIB_IPPROTO_NETMGMT;
	row.dwForwardType      = MIB_IPROUTE_TYPE_INDIRECT;
	//row.dwForwardType      = 3;

	return CreateIpForwardEntry(&row);

}

//获取默认路由
DWORD GetDefaultRoute(IP_FORWARD_ROUTE *ptForwardRoute)
{
	/* variables used for GetIfForwardTable */
    PMIB_IPFORWARDTABLE pIpForwardTable;
    DWORD dwSize = 0;
    DWORD dwRetVal = 0;

	struct in_addr IpAddr;

 
    int i;

	if (NULL == ptForwardRoute)
	{
	    printf("ptForwardRoute is NULL");
		return WIN_ERROR;
	}

    pIpForwardTable = (MIB_IPFORWARDTABLE *) MALLOC(sizeof (MIB_IPFORWARDTABLE));
    if (pIpForwardTable == NULL) 
	{
        printf("Error allocating memory\n");
        return WIN_ERROR;
    }

    if (GetIpForwardTable(pIpForwardTable, &dwSize, 0) ==
        ERROR_INSUFFICIENT_BUFFER) {
        FREE(pIpForwardTable);
        pIpForwardTable = (MIB_IPFORWARDTABLE *) MALLOC(dwSize);
        if (pIpForwardTable == NULL) {
            printf("Error allocating memory\n");
            return WIN_ERROR;
        }
    }

	if ((dwRetVal = GetIpForwardTable(pIpForwardTable, &dwSize, 0)) == NO_ERROR) 
	{
        for (i = 0; i < (int) pIpForwardTable->dwNumEntries; i++)
		{
		    IpAddr.S_un.S_addr = (long) pIpForwardTable->table[i].dwForwardDest;
			strcpy(ptForwardRoute->szDestIp, inet_ntoa(IpAddr));
            
			/*get default router*/
			/*
			if(strcmp(ptForwardRoute->szDestIp,DEFALT_ROUTE_DEST) != 0)
			{
			     continue;
			}*/


			IpAddr.S_un.S_addr = (u_long) pIpForwardTable->table[i].dwForwardMask;
			strcpy(ptForwardRoute->szMaskIp, inet_ntoa(IpAddr));
			IpAddr.S_un.S_addr = (u_long) pIpForwardTable->table[i].dwForwardNextHop;
			strcpy(ptForwardRoute->szGatewayIp, inet_ntoa(IpAddr));

			ptForwardRoute->dwForwardType    = pIpForwardTable->table[i].dwForwardType;
			ptForwardRoute->dwForwardProto   = pIpForwardTable->table[i].dwForwardProto;
            ptForwardRoute->dwForwardMetric1 = pIpForwardTable->table[i].dwForwardMetric1;
			ptForwardRoute->dwForwardAge     = pIpForwardTable->table[i].dwForwardAge; 

            /*
			cout<<"pIpForwardTable->table[i].dwForwardDest："<<pIpForwardTable->table[i].dwForwardDest<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardMask："<<pIpForwardTable->table[i].dwForwardMask<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardPolicy："<<pIpForwardTable->table[i].dwForwardPolicy<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardNextHop："<<pIpForwardTable->table[i].dwForwardNextHop<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardIfIndex："<<pIpForwardTable->table[i].dwForwardIfIndex<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardType："<<pIpForwardTable->table[i].dwForwardType<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardProto："<<pIpForwardTable->table[i].dwForwardProto<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardAge："<<pIpForwardTable->table[i].dwForwardAge<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardNextHopAS："<<pIpForwardTable->table[i].dwForwardNextHopAS<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardMetric1："<<pIpForwardTable->table[i].dwForwardMetric1<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardMetric2："<<pIpForwardTable->table[i].dwForwardMetric2<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardMetric3："<<pIpForwardTable->table[i].dwForwardMetric3<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardMetric4："<<pIpForwardTable->table[i].dwForwardMetric4<<endl;
			cout<<"pIpForwardTable->table[i].dwForwardMetric5："<<pIpForwardTable->table[i].dwForwardMetric5<<endl;
            */

		}

	}

	FREE(pIpForwardTable);
	return WIN_SUCCESS;
}

//添加ip地址
int AddIPAddr(DWORD ifIndex, char* IPAddress, char* Netmask)
{
    DWORD dwRetVal = 0;

	UINT iaIPAddress;
    UINT iaIPMask;

	ULONG NTEContext = 0;
    ULONG NTEInstance = 0;

	iaIPAddress = inet_addr(IPAddress);
    if (iaIPAddress == INADDR_NONE) {
		cout<<"usage:IPAddress SubnetMask:"<<endl;
        return 0;
    }

    iaIPMask = inet_addr(Netmask);
    if (iaIPMask == INADDR_NONE) {
		cout<<"usage:IPAddress SubnetMask:"<<endl;
        return 0;
     }

    if ((dwRetVal = AddIPAddress(iaIPAddress,
                                 iaIPMask,
                                 ifIndex,
                                 &NTEContext, &NTEInstance)) == NO_ERROR) 
	{
	    cout<<"IPv4 address was successfully added："<<IPAddress<<endl;
		cout<<"IPv4 address was successfully added："<<Netmask<<endl;
		return NTEContext;
    } 
	else 
	{
        cout<<"IPv4 address was failed added："<<IPAddress<<endl;
        cout<<"IPv4 address was failed added："<<Netmask<<endl;
		return 0;
    }

}


int DeleteIPAddr(ULONG NTEContext)
{
    DWORD dwRetVal = 0;

	 // Delete the IP we just added using the NTEContext
    // variable where the handle was returned       
    if ((dwRetVal = DeleteIPAddress(NTEContext)) == NO_ERROR) {
		cout<<"IP Address Deleted sucessfully"<<endl;
		return WIN_SUCCESS;

    } else 
	{
        cout<<"IP Address Deleted failed"<<endl;
		return WIN_ERROR;
    }

}


//通知ip地址改变了
int NotifyIpChange(ULONG nIndex, LPCSTR lpszAdapterName, char pIpAddr[IP_ADDR_LEN], char pNetMask[IP_ADDR_LEN])
{
    int bResult       =   WIN_ERROR;
	HINSTANCE hDhcpDll;
	DHCPNOTIFYPROC pDhcpNotifyProc; 
	WCHAR   wcAdapterName[256];

	MultiByteToWideChar(CP_ACP, 0, lpszAdapterName, -1, wcAdapterName, 256);

	if((hDhcpDll = LoadLibrary("dhcpcsvc")) == NULL) 
	{
		cout<<"load dhcpsvc filed, exit"<<endl;
	    return   WIN_ERROR;
	}

	if((pDhcpNotifyProc = (DHCPNOTIFYPROC)GetProcAddress(hDhcpDll, "DhcpNotifyConfigChange")) != NULL)
	{
		cout<<"wcAdapterName:"<<wcAdapterName<<endl;
		cout<<"nIndex:"<<nIndex<<endl;
		cout<<"inet_addr(pIpAddr):"<<inet_addr(pIpAddr)<<endl;
		cout<<" inet_addr(pNetMask):"<< inet_addr(pNetMask)<<endl;

	    if((pDhcpNotifyProc)(NULL, wcAdapterName, TRUE, nIndex,  inet_addr(pIpAddr),  inet_addr(pNetMask), 0) == ERROR_SUCCESS)
		{
		   bResult = WIN_SUCCESS; 
		   cout<<"dhcp notify success"<<endl;
		}

		FreeLibrary(hDhcpDll);
		return bResult;
	}
    cout<<"dhcp notify failed!"<<endl;
	return WIN_ERROR;


}

//修改ip，将ip信息写入注册表
int RegGetCHName(const char* lpszAdapterName, char* CHName)
{
    char	szKeyName[1024] = "SYSTEM\\ControlSet001\\Control\\Network\\{4D36E972-E325-11CE-BFC1-08002BE10318}\\";

    HKEY	hKey;
	DWORD   NameLen = DEVICE_NAME_LEN;
    DWORD   type = REG_SZ;

	BYTE*   byBuffer = NULL;
    DWORD dwLen;

	int rt = 0;


    strcat(szKeyName,lpszAdapterName);
	strcat(szKeyName, "\\Connection");

	if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, szKeyName, 0, KEY_QUERY_VALUE, &hKey) != ERROR_SUCCESS)
	{
	    cout<<"Open register key error!"<<endl;
		return WIN_ERROR;
	}

    RegQueryValueEx(hKey, "Name", 0, NULL, NULL, &dwLen);

    byBuffer=new BYTE[dwLen];

	 rt = RegQueryValueEx(hKey, "Name", 0, NULL, (BYTE*)byBuffer, &dwLen);
	if (rt!= ERROR_SUCCESS)
	{
	    cout<<"get chname  failure！"<<endl;
		cout<<"return value:"<<rt<<endl;
		RegCloseKey(hKey);
        return WIN_ERROR;
	}

	strcpy(CHName, (char *)byBuffer);


	RegCloseKey(hKey);

	return WIN_SUCCESS;


}



//修改ip，将ip信息写入注册表
int RegSetIp(ULONG ifIndex, char pIpAddr[IP_ADDR_LEN], char pNetMask[IP_ADDR_LEN], char pNetGate[IP_ADDR_LEN])
{
    char	szKeyName[1024] = "System\\CurrentControlSet\\Services\\Tcpip\\Parameters\\Interfaces\\";
    HKEY	hKey;

	char lpszAdapterName[DEVICE_NAME_LEN];

	char	reg_IpAddr[IP_SIZE]  = {'\0'};
	char	reg_NetMask[IP_SIZE] = {'\0'};
	char	reg_NetGate[IP_SIZE] = {'\0'};

	int		nIpLen = 0, nNetMaskLen = 0, nNetGateLen = 0;


	GetDeviceNameByIndex(ifIndex,lpszAdapterName);

    strcat(szKeyName,lpszAdapterName);
	if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, szKeyName, 0, KEY_WRITE, &hKey) != ERROR_SUCCESS)
	{
	    cout<<"Open register key error!"<<endl;
		return WIN_ERROR;
	}


	nIpLen      = strlen(pIpAddr);
    nNetGateLen = strlen(pNetMask);
	nNetMaskLen = strlen(pNetGate);

	nIpLen      += 2;
    nNetGateLen += 2;
    nNetMaskLen += 2;


	if (RegSetValueEx(hKey, "IPAddress", 0, REG_MULTI_SZ, (unsigned char*)pIpAddr, nIpLen) != ERROR_SUCCESS)
	{
	    cout<<"Change ip failure！"<<endl;
		RegCloseKey(hKey);
        return WIN_ERROR;
	}

	if (RegSetValueEx(hKey, "SubnetMask", 0, REG_MULTI_SZ, (unsigned char*)pNetMask, nNetMaskLen) != ERROR_SUCCESS)
	{
		cout<<"Change subnet failure！"<<endl;
		RegCloseKey(hKey);
        return WIN_ERROR;

	
	}

	if (RegSetValueEx(hKey, "DefaultGateway", 0, REG_MULTI_SZ, (unsigned char*)pNetGate, nNetGateLen) != ERROR_SUCCESS)
	{
	    cout<<"Change gateway failure！"<<endl;
		RegCloseKey(hKey);
        return WIN_ERROR;
	}

	RegCloseKey(hKey);

	return NotifyIpChange(ifIndex,lpszAdapterName,pIpAddr,pNetMask);


}
//设置网卡的禁用和启用状态
BOOL SetDevState(HDEVINFO hDevInfo, DWORD dwState)
{
	SP_DEVINFO_DATA	DevInfoData = {sizeof(SP_DEVINFO_DATA)};
    char	szDevName[DEVICE_NAME_LEN] ;
	char	szDevInst[DEVICE_NAME_LEN] ;

	for (DWORD dwIndex = 0; SetupDiEnumDeviceInfo(hDevInfo, dwIndex, &DevInfoData); dwIndex++)
	{
		SetupDiClassNameFromGuid(&DevInfoData.ClassGuid, szDevName, DEVICE_NAME_LEN, NULL);
        if (strcmp(szDevName, "Net"))
			continue;

		SetupDiGetDeviceInstanceId(hDevInfo, &DevInfoData, szDevInst, DEVICE_NAME_LEN, NULL);

		if (strncmp(szDevInst, "PCI", 3))
            continue;

		SP_PROPCHANGE_PARAMS	Param =	{sizeof(SP_CLASSINSTALL_HEADER)};
        Param.HwProfile   =  0 ;
        Param.StateChange = dwState ;
        Param.Scope       = DICS_FLAG_CONFIGSPECIFIC ;
        Param.ClassInstallHeader.InstallFunction = DIF_PROPERTYCHANGE;
        SetupDiSetClassInstallParams(hDevInfo, &DevInfoData, (SP_CLASSINSTALL_HEADER*)&Param, sizeof(SP_PROPCHANGE_PARAMS));
        if (!SetupDiChangeState(hDevInfo, &DevInfoData))
            return FALSE ;
	}

	return TRUE;

}

//重启网卡
int ReStartCard()
{
    HDEVINFO	hDevInfo ;
    hDevInfo = SetupDiGetClassDevs(NULL, NULL, NULL, DIGCF_ALLCLASSES | DIGCF_PRESENT);
    if (INVALID_HANDLE_VALUE == hDevInfo)
	{
	    cout<<"restart nic failed!"<<endl;
		return WIN_ERROR;
	}

	if (!SetDevState(hDevInfo, DICS_DISABLE))
	{
	    cout<<"diabled nic failed!"<<endl;
		return WIN_ERROR;	    
	}

	if (!SetDevState(hDevInfo,  DICS_ENABLE))
	{
	    cout<<"start nic failed!"<<endl;
		return WIN_ERROR;	    
	}

	SetupDiDestroyDeviceInfoList(hDevInfo) ;

	return WIN_SUCCESS;
}

//获取设备的显示名称
int GetDeviceCHName(char* mac, char* CHName)
{
	int rt = WIN_ERROR;
	char  Name[DEVICE_NAME_LEN]={0};
	rt = GetDeviceNameByMac(mac,Name);
	if(rt != WIN_SUCCESS)
	{
	    return WIN_ERROR;
	}

    rt = RegGetCHName(Name, CHName);
	if(rt != WIN_SUCCESS)
	{
	    return WIN_ERROR;
	}


	return WIN_SUCCESS;
	
}

