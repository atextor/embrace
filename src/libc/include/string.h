#ifndef _STRING_H
#define _STRING_H

#include <stddef.h>

size_t strlen(const char* str);
int memcmp(const void* aptr, const void* bptr, size_t size);
void* memcpy(void* __restrict, const void* __restrict, size_t);
void* memmove(void* dstptr, const void* srcptr, size_t size);
void* memset(void* bufptr, int value, size_t size);

#endif
