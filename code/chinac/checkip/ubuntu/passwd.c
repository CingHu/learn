/*
 * passwd.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */



#include "checkip.h"
#include "lib/utils.h"



static char *
make_salt(void)
{
     unsigned long seed[2];
     const char *const seedchars =
          "./0123456789ABCDEFGHIJKLMNOPQRST"
          "UVWXYZabcdefghijklmnopqrstuvwxyz";
     int i;
     char *salt;

     salt = strdup("$6$........");

     seed[0] = time(NULL);
     seed[1] = getpid() ^ (seed[0] >> 14 & 0x30000);

     for (i = 0; i < 8; i++)
          salt[3 + i] = seedchars[(seed[i/5]>>(i%5)*6) & 0x3f];

     return salt;
}



#define SHADOW  "/etc/shadow"

bool
set_user_password(const char *user, const char *passwd)
{
    int i;
    bool ok;
    string_list_t *list;
    char *p, *salt, *line, *shadow, *newline;

    list = sl_load_file(SHADOW);

    if (list == NULL) {
        log_error("Could read file %s", SHADOW);
        return false;
    }

    for (i = 0; i < list->count; i++) {

        line = list->data[i];

        p = strchr(line, ':');

        if (p == NULL) {
            // impossible ...
            log_error(SHADOW " broken in line %d: %s", i + 1, line);
            string_list_free(list);
            return false;
        }

        *p = '\0';

        if (0 != strcasecmp(line, user)) {
            *p = ':';
            continue;
        }

        // We have found the line we need to update for user

        p = strchr(p+1, ':');

        salt = make_salt();
        shadow = crypt(passwd, salt);

        newline = str_print("%s:%s%s", user, shadow, p);
        sl_set(list, i, newline);
        free(salt);

        ok = sl_write_file(SHADOW, list);

        string_list_free(list);

        if (!ok) {
            log_error("Could not write to file" SHADOW);
            return false;
        }

        return true;
    }

    return false;
}



bool
configure_password(header_list_t *l)
{
    bool ok;
    const char *passwd;

    log_info("Update administrator password");

    passwd = hl_get(l, "AdminPsw");

    if (passwd == NULL) {
        log_error("<AdminPsw> not found in XML");
        return false;
    }

    ok = set_user_password("root", passwd);

    if (ok)
        ok = update_password_config();

    return ok;
}






