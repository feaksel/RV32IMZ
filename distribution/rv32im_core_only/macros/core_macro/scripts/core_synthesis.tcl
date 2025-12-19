#===============================================================================
# Cadence Genus Synthesis Script - Core Macro
# Based on proven working synthesis.tcl
# For: Core Macro (Pipeline + Register File + ALU + Decoder + CSR + Exception)
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
# Read RTL - Core Macro Dependencies
#===============================================================================

puts "Reading RTL files..."

# Read core macro RTL (includes hierarchical dependencies)
read_hdl -v2001 {
    core_macro.v
}

#===============================================================================
# Elaborate Design
#===============================================================================

puts "Elaborating design..."
elaborate core_macro

# Check design
check_design -unresolved

#===============================================================================
# Constraints - Same as Working Script
#===============================================================================

puts "Applying constraints..."

# Read timing constraints (create basic one if not exists)
if {[file exists "../constraints/core_macro.sdc"]} {
    read_sdc ../constraints/core_macro.sdc
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
write_hdl > outputs/core_macro_netlist.v

# Write SDC constraints for P&R
write_sdc > outputs/core_macro_constraints.sdc

# Write design database for Innovus
write_design -innovus -base_name outputs/core_macro_design

#===============================================================================
# Summary - Same as Working Script
#===============================================================================

puts "\n========================================="
puts "Core Macro Synthesis Complete!"
puts "========================================="
puts ""
puts "Check the following:"
puts "  reports/area.rpt     - Area breakdown"
puts "  reports/timing.rpt   - Timing analysis"
puts "  reports/power.rpt    - Power analysis"
puts "  reports/qor.rpt      - Quality summary"
puts ""
puts "Output files:"
puts "  outputs/core_macro_netlist.v    - Gate-level netlist"
puts "  outputs/core_macro_constraints.sdc - Timing constraints"
puts "  outputs/core_macro_design/      - Design database for Innovus"
puts ""

#==============================================================================
# Synthesis Configuration
#==============================================================================

# Configure synthesis options for better timing
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# Enable useful optimizations
set_db auto_ungroup none
set_db hdl_track_filename_row_col true

# Clock gating settings for power
set_db lp_insert_clock_gating true
set_db lp_clock_gating_min_flops 4

# Set optimization goals
set_db syn_opt_area_map_effort high

#==============================================================================
# Synthesis Execution
#==============================================================================

# Generic synthesis
syn_generic

# Check intermediate design
check_design -all

# Technology mapping
syn_map

# Check post-map design
check_design -all

# Optimization
syn_opt

# Check final design
check_design -all

#==============================================================================
# Design Analysis and Reports
#==============================================================================

# Report area
report_area > reports/core_macro_area.rpt

# Report timing
report_timing -check_type setup -max_paths 10 > reports/core_macro_setup_timing.rpt
report_timing -check_type hold -max_paths 10 > reports/core_macro_hold_timing.rpt

# Report power (estimated)
report_power > reports/core_macro_power.rpt

# Report gates and cells
report_gates > reports/core_macro_gates.rpt

# Check design rules
check_design > reports/core_macro_check_design.rpt

# Report congestion
report_dp > reports/core_macro_congestion.rpt

#==============================================================================
# Export Results
#==============================================================================

# Write out the synthesized netlist (for P&R)
write_hdl > outputs/core_macro_netlist.v

# Write netlist for hierarchical integration (used by rv32im_integrated_macro)
write_hdl > outputs/core_macro_syn.v

# Write out constraints for P&R
write_sdc > outputs/core_macro.sdc

# Write design database
write_db -to_file db/core_macro_syn.db

# Export physical data for P&R
write_design -innovus -base_name outputs/core_macro

#==============================================================================
# Summary and Cleanup
#==============================================================================

# Final timing summary
puts "=========================================="
puts "Core Macro Synthesis Complete"
puts "=========================================="

# Print summary information
puts "Design: $DESIGN_NAME"

# Get basic metrics
set cell_count [sizeof_collection [get_cells -hier]]
set net_count [sizeof_collection [get_nets -hier]]

puts "Cells: $cell_count"
puts "Nets: $net_count"

# Check for any violations
set setup_violations [get_timing_paths -slack_lesser_than 0.0 -max_paths 1]
set hold_violations [get_timing_paths -delay_type min -slack_lesser_than 0.0 -max_paths 1]

if {[sizeof_collection $setup_violations] > 0} {
    puts "WARNING: Setup violations detected!"
} else {
    puts "Setup timing: CLEAN"
}

if {[sizeof_collection $hold_violations] > 0} {
    puts "WARNING: Hold violations detected!"  
} else {
    puts "Hold timing: CLEAN"
}

puts "Synthesis database saved to: db/core_macro_syn.db"
puts "Netlist written to: outputs/core_macro_netlist.v and outputs/core_macro_syn.v"
puts "Constraints written to: outputs/core_macro.sdc"
puts "=========================================="

# Exit genus
exit