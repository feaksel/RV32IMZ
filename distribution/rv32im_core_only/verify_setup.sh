#!/bin/bash
#===============================================================================
# PDK and Setup Verification Script
# Checks if all required files are in place before running synthesis
#===============================================================================

echo "Verifying ASIC Flow Setup..."
echo "==============================="

cd /home/furka/RV32IMZ/distribution/rv32im_core_only

ERRORS=0

# Check RTL files
echo "Checking RTL files..."
if [ -f "rtl/custom_riscv_core.v" ]; then
    echo "✓ RTL top-level found"
else
    echo "✗ Missing RTL top-level: rtl/custom_riscv_core.v"
    ERRORS=$((ERRORS + 1))
fi

# Check PDK library files
echo ""
echo "Checking PDK library files..."
PDK_LIBS=(
    "pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib"
    "pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
    "pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_100C_1v95.lib"
)

for lib in "${PDK_LIBS[@]}"; do
    if [ -f "$lib" ]; then
        echo "✓ $(basename $lib)"
    else
        echo "✗ Missing: $lib"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check LEF files
echo ""
echo "Checking LEF files..."
PDK_LEFS=(
    "pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd__tech.lef"
    "pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
)

for lef in "${PDK_LEFS[@]}"; do
    if [ -f "$lef" ]; then
        echo "✓ $(basename $lef)"
    else
        echo "✗ Missing: $lef"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check constraint file
echo ""
echo "Checking constraint files..."
if [ -f "constraints/basic_timing.sdc" ]; then
    echo "✓ basic_timing.sdc"
else
    echo "✗ Missing: constraints/basic_timing.sdc"
    ERRORS=$((ERRORS + 1))
fi

# Check GDS map file
echo ""
echo "Checking GDS support files..."
if [ -f "pdk/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.map" ]; then
    echo "✓ GDS map file"
else
    echo "✗ Missing: pdk/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.map"
    ERRORS=$((ERRORS + 1))
fi

# Check synthesis scripts
echo ""
echo "Checking synthesis scripts..."
SCRIPTS=(
    "synthesis_cadence/synthesis.tcl"
    "synthesis_cadence/place_route.tcl"
    "synthesis_cadence/mmmc.tcl"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "✓ $(basename $script)"
    else
        echo "✗ Missing: $script"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check if directories exist
echo ""
echo "Checking directory structure..."
DIRS=(
    "synthesis_cadence"
    "rtl"
    "pdk/sky130A/libs.ref/sky130_fd_sc_hd"
    "constraints"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✓ $dir/"
    else
        echo "✗ Missing directory: $dir/"
        ERRORS=$((ERRORS + 1))
    fi
done

# Summary
echo ""
echo "==============================="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All checks passed! Ready to run synthesis."
    echo ""
    echo "To run complete flow:"
    echo "  ./run_complete_flow.sh"
    echo ""
    echo "To run individual steps:"
    echo "  cd synthesis_cadence"
    echo "  genus -f synthesis.tcl"
    echo "  innovus -f place_route.tcl"
else
    echo "✗ Found $ERRORS error(s). Please fix before running synthesis."
    echo ""
    echo "Common fixes:"
    echo "1. Copy PDK files from main project:"
    echo "   cp -r ../../../pdk/sky130A/libs.ref/sky130_fd_sc_hd/* pdk/sky130A/libs.ref/sky130_fd_sc_hd/"
    echo ""
    echo "2. If main PDK missing, copy from rv32imz_full_soc:"
    echo "   cp -r ../rv32imz_full_soc/pdk/* pdk/"
fi
echo "==============================="