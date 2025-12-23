# Complete SOC Integration Guide for RV32IMZ with sky130_cds

## TL;DR - Quick Answer to Your Question

**Q: If I generate all the leaf macros from sky130_cds directly with `make synth` and `make pr`, would it still work for hierarchical integration?**

**A: YES! Absolutely!** ✅

Here's the workflow:
1. **Build leaf macros** using standard `make synth` and `make pr` (NO changes needed!)
2. **Generate integration files** (LEF, netlist, GDS) from each leaf macro
3. **Create `*_integrated.tcl` scripts** for hierarchical integration (NEW files, don't modify standard ones!)
4. **Run integration** using the new scripts

**You keep the standard sky130_cds Makefiles unchanged for leaf macros, and ADD new files for integration.**

---

# Complete Multi-Level SOC Integration

This guide shows the **complete workflow** for building a full SOC with multiple levels of hierarchy:

```
Level 0 (Leaf Macros - Built with standard sky130_cds):
├── core_macro
├── mdu_macro
├── memory_macro
├── communication_macro
├── protection_macro
├── adc_subsystem_macro
└── pwm_accelerator_macro

Level 1 (Integrated Subsystems):
├── rv32im_integrated_macro (core + mdu)
└── peripheral_subsystem_macro (communication + protection + adc + pwm)

Level 2 (Top-Level SOC):
└── rv32imz_soc_macro (rv32im_integrated + peripheral_subsystem + memory)
```

---

## Part 1: Building Leaf Macros (Standard sky130_cds - UNCHANGED!)

### Step 1: Setup sky130_cds Repository

```bash
# Clone sky130_cds
git clone https://github.com/stineje/sky130_cds.git
cd sky130_cds

# Initialize submodules (gets OSU standard cells)
git submodule update --init --recursive

# Verify libraries are installed
ls -lh sky130_osu_sc_t18/lib/
```

### Step 2: Build Each Leaf Macro Using Standard Makefiles

For each leaf macro, use the **standard sky130_cds workflow** (NO modifications needed!):

#### Example: Building core_macro

**Directory Structure:**
```
sky130_cds/
├── synth/
│   ├── Makefile           # Standard Makefile (keep as-is!)
│   ├── genus_script.tcl   # Standard synthesis script (keep as-is!)
│   └── hdl/core_macro/    # Your RTL goes here
└── pnr/
    ├── Makefile           # Standard Makefile (keep as-is!)
    ├── setup.tcl          # Standard setup (keep as-is!)
    └── SCRIPTS/           # Standard PNR scripts (keep as-is!)
```

**Step 2a: Copy Your RTL**

```bash
mkdir -p sky130_cds/synth/hdl/core_macro
cp /path/to/RV32IMZ/macros/core_macro/rtl/*.v sky130_cds/synth/hdl/core_macro/
```

**Step 2b: Create Constraints**

Create `sky130_cds/synth/constraints/core_macro.sdc`:

```tcl
# Core macro timing constraints
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks clk]

# Input/output delays
set_input_delay 2.0 -clock clk [all_inputs]
remove_input_delay [get_ports clk]

set_output_delay 2.0 -clock clk [all_outputs]

# Load and drive
set_load 0.05 [all_outputs]
set_driving_cell -lib_cell sky130_osu_sc_18T_ms__buf_1 [all_inputs]

# False paths
set_false_path -from [get_ports rst_n]
```

**Step 2c: Update genus_script.tcl for Your Design**

Edit `sky130_cds/synth/genus_script.tcl`:

```tcl
# Change DESIGN name
set DESIGN "core_macro"

# Change HDL path
set HDL_PATH "hdl/core_macro"

# Read your RTL files
read_hdl -v2001 {
    core_macro.v
    # Add all your .v files here
}

# Rest stays the same!
```

**Step 2d: Run Standard Synthesis**

```bash
cd sky130_cds/synth

# Use standard Makefile!
make synth

# Check results
grep -i "error" synth.log
cat reports/area.rpt
cat reports/timing.rpt
```

**Output Files:**
- `core_macro.vh` - Gate-level netlist
- `core_macro.sdc` - Timing constraints
- `reports/` - Area, timing, power reports

**Step 2e: Run Standard Place & Route**

```bash
cd ../pnr

# Update setup.tcl with your design name
# (Just change DESIGN variable, rest stays the same!)

# Use standard Makefile!
make init
make place
make cts
make route
make signoff

# Check results
cat RPT/timing.rpt
```

**Step 2f: Generate Integration Files**

This is the **only new step** - generate files needed for integration:

```bash
cd sky130_cds/pnr

# Open Innovus
innovus
```

In Innovus console:
```tcl
# Restore your completed design
restoreDesign DBS/signoff.enc.dat core_macro

# Create outputs directory
exec mkdir -p outputs/core_macro

#===============================================================================
# Generate ALL Integration Files
#===============================================================================

# 1. LEF Abstract (for physical integration)
write_lef_abstract -5.7 outputs/core_macro/core_macro.lef

# 2. Gate-level netlist (for synthesis integration)
saveNetlist outputs/core_macro/core_macro_netlist.v -excludeLeafCell

# 3. Timing constraints (for timing integration)
write_sdc outputs/core_macro/core_macro.sdc

# 4. GDSII layout (for final merge)
streamOut outputs/core_macro/core_macro.gds \
    -mapFile ../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map \
    -stripes 1 \
    -units 1000 \
    -mode ALL

# 5. (Optional) Generate .lib timing model for more accurate integration
setExtractMode -engine postRoute
extractRC
write_timing_model \
    -format lib \
    -library_name core_macro_lib \
    -typ_opcond \
    outputs/core_macro/core_macro.lib

puts "✓ Integration files generated in outputs/core_macro/"
exit
```

**You now have all files needed for integration:**
```
outputs/core_macro/
├── core_macro.lef            # Physical abstract
├── core_macro_netlist.v      # Gate-level netlist
├── core_macro.sdc            # Timing constraints
├── core_macro.gds            # Layout
└── core_macro.lib            # (Optional) Timing model
```

### Step 3: Repeat for All Leaf Macros

Repeat Step 2 for each macro:

```bash
# Build mdu_macro
cd synth
# Update genus_script.tcl for mdu_macro
make synth
cd ../pnr
make all
# Generate integration files in Innovus

# Build memory_macro
cd synth
# Update genus_script.tcl for memory_macro
make synth
cd ../pnr
make all
# Generate integration files in Innovus

# ... repeat for all leaf macros ...
```

**At the end, you'll have:**
```
sky130_cds/pnr/outputs/
├── core_macro/
│   ├── core_macro.lef
│   ├── core_macro_netlist.v
│   ├── core_macro.sdc
│   └── core_macro.gds
├── mdu_macro/
│   ├── mdu_macro.lef
│   ├── mdu_macro_netlist.v
│   ├── mdu_macro.sdc
│   └── mdu_macro.gds
├── memory_macro/
│   └── ...
└── ... (all your leaf macros)
```

---

## Part 2: Level 1 Integration (Combining Leaf Macros)

Now we integrate leaf macros into subsystems. This is where you **ADD new scripts** (don't modify the standard ones!).

### Example: rv32im_integrated_macro (core + mdu)

**Directory Structure:**
```
sky130_cds/
├── synth/
│   ├── genus_script.tcl           # Standard (keep for leaf macros!)
│   ├── genus_script_rv32im.tcl    # NEW - For integration
│   └── hdl/rv32im_integrated/     # NEW - Integration RTL
└── pnr/
    ├── setup.tcl                   # Standard (keep for leaf macros!)
    ├── setup_rv32im.tcl            # NEW - For integration
    └── SCRIPTS/
        ├── init.tcl                # Standard (keep for leaf macros!)
        └── init_rv32im.tcl         # NEW - For integration
```

### Step 1: Create Integration RTL

Create `sky130_cds/synth/hdl/rv32im_integrated/rv32im_integrated_macro.v`:

```verilog
//===============================================================================
// RV32IM Integrated Macro
// Integrates: core_macro + mdu_macro
//===============================================================================

module rv32im_integrated_macro (
    // Clock and reset
    input  wire        clk,
    input  wire        rst_n,

    // Instruction interface
    input  wire [31:0] instruction,

    // Data memory interface
    input  wire [31:0] data_in,
    output wire [31:0] data_out,
    output wire [31:0] addr_out,
    output wire        mem_write_enable,
    output wire        mem_read_enable,

    // Interrupt
    input  wire        interrupt
);

//===============================================================================
// Internal Signals (Interconnect between core and MDU)
//===============================================================================

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

//===============================================================================
// Core Macro Instance (Pre-built Black Box)
//===============================================================================

core_macro u_core_macro (
    // Clock and reset
    .clk(clk),
    .rst_n(rst_n),

    // Instruction interface
    .instruction(instruction),

    // Data memory interface
    .data_in(data_in),
    .data_out(data_out),
    .addr_out(addr_out),
    .mem_write_enable(mem_write_enable),
    .mem_read_enable(mem_read_enable),

    // MDU interface (outputs from core to MDU)
    .mdu_start(mdu_start),
    .mdu_ack(mdu_ack),
    .mdu_funct3(mdu_funct3),
    .mdu_operand_a(mdu_operand_a),
    .mdu_operand_b(mdu_operand_b),

    // MDU interface (inputs from MDU to core)
    .mdu_busy(mdu_busy),
    .mdu_done(mdu_done),
    .mdu_product(mdu_product),
    .mdu_quotient(mdu_quotient),
    .mdu_remainder(mdu_remainder),

    // Interrupt
    .interrupt(interrupt)
);

//===============================================================================
// MDU Macro Instance (Pre-built Black Box)
//===============================================================================

mdu_macro u_mdu_macro (
    // Clock and reset
    .clk(clk),
    .rst_n(rst_n),

    // Control signals from core
    .start(mdu_start),
    .ack(mdu_ack),
    .funct3(mdu_funct3),

    // Operands from core
    .operand_a(mdu_operand_a),
    .operand_b(mdu_operand_b),

    // Status to core
    .busy(mdu_busy),
    .done(mdu_done),

    // Results to core
    .product(mdu_product),
    .quotient(mdu_quotient),
    .remainder(mdu_remainder)
);

endmodule
```

### Step 2: Create Integration Synthesis Script

Create `sky130_cds/synth/genus_script_rv32im.tcl`:

```tcl
#===============================================================================
# Genus Synthesis Script for rv32im_integrated_macro
# Integrates pre-built core_macro + mdu_macro
#===============================================================================

set DESIGN "rv32im_integrated_macro"

# Paths
set LIB_PATH "../sky130_osu_sc_t18"
set HDL_PATH "hdl/rv32im_integrated"
set MACRO_DIR "../pnr/outputs"  # Where pre-built macros are

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
# NEW: Read Pre-Built Macro Netlists (Black Boxes)
#===============================================================================

puts "==> Reading pre-built macro netlists..."

# Read core_macro netlist
if {[file exists "${MACRO_DIR}/core_macro/core_macro_netlist.v"]} {
    read_hdl -v2001 "${MACRO_DIR}/core_macro/core_macro_netlist.v"
    puts "    ✓ core_macro netlist loaded"
} else {
    puts "ERROR: core_macro netlist not found!"
    puts "Build core_macro first: cd pnr && make all"
    exit 1
}

# Read mdu_macro netlist
if {[file exists "${MACRO_DIR}/mdu_macro/mdu_macro_netlist.v"]} {
    read_hdl -v2001 "${MACRO_DIR}/mdu_macro/mdu_macro_netlist.v"
    puts "    ✓ mdu_macro netlist loaded"
} else {
    puts "ERROR: mdu_macro netlist not found!"
    puts "Build mdu_macro first: cd pnr && make all"
    exit 1
}

#===============================================================================
# Read Top-Level Integration RTL
#===============================================================================

puts "==> Reading integration RTL..."
read_hdl -v2001 {
    rv32im_integrated_macro.v
}

#===============================================================================
# Elaborate
#===============================================================================

puts "==> Elaborating design..."
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
catch {read_sdc "${MACRO_DIR}/core_macro/core_macro.sdc"}
catch {read_sdc "${MACRO_DIR}/mdu_macro/mdu_macro.sdc"}

# Read top-level constraints
if {[file exists "constraints/rv32im_integrated.sdc"]} {
    read_sdc "constraints/rv32im_integrated.sdc"
} else {
    # Default constraints
    create_clock -period 10.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    set_output_delay 2.0 -clock clk [all_outputs]
}

#===============================================================================
# Synthesis (Only Glue Logic!)
#===============================================================================

puts "==> Running synthesis (glue logic only)..."

set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# This will only synthesize the wires connecting the macros
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

#===============================================================================
# Write Outputs
#===============================================================================

puts "==> Writing outputs..."

exec mkdir -p outputs/rv32im_integrated

write_hdl > outputs/rv32im_integrated/${DESIGN}.vh
write_sdc > outputs/rv32im_integrated/${DESIGN}.sdc
write_sdf > outputs/rv32im_integrated/${DESIGN}.sdf

puts ""
puts "========================================="
puts "RV32IM Integration Synthesis Complete!"
puts "========================================="
puts ""
puts "Next: Run P&R with setup_rv32im.tcl"
puts ""

exit
```

### Step 3: Create Integration P&R Setup

Create `sky130_cds/pnr/setup_rv32im.tcl`:

```tcl
#===============================================================================
# Setup for rv32im_integrated_macro P&R
# Reads pre-built macro LEF files
#===============================================================================

set DESIGN "rv32im_integrated_macro"
set LIB_PATH "../sky130_osu_sc_t18"
set MACRO_DIR "outputs"  # Where macro LEF files are

#===============================================================================
# MMMC Setup (Same as standard flow)
#===============================================================================

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
# Read Technology LEF
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
if {[file exists "${MACRO_DIR}/core_macro/core_macro.lef"]} {
    read_physical -lef "${MACRO_DIR}/core_macro/core_macro.lef"
    puts "    ✓ core_macro LEF loaded"
} else {
    puts "ERROR: core_macro.lef not found!"
    exit 1
}

# Read mdu_macro LEF
if {[file exists "${MACRO_DIR}/mdu_macro/mdu_macro.lef"]} {
    read_physical -lef "${MACRO_DIR}/mdu_macro/mdu_macro.lef"
    puts "    ✓ mdu_macro LEF loaded"
} else {
    puts "ERROR: mdu_macro.lef not found!"
    exit 1
}

#===============================================================================
# Read Netlist and Initialize
#===============================================================================

puts "==> Reading integrated netlist..."

read_netlist "../synth/outputs/rv32im_integrated/${DESIGN}.vh"

init_design -setup {setup_func} -hold {hold_func}

puts ""
puts "Setup complete!"
puts ""
```

### Step 4: Create Integration Init Script

Create `sky130_cds/pnr/SCRIPTS/init_rv32im.tcl`:

```tcl
#===============================================================================
# Init Script for rv32im_integrated_macro
# Places pre-built macros as fixed blocks
#===============================================================================

source setup_rv32im.tcl

#===============================================================================
# Create Floorplan (Larger to fit macros!)
#===============================================================================

puts "==> Creating floorplan..."

# Size based on macro dimensions + margins
# Example: 350µm x 300µm with 10µm margins
floorPlan -site unithd -s 350.0 300.0 10.0 10.0 10.0 10.0

puts "Floorplan created: 350µm x 300µm"

#===============================================================================
# NEW: Place Pre-Built Macros as Fixed Blocks
#===============================================================================

puts "==> Placing pre-built macros..."

# Get macro sizes for verification
set core_bbox [get_db [get_db insts u_core_macro] .bbox]
set mdu_bbox [get_db [get_db insts u_mdu_macro] .bbox]

puts "Core macro bbox: $core_bbox"
puts "MDU macro bbox: $mdu_bbox"

# Place core_macro on the left
placeInstance u_core_macro 30.0 50.0 -fixed

# Place mdu_macro on the right
placeInstance u_mdu_macro 200.0 50.0 -fixed

puts "    ✓ core_macro placed at (30.0, 50.0)"
puts "    ✓ mdu_macro placed at (200.0, 50.0)"

# Verify no overlap
verifyGeometry -noRoutingBlkg

#===============================================================================
# Power Planning
#===============================================================================

puts "==> Creating power distribution..."

# Global net connections
globalNetConnect VDD -type pgpin -pin vdd -inst *
globalNetConnect VSS -type pgpin -pin gnd -inst *

# Power rings
addRing -nets {VDD VSS} \
        -type core_rings \
        -follow io \
        -layer {top met1 bottom met1 left met2 right met2} \
        -width 2.0 \
        -spacing 1.0 \
        -offset 2.0

# Power stripes
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

#===============================================================================
# Save Database
#===============================================================================

exec mkdir -p DBS/rv32im_integrated
saveDesign DBS/rv32im_integrated/init.enc

puts ""
puts "========================================="
puts "Init Complete for RV32IM Integration"
puts "========================================="
puts ""
puts "Macros placed:"
puts "  u_core_macro: Fixed at (30.0, 50.0)"
puts "  u_mdu_macro:  Fixed at (200.0, 50.0)"
puts ""
```

### Step 5: Create Integration Makefile

Create `sky130_cds/pnr/Makefile.rv32im`:

```makefile
#===============================================================================
# Makefile for rv32im_integrated_macro
#===============================================================================

DESIGN = rv32im_integrated_macro
SCRIPTS_DIR = SCRIPTS

.PHONY: all init place cts route signoff clean help

all: init place cts route signoff

init:
	@echo "=== Initializing RV32IM Integrated Macro ==="
	innovus -init $(SCRIPTS_DIR)/init_rv32im.tcl -log LOG/rv32im_init.log

place:
	@echo "=== Placing Design (Glue Logic Only) ==="
	@echo "restoreDesign DBS/rv32im_integrated/init.enc $(DESIGN)" > .tmp_place.tcl
	@echo "setPlaceMode -fp false -maxRouteLayer 5" >> .tmp_place.tcl
	@echo "placeDesign -inPlaceOpt -noPrePlaceOpt" >> .tmp_place.tcl
	@echo "optDesign -preCTS -incr" >> .tmp_place.tcl
	@echo "saveDesign DBS/rv32im_integrated/place.enc" >> .tmp_place.tcl
	@echo "exit" >> .tmp_place.tcl
	innovus -init .tmp_place.tcl -log LOG/rv32im_place.log
	@rm .tmp_place.tcl

cts:
	@echo "=== Clock Tree Synthesis ==="
	@echo "restoreDesign DBS/rv32im_integrated/place.enc $(DESIGN)" > .tmp_cts.tcl
	@echo "create_ccopt_clock_tree_spec" >> .tmp_cts.tcl
	@echo "set_ccopt_property target_max_trans 0.5" >> .tmp_cts.tcl
	@echo "set_ccopt_property target_skew 0.1" >> .tmp_cts.tcl
	@echo "catch {ccopt_design}" >> .tmp_cts.tcl
	@echo "optDesign -postCTS -incr" >> .tmp_cts.tcl
	@echo "saveDesign DBS/rv32im_integrated/cts.enc" >> .tmp_cts.tcl
	@echo "exit" >> .tmp_cts.tcl
	innovus -init .tmp_cts.tcl -log LOG/rv32im_cts.log
	@rm .tmp_cts.tcl

route:
	@echo "=== Routing Design ==="
	@echo "restoreDesign DBS/rv32im_integrated/cts.enc $(DESIGN)" > .tmp_route.tcl
	@echo "setNanoRouteMode -routeWithTimingDriven true" >> .tmp_route.tcl
	@echo "setNanoRouteMode -routeWithSiDriven true" >> .tmp_route.tcl
	@echo "globalRoute" >> .tmp_route.tcl
	@echo "detailRoute" >> .tmp_route.tcl
	@echo "optDesign -postRoute -incr" >> .tmp_route.tcl
	@echo "saveDesign DBS/rv32im_integrated/route.enc" >> .tmp_route.tcl
	@echo "exit" >> .tmp_route.tcl
	innovus -init .tmp_route.tcl -log LOG/rv32im_route.log
	@rm .tmp_route.tcl

signoff:
	@echo "=== Signoff and GDS Generation ==="
	@echo "restoreDesign DBS/rv32im_integrated/route.enc $(DESIGN)" > .tmp_signoff.tcl
	@echo "setExtractMode -engine postRoute" >> .tmp_signoff.tcl
	@echo "extractRC" >> .tmp_signoff.tcl
	@echo "timeDesign -postRoute -si" >> .tmp_signoff.tcl
	@echo "exec mkdir -p outputs/rv32im_integrated" >> .tmp_signoff.tcl
	@echo "write_lef_abstract -5.7 outputs/rv32im_integrated/rv32im_integrated_macro.lef" >> .tmp_signoff.tcl
	@echo "saveNetlist outputs/rv32im_integrated/rv32im_integrated_macro_netlist.v -excludeLeafCell" >> .tmp_signoff.tcl
	@echo "write_sdc outputs/rv32im_integrated/rv32im_integrated_macro.sdc" >> .tmp_signoff.tcl
	@echo "streamOut outputs/rv32im_integrated/rv32im_integrated_macro.gds \\" >> .tmp_signoff.tcl
	@echo "    -mapFile ../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map \\" >> .tmp_signoff.tcl
	@echo "    -merge {outputs/core_macro/core_macro.gds outputs/mdu_macro/mdu_macro.gds} \\" >> .tmp_signoff.tcl
	@echo "    -stripes 1 -units 1000 -mode ALL" >> .tmp_signoff.tcl
	@echo "saveDesign DBS/rv32im_integrated/signoff.enc" >> .tmp_signoff.tcl
	@echo "exit" >> .tmp_signoff.tcl
	innovus -init .tmp_signoff.tcl -log LOG/rv32im_signoff.log
	@rm .tmp_signoff.tcl

clean:
	rm -rf DBS/rv32im_integrated RPT/rv32im_integrated LOG/rv32im_*.log outputs/rv32im_integrated .tmp_*.tcl

help:
	@echo "Makefile for rv32im_integrated_macro"
	@echo "Targets:"
	@echo "  make init    - Initialize and place macros"
	@echo "  make place   - Place glue logic"
	@echo "  make cts     - Clock tree synthesis"
	@echo "  make route   - Route design"
	@echo "  make signoff - Generate LEF/netlist/GDS"
	@echo "  make all     - Run complete flow"
```

### Step 6: Run Integration

```bash
cd sky130_cds/synth

# Synthesis
genus -batch -files genus_script_rv32im.tcl -log rv32im_synth.log

cd ../pnr

# P&R
make -f Makefile.rv32im all

# Check results
ls -lh outputs/rv32im_integrated/
# Should see: rv32im_integrated_macro.lef, .gds, _netlist.v
```

---

## Part 3: Level 2 Integration (Top-Level SOC)

Now integrate everything into the final SOC!

### Example: rv32imz_soc_macro (rv32im + peripherals + memory)

**Create Integration RTL:**

`sky130_cds/synth/hdl/soc_integrated/rv32imz_soc_macro.v`:

```verilog
//===============================================================================
// RV32IMZ SOC Top-Level Macro
// Integrates: rv32im_integrated + peripheral_subsystem + memory
//===============================================================================

module rv32imz_soc_macro (
    // Clock and reset
    input  wire        clk,
    input  wire        rst_n,

    // External memory interface
    input  wire [31:0] ext_mem_data_in,
    output wire [31:0] ext_mem_data_out,
    output wire [31:0] ext_mem_addr,
    output wire        ext_mem_write_en,
    output wire        ext_mem_read_en,

    // Peripheral I/O
    input  wire [7:0]  gpio_in,
    output wire [7:0]  gpio_out,

    // UART
    input  wire        uart_rx,
    output wire        uart_tx,

    // SPI
    output wire        spi_sck,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire        spi_ss,

    // ADC
    input  wire [11:0] adc_data,
    output wire        adc_sample,

    // PWM
    output wire [3:0]  pwm_out,

    // Interrupts
    input  wire        external_interrupt
);

//===============================================================================
// Internal Buses
//===============================================================================

// Instruction bus (from memory to processor)
wire [31:0] instruction;

// Data bus (processor to memory)
wire [31:0] proc_data_out;
wire [31:0] proc_data_in;
wire [31:0] proc_addr;
wire        proc_mem_write;
wire        proc_mem_read;

// Peripheral bus
wire [31:0] periph_data_out;
wire [31:0] periph_addr;
wire        periph_write_en;
wire        periph_read_en;

//===============================================================================
// RV32IM Integrated Macro Instance (Pre-built)
//===============================================================================

rv32im_integrated_macro u_rv32im_core (
    .clk(clk),
    .rst_n(rst_n),

    // Instruction interface (from memory)
    .instruction(instruction),

    // Data memory interface
    .data_in(proc_data_in),
    .data_out(proc_data_out),
    .addr_out(proc_addr),
    .mem_write_enable(proc_mem_write),
    .mem_read_enable(proc_mem_read),

    // Interrupt
    .interrupt(external_interrupt)
);

//===============================================================================
// Memory Macro Instance (Pre-built)
//===============================================================================

memory_macro u_memory (
    .clk(clk),
    .rst_n(rst_n),

    // Instruction port
    .instr_addr(proc_addr[15:2]),  // Word-aligned
    .instr_data(instruction),

    // Data port
    .data_addr(proc_addr[15:2]),
    .data_in(proc_data_out),
    .data_out(proc_data_in),
    .data_write_en(proc_mem_write),
    .data_read_en(proc_mem_read),

    // External memory interface
    .ext_mem_data_in(ext_mem_data_in),
    .ext_mem_data_out(ext_mem_data_out),
    .ext_mem_addr(ext_mem_addr),
    .ext_mem_write_en(ext_mem_write_en),
    .ext_mem_read_en(ext_mem_read_en)
);

//===============================================================================
// Peripheral Subsystem Macro Instance (Pre-built)
//===============================================================================

peripheral_subsystem_macro u_peripherals (
    .clk(clk),
    .rst_n(rst_n),

    // Processor interface
    .addr(periph_addr),
    .data_in(proc_data_out),
    .data_out(periph_data_out),
    .write_en(periph_write_en),
    .read_en(periph_read_en),

    // GPIO
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),

    // UART
    .uart_rx(uart_rx),
    .uart_tx(uart_tx),

    // SPI
    .spi_sck(spi_sck),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_ss(spi_ss),

    // ADC
    .adc_data(adc_data),
    .adc_sample(adc_sample),

    // PWM
    .pwm_out(pwm_out)
);

//===============================================================================
// Address Decoding (Simple Example)
//===============================================================================

// Memory mapped I/O: 0x8000_0000 and above goes to peripherals
assign periph_write_en = proc_mem_write && proc_addr[31];
assign periph_read_en  = proc_mem_read && proc_addr[31];
assign periph_addr     = proc_addr;

endmodule
```

**Create Synthesis Script:**

`sky130_cds/synth/genus_script_soc.tcl`:

```tcl
#===============================================================================
# Genus Synthesis Script for rv32imz_soc_macro
# Integrates: rv32im_integrated + peripheral_subsystem + memory
#===============================================================================

set DESIGN "rv32imz_soc_macro"

set LIB_PATH "../sky130_osu_sc_t18"
set HDL_PATH "hdl/soc_integrated"
set MACRO_DIR "../pnr/outputs"

#===============================================================================
# Library Setup
#===============================================================================

set_db init_lib_search_path "$LIB_PATH/lib $LIB_PATH/lef"
set_db init_hdl_search_path $HDL_PATH

read_libs "$LIB_PATH/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"

read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T_tech.lef"
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T.lef"

#===============================================================================
# Read ALL Pre-Built Macro Netlists
#===============================================================================

puts "==> Reading pre-built macro netlists..."

# Level 1 integrated macros
read_hdl -v2001 "${MACRO_DIR}/rv32im_integrated/rv32im_integrated_macro_netlist.v"
puts "    ✓ rv32im_integrated loaded"

# Leaf macros (for peripheral subsystem)
read_hdl -v2001 "${MACRO_DIR}/memory_macro/memory_macro_netlist.v"
puts "    ✓ memory_macro loaded"

read_hdl -v2001 "${MACRO_DIR}/peripheral_subsystem/peripheral_subsystem_netlist.v"
puts "    ✓ peripheral_subsystem loaded"

#===============================================================================
# Read Top-Level RTL
#===============================================================================

read_hdl -v2001 {
    rv32imz_soc_macro.v
}

elaborate $DESIGN
check_design -unresolved

#===============================================================================
# Mark ALL Macros as Black Boxes
#===============================================================================

puts "==> Setting macros as black boxes..."

foreach macro {rv32im_integrated_macro memory_macro peripheral_subsystem_macro} {
    if {[llength [get_db designs $macro]] > 0} {
        set_db [get_db designs $macro] .preserve true
        set_dont_touch [get_db designs $macro]
        puts "    ✓ $macro marked as black box"
    }
}

#===============================================================================
# Constraints
#===============================================================================

# Read constraints from sub-macros
catch {read_sdc "${MACRO_DIR}/rv32im_integrated/rv32im_integrated_macro.sdc"}
catch {read_sdc "${MACRO_DIR}/memory_macro/memory_macro.sdc"}
catch {read_sdc "${MACRO_DIR}/peripheral_subsystem/peripheral_subsystem.sdc"}

# Top-level constraints
if {[file exists "constraints/soc_integrated.sdc"]} {
    read_sdc "constraints/soc_integrated.sdc"
} else {
    create_clock -period 10.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    set_output_delay 2.0 -clock clk [all_outputs]
}

#===============================================================================
# Synthesis
#===============================================================================

syn_generic
syn_map
syn_opt

#===============================================================================
# Write Outputs
#===============================================================================

exec mkdir -p outputs/soc_integrated

write_hdl > outputs/soc_integrated/${DESIGN}.vh
write_sdc > outputs/soc_integrated/${DESIGN}.sdc

puts "SOC Integration Synthesis Complete!"
exit
```

**Create P&R Makefile:**

`sky130_cds/pnr/Makefile.soc`:

```makefile
DESIGN = rv32imz_soc_macro

all: init place cts route signoff

init:
	@echo "=== SOC Init ==="
	innovus -init SCRIPTS/init_soc.tcl -log LOG/soc_init.log

# ... (similar targets as Makefile.rv32im, but for soc) ...

signoff:
	@echo "=== SOC Signoff ==="
	@echo "restoreDesign DBS/soc_integrated/route.enc $(DESIGN)" > .tmp_signoff.tcl
	@echo "streamOut outputs/soc_integrated/rv32imz_soc_macro.gds \\" >> .tmp_signoff.tcl
	@echo "    -merge { \\" >> .tmp_signoff.tcl
	@echo "        outputs/rv32im_integrated/rv32im_integrated_macro.gds \\" >> .tmp_signoff.tcl
	@echo "        outputs/memory_macro/memory_macro.gds \\" >> .tmp_signoff.tcl
	@echo "        outputs/peripheral_subsystem/peripheral_subsystem.gds \\" >> .tmp_signoff.tcl
	@echo "    } \\" >> .tmp_signoff.tcl
	@echo "    -stripes 1 -units 1000 -mode ALL" >> .tmp_signoff.tcl
	@echo "exit" >> .tmp_signoff.tcl
	innovus -init .tmp_signoff.tcl -log LOG/soc_signoff.log
```

---

## Part 4: Complete Workflow Summary

Here's the **complete build sequence**:

```bash
#===============================================================================
# LEVEL 0: Build All Leaf Macros (Standard sky130_cds - UNCHANGED!)
#===============================================================================

cd sky130_cds

# Build core_macro
cd synth
# Update genus_script.tcl for core_macro
make synth
cd ../pnr
make all
# Generate integration files in Innovus

# Build mdu_macro
cd ../synth
# Update genus_script.tcl for mdu_macro
make synth
cd ../pnr
make all
# Generate integration files in Innovus

# Repeat for ALL leaf macros:
# - memory_macro
# - communication_macro
# - protection_macro
# - adc_subsystem_macro
# - pwm_accelerator_macro

#===============================================================================
# LEVEL 1: Build Integrated Subsystems (NEW Integration Scripts)
#===============================================================================

# Build rv32im_integrated_macro (core + mdu)
cd synth
genus -batch -files genus_script_rv32im.tcl
cd ../pnr
make -f Makefile.rv32im all

# Build peripheral_subsystem_macro (communication + protection + adc + pwm)
cd ../synth
genus -batch -files genus_script_periph.tcl
cd ../pnr
make -f Makefile.periph all

#===============================================================================
# LEVEL 2: Build Top-Level SOC (NEW Integration Scripts)
#===============================================================================

# Build rv32imz_soc_macro (rv32im_integrated + peripheral_subsystem + memory)
cd synth
genus -batch -files genus_script_soc.tcl
cd ../pnr
make -f Makefile.soc all

#===============================================================================
# DONE! Final GDS with ALL macros merged
#===============================================================================

ls -lh pnr/outputs/soc_integrated/rv32imz_soc_macro.gds
```

---

## Part 5: Automated Build System

Create a master Makefile to automate everything!

`sky130_cds/Makefile`:

```makefile
#===============================================================================
# Master Makefile for Complete SOC Build
#===============================================================================

# Define all macros by level
LEAF_MACROS = core mdu memory communication protection adc_subsystem pwm_accelerator
L1_MACROS = rv32im_integrated peripheral_subsystem
SOC_MACRO = soc_integrated

.PHONY: all leaf level1 soc clean help

all: leaf level1 soc
	@echo ""
	@echo "========================================="
	@echo "Complete SOC Build Finished!"
	@echo "========================================="
	@echo "Final GDS: pnr/outputs/soc_integrated/rv32imz_soc_macro.gds"
	@echo ""

#===============================================================================
# Level 0: Leaf Macros (Standard Flow)
#===============================================================================

leaf:
	@echo "========================================="
	@echo "Building Level 0: Leaf Macros"
	@echo "========================================="
	@for macro in $(LEAF_MACROS); do \
		echo ""; \
		echo "=== Building $$macro ==="; \
		cd synth && make synth DESIGN=$$macro && cd ..; \
		cd pnr && make all DESIGN=$$macro && cd ..; \
	done
	@echo "All leaf macros built!"

#===============================================================================
# Level 1: Integrated Subsystems (Integration Flow)
#===============================================================================

level1: leaf
	@echo "========================================="
	@echo "Building Level 1: Integrated Subsystems"
	@echo "========================================="
	@echo "=== Building rv32im_integrated ==="
	cd synth && genus -batch -files genus_script_rv32im.tcl && cd ..
	cd pnr && make -f Makefile.rv32im all && cd ..
	@echo ""
	@echo "=== Building peripheral_subsystem ==="
	cd synth && genus -batch -files genus_script_periph.tcl && cd ..
	cd pnr && make -f Makefile.periph all && cd ..
	@echo "Level 1 integration complete!"

#===============================================================================
# Level 2: Top-Level SOC (SOC Integration)
#===============================================================================

soc: level1
	@echo "========================================="
	@echo "Building Level 2: Top-Level SOC"
	@echo "========================================="
	cd synth && genus -batch -files genus_script_soc.tcl && cd ..
	cd pnr && make -f Makefile.soc all && cd ..
	@echo "SOC integration complete!"

#===============================================================================
# Utilities
#===============================================================================

clean:
	@echo "Cleaning all build artifacts..."
	cd synth && rm -rf *.vh *.sdc outputs/* reports/* *.log* && cd ..
	cd pnr && rm -rf DBS/* RPT/* LOG/* outputs/* .tmp_*.tcl && cd ..
	@echo "Clean complete!"

help:
	@echo "RV32IMZ Complete SOC Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make all     - Build complete SOC (all levels)"
	@echo "  make leaf    - Build leaf macros only"
	@echo "  make level1  - Build level 1 integrated subsystems"
	@echo "  make soc     - Build top-level SOC"
	@echo "  make clean   - Clean all build artifacts"
	@echo ""
	@echo "Macro Hierarchy:"
	@echo "  Level 0 (Leaf):  $(LEAF_MACROS)"
	@echo "  Level 1 (Integrated): $(L1_MACROS)"
	@echo "  Level 2 (SOC):   $(SOC_MACRO)"
```

**Usage:**

```bash
cd sky130_cds

# Build everything at once!
make all

# Or build level by level
make leaf       # Build all leaf macros
make level1     # Build integrated subsystems
make soc        # Build final SOC

# Clean everything
make clean
```

---

## Summary: What Files to Keep vs. Add

### ✅ KEEP (Standard sky130_cds files - UNCHANGED!)
```
sky130_cds/
├── synth/
│   ├── Makefile             # Keep for leaf macros
│   └── genus_script.tcl     # Keep for leaf macros
└── pnr/
    ├── Makefile             # Keep for leaf macros
    ├── setup.tcl            # Keep for leaf macros
    └── SCRIPTS/
        └── init.tcl         # Keep for leaf macros
```

### ✨ ADD (New integration files)
```
sky130_cds/
├── Makefile                        # NEW - Master build automation
├── synth/
│   ├── genus_script_rv32im.tcl    # NEW - RV32IM integration
│   ├── genus_script_periph.tcl    # NEW - Peripheral integration
│   ├── genus_script_soc.tcl       # NEW - SOC integration
│   └── hdl/
│       ├── rv32im_integrated/     # NEW - Integration RTL
│       ├── periph_integrated/     # NEW - Integration RTL
│       └── soc_integrated/        # NEW - Integration RTL
└── pnr/
    ├── setup_rv32im.tcl           # NEW - RV32IM setup
    ├── setup_periph.tcl           # NEW - Peripheral setup
    ├── setup_soc.tcl              # NEW - SOC setup
    ├── Makefile.rv32im            # NEW - RV32IM build
    ├── Makefile.periph            # NEW - Peripheral build
    ├── Makefile.soc               # NEW - SOC build
    └── SCRIPTS/
        ├── init_rv32im.tcl        # NEW - RV32IM init
        ├── init_periph.tcl        # NEW - Peripheral init
        └── init_soc.tcl           # NEW - SOC init
```

---

## Key Takeaways

1. **Standard sky130_cds Makefiles work perfectly for leaf macros** ✅
   - Use `make synth` and `make all` as-is
   - No modifications needed!

2. **Add new scripts for integration** ✨
   - Create `*_integrated.tcl` scripts
   - Keep standard scripts unchanged

3. **Multi-level hierarchy works seamlessly** 🎯
   - Level 0: Standard flow
   - Level 1: Integration flow
   - Level 2: SOC integration flow

4. **Master Makefile automates everything** 🚀
   - `make all` builds the entire SOC
   - Handles dependencies automatically

5. **Final GDS includes all macros merged** 📦
   - Use `-merge` flag in `streamOut`
   - One complete GDS file with full chip

---

## You're All Set! 🎉

You can now:
- ✅ Build leaf macros with standard `make synth` and `make pr`
- ✅ Integrate hierarchically with new `*_integrated.tcl` scripts
- ✅ Build the complete SOC with `make all`
- ✅ Get a final merged GDS with all macros included

**No changes to standard sky130_cds infrastructure needed!**
