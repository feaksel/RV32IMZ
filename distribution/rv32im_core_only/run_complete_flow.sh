#!/bin/bash
#===============================================================================
# Complete ASIC Flow for RV32IM Core
# Synthesis → Place & Route → GDS Generation
#===============================================================================

set -e  # Exit on any error

echo "================================================================================"
echo "Complete ASIC Flow for RV32IM Core Only"
echo "Date: $(date)"
echo "Using Full Sky130 PDK (1.1GB)"
echo "================================================================================"

# Change to synthesis directory (relative path)
cd synthesis_cadence

# Check if PDK files exist
echo "==> Verifying PDK files..."
if [ ! -f "../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib" ]; then
    echo "ERROR: Missing PDK library files!"
    echo "Please ensure all Sky130 library files are present in ../pdk/"
    echo "Expected: Full Sky130 PDK (13MB+ .lib files, 1.4MB .lef files)"
    exit 1
fi

# Check PDK file size to ensure it's not a stub
LIB_SIZE=$(stat -f%z "../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib" 2>/dev/null || stat -c%s "../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib" 2>/dev/null)
if [ "$LIB_SIZE" -lt 1000000 ]; then
    echo "ERROR: PDK library file is too small (${LIB_SIZE} bytes)"
    echo "This appears to be a stub file. Please install the full Sky130 PDK."
    echo "Run: volare enable --pdk sky130 <version>"
    exit 1
fi

echo "==> PDK files verified (Full PDK: ${LIB_SIZE} bytes)"

# Clean previous run
echo "==> Cleaning previous run..."
rm -rf outputs/ reports/ logs/ genus.log* innovus.log* *.log.* 2>/dev/null || true

# Create output directories
mkdir -p outputs reports logs

echo
echo "================================================================================"
echo "Step 1: Logic Synthesis with Genus"
echo "================================================================================"

# Run synthesis
genus -f synthesis.tcl -log logs/synthesis.log 2>&1 | tee logs/synthesis_run.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "==> Synthesis completed successfully"

    # Check if netlist was generated
    if [ -f "outputs/core_netlist.v" ]; then
        NETLIST_SIZE=$(wc -l < outputs/core_netlist.v)
        echo "==> Netlist generated: outputs/core_netlist.v (${NETLIST_SIZE} lines)"
    else
        echo "ERROR: Netlist not found!"
        echo "Check logs/synthesis.log for errors"
        exit 1
    fi
else
    echo "ERROR: Synthesis failed!"
    echo "Check logs/synthesis.log and logs/synthesis_run.log for details"
    exit 1
fi

echo
echo "================================================================================"
echo "Step 2: Place & Route with Innovus"
echo "================================================================================"

# Run place and route
innovus -f place_route.tcl -log logs/place_route.log 2>&1 | tee logs/place_route_run.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "==> Place & Route completed successfully"

    # Check if GDS was generated
    if [ -f "outputs/custom_riscv_core_final.gds" ]; then
        GDS_SIZE=$(ls -lh outputs/custom_riscv_core_final.gds | awk '{print $5}')
        echo "==> GDS file generated: outputs/custom_riscv_core_final.gds"
        echo "    Size: ${GDS_SIZE}"
    elif [ -f "outputs/custom_riscv_core_final.def" ]; then
        DEF_SIZE=$(ls -lh outputs/custom_riscv_core_final.def | awk '{print $5}')
        echo "==> DEF file generated: outputs/custom_riscv_core_final.def"
        echo "    Size: ${DEF_SIZE}"
        echo "    (GDS generation may have failed but DEF is available)"
    else
        echo "WARNING: Neither GDS nor DEF file found"
        echo "Check logs/place_route.log for details"
    fi
else
    echo "ERROR: Place & Route failed!"
    echo "Check logs/place_route.log and logs/place_route_run.log for details"
    exit 1
fi

echo
echo "================================================================================"
echo "Step 3: Results Summary"
echo "================================================================================"

echo "Generated Output Files:"
ls -lh outputs/ | grep -E '\\.(gds|def|v|sdf)$' || echo "  No output files found"

echo
echo "Generated Reports:"
ls -lh reports/ | grep -E '\\.(rpt|txt)$' || echo "  No reports found"

echo
echo "Design Statistics:"
if [ -f "reports/area.rpt" ]; then
    echo "  Area Report: reports/area.rpt"
    grep -i "total" reports/area.rpt 2>/dev/null | head -5 || echo "  Area data not found"
fi

if [ -f "reports/timing.rpt" ]; then
    echo "  Synthesis Timing: reports/timing.rpt"
    grep -i "slack" reports/timing.rpt 2>/dev/null | head -3 || echo "  Timing data not found"
fi

if [ -f "reports/post_route_timing.rpt" ]; then
    echo "  Post-Route Timing: reports/post_route_timing.rpt"
    grep -i "slack" reports/post_route_timing.rpt 2>/dev/null | head -3 || echo "  Timing data not found"
fi

echo
echo "================================================================================"
if [ -f "outputs/custom_riscv_core_final.gds" ]; then
    echo "==> SUCCESS: Complete ASIC flow finished!"
    echo "    GDS file ready: outputs/custom_riscv_core_final.gds"
elif [ -f "outputs/custom_riscv_core_final.def" ]; then
    echo "==> PARTIAL SUCCESS: Flow completed with DEF output"
    echo "    DEF file available: outputs/custom_riscv_core_final.def"
    echo "    (Can be converted to GDS manually if needed)"
else
    echo "WARNING: Flow completed but no layout file generated"
    echo "         Check individual tool logs for issues"
fi
echo "================================================================================"

# Show next steps
echo
echo "Next Steps:"
echo "  1. View layout:    klayout outputs/custom_riscv_core_final.gds"
echo "  2. Check timing:   cat reports/post_route_timing.rpt"
echo "  3. Check area:     cat reports/area.rpt"
echo "  4. View summary:   cat outputs/cadence_flow_summary.txt"
echo "  5. Screenshots:    Take layout screenshots for documentation"
echo
echo "Notes:"
echo "  - Full Sky130 PDK (1.1GB) provides complete timing/physical data"
echo "  - Check reports/ directory for detailed analysis"
echo "  - All logs saved in logs/ directory"
echo
echo "================================================================================"
