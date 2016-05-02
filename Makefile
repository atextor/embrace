TARGET=i686-elf
TOOLCHAIN=$(TARGET)-4.9.1-Linux-x86_64
CC=$(TOOLCHAIN)/bin/$(TARGET)-gcc
ASSEMBLER=nasm -felf32

# The debug symbols introduced with -g are split out into the
# separate file kernel.sym below
CCFLAGS=-g -Isrc/kernel/include -std=gnu99 -ffreestanding -O2 -Wall -Wextra

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

default: $(ISO)

$(TOOLCHAIN).tar.xz:
	wget http://newos.org/toolchains/i686-elf-4.9.1-Linux-x86_64.tar.xz

$(TOOLCHAIN): $(TOOLCHAIN).tar.xz
	tar xf $(TOOLCHAIN).tar.xz
	rm -f $(TOOLCHAIN).tar.xz

.PHONY: requirements
requirements:
	@which qemu-system-x86_64 > /dev/null || (echo "qemu-system-x86_64 not found." && exit 1)
	@which nasm > /dev/null || (echo "nasm not found." && exit 1)
	@which tar > /dev/null || (echo "tar not found." && exit 1)
	@which grub-mkrescue > /dev/null || (echo "grub-mkrescue not found." && exit 1)
	@which gdb > /dev/null || (echo "gdb not found." && exit 1)
	@which xorriso > /dev/null || (echo "xorriso not found." && exit 1)
	@test -e $(CC) || (echo -e "\nNo toolchain installed. Run 'make install_toolchain'.\n" && exit 1)

.PHONY: install_toolchain
install_toolchain: $(TOOLCHAIN)

$(BOOTLOADER_HEADER): src/multiboot_header.asm
	$(ASSEMBLER) src/multiboot_header.asm -o $(BOOTLOADER_HEADER)

$(BOOT): src/boot.asm requirements
	$(ASSEMBLER) src/boot.asm -o $(BOOT)

%.o: src/kernel/%.c requirements
	$(CC) -c $< -o $@ $(CCFLAGS)

$(KERNEL_BIG): $(BOOTLOADER_HEADER) $(BOOT) src/linker.ld kernel.o vga.o tty.o requirements
	$(CC) -T src/linker.ld -o $(KERNEL_BIG) -ffreestanding -O2 -nostdlib $(BOOTLOADER_HEADER) $(BOOT) kernel.o vga.o tty.o -lgcc

# From the full kernel, extract debug symbols
$(KERNEL_SYM): $(KERNEL_BIG)
	objcopy --only-keep-debug $(KERNEL_BIG) $(KERNEL_SYM)

# From the full kernel, remove debug symbols
$(KERNEL): $(KERNEL_BIG) $(KERNEL_SYM)
	objcopy --strip-debug $(KERNEL_BIG) $(KERNEL)

$(ISO): $(GRUBCONFIG) $(KERNEL) requirements
	rm -rf iso/
	mkdir -p iso/boot/grub
	cp $(GRUBCONFIG) iso/boot/grub
	cp $(KERNEL) iso/boot
	/bin/echo -en "#!/bin/sh\nxorriso $$""* -V $(VOLID)"  > boot/xorriso.sh
	chmod a+x boot/xorriso.sh
	grub-mkrescue --xorriso="./boot/xorriso.sh" -o $(ISO) iso

# -s means: Open GDB server on TCP port 1234
# -S means: Don't start CPU at startup
run: $(ISO)
	qemu-system-x86_64 -s -S -cdrom $(ISO) &
	gdb

clean:
	rm -rf $(BOOTLOADER_HEADER) $(BOOT) $(KERNEL) $(KERNEL_BIG) $(KERNEL_SYM) $(ISO) *.o boot/xorriso.sh iso/
