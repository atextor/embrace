#ifndef _KERNEL_H
#define _KERNEL_H

#if defined(__linux__)
#error "You are not using a cross-compiler, you will most certainly run into trouble"
#endif

#if !defined(__x86_64__)
#error "Kernel needs to be compiled with a x86_64-elf compiler"
#endif

#endif
