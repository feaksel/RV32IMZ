# test_single_char.S
#
# Simplest possible test: Write a single character 'A' (0x41) to UART
# This isolates the UART transmission from any loop complexity

.section .text
.globl _start

# Define peripheral base addresses
.equ UART_BASE, 0x00020500
.equ UART_TX_DATA, UART_BASE

_start:
    # Write a single 'A' character (0x41) to UART
    li t0, 0x41         # Load 'A'
    li t1, UART_TX_DATA # Load UART TX address
    sw t0, 0(t1)        # Write to UART

    # Wait a long time for transmission to complete
    li t2, 1000000      # Big delay counter
delay:
    addi t2, t2, -1
    bnez t2, delay

hang:
    j hang
