#===============================================================================
# Multi-Mode Multi-Corner Analysis Configuration
# For RV32IM Core with Sky130 PDK
# Innovus 21.1+ Compatible Syntax
#===============================================================================

set TECH_LIB_PATH "../pdk/sky130A/libs.ref"
set CONSTRAINT_PATH "../constraints"
set SRAM_LIB_PATH "$TECH_LIB_PATH/sky130_sram_macros"

#===============================================================================
# Step 1: Create Library Sets
#===============================================================================

# Slow corner (SS - slow-slow, worst setup)
create_library_set -name SS_LIB \
    -timing [list \
        $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib \
        $SRAM_LIB_PATH/sky130_sram_macros.lib]

# Typical corner (TT - typical-typical)
create_library_set -name TT_LIB \
    -timing [list \
        $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib \
        $SRAM_LIB_PATH/sky130_sram_macros.lib]

# Fast corner (FF - fast-fast, worst hold)
create_library_set -name FF_LIB \
    -timing [list \
        $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_100C_1v95.lib \
        $SRAM_LIB_PATH/sky130_sram_macros.lib]

#===============================================================================
# Step 2: Create RC Corners (optional - using default for simplicity)
#===============================================================================

# For academic project, we can use default RC or skip this step
# create_rc_corner -name RC_WORST -temperature 125
# create_rc_corner -name RC_BEST -temperature -40

#===============================================================================
# Step 3: Create Delay Corners
#===============================================================================

# Slow corner for setup analysis
create_delay_corner -name SS_CORNER \
    -library_set SS_LIB

# Typical corner
create_delay_corner -name TT_CORNER \
    -library_set TT_LIB

# Fast corner for hold analysis
create_delay_corner -name FF_CORNER \
    -library_set FF_LIB

#===============================================================================
# Step 4: Create Constraint Modes
#===============================================================================

# Functional mode with timing constraints
create_constraint_mode -name FUNC_MODE \
    -sdc_files [list $CONSTRAINT_PATH/basic_timing.sdc]

#===============================================================================
# Step 5: Create Analysis Views
#===============================================================================

# Setup analysis views (slow corners)
create_analysis_view -name SS_VIEW \
    -constraint_mode FUNC_MODE \
    -delay_corner SS_CORNER

create_analysis_view -name TT_VIEW \
    -constraint_mode FUNC_MODE \
    -delay_corner TT_CORNER

# Hold analysis view (fast corner)
create_analysis_view -name FF_VIEW \
    -constraint_mode FUNC_MODE \
    -delay_corner FF_CORNER

#===============================================================================
# Step 6: Set Analysis Views for Optimization
#===============================================================================

# Use SS and TT for setup checks, FF and TT for hold checks
set_analysis_view -setup {SS_VIEW TT_VIEW} \
                  -hold {FF_VIEW TT_VIEW}

puts "MMMC setup complete:"
puts "  Setup analysis: SS_VIEW, TT_VIEW"
puts "  Hold analysis:  FF_VIEW, TT_VIEW"
