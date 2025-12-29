# ####################################################################

#  Created by Genus(TM) Synthesis Solution 21.18-s082_1 on Thu Dec 25 11:39:34 +03 2025

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design rv32im_soc_with_integrated_core

set_clock_gating_check -setup 0.0 
set_wire_load_mode "enclosed"
