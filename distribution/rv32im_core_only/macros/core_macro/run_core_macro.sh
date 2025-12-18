#!/bin/bash

#==============================================================================
# Core Macro Synthesis and P&R Script
# Handles: Pipeline, Register File, ALU, Decoder, CSR, Exception handling
#==============================================================================

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_MACRO_DIR="${SCRIPT_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if we're in the right directory
if [ ! -f "rtl/core_macro.v" ]; then
    error "core_macro.v not found! Run from macros/core_macro/ directory"
fi

log "Starting Core Macro Implementation Flow"
log "Working directory: $CORE_MACRO_DIR"

#==============================================================================
# Setup and Preparation
#==============================================================================

# Create necessary directories
log "Creating output directories..."
mkdir -p reports violations outputs netlist db logs

# Check for required files
REQUIRED_FILES=(
    "rtl/core_macro.v"
    "constraints/core_macro.sdc"
    "mmmc/core_macro_mmmc.tcl"
    "scripts/core_synthesis.tcl"
    "scripts/core_place_route.tcl"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        error "Required file not found: $file"
    fi
done

log "All required files present"

#==============================================================================
# Synthesis Phase
#==============================================================================

log "Starting Synthesis Phase..."

# Check if Cadence Genus is available
if ! command -v genus &> /dev/null; then
    error "Cadence Genus not found in PATH. Please source Cadence environment"
fi

# Run synthesis
log "Launching Cadence Genus for synthesis..."
genus -f scripts/core_synthesis.tcl -log logs/core_synthesis.log

# Check synthesis results
if [ ! -f "netlist/core_macro_syn.v" ]; then
    error "Synthesis failed! No synthesized netlist found"
fi

if [ ! -f "db/core_macro_syn.db" ]; then
    error "Synthesis failed! No database found"
fi

log "Synthesis completed successfully"

# Check for timing violations in synthesis
if grep -q "WARNING.*violations detected" logs/core_synthesis.log; then
    warn "Timing violations detected in synthesis - check logs/core_synthesis.log"
else
    log "Synthesis timing: CLEAN"
fi

#==============================================================================
# Place and Route Phase
#==============================================================================

log "Starting Place and Route Phase..."

# Check if Cadence Innovus is available
if ! command -v innovus &> /dev/null; then
    error "Cadence Innovus not found in PATH. Please source Cadence environment"
fi

# Run place and route
log "Launching Cadence Innovus for place and route..."
innovus -init scripts/core_place_route.tcl -log logs/core_place_route.log

# Check P&R results
if [ ! -f "outputs/core_macro.gds" ]; then
    error "Place and Route failed! No GDS file found"
fi

if [ ! -f "outputs/core_macro.lef" ]; then
    error "Place and Route failed! No LEF file found"
fi

if [ ! -f "outputs/core_macro_final.enc" ]; then
    error "Place and Route failed! No final database found"
fi

log "Place and Route completed successfully"

#==============================================================================
# Quality Checks and Reporting
#==============================================================================

log "Running Quality Checks..."

# Check for timing violations
SETUP_VIOLATIONS=0
HOLD_VIOLATIONS=0

if grep -q "Setup violations exist" logs/core_place_route.log; then
    SETUP_VIOLATIONS=1
    warn "Setup timing violations detected!"
fi

if grep -q "Hold violations exist" logs/core_place_route.log; then
    HOLD_VIOLATIONS=1
    warn "Hold timing violations detected!"
fi

# Check for DRC violations
DRC_VIOLATIONS=0
if grep -q "DRC violations detected" logs/core_place_route.log; then
    DRC_VIOLATIONS=1
    warn "DRC violations detected!"
fi

#==============================================================================
# Generate Summary Report
#==============================================================================

log "Generating summary report..."

SUMMARY_FILE="reports/core_macro_flow_summary.txt"

cat > "$SUMMARY_FILE" << EOF
================================================================================
CORE MACRO IMPLEMENTATION FLOW SUMMARY
Generated: $(date)
================================================================================

DESIGN INFORMATION:
- Design Name: core_macro
- Contains: Pipeline, Register File, ALU, Decoder, CSR, Exception handling
- External Interface: MDU macro connection
- Technology: SKY130 HD

FILES GENERATED:
- Synthesized Netlist: netlist/core_macro_syn.v
- Final Netlist: outputs/core_macro_final.v
- GDS Layout: outputs/core_macro.gds
- LEF Abstract: outputs/core_macro.lef
- Database: outputs/core_macro_final.enc
- SDF Timing: outputs/core_macro.sdf

QUALITY METRICS:
EOF

# Extract metrics from logs if available
if [ -f "logs/core_synthesis.log" ]; then
    CELL_COUNT=$(grep "Cells:" logs/core_synthesis.log | head -1 | awk '{print $2}' || echo "N/A")
    echo "- Cell Count: $CELL_COUNT" >> "$SUMMARY_FILE"
fi

echo "- Setup Timing: $([ $SETUP_VIOLATIONS -eq 0 ] && echo "PASS" || echo "FAIL")" >> "$SUMMARY_FILE"
echo "- Hold Timing: $([ $HOLD_VIOLATIONS -eq 0 ] && echo "PASS" || echo "FAIL")" >> "$SUMMARY_FILE"  
echo "- DRC Check: $([ $DRC_VIOLATIONS -eq 0 ] && echo "PASS" || echo "FAIL")" >> "$SUMMARY_FILE"

cat >> "$SUMMARY_FILE" << EOF

REPORTS GENERATED:
- reports/core_macro_area.rpt
- reports/core_macro_setup_timing.rpt
- reports/core_macro_hold_timing.rpt
- reports/core_macro_final_setup.rpt
- reports/core_macro_final_hold.rpt
- reports/core_macro_power.rpt
- reports/core_macro_summary.rpt

VIOLATIONS (if any):
- violations/core_macro_geometry.rpt
- violations/core_macro_connectivity.rpt
- violations/core_macro_density.rpt
- violations/core_macro_final_drc.rpt

LOG FILES:
- logs/core_synthesis.log
- logs/core_place_route.log

NEXT STEPS:
1. Review timing reports if violations exist
2. Use outputs/core_macro.lef for top-level integration
3. Copy outputs/core_macro.gds for final tapeout

================================================================================
EOF

#==============================================================================
# Final Status
#==============================================================================

echo ""
echo "=============================================================================="
log "CORE MACRO IMPLEMENTATION COMPLETE"
echo "=============================================================================="

log "Summary report: $SUMMARY_FILE"
log "Key outputs:"
log "  - GDS: outputs/core_macro.gds"
log "  - LEF: outputs/core_macro.lef"
log "  - Database: outputs/core_macro_final.enc"

if [ $SETUP_VIOLATIONS -eq 0 ] && [ $HOLD_VIOLATIONS -eq 0 ] && [ $DRC_VIOLATIONS -eq 0 ]; then
    log "✓ ALL QUALITY CHECKS PASSED - Ready for integration!"
else
    warn "Quality issues detected - review reports before proceeding"
    if [ $SETUP_VIOLATIONS -eq 1 ]; then
        warn "  - Setup timing violations (check reports/core_macro_final_setup.rpt)"
    fi
    if [ $HOLD_VIOLATIONS -eq 1 ]; then
        warn "  - Hold timing violations (check reports/core_macro_final_hold.rpt)"
    fi
    if [ $DRC_VIOLATIONS -eq 1 ]; then
        warn "  - DRC violations (check violations/core_macro_final_drc.rpt)"
    fi
fi

echo "=============================================================================="
log "Core macro ready for integration with MDU macro and top-level SoC"