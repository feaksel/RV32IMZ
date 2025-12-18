# SDC Constraints for ADC Subsystem Macro
# Contains: Sigma-Delta ADC + thermal monitoring
# Optimized for SKY130 technology and timing closure

#==============================================================================
# Clock Definition
#==============================================================================

# Primary clock: 100 MHz target
create_clock -name clk -period 10.0 [get_ports clk]

# ADC sampling clock (derived from main clock)
create_generated_clock -name adc_clk -source [get_ports clk] -divide_by 8 [get_pins *adc_clk_div*]

# Clock uncertainty and transition time
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_uncertainty 1.0 [get_clocks adc_clk]
set_clock_transition 0.1 [get_clocks clk]
set_clock_transition 0.2 [get_clocks adc_clk]

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

# Analog inputs (relaxed timing - asynchronous)
set_input_delay 0.0 -clock clk [get_ports analog_in]
set_false_path -from [get_ports analog_in]

# Digital outputs
set_output_delay 1.0 -clock clk [get_ports adc_data]
set_output_delay 0.5 -clock clk [get_ports adc_valid]
set_output_delay 1.0 -clock clk [get_ports irq]
set_output_delay 1.0 -clock clk [get_ports temp_alarm]

# Status outputs
set_output_delay 1.0 -clock clk [get_ports adc_status]

#==============================================================================
# False Paths and Multicycle
#==============================================================================

# Clock domain crossing between main and ADC clock
set_false_path -from [get_clocks clk] -to [get_clocks adc_clk]
set_false_path -from [get_clocks adc_clk] -to [get_clocks clk]

# Thermal monitoring paths can be slower
set_multicycle_path -setup 4 -through [get_pins *thermal*]
set_multicycle_path -hold 2 -through [get_pins *thermal*]

#==============================================================================
# Load and Drive Constraints
#==============================================================================

# Set driving cells for inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [all_inputs]

# Analog inputs have minimal drive
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_1 [get_ports analog_in]

# Set load for outputs
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 4] [all_outputs]

#==============================================================================
# Operating Conditions
#==============================================================================

set_timing_derate -early 0.95
set_timing_derate -late 1.05