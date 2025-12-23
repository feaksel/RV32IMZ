# Complete Hierarchical Macro Integration Guide

## Do You Need .lib Timing Files?

**SHORT ANSWER:** It depends on your approach.

### Two Integration Approaches

| Approach | Timing Method | Accuracy | Complexity | Recommended For |
|----------|--------------|----------|------------|-----------------|
| **A: Without .lib** | Use SDC constraints | Good enough | Simpler | Academic projects, first pass |
| **B: With .lib** | Liberty timing models | Very accurate | More complex | Production, critical timing |

**For university projects: Approach A (without .lib) is usually sufficient!**

---

## APPROACH A: Integration WITHOUT .lib Files (Recommended for University)

### How It Works

When you integrate macros without `.lib` files:

1. **Synthesis** reads the gate-level netlist and treats the macro as a **black box**
2. **P&R** places the macro using the LEF file (physical abstract)
3. **Timing** uses SDC constraints you provide to estimate macro delays

### Pros and Cons

**Pros:**
✅ Simpler workflow
✅ No need to characterize timing
✅ Faster integration
✅ Works well for first-pass designs

**Cons:**
❌ Less accurate timing (uses estimates)
❌ May have timing violations you didn't catch
❌ Can't optimize through the macro

### Files You Need Per Macro

```
mdu_macro/outputs/
├── mdu_macro.lef          # Physical abstract (REQUIRED)
├── mdu_macro_netlist.v    # Gate-level netlist (REQUIRED)
├── mdu_macro.sdc          # Timing constraints (REQUIRED)
└── mdu_macro.gds          # Layout for final GDS merge (REQUIRED)

core_macro/outputs/
├── core_macro.lef
├── core_macro_netlist.v
├── core_macro.sdc
└── core_macro.gds
```

### Complete Integration Example: rv32im_integrated_macro

This example shows how to integrate `core_macro` + `mdu_macro` into `rv32im_integrated_macro`.

#### Step 1: Prepare Your Leaf Macros

Build each macro first:

```bash
# Build core_macro
cd core_macro
genus -files scripts/core_synthesis.tcl
innovus -files scripts/core_place_route.tcl

# Generate integration files
innovus
```

In Innovus:
```tcl
restoreDesign DBS/route.enc.dat core_macro
exec mkdir -p outputs

# Generate required files
write_lef_abstract -5.7 outputs/core_macro.lef
saveNetlist outputs/core_macro_netlist.v -excludeLeafCell
write_sdc outputs/core_macro.sdc
streamOut outputs/core_macro.gds \
    -mapFile $env(PDK_ROOT)/sky130A/libs.tech/klayout/sky130A.gds.map \
    -mode ALL

exit
```

Repeat for `mdu_macro`.

#### Step 2: Create Integration RTL

Create `rv32im_integrated_macro/rtl/rv32im_integrated_macro.v`:

```verilog
module rv32im_integrated_macro (
    // Clock and reset
    input wire clk,
    input wire rst_n,

    // Core interfaces (simplified example)
    input  wire [31:0] instruction,
    input  wire [31:0] data_in,
    output wire [31:0] data_out,
    output wire [31:0] addr_out,

    // Other signals...
    input  wire        interrupt
);

//=============================================================================
// Instantiate Core Macro (Pre-built)
//=============================================================================

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

core_macro u_core_macro (
    .clk(clk),
    .rst_n(rst_n),

    // Instruction/data interfaces
    .instruction(instruction),
    .data_in(data_in),
    .data_out(data_out),
    .addr_out(addr_out),

    // MDU interface
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

    // Other signals
    .interrupt(interrupt)
);

//=============================================================================
// Instantiate MDU Macro (Pre-built)
//=============================================================================

mdu_macro u_mdu_macro (
    .clk(clk),
    .rst_n(rst_n),

    // Control signals
    .start(mdu_start),
    .ack(mdu_ack),
    .funct3(mdu_funct3),

    // Operands
    .operand_a(mdu_operand_a),
    .operand_b(mdu_operand_b),

    // Results
    .busy(mdu_busy),
    .done(mdu_done),
    .product(mdu_product),
    .quotient(mdu_quotient),
    .remainder(mdu_remainder)
);

endmodule
```

