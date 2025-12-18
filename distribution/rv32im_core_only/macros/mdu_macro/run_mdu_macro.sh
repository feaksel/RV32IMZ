#!/bin/bash
#
# run_mdu_macro.sh - Complete MDU Macro Implementation Flow
# 
# This script runs the complete MDU macro flow:
# 1. Synthesis with Genus
# 2. Place & Route with Innovus
# 3. Report generation and verification
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACRO_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MDU Macro Implementation Flow${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if we're in the right directory
if [ ! -f "${MACRO_DIR}/rtl/mdu_macro.v" ]; then
    echo -e "${RED}Error: mdu_macro.v not found in rtl/ directory${NC}"
    echo "Please run this script from the macros/mdu_macro directory"
    exit 1
fi

# Create output directories if they don't exist
mkdir -p "${MACRO_DIR}/reports" "${MACRO_DIR}/outputs"

cd "${SCRIPT_DIR}"

#==============================================================================
# Phase 1: Synthesis with Genus
#==============================================================================

echo -e "${YELLOW}Phase 1: Starting synthesis with Genus...${NC}"

if command -v genus &> /dev/null; then
    echo "Running Genus synthesis..."
    genus -f mdu_synthesis.tcl | tee ../reports/synthesis.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✓ Synthesis completed successfully${NC}"
    else
        echo -e "${RED}✗ Synthesis failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: Genus not found in PATH${NC}"
    echo "Please ensure Cadence tools are properly loaded"
    exit 1
fi

#==============================================================================
# Phase 2: Place & Route with Innovus
#==============================================================================

echo -e "${YELLOW}Phase 2: Starting place & route with Innovus...${NC}"

if command -v innovus &> /dev/null; then
    echo "Running Innovus place & route..."
    innovus -f mdu_place_route.tcl | tee ../reports/place_route.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✓ Place & Route completed successfully${NC}"
    else
        echo -e "${RED}✗ Place & Route failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: Innovus not found in PATH${NC}"
    echo "Please ensure Cadence tools are properly loaded"
    exit 1
fi

#==============================================================================
# Phase 3: Verification and Summary
#==============================================================================

echo -e "${YELLOW}Phase 3: Verification and summary...${NC}"

# Check for generated files
REQUIRED_FILES=(
    "outputs/mdu_macro.lef"
    "outputs/mdu_macro.lib" 
    "outputs/mdu_macro.gds"
    "outputs/mdu_macro_final.v"
)

ALL_FILES_EXIST=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "${MACRO_DIR}/${file}" ]; then
        echo -e "${GREEN}✓ ${file}${NC}"
    else
        echo -e "${RED}✗ ${file} (missing)${NC}"
        ALL_FILES_EXIST=false
    fi
done

# Display summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MDU Macro Implementation Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$ALL_FILES_EXIST" = true ]; then
    echo -e "${GREEN}✓ All macro deliverables generated successfully${NC}"
    echo ""
    echo "Generated files:"
    echo "  • LEF file for top-level integration"
    echo "  • LIB file for timing analysis"
    echo "  • GDS file for final tapeout"
    echo "  • Netlist for simulation"
    echo ""
    echo "Next steps:"
    echo "  1. Review timing reports in reports/"
    echo "  2. Implement core macro"
    echo "  3. Run top-level integration"
else
    echo -e "${RED}✗ Some deliverables are missing${NC}"
    echo "Please check the log files for errors:"
    echo "  • reports/synthesis.log"
    echo "  • reports/place_route.log"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}MDU Macro flow completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"