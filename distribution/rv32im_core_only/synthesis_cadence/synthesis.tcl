#===============================================================================
# Cadence Genus Synthesis Script
# For: Custom RISC-V Core (RV32IM)
# Target: School technology library
#===============================================================================

# Paths relative to synthesis/cadence/ directory
set TECH_LIB_PATH "../pdk/sky130A/libs.ref"
set RTL_PATH "../rtl"
set SRAM_LIB_PATH "$TECH_LIB_PATH/sky130_sram_macros"

#===============================================================================
# Setup
#===============================================================================

# Set search paths
set_db init_lib_search_path $TECH_LIB_PATH
set_db init_hdl_search_path $RTL_PATH

# ============================================================================
# LIBRARY READING - SIMPLE AND DIRECT
# ============================================================================

puts "==> Loading technology libraries..."

# Environment and debug setup
set_db information_level 7
set_db hdl_max_loop_limit 10000
# Note: library_setup_isj_for_simple_flops causes errors with stub libraries

# Read single technology library (typical corner only)
set lib_path "$TECH_LIB_PATH/sky130_fd_sc_hd/lib"

puts "==> Loading single typical corner library..."
read_libs ${lib_path}/sky130_fd_sc_hd__tt_025C_1v80.lib
puts "==> Library loaded successfully"



#===============================================================================
# Read RTL
#===============================================================================

puts "Reading RTL files..."

# Read SRAM macro models first
read_hdl -v2001 $SRAM_LIB_PATH/sky130_sram_2kbyte_1rw1r_32x512_8.v

# Read complete core design (core only)
read_hdl -v2001 {
    ../rtl/riscv_defines.vh
    ../rtl/alu.v
    ../rtl/regfile.v  
    ../rtl/decoder.v
    ../rtl/mdu.v
    ../rtl/csr_unit.v
    ../rtl/exception_unit.v
    ../rtl/interrupt_controller.v
    ../rtl/custom_riscv_core.v
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

# Read timing constraints from the constraint file
read_sdc ../constraints/basic_timing.sdc

#===============================================================================
# Synthesis Settings
#===============================================================================

puts "Setting synthesis options..."

# Effort levels (high for best results)
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high





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
report_clocks > reports/clock.rpt

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
write_design -innovus -base_name outputs/core_design

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
#report_summary

puts "\nIf timing doesn't meet:"
puts "  1. Check critical path in reports/timing.rpt"
puts "  2. Try reducing clock frequency in this script"
puts "  3. Check for combinational loops"
puts "  4. Consider pipelining critical paths"
puts ""
puts "Next step: Place & Route with Innovus"
puts "  Run: innovus -init place_route.tcl"
puts "========================================="

    
