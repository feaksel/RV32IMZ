# MMMC Setup for ADC Subsystem Macro
# Multi-Mode Multi-Corner analysis setup

set PDK_ROOT $env(PDK_ROOT)

# Define library set (typical corner)
create_library_set -name typical_libs \
    -timing [list "${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"]

# Define RC corner
create_rc_corner -name typical_rc \
    -temperature 25 \
    -cap_table "${PDK_ROOT}/sky130A/libs.tech/openlane/sky130_fd_sc_hd/sky130_fd_sc_hd.captable"

# Define delay corner
create_delay_corner -name typical_delay \
    -library_set typical_libs \
    -rc_corner typical_rc

# Define constraint mode
create_constraint_mode -name func_mode \
    -sdc_files [list "outputs/adc_subsystem_macro_constraints.sdc"]

# Define analysis view
create_analysis_view -name typical_view \
    -constraint_mode func_mode \
    -delay_corner typical_delay

# Set analysis view for setup and hold
set_analysis_view -setup typical_view -hold typical_view
