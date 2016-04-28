TARGET=i686-elf
TOOLCHAIN=$(TARGET)-4.9.1-Linux-x86_64
CC=$(TOOLCHAIN)/bin/$(TARGET)-gcc
ASSEMBLER=nasm -felf32

CCFLAGS=-Isrc/include -std=gnu99 -ffreestanding -O2 -Wall -Wextra 

GRUBCONFIG=boot/grub.cfg
KERNEL=kernel.bin
BOOTLOADER_HEADER=multiboot_header.o
BOOT=boot.o

ISO=embrace.iso

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

$(KERNEL): $(BOOTLOADER_HEADER) $(BOOT) src/linker.ld kernel.o toolchain_installed
	$(CC) -T src/linker.ld -o $(KERNEL) -ffreestanding -O2 -nostdlib $(BOOTLOADER_HEADER) $(BOOT) kernel.o -lgcc

$(ISO): $(GRUBCONFIG) $(KERNEL)
	rm -rf iso/
	mkdir -p iso/boot/grub
	cp $(GRUBCONFIG) iso/boot/grub
	cp $(KERNEL) iso/boot
	grub-mkrescue -o $(ISO) iso
	rm -rf iso 

run: $(ISO)
	qemu-system-x86_64 -cdrom $(ISO)

clean:
	rm -f $(BOOTLOADER_HEADER) $(BOOT) $(KERNEL) $(ISO)
