; vim:ft=nasm
; This is the header following the Multiboot 2 specification.
; This allows a compliant bootloader, such as GRUB 2, to load
; the kernel.
section .multiboot_header
header_start:
    dd 0xe85250d6                ; magic number for multiboot 2
	dd 0                         ; architecture (0=i386, 4=mips32)
    dd header_end - header_start ; header length

	; checksum: -(magic number + architecture + header_length)
    dd 0x100000000 - (0xe85250d6 + 0 + (header_end - header_start))

    ; required end tag
    dw 0    ; type
    dw 0    ; flags
    dd 8    ; size
header_end:

