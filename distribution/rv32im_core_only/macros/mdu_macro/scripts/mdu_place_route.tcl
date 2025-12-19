# Innovus TCL Script for MDU Macro Place & Route
# Based on the main core P&R flow
# Optimized for timing closure

puts "=========================================="
puts "Starting MDU Macro Place & Route"
puts "=========================================="

set DESIGN_NAME "mdu_macro"
set OUTPUT_DIR "../outputs"
set REPORT_DIR "../reports"

#==============================================================================
# Initialize Design
#==============================================================================

# LEF files
set init_lef_file {
    ../../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd__tech.lef
    ../../pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
}

# Netlist from synthesis
set init_verilog ${OUTPUT_DIR}/${DESIGN_NAME}_netlist.v

# Design name
set init_top_cell ${DESIGN_NAME}

# Power/Ground
set init_pwr_net VDD
set init_gnd_net VSS

# MMMC file (simplified for macro)
set init_mmmc_file ../mmmc/mmmc_mdu.tcl

# Initialize design
init_design

#==============================================================================
# Pin Placement
#==============================================================================

puts "Applying pin placement constraints..."
source scripts/mdu_pin_placement.tcl

#==============================================================================
# Floorplanning
#==============================================================================

puts "Creating floorplan..."

# Create floorplan - compact for macro
floorPlan -s 60 60 5 5 5 5

# Add power stripes for macro
addStripe -nets {VDD VSS} -layer met1 -direction vertical -width 0.48 -spacing 2.0 -number_of_sets 3
addStripe -nets {VDD VSS} -layer met2 -direction horizontal -width 0.48 -spacing 2.0 -number_of_sets 3

# Create power rings
addRing -nets {VDD VSS} -layer {top met1 bottom met1 left met2 right met2} -width 0.96 -spacing 0.5 -offset 1.0

#==============================================================================
# Placement
#==============================================================================

puts "Starting placement..."

# Set placement effort
setPlaceMode -effort high -modulePlan true

# Place design
placeDesign -effort high

# Optimize placement
refinePlace

#==============================================================================
# Clock Tree Synthesis
#==============================================================================

puts "Running Clock Tree Synthesis..."

# CTS configuration for macro
set_ccopt_property target_skew 0.1
set_ccopt_property target_max_trans 0.2

# Run CTS
ccopt_design

#==============================================================================
# Routing
#==============================================================================

puts "Starting routing..."

# Set routing mode for macro (tighter DRCs)
setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -routeTopRoutingLayer 5
setNanoRouteMode -routeBottomRoutingLayer 1
setNanoRouteMode -drouteRedundantViaInsertion true

# Route design
routeDesign -effort high

#==============================================================================
# Post-Route Optimization
#==============================================================================

puts "Post-route optimization..."

# Fix any timing violations
optDesign -postRoute -effort high

# Fix any DRC violations
setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -droutePostRouteSpreadWire true

# Additional cleanup routing
routeDesign -effort high -wireOpt

#==============================================================================
# Generate Reports
#==============================================================================

puts "Generating reports..."

# Timing reports
report_timing -max_paths 10 > ${REPORT_DIR}/post_route_timing.rpt
report_timing -hold -max_paths 10 > ${REPORT_DIR}/hold_timing.rpt

# Physical reports
report_design_summary > ${REPORT_DIR}/design_summary.rpt
summaryReport -outfile ${REPORT_DIR}/summary.rpt

# DRC check
verify_drc -report ${REPORT_DIR}/drc.rpt

# Power analysis
report_power > ${REPORT_DIR}/power.rpt

#==============================================================================
# Write Outputs
#==============================================================================

puts "Writing final outputs..."

# LEF file for top-level integration
write_lef_abstract ${OUTPUT_DIR}/${DESIGN_NAME}.lef

# LIB file for timing
write_timing_library ${OUTPUT_DIR}/${DESIGN_NAME}.lib

# GDS file
streamOut ${OUTPUT_DIR}/${DESIGN_NAME}.gds

# Final netlist
saveNetlist ${OUTPUT_DIR}/${DESIGN_NAME}_final.v

# DEF file
defOut -routing ${OUTPUT_DIR}/${DESIGN_NAME}.def

# SDF for simulation
write_sdf ${OUTPUT_DIR}/${DESIGN_NAME}.sdf

puts "=========================================="
puts "MDU Macro P&R completed successfully!"
puts "Generated files:"
puts "  LEF: ${OUTPUT_DIR}/${DESIGN_NAME}.lef"
puts "  LIB: ${OUTPUT_DIR}/${DESIGN_NAME}.lib"
puts "  GDS: ${OUTPUT_DIR}/${DESIGN_NAME}.gds"
puts "  Netlist: ${OUTPUT_DIR}/${DESIGN_NAME}_final.v"
puts "=========================================="