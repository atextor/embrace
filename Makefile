TARGET=i686-elf
TOOLCHAIN=$(TARGET)-4.9.1-Linux-x86_64
CC=$(TOOLCHAIN)/bin/$(TARGET)-gcc
ASSEMBLER=nasm -felf32

# The debug symbols introduced with -g are split out into the
# separate file kernel.sym below
CCFLAGS=-g -Isrc/include -std=gnu99 -ffreestanding -O2 -Wall -Wextra

# Configuration for cd image
GRUBCONFIG=boot/grub.cfg
SYS_NAME=embrace
VOLID:=`echo $(SYS_NAME) | tr '[:lower:]' '[:upper:]'`

# The kernel including debugging symbols
KERNEL_BIG=kernel.elf
# The kernel without debugging symbols that goes into the disk image
KERNEL=kernel.bin
# The kernel debugging symbols that can be used in conjunction with
# the stripped kernel binary
KERNEL_SYM=kernel.sym

BOOTLOADER_HEADER=multiboot_header.o
BOOT=boot.o

ISO=$(SYS_NAME).iso

default: $(KERNEL)

$(TOOLCHAIN).tar.xz:
	wget http://newos.org/toolchains/i686-elf-4.9.1-Linux-x86_64.tar.xz

$(TOOLCHAIN): $(TOOLCHAIN).tar.xz
	tar xf $(TOOLCHAIN).tar.xz
	rm -f $(TOOLCHAIN).tar.xz

.PHONY: install_toolchain
install_toolchain: $(TOOLCHAIN)

.PHONY: toolchain_installed
toolchain_installed:
	@test -e $(CC) > /dev/null || echo -e "\nNo toolchain installed. Run 'make install_toolchain'.\n"
	@test -e $(CC)

$(BOOTLOADER_HEADER): src/multiboot_header.asm
	$(ASSEMBLER) src/multiboot_header.asm -o $(BOOTLOADER_HEADER)

$(BOOT): src/boot.asm
	$(ASSEMBLER) src/boot.asm -o $(BOOT)

%.o: src/%.c
	$(CC) -c $< -o $@ $(CCFLAGS)

$(KERNEL_BIG): $(BOOTLOADER_HEADER) $(BOOT) src/linker.ld kernel.o toolchain_installed
	$(CC) -T src/linker.ld -o $(KERNEL_BIG) -ffreestanding -O2 -nostdlib $(BOOTLOADER_HEADER) $(BOOT) kernel.o -lgcc

# From the full kernel, extract debug symbols
$(KERNEL_SYM): $(KERNEL_BIG)
	objcopy --only-keep-debug $(KERNEL_BIG) $(KERNEL_SYM)

# From the full kernel, remove debug symbols
$(KERNEL): $(KERNEL_BIG) $(KERNEL_SYM)
	objcopy --strip-debug $(KERNEL_BIG) $(KERNEL)

$(ISO): $(GRUBCONFIG) $(KERNEL)
	rm -rf iso/
	mkdir -p iso/boot/grub
	cp $(GRUBCONFIG) iso/boot/grub
	cp $(KERNEL) iso/boot
	echo -en "#!/bin/sh\nxorriso $$""* -V $(VOLID)"  > xorriso.sh
	chmod a+x xorriso.sh
	grub-mkrescue --xorriso="./xorriso.sh" -o $(ISO) iso &>/dev/null
	rm -f ./xorriso.sh
	rm -rf iso 

# -s means: Open GDB server on TCP port 1234
# -S means: Don't start CPU at startup
run: $(ISO)
	qemu-system-x86_64 -s -S -cdrom $(ISO) &
	gdb

clean:
	rm -f $(BOOTLOADER_HEADER) $(BOOT) $(KERNEL) $(KERNEL_BIG) $(KERNEL_SYM) $(ISO)
