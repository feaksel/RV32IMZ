# SoC Integration Place & Route Script
# Places all macros and routes top-level connections

set PDK_ROOT $env(PDK_ROOT)
set DESIGN rv32im_soc_complete

# Setup technology
set init_lef_file "${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd.tlef ${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
set init_verilog "outputs/${DESIGN}_syn.v"
set init_mmmc_file "mmmc/soc_mmmc.tcl"
set init_design_uniquify 1
set init_design_settop 1
set init_top_cell $DESIGN

# Load macro LEF files
lappend init_lef_file "../rv32im_integrated_macro/outputs/rv32im_integrated_macro.lef"
lappend init_lef_file "../memory_macro/outputs/memory_macro.lef"
lappend init_lef_file "../communication_macro/outputs/communication_macro.lef"
lappend init_lef_file "../protection_macro/outputs/protection_macro.lef"
lappend init_lef_file "../adc_subsystem_macro/outputs/adc_subsystem_macro.lef"
lappend init_lef_file "../pwm_accelerator_macro/outputs/pwm_accelerator_macro.lef"

init_design

# Pin placement
puts "Applying pin placement constraints..."
source scripts/soc_integration_pin_placement.tcl

# Floorplan (adjust size as needed)
floorPlan -site unithd -r 1.0 0.7 10 10 10 10

# Place macros
placeInstance rv32im_integrated_inst 50 50
placeInstance memory_inst 300 50
placeInstance comm_inst 50 300
placeInstance protection_inst 200 300
placeInstance adc_inst 350 300
placeInstance pwm_inst 500 300

# Power planning
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top met4 bottom met4 left met5 right met5} -width 2.0 -spacing 1.0

# Place standard cells
setPlaceMode -fp false
place_design

# Clock tree synthesis
create_ccopt_clock_tree_spec -file scripts/ccopt.spec
ccopt_design

# Route
setNanoRouteMode -quiet -droutePostRouteSwapVia false
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
routeDesign

# Optimization
optDesign -postRoute

# Reports
report_timing > outputs/${DESIGN}_final_timing.rpt
report_power > outputs/${DESIGN}_final_power.rpt
summaryReport -outFile outputs/${DESIGN}_summary.rpt

# Write outputs
streamOut outputs/${DESIGN}.gds -mapFile ${PDK_ROOT}/sky130A/libs.tech/openlane/sky130_fd_sc_hd/sky130_fd_sc_hd.map -merge {../rv32im_integrated_macro/outputs/rv32im_integrated_macro.gds ../memory_macro/outputs/memory_macro.gds ../communication_macro/outputs/communication_macro.gds ../protection_macro/outputs/protection_macro.gds ../adc_subsystem_macro/outputs/adc_subsystem_macro.gds ../pwm_accelerator_macro/outputs/pwm_accelerator_macro.gds}

write_lef_abstract outputs/${DESIGN}.lef

puts "SoC integration P&R complete - GDS ready for tapeout!"
exit
