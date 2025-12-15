#!/bin/bash
echo "Checking for MDU integration with timeout reduced for testing..."
cd riscv-tests/testbenches 
timeout 5 iverilog -o tb_mul tb_compliance_rv32um_p_mul.v -I ../../rtl/core -I ../../rtl/bus -I ../../rtl/memory -I ../../rtl/soc -I ../../rtl/peripherals ../../rtl/core/*.v ../../rtl/peripherals/*.v ../../rtl/memory/*.v ../../rtl/bus/*.v && echo "Compilation successful" 
if [ $? -eq 0 ]; then
    echo "Running with 10 second timeout..."
    timeout 10 ./tb_mul && echo "Test finished normally" || echo "Test timed out or failed"
else
    echo "Compilation failed"
fi