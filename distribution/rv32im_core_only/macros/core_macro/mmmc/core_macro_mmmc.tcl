# MMMC Setup for Core Macro Synthesis and P&R
# Configuration for multi-mode multi-corner analysis

#==============================================================================
# Define Corners
#==============================================================================

create_rc_corner -name typical \
    -temperature 25 \
    -cap_table "$env(PDK_ROOT)/sky130A/libs.tech/openlane/sky130_fd_sc_hd/sky130_fd_sc_hd.tlef" \
    -qrc_tech "$env(PDK_ROOT)/sky130A/libs.tech/openlane/sky130_fd_sc_hd/qrc/qx/sky130_fd_sc_hd_qx.tch"

create_rc_corner -name worst \
    -temperature 125 \
    -cap_table "$env(PDK_ROOT)/sky130A/libs.tech/openlane/sky130_fd_sc_hd/sky130_fd_sc_hd.tlef" \
    -qrc_tech "$env(PDK_ROOT)/sky130A/libs.tech/openlane/sky130_fd_sc_hd/qrc/qx/sky130_fd_sc_hd_qx.tch"

create_rc_corner -name best \
    -temperature -40 \
    -cap_table "$env(PDK_ROOT)/sky130A/libs.tech/openlane/sky130_fd_sc_hd/sky130_fd_sc_hd.tlef" \
    -qrc_tech "$env(PDK_ROOT)/sky130A/libs.tech/openlane/sky130_fd_sc_hd/qrc/qx/sky130_fd_sc_hd_qx.tch"

#==============================================================================
# Define Library Sets
#==============================================================================

create_library_set -name typical_libs \
    -timing [list "$env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"]

create_library_set -name slow_libs \
    -timing [list "$env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_100C_1v60.lib"]

create_library_set -name fast_libs \
    -timing [list "$env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_n40C_1v95.lib"]

#==============================================================================
# Define Constraint Modes  
#==============================================================================

create_constraint_mode -name core_func \
    -sdc_files [list "constraints/core_macro.sdc"]

#==============================================================================
# Define Delay Corners
#==============================================================================

create_delay_corner -name typical_corner \
    -library_set typical_libs \
    -rc_corner typical

create_delay_corner -name slow_corner \
    -library_set slow_libs \
    -rc_corner worst

create_delay_corner -name fast_corner \
    -library_set fast_libs \
    -rc_corner best

#==============================================================================
# Define Analysis Views
#==============================================================================

create_analysis_view -name typical_view \
    -constraint_mode core_func \
    -delay_corner typical_corner

create_analysis_view -name hold_view \
    -constraint_mode core_func \
    -delay_corner fast_corner

create_analysis_view -name setup_view \
    -constraint_mode core_func \
    -delay_corner slow_corner

#==============================================================================
# Set Analysis Views
#==============================================================================

set_analysis_view -setup [list setup_view] \
                  -hold [list hold_view] \
                  -leakage_power [list typical_view] \
                  -dynamic_power [list typical_view]