# Hierarchical Macro Integration Using sky130_cds Infrastructure

This guide shows you **exactly what to modify** in the sky130_cds repository to support hierarchical macro integration.

---

## Overview: What We're Doing

**Goal:** Use sky130_cds build system to integrate pre-built macros (core_macro + mdu_macro) into rv32im_integrated_macro.

**Strategy:**
1. Build individual macros using sky130_cds (unchanged)
2. **Modify** `genus_script.tcl` to read pre-built macro netlists
3. **Modify** `setup.tcl` to include macro LEF files
4. **Add** new targets to Makefile for integration flow
5. **Add** macro-specific configuration files

---

## Part 1: Building Individual Macros (Standard sky130_cds Flow)

### Step 1: Setup Directory Structure

```bash
cd sky130_cds

# Create directories for each macro
mkdir -p designs/core_macro/hdl
mkdir -p designs/core_macro/constraints
mkdir -p designs/mdu_macro/hdl
mkdir -p designs/mdu_macro/constraints
mkdir -p designs/rv32im_integrated/hdl
mkdir -p designs/rv32im_integrated/constraints
```

### Step 2: Copy Your RTL

```bash
# Copy core macro RTL
cp /path/to/RV32IMZ/macros/core_macro/rtl/*.v designs/core_macro/hdl/

# Copy mdu macro RTL
cp /path/to/RV32IMZ/macros/mdu_macro/rtl/*.v designs/mdu_macro/hdl/

# Copy integration RTL (we'll create this)
# designs/rv32im_integrated/hdl/rv32im_integrated_macro.v
```

### Step 3: Build Individual Macros (Standard Flow)

For each leaf macro, use the **standard sky130_cds flow**:

#### Create `synth/genus_script_core.tcl` (for core_macro)

```tcl
#===============================================================================
# Genus Script for Core Macro (Standard sky130_cds template)
#===============================================================================

set DESIGN "core_macro"

# Library paths
set LIB_PATH "../sky130_osu_sc_t18"
set HDL_PATH "../designs/core_macro/hdl"

# Setup library search paths
set_db init_lib_search_path "$LIB_PATH/lib $LIB_PATH/lef"
set_db init_hdl_search_path $HDL_PATH

puts "==> Loading libraries..."
read_libs "$LIB_PATH/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"

puts "==> Reading LEF files..."
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T_tech.lef"
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T.lef"

puts "==> Reading RTL..."
read_hdl -v2001 {
    core_macro.v
}

puts "==> Elaborating design..."
elaborate $DESIGN

# Read constraints
if {[file exists "../designs/core_macro/constraints/core_macro.sdc"]} {
    read_sdc "../designs/core_macro/constraints/core_macro.sdc"
} else {
    # Default constraints
    create_clock -period 10.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    set_output_delay 2.0 -clock clk [all_outputs]
}

# Synthesis
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

syn_generic
syn_map
syn_opt

# Reports
exec mkdir -p reports/core_macro
report_timing > reports/core_macro/timing.rpt
report_area > reports/core_macro/area.rpt
report_qor > reports/core_macro/qor.rpt
report_power > reports/core_macro/power.rpt

# Write outputs
exec mkdir -p outputs/core_macro
write_hdl > outputs/core_macro/${DESIGN}.vh
write_sdc > outputs/core_macro/${DESIGN}.sdc
write_sdf > outputs/core_macro/${DESIGN}.sdf

puts "Core macro synthesis complete!"
exit
```

**Repeat for mdu_macro** (create `genus_script_mdu.tcl`)

#### Create `pnr/setup_core.tcl` (for core_macro)

