#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "hashtable.h"
//#include "linux/mempool.h"
//#include "log.h"

#define SUCCESS 1
#define FAILED 0
#define HASH_LEN 5



int hash_init(HashTable **ht) {
    (*ht) = (HashTable *)malloc(sizeof(HashTable));
    if (NULL == ht) {
        //write_log("HashTable init error");
        printf("HashTable init error");
        exit(1);
    }
    (*ht)->size = 0;
    (*ht)->total = HASH_LEN;
    Bucket *bucket = (Bucket *)malloc(sizeof(Bucket) * HASH_LEN);
    memset(bucket, 0, sizeof(sizeof(Bucket) * HASH_LEN));
    (*ht)->buckets = bucket;
    return SUCCESS;
}

int hash_insert(HashTable *ht, char *key, void *value) {
    if (ht->size >= ht->total) {
        ht->buckets = (Bucket *)realloc(ht->buckets, sizeof(Bucket) * (ht->size + HASH_LEN));
        ht->total = ht->size + HASH_LEN;
    }
    int index = hash_index(ht, key);
    Bucket *bucket = &ht->buckets[index];
    int _tmpindex;
    char _tmpindexstr[20];
    while (NULL != bucket->value) {

        while (NULL != bucket->next) {
            if (strcmp(key, bucket->key) == 0) {
                memset(bucket->value, 0, sizeof(bucket->value));
                memcpy(bucket->value, value, sizeof(value));
                return SUCCESS;
            }
            bucket = bucket->next;
        }

        do {
            _tmpindex = abs(rand() - index);
            sprintf(_tmpindexstr, "%d", _tmpindex);
            _tmpindex = hash_index(ht, _tmpindexstr);
        } while (_tmpindex == index || ht->buckets[_tmpindex].value != NULL);

        index = _tmpindex;
        bucket->next = &ht->buckets[index];
        bucket = bucket->next;
    }

    bucket->key = (char *)malloc(sizeof(key));
    bucket->value = (void *)malloc(sizeof(value));
    memcpy(bucket->key, key, sizeof(key));
    memcpy(bucket->value, value, sizeof(value));
    bucket->next = NULL;
    ht->size ++;

    return SUCCESS;
}

int hash_find(HashTable *ht, char *key, void **result) {
    int index = hash_index(ht, key);
    Bucket *bucket = &ht->buckets[index];
    if (NULL == bucket->value) {
        return FAILED;
    }

    while (strcmp(key, bucket->key)) {
        if (NULL != bucket->next) {
            bucket = bucket->next;
        } else {
            break;
        }
    }
    if (NULL == bucket->value || strcmp(key, bucket->key)) {
        return FAILED;
    }

    *result = bucket->value;
    return SUCCESS;

}

int hash_delete(HashTable *ht, char *key) {
    int index = hash_index(ht, key);
    Bucket *bucket = &ht->buckets[index];
    if (NULL == bucket->value) {
        return FAILED;
    }

    while (strcmp(key, bucket->key)) {
        if (NULL != bucket->next) {
            bucket = bucket->next;
        } else {
            break;
        }
    }

    if (NULL == bucket->value || strcmp(key, bucket->key)) {
        return FAILED;
    }

    memset(bucket, 0, sizeof(Bucket));
    ht->size --;
    return SUCCESS;
}

void hash_status(HashTable *ht) {
    printf("Total Size:\t\t%d\n", ht->total);
    printf("Current Size:\t\t%d\n", ht->size);
}

int hash_index(HashTable *ht, char *key) {
    return ELFHash(key, ht->total);
}

// ELF Hash Function
static unsigned int ELFHash(char *str, unsigned int length){
    unsigned int hash = 0;
    unsigned int x = 0;

    while (*str)
    {
        hash = (hash << 4) + (*str++);//hash左移4位，把当前字符ASCII存入hash低四位。 
        if ((x = hash & 0xF0000000L) != 0)
        {
            //如果最高的四位不为0，则说明字符多余7个，现在正在存第8个字符，如果不处理，再加下一个字符时，第一个字符会被移出，因此要有如下处理。
            //该处理，如果对于字符串(a-z 或者A-Z)就会仅仅影响5-8位，否则会影响5-31位，因为C语言使用的算数移位
            //因为1-4位刚刚存储了新加入到字符，所以不能>>28
            hash ^= (x >> 24);
            //上面这行代码并不会对X有影响，本身X和hash的高4位相同，下面这行代码&~即对28-31(高4位)位清零。
            hash &= ~x;
        }
    }
    //返回一个符号位为0的数，即丢弃最高位，以免函数外产生影响。(我们可以考虑，如果只有字符，符号位不可能为负)
    return (hash & 0x7FFFFFFF) % length;
}