#### Step 3: Synthesis Script (WITHOUT .lib files)

Create `rv32im_integrated_macro/scripts/rv32im_integrated_synthesis.tcl`:

```tcl
#===============================================================================
# Synthesis for rv32im_integrated_macro
# Integrates pre-built core_macro + mdu_macro WITHOUT .lib files
#===============================================================================

set DESIGN "rv32im_integrated_macro"

# Paths
set TECH_LIB_PATH "$env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib"
set RTL_PATH "rtl"
set MACRO_DIR ".."

#===============================================================================
# Library Setup
#===============================================================================

set_db init_lib_search_path $TECH_LIB_PATH
set_db init_hdl_search_path $RTL_PATH

# Read standard cell library (for glue logic)
read_libs ${TECH_LIB_PATH}/sky130_fd_sc_hd__tt_025C_1v80.lib

puts "==> Library loaded successfully"

#===============================================================================
# Read Pre-Built Macro Netlists (Treated as Black Boxes)
#===============================================================================

puts "Reading pre-built macro netlists..."

# Read core_macro netlist
if {[file exists "$MACRO_DIR/core_macro/outputs/core_macro_netlist.v"]} {
    read_hdl -v2001 "$MACRO_DIR/core_macro/outputs/core_macro_netlist.v"
    puts "✓ core_macro netlist loaded"
} else {
    puts "ERROR: core_macro netlist not found!"
    exit 1
}

# Read mdu_macro netlist
if {[file exists "$MACRO_DIR/mdu_macro/outputs/mdu_macro_netlist.v"]} {
    read_hdl -v2001 "$MACRO_DIR/mdu_macro/outputs/mdu_macro_netlist.v"
    puts "✓ mdu_macro netlist loaded"
} else {
    puts "ERROR: mdu_macro netlist not found!"
    exit 1
}

#===============================================================================
# Read Top-Level RTL
#===============================================================================

puts "Reading top-level RTL..."

read_hdl -v2001 {
    rv32im_integrated_macro.v
}

#===============================================================================
# Elaborate Design
#===============================================================================

puts "Elaborating design..."
elaborate $DESIGN

# Check design
check_design -unresolved

#===============================================================================
# Set Macros as BLACK BOXES (Don't Touch)
#===============================================================================

puts "Setting macros as black boxes..."

# Mark macros as black boxes (don't synthesize inside them)
set_db [get_db designs core_macro] .preserve true
set_db [get_db designs mdu_macro] .preserve true

# Don't optimize through macro boundaries
set_dont_touch [get_db designs core_macro]
set_dont_touch [get_db designs mdu_macro]

puts "✓ Macros set as black boxes"

#===============================================================================
# Apply Timing Constraints
#===============================================================================

puts "Applying timing constraints..."

# Read macro SDC files (contain macro-specific constraints)
if {[file exists "$MACRO_DIR/core_macro/outputs/core_macro.sdc"]} {
    read_sdc "$MACRO_DIR/core_macro/outputs/core_macro.sdc"
}

if {[file exists "$MACRO_DIR/mdu_macro/outputs/mdu_macro.sdc"]} {
    read_sdc "$MACRO_DIR/mdu_macro/outputs/mdu_macro.sdc"
}

# Read top-level constraints
if {[file exists "constraints/rv32im_integrated.sdc"]} {
    read_sdc "constraints/rv32im_integrated.sdc"
} else {
    # Basic constraints if no SDC
    create_clock -period 10.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    set_output_delay 2.0 -clock clk [all_outputs]
}

# CRITICAL: Set timing budgets for macro interfaces
# This tells the tool how much delay to expect through the macros

# Example: Core macro paths
set_input_delay  3.0 -clock clk [get_pins u_core_macro/instruction*]
set_output_delay 3.0 -clock clk [get_pins u_core_macro/data_out*]

# Example: MDU macro paths
set_input_delay  4.0 -clock clk [get_pins u_mdu_macro/operand*]
set_output_delay 5.0 -clock clk [get_pins u_mdu_macro/product*]

puts "✓ Constraints applied"

#===============================================================================
# Synthesis (Only Glue Logic, Macros are Black Boxes)
#===============================================================================

puts "Running synthesis..."

set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# Synthesize only the glue logic connecting the macros
syn_generic
syn_map
syn_opt

puts "✓ Synthesis complete"

#===============================================================================
# Reports
#===============================================================================

puts "Generating reports..."

exec mkdir -p reports

report_area > reports/area.rpt
report_gates > reports/gates.rpt
report_timing -nworst 10 > reports/timing.rpt
report_power > reports/power.rpt
report_qor > reports/qor.rpt

#===============================================================================
# Write Outputs
#===============================================================================

puts "Writing outputs..."

exec mkdir -p outputs

# Write netlist (contains macros as instances + glue logic)
write_hdl > outputs/rv32im_integrated_macro_syn.v

# Write constraints for P&R
write_sdc > outputs/rv32im_integrated_macro.sdc

# Write design database
write_design -innovus -base_name outputs/rv32im_integrated_macro_design

puts ""
puts "========================================="
puts "rv32im_integrated_macro Synthesis Complete!"
puts "========================================="
puts ""
puts "Next step: Place & Route with Innovus"
puts ""

exit
```

#### Step 4: Place & Route Script (WITHOUT .lib files)

Create `rv32im_integrated_macro/scripts/rv32im_integrated_place_route.tcl`:

```tcl
#===============================================================================
# Place & Route for rv32im_integrated_macro
# Integrates core_macro + mdu_macro WITHOUT .lib files
#===============================================================================

set DESIGN "rv32im_integrated_macro"
set LIB_DIR "$env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib"
set TECH_DIR "$env(PDK_ROOT)/sky130A/libs.tech/openlane/sky130_fd_sc_hd"
set MACRO_DIR ".."

#===============================================================================
# MMMC Setup (Without .lib timing models for macros)
#===============================================================================

# Create library set for standard cells only
create_library_set -name libs_tt \
    -timing [list "${LIB_DIR}/sky130_fd_sc_hd__tt_025C_1v80.lib"]

# Create RC corner
create_rc_corner -name rc_typ \
    -temperature 25 \
    -pre_route_res 1.0 \
    -pre_route_cap 1.0 \
    -post_route_res 1.0 \
    -post_route_cap 1.0

# Create delay corner
create_delay_corner -name corner_tt \
    -library_set libs_tt \
    -rc_corner rc_typ

# Read constraints (includes macro timing estimates)
create_constraint_mode -name setup_func_mode \
    -sdc_files [list "outputs/rv32im_integrated_macro.sdc"]

# Create analysis views
create_analysis_view -name setup_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

create_analysis_view -name hold_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

set_analysis_view -setup {setup_func} -hold {hold_func}

#===============================================================================
# Technology Files
#===============================================================================

puts "Loading technology files..."

read_physical -lef [list \
    "$TECH_DIR/sky130_fd_sc_hd.tlef" \
    "$TECH_DIR/sky130_fd_sc_hd.lef" \
]

#===============================================================================
# Load Pre-Built Macro LEF Files (Physical Abstracts)
#===============================================================================

puts "Loading pre-built macro LEF files..."

# Read core_macro LEF
if {[file exists "$MACRO_DIR/core_macro/outputs/core_macro.lef"]} {
    read_physical -lef "$MACRO_DIR/core_macro/outputs/core_macro.lef"
    puts "✓ core_macro LEF loaded"
} else {
    puts "ERROR: core_macro.lef not found!"
    exit 1
}

# Read mdu_macro LEF
if {[file exists "$MACRO_DIR/mdu_macro/outputs/mdu_macro.lef"]} {
    read_physical -lef "$MACRO_DIR/mdu_macro/outputs/mdu_macro.lef"
    puts "✓ mdu_macro LEF loaded"
} else {
    puts "ERROR: mdu_macro.lef not found!"
    exit 1
}

#===============================================================================
# Read Netlist and Initialize Design
#===============================================================================

puts "Reading synthesized netlist..."

read_netlist "outputs/rv32im_integrated_macro_syn.v"

init_design -setup {setup_func} -hold {hold_func}

#===============================================================================
# Floorplan - Big Enough for Both Macros
#===============================================================================

puts "Creating floorplan..."

# Create floorplan (adjust size based on your macros)
# Size: 300µm x 250µm with 10µm margins
floorPlan -site unithd -s 300.0 250.0 10.0 10.0 10.0 10.0

#===============================================================================
# Place Pre-Built Macros
#===============================================================================

puts "Placing pre-built macros..."

# Place core_macro on the left
placeInstance u_core_macro 20.0 30.0 -fixed

# Place mdu_macro on the right (adjust X based on core width)
placeInstance u_mdu_macro 180.0 30.0 -fixed

puts "✓ Macros placed as fixed blocks"

# Verify placement
report_property [get_cells u_core_macro] {origin bbox_llx bbox_lly bbox_urx bbox_ury}
report_property [get_cells u_mdu_macro] {origin bbox_llx bbox_lly bbox_urx bbox_ury}

#===============================================================================
# Apply Pin Placement (Top-Level Pins)
#===============================================================================

if {[file exists "scripts/rv32im_integrated_pin_placement.tcl"]} {
    source scripts/rv32im_integrated_pin_placement.tcl
}

#===============================================================================
# Power Planning
#===============================================================================

puts "Creating power distribution..."

# Global net connections
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *

# Power rings around core
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
          -spacing 10.0 \
          -number_of_sets 15

addStripe -nets {VDD VSS} \
          -layer met3 \
          -direction horizontal \
          -width 1.5 \
          -spacing 10.0 \
          -number_of_sets 12

# Special route to connect power
sroute -connect {blockPin padPin padRing corePin floatingStripe} \
       -layerChangeRange {met1 met3}

#===============================================================================
# Placement (Only Glue Logic, Macros are Fixed)
#===============================================================================

puts "Placing standard cells (glue logic)..."

setPlaceMode -fp false -maxRouteLayer 5

# Place only the glue logic (macros are already placed)
placeDesign -inPlaceOpt -noPrePlaceOpt

# Post-placement optimization
optDesign -preCTS -incr

#===============================================================================
# Clock Tree Synthesis
#===============================================================================

puts "Building clock tree..."

create_ccopt_clock_tree_spec

set_ccopt_property target_max_trans 0.5
set_ccopt_property target_skew 0.1

if {[catch {ccopt_design} result]} {
    puts "WARNING: CTS failed, continuing with ideal clocking"
    catch {ccopt_design}
}

optDesign -postCTS -incr

#===============================================================================
# Routing (Connects Glue Logic to Macro Pins)
#===============================================================================

puts "Routing design..."

setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven true

globalRoute
detailRoute

optDesign -postRoute -incr

#===============================================================================
# Timing Analysis
#===============================================================================

puts "Running timing analysis..."

setExtractMode -engine postRoute
extractRC

timeDesign -postRoute -si

# Reports
exec mkdir -p reports

report_timing -check_type setup -max_paths 20 > reports/rv32im_integrated_setup.rpt
report_timing -check_type hold -max_paths 20 > reports/rv32im_integrated_hold.rpt
report_area > reports/rv32im_integrated_area.rpt
summaryReport -noHtml -outFile reports/rv32im_integrated_summary.rpt

#===============================================================================
# Generate Integration Files
#===============================================================================

puts "Generating integration files..."

exec mkdir -p outputs

# LEF abstract (for next-level integration)
write_lef_abstract -5.7 outputs/rv32im_integrated_macro.lef

# Netlist
saveNetlist outputs/rv32im_integrated_macro_netlist.v -excludeLeafCell

# GDSII with merged macros
# IMPORTANT: Merge the macro GDS files!
catch {
    streamOut outputs/rv32im_integrated_macro.gds \
        -mapFile $env(PDK_ROOT)/sky130A/libs.tech/klayout/sky130A.gds.map \
        -merge [list \
            "$MACRO_DIR/core_macro/outputs/core_macro.gds" \
            "$MACRO_DIR/mdu_macro/outputs/mdu_macro.gds" \
        ] \
        -stripes 1 \
        -units 1000 \
        -mode ALL
}

puts ""
puts "========================================="
puts "rv32im_integrated_macro P&R Complete!"
puts "========================================="
puts ""
puts "Macro instances:"
puts "  u_core_macro (fixed at 20.0, 30.0)"
puts "  u_mdu_macro  (fixed at 180.0, 30.0)"
puts ""
puts "Integration files:"
puts "  outputs/rv32im_integrated_macro.lef"
puts "  outputs/rv32im_integrated_macro_netlist.v"
puts "  outputs/rv32im_integrated_macro.gds"
puts ""

exit
```

