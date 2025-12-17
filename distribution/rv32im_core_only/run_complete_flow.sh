#!/bin/bash
#===============================================================================
# Complete ASIC Flow for RV32IM Core
# Bulletproof Synthesis → Place & Route → GDS Generation
#===============================================================================

set -e  # Exit on any error

echo "======================================================"
echo "Starting Complete ASIC Flow for RV32IM Core"
echo "======================================================"

# Change to synthesis directory (relative path)
cd synthesis_cadence

# Check if PDK files exist
echo "Verifying PDK files..."
if [ ! -f "../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib" ]; then
    echo "ERROR: Missing PDK library files!"
    echo "Please ensure all Sky130 library files are present in ../pdk/"
    exit 1
fi

echo "✓ PDK files found"

# Create output directories
mkdir -p outputs
mkdir -p reports
mkdir -p logs

echo "======================================================"
echo "Step 1: Logic Synthesis with Genus"
echo "======================================================"

# Run synthesis
if genus -f synthesis.tcl -log logs/synthesis.log; then
    echo "✓ Synthesis completed successfully"
    
    # Check if netlist was generated
    if [ -f "outputs/core_netlist.v" ]; then
        echo "✓ Netlist generated: outputs/core_netlist.v"
    else
        echo "ERROR: Netlist not found!"
        echo "Check logs/synthesis.log for errors"
        exit 1
    fi
else
    echo "ERROR: Synthesis failed!"
    echo "Check logs/synthesis.log for details"
    exit 1
fi

echo "======================================================"
echo "Step 2: Place & Route with Innovus"
echo "======================================================"

# Run place and route
if innovus -f place_route.tcl -log logs/place_route.log; then
    echo "✓ Place & Route completed successfully"
    
    # Check if GDS was generated
    if [ -f "outputs/core_final.gds" ]; then
        echo "✓ GDS file generated: outputs/core_final.gds"
        echo "  Size: $(ls -lh outputs/core_final.gds | awk '{print $5}')"
    elif [ -f "outputs/core_final.def" ]; then
        echo "✓ DEF file generated: outputs/core_final.def"
        echo "  (GDS generation may have failed but DEF is available)"
    else
        echo "WARNING: Neither GDS nor DEF file found"
        echo "Check logs/place_route.log for details"
    fi
else
    echo "ERROR: Place & Route failed!"
    echo "Check logs/place_route.log for details"
    exit 1
fi

echo "======================================================"
echo "Step 3: Results Summary"
echo "======================================================"

echo "Generated files:"
ls -la outputs/ | grep -E '\\.(gds|def|v|sdf)$' || echo "  No output files found"

echo ""
echo "Reports generated:"
ls -la reports/ | grep -E '\\.(rpt|txt)$' || echo "  No reports found"

echo ""
echo "Design Statistics:"
if [ -f "reports/area.rpt" ]; then
    echo "  Area Report: reports/area.rpt"
    grep -A 5 "Total cell area:" reports/area.rpt 2>/dev/null || echo "  Area data not found"
fi

if [ -f "reports/post_route_timing.rpt" ]; then
    echo "  Timing Report: reports/post_route_timing.rpt"
    grep -A 3 "Slack" reports/post_route_timing.rpt 2>/dev/null || echo "  Timing data not found"
fi

echo ""
echo "======================================================"
if [ -f "outputs/core_final.gds" ]; then
    echo "SUCCESS: Complete ASIC flow finished!"
    echo "✓ GDS file ready for presentation: outputs/core_final.gds"
elif [ -f "outputs/core_final.def" ]; then
    echo "PARTIAL SUCCESS: Flow completed with DEF output"
    echo "✓ DEF file available: outputs/core_final.def"
    echo "  (Can be converted to GDS manually if needed)"
else
    echo "WARNING: Flow completed but no layout file generated"
    echo "  Check individual tool logs for issues"
fi
echo "======================================================"

# Show next steps
echo ""
echo "Next Steps:"
echo "1. View layout: klayout outputs/core_final.gds (if available)"
echo "2. Check timing: cat reports/post_route_timing.rpt"
echo "3. Check area: cat reports/area.rpt" 
echo "4. For presentation: Take screenshots of layout"
echo "5. Include reports in graduation documentation"
echo ""
echo "Academic Note: Clock may be routed as regular net (no CTS)"
echo "This is acceptable for academic demonstration purposes."
echo ""
