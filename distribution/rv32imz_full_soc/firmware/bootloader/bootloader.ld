/* bootloader.ld - Linker script for bootloader */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    /* Bootloader ROM space */
    ROM (rx)   : ORIGIN = 0x00000000, LENGTH = 16K
    /* Use RAM for variables */
    RAM (rwx)  : ORIGIN = 0x00008000, LENGTH = 8K   /* Use first 8KB of RAM */
}

SECTIONS
{
    /* Bootloader code starts at reset vector */
    .text : {
        KEEP(*(.text.start))     /* Startup code first */
        *(.text*)
        *(.rodata*)
        *(.srodata*)
        
        /* Ensure word alignment */
        . = ALIGN(4);
        _etext = .;
        
        /* Global pointer for relaxed addressing */
        __global_pointer$ = . + 0x800;
    } > ROM

    /* Read-write data (copied from ROM to RAM at startup) */
    .data : {
        . = ALIGN(4);
        _data_start = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM AT > ROM

    /* Location of data in ROM (for copying) */
    _data_load = LOADADDR(.data);

    /* Zero-initialized data */
    .bss : {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    /* Stack grows downward from end of RAM section */
    .stack : {
        . = ALIGN(16);
        . = ORIGIN(RAM) + LENGTH(RAM) - 1K;  /* Reserve 1KB for stack */
        _stack_start = .;
        . = . + 1K;
        _stack_top = .;
    } > RAM

    /* End of allocated memory */
    _end = .;

    /* Debugging sections */
    .comment 0 : { *(.comment) }
    .debug_info 0 : { *(.debug_info) }
    .debug_abbrev 0 : { *(.debug_abbrev) }
    .debug_line 0 : { *(.debug_line) }
    .debug_frame 0 : { *(.debug_frame) }
    .debug_str 0 : { *(.debug_str) }
}

/* Provide symbols for runtime */
PROVIDE(_heap_start = _bss_end);
PROVIDE(_heap_end = _stack_start);