#### Step 5: Create Timing Budget SDC

Create `rv32im_integrated_macro/constraints/rv32im_integrated.sdc`:

```tcl
#===============================================================================
# Timing Constraints for rv32im_integrated_macro
# WITHOUT .lib files - using timing budgets
#===============================================================================

# Clock definition (100 MHz)
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks clk]

# Input delays
set_input_delay 2.0 -clock clk [all_inputs]
remove_input_delay [get_ports clk]
remove_input_delay [get_ports rst_n]

# Output delays
set_output_delay 2.0 -clock clk [all_outputs]

#===============================================================================
# Macro Interface Timing Budgets
# These tell Innovus how much delay to expect through each macro
#===============================================================================

# Core macro timing budget
# Assume core takes 60% of clock period for internal logic
set core_internal_delay 6.0

set_input_delay  $core_internal_delay -clock clk [get_pins u_core_macro/mdu_*] -add_delay
set_output_delay $core_internal_delay -clock clk [get_pins u_core_macro/mdu_*] -add_delay

# MDU macro timing budget
# Assume MDU takes multiple cycles (mark as multicycle path)
set_multicycle_path -setup 4 -from [get_pins u_mdu_macro/operand*] -to [get_pins u_mdu_macro/product*]
set_multicycle_path -hold 3 -from [get_pins u_mdu_macro/operand*] -to [get_pins u_mdu_macro/product*]

# False paths (asynchronous signals)
set_false_path -from [get_ports rst_n]

#===============================================================================
# Load and Drive
#===============================================================================

set_load 0.05 [all_outputs]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [all_inputs]
```

