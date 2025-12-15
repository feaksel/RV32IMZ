#!/bin/bash
# Run carrier generator testbench

set -e

echo "========================================"
echo "Carrier Generator Testbench"
echo "========================================"

# Compile
echo "Compiling RTL and testbench..."
iverilog -g2012 -o tb_carrier_generator \
    -I../rtl/peripherals \
    testbench/tb_carrier_generator.v \
    ../rtl/peripherals/carrier_generator.v

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi

echo "Compilation successful!"
echo ""

# Run simulation
echo "Running simulation..."
echo "========================================"
vvp tb_carrier_generator

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "✓ Simulation completed successfully!"
    echo "========================================"
    echo "Waveforms saved to: tb_carrier_generator.vcd"
    echo "View with: gtkwave tb_carrier_generator.vcd"
else
    echo ""
    echo "========================================"
    echo "✗ Simulation failed!"
    echo "========================================"
    exit 1
fi
