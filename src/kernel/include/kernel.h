#ifndef _KERNEL_H
#define _KERNEL_H

#if defined(__linux__)
#error "You are not using a cross-compiler, you will most certainly run into trouble"
#endif

#if !defined(__i386__)
#error "Kernel needs to be compiled with a x86-elf compiler"
#endif

#endif
