#===============================================================================
# Generic SDC Template for Peripheral Leaf Macros
# Works for: memory, communication, protection, ADC, PWM, etc.
#
# Usage: Copy this to constraints/<macro_name>.sdc for each peripheral
#===============================================================================

#===============================================================================
# Clock Definition
#===============================================================================

# Main clock (adjust period as needed - 10ns = 100MHz)
# Change "clk" to your actual clock port name if different
create_clock -period 10.0 -name clk [get_ports clk]

# Clock uncertainty (accounts for jitter, skew)
set_clock_uncertainty 0.5 [get_clocks clk]

# Clock transition (rise/fall time)
set_clock_transition 0.2 [get_clocks clk]

#===============================================================================
# Input Constraints
#===============================================================================

# Input delay relative to clock
# Max delay = 20% of clock period (2ns for 10ns clock)
set_input_delay -clock clk -max 2.0 [all_inputs]
set_input_delay -clock clk -min 1.0 [all_inputs]

# Don't constrain clock itself
remove_input_delay [get_ports clk]

# Don't constrain reset (if you have async reset)
if {[sizeof_collection [get_ports rst*]] > 0} {
    remove_input_delay [get_ports rst*]
    set_false_path -from [get_ports rst*]
}
if {[sizeof_collection [get_ports reset*]] > 0} {
    remove_input_delay [get_ports reset*]
    set_false_path -from [get_ports reset*]
}

#===============================================================================
# Output Constraints
#===============================================================================

# Output delay relative to clock
# Max delay = 20% of clock period
set_output_delay -clock clk -max 2.0 [all_outputs]
set_output_delay -clock clk -min 1.0 [all_outputs]

#===============================================================================
# Environmental Constraints (Optional)
#===============================================================================

# Input driving cell (what's driving the inputs)
# Uncomment if needed:
# set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [all_inputs]

# Output load capacitance
# Uncomment if needed:
# set_load 0.05 [all_outputs]

#===============================================================================
# Special Paths (Modify as needed for your design)
#===============================================================================

# Example: If you have asynchronous paths, mark them as false paths
# set_false_path -from [get_ports async_input] -to [get_ports async_output]

# Example: Multi-cycle paths (if some paths can take 2 cycles)
# set_multicycle_path 2 -setup -from [get_pins some_reg/Q] -to [get_pins other_reg/D]
# set_multicycle_path 1 -hold -from [get_pins some_reg/Q] -to [get_pins other_reg/D]

#===============================================================================
# SRAM Constraints (for memory_macro)
#===============================================================================

# If your macro uses SRAM, the SRAM itself has internal timing
# Mark SRAM paths as don't touch or add specific constraints

# Example: Don't optimize SRAM instance
# set_dont_touch [get_cells u_sram]

# Example: If SRAM has its own timing file
# read_sdc /path/to/sram_constraints.sdc

#===============================================================================
# Notes
#===============================================================================

# Adjust these values based on your design:
# - Clock period: Set to your target frequency
#   - 10ns = 100MHz
#   - 20ns = 50MHz
#   - 5ns = 200MHz
#
# - I/O delays: Typically 10-20% of clock period
#   - Conservative: 20% (2ns for 10ns clock)
#   - Aggressive: 10% (1ns for 10ns clock)
#
# - Clock uncertainty: Typically 5-10% of clock period
#   - Conservative: 10% (1ns for 10ns clock)
#   - Normal: 5% (0.5ns for 10ns clock)
