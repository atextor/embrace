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

; Read-Only data section
section .rodata

; Global Descriptor Table (GDT) for when we're in long mode (64 bit)
; This needs to have at least one zero-entry, one code entry and one
; data entry. Entries in the GDT are also sometimes called gates.
; Each entry is always 8 bytes long and has the following format:
; Bit(s)  Name                   Meaning
; 0-15    limit 0-15             the first 2 byte of the segment’s limit
; 16-39   base 0-23              the first 3 byte of the segment’s base address
; 40      accessed               set by the CPU when the segment is accessed
; 41      read/write             reads allowed for code segments / writes allowed for data segments
; 42      direction/conforming   the segment grows down (i.e. base>limit) for data segments / the current privilege level can be higher than the specified level for code segments (else it must match exactly)
; 43      executable             if set, it’s a code segment, else it’s a data segment
; 44      descriptor type        should be 1 for code and data segments
; 45-46   privilege              the ring level: 0 for kernel, 3 for user
; 47      present                must be 1 for valid selectors
; 48-51   limit 16-19            bits 16 to 19 of the segment’s limit
; 52      available              freely available to the OS
; 53      64-bit                 should be set for 64-bit code segments
; 54      32-bit                 should be set for 32-bit segments
; 55      granularity            if it’s set, the limit is the number of pages, else it’s a byte number
; 56-63   base 24-31             the last byte of the base address
gdt64:
	; zero entry
	dq 0
	; code segment
.code: equ $ - gdt64
	dq (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53)
	; data segment
.data equ $ - gdt64
	dq (1<<44) | (1<<47) | (1<<41)
.pointer:
	dw $ - gdt64 - 1
	dq gdt64

; Data section
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
align 4 

; Code section
section .text
bits 32

; This is where the bootloader will jump, see linker.ld
_start:
	; To set up a stack, we simply set the esp register to point to the top of
	; our stack (as it grows downwards).
	mov esp, stack_top

	; Make sure that we were booted using multiboot 2
	call check_multiboot

	; A multiboot compliant bootloader passes a pointer to a boot information
	; structure in ebx. To be able to pass this to the kernel, we set the edi
	; register: The first six arguments to calling a functions are passed in
	; (64 Bit) registers: rdi, rsi, rdx, rcx, r8, r9
	mov edi, ebx       ; Move Multiboot info pointer to edi

	; Check if CPUID instruction is available
	call check_cpuid

	; Check if long mode is available, using CPUID
	call check_long_mode 

	; Set up page tables
	call set_up_page_tables

	; Set up paging
	call enable_paging

	; Load the 64-bit GDT
	lgdt [gdt64.pointer]

	; Update selectors
	mov ax, gdt64.data
	mov ss, ax  ; stack selector
	mov ds, ax  ; data selector
	mov es, ax  ; extra selector

	; last step towards long mode: long jump to the 64 bit code
	; This is the only way to set up the code selector
	jmp gdt64.code:long_mode_start

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
.hang:
	cli
	hlt
	jmp .hang

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
	mov al, "2"
	jmp error

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


;
; 64 bit part! This is only valid after the incantations in _start
; (checking if paging is available, setting up paging, building 64bit GDT,
; updating segment selectors and longjumping to here.
;
global long_mode_start

section .text
bits 64
long_mode_start:
	; Call kernel_main from kernel.c, which of course must be compiled for x86_64
	extern kernel_main
	call kernel_main

; last resort if kernel_main returns
.hang64:
	cli
	hlt
	jmp .hang64
	
