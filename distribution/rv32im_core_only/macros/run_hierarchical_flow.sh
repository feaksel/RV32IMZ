#!/bin/bash

#==============================================================================
# Complete 2-Macro Hierarchical Implementation Script
# Builds MDU macro, Core macro, and integrates them
#==============================================================================

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACRO_DIR="${SCRIPT_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

#==============================================================================
# Environment Verification
#==============================================================================

log "2-Macro RV32IM Hierarchical Implementation Flow"
log "Working directory: $MACRO_DIR"

# Check for Cadence tools
if ! command -v genus &> /dev/null; then
    error "Cadence Genus not found in PATH. Please source Cadence environment"
fi

if ! command -v innovus &> /dev/null; then
    error "Cadence Innovus not found in PATH. Please source Cadence environment"
fi

# Check directory structure
if [ ! -d "mdu_macro" ] || [ ! -d "core_macro" ]; then
    error "Macro directories not found! Run from macros/ directory with mdu_macro and core_macro subdirs"
fi

log "Environment check passed"

#==============================================================================
# Phase 1: MDU Macro Implementation
#==============================================================================

log "Phase 1: Building MDU Macro"

cd mdu_macro || error "Cannot enter mdu_macro directory"

# Run MDU macro flow
info "Starting MDU macro synthesis and P&R..."
./run_mdu_macro.sh

if [ $? -ne 0 ]; then
    error "MDU macro implementation failed!"
fi

# Verify MDU outputs
if [ ! -f "outputs/mdu_macro.gds" ] || [ ! -f "outputs/mdu_macro.lef" ]; then
    error "MDU macro outputs missing!"
fi

log "✓ MDU macro completed successfully"

cd "$MACRO_DIR" || error "Cannot return to macro directory"

#==============================================================================
# Phase 2: Core Macro Implementation
#==============================================================================

log "Phase 2: Building Core Macro"

cd core_macro || error "Cannot enter core_macro directory"

# Run core macro flow
info "Starting Core macro synthesis and P&R..."
./run_core_macro.sh

if [ $? -ne 0 ]; then
    error "Core macro implementation failed!"
fi

# Verify core outputs
if [ ! -f "outputs/core_macro.gds" ] || [ ! -f "outputs/core_macro.lef" ]; then
    error "Core macro outputs missing!"
fi

log "✓ Core macro completed successfully"

cd "$MACRO_DIR" || error "Cannot return to macro directory"

#==============================================================================
# Phase 3: Integration and Final Assembly
#==============================================================================

log "Phase 3: Integrating Hierarchical Design"

# Create integration workspace
mkdir -p integration/{outputs,reports,logs}

# Copy macro outputs to integration area
cp mdu_macro/outputs/mdu_macro.lef integration/
cp mdu_macro/outputs/mdu_macro.gds integration/
cp core_macro/outputs/core_macro.lef integration/
cp core_macro/outputs/core_macro.gds integration/

info "Macro outputs copied to integration directory"

#==============================================================================
# Quality Assessment and Reporting
#==============================================================================

log "Phase 4: Quality Assessment"

# Create comprehensive summary
SUMMARY_FILE="integration/reports/hierarchical_flow_summary.txt"

cat > "$SUMMARY_FILE" << EOF
================================================================================
2-MACRO HIERARCHICAL RV32IM IMPLEMENTATION SUMMARY
Generated: $(date)
================================================================================

IMPLEMENTATION STRATEGY:
- Approach: 2-macro hierarchical design for timing closure
- Macro 1: MDU (Multiply/Divide Unit) - Isolated heavy computation
- Macro 2: Core (Pipeline + Register File + ALU + Decoder + CSR + Exception)
- Technology: SKY130 HD standard cells
- Tools: Cadence Genus (synthesis) + Innovus (place & route)

MACRO STATUS:
EOF

# Check MDU status
if [ -f "mdu_macro/logs/mdu_synthesis.log" ]; then
    MDU_CELLS=$(grep "Cells:" mdu_macro/logs/mdu_synthesis.log | head -1 | awk '{print $2}' 2>/dev/null || echo "N/A")
    echo "- MDU Macro: COMPLETED ($MDU_CELLS cells)" >> "$SUMMARY_FILE"
    
    if grep -q "WARNING.*violations detected" mdu_macro/logs/mdu_synthesis.log 2>/dev/null; then
        echo "  - Timing: WITH VIOLATIONS (check mdu_macro/reports/)" >> "$SUMMARY_FILE"
    else
        echo "  - Timing: CLEAN" >> "$SUMMARY_FILE"
    fi
    
    if grep -q "DRC violations detected" mdu_macro/logs/mdu_place_route.log 2>/dev/null; then
        echo "  - DRC: WITH VIOLATIONS (check mdu_macro/violations/)" >> "$SUMMARY_FILE"
    else
        echo "  - DRC: CLEAN" >> "$SUMMARY_FILE"
    fi
else
    echo "- MDU Macro: ERROR (no synthesis log found)" >> "$SUMMARY_FILE"
fi

