################################################################################
#
# Init setup file
# Created by Genus(TM) Synthesis Solution on 12/18/2025 12:04:50
#
################################################################################
if { ![is_common_ui_mode] } { error "ERROR: This script requires common_ui to be active."}

read_netlist outputs/core_design.v

init_design -skip_sdc_read
