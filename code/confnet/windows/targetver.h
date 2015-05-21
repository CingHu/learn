#pragma once

// ���º궨��Ҫ������ƽ̨��Ҫ������ƽ̨
// �Ǿ�������Ӧ�ó������蹦�ܵ� Windows��Internet Explorer �Ȳ�Ʒ��
// ����汾��ͨ����ָ���汾�����Ͱ汾��ƽ̨���������п��õĹ��ܣ������
// ����������

// �������Ҫ��Ե�������ָ���汾��ƽ̨�����޸����ж��塣
// �йز�ͬƽ̨��Ӧֵ��������Ϣ����ο� MSDN��
//#ifndef _WIN32_WINNT            // ָ��Ҫ������ƽ̨�� Windows Vista��
//#define _WIN32_WINNT 0x0600     // ����ֵ����Ϊ��Ӧ��ֵ���������� Windows �������汾��

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
	DWORD dwIndex;                     //���
	bool filled;                       //�Ƿ�ȡ����������Ϣ

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



