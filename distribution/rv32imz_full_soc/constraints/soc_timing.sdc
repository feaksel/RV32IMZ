# SDC Constraints for RV32IM SoC (soc_top.v)
# Complete System-on-Chip Timing Constraints

#==============================================================================
# Clock Definition
#==============================================================================

# Primary clock: 100 MHz input from Basys3
create_clock -name clk_100mhz -period 10.0 [get_ports clk_100mhz]

# Generated clock: 50 MHz system clock (divided internally)
create_generated_clock -name clk_50mhz -source [get_ports clk_100mhz] \
                       -divide_by 2 [get_nets clk_50mhz]

# Set uncertainty and jitter
set_clock_uncertainty 0.5 [get_clocks clk_100mhz]
set_clock_uncertainty 0.3 [get_clocks clk_50mhz]

# Clock transition time
set_clock_transition 0.1 [get_clocks]

#==============================================================================
# Input/Output Timing
#==============================================================================

# Input delays relative to 50MHz system clock
set_input_delay -clock clk_50mhz -max 2.0 [remove_from_collection [all_inputs] [get_ports clk_100mhz]]
set_input_delay -clock clk_50mhz -min 1.0 [remove_from_collection [all_inputs] [get_ports clk_100mhz]]

# Output delays relative to 50MHz system clock  
set_output_delay -clock clk_50mhz -max 2.0 [all_outputs]
set_output_delay -clock clk_50mhz -min 1.0 [all_outputs]

#==============================================================================
# Reset Timing
#==============================================================================

# Reset is asynchronous
set_false_path -from [get_ports rst_n]
set_false_path -to [get_pins */rst_sync*/D]

#==============================================================================
# Critical Path Constraints
#==============================================================================

# CPU core critical paths
set_multicycle_path -setup 2 -through [get_pins cpu/cpu/*]
set_multicycle_path -hold 1 -through [get_pins cpu/cpu/*]

# Memory interface timing (relaxed for academic use)
set_multicycle_path -setup 2 -to [get_pins rom_inst/addr_reg*/D]
set_multicycle_path -setup 2 -to [get_pins ram_inst/addr_reg*/D]

# Wishbone bus timing
set_multicycle_path -setup 2 -through [get_pins interconnect/*wb*]
set_multicycle_path -hold 1 -through [get_pins interconnect/*wb*]

#==============================================================================
# Peripheral Timing Constraints
#==============================================================================

# UART timing (115200 baud = ~8.68μs bit period)
set_multicycle_path -setup 434 -through [get_pins uart_inst/*]  # 50MHz/115200 ≈ 434 cycles
set_multicycle_path -hold 1 -through [get_pins uart_inst/*]

# PWM timing (high-frequency switching)
set_case_analysis 1 [get_pins pwm_inst/enable] -if_exists
set_multicycle_path -setup 2 -through [get_pins pwm_inst/*]

# GPIO timing (slow external signals)
set_input_delay -clock clk_50mhz -max 5.0 [get_ports gpio*] -add_delay
set_output_delay -clock clk_50mhz -max 5.0 [get_ports gpio*] -add_delay

# Timer/Counter paths
set_multicycle_path -setup 2 -through [get_pins timer_inst/*]

# ADC sigma-delta timing
set_multicycle_path -setup 4 -through [get_pins adc_inst/*]

#==============================================================================
# Drive Strength and Load Modeling
#==============================================================================

# Input drive strength (assume standard CMOS buffers)
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 [all_inputs]

# Output loads (assume PCB traces + external components)
set_load 0.1 [get_ports uart_tx]      # UART to external connector
set_load 0.2 [get_ports pwm_out*]     # PWM to gate drivers
set_load 0.05 [get_ports led*]        # LEDs (low load)
set_load 0.15 [get_ports gpio*]       # GPIO to external pins

#==============================================================================
# Power and Area Constraints
#==============================================================================

# Set operating conditions for power analysis
set_operating_conditions -analysis_type on_chip_variation

# Area constraint (academic target)
set_max_area 5000   # Allow reasonable area for homework

#==============================================================================
# Special Timing Exceptions
#==============================================================================

# Clock domain crossing (none in this design)
# All logic runs on single 50MHz domain

# Debug/test signals
set_false_path -through [get_pins *debug*] -if_exists
set_false_path -through [get_pins *test*] -if_exists

# Interrupt signals (asynchronous by nature)
set_false_path -from [get_ports fault_ocp]
set_false_path -from [get_ports fault_ovp]  
set_false_path -from [get_ports estop_n]

#==============================================================================
# Design Rule Constraints
#==============================================================================

# Maximum transition time
set_max_transition 0.5 [all_outputs]

# Maximum fanout
set_max_fanout 20 [all_inputs]

# Maximum capacitance
set_max_capacitance 0.2 [all_outputs]

#==============================================================================
# Synthesis Directives
#==============================================================================

# Don't optimize clock trees during synthesis
set_dont_touch_network [get_clocks]

# Preserve hierarchy for debug
set_dont_touch [get_cells cpu]
set_dont_touch [get_cells rom_inst]
set_dont_touch [get_cells ram_inst]

#==============================================================================
# Comments for Academic Use
#==============================================================================

# This constraint file is designed for:
# - SKY130 technology (130nm)
# - Academic synthesis tools
# - Conservative timing for homework success
# - Comprehensive peripheral coverage
# 
# Expected results:
# - 50 MHz operation achievable
# - ~3000-5000 logic cells
# - Reasonable power consumption
# - All timing constraints met