# SDC Constraints for CPU Core Macro
# Contains: Pipeline, Register File, ALU, Decoder, CSR, Exception handling
# Optimized for SKY130 technology and timing closure

#==============================================================================
# Clock Definition
#==============================================================================

# Primary clock: 100 MHz target (can be relaxed if needed)
create_clock -name clk -period 10.0 [get_ports clk]

# Clock uncertainty and transition time
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_transition 0.1 [get_clocks clk]

#==============================================================================
# Input/Output Timing Constraints
#==============================================================================

# Instruction Wishbone bus inputs
set_input_delay 2.0 -clock clk [get_ports iwb_dat_i]
set_input_delay 1.0 -clock clk [get_ports iwb_ack_i]
set_input_delay 1.0 -clock clk [get_ports iwb_err_i]

# Instruction Wishbone bus outputs  
set_output_delay 2.0 -clock clk [get_ports iwb_adr_o]
set_output_delay 1.0 -clock clk [get_ports iwb_cyc_o]
set_output_delay 1.0 -clock clk [get_ports iwb_stb_o]

# Data Wishbone bus inputs
set_input_delay 2.0 -clock clk [get_ports dwb_dat_i]
set_input_delay 1.0 -clock clk [get_ports dwb_ack_i]
set_input_delay 1.0 -clock clk [get_ports dwb_err_i]

# Data Wishbone bus outputs
set_output_delay 2.0 -clock clk [get_ports dwb_adr_o]
set_output_delay 2.0 -clock clk [get_ports dwb_dat_o]
set_output_delay 1.0 -clock clk [get_ports dwb_we_o]
set_output_delay 1.0 -clock clk [get_ports dwb_sel_o]
set_output_delay 1.0 -clock clk [get_ports dwb_cyc_o]
set_output_delay 1.0 -clock clk [get_ports dwb_stb_o]

# MDU interface (if external MDU macro)
set_output_delay 1.5 -clock clk [get_ports mdu_start]
set_output_delay 1.0 -clock clk [get_ports mdu_funct3]
set_output_delay 2.0 -clock clk [get_ports mdu_a]
set_output_delay 2.0 -clock clk [get_ports mdu_b]
set_input_delay 1.0 -clock clk [get_ports mdu_busy]
set_input_delay 1.0 -clock clk [get_ports mdu_done]
set_input_delay 2.0 -clock clk [get_ports mdu_result]

# Interrupts and external signals
set_input_delay 1.0 -clock clk [get_ports external_irq]
set_output_delay 1.0 -clock clk [get_ports timer_irq]

# Status outputs
set_output_delay 1.0 -clock clk [get_ports core_status]

#==============================================================================
# Critical Path Constraints
#==============================================================================

# ALU operations are typically critical
set_max_delay 8.0 -from [get_pins *alu*] -to [get_pins *result*]

# Register file access paths
set_max_delay 6.0 -from [get_pins *reg_file*] -to [get_pins *reg_data*]

# CSR operations can be multicycle
set_multicycle_path -setup 2 -through [get_pins *csr*]
set_multicycle_path -hold 1 -through [get_pins *csr*]

#==============================================================================
# Load and Drive Constraints
#==============================================================================

# Set driving cells for inputs (typical SoC environment)
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [all_inputs]

# Set load for outputs (typical SoC fanout)
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 4] [all_outputs]

# Wishbone buses may have higher fanout
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 6] [get_ports *wb_*]

#==============================================================================
# Operating Conditions and Timing Derate
#==============================================================================

# Standard timing derate for digital logic
set_timing_derate -early 0.95
set_timing_derate -late 1.05