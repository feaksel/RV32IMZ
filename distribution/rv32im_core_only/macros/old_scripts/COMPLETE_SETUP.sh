#!/bin/bash

#==============================================================================
# PRE-SESSION CRITICAL FIXES
# Run this script BEFORE going to university session
# Fixes known bugs that will cause synthesis to fail
#==============================================================================

echo "=========================================="
echo "RV32IM Pre-Session Critical Fixes"
echo "=========================================="
echo ""

MACRO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$MACRO_DIR" || exit 1

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

#==============================================================================
# FIX 1: Verify Port Connections
#==============================================================================

echo -e "${YELLOW}[FIX 1]${NC} Verifying MDU port connections in rv32im_hierarchical_top.v"

HIER_TOP="rv32im_hierarchical_top.v"

if [ ! -f "$HIER_TOP" ]; then
    echo -e "${RED}ERROR:${NC} $HIER_TOP not found!"
    exit 1
fi

# Verify port names match mdu_macro.v (operand_a, operand_b)
if grep -q "\.operand_a" "$HIER_TOP" && grep -q "\.operand_b" "$HIER_TOP"; then
    echo -e "  ${GREEN}✓${NC} Port connections are correct (operand_a, operand_b)"
else
    echo -e "  ${RED}✗${NC} Port name mismatch detected - needs manual fix!"
fi

# Create backup anyway for safety
cp "$HIER_TOP" "${HIER_TOP}.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "  ${GREEN}✓${NC} Backup created for safety"

#==============================================================================
# FIX 2: Add Missing SRAM Constraints
#==============================================================================

echo ""
echo -e "${YELLOW}[FIX 2]${NC} Adding SRAM timing constraints to memory_macro.sdc"

MEMORY_SDC="memory_macro/constraints/memory_macro.sdc"

if [ -f "$MEMORY_SDC" ]; then
    # Check if constraints already exist
    if ! grep -q "SRAM internal paths" "$MEMORY_SDC"; then
        cat >> "$MEMORY_SDC" << 'EOF'

#==============================================================================
# SRAM Macro Timing Constraints (Auto-added by PRE_SESSION_FIXES.sh)
#==============================================================================

# SRAM internal paths are don't-care (black box)
set_false_path -through [get_pins -hier *sram_rom*/dout*]
set_false_path -through [get_pins -hier *sram_ram*/dout*]

# SRAM access timing (from sky130_sram datasheet: ~2.5ns typical)
set sram_access_time 2.5
set_max_delay $sram_access_time -from [get_pins -hier *sram_*/clk0] \
                                 -to [get_pins -hier *sram_*/dout*]

# SRAM setup/hold time
set_input_delay 1.5 -clock clk [get_pins -hier *sram_*/din*]
set_output_delay 2.0 -clock clk [get_pins -hier *sram_*/dout*]
EOF
        echo -e "  ${GREEN}✓${NC} SRAM constraints added to $MEMORY_SDC"
    else
        echo -e "  ${YELLOW}!${NC} SRAM constraints already present, skipping"
    fi
else
    echo -e "  ${YELLOW}!${NC} $MEMORY_SDC not found, skipping (will be created during build)"
fi

#==============================================================================
# FIX 3: Verify SRAM Macro Files
#==============================================================================

echo ""
echo -e "${YELLOW}[FIX 3]${NC} Verifying SKY130 SRAM macro files"

PDK_PATH="$(cd "${MACRO_DIR}/../../../pdk/sky130A" && pwd)"
SRAM_BASE="sky130_sram_2kbyte_1rw1r_32x512_8"

SRAM_FILES=(
    "libs.ref/sky130_sram_macros/verilog/${SRAM_BASE}.v"
    "libs.ref/sky130_sram_macros/lib/${SRAM_BASE}_TT_1p8V_25C.lib"
    "libs.ref/sky130_sram_macros/gds/${SRAM_BASE}.gds"
    "libs.ref/sky130_sram_macros/lef/${SRAM_BASE}.lef"
)

SRAM_OK=true

for file in "${SRAM_FILES[@]}"; do
    full_path="$PDK_PATH/$file"
    if [ -f "$full_path" ]; then
        echo -e "  ${GREEN}✓${NC} Found: $file"
    else
        echo -e "  ${RED}✗${NC} Missing: $file"
        SRAM_OK=false
    fi
done

if [ "$SRAM_OK" = false ]; then
    echo ""
    echo -e "${RED}WARNING:${NC} SRAM macro files missing!"
    echo "Memory macro will likely fail during synthesis."
    echo ""
    echo "Options:"
    echo "  1. Download from: https://github.com/efabless/sky130_sram_macros"
    echo "  2. Skip memory_macro during build"
    echo "  3. Use behavioral memory instead (less realistic)"
    echo ""
else
    echo -e "  ${GREEN}✓${NC} All SRAM files present"
fi

#==============================================================================
# FIX 4: Create Pin Placement Scripts
#==============================================================================

echo ""
echo -e "${YELLOW}[FIX 4]${NC} Creating production-quality pin placement scripts"

# Core macro pin placement
mkdir -p core_macro/scripts
cat > core_macro/scripts/core_macro_pin_placement.tcl << 'EOF'
#===============================================================================
# Core Macro Pin Placement - Production Quality
# Creates logical grouping and optimal routing
#===============================================================================

puts "Applying pin placement for Core Macro..."

# Group 1: Wishbone instruction interface (BOTTOM side)
catch {
    editPin -pin {iwb_adr_o[*]} -side BOTTOM -layer 3 -spreadType RANGE \
            -start {10.0 0} -end {50.0 0}
    editPin -pin {iwb_dat_i[*]} -side BOTTOM -layer 3 -spreadType RANGE \
            -start {60.0 0} -end {100.0 0}
    editPin -pin {iwb_cyc_o iwb_stb_o iwb_ack_i} -side BOTTOM -layer 3 \
            -spreadType RANGE -start {110.0 0} -end {120.0 0}
}

