// stdafx.h : include file for standard system include files,
//  or project specific include files that are used frequently, but
//      are changed infrequently
//

#if !defined(AFX_STDAFX_H__A9DB83DB_A9FD_11D0_BFD1_444553540000__INCLUDED_)
#define AFX_STDAFX_H__A9DB83DB_A9FD_11D0_BFD1_444553540000__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#define WIN32_LEAN_AND_MEAN		// Exclude rarely-used stuff from Windows headers

#include <windows.h>


#include "targetver.h"

#include <stdio.h>
#include <tchar.h>
#include <windows.h>
#include <iphlpapi.h>
#include <string.h>
//#include <atlstr.h>
#include <iostream>
#include <setupapi.h>
#include <commctrl.h>
//#include <winsock2.h>
//#include <Netioapi.h>
#include <Winsock2.h>
#include "win_common.h"

//#include <commctrl.h>
//#include <ws2tcpip.h>

#include "targetver.h"


//#include <setupapi.h>
//#include <commctrl.h>
#include <shellapi.h>

#include "logger.h"
#include "basefunc.h"


// TODO: 在此处引用程序需要的其他头文件

int WinShell(char * cmd);
char* str_lower(const char *str);




// TODO: reference additional headers your program requires here

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_STDAFX_H__A9DB83DB_A9FD_11D0_BFD1_444553540000__INCLUDED_)
