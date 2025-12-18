# SDC Constraints for PWM Accelerator Macro
# Contains: 4-channel PWM generator with DMA support
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

# PWM output constraints (relaxed for analog outputs)
set_output_delay 0.5 -clock clk [get_ports pwm_out]

# Interrupt output
set_output_delay 1.0 -clock clk [get_ports irq]

# Status outputs
set_output_delay 1.0 -clock clk [get_ports pwm_status]

#==============================================================================
# False Paths and Multicycle
#==============================================================================

# PWM counters can be multicycle for area optimization
set_multicycle_path -setup 2 -through [get_pins *pwm_counter*]
set_multicycle_path -hold 1 -through [get_pins *pwm_counter*]

#==============================================================================
# Load and Drive Constraints
#==============================================================================

# Set driving cells for inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [all_inputs]

# Set load for outputs
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 4] [all_outputs]

# PWM outputs may drive external loads
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 8] [get_ports pwm_out]

#==============================================================================
# Operating Conditions
#==============================================================================

set_timing_derate -early 0.95
set_timing_derate -late 1.05