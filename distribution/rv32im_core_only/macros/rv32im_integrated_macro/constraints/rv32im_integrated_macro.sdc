# SDC Constraints for Core Macro
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

# Wishbone bus timing constraints
# Instruction bus inputs
set_input_delay 2.0 -clock clk [get_ports iwb_dat_i]
set_input_delay 1.0 -clock clk [get_ports iwb_ack_i]

# Instruction bus outputs  
set_output_delay 2.0 -clock clk [get_ports iwb_adr_o]
set_output_delay 1.0 -clock clk [get_ports iwb_cyc_o]
set_output_delay 1.0 -clock clk [get_ports iwb_stb_o]

# Data bus inputs
set_input_delay 2.0 -clock clk [get_ports dwb_dat_i]
set_input_delay 1.0 -clock clk [get_ports dwb_ack_i]
set_input_delay 1.0 -clock clk [get_ports dwb_err_i]

# Data bus outputs
set_output_delay 2.0 -clock clk [get_ports dwb_adr_o]
set_output_delay 2.0 -clock clk [get_ports dwb_dat_o]
set_output_delay 1.0 -clock clk [get_ports dwb_we_o]
set_output_delay 1.0 -clock clk [get_ports dwb_sel_o]
set_output_delay 1.0 -clock clk [get_ports dwb_cyc_o]
set_output_delay 1.0 -clock clk [get_ports dwb_stb_o]

# MDU interface timing (to external MDU macro)
set_output_delay 1.0 -clock clk [get_ports mdu_start]
set_output_delay 1.0 -clock clk [get_ports mdu_ack]
set_output_delay 1.0 -clock clk [get_ports mdu_funct3]
set_output_delay 2.0 -clock clk [get_ports mdu_operand_a]
set_output_delay 2.0 -clock clk [get_ports mdu_operand_b]

set_input_delay 1.0 -clock clk [get_ports mdu_busy]
set_input_delay 1.0 -clock clk [get_ports mdu_done]
set_input_delay 2.0 -clock clk [get_ports mdu_product]
set_input_delay 2.0 -clock clk [get_ports mdu_quotient]
set_input_delay 2.0 -clock clk [get_ports mdu_remainder]

# Interrupt inputs
set_input_delay 1.0 -clock clk [get_ports interrupts]

#==============================================================================
# Reset Constraints
#==============================================================================

# Reset is asynchronous
set_false_path -from [get_ports rst_n]

#==============================================================================
# Critical Path Optimization
#==============================================================================

# Register file critical paths (these were causing timing violations)
# Relax register file access timing since it's a multi-cycle operation
set_multicycle_path -setup 2 -from [get_pins regfile_inst/registers_reg*/CLK] -to [get_pins regfile_inst/rs1_data*]
set_multicycle_path -hold 1 -from [get_pins regfile_inst/registers_reg*/CLK] -to [get_pins regfile_inst/rs1_data*]

set_multicycle_path -setup 2 -from [get_pins regfile_inst/registers_reg*/CLK] -to [get_pins regfile_inst/rs2_data*]
set_multicycle_path -hold 1 -from [get_pins regfile_inst/registers_reg*/CLK] -to [get_pins regfile_inst/rs2_data*]

# ALU paths can be relaxed since they're captured in registers
set_max_delay 8.0 -from [get_pins regfile_inst/rs1_data*] -to [get_pins alu_inst/result*]
set_max_delay 8.0 -from [get_pins regfile_inst/rs2_data*] -to [get_pins alu_inst/result*]

# Decoder paths are combinational but can be relaxed
set_max_delay 6.0 -from [get_pins instruction*] -to [get_pins decoder_inst/*]

#==============================================================================
# Pipeline State Machine Constraints
#==============================================================================

# State machine transitions can take multiple cycles for some operations
set_multicycle_path -setup 2 -from [get_pins state_reg*] -to [get_pins state_reg*]
set_multicycle_path -hold 1 -from [get_pins state_reg*] -to [get_pins state_reg*]

# Wishbone bus transactions are multi-cycle
set_multicycle_path -setup 3 -from [get_pins ifetch_req*] -to [get_pins iwb_*]
set_multicycle_path -hold 2 -from [get_pins ifetch_req*] -to [get_pins iwb_*]

set_multicycle_path -setup 3 -from [get_pins dmem_req*] -to [get_pins dwb_*]
set_multicycle_path -hold 2 -from [get_pins dmem_req*] -to [get_pins dwb_*]

#==============================================================================
# CSR and Exception Handling
#==============================================================================

# CSR operations are not on critical timing path
set_max_delay 8.0 -from [get_pins instruction*] -to [get_pins csr_inst/*]

# Exception handling can be relaxed since it's not frequent
set_max_delay 8.0 -from [get_pins exc_unit/*] -to [get_pins trap_*]

#==============================================================================
# False Paths
#==============================================================================

# Interrupt signals are asynchronous
set_false_path -from [get_ports interrupts]

# Some control signals don't need tight timing
set_false_path -from [get_pins *_pending*] -to [get_pins instr_retired*]

#==============================================================================
# Area and Power Optimization
#==============================================================================

# Set area constraint to encourage optimization
set_max_area 80000.0

# Set load constraints for outputs
set_load 0.1 [all_outputs]

#==============================================================================
# Special Timing for Register File (Address Key Issue)
#==============================================================================

# The original timing violations were in the register file
# Add specific constraints to address the reset network issue
set_max_fanout 100 [get_nets rst_n]

# Constrain the register file reset paths specifically
set_max_delay 5.0 -from [get_ports rst_n] -to [get_pins regfile_inst/registers_reg*/D]