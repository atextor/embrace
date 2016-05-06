#ifndef _VGA_H
#define _VGA_H

static const size_t VGA_WIDTH = 80;
static const size_t VGA_HEIGHT = 25;

/* Hardware text mode color constants. */
enum vga_color {
	COLOR_BLACK = 0x0,
	COLOR_BLUE = 0x1,
	COLOR_GREEN = 0x2,
	COLOR_CYAN = 0x3,
	COLOR_RED = 0x4,
	COLOR_MAGENTA = 0x5,
	COLOR_BROWN = 0x6,
	COLOR_LIGHT_GREY = 0x7,
	COLOR_DARK_GREY = 0x8,
	COLOR_LIGHT_BLUE = 0x9,
	COLOR_LIGHT_GREEN = 0xa,
	COLOR_LIGHT_CYAN = 0xb,
	COLOR_LIGHT_RED = 0xc,
	COLOR_LIGHT_MAGENTA = 0xd,
	COLOR_LIGHT_BROWN = 0xd,
	COLOR_WHITE = 0xf,
};

uint8_t vga_make_color(enum vga_color fg, enum vga_color bg);
uint16_t vga_make_vgaentry(char c, uint8_t color);

#endif
