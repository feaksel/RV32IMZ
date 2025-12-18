# SDC Constraints for Hierarchical RV32IM Top-Level
# Integrates MDU macro and Core macro with proper timing budgets

#==============================================================================
# Clock Definition
#==============================================================================

# Primary clock: 100 MHz target
create_clock -name clk -period 10.0 [get_ports clk]

# Clock uncertainty and transition time
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_transition 0.1 [get_clocks clk]

#==============================================================================
# Input/Output Timing Constraints
#==============================================================================

# Wishbone bus timing constraints
# Instruction bus
set_input_delay 2.0 -clock clk [get_ports iwb_dat_i]
set_input_delay 1.0 -clock clk [get_ports iwb_ack_i]
set_input_delay 1.0 -clock clk [get_ports iwb_err_i]

set_output_delay 2.0 -clock clk [get_ports iwb_adr_o]
set_output_delay 2.0 -clock clk [get_ports iwb_dat_o]
set_output_delay 1.0 -clock clk [get_ports iwb_we_o]
set_output_delay 1.0 -clock clk [get_ports iwb_sel_o]
set_output_delay 1.0 -clock clk [get_ports iwb_cyc_o]
set_output_delay 1.0 -clock clk [get_ports iwb_stb_o]

# Data bus
set_input_delay 2.0 -clock clk [get_ports dwb_dat_i]
set_input_delay 1.0 -clock clk [get_ports dwb_ack_i]
set_input_delay 1.0 -clock clk [get_ports dwb_err_i]

set_output_delay 2.0 -clock clk [get_ports dwb_adr_o]
set_output_delay 2.0 -clock clk [get_ports dwb_dat_o]
set_output_delay 1.0 -clock clk [get_ports dwb_we_o]
set_output_delay 1.0 -clock clk [get_ports dwb_sel_o]
set_output_delay 1.0 -clock clk [get_ports dwb_cyc_o]
set_output_delay 1.0 -clock clk [get_ports dwb_stb_o]

# Interrupt inputs
set_input_delay 1.0 -clock clk [get_ports interrupts]

#==============================================================================
# Reset Constraints
#==============================================================================

# Reset is asynchronous
set_false_path -from [get_ports rst_n]

#==============================================================================
# Inter-Macro Timing Budget
#==============================================================================

# MDU interface timing budget - allocate 3ns for inter-macro communication
# This leaves 7ns for internal macro timing

# Core to MDU signals (requests)
set_max_delay 3.0 -from [get_pins u_core_macro/mdu_start] -to [get_pins u_mdu_macro/start]
set_max_delay 3.0 -from [get_pins u_core_macro/mdu_ack] -to [get_pins u_mdu_macro/ack]
set_max_delay 3.0 -from [get_pins u_core_macro/mdu_funct3*] -to [get_pins u_mdu_macro/funct3*]
set_max_delay 3.0 -from [get_pins u_core_macro/mdu_operand_a*] -to [get_pins u_mdu_macro/operand_a*]
set_max_delay 3.0 -from [get_pins u_core_macro/mdu_operand_b*] -to [get_pins u_mdu_macro/operand_b*]

# MDU to Core signals (responses)
set_max_delay 3.0 -from [get_pins u_mdu_macro/busy] -to [get_pins u_core_macro/mdu_busy]
set_max_delay 3.0 -from [get_pins u_mdu_macro/done] -to [get_pins u_core_macro/mdu_done]
set_max_delay 3.0 -from [get_pins u_mdu_macro/product*] -to [get_pins u_core_macro/mdu_product*]
set_max_delay 3.0 -from [get_pins u_mdu_macro/quotient*] -to [get_pins u_core_macro/mdu_quotient*]
set_max_delay 3.0 -from [get_pins u_mdu_macro/remainder*] -to [get_pins u_core_macro/mdu_remainder*]

#==============================================================================
# Macro-Level Constraints
#==============================================================================

# Set individual timing budgets for each macro
# Core macro gets 7ns, MDU macro gets 7ns for internal timing

# Create groups for each macro
group_path -name core_macro_group -from [get_pins u_core_macro/*] -to [get_pins u_core_macro/*]
group_path -name mdu_macro_group -from [get_pins u_mdu_macro/*] -to [get_pins u_mdu_macro/*]

# Set timing budgets
set_max_delay 7.0 -group core_macro_group
set_max_delay 7.0 -group mdu_macro_group

#==============================================================================
# Clock Domain Constraints
#==============================================================================

# Both macros use the same clock - no CDC issues
# But ensure proper clock distribution

set_max_skew 0.5 [get_clocks clk]

#==============================================================================
# Physical Constraints (for P&R guidance)
#==============================================================================

# Relative placement preferences - place macros for minimal interconnect
set_placement_preference u_mdu_macro -group mdu_group
set_placement_preference u_core_macro -group core_group

# Try to keep inter-macro connections short
set_placement_preference mdu_group -near core_group

#==============================================================================
# Optimization Directives
#==============================================================================

# Don't break hierarchy during optimization - preserve macro boundaries
set_dont_touch [get_cells u_mdu_macro]
set_dont_touch [get_cells u_core_macro]

# Set area constraints - total budget for both macros
set_max_area 120000.0

#==============================================================================
# Load and Drive Constraints
#==============================================================================

# Set drive strength for inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [all_inputs]

# Set load constraints for outputs
set_load 0.1 [all_outputs]

#==============================================================================
# Special Multi-Cycle Paths
#==============================================================================

# MDU operations take multiple cycles - relax timing accordingly
set_multicycle_path -setup 8 -from [get_pins u_core_macro/mdu_start] -to [get_pins u_mdu_macro/done]
set_multicycle_path -hold 7 -from [get_pins u_core_macro/mdu_start] -to [get_pins u_mdu_macro/done]

# Wishbone bus transactions are multi-cycle
set_multicycle_path -setup 3 -from [get_pins u_core_macro/dwb_*] 
set_multicycle_path -hold 2 -from [get_pins u_core_macro/dwb_*]

set_multicycle_path -setup 3 -from [get_pins u_core_macro/iwb_*]
set_multicycle_path -hold 2 -from [get_pins u_core_macro/iwb_*]