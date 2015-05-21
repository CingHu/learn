// stdafx.cpp : source file that includes just the standard includes
//	confnet_win.pch will be the pre-compiled header
//	stdafx.obj will contain the pre-compiled type information

#include "stdafx.h"
#include <time.h>

// TODO: reference any additional headers you need in STDAFX.H
// and not in this file





int WinShell(char * cmd)
{
    //system(cmd);
    WinExec(cmd, SW_HIDE);
	return 0;
}


