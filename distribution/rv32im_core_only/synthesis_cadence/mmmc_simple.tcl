#===============================================================================
# SINGLE CORNER MMMC (Fallback for Minimal PDK)
# Use this if the main mmmc.tcl fails
#===============================================================================

set TECH_LIB_PATH "../pdk/sky130A/libs.ref"

puts "Setting up single-corner MMMC (minimal PDK fallback)..."

# Single library set using only TT corner
create_library_set -name SINGLE_LIB \
    -timing [list $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib]

# Single delay corner
create_delay_corner -name SINGLE_CORNER \
    -library_set SINGLE_LIB

# Single constraint mode
create_constraint_mode -name FUNC_MODE \
    -sdc_files [list ../constraints/basic_timing.sdc]

# Single analysis view
create_analysis_view -name SINGLE_VIEW \
    -constraint_mode FUNC_MODE \
    -delay_corner SINGLE_CORNER

# Use same view for both setup and hold
set_analysis_view -setup {SINGLE_VIEW} \
                  -hold {SINGLE_VIEW}

puts "Single-corner MMMC setup complete"
puts "Note: Using TT corner for both setup and hold analysis"
puts "This is acceptable for academic demonstration"