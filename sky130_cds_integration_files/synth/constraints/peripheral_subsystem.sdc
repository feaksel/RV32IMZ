#===============================================================================
# Timing Constraints for peripheral_subsystem_macro
# Integration of communication + protection + adc + pwm macros
#===============================================================================

# Clock definition (100 MHz = 10ns period)
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks clk]

#===============================================================================
# Input Delays
#===============================================================================

# Processor bus inputs (assume arrive midway through cycle)
set_input_delay 5.0 -clock clk [get_ports addr*]
set_input_delay 5.0 -clock clk [get_ports data_in*]
set_input_delay 5.0 -clock clk [get_ports write_en]
set_input_delay 5.0 -clock clk [get_ports read_en]

# External I/O inputs (asynchronous, register them)
set_input_delay 0.0 -clock clk [get_ports gpio_in*]
set_input_delay 0.0 -clock clk [get_ports uart_rx]
set_input_delay 0.0 -clock clk [get_ports spi_miso]
set_input_delay 0.0 -clock clk [get_ports adc_data*]

# Remove delay from clock and reset
remove_input_delay [get_ports clk]
remove_input_delay [get_ports rst_n]

#===============================================================================
# Output Delays
#===============================================================================

# Processor bus outputs (must be stable by next cycle)
set_output_delay 3.0 -clock clk [get_ports data_out*]

# External I/O outputs (relaxed timing)
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

# External I/O inputs are asynchronous (synchronized internally)
set_false_path -from [get_ports gpio_in*]
set_false_path -from [get_ports uart_rx]
set_false_path -from [get_ports spi_miso]
set_false_path -from [get_ports adc_data*]

#===============================================================================
# Multicycle Paths
#===============================================================================

# ADC sampling is slow (multiple cycles)
set_multicycle_path -setup 8 -to [get_ports adc_sample]
set_multicycle_path -hold 7 -to [get_ports adc_sample]

# PWM outputs are slow (many cycles per period)
set_multicycle_path -setup 10 -to [get_ports pwm_out*]
set_multicycle_path -hold 9 -to [get_ports pwm_out*]

#===============================================================================
# Load and Drive
#===============================================================================

# Processor bus is internal (light load)
set_load 0.03 [get_ports data_out*]

# External I/O has higher load (pads, traces)
set_load 0.1 [get_ports gpio_out*]
set_load 0.1 [get_ports uart_tx]
set_load 0.1 [get_ports spi_sck]
set_load 0.1 [get_ports spi_mosi]
set_load 0.1 [get_ports spi_ss]
set_load 0.1 [get_ports adc_sample]
set_load 0.1 [get_ports pwm_out*]

# Input drive
set_driving_cell -lib_cell sky130_osu_sc_18T_ms__buf_2 [all_inputs]
remove_driving_cell [get_ports clk]

#===============================================================================
# Design Rules
#===============================================================================

# Maximum transition time
set_max_transition 0.5 [current_design]

# Maximum fanout
set_max_fanout 32 [current_design]

# Maximum capacitance
set_max_capacitance 0.5 [all_outputs]
