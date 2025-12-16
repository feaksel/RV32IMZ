/**
 * @file linker.ld
 * @brief Linker script for bare-metal RISC-V programs
 *
 * Maps program to start at address 0x00000000
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 1K
}

SECTIONS {
    .text : {
        *(.text._start)
        *(.text*)
    } > RAM

    .rodata : {
        *(.rodata*)
    } > RAM

    .data : {
        *(.data*)
    } > RAM

    .bss : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    /* End of allocated memory */
    _end = .;

    /* Stack pointer initialization */
    . = ALIGN(16);
    . = . + 1024; /* 1K stack */
    __stack_top = .;
}