```tcl
#===============================================================================
# Setup for Core Macro P&R (Standard sky130_cds template)
#===============================================================================

set DESIGN "core_macro"
set LIB_PATH "../sky130_osu_sc_t18"

# Library set
create_library_set -name libs_tt \
    -timing [list "${LIB_PATH}/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"]

# RC corner
create_rc_corner -name rc_typ -temperature 25

# Delay corner
create_delay_corner -name corner_tt \
    -library_set libs_tt \
    -rc_corner rc_typ

# Constraint mode
create_constraint_mode -name setup_func_mode \
    -sdc_files [list "../synth/outputs/core_macro/${DESIGN}.sdc"]

# Analysis views
create_analysis_view -name setup_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

create_analysis_view -name hold_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

set_analysis_view -setup {setup_func} -hold {hold_func}

# Power/ground
set_power_net VDD
set_ground_net VSS

# Read LEF
read_physical -lef [list \
    "${LIB_PATH}/lef/sky130_osu_sc_18T_tech.lef" \
    "${LIB_PATH}/lef/sky130_osu_sc_18T.lef" \
]

# Read netlist
read_netlist "../synth/outputs/core_macro/${DESIGN}.vh"

# Initialize
init_design -setup {setup_func} -hold {hold_func}
```

**Repeat for mdu_macro** (create `setup_mdu.tcl`)

---

## Part 2: Modifying sky130_cds for Hierarchical Integration

Now the **key modifications** for integration!

### MODIFICATION 1: Create Modified Synthesis Script

Create **`synth/genus_script_integrated.tcl`** (NEW FILE):

```tcl
#===============================================================================
# Modified Genus Script for Hierarchical Integration
# Reads pre-built macro netlists and integrates them
#===============================================================================

set DESIGN "rv32im_integrated_macro"

# Paths
set LIB_PATH "../sky130_osu_sc_t18"
set HDL_PATH "../designs/rv32im_integrated/hdl"
set MACRO_PATH "outputs"  # Where pre-built macro outputs are

#===============================================================================
# Library Setup (Same as standard flow)
#===============================================================================

set_db init_lib_search_path "$LIB_PATH/lib $LIB_PATH/lef"
set_db init_hdl_search_path $HDL_PATH

puts "==> Loading libraries..."
read_libs "$LIB_PATH/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"

puts "==> Reading LEF files..."
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T_tech.lef"
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T.lef"

#===============================================================================
# NEW: Read Pre-Built Macro Netlists
#===============================================================================

puts "==> Reading pre-built macro netlists..."

# Read core_macro netlist (MUST be built first!)
if {[file exists "${MACRO_PATH}/core_macro/core_macro.vh"]} {
    read_hdl -v2001 "${MACRO_PATH}/core_macro/core_macro.vh"
    puts "    ✓ core_macro netlist loaded"
} else {
    puts "ERROR: core_macro.vh not found! Build core_macro first."
    exit 1
}

# Read mdu_macro netlist (MUST be built first!)
if {[file exists "${MACRO_PATH}/mdu_macro/mdu_macro.vh"]} {
    read_hdl -v2001 "${MACRO_PATH}/mdu_macro/mdu_macro.vh"
    puts "    ✓ mdu_macro netlist loaded"
} else {
    puts "ERROR: mdu_macro.vh not found! Build mdu_macro first."
    exit 1
}

#===============================================================================
# Read Top-Level Integration RTL
#===============================================================================

puts "==> Reading top-level integration RTL..."
read_hdl -v2001 {
    rv32im_integrated_macro.v
}

#===============================================================================
# Elaborate Integrated Design
#===============================================================================

puts "==> Elaborating integrated design..."
elaborate $DESIGN

check_design -unresolved

#===============================================================================
# NEW: Mark Macros as Black Boxes (Don't Touch!)
#===============================================================================

puts "==> Setting macros as black boxes..."

# Preserve pre-built macros (don't re-synthesize them)
if {[llength [get_db designs core_macro]] > 0} {
    set_db [get_db designs core_macro] .preserve true
    set_dont_touch [get_db designs core_macro]
    puts "    ✓ core_macro marked as black box"
}

if {[llength [get_db designs mdu_macro]] > 0} {
    set_db [get_db designs mdu_macro] .preserve true
    set_dont_touch [get_db designs mdu_macro]
    puts "    ✓ mdu_macro marked as black box"
}

#===============================================================================
# Read Constraints
#===============================================================================

puts "==> Applying constraints..."

# Read macro SDC files (optional - for better timing)
catch {read_sdc "${MACRO_PATH}/core_macro/core_macro.sdc"}
catch {read_sdc "${MACRO_PATH}/mdu_macro/mdu_macro.sdc"}

# Read top-level constraints
if {[file exists "../designs/rv32im_integrated/constraints/rv32im_integrated.sdc"]} {
    read_sdc "../designs/rv32im_integrated/constraints/rv32im_integrated.sdc"
} else {
    # Default constraints
    create_clock -period 10.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    set_output_delay 2.0 -clock clk [all_outputs]

    # NEW: Add timing budgets for macro interfaces
    # Assume macros take 60% of clock period
    set_input_delay  6.0 -clock clk [get_pins u_core_macro/*] -add_delay
    set_output_delay 6.0 -clock clk [get_pins u_core_macro/*] -add_delay
    set_input_delay  6.0 -clock clk [get_pins u_mdu_macro/*] -add_delay
    set_output_delay 6.0 -clock clk [get_pins u_mdu_macro/*] -add_delay
}

#===============================================================================
# Synthesis (Only Glue Logic - Macros are Black Boxes!)
#===============================================================================

puts "==> Running synthesis (glue logic only)..."

set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

# This will only synthesize the logic connecting the macros
syn_generic
syn_map
syn_opt

#===============================================================================
# Reports
#===============================================================================

puts "==> Generating reports..."

exec mkdir -p reports/rv32im_integrated

report_timing > reports/rv32im_integrated/timing.rpt
report_area > reports/rv32im_integrated/area.rpt
report_qor > reports/rv32im_integrated/qor.rpt
report_power > reports/rv32im_integrated/power.rpt
report_hierarchy > reports/rv32im_integrated/hierarchy.rpt

#===============================================================================
# Write Outputs
#===============================================================================

puts "==> Writing outputs..."

exec mkdir -p outputs/rv32im_integrated

# Write netlist (includes macro instances + glue logic)
write_hdl > outputs/rv32im_integrated/${DESIGN}.vh

# Write constraints
write_sdc > outputs/rv32im_integrated/${DESIGN}.sdc

# Write SDF
write_sdf > outputs/rv32im_integrated/${DESIGN}.sdf

puts ""
puts "========================================="
puts "Integrated Macro Synthesis Complete!"
puts "========================================="
puts ""
puts "Design contains:"
puts "  - core_macro (pre-built black box)"
puts "  - mdu_macro (pre-built black box)"
puts "  - Glue logic (newly synthesized)"
puts ""
puts "Next: Run place & route with setup_integrated.tcl"
puts ""

exit
```

