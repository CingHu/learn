#pragma once

// 以下宏定义要求的最低平台。要求的最低平台
// 是具有运行应用程序所需功能的 Windows、Internet Explorer 等产品的
// 最早版本。通过在指定版本及更低版本的平台上启用所有可用的功能，宏可以
// 正常工作。

// 如果必须要针对低于以下指定版本的平台，请修改下列定义。
// 有关不同平台对应值的最新信息，请参考 MSDN。
//#ifndef _WIN32_WINNT            // 指定要求的最低平台是 Windows Vista。
//#define _WIN32_WINNT 0x0600     // 将此值更改为相应的值，以适用于 Windows 的其他版本。

#include "win_common.h"
#include <windows.h>
#include <string>

typedef struct IpAddressInfo
{
    char szIPAddrStr[IP_ADDR_LEN];
	char szGatewagStr[IP_ADDR_LEN];
	char szNetmaskStr[IP_ADDR_LEN];
	bool filled;
	ULONG NTEContext;
	DWORD dwIndex;
}INFO_IP,*PINFO_IP;

typedef struct tagAdapterInfo
{
    char szDeviceName[DEVICE_NAME_LEN];//name
	INFO_IP IPInfo[IP_NUMBER];        //IP info
	char szHWAddrStr[MAC_ADDR_LEN];    //MAC
	int  nType;
	DWORD dwIndex;                     //编号
	bool filled;                       //是否取得了网卡信息

}INFO_ADAPTER, *PINFO_ADAPTER;

typedef struct IpFowardRoute
{
    char szDestIp[IP_ADDR_LEN];
    char szMaskIp[IP_ADDR_LEN];
    char szGatewayIp[IP_ADDR_LEN];
	DWORD dwForwardType;
	DWORD dwForwardProto;
	DWORD dwForwardAge;
	DWORD dwForwardMetric1;
}IP_FORWARD_ROUTE;

//#endif



