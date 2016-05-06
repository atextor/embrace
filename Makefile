#
# Settings
#
TARGET=x86_64-elf
TOOLCHAIN=$(TARGET)-4.9.1-Linux-x86_64
CC=$(TOOLCHAIN)/bin/$(TARGET)-gcc
LD=$(TOOLCHAIN)/bin/$(TARGET)-ld
ASSEMBLER=nasm -felf64

# The debug symbols introduced with -g are split out into the
# separate file kernel.sym below
CCFLAGS=-g -Isrc/kernel/include -Isrc/libc/include -std=gnu99 -ffreestanding -O2 -Wall -Wextra

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

BOOT=boot.o

ISO=$(SYS_NAME).iso

default: $(ISO)

#
# Toolchain & Build requirements
#
$(TOOLCHAIN).tar.xz:
	wget http://newos.org/toolchains/$(TOOLCHAIN).tar.xz

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

#
# Kernel components
#
kernelobj := $(patsubst src/kernel/%.c,bin/kernel/%.o,$(wildcard src/kernel/*.c))

$(BOOT): src/boot.asm requirements
	$(ASSEMBLER) src/boot.asm -o $(BOOT)

bin/kernel/%.o: src/kernel/%.c requirements
	@mkdir -p bin/kernel
	$(CC) -c $< -o $@ $(CCFLAGS)

#
# libc
#
libcobj := $(patsubst src/libc/%.c,bin/libc/%.o,$(wildcard src/libc/*.c))

bin/libc/%.o: src/libc/%.c requirements
	@mkdir -p bin/libc
	$(CC) -c $< -o $@ $(CCFLAGS)

#
# Kernel & Images
# 
allobjects := $(kernelobj) $(libcobj)

$(KERNEL_BIG): $(BOOT) src/linker.ld $(allobjects) requirements
	$(LD) -n -o $(KERNEL_BIG) -T src/linker.ld $(BOOT) $(allobjects)

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
	@/bin/echo -en "#!/bin/sh\nxorriso $$""* -V $(VOLID)"  > boot/xorriso.sh
	@chmod a+x boot/xorriso.sh
	grub-mkrescue --xorriso="./boot/xorriso.sh" -o $(ISO) iso

# -s means: Open GDB server on TCP port 1234
# -S means: Don't start CPU at startup
run: $(ISO)
	qemu-system-x86_64 -d int -s -cdrom $(ISO) &
	#gdb

clean:
	rm -rf $(BOOT) $(KERNEL) $(KERNEL_BIG) $(KERNEL_SYM) $(ISO) bin/ boot/xorriso.sh iso/
