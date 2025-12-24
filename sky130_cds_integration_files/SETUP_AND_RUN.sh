#!/bin/bash
#===============================================================================
# Quick Setup and Run Script for RV32IM Integration
# Verifies files are in place and runs integration P&R
#===============================================================================

set -e  # Exit on error

echo "========================================="
echo "RV32IM Integration Setup Verification"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Function to check file existence
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1 ${RED}(MISSING)${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
        return 0
    else
        echo -e "${RED}✗${NC} $1/ ${RED}(MISSING)${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "1. Checking synthesis outputs..."
echo "=================================="
check_file "../synth/outputs/rv32im_integrated/rv32im_integrated_macro.vh"
check_file "../synth/outputs/rv32im_integrated/rv32im_integrated_macro.sdc"
echo ""

echo "2. Checking core_macro files..."
echo "=================================="
check_dir "../pnr/outputs/core_macro"
check_file "../pnr/outputs/core_macro/core_macro.lef"
check_file "../pnr/outputs/core_macro/core_macro_netlist.v"
check_file "../pnr/outputs/core_macro/core_macro.sdc"
check_file "../pnr/outputs/core_macro/core_macro.gds"
echo ""

echo "3. Checking mdu_macro files..."
echo "=================================="
check_dir "../pnr/outputs/mdu_macro"
check_file "../pnr/outputs/mdu_macro/mdu_macro.lef"
check_file "../pnr/outputs/mdu_macro/mdu_macro_netlist.v"
check_file "../pnr/outputs/mdu_macro/mdu_macro.sdc"
check_file "../pnr/outputs/mdu_macro/mdu_macro.gds"
echo ""

echo "4. Checking library files..."
echo "=================================="
check_file "../sky130_osu_sc_t18/sky130_osu_sc_18T.tlef"
check_file "../sky130_osu_sc_t18/18T_ms/lef/sky130_osu_sc_18T_ms.lef"
check_file "../sky130_osu_sc_t18/18T_ms/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib" || \
check_file "../sky130_osu_sc_t18/18T_ms/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.lib"
echo ""

echo "5. Checking P&R scripts..."
echo "=================================="
check_file "pnr/SCRIPTS/setup_rv32im.tcl"
check_file "pnr/SCRIPTS/init_rv32im.tcl"
echo ""

echo "========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo "========================================="
    echo ""
    echo "Ready to run integration P&R!"
    echo ""
    echo "Options:"
    echo "  1. Run full P&R flow:"
    echo "     cd pnr && make -f Makefile.rv32im all"
    echo ""
    echo "  2. Run step-by-step:"
    echo "     cd pnr"
    echo "     make -f Makefile.rv32im init    # Floorplan + macro placement"
    echo "     make -f Makefile.rv32im place   # Place standard cells"
    echo "     make -f Makefile.rv32im cts     # Clock tree"
    echo "     make -f Makefile.rv32im route   # Routing"
    echo "     make -f Makefile.rv32im signoff # GDS generation"
    echo ""
    echo "  3. Interactive mode:"
    echo "     cd pnr"
    echo "     innovus -init SCRIPTS/init_rv32im.tcl"
    echo ""

    read -p "Run integration P&R now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Starting integration P&R..."
        cd pnr
        make -f Makefile.rv32im all
    fi
else
    echo -e "${RED}Found $ERRORS missing files!${NC}"
    echo "========================================="
    echo ""
    echo "Please ensure all files are in place before running integration."
    echo ""
    echo "If synthesis isn't done:"
    echo "  cd synth && genus -batch -files genus_script_rv32im.tcl"
    echo ""
    echo "If leaf macros aren't built:"
    echo "  Build each macro using sky130_cds method"
    echo "  Then copy LEF/netlist/GDS/SDC to pnr/outputs/<macro_name>/"
    exit 1
fi
