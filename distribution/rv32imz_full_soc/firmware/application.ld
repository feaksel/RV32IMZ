/* application.ld - Linker script for applications (loaded by bootloader) */

OUTPUT_ARCH("riscv")
ENTRY(_app_start)

MEMORY
{
    /* Application space starts after bootloader */
    FLASH (rx)  : ORIGIN = 0x00004000, LENGTH = 48K   /* After 16KB bootloader */
    RAM (rwx)   : ORIGIN = 0x00010000, LENGTH = 60K   /* Main RAM (4KB reserved for stack) */
}

SECTIONS
{
    /* Application entry point */
    .text : {
        KEEP(*(.text.start))     /* Application startup code */
        *(.text*)
        *(.rodata*)
        *(.srodata*)
        
        /* Ensure word alignment */
        . = ALIGN(4);
        _etext = .;
        
        /* Global pointer for relaxed addressing */
        __global_pointer$ = . + 0x800;
    } > FLASH

    /* Read-write data (copied from flash to RAM at startup) */
    .data : {
        . = ALIGN(4);
        _data_start = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM AT > FLASH

    /* Location of data in flash (for copying) */
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

    /* Heap (optional, grows upward) */
    .heap : {
        . = ALIGN(4);
        _heap_start = .;
        /* Heap grows upward until it hits stack */
    } > RAM

    /* Stack (grows downward from top of RAM) */
    .stack : {
        . = ALIGN(16);
        . = ORIGIN(RAM) + LENGTH(RAM) - 4K;  /* Reserve 4KB for stack */
        _stack_start = .;
        . = . + 4K;
        _stack_top = .;
    } > RAM

    /* End of allocated memory */
    _end = .;
    _heap_end = _stack_start;

    /* Debugging sections (not loaded) */
    .comment 0 : { *(.comment) }
    .debug_info 0 : { *(.debug_info) }
    .debug_abbrev 0 : { *(.debug_abbrev) }
    .debug_line 0 : { *(.debug_line) }
    .debug_frame 0 : { *(.debug_frame) }
    .debug_str 0 : { *(.debug_str) }
    .debug_loc 0 : { *(.debug_loc) }
    .debug_macinfo 0 : { *(.debug_macinfo) }
    .debug_pubnames 0 : { *(.debug_pubnames) }
    .debug_pubtypes 0 : { *(.debug_pubtypes) }
    .debug_ranges 0 : { *(.debug_ranges) }

    /* Discard sections */
    /DISCARD/ : {
        *(.note.GNU-stack)
        *(.gnu_debuglink)
        *(.gnu.lto_*)
    }
}

/* Provide symbols for C runtime */
PROVIDE(_heap_size = _heap_end - _heap_start);
PROVIDE(_stack_size = _stack_top - _stack_start);