### MODIFICATION 2: Create Modified P&R Setup

Create **`pnr/setup_integrated.tcl`** (NEW FILE):

```tcl
#===============================================================================
# Modified Setup for Hierarchical Integration P&R
# Reads pre-built macro LEF files
#===============================================================================

set DESIGN "rv32im_integrated_macro"
set LIB_PATH "../sky130_osu_sc_t18"
set MACRO_PATH "../pnr/outputs"  # Where macro LEF/GDS files are

#===============================================================================
# Library Setup (Same as standard flow)
#===============================================================================

# Library set (standard cells only)
create_library_set -name libs_tt \
    -timing [list "${LIB_PATH}/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"]

# RC corner
create_rc_corner -name rc_typ -temperature 25

# Delay corner
create_delay_corner -name corner_tt \
    -library_set libs_tt \
    -rc_corner rc_typ

# Constraint mode
create_constraint_mode -name setup_func_mode \
    -sdc_files [list "../synth/outputs/rv32im_integrated/${DESIGN}.sdc"]

# Analysis views
create_analysis_view -name setup_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

create_analysis_view -name hold_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

set_analysis_view -setup {setup_func} -hold {hold_func}

# Power/ground
set_power_net VDD
set_ground_net VSS

#===============================================================================
# Read Technology LEF (Same as standard flow)
#===============================================================================

puts "==> Loading technology LEF files..."

read_physical -lef [list \
    "${LIB_PATH}/lef/sky130_osu_sc_18T_tech.lef" \
    "${LIB_PATH}/lef/sky130_osu_sc_18T.lef" \
]

#===============================================================================
# NEW: Read Pre-Built Macro LEF Files
#===============================================================================

puts "==> Loading pre-built macro LEF files..."

# Read core_macro LEF
if {[file exists "${MACRO_PATH}/core_macro/core_macro.lef"]} {
    read_physical -lef "${MACRO_PATH}/core_macro/core_macro.lef"
    puts "    ✓ core_macro LEF loaded"
} else {
    puts "ERROR: core_macro.lef not found!"
    puts "Generate it with: write_lef_abstract -5.7 core_macro.lef"
    exit 1
}

# Read mdu_macro LEF
if {[file exists "${MACRO_PATH}/mdu_macro/mdu_macro.lef"]} {
    read_physical -lef "${MACRO_PATH}/mdu_macro/mdu_macro.lef"
    puts "    ✓ mdu_macro LEF loaded"
} else {
    puts "ERROR: mdu_macro.lef not found!"
    puts "Generate it with: write_lef_abstract -5.7 mdu_macro.lef"
    exit 1
}

#===============================================================================
# Read Integrated Netlist
#===============================================================================

puts "==> Reading integrated netlist..."

read_netlist "../synth/outputs/rv32im_integrated/${DESIGN}.vh"

#===============================================================================
# Initialize Design
#===============================================================================

puts "==> Initializing design..."

init_design -setup {setup_func} -hold {hold_func}

puts ""
puts "Setup complete! Design contains:"
puts "  - core_macro (from LEF)"
puts "  - mdu_macro (from LEF)"
puts "  - Glue logic (to be placed)"
puts ""
```

