; vim:ft=nasm
section .bss
align 4096
; Set up page tables.
; p4 = page table,
; p3 a.k.a. page directory table (PD),
; p2 a.k.a. page directory pointer table (PDP),
; p1 a.k.a. page map level 4 table (PML4)
; Each page table entry is 8 bytes, and each table
; contains 512 entries, so each size is 512*9 = 4096.
; This is in the .bss section, and because GRUB will initialize it with 0,
; it's already valid (although useless)
p4_table:
    resb 4096
p3_table:
    resb 4096
p2_table:
    resb 4096
stack_bottom:
    resb 16384
stack_top:

section .bootstrap_stack, nobits
; Setup temporary stack
align 4 
;stack_bottom:
;resb 16384
;stack_top:

global _start 
section .text
bits 32

; This is where the bootloader will jump, see linker.ld
_start:
	; To set up a stack, we simply set the esp register to point to the top of
	; our stack (as it grows downwards).
	mov esp, stack_top

	; The one thing we must do here, before register eax is overwritten, is
	; to make sure that we were booted using multiboot 2
	call check_multiboot

	; Call kernel_main from kernel.c
	extern kernel_main
	call kernel_main

global hang
hang:
	; In case the function returns, we'll want to put the computer into an
	; infinite loop. To do that, we use the clear interrupt ('cli') instruction
	; to disable interrupts, the halt instruction ('hlt') to stop the CPU until
	; the next interrupt arrives, and jumping to the halt instruction if it ever
	; continues execution, just to be safe.
	cli
	hlt
	jmp hang

; Checks if register eax contains the multiboot 2 magic string,
; as specified by the multiboot 2 spec, because we rely on multiboot 2
; features later.
extern kernel_error
extern tty_initialize
check_multiboot:
	cmp eax, 0x36d76289  ; magic string that the bootloader will write
	jne .no_multiboot
	ret
.no_multiboot:
	call tty_initialize
	push dword 0x0       ; Error code, see corresponding message in kernel.c
	call kernel_error
	jmp hang

; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
; in the FLAGS register. If we can flip it, CPUID is available.
global check_cpuid
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
	push dword 0x1       ; Error code, see corresponding message in kernel.c
	call kernel_error
	jmp hang

; Use the CPUID instruction to check if long mode is available
global check_long_mode
check_long_mode:
	; test if extended processor info in available
	mov eax, 0x80000000     ; implicit argument for cpuid
	cpuid                   ; get highest supported argument from address eax
	cmp eax, 0x80000001     ; it needs to be at least 0x80000001
	jb .no_long_mode        ; if it's less, the CPU is too old for long mode

	; use extended info to test if long mode is available
	mov eax, 0x80000001     ; argument for extended processor info
	cpuid                   ; returns various feature bits in ecx and edx
	test edx, 1 << 29       ; test if the LM-bit is set in the D-register
	jz .no_long_mode        ; If it's not set, there is no long mode
	ret
.no_long_mode:
	push dword 0x2       ; Error code, see corresponding message in kernel.c
	call kernel_error
	jmp hang

global set_up_page_tables
set_up_page_tables:
	; map first P4 entry to P3 table
	mov eax, p3_table
	or eax, 0b11            ; present + writable
	mov [p4_table], eax

	; map first P3 entry to P2 table
	mov eax, p2_table
	or eax, 0b11            ; present + writable
	mov [p3_table], eax

	; map each P2 entry to a huge 2MiB page
	; By setting the 'huge' bit in a P2 entry, it means the entry
	; refers to a 2MiB page
	mov ecx, 0              ; counter variable 
.map_p2_table:
	; map ecx-th P2 entry to a huge page that starts at address 2MiB*ecx
	mov eax, 0x200000       ; 2MiB
	mul ecx                 ; start address of ecx-th page
	or eax, 0b10000011      ; present + writable + huge
	mov [p2_table + ecx * 8], eax ; map ecx-th entry

	inc ecx                 ; increase counter
	cmp ecx, 512            ; if counter == 512, the whole P2 table is mapped
	jne .map_p2_table       ; else map the next entry

	ret

global enable_paging
enable_paging:
	; load P4 to cr3 register (cpu uses this to access the P4 table)
	mov eax, p4_table
	mov cr3, eax

	; enable PAE-flag in cr4 (Physical Address Extension)
	mov eax, cr4
	or eax, 1 << 5
	mov cr4, eax

	; set the long mode bit in the EFER MSR (model specific register)
	mov ecx, 0xC0000080     ; magic string: address of the "EFER" model specific register
	rdmsr                   ; "read model specific register" at address ecx
	or eax, 1 << 8          ; magic bit: set the "EFER.LME" bit
	wrmsr                   ; "write model specific register" at address ecx

	; enable paging in the cr0 register
	mov eax, cr0
	or eax, 1 << 31
	mov cr0, eax

	ret
