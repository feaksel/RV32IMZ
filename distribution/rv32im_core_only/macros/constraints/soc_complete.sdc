# SDC Constraints for Complete RV32IM SoC
# Integrates hierarchical core with all peripherals

#==============================================================================
# Clock Definition
#==============================================================================

# Primary clock: 100 MHz target (can be adjusted based on timing closure)
create_clock -name clk -period 10.0 [get_ports clk]

# Clock uncertainty and transition time
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_transition 0.1 [get_clocks clk]

#==============================================================================
# Input/Output Timing Constraints
#==============================================================================

# External memory interface
set_input_delay 2.0 -clock clk [get_ports ext_mem_dat_i]
set_input_delay 1.0 -clock clk [get_ports ext_mem_ack_i]
set_input_delay 1.0 -clock clk [get_ports ext_mem_err_i]

set_output_delay 2.0 -clock clk [get_ports ext_mem_adr_o]
set_output_delay 2.0 -clock clk [get_ports ext_mem_dat_o]
set_output_delay 1.0 -clock clk [get_ports ext_mem_we_o]
set_output_delay 1.0 -clock clk [get_ports ext_mem_sel_o]
set_output_delay 1.0 -clock clk [get_ports ext_mem_cyc_o]
set_output_delay 1.0 -clock clk [get_ports ext_mem_stb_o]

# UART interface
set_output_delay 5.0 -clock clk [get_ports uart_tx]
set_input_delay 5.0 -clock clk [get_ports uart_rx]

# SPI interface (can be relaxed - not critical timing)
set_output_delay 3.0 -clock clk [get_ports spi_sclk]
set_output_delay 3.0 -clock clk [get_ports spi_mosi]
set_output_delay 2.0 -clock clk [get_ports spi_cs_n]
set_input_delay 3.0 -clock clk [get_ports spi_miso]

# PWM outputs (very relaxed - static after setup)
set_output_delay 8.0 -clock clk [get_ports pwm_out]

# GPIO (relaxed timing)
set_input_delay 5.0 -clock clk [get_ports gpio]
set_output_delay 5.0 -clock clk [get_ports gpio]

# ADC interface
set_input_delay 3.0 -clock clk [get_ports adc_data_in]
set_output_delay 3.0 -clock clk [get_ports adc_clk_out]

# Thermal monitoring (relaxed)
set_output_delay 8.0 -clock clk [get_ports thermal_alert]

# Debug UART (relaxed)
set_output_delay 8.0 -clock clk [get_ports debug_uart_tx]
set_input_delay 8.0 -clock clk [get_ports debug_uart_rx]

# External interrupts (asynchronous)
set_input_delay 2.0 -clock clk [get_ports ext_interrupts]

#==============================================================================
# Reset Constraints
#==============================================================================

# Reset is asynchronous
set_false_path -from [get_ports rst_n]

#==============================================================================
# Core Module Constraints (Hierarchical)
#==============================================================================

# The core uses the proven 2-macro hierarchical approach
# Allocate most of the timing budget to the core

# Core gets 7ns out of 10ns total cycle time
set_max_delay 7.0 -from [get_pins u_core/*] -to [get_pins u_core/*]

# Core to peripheral interface timing
set_max_delay 2.0 -from [get_pins u_core/dwb_*] -to [get_pins u_*/wb_*]

#==============================================================================
# Peripheral Timing Budgets
#==============================================================================

# Peripherals are simpler and get relaxed timing
# Each peripheral gets 3ns budget for internal operations

