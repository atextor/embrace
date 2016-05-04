; vim:ft=nasm
section .bootstrap_stack, nobits
; Setup temporary stack
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

	; Make sure that we were booted using multiboot 2
	call check_multiboot

	; Check if the CPUID instruction is available
	call check_cpuid

	; Now use CPUID to check if long mode is available
	call check_long_mode

	; Call kernel_main from kernel.c
	extern kernel_main
	call kernel_main

	; In case the function returns, we'll want to put the computer into an
	; infinite loop. To do that, we use the clear interrupt ('cli') instruction
	; to disable interrupts, the halt instruction ('hlt') to stop the CPU until
	; the next interrupt arrives, and jumping to the halt instruction if it ever
	; continues execution, just to be safe.
	cli

hang:
	hlt
	jmp hang
 
; Displays an error code, if something goes wrong here.
; Will display 'ERR: x', with x being an error code symbol.
; 0xb8000 is the base address of the VGA text buffer.
; 0x07 = light grey text on black background (see vga.h)
; 0x52 = R, 0x45 = E, 0x3A = :, 0x20 = ' '
error:
	mov dword [0xb8000], 0x07520745  ; RE
	mov dword [0xb8004], 0x073A0752  ; :R
	mov dword [0xb8008], 0x07200720  ; '  '
	mov byte  [0xb800a], al
	jmp hang

; Checks if register eax contains the multiboot 2 magic string,
; as specified by the multiboot 2 spec, because we rely on multiboot 2
; features later.
check_multiboot:
    cmp eax, 0x36d76289  ; magic string that the bootloader will write
    jne .no_multiboot
    ret
.no_multiboot:
    mov al, "0"
    jmp error

; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
; in the FLAGS register. If we can flip it, CPUID is available.
check_cpuid: 
	; Copy FLAGS in to EAX via stack
	pushfd
	pop eax

	; Copy to ECX as well for comparing later on
	mov ecx, eax

	; Flip the ID bit
	xor eax, 1 << 21

	; Copy EAX to FLAGS via the stack
	push eax
	popfd

	; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
	pushfd
	pop eax

	; Restore FLAGS from the old version stored in ECX (i.e. flipping the
	; ID bit back if it was ever flipped).
	push ecx
	popfd

	; Compare EAX and ECX. If they are equal then that means the bit
	; wasn't flipped, and CPUID isn't supported.
	cmp eax, ecx
	je .no_cpuid
	ret
.no_cpuid:
	mov al, "1"
	jmp error

; Use the CPUID instruction to check if long mode is available
check_long_mode:
	; test if extended processor info in available
	mov eax, 0x80000000     ; implicit argument for cpuid
	cpuid                   ; get highest supported argument
	cmp eax, 0x80000001     ; it needs to be at least 0x80000001
	jb .no_long_mode        ; if it's less, the CPU is too old for long mode

	; use extended info to test if long mode is available
	mov eax, 0x80000001     ; argument for extended processor info
	cpuid                   ; returns various feature bits in ecx and edx
	test edx, 1 << 29       ; test if the LM-bit is set in the D-register
	jz .no_long_mode        ; If it's not set, there is no long mode
	ret
.no_long_mode:
	mov al, "2"
	jmp error

