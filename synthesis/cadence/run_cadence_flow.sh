#!/bin/bash
# Complete Cadence Academic Synthesis Flow 
# Runs Genus (synthesis) followed by Innovus (place & route)

set -e  # Exit on any error

echo "================================================================================"
echo "Cadence Academic Synthesis Flow for RV32IMZ SoC"
echo "Date: $(date)"
echo "================================================================================"

# Check if we're in the right directory
if [ ! -f "synthesis.tcl" ]; then
    echo "Error: Must run from synthesis/cadence directory"
    echo "Usage: cd synthesis/cadence && ./run_cadence_flow.sh"
    exit 1
fi

# Create outputs directory
mkdir -p outputs

echo
echo "Step 1: Running Genus Synthesis..."
echo "====================================="

# Run Genus synthesis
genus -f synthesis.tcl -log outputs/synthesis.log

if [ $? -eq 0 ]; then
    echo "✓ Synthesis completed successfully"
    echo "  - Netlist: outputs/soc_simple_netlist.v"
    echo "  - Reports: outputs/synthesis_reports/"
else
    echo "✗ Synthesis failed - see outputs/synthesis.log"
    exit 1
fi

echo
echo "Step 2: Running Innovus Place & Route..."
echo "========================================"

# Run Innovus place and route
innovus -f place_route.tcl -log outputs/place_route.log

if [ $? -eq 0 ]; then
    echo "✓ Place & Route completed successfully" 
    echo "  - Final GDS: outputs/soc_simple_final.gds"
    echo "  - DEF: outputs/soc_simple_final.def"
    echo "  - Reports: outputs/place_route_reports/"
else
    echo "✗ Place & Route failed - see outputs/place_route.log"
    exit 1
fi

echo
echo "Step 3: Generating Final Reports..."
echo "==================================="

# Generate summary report
cat > outputs/cadence_flow_summary.txt << EOF
Cadence Academic Flow Summary - $(date)
=========================================

SYNTHESIS RESULTS (Genus):
$(grep -A10 "Final Report" outputs/synthesis.log | head -10)

PLACE & ROUTE RESULTS (Innovus):
$(grep -A15 "Final Statistics" outputs/place_route.log | head -15)

TIMING SUMMARY:
$(grep -A5 "Timing Summary" outputs/place_route.log | head -5)

AREA SUMMARY:
$(grep -A5 "Area Report" outputs/place_route.log | head -5)

FILES GENERATED:
- Netlist: outputs/soc_simple_netlist.v
- Layout: outputs/soc_simple_final.gds  
- DEF: outputs/soc_simple_final.def
- Timing: outputs/timing_report.txt
- Area: outputs/area_report.txt

NOTES:
- Verify timing closure in timing_report.txt
- Check DRC violations in drc_report.txt
- Review LVS results in lvs_report.txt
EOF

echo "✓ Flow completed successfully!"
echo 
echo "Final Results:"
echo "  - Complete flow summary: outputs/cadence_flow_summary.txt"
echo "  - GDSII layout: outputs/soc_simple_final.gds"
echo "  - Gate-level netlist: outputs/soc_simple_netlist.v"
echo
echo "Next Steps:"
echo "  1. Review timing closure in outputs/timing_report.txt"
echo "  2. Check layout in Virtuoso or other GDS viewer" 
echo "  3. Run post-layout simulation if needed"
echo "  4. Generate final fabrication files"