set_max_delay 3.0 -from [get_pins u_uart/*] -to [get_pins u_uart/*]
set_max_delay 3.0 -from [get_pins u_spi/*] -to [get_pins u_spi/*]
set_max_delay 3.0 -from [get_pins u_pwm/*] -to [get_pins u_pwm/*]
set_max_delay 3.0 -from [get_pins u_gpio/*] -to [get_pins u_gpio/*]
set_max_delay 3.0 -from [get_pins u_adc/*] -to [get_pins u_adc/*]
set_max_delay 3.0 -from [get_pins u_thermal/*] -to [get_pins u_thermal/*]
set_max_delay 3.0 -from [get_pins u_mem_ctrl/*] -to [get_pins u_mem_ctrl/*]

#==============================================================================
# Bus Arbitration and Decode Logic
#==============================================================================

# Address decode logic can be relaxed since it's combinational
set_max_delay 1.5 -from [get_pins dwb_adr*] -to [get_pins *_sel]

# Bus multiplexer timing
set_max_delay 1.0 -from [get_pins *_wb_dat_miso*] -to [get_pins dwb_dat_miso*]
set_max_delay 1.0 -from [get_pins *_wb_ack] -to [get_pins dwb_ack]

#==============================================================================
# Multi-Cycle Paths
#==============================================================================

# Wishbone bus transactions are multi-cycle by nature
set_multicycle_path -setup 3 -from [get_pins u_core/dwb_*] -to [get_pins dwb_ack]
set_multicycle_path -hold 2 -from [get_pins u_core/dwb_*] -to [get_pins dwb_ack]

set_multicycle_path -setup 3 -from [get_pins u_core/iwb_*] -to [get_pins iwb_ack]
set_multicycle_path -hold 2 -from [get_pins u_core/iwb_*] -to [get_pins iwb_ack]

# Peripheral register accesses can take multiple cycles
set_multicycle_path -setup 2 -to [get_pins u_uart/wb_ack_o]
set_multicycle_path -setup 2 -to [get_pins u_spi/wb_ack_o]
set_multicycle_path -setup 2 -to [get_pins u_pwm/wb_ack_o]
set_multicycle_path -setup 2 -to [get_pins u_gpio/wb_ack_o]
set_multicycle_path -setup 2 -to [get_pins u_adc/wb_ack_o]
set_multicycle_path -setup 2 -to [get_pins u_thermal/wb_ack_o]

# External memory access is definitely multi-cycle
set_multicycle_path -setup 5 -from [get_pins u_mem_ctrl/*] -to [get_ports ext_mem_*]
set_multicycle_path -hold 4 -from [get_pins u_mem_ctrl/*] -to [get_ports ext_mem_*]

#==============================================================================
# False Paths
#==============================================================================

# Interrupt signals are asynchronous by nature
set_false_path -from [get_ports ext_interrupts]
set_false_path -from [get_pins */irq] -to [get_pins combined_interrupts*]

# GPIO can have asynchronous inputs
set_false_path -from [get_ports gpio] -to [get_pins u_gpio/*]

# Debug interface is not timing critical
set_false_path -from [get_pins debug_*] -to [get_ports debug_*]
set_false_path -from [get_ports debug_*] -to [get_pins debug_*]

# Thermal alerts are asynchronous
set_false_path -from [get_pins u_thermal/thermal_alert] -to [get_ports thermal_alert]

#==============================================================================
# Hierarchical Design Preservation
#==============================================================================

# Preserve the core hierarchy - don't flatten during optimization
set_dont_touch [get_cells u_core]
set_dont_touch [get_cells u_core/u_mdu_macro]
set_dont_touch [get_cells u_core/u_core_macro]

# Keep peripheral modules intact for easier debugging
set_dont_touch [get_cells u_uart]
set_dont_touch [get_cells u_spi]
set_dont_touch [get_cells u_pwm]
set_dont_touch [get_cells u_gpio]
set_dont_touch [get_cells u_adc]
set_dont_touch [get_cells u_thermal]
set_dont_touch [get_cells u_mem_ctrl]

#==============================================================================
# Area and Power Optimization
#==============================================================================

# Set overall area constraint (allowing for all peripherals)
set_max_area 200000.0

# Load and drive constraints
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [all_inputs]
set_load 0.1 [all_outputs]

#==============================================================================
# Clock Domain Management
#==============================================================================

# All modules use the same clock - no CDC issues
# But ensure clean clock distribution

set_max_skew 0.5 [get_clocks clk]
set_max_fanout 200 [get_nets clk]

# Special attention to reset distribution across large SoC
set_max_fanout 50 [get_nets rst_n]

#==============================================================================
# Physical Design Hints
#==============================================================================

# Placement preferences for better timing
set_placement_preference u_core -group core_group
set_placement_preference {u_uart u_spi u_pwm u_gpio} -group peripheral_group
set_placement_preference {u_adc u_thermal} -group analog_group
set_placement_preference u_mem_ctrl -group memory_group

# Keep related modules close
set_placement_preference core_group -near peripheral_group

# Memory controller should be close to external pins
set_placement_preference memory_group -near_io

#==============================================================================
# Special Optimization Directives
#==============================================================================

# Don't over-optimize peripheral simple logic
set_max_transition 0.5 [get_pins u_uart/*]
set_max_transition 0.5 [get_pins u_spi/*]
set_max_transition 0.5 [get_pins u_pwm/*]
set_max_transition 0.5 [get_pins u_gpio/*]

# Core can have tighter transition times since it's timing critical
set_max_transition 0.2 [get_pins u_core/*]