### MODIFICATION 3: Create Modified Innovus Init Script

Create **`pnr/SCRIPTS/init_integrated.tcl`** (NEW FILE):

```tcl
#===============================================================================
# Modified Init Script for Hierarchical Integration
# Adds macro placement after floorplan
#===============================================================================

source setup_integrated.tcl

#===============================================================================
# Create Floorplan (Larger to fit macros!)
#===============================================================================

# Size based on macro dimensions (adjust as needed)
# Example: 350µm x 300µm with 10µm margins
floorPlan -site unithd -s 350.0 300.0 10.0 10.0 10.0 10.0

puts "Floorplan created: 350µm x 300µm"

#===============================================================================
# NEW: Place Pre-Built Macros
#===============================================================================

puts "==> Placing pre-built macros..."

# Get macro sizes to verify spacing
set core_bbox [get_db [get_db insts u_core_macro] .bbox]
set mdu_bbox [get_db [get_db insts u_mdu_macro] .bbox]

puts "Core macro bbox: $core_bbox"
puts "MDU macro bbox: $mdu_bbox"

# Place core_macro on the left
placeInstance u_core_macro 30.0 50.0 -fixed

# Place mdu_macro on the right (adjust X based on core width + spacing)
placeInstance u_mdu_macro 200.0 50.0 -fixed

puts "    ✓ core_macro placed at (30.0, 50.0)"
puts "    ✓ mdu_macro placed at (200.0, 50.0)"

# Verify no overlap
verifyGeometry -noRoutingBlkg

#===============================================================================
# Apply Pin Placement (Top-Level I/O Pins)
#===============================================================================

# Place top-level pins on edges
# Clock and reset on top
editPin -pin clk -edge TOP -layer met3 -spreadType center
editPin -pin rst_n -edge TOP -layer met3 -spreadType center -start {10.0 0.0}

# Other I/O pins spread on edges
editPin -pin instruction* -edge LEFT -layer met2 -spreadType spread
editPin -pin data_in* -edge LEFT -layer met2 -spreadType spread
editPin -pin data_out* -edge RIGHT -layer met2 -spreadType spread
editPin -pin addr_out* -edge BOTTOM -layer met2 -spreadType spread

puts "Top-level pins placed"

#===============================================================================
# Global Net Connections (Same as standard flow)
#===============================================================================

globalNetConnect VDD -type pgpin -pin vdd -inst *
globalNetConnect VSS -type pgpin -pin gnd -inst *

#===============================================================================
# Power Planning
#===============================================================================

# Power rings
addRing -nets {VDD VSS} \
        -type core_rings \
        -follow io \
        -layer {top met1 bottom met1 left met2 right met2} \
        -width 2.0 \
        -spacing 1.0 \
        -offset 2.0

# Power stripes (more stripes for larger design)
addStripe -nets {VDD VSS} \
          -layer met2 \
          -direction vertical \
          -width 1.5 \
          -spacing 8.0 \
          -number_of_sets 20

addStripe -nets {VDD VSS} \
          -layer met3 \
          -direction horizontal \
          -width 1.5 \
          -spacing 8.0 \
          -number_of_sets 15

# Connect power
sroute -connect {blockPin padPin padRing corePin floatingStripe} \
       -layerChangeRange {met1 met3}

puts "Power planning complete"

#===============================================================================
# Save Initial Database
#===============================================================================

exec mkdir -p DBS/rv32im_integrated
saveDesign DBS/rv32im_integrated/init.enc

puts ""
puts "========================================="
puts "Init Complete for Integrated Macro"
puts "========================================="
puts ""
puts "Macros placed:"
puts "  u_core_macro: Fixed at (30.0, 50.0)"
puts "  u_mdu_macro:  Fixed at (200.0, 50.0)"
puts ""
puts "Next: Run place, cts, route stages"
puts ""
```

