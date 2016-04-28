; Currently the stack pointer register (esp) points at anything and using it may
; cause massive harm. Instead, we'll provide our own stack. We will allocate
; room for a small temporary stack by creating a symbol at the bottom of it,
; then allocating 16384 bytes for it, and finally creating a symbol at the top.
section .bootstrap_stack, nobits
align 4
stack_bottom:
resb 16384
stack_top:


global _start 
section .text
bits 32
; This is where the bootloader will jump, see linker.ld
_start:
	; To set up a stack, we simply set the esp register to point to the top of
	; our stack (as it grows downwards).
	mov esp, stack_top

	; We are now ready to actually execute C code. We cannot embed that in an
	; assembly file, so we'll create a kernel.c file in a moment. In that file,
	; we'll create a C entry point called kernel_main and call it here.
	extern kernel_main
	call kernel_main

;    mov word [0xb8000], 0x0248 ; H
;    mov word [0xb8002], 0x0265 ; e
;    mov word [0xb8004], 0x026c ; l
;    mov word [0xb8006], 0x026c ; l
;    mov word [0xb8008], 0x026f ; o
;    mov word [0xb800a], 0x022c ; ,
;    mov word [0xb800c], 0x0220 ;
;    mov word [0xb800e], 0x0277 ; w
;    mov word [0xb8010], 0x026f ; o
;    mov word [0xb8012], 0x0272 ; r
;    mov word [0xb8014], 0x026c ; l
;    mov word [0xb8016], 0x0264 ; d
;    mov word [0xb8018], 0x0221 ; !

	; In case the function returns, we'll want to put the computer into an
	; infinite loop. To do that, we use the clear interrupt ('cli') instruction
	; to disable interrupts, the halt instruction ('hlt') to stop the CPU until
	; the next interrupt arrives, and jumping to the halt instruction if it ever
	; continues execution, just to be safe.
	cli
.hang:
	hlt
	jmp .hang
 