#### Step 6: Run the Integration

```bash
cd rv32im_integrated_macro

# Synthesis
genus -batch -files scripts/rv32im_integrated_synthesis.tcl -log logs/synthesis.log

# Check synthesis results
grep -i "error" logs/synthesis.log
cat reports/qor.rpt

# Place & Route
innovus -batch -files scripts/rv32im_integrated_place_route.tcl -log logs/pnr.log

# Check P&R results
grep -i "violation" logs/pnr.log
cat reports/rv32im_integrated_summary.rpt
```

---

## APPROACH B: Integration WITH .lib Files (More Accurate)

### Why Use .lib Files?

**.lib (Liberty) files** contain:
- Accurate timing arcs (delay from each input to each output)
- Power consumption data
- Pin capacitances
- Setup/hold time requirements

This gives **much more accurate timing** than estimates.

### When to Use .lib Files

Use .lib files when:
- ✅ You need accurate timing closure
- ✅ Your macros have critical timing paths
- ✅ You're preparing for tapeout
- ✅ You have time to characterize macros

### How to Generate .lib Files in Innovus

After completing P&R for a macro:

```tcl
#===============================================================================
# Generate Liberty Timing Model in Innovus
#===============================================================================

# Restore your completed design
restoreDesign DBS/signoff.enc.dat mdu_macro

# Extract parasitics
setExtractMode -engine postRoute
extractRC

# Generate .lib file
write_timing_model \
    -format lib \
    -library_name mdu_macro_lib \
    -typ_opcond \
    -views {setup_func hold_func} \
    outputs/mdu_macro.lib

puts "✓ Liberty timing model generated: outputs/mdu_macro.lib"
```

**Problem:** This generates timing for **all combinational paths** through the macro, which can take a long time for complex macros.

**Better approach:** Generate abstract timing model:

```tcl
# Generate abstract .lib (faster, simplified timing)
write_abstract_timing_model \
    -output outputs/mdu_macro.lib \
    -format lib

# This creates a simplified model with:
# - Pin-to-pin delays
# - Setup/hold times
# - Clock-to-Q delays
```

### Integration Synthesis WITH .lib Files

The synthesis script changes slightly:

