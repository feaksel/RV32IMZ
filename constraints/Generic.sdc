# Basic timing constraints for memory_macro

# Clock definition (adjust period as needed)
create_clock -period 10.0 -name clk [get_ports clk]

# Clock uncertainty
set_clock_uncertainty 0.5 [get_clocks clk]

# Input delays (relative to clock)
set_input_delay -clock clk -max 2.0 [all_inputs]
set_input_delay -clock clk -min 1.0 [all_inputs]
remove_input_delay [get_ports clk]  # Don't constrain clock itself

# Output delays
set_output_delay -clock clk -max 2.0 [all_outputs]
set_output_delay -clock clk -min 1.0 [all_outputs]

# Don't touch SRAM constraints (if it has its own timing)
# set_case_analysis / set_false_path as needed
