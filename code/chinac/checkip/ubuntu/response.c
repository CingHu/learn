/*
 * response.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */



#include "lib/utils.h"
#include "config.h"
#include <libxml2/libxml/tree.h>
#include <libxml2/libxml/parser.h>



header_list_t *
parse_xml_Info(const char *xml)
{
    xmlDoc *doc;
    xmlNode *node, *info;
    header_list_t *list;

    doc = xmlReadMemory(xml, strlen(xml), "noname.xml", NULL, 0);

    if (doc == NULL ) {
        log_error("xmlReadMemory() failed\n%s", xml);
        return NULL ;
    }

    list = header_list_new();

    info = xmlDocGetRootElement(doc);

    for (node = info->children; node; node = node->next)
        if (node->type == XML_ELEMENT_NODE)
            hl_add(list, strdup((const char *) node->name),
                    (char *) xmlNodeGetContent(node), rel_both);

    xmlFreeDoc(doc);
    xmlCleanupParser();
    xmlMemoryDump();

    return list;
}



header_list_t *
parse_xml_Servicesreply(const char *xml)
{
    xmlDoc *doc = NULL;
    xmlNode *node = NULL, *servicesreply = NULL;
    xmlNode *service = NULL, *info = NULL;
    xmlNode *returncode = NULL, *returnmess = NULL;
    header_list_t *list = NULL;

    doc = xmlReadMemory(xml, strlen(xml), "noname.xml", NULL, 0);

    if (doc == NULL ) {
        log_error("xmlReadMemory() failed=n%s", xml);
        return NULL ;
    }

    servicesreply = xmlDocGetRootElement(doc);

    for (node = servicesreply->children; node; node = node->next)
        if (node->type == XML_ELEMENT_NODE) {
            if (0 == strcasecmp((const char *) node->name, "Service"))
                service = node;
            else if (0 == strcasecmp((const char *) node->name, "Info"))
                info = node;
        }

    log_debug("Looking for node <ReturnCode> and <ReturnMess>");

    for (node = service->children; node; node = node->next)
        if (node->type == XML_ELEMENT_NODE) {
            if (0 == strcasecmp((const char *) node->name, "ReturnCode"))
                returncode = node;
            else if (0 == strcasecmp((const char *) node->name, "ReturnMess"))
                returnmess = node;
        }

    list = header_list_new();

    hl_add(list, strdup((const char *) returncode->name),
            (char *) xmlNodeGetContent(returncode), rel_both);
    hl_add(list, strdup((const char *) returnmess->name),
            (char *) xmlNodeGetContent(returnmess), rel_both);

    if (info != NULL )
        hl_add(list, strdup((const char *) info->name),
                (char *) xmlNodeGetContent(info), rel_both);

    xmlFreeDoc(doc);
    xmlCleanupParser();
    xmlMemoryDump();

    return list;
}



char *
unfold_message(const char *str)
{
    if (strlen(str) == 0)
        return strdup("");

    int len = strlen(str);
    char buf[len + 1];
    size_t enclen;

    strcpy(buf, str);
    str_replace(buf, '^', '+');

    char *enc = base64_decode(buf, &enclen);

    if (enc == NULL) {
        log_error("base64_decode() failed");
        return NULL;
    }

    char *data = aes128_cbc_decrypt(enc, enclen, Config.aeskey, Config.aesiv);

    free(enc);

    return data;
}



header_list_t *
handle_info(const char *info)
{
    char *xml;
    header_list_t *list;

    xml = unfold_message(info);

    if (xml == NULL ) {
        log_error("unfodl_message() failed");
        return NULL ;
    }

    list = parse_xml_Info(xml);

    free(xml);
    return list;
}



#define CHECKVAR(var)                                                   \
    do {                                                                \
        if (var == NULL) {                                              \
            log_error("Variable $" #var "is empty");                    \
            header_list_free(list);                                     \
            return NULL;                                                \
        } else {                                                        \
            log_debug("Value of variable: " #var " = %s", var);         \
        }                                                               \
    } while (0)


header_list_t *
handle_response(http_response_t *resp)
{
    header_list_t *list, *infolist;
    const char *code, *mess, *info;

    if (resp->status != 200) {
        log_error("Status code != 200, exit");
        return NULL ;
    }

    list = parse_xml_Servicesreply(resp->body);

    code = hl_get(list, "ReturnCode");
    mess = hl_get(list, "ReturnMess");
    info = hl_get(list, "Info");

    CHECKVAR(code);
    CHECKVAR(mess);
    CHECKVAR(info);

    if (atoi(code) != 1000) {
        log_error("Session failed: ReturnCode = %s, ReturnMess = %s", code,
                  mess);
        header_list_free(list);
        return NULL ;
    }

    infolist = handle_info(info);

    header_list_free(list);

    return infolist;
}


#undef CHECKVAR