```tcl
#===============================================================================
# Read Macro Timing Models (.lib files)
#===============================================================================

puts "Reading macro timing libraries..."

# Read core_macro .lib
if {[file exists "$MACRO_DIR/core_macro/outputs/core_macro.lib"]} {
    read_libs "$MACRO_DIR/core_macro/outputs/core_macro.lib"
    puts "✓ core_macro timing model loaded"
}

# Read mdu_macro .lib
if {[file exists "$MACRO_DIR/mdu_macro/outputs/mdu_macro.lib"]} {
    read_libs "$MACRO_DIR/mdu_macro/outputs/mdu_macro.lib"
    puts "✓ mdu_macro timing model loaded"
}

# Read standard cell library
read_libs "${TECH_LIB_PATH}/sky130_fd_sc_hd__tt_025C_1v80.lib"

# NOW you don't need to manually set timing budgets!
# The tool knows the actual delays through the macros
```

### Integration P&R WITH .lib Files

In the MMMC setup:

```tcl
#===============================================================================
# MMMC with Macro .lib Files
#===============================================================================

# Create library set INCLUDING macro .lib files
create_library_set -name libs_tt \
    -timing [list \
        "${LIB_DIR}/sky130_fd_sc_hd__tt_025C_1v80.lib" \
        "$MACRO_DIR/core_macro/outputs/core_macro.lib" \
        "$MACRO_DIR/mdu_macro/outputs/mdu_macro.lib" \
    ]

# Rest is the same...
```

Now Innovus will use **accurate timing** from the .lib files instead of estimates!

---

## Comparison: With vs Without .lib

| Aspect | Without .lib | With .lib |
|--------|-------------|-----------|
| **Setup effort** | Easy | Moderate (need to generate .lib) |
| **Timing accuracy** | Estimates (conservative) | Accurate (measured delays) |
| **Synthesis time** | Fast | Slower (more timing info to process) |
| **Timing closure** | May need iteration | Better first-pass results |
| **Best for** | Academic, first pass | Production, critical designs |

---

## Complete Integration Workflow Summary

### Without .lib Files (Recommended for University):

```bash
# 1. Build leaf macros
cd core_macro
genus -f scripts/core_synthesis.tcl
innovus -f scripts/core_place_route.tcl

# Generate: core_macro.lef, core_macro_netlist.v, core_macro.sdc, core_macro.gds

# 2. Build integrated macro
cd ../rv32im_integrated_macro

# Synthesis (reads netlists, treats as black boxes)
genus -f scripts/rv32im_integrated_synthesis.tcl

# P&R (reads LEF files, places macros, routes connections)
innovus -f scripts/rv32im_integrated_place_route.tcl

# Generate: rv32im_integrated_macro.lef, .v, .gds
```

### With .lib Files (For Better Timing):

```bash
# 1. Build leaf macros AND generate .lib files
cd core_macro
genus -f scripts/core_synthesis.tcl
innovus -f scripts/core_place_route.tcl

# In Innovus:
innovus
restoreDesign DBS/signoff.enc.dat core_macro
extractRC
write_timing_model -format lib -library_name core_macro_lib outputs/core_macro.lib
exit

# Generate: core_macro.lef, .v, .sdc, .gds, .lib

# 2. Build integrated macro (reads .lib for accurate timing)
cd ../rv32im_integrated_macro
genus -f scripts/rv32im_integrated_synthesis.tcl  # Reads .lib files
innovus -f scripts/rv32im_integrated_place_route.tcl  # Uses .lib timing
```

---

## Key Takeaways

1. **You DON'T strictly need .lib files** - SDC timing budgets work for academic projects

2. **.lib files give better accuracy** - Use them if you have time and need production-quality results

3. **Files required for integration (minimum):**
   - ✅ `.lef` - Physical abstract
   - ✅ `.v` - Gate-level netlist
   - ✅ `.sdc` - Timing constraints
   - ✅ `.gds` - Layout for final merge

4. **Files for better integration:**
   - ✅ All of the above PLUS
   - ✅ `.lib` - Accurate timing model

5. **Integration workflow:**
   - Read macro netlists in synthesis (black boxes)
   - Read macro LEF files in P&R (physical placement)
   - Use SDC timing budgets OR .lib timing models
   - Synthesize/place/route only the glue logic
   - Merge macro GDS into final GDS

Let me know if you want me to create complete working scripts for your specific macros!
