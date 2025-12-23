#===============================================================================
# Timing Constraints for rv32im_integrated_macro
# Integration of core_macro + mdu_macro
#===============================================================================

# Clock definition (100 MHz = 10ns period)
# Adjust based on your target frequency
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks clk]

#===============================================================================
# Input Delays
#===============================================================================

# Default input delay (20% of clock period)
set_input_delay 2.0 -clock clk [all_inputs]

# Remove delay from clock and reset (asynchronous)
remove_input_delay [get_ports clk]
remove_input_delay [get_ports rst_n]

#===============================================================================
# Output Delays
#===============================================================================

# Default output delay (20% of clock period)
set_output_delay 2.0 -clock clk [all_outputs]

#===============================================================================
# Macro Interface Timing Budgets
# These tell the tool how much delay to expect through each macro
#===============================================================================

# Core macro internal delay budget
# Assume core takes 60% of clock period for internal logic
set core_delay 6.0

# MDU macro is multi-cycle (takes 4 cycles for multiply/divide)
# Set multicycle paths for MDU operations
set_multicycle_path -setup 4 -from [get_pins u_core_macro/mdu_start]
set_multicycle_path -setup 4 -to [get_pins u_core_macro/mdu_done]
set_multicycle_path -setup 4 -to [get_pins u_core_macro/mdu_product*]
set_multicycle_path -setup 4 -to [get_pins u_core_macro/mdu_quotient*]
set_multicycle_path -setup 4 -to [get_pins u_core_macro/mdu_remainder*]

set_multicycle_path -hold 3 -from [get_pins u_core_macro/mdu_start]
set_multicycle_path -hold 3 -to [get_pins u_core_macro/mdu_done]
set_multicycle_path -hold 3 -to [get_pins u_core_macro/mdu_product*]
set_multicycle_path -hold 3 -to [get_pins u_core_macro/mdu_quotient*]
set_multicycle_path -hold 3 -to [get_pins u_core_macro/mdu_remainder*]

#===============================================================================
# False Paths
#===============================================================================

# Reset is asynchronous
set_false_path -from [get_ports rst_n]

# Asynchronous paths between core and MDU control signals
# (These are handshake signals, not timing-critical)
set_false_path -from [get_pins u_core_macro/mdu_ack] -to [get_pins u_mdu_macro/ack]

#===============================================================================
# Load and Drive
#===============================================================================

# Output load (typical capacitance for sky130 at 1.8V)
set_load 0.05 [all_outputs]

# Input drive (assume driven by a typical buffer)
set_driving_cell -lib_cell sky130_osu_sc_18T_ms__buf_1 [all_inputs]

# Remove drive from clock (comes from clock tree)
remove_driving_cell [get_ports clk]

#===============================================================================
# Design Rules
#===============================================================================

# Maximum transition time (500ps)
set_max_transition 0.5 [current_design]

# Maximum fanout
set_max_fanout 32 [current_design]

# Maximum capacitance
set_max_capacitance 0.5 [all_outputs]
