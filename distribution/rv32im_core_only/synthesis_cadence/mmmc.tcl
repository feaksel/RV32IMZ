# Multi-Mode Multi-Corner Analysis Configuration
# For RV32IM Core with Sky130 PDK

# Define analysis views for different corners (using core constraints)
create_analysis_view -name SS_VIEW -constraint_file ../../constraints/basic_timing.sdc -library_file ../../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib

create_analysis_view -name TT_VIEW -constraint_file ../../constraints/basic_timing.sdc -library_file ../../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

create_analysis_view -name FF_VIEW -constraint_file ../../constraints/basic_timing.sdc -library_file ../../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_100C_1v95.lib

# Set analysis views
set_analysis_view -setup {SS_VIEW TT_VIEW} -hold {FF_VIEW TT_VIEW}

# Power analysis (if needed)
# create_power_analysis_view -name POWER_VIEW -constraint_file ../../constraints/soc_power.sdc