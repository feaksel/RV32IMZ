# RV32IMZ Core Timing Constraints (SDC format)
# For synthesis tools supporting Synopsys Design Constraints

# Main system clock - 100 MHz (10ns period) for conservative timing closure
create_clock -name sys_clk -period 10.0 [get_ports clk]

# Clock uncertainty for synthesis (allows for clock jitter/skew)
set_clock_uncertainty 0.5 [get_clocks sys_clk]

# Input/Output delays relative to clock
set_input_delay -clock sys_clk 2.0 [get_ports rst_n]
set_input_delay -clock sys_clk 3.0 [get_ports {iwb_dat_i[*] dwb_dat_i[*] iwb_ack_i dwb_ack_i}]
set_output_delay -clock sys_clk 3.0 [get_ports {iwb_adr_o[*] iwb_dat_o[*] iwb_cyc_o iwb_stb_o iwb_we_o}]
set_output_delay -clock sys_clk 3.0 [get_ports {dwb_adr_o[*] dwb_dat_o[*] dwb_cyc_o dwb_stb_o dwb_we_o dwb_sel_o[*]}]

# MDU Critical Timing Constraints
# Division algorithm has critical paths that need special attention

# Critical path: 33-bit comparison in division algorithm
set_max_delay -from [get_pins custom_riscv_core/mdu/remainder_reg_reg[*]/Q] -to [get_pins custom_riscv_core/mdu/quotient_reg_reg[*]/D] 8.0

# Critical path: 33-bit subtraction in division
set_max_delay -from [get_pins custom_riscv_core/mdu/remainder_reg_reg[*]/Q] -to [get_pins custom_riscv_core/mdu/remainder_reg_reg[*]/D] 8.5

# Division counter and state machine paths
set_max_delay -from [get_pins custom_riscv_core/mdu/div_count_reg[*]/Q] -to [get_pins custom_riscv_core/mdu/state_reg[*]/D] 5.0

# Multiplication accumulator critical path (64-bit addition)
set_max_delay -from [get_pins custom_riscv_core/mdu/acc_reg[*]/Q] -to [get_pins custom_riscv_core/mdu/acc_reg[*]/D] 7.0

# Multiplicand and multiplier shift operations
set_max_delay -from [get_pins custom_riscv_core/mdu/multiplicand_reg[*]/Q] -to [get_pins custom_riscv_core/mdu/multiplicand_reg[*]/D] 4.0
set_max_delay -from [get_pins custom_riscv_core/mdu/multiplier_reg[*]/Q] -to [get_pins custom_riscv_core/mdu/multiplier_reg[*]/D] 4.0

# Multi-cycle paths for MDU operations (not critical every cycle)
set_multicycle_path -setup 2 -from [get_pins custom_riscv_core/mdu/mul_count_reg[*]/Q]
set_multicycle_path -setup 2 -from [get_pins custom_riscv_core/mdu/div_count_reg[*]/Q]
set_multicycle_path -setup 2 -from [get_pins custom_riscv_core/mdu/op_latched_reg[*]/Q]

# CPU-MDU interface timing
set_max_delay -from [get_pins custom_riscv_core/mdu_start_reg/Q] -to [get_pins custom_riscv_core/mdu/busy_reg/D] 5.0
set_max_delay -from [get_pins custom_riscv_core/mdu/done_reg/Q] -to [get_pins custom_riscv_core/mdu_pending_reg[*]/D] 5.0

# Wishbone interface timing
set_max_delay -from [get_pins custom_riscv_core/*wb_cyc_reg/Q] -to [get_ports *wb_cyc_o] 4.0
set_max_delay -from [get_pins custom_riscv_core/*wb_stb_reg/Q] -to [get_ports *wb_stb_o] 4.0

# Register file timing (32x32 register array)
set_max_delay -from [get_pins custom_riscv_core/regfile/registers_reg[*][*]/Q] -to [get_pins custom_riscv_core/regfile/registers_reg[*][*]/D] 6.0

# ALU timing constraints
set_max_delay -from [get_pins custom_riscv_core/alu/a[*]] -to [get_pins custom_riscv_core/alu/result[*]] 6.0

# CSR unit timing
set_max_delay -from [get_pins custom_riscv_core/csr_unit/mstatus_reg[*]/Q] -to [get_pins custom_riscv_core/csr_unit/csr_rdata[*]] 5.0

# Exception unit timing
set_max_delay -from [get_pins custom_riscv_core/exception_unit/*] -to [get_pins custom_riscv_core/trap_*] 4.0

# Don't touch critical MDU registers during optimization
set_dont_touch [get_cells custom_riscv_core/mdu/remainder_reg_reg[*]]
set_dont_touch [get_cells custom_riscv_core/mdu/quotient_reg_reg[*]]
set_dont_touch [get_cells custom_riscv_core/mdu/state_reg[*]]

# Clock domain constraints
set_clock_groups -asynchronous -group [get_clocks sys_clk]

# Environmental constraints
set_operating_conditions -grade C -max_library your_library_worst_case -min_library your_library_best_case
set_wire_load_model -name conservative -library your_library