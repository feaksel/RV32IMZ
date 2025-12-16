# test_soc.S
#
# A simple SoC test program that:
# 1. Writes "Hello World!" to the UART.
# 2. Enters an infinite loop.
#
# This verifies that the CPU can fetch instructions from ROM and
# write to a peripheral (UART) across the Wishbone bus.

.section .text
.globl _start

# Define peripheral base addresses from the memory map
.equ UART_BASE, 0x80000000
.equ UART_TX_DATA, UART_BASE
.equ UART_STATUS, UART_BASE + 4
.equ TX_EMPTY_BIT, 0x02  # Bit 1 of STATUS register

_start:
    # --- Test UART Output ---
    la s0, hello_string # Load address of the string into s0
    mv s1, s0           # s1 will be our pointer

loop:
    lb t0, 0(s1)        # Load a byte (character) from the string
    beq t0, zero, end_loop # If it's the null terminator, exit loop

wait_tx_empty:
    # Poll UART STATUS register until TX_EMPTY is set
    li t1, UART_STATUS  # Load UART STATUS register address
    lw t2, 0(t1)        # Read status
    andi t2, t2, TX_EMPTY_BIT  # Check TX_EMPTY bit (bit 1)
    beqz t2, wait_tx_empty # If not empty, keep waiting

    # Add delay to ensure idle period between characters
    # This ensures testbench can detect the start bit edge
    li t3, 2000         # Longer delay for proper synchronization
inter_char_delay:
    addi t3, t3, -1
    bnez t3, inter_char_delay

    # Write the character to the UART TX data register
    li t1, UART_TX_DATA # Load UART TX data register address
    sw t0, 0(t1)        # Write character to UART

    addi s1, s1, 1      # Move to the next character
    j loop

end_loop:
    # Infinite loop to end the program
hang:
    j hang

.section .rodata
hello_string:
    .string "Hello World!\n"
