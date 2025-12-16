# RV32IMZ Core Timing Constraints (Xilinx XDC format)
# For Vivado synthesis and implementation

# Primary clock constraint - 100 MHz
create_clock -period 10.000 -name sys_clk [get_ports clk]

# Clock uncertainty and jitter
set_clock_uncertainty 0.500 [get_clocks sys_clk]

# Input delays (account for board trace delays and setup times)
set_input_delay -clock [get_clocks sys_clk] 2.000 [get_ports rst_n]
set_input_delay -clock [get_clocks sys_clk] 3.000 [get_ports iwb_dat_i[*]]
set_input_delay -clock [get_clocks sys_clk] 3.000 [get_ports dwb_dat_i[*]]
set_input_delay -clock [get_clocks sys_clk] 2.500 [get_ports iwb_ack_i]
set_input_delay -clock [get_clocks sys_clk] 2.500 [get_ports dwb_ack_i]

# Output delays (account for board trace delays and hold times)
set_output_delay -clock [get_clocks sys_clk] 3.000 [get_ports iwb_adr_o[*]]
set_output_delay -clock [get_clocks sys_clk] 3.000 [get_ports iwb_dat_o[*]]
set_output_delay -clock [get_clocks sys_clk] 2.500 [get_ports iwb_cyc_o]
set_output_delay -clock [get_clocks sys_clk] 2.500 [get_ports iwb_stb_o]
set_output_delay -clock [get_clocks sys_clk] 2.500 [get_ports iwb_we_o]
set_output_delay -clock [get_clocks sys_clk] 3.000 [get_ports dwb_adr_o[*]]
set_output_delay -clock [get_clocks sys_clk] 3.000 [get_ports dwb_dat_o[*]]
set_output_delay -clock [get_clocks sys_clk] 2.500 [get_ports dwb_cyc_o]
set_output_delay -clock [get_clocks sys_clk] 2.500 [get_ports dwb_stb_o]
set_output_delay -clock [get_clocks sys_clk] 2.500 [get_ports dwb_we_o]
set_output_delay -clock [get_clocks sys_clk] 3.000 [get_ports dwb_sel_o[*]]

# MDU Critical Path Constraints
# These paths are critical for timing closure with the restoring division algorithm

# Division algorithm critical paths
# 33-bit comparison path in restoring division
set_max_delay -from [get_cells -hier -filter {NAME =~ "*mdu*remainder_reg_reg[*]"}] -to [get_cells -hier -filter {NAME =~ "*mdu*quotient_reg_reg[*]"}] 8.000

# 33-bit subtraction path in division
set_max_delay -from [get_cells -hier -filter {NAME =~ "*mdu*remainder_reg_reg[*]"}] -to [get_cells -hier -filter {NAME =~ "*mdu*remainder_reg_reg[*]"}] 8.500

# Division counter logic
set_max_delay -from [get_cells -hier -filter {NAME =~ "*mdu*div_count_reg[*]"}] -to [get_cells -hier -filter {NAME =~ "*mdu*state_reg[*]"}] 5.000

# Multiplication critical paths
# 64-bit accumulator addition in multiplication
set_max_delay -from [get_cells -hier -filter {NAME =~ "*mdu*acc_reg[*]"}] -to [get_cells -hier -filter {NAME =~ "*mdu*acc_reg[*]"}] 7.000

# Multiplicand and multiplier shift operations
set_max_delay -from [get_cells -hier -filter {NAME =~ "*mdu*multiplicand_reg[*]"}] -to [get_cells -hier -filter {NAME =~ "*mdu*multiplicand_reg[*]"}] 4.000
set_max_delay -from [get_cells -hier -filter {NAME =~ "*mdu*multiplier_reg[*]"}] -to [get_cells -hier -filter {NAME =~ "*mdu*multiplier_reg[*]"}] 4.000

# Multi-cycle path constraints for MDU operations
# These paths don't need to complete in a single clock cycle
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ "*mdu*mul_count_reg[*]"}]
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ "*mdu*div_count_reg[*]"}]
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ "*mdu*op_latched_reg[*]"}]
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ "*mdu*a_latched_reg[*]"}]
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ "*mdu*b_latched_reg[*]"}]

# CPU-MDU interface timing
set_max_delay -from [get_cells -hier -filter {NAME =~ "*mdu_start_reg"}] -to [get_cells -hier -filter {NAME =~ "*mdu*busy_reg"}] 5.000
set_max_delay -from [get_cells -hier -filter {NAME =~ "*mdu*done_reg"}] -to [get_cells -hier -filter {NAME =~ "*mdu_pending_reg[*]"}] 5.000

# Wishbone interface timing constraints
set_max_delay -from [get_cells -hier -filter {NAME =~ "*wb_cyc_reg"}] -to [get_ports *wb_cyc_o] 4.000
set_max_delay -from [get_cells -hier -filter {NAME =~ "*wb_stb_reg"}] -to [get_ports *wb_stb_o] 4.000

# Register file timing (32x32-bit register array)
set_max_delay -from [get_cells -hier -filter {NAME =~ "*regfile*registers_reg[*][*]"}] -to [get_cells -hier -filter {NAME =~ "*regfile*registers_reg[*][*]"}] 6.000

# ALU timing constraints
set_max_delay -from [get_cells -hier -filter {NAME =~ "*alu*"}] -to [get_cells -hier -filter {NAME =~ "*alu*"}] 6.000

# CSR unit timing
set_max_delay -from [get_cells -hier -filter {NAME =~ "*csr_unit*"}] -to [get_cells -hier -filter {NAME =~ "*csr_unit*"}] 5.000

# Exception unit timing
set_max_delay -from [get_cells -hier -filter {NAME =~ "*exception_unit*"}] -to [get_cells -hier -filter {NAME =~ "*exception_unit*"}] 4.000

# Critical register constraints - prevent optimization that could break timing
set_dont_touch [get_cells -hier -filter {NAME =~ "*mdu*remainder_reg_reg[*]"}]
set_dont_touch [get_cells -hier -filter {NAME =~ "*mdu*quotient_reg_reg[*]"}]
set_dont_touch [get_cells -hier -filter {NAME =~ "*mdu*state_reg[*]"}]

# Place and route constraints for better timing closure
# Keep MDU logic close together to minimize routing delays
create_pblock MDU_pblock
add_cells_to_pblock [get_pblocks MDU_pblock] [get_cells -hier -filter {NAME =~ "*mdu*"}]
resize_pblock [get_pblocks MDU_pblock] -add {SLICE_X0Y0:SLICE_X50Y100}

# Set higher priority for critical MDU nets
set_property HIGH_PRIORITY true [get_nets -hier -filter {NAME =~ "*mdu*remainder_reg[*]"}]
set_property HIGH_PRIORITY true [get_nets -hier -filter {NAME =~ "*mdu*quotient_reg[*]"}]

# Clock domain crossing constraints (if applicable)
set_clock_groups -asynchronous -group [get_clocks sys_clk]

# Configuration constraints
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Bitstream options
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]