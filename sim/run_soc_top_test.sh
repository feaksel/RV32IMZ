#!/bin/bash
#
# run_soc_top_test.sh
#
# Build and run the SoC top testbench
#
# This script:
# 1. Compiles the test_soc firmware to firmware.hex
# 2. Compiles all RTL modules for the SoC
# 3. Runs the tb_soc_top testbench
# 4. Reports PASS/FAIL

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RISCV_ROOT="$(dirname "$SCRIPT_DIR")"
RTL_DIR="$RISCV_ROOT/rtl"
FIRMWARE_DIR="$RISCV_ROOT/firmware/test_soc"
TB_DIR="$SCRIPT_DIR/testbench"
BUILD_DIR="$SCRIPT_DIR/build"
FIRMWARE_OUT_DIR="$SCRIPT_DIR/firmware"

# Output files
VVP_OUT="$BUILD_DIR/tb_soc_top.vvp"
VCD_OUT="$SCRIPT_DIR/tb_soc_top.vcd"
FIRMWARE_HEX="$FIRMWARE_OUT_DIR/firmware.hex"
FIRMWARE_ELF="$BUILD_DIR/test_soc.elf"

# RISC-V toolchain
RISCV_PREFIX="${RISCV_PREFIX:-riscv32-unknown-elf}"
RISCV_CC="${RISCV_PREFIX}-gcc"
RISCV_OBJCOPY="${RISCV_PREFIX}-objcopy"
RISCV_OBJDUMP="${RISCV_PREFIX}-objdump"

# Create necessary directories
mkdir -p "$BUILD_DIR"
mkdir -p "$FIRMWARE_OUT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SoC Top Testbench Build and Run${NC}"
echo -e "${BLUE}========================================${NC}"

# Step 1: Compile firmware
echo -e "${YELLOW}Step 1: Compiling test_soc firmware...${NC}"

# Check if RISC-V toolchain is available
if ! command -v "$RISCV_CC" &> /dev/null; then
    echo -e "${RED}ERROR: RISC-V toolchain not found!${NC}"
    echo -e "${RED}Please install riscv32-unknown-elf-gcc or set RISCV_PREFIX${NC}"
    exit 1
fi

# Compile the assembly file
$RISCV_CC -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
    -Wl,-Ttext=0x00000000 \
    -o "$FIRMWARE_ELF" \
    "$FIRMWARE_DIR/test_soc.S"

# Generate binary file first
$RISCV_OBJCOPY -O binary "$FIRMWARE_ELF" "$BUILD_DIR/test_soc.bin"

# Convert binary to 32-bit word hex format for Verilog $readmemh
chmod +x "$SCRIPT_DIR/bin2hex.py"
python3 "$SCRIPT_DIR/bin2hex.py" "$BUILD_DIR/test_soc.bin" "$FIRMWARE_HEX"

# Generate disassembly for reference
$RISCV_OBJDUMP -d "$FIRMWARE_ELF" > "$BUILD_DIR/test_soc.dis"

echo -e "${GREEN}Firmware compiled successfully!${NC}"
echo -e "  ELF: $FIRMWARE_ELF"
echo -e "  HEX: $FIRMWARE_HEX"
echo -e "  DIS: $BUILD_DIR/test_soc.dis"

# Step 2: Compile RTL
echo -e "\n${YELLOW}Step 2: Compiling RTL modules...${NC}"

# Collect all Verilog files
RTL_FILES=(
    # Core CPU files
    "$RTL_DIR/core/alu.v"
    "$RTL_DIR/core/regfile.v"
    "$RTL_DIR/core/decoder.v"
    "$RTL_DIR/core/mdu.v"
    "$RTL_DIR/core/csr_unit.v"
    "$RTL_DIR/core/interrupt_controller.v"
    "$RTL_DIR/core/exception_unit.v"
    "$RTL_DIR/core/custom_riscv_core.v"
    "$RTL_DIR/core/custom_core_wrapper.v"

    # Wishbone/Bus components
    "$RTL_DIR/bus/wishbone_arbiter_2x1.v"
    "$RTL_DIR/bus/wishbone_interconnect.v"

    # Peripherals
    "$RTL_DIR/peripherals/carrier_generator.v"
    "$RTL_DIR/peripherals/sine_generator.v"
    "$RTL_DIR/peripherals/pwm_comparator.v"
    "$RTL_DIR/peripherals/pwm_accelerator.v"
    "$RTL_DIR/peripherals/sigma_delta_adc.v"
    "$RTL_DIR/peripherals/protection.v"
    "$RTL_DIR/peripherals/timer.v"
    "$RTL_DIR/peripherals/gpio.v"
    "$RTL_DIR/peripherals/uart.v"

    # SoC top
    "$RTL_DIR/soc/soc_top.v"

    # Testbench
    "$TB_DIR/tb_soc_top.v"
)

# Check if all files exist
missing_files=0
for file in "${RTL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}ERROR: File not found: $file${NC}"
        missing_files=$((missing_files + 1))
    fi
done

if [ $missing_files -gt 0 ]; then
    echo -e "${RED}ERROR: $missing_files RTL files are missing!${NC}"
    exit 1
fi

# Compile with iverilog
iverilog -g2012 -Wall \
    -DSIMULATION \
    -I"$RTL_DIR/core" \
    -o "$VVP_OUT" \
    "${RTL_FILES[@]}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}RTL compilation successful!${NC}"
else
    echo -e "${RED}RTL compilation failed!${NC}"
    exit 1
fi

# Step 3: Run simulation
echo -e "\n${YELLOW}Step 3: Running simulation...${NC}"
echo -e "${BLUE}========================================${NC}"

# Change to sim directory so firmware path is correct
cd "$SCRIPT_DIR"

# Run the simulation
vvp "$VVP_OUT" | tee "$BUILD_DIR/simulation.log"

# Check the result
if grep -q "^PASS:" "$BUILD_DIR/simulation.log"; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}✓ TESTBENCH PASSED!${NC}"
    echo -e "${BLUE}========================================${NC}"

    if [ -f "$VCD_OUT" ]; then
        echo -e "Waveforms saved to: $VCD_OUT"
        echo -e "View with: gtkwave $VCD_OUT"
    fi

    exit 0
else
    echo -e "${BLUE}========================================${NC}"
    echo -e "${RED}✗ TESTBENCH FAILED!${NC}"
    echo -e "${BLUE}========================================${NC}"

    if [ -f "$VCD_OUT" ]; then
        echo -e "Waveforms saved to: $VCD_OUT"
        echo -e "View with: gtkwave $VCD_OUT"
    fi

    exit 1
fi
