// VMWindowsNetworkConfig.cpp : 定义控制台应用程序的入口点。
//
#include "StdAfx.h"
#include "manager.h"
#include "shell.h"
#include "inet.h"

using namespace std;

#pragma comment(lib,"ws2_32.lib") 
#pragma comment(lib,"setupapi.lib") 
#pragma comment(lib, "iphlpapi.lib")



//help info
void print_func()
{
	cout<<"input param error, please check input param,help info:"<<endl;
    cout<<"\tget_index_by_mac   mac"<<endl;
    cout<<"\tinterface"<<endl;
    cout<<"\treset_interface   mac"<<endl;
    cout<<"\treset_all_interface"<<endl;
}


int main(int argc, _TCHAR* argv[])
{
	char mac[MAC_ADDR_LEN];
    char ip[IP_ADDR_LEN];
    char netmask[IP_ADDR_LEN];
    char gateway[IP_ADDR_LEN];
	char name[DEVICE_NAME_LEN];
	int num = 0;
	int rt = -1;

	char func[128];
	int index = 0;

	if(argc < 2)
    {
        print_func();
        return WIN_ERROR;
    }

	log_init(LOG_NAME, true);

	strcpy(func, argv[1]);

	if(strcmp(func, "get_index_by_mac") == 0 && argc == 3)
    {
        strcpy(mac, argv[2]);
        index = GetDeviceIndex(mac);
        cout<<"0x"<<hex<<index<<endl;
        return WIN_SUCCESS;
    }
	else if(strcmp(func, "interface") == 0 && argc == 2)
    {
		parase_dir_file();
		rt = config_interface();
        return rt;
    }
    else if(strcmp(func, "reset_interface") == 0 && argc == 3)
    {
        strcpy(mac, argv[2]);
        ReStartCard();
        return WIN_SUCCESS;
    }
    else if(strcmp(func, "reset_all_interface") == 0 && argc == 2)
    {
         ReStartCard();
    }
	else
	{
        print_func();
        return WIN_ERROR;
	}


    return WIN_SUCCESS;

}