### MODIFICATION 4: Create Modified Signoff Script

Create **`pnr/SCRIPTS/signoff_integrated.tcl`** (NEW FILE):

```tcl
#===============================================================================
# Modified Signoff Script for Hierarchical Integration
# Generates LEF, netlist, and MERGED GDS
#===============================================================================

# Restore post-route design
restoreDesign DBS/rv32im_integrated/route.enc rv32im_integrated_macro

# Extract parasitics
setExtractMode -engine postRoute
extractRC

# Final timing
timeDesign -postRoute -si

# Reports
exec mkdir -p RPT/rv32im_integrated

report_timing -check_type setup -max_paths 20 > RPT/rv32im_integrated/setup.rpt
report_timing -check_type hold -max_paths 20 > RPT/rv32im_integrated/hold.rpt
report_area > RPT/rv32im_integrated/area.rpt
summaryReport -noHtml -outFile RPT/rv32im_integrated/summary.rpt

#===============================================================================
# Generate Integration Files
#===============================================================================

exec mkdir -p outputs/rv32im_integrated

puts "==> Generating integration files..."

# 1. LEF abstract
write_lef_abstract -5.7 outputs/rv32im_integrated/rv32im_integrated_macro.lef
puts "    ✓ LEF: outputs/rv32im_integrated/rv32im_integrated_macro.lef"

# 2. Netlist
saveNetlist outputs/rv32im_integrated/rv32im_integrated_macro.v -excludeLeafCell
puts "    ✓ Netlist: outputs/rv32im_integrated/rv32im_integrated_macro.v"

# 3. DEF
defOut outputs/rv32im_integrated/rv32im_integrated_macro.def
puts "    ✓ DEF: outputs/rv32im_integrated/rv32im_integrated_macro.def"

#===============================================================================
# NEW: GDSII with MERGED Macro GDS Files
#===============================================================================

puts "==> Generating GDSII with merged macro layouts..."

set MACRO_PATH "outputs"

# Check if macro GDS files exist
set core_gds "${MACRO_PATH}/core_macro/core_macro.gds"
set mdu_gds "${MACRO_PATH}/mdu_macro/mdu_macro.gds"

set merge_list {}
if {[file exists $core_gds]} {
    lappend merge_list $core_gds
    puts "    ✓ Will merge core_macro.gds"
} else {
    puts "    WARNING: core_macro.gds not found at $core_gds"
}

if {[file exists $mdu_gds]} {
    lappend merge_list $mdu_gds
    puts "    ✓ Will merge mdu_macro.gds"
} else {
    puts "    WARNING: mdu_macro.gds not found at $mdu_gds"
}

# Find GDS map file
set gds_map ""
if {[file exists "../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map"]} {
    set gds_map "../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map"
} elseif {[file exists "streamOut.map"]} {
    set gds_map "streamOut.map"
}

# Stream out with merged GDS
if {[llength $merge_list] > 0} {
    if {$gds_map != ""} {
        streamOut outputs/rv32im_integrated/rv32im_integrated_macro.gds \
            -mapFile $gds_map \
            -merge $merge_list \
            -stripes 1 \
            -units 1000 \
            -mode ALL
    } else {
        streamOut outputs/rv32im_integrated/rv32im_integrated_macro.gds \
            -merge $merge_list \
            -stripes 1 \
            -units 1000 \
            -mode ALL
    }
    puts "    ✓ GDSII: outputs/rv32im_integrated/rv32im_integrated_macro.gds (with merged macros)"
} else {
    puts "    ERROR: No macro GDS files found to merge!"
}

#===============================================================================
# Save Final Database
#===============================================================================

saveDesign DBS/rv32im_integrated/signoff.enc

puts ""
puts "========================================="
puts "Signoff Complete!"
puts "========================================="
puts ""
puts "Integration files generated:"
puts "  - outputs/rv32im_integrated/rv32im_integrated_macro.lef"
puts "  - outputs/rv32im_integrated/rv32im_integrated_macro.v"
puts "  - outputs/rv32im_integrated/rv32im_integrated_macro.gds"
puts ""
puts "GDS includes merged layouts:"
if {[file exists $core_gds]} {
    puts "  ✓ core_macro.gds"
}
if {[file exists $mdu_gds]} {
    puts "  ✓ mdu_macro.gds"
}
puts ""
```

