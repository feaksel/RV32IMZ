#!/bin/bash
# Run single character UART test

set -e

echo "========================================"
echo "Single Character UART Test"
echo "========================================"

# Copy the single char firmware hex to the default location
echo "Step 1: Copying firmware..."
cp firmware/firmware_single.hex firmware/firmware.hex

# Compile RTL
echo "Step 2: Compiling RTL..."
iverilog -g2012 -o tb_single_char -DSIMULATION \
    -I../rtl \
    -I../rtl/core \
    -I../rtl/bus \
    -I../rtl/peripherals \
    -I../rtl/soc \
    testbench/tb_single_char.v \
    ../rtl/core/*.v \
    ../rtl/bus/*.v \
    ../rtl/peripherals/*.v \
    ../rtl/soc/*.v

# Run simulation
echo "Step 3: Running simulation..."
echo "========================================"
vvp tb_single_char

echo "========================================"
echo "Waveforms saved to: tb_single_char.vcd"
echo "View with: gtkwave tb_single_char.vcd"
