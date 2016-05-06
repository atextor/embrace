#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <kernel.h>
#include <vga.h>
#include <tty.h>

void kernel_main(void* boot_info) {
	// Initialize terminal interface
	tty_initialize();

	tty_writestring("Hello, ^4kernel^7 World!");
	tty_writestring("\nBoot info pointer: ");
	tty_writepointer(boot_info);
/*
	for (size_t i = 0;; i++) {
		tty_writestring("Hello world ");
		tty_putchar(i % 10 + '0');
		tty_putchar('\n');
	}
*/
}

