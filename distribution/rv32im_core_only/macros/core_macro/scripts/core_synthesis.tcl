# Synthesis TCL Script for Core Macro
# Handles: Pipeline, Register File, ALU, Decoder, CSR, Exception handling
# Connects to external MDU macro

#==============================================================================
# Setup and Initialization
#==============================================================================

# Set variables
set DESIGN_NAME "core_macro"
set RTL_DIR "rtl"
set LIB_DIR "/home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib"
set TECH_DIR "/home/furka/RV32IMZ/pdk/sky130A/libs.tech/openlane/sky130_fd_sc_hd"

# Create work directory
set_db init_lib_search_path [list $LIB_DIR]

# Read technology libraries
read_libs [list \
    "$LIB_DIR/sky130_fd_sc_hd__tt_025C_1v80.lib" \
    "$LIB_DIR/sky130_fd_sc_hd__ss_100C_1v60.lib" \
    "$LIB_DIR/sky130_fd_sc_hd__ff_n40C_1v95.lib" \
]

# Read LEF files
read_physical -lef [list \
    "$TECH_DIR/sky130_fd_sc_hd.tlef" \
    "$TECH_DIR/sky130_fd_sc_hd.lef" \
]

#==============================================================================
# RTL Reading and Elaboration
#==============================================================================

# Read RTL files in dependency order
read_hdl [list \
    "$RTL_DIR/core_macro.v" \
]

# Elaborate the design
elaborate $DESIGN_NAME

# Check design
check_design -unresolved

#==============================================================================
# Constraints and Timing
#==============================================================================

# Read timing constraints
read_sdc "constraints/core_macro.sdc"

# Report timing constraints
report_timing_requirements

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

# Write out the synthesized netlist
write_hdl > netlist/core_macro_syn.v

# Write out constraints for P&R
write_sdc > netlist/core_macro_syn.sdc

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
puts "Netlist written to: netlist/core_macro_syn.v"
puts "Constraints written to: netlist/core_macro_syn.sdc"
puts "=========================================="

# Exit genus
exit