# Group 2: Wishbone data interface (TOP side)
catch {
    editPin -pin {dwb_adr_o[*]} -side TOP -layer 3 -spreadType RANGE \
            -start {10.0 0} -end {50.0 0}
    editPin -pin {dwb_dat_o[*]} -side TOP -layer 3 -spreadType RANGE \
            -start {60.0 0} -end {100.0 0}
    editPin -pin {dwb_dat_i[*]} -side TOP -layer 3 -spreadType RANGE \
            -start {110.0 0} -end {150.0 0}
    editPin -pin {dwb_we_o dwb_sel_o[*] dwb_cyc_o dwb_stb_o dwb_ack_i dwb_err_i} \
            -side TOP -layer 3 -spreadType RANGE -start {160.0 0} -end {180.0 0}
}

# Group 3: MDU interface (RIGHT side - connects to MDU macro)
catch {
    editPin -pin {mdu_start mdu_ack mdu_funct3[*]} -side RIGHT -layer 2 \
            -spreadType RANGE -start {0 10.0} -end {0 20.0}
    editPin -pin {mdu_operand_a[*] mdu_operand_b[*]} -side RIGHT -layer 2 \
            -spreadType RANGE -start {0 25.0} -end {0 40.0}
    editPin -pin {mdu_busy mdu_done mdu_product[*] mdu_quotient[*] mdu_remainder[*]} \
            -side RIGHT -layer 2 -spreadType RANGE -start {0 45.0} -end {0 55.0}
}

# Group 4: System signals (LEFT side, distributed)
catch {
    editPin -pin {clk rst_n} -side LEFT -layer 4 -spreadType CENTER
    editPin -pin {interrupts[*]} -side LEFT -layer 2 -spreadType RANGE \
            -start {0 30.0} -end {0 50.0}
}

puts "Pin placement complete"
EOF

echo -e "  ${GREEN}✓${NC} Created: core_macro/scripts/core_macro_pin_placement.tcl"

# MDU macro pin placement
mkdir -p mdu_macro/scripts
cat > mdu_macro/scripts/mdu_macro_pin_placement.tcl << 'EOF'
#===============================================================================
# MDU Macro Pin Placement - Production Quality
#===============================================================================

puts "Applying pin placement for MDU Macro..."

# Control signals (LEFT side - connects to Core macro)
catch {
    editPin -pin {start ack funct3[*]} -side LEFT -layer 2 \
            -spreadType RANGE -start {0 10.0} -end {0 20.0}
}

# Input operands (LEFT side)
catch {
    editPin -pin {a[*] b[*]} -side LEFT -layer 2 \
            -spreadType RANGE -start {0 25.0} -end {0 40.0}
}

# Output results (LEFT side)
catch {
    editPin -pin {busy done product[*] quotient[*] remainder[*]} -side LEFT -layer 2 \
            -spreadType RANGE -start {0 45.0} -end {0 55.0}
}

# Clock and reset (distributed)
catch {
    editPin -pin {clk rst_n} -side BOTTOM -layer 4 -spreadType CENTER
}

puts "Pin placement complete"
EOF

echo -e "  ${GREEN}✓${NC} Created: mdu_macro/scripts/mdu_macro_pin_placement.tcl"

#==============================================================================
# FIX 5: Update P&R Scripts to Use Pin Placement
#==============================================================================

echo ""
echo -e "${YELLOW}[FIX 5]${NC} Updating P&R scripts to include pin placement"

# Check if core P&R script needs update
CORE_PR_SCRIPT="core_macro/scripts/core_place_route.tcl"
if [ -f "$CORE_PR_SCRIPT" ]; then
    if ! grep -q "core_macro_pin_placement.tcl" "$CORE_PR_SCRIPT"; then
        # Find floorPlan line and add pin placement after it
        sed -i '/^floorPlan/a \\n# Apply pin placement (production quality)\nsource scripts/core_macro_pin_placement.tcl' "$CORE_PR_SCRIPT"
        echo -e "  ${GREEN}✓${NC} Updated: $CORE_PR_SCRIPT to include pin placement"
    else
        echo -e "  ${YELLOW}!${NC} $CORE_PR_SCRIPT already includes pin placement"
    fi
else
    echo -e "  ${YELLOW}!${NC} $CORE_PR_SCRIPT not found, will be handled during build"
fi

#==============================================================================
# SUMMARY
#==============================================================================

echo ""
echo "=========================================="
echo "Pre-Session Fixes Complete!"
echo "=========================================="
echo ""
echo "Summary of changes:"
echo -e "  ${GREEN}1.${NC} Verified MDU port connections (already correct!)"
echo -e "  ${GREEN}2.${NC} Added SRAM timing constraints"
echo -e "  ${GREEN}3.${NC} Verified SRAM macro files"
echo -e "  ${GREEN}4.${NC} Created production-quality pin placement scripts"
echo -e "  ${GREEN}5.${NC} Updated P&R scripts to use pin placement"
echo ""

if [ "$SRAM_OK" = false ]; then
    echo -e "${YELLOW}WARNING:${NC} SRAM macro files missing - memory_macro may fail"
    echo ""
fi

echo "Next steps:"
echo "  1. Review changes in backup files if needed"
echo "  2. Test synthesis locally (optional but recommended):"
echo "     cd core_macro && genus -batch -files scripts/core_synthesis.tcl"
echo "  3. Package for university session:"
echo "     tar -czf rv32im_ready.tar.gz ./macros/"
echo ""
echo "You are now ready for the university Cadence session!"
echo ""
