/*
 * logger.h
 *
 *  Created on: 2013-2-27
 *      Author: changqian
 */

#ifndef LOGGER_H_
#define LOGGER_H_


#include <stdbool.h>


bool log_init(const char *pathname, bool debug);
void log_terminate(void);
bool log_info(const char *fmt, ...);
bool log_error(const char *fmt, ...);
bool log_debug(const char *fmt, ...);
bool log_fatal(const char *fmt, ...);


#endif /* LOGGER_H_ */
