/* startup.S - Application startup code for bootloader-loaded programs */

.section .text.start, "ax"
.global _app_start

_app_start:
    # Set stack pointer
    la sp, _stack_top

    # Set global pointer for relaxed addressing
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    # Initialize .data section (copy from flash to RAM)
    la a0, _data_load     # Source address in flash
    la a1, _data_start    # Destination address in RAM
    la a2, _data_end      # End of data section

.L_copy_data:
    beq a1, a2, .L_data_done
    lw t0, 0(a0)
    sw t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j .L_copy_data

.L_data_done:
    # Zero .bss section
    la a0, _bss_start
    la a1, _bss_end

.L_zero_bss:
    beq a0, a1, .L_bss_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j .L_zero_bss

.L_bss_done:
    # Call main function
    call main

    # If main returns, halt (should not happen in embedded system)
.L_halt:
    wfi
    j .L_halt

# Weak default handlers for interrupts (can be overridden)
.weak _interrupt_handler
.weak _exception_handler

_interrupt_handler:
_exception_handler:
    # Default: just return
    mret