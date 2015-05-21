#ifndef MANAGER_H
#define MANAGER_H

void GetAdapterInfo();
DWORD  GetDeviceIndex(char* szDeviceMac);
DWORD  GetDeviceNameByIndex(DWORD ifIndex, char* DeviceName);
DWORD  GetDeviceNameByMac(char* szDeviceMac, char* DeviceName);
int GetDeviceIPNum(DWORD Index);
static DWORD SetDeviceRoute(const DWORD& dwDestAddr, const DWORD& dwMask, const DWORD& dwNextHop, const DWORD& dwInterfaceIndex);
DWORD GetDefaultRoute(IP_FORWARD_ROUTE *ptForwardRoute);
int AddIPAddr(DWORD ifIndex, char* IPAddress, char* Netmask);
int DeleteIPAddr(ULONG NTEContext);
int NotifyIpChange(ULONG nIndex, LPCSTR lpszAdapterName, char pIpAddr[IP_ADDR_LEN], char pNetMask[IP_ADDR_LEN]);
int RegGetCHName(const char* lpszAdapterName, char* CHName);
int RegSetIp(ULONG ifIndex, char pIpAddr[IP_ADDR_LEN], char pNetMask[IP_ADDR_LEN], char pNetGate[IP_ADDR_LEN]);
BOOL SetDevState(HDEVINFO hDevInfo, DWORD dwState);
int ReStartCard();
int GetDeviceCHName(char* mac, char* CHName);
void FormatMACToStr(LPSTR lpHWAddrStr,const unsigned char *HWAddr);
DWORD  GetExternalDeviceMac(char *mac);
int GetDeviceIPAddress(DWORD Index, char IPAddrArr[][IP_ADDR_LEN]);


#endif











