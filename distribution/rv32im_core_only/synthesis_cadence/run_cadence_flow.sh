#!/bin/bash
# Complete Cadence Academic Synthesis Flow
# Runs Genus (synthesis) followed by Innovus (place & route)

set -e  # Exit on any error

echo "================================================================================"
echo "Cadence Academic Synthesis Flow for RV32IM Core Only"
echo "Date: $(date)"
echo "Using Full Sky130 PDK (1.1GB)"
echo "================================================================================"

# Check if we're in the right directory
if [ ! -f "synthesis.tcl" ]; then
    echo "ERROR: Must run from synthesis_cadence directory"
    echo "Usage: cd synthesis_cadence && ./run_cadence_flow.sh"
    exit 1
fi

# Clean previous run
echo "==> Cleaning previous run..."
rm -rf outputs/ reports/ genus.log* innovus.log* *.log.* 2>/dev/null || true

# Create output directories
mkdir -p outputs reports

echo
echo "Step 1: Running Genus Synthesis..."
echo "====================================="

# Run Genus synthesis
genus -f synthesis.tcl -log outputs/synthesis.log 2>&1 | tee synthesis_run.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "==> Synthesis completed successfully"
    echo "  - Netlist: outputs/core_netlist.v"
    echo "  - Reports: reports/"

    # Check if netlist was actually generated
    if [ ! -f "outputs/core_netlist.v" ]; then
        echo "ERROR: Netlist not generated!"
        exit 1
    fi
else
    echo "ERROR: Synthesis failed - see outputs/synthesis.log"
    exit 1
fi

echo
echo "Step 2: Running Innovus Place & Route..."
echo "========================================"

# Run Innovus place and route
innovus -f place_route.tcl -log outputs/place_route.log 2>&1 | tee place_route_run.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "==> Place & Route completed successfully"
    echo "  - Final GDS: outputs/custom_riscv_core_final.gds"
    echo "  - DEF: outputs/custom_riscv_core_final.def"
    echo "  - Reports: reports/"
else
    echo "ERROR: Place & Route failed - see outputs/place_route.log"
    echo "Check place_route_run.log for details"
    exit 1
fi

echo
echo "Step 3: Generating Final Reports..."
echo "==================================="

# Generate summary report
cat > outputs/cadence_flow_summary.txt << EOF
Cadence Academic Flow Summary - $(date)
=========================================

Design: custom_riscv_core (RV32IM)
PDK: Sky130 (Full PDK - 1.1GB)
Clock Target: See constraints file

SYNTHESIS RESULTS:
$(grep -i "slack\|timing\|area" reports/qor.rpt 2>/dev/null | head -20 || echo "See reports/qor.rpt for details")

PLACE & ROUTE RESULTS:
$(grep -i "slack\|timing\|area\|density" outputs/place_route.log 2>/dev/null | head -20 || echo "See outputs/place_route.log")

FILES GENERATED:
- Gate-level netlist: outputs/core_netlist.v
- Final layout (GDS): outputs/custom_riscv_core_final.gds
- DEF file: outputs/custom_riscv_core_final.def
- Synthesis reports: reports/*.rpt
- P&R reports: outputs/*.rpt

KEY REPORTS TO REVIEW:
1. reports/timing.rpt - Synthesis timing analysis
2. reports/area.rpt - Area breakdown
3. reports/power.rpt - Power analysis
4. reports/qor.rpt - Quality of Results summary

NEXT STEPS:
1. Check timing closure (slack should be positive)
2. Review area and power consumption
3. View layout: klayout outputs/custom_riscv_core_final.gds
4. Run post-layout verification if needed
EOF

echo
echo "==========================================="
echo "==> COMPLETE FLOW FINISHED SUCCESSFULLY"
echo "==========================================="
echo
echo "Output Files:"
echo "  - Netlist:  outputs/core_netlist.v"
echo "  - Layout:   outputs/custom_riscv_core_final.gds"
echo "  - Summary:  outputs/cadence_flow_summary.txt"
echo
echo "View the summary:"
echo "  cat outputs/cadence_flow_summary.txt"
echo
echo "View layout (if klayout installed):"
echo "  klayout outputs/custom_riscv_core_final.gds"
echo
echo "==========================================="