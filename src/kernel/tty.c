#include <tty.h>
#include <vga.h>

size_t strlen(const char* str) {
	size_t ret = 0;
	while ( str[ret] != 0 )
		ret++;
	return ret;
}

uint8_t tty_default_color;
size_t tty_row;
size_t tty_column;
uint8_t tty_color;
uint16_t* tty_buffer;

void tty_initialize() {
	tty_row = 0;
	tty_column = 0;
	tty_default_color = vga_make_color(COLOR_LIGHT_GREY, COLOR_BLACK);
	tty_color = tty_default_color;
	tty_buffer = (uint16_t*) 0xB8000;
	for (size_t y = 0; y < VGA_HEIGHT; y++) {
		for (size_t x = 0; x < VGA_WIDTH; x++) {
			const size_t index = y * VGA_WIDTH + x;
			tty_buffer[index] = vga_make_vgaentry(' ', tty_color);
		}
	}
}

void tty_setcolor(uint8_t color) {
	tty_color = color;
}

void tty_putentryat(char c, uint8_t color, size_t x, size_t y) {
	const size_t index = y * VGA_WIDTH + x;
	tty_buffer[index] = vga_make_vgaentry(c, color);
}

void tty_scroll() {
	for (size_t y = 1; y < VGA_HEIGHT; y++) {
		for (size_t x = 0; x < VGA_WIDTH; x++) {
			const size_t index1 = y * VGA_WIDTH + x;
			const size_t index2 = index1 - VGA_WIDTH;
			tty_buffer[index2] = tty_buffer[index1];
		}
	}
	for (size_t x = 0; x < VGA_WIDTH; x++) {
		const size_t index = VGA_HEIGHT * VGA_WIDTH + x;
		tty_buffer[index] = vga_make_vgaentry(' ', tty_default_color);
	}
}

void tty_putchar(char c) {
	if (c == '\n') {
		tty_column = 0;
		if (tty_row + 1 == VGA_HEIGHT) {
			tty_scroll();
			tty_row = VGA_HEIGHT - 1;
		} else {
			tty_row++;
		}
	} else {
		tty_putentryat(c, tty_color, tty_column, tty_row);
		if (++tty_column == VGA_WIDTH) {
			tty_column = 0;
			if (++tty_row == VGA_HEIGHT) {
				tty_row = 0;
			}
		}
	}
}

void tty_writestring(const char* data) {
	size_t datalen = strlen(data);
	char c;
	for (size_t i = 0; i < datalen; i++) {
		c = data[i];
		if (c == '^' && i + 1 < datalen) {
			char col = data[i + 1];
			if (col >= '0' && col <= 'A') {
				uint8_t color = vga_make_color(data[i + 1] - '0', COLOR_BLACK);
				tty_setcolor(color);
				i++;
			}
		} else {
			tty_putchar(c);
		}
	}
}

