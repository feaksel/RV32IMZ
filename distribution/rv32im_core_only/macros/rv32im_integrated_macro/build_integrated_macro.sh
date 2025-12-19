#!/bin/bash
#
# Build RV32IM Integrated Macro
# Hierarchically integrates pre-built core_macro + mdu_macro
#
# Prerequisites: core_macro and mdu_macro must be built first!
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}RV32IM Integrated Macro Build${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
if [ ! -f "../core_macro/outputs/core_macro.lef" ]; then
    echo -e "${RED}ERROR: core_macro.lef not found!${NC}"
    echo "You must build core_macro first:"
    echo "  cd ../core_macro && genus -batch -files scripts/core_synthesis.tcl"
    echo "  cd ../core_macro && innovus -batch -files scripts/core_place_route.tcl"
    exit 1
fi

if [ ! -f "../mdu_macro/outputs/mdu_macro.lef" ]; then
    echo -e "${RED}ERROR: mdu_macro.lef not found!${NC}"
    echo "You must build mdu_macro first:"
    echo "  cd ../mdu_macro && ./run_mdu_macro.sh"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Create directories if needed
mkdir -p outputs reports netlist

# Run synthesis
echo -e "${YELLOW}Running Genus synthesis...${NC}"
cd scripts
genus -batch -files rv32im_integrated_synthesis.tcl
cd ..

if [ ! -f "outputs/rv32im_integrated_macro_syn.v" ]; then
    echo -e "${RED}ERROR: Synthesis failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Synthesis complete${NC}"
echo ""

# Create netlist directory for P&R
mkdir -p netlist
cp outputs/rv32im_integrated_macro_syn.v netlist/

# Run Place & Route
echo -e "${YELLOW}Running Innovus Place & Route...${NC}"
cd scripts
innovus -batch -files rv32im_integrated_place_route.tcl
cd ..

if [ ! -f "outputs/rv32im_integrated_macro.gds" ]; then
    echo -e "${RED}ERROR: Place & Route failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Place & Route complete${NC}"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Outputs:"
echo "  GDS: outputs/rv32im_integrated_macro.gds"
echo "  LEF: outputs/rv32im_integrated_macro.lef"
echo "  DEF: outputs/rv32im_integrated_macro.def"
echo ""
echo "This macro hierarchically combines:"
echo "  - core_macro (~8-9K cells)"
echo "  - mdu_macro (~3-4K cells)"
echo ""
echo "Total: ~11-13K cells in single RV32IM IP block"
echo ""
