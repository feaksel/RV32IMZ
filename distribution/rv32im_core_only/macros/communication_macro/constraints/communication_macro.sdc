# SDC Constraints for Communication Macro
# Contains: UART, GPIO, Timer, SPI
# Optimized for SKY130 technology and timing closure

#==============================================================================
# Clock Definition
#==============================================================================

# Primary clock: 100 MHz target
create_clock -name clk -period 10.0 [get_ports clk]

# UART baud clock (derived from main clock)
create_generated_clock -name uart_clk -source [get_ports clk] -divide_by 868 [get_pins *uart_baud_div*]

# SPI clock (derived from main clock)
create_generated_clock -name spi_clk -source [get_ports clk] -divide_by 4 [get_pins *spi_clk_div*]

# Clock uncertainty and transition time
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_uncertainty 1.0 [get_clocks uart_clk]
set_clock_uncertainty 0.8 [get_clocks spi_clk]
set_clock_transition 0.1 [get_clocks clk]
set_clock_transition 0.3 [get_clocks uart_clk]
set_clock_transition 0.2 [get_clocks spi_clk]

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

# UART interface (asynchronous)
set_output_delay 0.0 -clock clk [get_ports uart_tx]
set_input_delay 0.0 -clock clk [get_ports uart_rx]
set_false_path -from [get_ports uart_rx]
set_false_path -to [get_ports uart_tx]

# GPIO interface (asynchronous)
set_input_delay 0.0 -clock clk [get_ports gpio]
set_output_delay 0.0 -clock clk [get_ports gpio]
set_false_path -from [get_ports gpio]
set_false_path -to [get_ports gpio]

# SPI interface (synchronous to spi_clk)
set_output_delay 2.0 -clock spi_clk [get_ports spi_sclk]
set_output_delay 2.0 -clock spi_clk [get_ports spi_mosi]
set_input_delay 2.0 -clock spi_clk [get_ports spi_miso]
set_output_delay 1.0 -clock spi_clk [get_ports spi_cs_n]

# Timer outputs
set_output_delay 1.0 -clock clk [get_ports timer_interrupt]
set_output_delay 0.5 -clock clk [get_ports timer_compare_out]

# Interrupt and status
set_output_delay 1.0 -clock clk [get_ports irq]
set_output_delay 1.0 -clock clk [get_ports comm_status]

#==============================================================================
# False Paths and Multicycle
#==============================================================================

# Clock domain crossing between main, UART, and SPI clocks
set_false_path -from [get_clocks clk] -to [get_clocks uart_clk]
set_false_path -from [get_clocks uart_clk] -to [get_clocks clk]
set_false_path -from [get_clocks clk] -to [get_clocks spi_clk]
set_false_path -from [get_clocks spi_clk] -to [get_clocks clk]

# Timer counters can be multicycle
set_multicycle_path -setup 2 -through [get_pins *timer_counter*]
set_multicycle_path -hold 1 -through [get_pins *timer_counter*]

#==============================================================================
# Load and Drive Constraints
#==============================================================================

# Set driving cells for inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [all_inputs]

# GPIO and external signals have minimal drive
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_1 [get_ports gpio]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_1 [get_ports uart_rx]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_1 [get_ports spi_miso]

# Set load for outputs
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 4] [all_outputs]

# External communication signals may have higher loads
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 8] [get_ports uart_tx]
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 8] [get_ports spi_*]
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 6] [get_ports gpio]

#==============================================================================
# Operating Conditions
#==============================================================================

set_timing_derate -early 0.95
set_timing_derate -late 1.05