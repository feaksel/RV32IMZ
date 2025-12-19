# MMMC (Multi-Mode Multi-Corner) setup for SoC integration

set PDK_ROOT $env(PDK_ROOT)

# Define library sets
create_library_set -name typical_lib \
    -timing "${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

# Define timing condition
create_timing_condition -name typical_tc \
    -library_sets typical_lib

# Define RC corner
create_rc_corner -name typical_rc \
    -temperature 25 \
    -qrc_tech ${PDK_ROOT}/sky130A/libs.tech/openlane/qrc/sky130A.tch

# Define delay corner
create_delay_corner -name typical_dc \
    -timing_condition typical_tc \
    -rc_corner typical_rc

# Define constraint mode
create_constraint_mode -name typical_cm \
    -sdc_files {../soc_integration/outputs/rv32im_soc_complete.sdc}

# Define analysis view
create_analysis_view -name typical_av \
    -constraint_mode typical_cm \
    -delay_corner typical_dc

# Set analysis view
set_analysis_view -setup typical_av -hold typical_av
