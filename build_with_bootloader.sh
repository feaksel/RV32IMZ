#!/bin/bash
# build_with_bootloader.sh - Complete build script for bootloader + application

set -e  # Exit on error

echo "========================================"
echo "RV32IMZ SoC with Bootloader Build System"
echo "Date: $(date)"
echo "========================================"

cd "$(dirname "$0")"

# Step 1: Build bootloader
echo ""
echo "Step 1: Building bootloader..."
cd firmware/bootloader
make clean
make all install
cd ../..

# Step 2: Check if application exists, if not create dummy
echo ""
echo "Step 2: Preparing application..."
if [ ! -f firmware/firmware.hex ]; then
    echo "No application found, creating dummy firmware..."
    
    # Create simple test application
    cat > firmware/test_app.hex << 'EOF'
# Simple test application
93 00 a0 00  # addi x1, x0, 10
13 01 50 00  # addi x2, x0, 5  
63 84 20 00  # beq x1, x2, end
93 08 10 00  # addi x17, x0, 1
73 00 10 00  # ebreak
6f 00 00 00  # j loop
EOF
    cp firmware/test_app.hex firmware/firmware.hex
fi

# Step 3: Update synthesis script to use dual ROM
echo ""  
echo "Step 3: Updating synthesis configuration..."

# Update synthesis script to include dual_rom.v
if ! grep -q "dual_rom.v" synthesize_soc.sh; then
    sed -i 's/read_verilog.*rom_32kb.v/read_verilog -sv rtl\/memory\/dual_rom.v/' synthesize_soc.sh
    echo "Updated synthesize_soc.sh to use dual_rom.v"
fi

# Step 4: Test compile
echo ""
echo "Step 4: Testing synthesis..."
echo "Running syntax check..."

yosys -p "
    read_verilog -sv rtl/memory/dual_rom.v
    read_verilog -sv rtl/soc/soc_simple.v
    read_verilog -sv rtl/core/custom_core_wrapper.v
    read_verilog -sv rtl/core/custom_riscv_core.v
    hierarchy -top soc_simple
    check
" > build_test.log 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Syntax check passed!"
else
    echo "❌ Syntax check failed! Check build_test.log"
    exit 1
fi

echo ""
echo "========================================"
echo "Bootloader integration complete! 🚀"
echo "========================================"
echo ""
echo "What you now have:"
echo "✅ UART Bootloader (16KB at 0x00000000)"
echo "✅ Application Space (16KB at 0x00004000)" 
echo "✅ Dual ROM memory controller"
echo "✅ Updated SoC integration"
echo ""
echo "Memory Layout:"
echo "  0x00000000-0x00003FFF: Bootloader (16KB)"
echo "  0x00004000-0x00007FFF: Your CHB App (16KB)"
echo "  0x00008000-0x00017FFF: RAM (64KB)"
echo ""
echo "Next steps:"
echo "1. Synthesize: ./synthesize_soc.sh"
echo "2. Program FPGA with bootloader"
echo "3. Upload your CHB controller via UART!"
echo ""
echo "Your core is UNCHANGED - just better firmware loading! ✨"