### MODIFICATION 5: Create Modified Makefile

Create **`pnr/Makefile.integrated`** (NEW FILE):

```makefile
#===============================================================================
# Modified Makefile for Hierarchical Integration
# Extends standard sky130_cds Makefile with integration targets
#===============================================================================

DESIGN = rv32im_integrated_macro
SCRIPTS_DIR = SCRIPTS

.PHONY: all init place cts route signoff clean help

# Run complete flow
all: init place cts route signoff

#===============================================================================
# Integration Flow Stages
#===============================================================================

init:
	@echo "========================================="
	@echo "Initializing Integrated Design"
	@echo "========================================="
	innovus -init $(SCRIPTS_DIR)/init_integrated.tcl -log LOG/rv32im_integrated_init.log
	@echo "Init complete. Check LOG/rv32im_integrated_init.log"

place:
	@echo "========================================="
	@echo "Placing Design (Glue Logic Only)"
	@echo "========================================="
	@echo "Loading design..."
	@echo "restoreDesign DBS/rv32im_integrated/init.enc $(DESIGN)" > .tmp_place.tcl
	@echo "setPlaceMode -fp false -maxRouteLayer 5" >> .tmp_place.tcl
	@echo "placeDesign -inPlaceOpt -noPrePlaceOpt" >> .tmp_place.tcl
	@echo "optDesign -preCTS -incr" >> .tmp_place.tcl
	@echo "saveDesign DBS/rv32im_integrated/place.enc" >> .tmp_place.tcl
	@echo "exit" >> .tmp_place.tcl
	innovus -init .tmp_place.tcl -log LOG/rv32im_integrated_place.log
	@rm .tmp_place.tcl
	@echo "Placement complete. Check LOG/rv32im_integrated_place.log"

cts:
	@echo "========================================="
	@echo "Clock Tree Synthesis"
	@echo "========================================="
	@echo "restoreDesign DBS/rv32im_integrated/place.enc $(DESIGN)" > .tmp_cts.tcl
	@echo "create_ccopt_clock_tree_spec" >> .tmp_cts.tcl
	@echo "set_ccopt_property target_max_trans 0.5" >> .tmp_cts.tcl
	@echo "set_ccopt_property target_skew 0.1" >> .tmp_cts.tcl
	@echo "catch {ccopt_design}" >> .tmp_cts.tcl
	@echo "optDesign -postCTS -incr" >> .tmp_cts.tcl
	@echo "saveDesign DBS/rv32im_integrated/cts.enc" >> .tmp_cts.tcl
	@echo "exit" >> .tmp_cts.tcl
	innovus -init .tmp_cts.tcl -log LOG/rv32im_integrated_cts.log
	@rm .tmp_cts.tcl
	@echo "CTS complete. Check LOG/rv32im_integrated_cts.log"

route:
	@echo "========================================="
	@echo "Routing Design"
	@echo "========================================="
	@echo "restoreDesign DBS/rv32im_integrated/cts.enc $(DESIGN)" > .tmp_route.tcl
	@echo "setNanoRouteMode -routeWithTimingDriven true" >> .tmp_route.tcl
	@echo "setNanoRouteMode -routeWithSiDriven true" >> .tmp_route.tcl
	@echo "globalRoute" >> .tmp_route.tcl
	@echo "detailRoute" >> .tmp_route.tcl
	@echo "optDesign -postRoute -incr" >> .tmp_route.tcl
	@echo "saveDesign DBS/rv32im_integrated/route.enc" >> .tmp_route.tcl
	@echo "exit" >> .tmp_route.tcl
	innovus -init .tmp_route.tcl -log LOG/rv32im_integrated_route.log
	@rm .tmp_route.tcl
	@echo "Routing complete. Check LOG/rv32im_integrated_route.log"

signoff:
	@echo "========================================="
	@echo "Signoff and File Generation"
	@echo "========================================="
	innovus -init $(SCRIPTS_DIR)/signoff_integrated.tcl -log LOG/rv32im_integrated_signoff.log
	@echo "Signoff complete. Check outputs/rv32im_integrated/"

#===============================================================================
# Utility Targets
#===============================================================================

clean:
	@echo "Cleaning integrated design files..."
	rm -rf DBS/rv32im_integrated
	rm -rf RPT/rv32im_integrated
	rm -rf LOG/rv32im_integrated_*.log
	rm -rf outputs/rv32im_integrated
	rm -f .tmp_*.tcl
	@echo "Clean complete"

help:
	@echo "========================================="
	@echo "Hierarchical Integration Makefile"
	@echo "========================================="
	@echo "Targets:"
	@echo "  make init    - Initialize floorplan and place macros"
	@echo "  make place   - Place standard cells (glue logic)"
	@echo "  make cts     - Clock tree synthesis"
	@echo "  make route   - Route design"
	@echo "  make signoff - Generate LEF/netlist/GDS"
	@echo "  make all     - Run complete flow"
	@echo "  make clean   - Clean build files"
	@echo ""
	@echo "Prerequisites:"
	@echo "  1. Build core_macro first (generates .vh, .lef, .gds)"
	@echo "  2. Build mdu_macro first (generates .vh, .lef, .gds)"
	@echo "  3. Create integration RTL in designs/rv32im_integrated/hdl/"
	@echo "  4. Run synthesis: genus -f genus_script_integrated.tcl"
	@echo "  5. Run this makefile: make -f Makefile.integrated all"
	@echo "========================================="
```

