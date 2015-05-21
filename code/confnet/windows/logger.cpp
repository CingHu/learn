/*
 * logger.c
 *
 *  Created on: 2013-2-20
 *      Author: changqian
 */

/* For single-threaded and not regular logging. */

#include "StdAfx.h"
#include "time.h"
#include "windows.h"
#include "tchar.h"
#include "stdio.h"

#define PATH_MAX   128


#define LOGGER_BUFSIZ 2048

using namespace std;



struct Logger {
    char pathname[PATH_MAX];
    char buffer[LOGGER_BUFSIZ];
    bool inited;
    bool debug;
};


static struct Logger Log;



bool
log_init (const char *pathname, bool debug)
{
    FILE *fp;

    if (Log.inited)
        return true;

    fp = fopen(pathname, "w+");

    if (fp == NULL) {
        fprintf(stderr, "Could not open file %s: %s\n", pathname,
                 strerror(errno));
        return false;
    }

    fclose(fp);

    strcpy(Log.pathname, pathname);

    Log.inited = true;
    Log.debug = debug;

    return true;
}



void
log_terminate(void)
{
    Log.inited = false;
}



static void
write_time(struct Logger *log)
{
    time_t t;
    struct tm *tm;

    t = time(NULL);
    tm = localtime(&t);
    strftime(log->buffer, LOGGER_BUFSIZ, "%Y-%m-%d %H:%M:%S ", tm);
}



static void
write_msg(struct Logger *log, const char *fmt, va_list ap)
{
    int len;
    char *p;

    len = strlen(log->buffer);
    p = log->buffer + len;

    _vsnprintf(p, LOGGER_BUFSIZ - len, fmt, ap);

    /* todo: maybe we need some stripping (ending \r\n) */
}


static bool
log_to_file(struct Logger *log)
{
    FILE *fp;

    fp = fopen(log->pathname, "a");
    if (fp == NULL)
        return false;

    fprintf(fp, "%s\n", log->buffer);
    fclose(fp);

    return true;
}


bool
log_info(const char *fmt, ...)
{
    if (!Log.inited)
        return false;

    va_list ap;

    write_time(&Log);

    va_start(ap, fmt);
    write_msg(&Log, fmt, ap);
    va_end(ap);

    return log_to_file(&Log);
}


bool
log_error(const char *fmt, ...)
{
    if (!Log.inited)
        return false;

    va_list ap;

    write_time(&Log);
    strcat(Log.buffer, "*ERROR* ");

    va_start(ap, fmt);
    write_msg(&Log, fmt, ap);
    va_end(ap);

    return log_to_file(&Log);
}



bool
log_debug(const char *fmt, ...)
{
    if (!Log.inited || !Log.debug)
        return false;

    va_list ap;

    write_time(&Log);
    strcat(Log.buffer, "*DEBUG* ");

    va_start(ap, fmt);
    write_msg(&Log, fmt, ap);
    va_end(ap);

    return log_to_file(&Log);
}


bool
log_fatal(const char *fmt, ...)
{
    if (!Log.inited)
        return false;

    va_list ap;

    write_time(&Log);
    strcat(Log.buffer, "*FATAL* ");

    va_start(ap, fmt);
    write_msg(&Log, fmt, ap);
    va_end(ap);

    return log_to_file(&Log);
}
