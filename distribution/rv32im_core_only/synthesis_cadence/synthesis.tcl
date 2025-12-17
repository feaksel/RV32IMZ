#===============================================================================
# Cadence Genus Synthesis Script
# For: Custom RISC-V Core (RV32IM)
# Target: School technology library
#===============================================================================

# Paths relative to synthesis_cadence/ directory
set TECH_LIB_PATH "../pdk/sky130A/libs.ref"
set RTL_PATH "../rtl"
set SRAM_LIB_PATH "$TECH_LIB_PATH/sky130_sram_macros"

#===============================================================================
# Setup
#===============================================================================

# Set search paths
set_db init_lib_search_path $TECH_LIB_PATH
set_db init_hdl_search_path $RTL_PATH

# Read technology libraries
read_libs $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib
read_libs $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib  
read_libs $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_100C_1v95.lib
# Read SRAM macro library
read_libs $SRAM_LIB_PATH/sky130_sram_macros.lib

#===============================================================================
# Read RTL
#===============================================================================

puts "Reading RTL files..."

# Read SRAM macro models first
read_hdl -v2001 $SRAM_LIB_PATH/sky130_sram_2kbyte_1rw1r_32x512_8.v

# Read complete core design (core only)
read_hdl -v2001 {
    $RTL_PATH/riscv_defines.vh
    $RTL_PATH/alu.v
    $RTL_PATH/regfile.v  
    $RTL_PATH/decoder.v
    $RTL_PATH/mdu.v
    $RTL_PATH/csr_unit.v
    $RTL_PATH/exception_unit.v
    $RTL_PATH/interrupt_controller.v
    $RTL_PATH/custom_riscv_core.v
}

# Or read the top level which includes others
# read_hdl -sv custom_core_wrapper.v

#===============================================================================
# Elaborate Design
#===============================================================================

puts "Elaborating design..."
elaborate custom_riscv_core

# Check design
check_design -unresolved

#===============================================================================
# Constraints
#===============================================================================

puts "Applying constraints..."

# Clock definition (100 MHz = 10ns period)
# Adjust if your design doesn't meet timing
create_clock -name clk -period 10.0 [get_ports clk]

# If timing doesn't meet, try:
# create_clock -name clk -period 12.5 [get_ports clk]  # 80 MHz
# create_clock -name clk -period 20.0 [get_ports clk]  # 50 MHz

# Input/Output delays (20% of clock period is typical)
set_input_delay 2.0 -clock clk [all_inputs]
set_output_delay 2.0 -clock clk [all_outputs]

# Don't apply delay to clock
set_input_delay 0.0 -clock clk [get_ports clk]

# Set driving cell (update based on your library)
# set_driving_cell -lib_cell BUFX2 [all_inputs]

# Set load (update based on your library)
# set_load 0.1 [all_outputs]

# Set max transition time
set_max_transition 0.5 [current_design]

# Set max fanout
set_max_fanout 16 [current_design]

# Operating conditions (if needed)
# set_operating_conditions -max slow -min fast

#===============================================================================
# Synthesis Settings
#===============================================================================

puts "Setting synthesis options..."

# Effort levels (high for best results)
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# Enable area optimization
set_db syn_opt_area true

# Enable timing optimization
set_db syn_opt_timing true

# Enable power optimization (optional)
# set_db syn_opt_power true

# Map effort for better QoR
set_db lp_insert_clock_gating true  # Clock gating for power

#===============================================================================
# Synthesize
#===============================================================================

puts "Running generic synthesis..."
syn_generic

puts "Running mapping..."
syn_map

puts "Running optimization..."
syn_opt

#===============================================================================
# Reports
#===============================================================================

puts "Generating reports..."

# Create reports directory
exec mkdir -p reports

# Area report
report_area > reports/area.rpt
report_gates > reports/gates.rpt

# Timing report
report_timing -nworst 10 > reports/timing.rpt
report_timing -nworst 10 -path_type full > reports/timing_full.rpt

# Power report
report_power > reports/power.rpt

# QoR summary
report_qor > reports/qor.rpt

# Design hierarchy
report_hierarchy > reports/hierarchy.rpt

# Clock report
report_clock > reports/clock.rpt

#===============================================================================
# Write Outputs
#===============================================================================

puts "Writing outputs..."

# Create outputs directory
exec mkdir -p outputs

# Write gate-level netlist
write_hdl > outputs/core_netlist.v

# Write SDC constraints for P&R
write_sdc > outputs/core_constraints.sdc

# Write design database for Innovus
write_design -innovus outputs/core_design

# Write SDF (for timing simulation)
# write_sdf > outputs/timing.sdf

#===============================================================================
# Summary
#===============================================================================

puts "\n========================================="
puts "Synthesis Complete!"
puts "========================================="
puts ""
puts "Check the following:"
puts "  reports/area.rpt     - Area breakdown"
puts "  reports/timing.rpt   - Timing analysis"
puts "  reports/power.rpt    - Power analysis"
puts "  reports/qor.rpt      - Quality summary"
puts ""
puts "Output files:"
puts "  outputs/netlist.v    - Gate-level netlist"
puts "  outputs/constraints.sdc - Timing constraints"
puts "  outputs/design/      - Design database for Innovus"
puts ""

# Print summary statistics
report_summary

puts "\nIf timing doesn't meet:"
puts "  1. Check critical path in reports/timing.rpt"
puts "  2. Try reducing clock frequency in this script"
puts "  3. Check for combinational loops"
puts "  4. Consider pipelining critical paths"
puts ""
puts "Next step: Place & Route with Innovus"
puts "  Run: innovus -init place_route.tcl"
puts "========================================="