---

## Part 3: Complete Workflow Using Modified sky130_cds

### Step 1: Build Leaf Macros (Standard Flow)

```bash
cd sky130_cds

#===============================================================================
# Build Core Macro
#===============================================================================

cd synth
genus -batch -files genus_script_core.tcl -log ../logs/core_synth.log

cd ../pnr
# Modify innovus to use setup_core.tcl
innovus -init setup_core.tcl -log ../logs/core_init.log
# ... continue with standard place/cts/route ...

# Generate integration files
innovus
```

In Innovus:
```tcl
restoreDesign DBS/core_macro.enc core_macro

# Generate files
exec mkdir -p outputs/core_macro
write_lef_abstract -5.7 outputs/core_macro/core_macro.lef
saveNetlist outputs/core_macro/core_macro.v
streamOut outputs/core_macro/core_macro.gds -mode ALL
exit
```

Repeat for mdu_macro.

### Step 2: Create Integration RTL

Create `sky130_cds/designs/rv32im_integrated/hdl/rv32im_integrated_macro.v`:

```verilog
module rv32im_integrated_macro (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] instruction,
    input  wire [31:0] data_in,
    output wire [31:0] data_out,
    output wire [31:0] addr_out,
    input  wire        interrupt
);

// Interconnect signals between core and MDU
wire        mdu_start;
wire        mdu_ack;
wire [2:0]  mdu_funct3;
wire [31:0] mdu_operand_a;
wire [31:0] mdu_operand_b;
wire        mdu_busy;
wire        mdu_done;
wire [63:0] mdu_product;
wire [31:0] mdu_quotient;
wire [31:0] mdu_remainder;

// Instantiate core_macro (pre-built)
core_macro u_core_macro (
    .clk(clk),
    .rst_n(rst_n),
    .instruction(instruction),
    .data_in(data_in),
    .data_out(data_out),
    .addr_out(addr_out),
    .mdu_start(mdu_start),
    .mdu_ack(mdu_ack),
    .mdu_funct3(mdu_funct3),
    .mdu_operand_a(mdu_operand_a),
    .mdu_operand_b(mdu_operand_b),
    .mdu_busy(mdu_busy),
    .mdu_done(mdu_done),
    .mdu_product(mdu_product),
    .mdu_quotient(mdu_quotient),
    .mdu_remainder(mdu_remainder),
    .interrupt(interrupt)
);

// Instantiate mdu_macro (pre-built)
mdu_macro u_mdu_macro (
    .clk(clk),
    .rst_n(rst_n),
    .start(mdu_start),
    .ack(mdu_ack),
    .funct3(mdu_funct3),
    .operand_a(mdu_operand_a),
    .operand_b(mdu_operand_b),
    .busy(mdu_busy),
    .done(mdu_done),
    .product(mdu_product),
    .quotient(mdu_quotient),
    .remainder(mdu_remainder)
);

endmodule
```

