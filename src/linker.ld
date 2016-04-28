ENTRY(_start)

SECTIONS {
	. = 1M;

	.boot :
	{
		/* ensure that the multiboot header is at the beginning */
		*(.multiboot_header)
	}


	/* Read-only data. */
	.rodata BLOCK(4K) : ALIGN(4K)
	{
		*(.rodata)
	}

	/* Read-write data (initialized) */
	.data BLOCK(4K) : ALIGN(4K)
	{
		*(.data)
	}

	/* Read-write data (uninitialized) and stack */
	.bss BLOCK(4K) : ALIGN(4K)
	{
		*(COMMON)
		*(.bss)
		*(.bootstrap_stack)
	}

	.text :
	{
		*(.text)
	}
}
