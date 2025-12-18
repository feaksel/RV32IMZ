# SDC Constraints for MDU Macro
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

# Input delays (assume signals come from top-level with some delay)
set_input_delay 1.0 -clock clk [get_ports start]
set_input_delay 1.0 -clock clk [get_ports ack]
set_input_delay 1.0 -clock clk [get_ports funct3]
set_input_delay 1.0 -clock clk [get_ports a]
set_input_delay 1.0 -clock clk [get_ports b]

# Output delays (assume top-level needs some setup time)
set_output_delay 1.0 -clock clk [get_ports busy]
set_output_delay 1.0 -clock clk [get_ports done]
set_output_delay 1.0 -clock clk [get_ports product]
set_output_delay 1.0 -clock clk [get_ports quotient]
set_output_delay 1.0 -clock clk [get_ports remainder]

#==============================================================================
# Reset Constraints
#==============================================================================

# Reset is asynchronous
set_false_path -from [get_ports rst_n]

#==============================================================================
# MDU-Specific Constraints
#==============================================================================

# MDU operations are multi-cycle, so we can relax some internal paths
# Allow longer paths for division algorithm (up to 32 cycles)
set_multicycle_path -setup 32 -from [get_cells mdu_inst/div_count*] -to [get_cells mdu_inst/quotient_reg*]
set_multicycle_path -hold 31 -from [get_cells mdu_inst/div_count*] -to [get_cells mdu_inst/quotient_reg*]

# Allow longer paths for multiplication (up to 32 cycles)
set_multicycle_path -setup 32 -from [get_cells mdu_inst/mul_count*] -to [get_cells mdu_inst/acc*]
set_multicycle_path -hold 31 -from [get_cells mdu_inst/mul_count*] -to [get_cells mdu_inst/acc*]

#==============================================================================
# Area and Power Optimization
#==============================================================================

# Set area constraint to encourage optimization
set_max_area 50000.0

# Set load constraints for outputs
set_load 0.1 [all_outputs]