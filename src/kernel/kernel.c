#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <kernel.h>
#include <vga.h>
#include <tty.h>

extern void check_cpuid();
extern void check_long_mode();
extern void set_up_page_tables();
extern void enable_paging();

static const char *error_messages[] = {
	"Kernel was not booted by multiboot2-compliant bootloader",
	"CPUID instruction not supported",
	"Long mode not available"
};

void kernel_error(uint8_t e) {
	tty_writestring("Error: ");
	tty_writestring(error_messages[e]);
}

void kernel_main() {
	// Initialize terminal interface
	tty_initialize();

	check_cpuid();
	check_long_mode();

	set_up_page_tables();
	enable_paging();

	tty_writestring("Hello, ^4kernel^7 World!");
/*
	for (size_t i = 0;; i++) {
		tty_writestring("Hello world ");
		tty_putchar(i % 10 + '0');
		tty_putchar('\n');
	}
*/
}

