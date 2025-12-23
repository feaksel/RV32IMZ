#===============================================================================
# Timing Constraints for rv32imz_soc_macro
# Top-level SOC integration
#===============================================================================

# Clock definition (100 MHz = 10ns period)
# This is the main system clock
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks clk]

#===============================================================================
# Input Delays
#===============================================================================

# External memory interface inputs
# Assume external memory has 30% clock period delay
set ext_mem_delay 3.0
set_input_delay $ext_mem_delay -clock clk [get_ports ext_mem_data_in*]

# Peripheral I/O inputs (asynchronous, will be synchronized)
set_input_delay 0.0 -clock clk [get_ports gpio_in*]
set_input_delay 0.0 -clock clk [get_ports uart_rx]
set_input_delay 0.0 -clock clk [get_ports spi_miso]
set_input_delay 0.0 -clock clk [get_ports adc_data*]

# Interrupt (asynchronous)
set_input_delay 0.0 -clock clk [get_ports external_interrupt]

# Remove delay from clock and reset
remove_input_delay [get_ports clk]
remove_input_delay [get_ports rst_n]

#===============================================================================
# Output Delays
#===============================================================================

# External memory interface outputs
# Must be stable before next memory cycle
set_output_delay $ext_mem_delay -clock clk [get_ports ext_mem_data_out*]
set_output_delay $ext_mem_delay -clock clk [get_ports ext_mem_addr*]
set_output_delay $ext_mem_delay -clock clk [get_ports ext_mem_write_en]
set_output_delay $ext_mem_delay -clock clk [get_ports ext_mem_read_en]

# Peripheral I/O outputs (relaxed timing)
set_output_delay 1.0 -clock clk [get_ports gpio_out*]
set_output_delay 1.0 -clock clk [get_ports uart_tx]
set_output_delay 1.0 -clock clk [get_ports spi_sck]
set_output_delay 1.0 -clock clk [get_ports spi_mosi]
set_output_delay 1.0 -clock clk [get_ports spi_ss]
set_output_delay 1.0 -clock clk [get_ports adc_sample]
set_output_delay 1.0 -clock clk [get_ports pwm_out*]

#===============================================================================
# False Paths
#===============================================================================

# Reset is asynchronous
set_false_path -from [get_ports rst_n]

# External asynchronous inputs
set_false_path -from [get_ports gpio_in*]
set_false_path -from [get_ports uart_rx]
set_false_path -from [get_ports spi_miso]
set_false_path -from [get_ports adc_data*]
set_false_path -from [get_ports external_interrupt]

#===============================================================================
# Multicycle Paths
#===============================================================================

# Memory access can take multiple cycles
set_multicycle_path -setup 2 -from [get_pins u_rv32im_core/*] -through [get_pins u_memory/*]
set_multicycle_path -hold 1 -from [get_pins u_rv32im_core/*] -through [get_pins u_memory/*]

# External memory interface (slow)
set_multicycle_path -setup 3 -to [get_ports ext_mem_*]
set_multicycle_path -hold 2 -to [get_ports ext_mem_*]

# Peripheral accesses are slower (memory-mapped I/O)
set_multicycle_path -setup 2 -from [get_pins u_rv32im_core/*] -through [get_pins u_peripherals/*]
set_multicycle_path -hold 1 -from [get_pins u_rv32im_core/*] -through [get_pins u_peripherals/*]

# PWM outputs are very slow
set_multicycle_path -setup 10 -to [get_ports pwm_out*]
set_multicycle_path -hold 9 -to [get_ports pwm_out*]

# ADC sampling is slow
set_multicycle_path -setup 8 -to [get_ports adc_sample]
set_multicycle_path -hold 7 -to [get_ports adc_sample]

#===============================================================================
# Load and Drive
#===============================================================================

# External memory (moderate load - off-chip)
set_load 0.2 [get_ports ext_mem_data_out*]
set_load 0.2 [get_ports ext_mem_addr*]
set_load 0.1 [get_ports ext_mem_write_en]
set_load 0.1 [get_ports ext_mem_read_en]

# Peripheral I/O (higher load - pads + external)
set_load 0.15 [get_ports gpio_out*]
set_load 0.15 [get_ports uart_tx]
set_load 0.15 [get_ports spi_sck]
set_load 0.15 [get_ports spi_mosi]
set_load 0.15 [get_ports spi_ss]
set_load 0.15 [get_ports adc_sample]
set_load 0.15 [get_ports pwm_out*]

# Input drive (assume driven by pads)
set_driving_cell -lib_cell sky130_osu_sc_18T_ms__buf_4 [all_inputs]
remove_driving_cell [get_ports clk]

#===============================================================================
# Design Rules
#===============================================================================

# Maximum transition time (500ps for internal, 1ns for I/O)
set_max_transition 0.5 [current_design]
set_max_transition 1.0 [all_outputs]

# Maximum fanout
set_max_fanout 32 [current_design]

# Maximum capacitance
set_max_capacitance 0.5 [current_design]

#===============================================================================
# Power Optimization Hints (Optional)
#===============================================================================

# Set switching activity for power estimation
# Clock toggles every cycle
set_switching_activity -static_probability 0.5 -toggle_rate 100.0 [get_ports clk]

# Most data signals toggle less frequently
set_switching_activity -static_probability 0.25 -toggle_rate 25.0 [get_ports *data*]

# Control signals toggle rarely
set_switching_activity -static_probability 0.1 -toggle_rate 10.0 [get_ports *_en]
