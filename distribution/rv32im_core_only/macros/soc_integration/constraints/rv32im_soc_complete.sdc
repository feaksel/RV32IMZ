# Timing constraints for SoC integration
# Top-level timing for complete chip

# Clock definition - 100MHz (10ns period)
create_clock -name clk -period 10.0 [get_ports clk]

# Input delays (assume 20% of clock period)
set_input_delay -clock clk -max 2.0 [all_inputs]
set_input_delay -clock clk -min 0.5 [all_inputs]

# Output delays (assume 20% of clock period)
set_output_delay -clock clk -max 2.0 [all_outputs]
set_output_delay -clock clk -min 0.5 [all_outputs]

# Clock uncertainty (jitter + skew)
set_clock_uncertainty -setup 0.5 [get_clocks clk]
set_clock_uncertainty -hold 0.2 [get_clocks clk]

# Clock transition
set_clock_transition 0.2 [get_clocks clk]

# Drive strengths for inputs (assume strong driver)
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_8 [all_inputs]

# Load capacitance for outputs
set_load 0.05 [all_outputs]

# Multicycle paths if needed (example)
# set_multicycle_path -setup 2 -from [get_pins rv32im_integrated_inst/*] -to [get_pins memory_inst/*]

# False paths (example - if any asynchronous paths exist)
# set_false_path -from [get_ports rst_n] -to [all_registers]

# Max fanout
set_max_fanout 10 [current_design]

# Max transition
set_max_transition 1.0 [current_design]

# Operating conditions
set_operating_conditions -max tt_025C_1v80 -min tt_025C_1v80
