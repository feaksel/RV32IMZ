# MMMC file for MDU Macro
# Multi-Mode Multi-Corner analysis setup

# Define timing libraries
create_library_set -name tt_lib -timing {../../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib}

# Define operating conditions
create_opcond -name tt_cond -process 1.0 -voltage 1.8 -temperature 25

# Define timing constraints
create_timing_condition -name tt_timing -library_sets {tt_lib} -opcond tt_cond

# Define RC corners (typical for SKY130)
create_rc_corner -name tt_rc -cap_table {../../pdk/sky130A/libs.tech/sky130_fd_sc_hd/capacitor_table.cap} \
                              -preRoute_res 1.0 -postRoute_res 1.0 -preRoute_cap 1.0 -postRoute_cap 1.0 \
                              -preRoute_xcap 1.0 -postRoute_xcap 1.0

# Define delay corner  
create_delay_corner -name tt_delay -timing_condition tt_timing -rc_corner tt_rc

# Define constraint mode
create_constraint_mode -name sdc_mode -sdc_files {../constraints/mdu_macro.sdc}

# Define analysis view
create_analysis_view -name tt_view -delay_corner tt_delay -constraint_mode sdc_mode

# Set analysis view
set_analysis_view -setup {tt_view} -hold {tt_view}