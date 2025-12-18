# SDC Constraints for Protection Macro
# Contains: Security features, access control, memory protection
# Optimized for SKY130 technology and timing closure

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

# Wishbone interface constraints
set_input_delay 2.0 -clock clk [get_ports wb_adr_i]
set_input_delay 2.0 -clock clk [get_ports wb_dat_i]
set_input_delay 1.0 -clock clk [get_ports wb_we_i]
set_input_delay 1.0 -clock clk [get_ports wb_sel_i]
set_input_delay 1.0 -clock clk [get_ports wb_cyc_i]
set_input_delay 1.0 -clock clk [get_ports wb_stb_i]

set_output_delay 2.0 -clock clk [get_ports wb_dat_o]
set_output_delay 1.0 -clock clk [get_ports wb_ack_o]
set_output_delay 1.0 -clock clk [get_ports wb_err_o]

# Access control inputs (critical timing)
set_input_delay 1.5 -clock clk [get_ports access_addr]
set_input_delay 1.0 -clock clk [get_ports access_mode]
set_input_delay 1.0 -clock clk [get_ports access_privilege]

# Protection outputs (critical timing)
set_output_delay 1.0 -clock clk [get_ports access_grant]
set_output_delay 0.5 -clock clk [get_ports access_deny]
set_output_delay 1.0 -clock clk [get_ports security_violation]

# Interrupt and status
set_output_delay 1.0 -clock clk [get_ports irq]
set_output_delay 1.0 -clock clk [get_ports protection_status]

#==============================================================================
# False Paths and Multicycle
#==============================================================================

# Configuration registers can be multicycle
set_multicycle_path -setup 2 -through [get_pins *config_reg*]
set_multicycle_path -hold 1 -through [get_pins *config_reg*]

#==============================================================================
# Load and Drive Constraints
#==============================================================================

# Set driving cells for inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [all_inputs]

# Set load for outputs
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 4] [all_outputs]

# Critical security signals may have higher drive
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_4 [get_ports access_*]

#==============================================================================
# Operating Conditions
#==============================================================================

# Security-critical paths need tight timing
set_timing_derate -early 0.98
set_timing_derate -late 1.02