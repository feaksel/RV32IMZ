# startup.S
#
# Initializes the stack and calls the main C function.

.section .text
.globl _start

_start:
    # Initialize stack pointer
    # The stack grows downwards. We'll place it at the top of memory.
    # The linker script will define __stack_top.
    la sp, __stack_top

    # Call the main function of the C program
    call main

# If main returns, hang here
hang:
    j hang
