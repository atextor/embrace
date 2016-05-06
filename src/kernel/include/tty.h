#ifndef _TTY_H
#define _TTY_H

#include <stddef.h>
#include <stdint.h>

size_t strlen(const char* str);
void tty_initialize();
void tty_setcolor(uint8_t color);
void tty_putentryat(char c, uint8_t color, size_t x, size_t y);
void tty_putchar(char c);
void tty_writestring(const char* data);
void tty_putbyte(uint8_t b);
void tty_writepointer(const void* p);

#endif
