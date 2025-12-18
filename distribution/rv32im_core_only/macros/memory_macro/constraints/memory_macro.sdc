# SDC Constraints for Memory Macro
# Contains: 32KB ROM + 64KB RAM with SRAM macros
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

# ROM Wishbone interface constraints
set_input_delay 2.0 -clock clk [get_ports wb_rom_adr_i]
set_input_delay 1.0 -clock clk [get_ports wb_rom_sel_i]
set_input_delay 1.0 -clock clk [get_ports wb_rom_stb_i]
set_input_delay 1.0 -clock clk [get_ports wb_rom_cyc_i]

set_output_delay 2.0 -clock clk [get_ports wb_rom_dat_o]
set_output_delay 1.0 -clock clk [get_ports wb_rom_ack_o]

# RAM Wishbone interface constraints
set_input_delay 2.0 -clock clk [get_ports wb_ram_adr_i]
set_input_delay 2.0 -clock clk [get_ports wb_ram_dat_i]
set_input_delay 1.0 -clock clk [get_ports wb_ram_we_i]
set_input_delay 1.0 -clock clk [get_ports wb_ram_sel_i]
set_input_delay 1.0 -clock clk [get_ports wb_ram_stb_i]
set_input_delay 1.0 -clock clk [get_ports wb_ram_cyc_i]

set_output_delay 2.0 -clock clk [get_ports wb_ram_dat_o]
set_output_delay 1.0 -clock clk [get_ports wb_ram_ack_o]

#==============================================================================
# False Paths and Multicycle
#==============================================================================

# No false paths in memory macro

#==============================================================================
# Load and Drive Constraints
#==============================================================================

# Set driving cells for inputs (typical SoC environment)
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [all_inputs]

# Set load for outputs (typical SoC fanout)
set_load [expr [load_of sky130_fd_sc_hd__inv_2/A] * 4] [all_outputs]

#==============================================================================
# Operating Conditions and Timing Derate
#==============================================================================

# For memory-intensive modules, allow slightly more relaxed timing
set_timing_derate -early 0.95
set_timing_derate -late 1.05