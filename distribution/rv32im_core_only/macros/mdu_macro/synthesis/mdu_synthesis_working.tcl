#===============================================================================
# Cadence Genus Synthesis Script - MDU Macro  
# Based on proven working synthesis.tcl
# For: MDU Macro (Multiply, Divide, Remainder)
#===============================================================================

# Paths (relative to macro directory)
set TECH_LIB_PATH "../../../../pdk/sky130A/libs.ref"
set RTL_PATH "../rtl"

#===============================================================================
# Setup - Based on Working Script
#===============================================================================

# Set search paths
set_db init_lib_search_path $TECH_LIB_PATH
set_db init_hdl_search_path $RTL_PATH

puts "==> Loading technology libraries..."

# Environment and debug setup
set_db information_level 7
set_db hdl_max_loop_limit 10000

# Read single technology library (typical corner only)
set lib_path "$TECH_LIB_PATH/sky130_fd_sc_hd/lib"

puts "==> Loading single typical corner library..."
read_libs ${lib_path}/sky130_fd_sc_hd__tt_025C_1v80.lib
puts "==> Library loaded successfully"

#===============================================================================
# Read RTL - MDU Macro Dependencies
#===============================================================================

puts "Reading RTL files..."

# Read MDU macro RTL
read_hdl -v2001 {
    mdu_macro.v
}

#===============================================================================
# Elaborate Design
#===============================================================================

puts "Elaborating design..."
elaborate mdu_macro

# Check design
check_design -unresolved

#===============================================================================
# Constraints - Same as Working Script
#===============================================================================

puts "Applying constraints..."

# Read timing constraints (create basic one if not exists)
if {[file exists "../constraints/mdu_macro.sdc"]} {
    read_sdc ../constraints/mdu_macro.sdc
} else {
    # Create basic clock constraint
    create_clock -period 10.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    set_output_delay 2.0 -clock clk [all_outputs]
}

#===============================================================================
# Synthesis Settings - Same as Working Script
#===============================================================================

puts "Setting synthesis options..."

# Effort levels (high for best results)
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

#===============================================================================
# Synthesize - Same Commands as Working Script
#===============================================================================

puts "Running generic synthesis..."
syn_generic

puts "Running mapping..."
syn_map

puts "Running optimization..."
syn_opt

#===============================================================================
# Reports - Same as Working Script
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
# Write Outputs - Same as Working Script
#===============================================================================

puts "Writing outputs..."

# Create outputs directory
exec mkdir -p outputs

# Write gate-level netlist
write_hdl > outputs/mdu_macro_netlist.v

# Write SDC constraints for P&R
write_sdc > outputs/mdu_macro_constraints.sdc

# Write design database for Innovus
write_design -innovus -base_name outputs/mdu_macro_design

#===============================================================================
# Summary - Same as Working Script
#===============================================================================

puts "\n========================================="
puts "MDU Macro Synthesis Complete!"
puts "========================================="
puts ""
puts "Check the following:"
puts "  reports/area.rpt     - Area breakdown"
puts "  reports/timing.rpt   - Timing analysis"
puts "  reports/power.rpt    - Power analysis"
puts "  reports/qor.rpt      - Quality summary"
puts ""
puts "Output files:"
puts "  outputs/mdu_macro_netlist.v    - Gate-level netlist"
puts "  outputs/mdu_macro_constraints.sdc - Timing constraints"
puts "  outputs/mdu_macro_design/      - Design database for Innovus"
puts ""