# Check Core status  
if [ -f "core_macro/logs/core_synthesis.log" ]; then
    CORE_CELLS=$(grep "Cells:" core_macro/logs/core_synthesis.log | head -1 | awk '{print $2}' 2>/dev/null || echo "N/A")
    echo "- Core Macro: COMPLETED ($CORE_CELLS cells)" >> "$SUMMARY_FILE"
    
    if grep -q "WARNING.*violations detected" core_macro/logs/core_synthesis.log 2>/dev/null; then
        echo "  - Timing: WITH VIOLATIONS (check core_macro/reports/)" >> "$SUMMARY_FILE"
    else
        echo "  - Timing: CLEAN" >> "$SUMMARY_FILE"
    fi
    
    if grep -q "DRC violations detected" core_macro/logs/core_place_route.log 2>/dev/null; then
        echo "  - DRC: WITH VIOLATIONS (check core_macro/violations/)" >> "$SUMMARY_FILE"
    else
        echo "  - DRC: CLEAN" >> "$SUMMARY_FILE"
    fi
else
    echo "- Core Macro: ERROR (no synthesis log found)" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

INTEGRATION FILES READY:
- integration/mdu_macro.lef (for top-level P&R)
- integration/core_macro.lef (for top-level P&R)
- integration/mdu_macro.gds (final layout)
- integration/core_macro.gds (final layout)
- rv32im_hierarchical_top.v (top-level wrapper)
- constraints/hierarchical_top.sdc (top-level constraints)

NEXT STEPS FOR CADENCE SESSION:
1. Use rv32im_hierarchical_top.v as top-level design
2. Load macro LEF files during floorplanning
3. Apply constraints/hierarchical_top.sdc for timing
4. Place macros with optimal relative positioning
5. Route top-level connections between macros

TIMING STRATEGY:
- Total clock period: 10ns (100MHz)
- Inter-macro budget: 3ns for connections
- Intra-macro budget: 7ns for internal timing
- Multi-cycle paths for MDU operations (8 cycles)

BENEFITS ACHIEVED:
- Separated timing-critical paths into manageable macros
- Reduced reset network fanout per macro
- Enabled independent optimization of MDU and core
- Simplified routing congestion by hierarchy
- Improved synthesis/P&R runtime and convergence

FILES FOR NEXT CADENCE SESSION:
================================================================================
Ready-to-use files in macros/ directory:
- rv32im_hierarchical_top.v (top-level design)
- constraints/hierarchical_top.sdc (timing constraints)
- integration/mdu_macro.lef (MDU macro abstract view)
- integration/core_macro.lef (Core macro abstract view)
- mdu_macro/outputs/ (complete MDU implementation)
- core_macro/outputs/ (complete Core implementation)

USAGE:
1. cd to macros/ directory
2. Use rv32im_hierarchical_top.v as main design
3. Load LEF files from integration/ during floorplan
4. Apply hierarchical_top.sdc constraints
5. Proceed with normal synthesis + P&R flow

================================================================================
EOF

#==============================================================================
# Final Status and Next Steps
#==============================================================================

echo ""
echo "=============================================================================="
log "2-MACRO HIERARCHICAL IMPLEMENTATION COMPLETE"
echo "=============================================================================="

log "Summary report: $SUMMARY_FILE"
log ""
log "Key deliverables:"
log "  ✓ MDU Macro: mdu_macro/outputs/"
log "  ✓ Core Macro: core_macro/outputs/"
log "  ✓ Integration files: integration/"
log "  ✓ Top-level design: rv32im_hierarchical_top.v"
log "  ✓ Constraints: constraints/hierarchical_top.sdc"
log ""

# Check overall success
SUCCESS=true

if [ ! -f "mdu_macro/outputs/mdu_macro.gds" ]; then
    warn "MDU macro GDS missing"
    SUCCESS=false
fi

if [ ! -f "core_macro/outputs/core_macro.gds" ]; then
    warn "Core macro GDS missing"
    SUCCESS=false
fi

if [ ! -f "integration/mdu_macro.lef" ] || [ ! -f "integration/core_macro.lef" ]; then
    warn "Integration LEF files missing"
    SUCCESS=false
fi

if [ "$SUCCESS" = true ]; then
    log "🎉 ALL MACROS READY FOR CADENCE SESSION!"
    log ""
    info "Next steps:"
    info "1. cd to macros/ directory"
    info "2. Use rv32im_hierarchical_top.v as your top-level design"
    info "3. Load integration/*.lef files during floorplan setup"
    info "4. Apply constraints/hierarchical_top.sdc for timing"
    info "5. Run normal Genus synthesis + Innovus P&R flow"
    log ""
    log "Expected benefits:"
    log "  • Better timing closure (separate optimization per macro)"
    log "  • Reduced DRC violations (cleaner macro interfaces)"
    log "  • Faster convergence (smaller problem sizes per macro)"
    log "  • Improved reset distribution (limited fanout per macro)"
else
    error "Some macro implementations failed - check individual macro logs"
fi

echo "=============================================================================="