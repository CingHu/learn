/*
 * request.c
 *
 *  Created on: 2013-2-28
 *      Author: changqian
 */



#include "checkip.h"
#include "lib/utils.h"
#include <libxml2/libxml/tree.h>
#include <libxml2/libxml/parser.h>
#include <libxml2/libxml/xmlstring.h>


static char *
hl_tokin(header_list_t *list)
{
    char *tokin;
    char *tokinstr;

    tokinstr = hl_tokin_string(list);

    tokin = md5(tokinstr, strlen(tokinstr));

    free(tokinstr);
    return tokin;
}



void
hl_append_tokin(header_list_t *l)
{
    int i;
    char *tokin;
    header_t *h;
    header_list_t *nl;

    log_debug("hl_append_tokin()");

    nl = header_list_new();
    for (i = 0; i < l->count; i++) {
        h = &l->data[i];
        log_debug("header name = %s, value = %s", h->name, h->value);
        hl_add(nl, str_lower(h->name), strdup(h->value), rel_both);
    }
    hl_add(nl, "key", Config.md5key, rel_none);
    tokin = hl_tokin(nl);

    hl_add(l, "Tokin", tokin, rel_value);

    header_list_free(nl);
}



void
hl_append_rand(header_list_t *l)
{
    char *rand = randnums(16);
    hl_add(l, "Rand", rand, rel_value);
}



xmlNode *
make_xml_node(xmlNode *father,
              const char *name, const char *content)
{
    xmlNode *child = xmlNewNode(NULL, BAD_CAST(name));
    if (content)
        xmlAddChild(child, xmlNewText(BAD_CAST(content)));
    xmlAddChild(father, child);
    return child;
}



char *
xmldoc_to_string(xmlDoc *doc)
{
    char *str;
    xmlChar *buf;
    int bufsize;

    xmlDocDumpFormatMemory(doc, &buf, &bufsize, 1);
    str = (char*)malloc(bufsize + 1);
    memcpy(str, buf, bufsize);
    str[bufsize] = '\0';
    xmlFree(buf);

    return str;
}



char *
enfold_message(const char *msg)
{
    if (strlen(msg) == 0)
        return strdup("");

    const char *aeskey = Config.aeskey;
    const char *aesvec = Config.aesiv;

    char *msgenc, *msgenc64;
    size_t msgenclen;

    msgenc   = aes128_cbc_encrypt(msg, aeskey, aesvec, &msgenclen);
    msgenc64 = base64_encode(msgenc, msgenclen);
    str_replace(msgenc64, '+', '^');
    free(msgenc);

    return msgenc64;
}



char *
make_xml_Services(header_list_t *list)
{
    char *str;
    xmlDoc *doc;
    xmlNode *root, *service;

    doc = xmlNewDoc(BAD_CAST("1.0"));
    root = xmlNewNode(NULL, BAD_CAST("Services"));
    xmlDocSetRootElement(doc, root);

    service = make_xml_node(root, "Service", NULL);

    int i;
    header_t *h;

    for (i = 0; i < list->count; i++) {
        h = &list->data[i];
        if (h->name && h->value)
            make_xml_node(service, h->name, h->value);

    }

    str = xmldoc_to_string(doc);

    xmlFreeDoc(doc);
    xmlCleanupParser();
    xmlMemoryDump();

    return str;
}



char *
make_post_value(const char *mac)
{
    header_list_t *list;

    list = header_list_new();
    hl_add(list, "Action", "get_ip", rel_none);
    hl_add(list, "Mac", strdup(mac), rel_value);
    hl_append_rand(list);
    hl_append_tokin(list);

    char *xml;
    char *value;

    xml = make_xml_Services(list);
    value = enfold_message(xml);

    free(xml);
    header_list_free(list);
    return value;
}



char *
make_request_content(const char *mac)
{
    char *content;
    header_list_t *list;

    list = header_list_new();

    hl_add(list, "DFERYHKJ", make_post_value(mac), rel_value);
    content = hl_post_string(list);

    header_list_free(list);
    return content;
}



http_request_t *
make_request(const char *mac)
{
    char *content;
    const char *content_length;
    http_request_t *req;

    log_debug("make_request()");

    req = http_request_new();

    content = make_request_content(mac);
    content_length = int_to_str(strlen(content));

    hreq_set_method(req, "POST", Config.post_page);

    hreq_set_header(req, "Host", Config.conn_host, rel_none);
    hreq_set_header(req, "Content-Type",
                    "application/x-www-form-urlencoded", rel_none);
    hreq_set_header(req, "Content-Length", content_length, rel_value);
    hreq_set_header(req, "Accept", "*/*", rel_none);

    hreq_set_content(req, content);

    return req;
}



int
send_request(int fd, http_request_t *req)
{
    int i, ret;
    buffer_t buf;
    header_t *h;

    buf_init(&buf, 2048);

    buf_append(&buf, "%s %s HTTP/1.0\r\n", req->method, req->arg);

    for (i = 0; i < req->headers->count; i++) {
        h = &req->headers->data[i];
        buf_append(&buf, "%s: %s\r\n", h->name, h->value);
    }

    buf_append(&buf, "\r\n%s", req->content);

    log_debug("Request content:\n%s", buf.data);

    ret = send(fd, buf.data, buf.offset, 0);

    if (ret == -1)
        log_error("send() failed: %s", strerror(errno));

    buf_free(&buf);

    return ret;
}



