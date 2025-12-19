# SoC Integration Synthesis Script
# Combines rv32im_integrated_macro + all peripheral macros

set PDK_ROOT $env(PDK_ROOT)
set DESIGN rv32im_soc_complete

# Setup library
set_db init_lib_search_path "${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/lib"
set_db init_hdl_search_path "../soc_integration/rtl:../rv32im_integrated_macro/outputs:../memory_macro/outputs:../communication_macro/outputs:../protection_macro/outputs:../adc_subsystem_macro/outputs:../pwm_accelerator_macro/outputs"

read_libs sky130_fd_sc_hd__tt_025C_1v80.lib

# Read pre-built macro netlists as black boxes
read_hdl -sv ../rv32im_integrated_macro/outputs/rv32im_integrated_macro_syn.v
read_hdl -sv ../memory_macro/outputs/memory_macro_syn.v
read_hdl -sv ../communication_macro/outputs/communication_macro_syn.v
read_hdl -sv ../protection_macro/outputs/protection_macro_syn.v
read_hdl -sv ../adc_subsystem_macro/outputs/adc_subsystem_macro_syn.v
read_hdl -sv ../pwm_accelerator_macro/outputs/pwm_accelerator_macro_syn.v

# Read top-level SoC wrapper
read_hdl -sv rtl/${DESIGN}.v

elaborate $DESIGN

# Mark all macros as don't touch
set_dont_touch [get_cells -hier rv32im_integrated_inst] true
set_dont_touch [get_cells -hier memory_inst] true
set_dont_touch [get_cells -hier comm_inst] true
set_dont_touch [get_cells -hier protection_inst] true
set_dont_touch [get_cells -hier adc_inst] true
set_dont_touch [get_cells -hier pwm_inst] true

# Timing constraints
create_clock -name clk -period 10.0 [get_ports clk]
set_input_delay -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]

# Synthesis (only wrapper logic, macros are black boxes)
syn_generic
syn_map
syn_opt

# Write outputs
write_hdl > outputs/${DESIGN}_syn.v
write_sdc > outputs/${DESIGN}.sdc
report_area > outputs/${DESIGN}_area.rpt
report_timing > outputs/${DESIGN}_timing.rpt
report_power > outputs/${DESIGN}_power.rpt

puts "SoC integration synthesis complete"
exit