### Step 3: Run Integration Synthesis

```bash
cd sky130_cds/synth
genus -batch -files genus_script_integrated.tcl -log ../logs/integrated_synth.log
```

Check for errors:
```bash
grep -i "error" ../logs/integrated_synth.log
```

### Step 4: Run Integration P&R

```bash
cd ../pnr
make -f Makefile.integrated all
```

This runs:
1. `make init` - Creates floorplan, places macros
2. `make place` - Places glue logic
3. `make cts` - Clock tree synthesis
4. `make route` - Routes connections
5. `make signoff` - Generates LEF/netlist/GDS with merged macros

### Step 5: Verify Results

```bash
# Check logs
ls -lh LOG/rv32im_integrated_*.log

# Check outputs
ls -lh outputs/rv32im_integrated/
# Should see:
# - rv32im_integrated_macro.lef
# - rv32im_integrated_macro.v
# - rv32im_integrated_macro.gds

# View in GUI
innovus
restoreDesign DBS/rv32im_integrated/signoff.enc rv32im_integrated_macro
# Inspect layout, check macro placement, verify routing
```

---

## Summary of Changes

### What to ADD to sky130_cds:

1. **`synth/genus_script_integrated.tcl`** - Synthesis script that reads pre-built macro netlists
2. **`pnr/setup_integrated.tcl`** - P&R setup that reads pre-built macro LEF files
3. **`pnr/SCRIPTS/init_integrated.tcl`** - Init script with macro placement
4. **`pnr/SCRIPTS/signoff_integrated.tcl`** - Signoff script with GDS merge
5. **`pnr/Makefile.integrated`** - Makefile for integration flow
6. **`designs/rv32im_integrated/`** - Directory for integration RTL and constraints

### What to MODIFY in sky130_cds:

**Nothing!** Keep the standard scripts for leaf macros, add new scripts for integration.

### Workflow:

```
1. Build core_macro (standard sky130_cds flow)
   → Generates: .vh, .lef, .gds

2. Build mdu_macro (standard sky130_cds flow)
   → Generates: .vh, .lef, .gds

3. Synthesize integration (modified genus_script_integrated.tcl)
   → Reads macro .vh files
   → Treats them as black boxes
   → Synthesizes glue logic

4. P&R integration (Makefile.integrated)
   → Reads macro .lef files
   → Places macros as fixed blocks
   → Routes connections
   → Merges GDS files
```

All files created and pushed! You now have a complete sky130_cds integration flow! 🚀
