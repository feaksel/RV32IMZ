# Place and Route TCL Script for Core Macro
# Handles: Pipeline, Register File, ALU, Decoder, CSR, Exception handling
# Connects to external MDU macro

#==============================================================================
# Setup and Initialization
#==============================================================================

# Set variables
set DESIGN_NAME "core_macro"
set LIB_DIR "/home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib"
set TECH_DIR "/home/furka/RV32IMZ/pdk/sky130A/libs.tech/openlane/sky130_fd_sc_hd"

# Initialize Innovus
init_design

#==============================================================================
# Library and Technology Setup
#==============================================================================

# Load MMMC configuration
source mmmc/core_macro_mmmc.tcl

# Load technology files
read_physical -lef [list \
    "$TECH_DIR/sky130_fd_sc_hd.tlef" \
    "$TECH_DIR/sky130_fd_sc_hd.lef" \
]

# Load the synthesized netlist
read_netlist "netlist/core_macro_syn.v"

# Initialize the design
init_design -setup {setup_view} -hold {hold_view}

#==============================================================================
# Floorplan Creation
#==============================================================================

# Create initial floorplan - more rectangular for better routing
# Adjusted aspect ratio and utilization for better timing
floorPlan -site unithd -s 200.0 150.0 10.0 10.0 10.0 10.0

# Create power rings - simplified approach
addRing -nets {VDD VSS} -type core_rings -follow_io -layer {met1 met2} \
        -width 2.0 -spacing 2.0 -offset 2.0

#==============================================================================
# Power Planning
#==============================================================================

# Add power stripes for better power distribution
addStripe -nets {VDD VSS} -layer met2 -direction vertical \
          -width 1.0 -spacing 10.0 -number_of_sets 10

addStripe -nets {VDD VSS} -layer met3 -direction horizontal \
          -width 1.0 -spacing 10.0 -number_of_sets 8

# Add power connections
sroute -connect { blockPin padPin padRing corePin floatingStripe }

#==============================================================================
# Placement Configuration
#==============================================================================

# Configure placement for timing optimization
setPlaceMode -fp false -maxRouteLayer 5

# Place standard cells with optimization
placeDesign -inPlaceOpt -noPrePlaceOpt

# Post-placement optimization for timing
optDesign -preCTS -incr

#==============================================================================
# Clock Tree Synthesis
#==============================================================================

# Create clock tree specification
create_ccopt_clock_tree_spec

# Configure CTS for better skew control
set_ccopt_property target_max_trans 0.5
set_ccopt_property target_skew 0.1

# Build clock tree
ccopt_design

# Post-CTS optimization
optDesign -postCTS -incr

#==============================================================================
# Routing
#==============================================================================

# Configure routing for timing closure
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven true

# Global route
globalRoute

# Detailed routing
detailRoute

# Post-route optimization
optDesign -postRoute -incr

#==============================================================================
# Design Rule Check and Fixing
#==============================================================================

# Check and fix DRC violations
verifyGeometry -allowedMetalOverlap -report violations/core_macro_geometry.rpt

# Fix any remaining shorts
ecoRoute -fix_drc

#==============================================================================
# Timing Analysis and Reports
#==============================================================================

# Update timing with actual parasitics
setExtractMode -engine postRoute

# Extract parasitics
extractRC

# Timing analysis
timeDesign -postRoute -si

# Generate detailed reports
report_timing -check_type setup -max_paths 20 -format gtd > reports/core_macro_final_setup.rpt
report_timing -check_type hold -max_paths 20 -format gtd > reports/core_macro_final_hold.rpt

# Area and utilization reports  
report_area > reports/core_macro_final_area.rpt
summaryReport -noHtml -outFile reports/core_macro_summary.rpt

#==============================================================================
# Power Analysis
#==============================================================================

# Power analysis with actual layout
report_power > reports/core_macro_final_power.rpt

#==============================================================================
# Physical Verification
#==============================================================================

# Check connectivity
verifyConnectivity -type all -report violations/core_macro_connectivity.rpt

# Metal density check
checkMetalDensity -detailed -report violations/core_macro_density.rpt

#==============================================================================
# Export Final Results
#==============================================================================

# Export GDS
streamOut outputs/core_macro.gds -mapFile $TECH_DIR/sky130_fd_sc_hd.map \
          -libName core_macro -stripes 1 -units 1000 -mode ALL

# Export DEF
defOut -floorplan -netlist -routing outputs/core_macro.def

# Export LEF (for integration with top-level)
write_lef_abstract -5.8 outputs/core_macro.lef

# Export timing information
write_sdf -corners typical_corner outputs/core_macro.sdf

# Export netlist with physical information
saveNetlist outputs/core_macro_final.v -includeLeafCell -excludePowerGround

# Save final database
saveDesign outputs/core_macro_final.enc

#==============================================================================
# Final Quality Checks
#==============================================================================

# Summary information
puts "=========================================="
puts "Core Macro Place and Route Complete"
puts "=========================================="

# Get final metrics
set utilization [dbGet top.fPlan.coreBox_area]
set total_cells [llength [dbGet top.insts]]

puts "Design: $DESIGN_NAME"
puts "Total Cells: $total_cells"
puts "Core Area: $utilization"

# Check final timing
set setup_slack [timeDesign -postRoute -setup]
set hold_slack [timeDesign -postRoute -hold]

puts "Final Setup Slack: $setup_slack"
puts "Final Hold Slack: $hold_slack"

# Check for violations
if {$setup_slack < 0} {
    puts "WARNING: Setup violations exist!"
    puts "Check reports/core_macro_final_setup.rpt for details"
} else {
    puts "Setup timing: CLEAN"
}

if {$hold_slack < 0} {
    puts "WARNING: Hold violations exist!"
    puts "Check reports/core_macro_final_hold.rpt for details"
} else {
    puts "Hold timing: CLEAN"
}

# DRC summary
set drc_violations [verifyGeometry -report violations/core_macro_final_drc.rpt]
if {$drc_violations > 0} {
    puts "WARNING: $drc_violations DRC violations detected!"
} else {
    puts "DRC: CLEAN"
}

puts "Final database: outputs/core_macro_final.enc"
puts "GDS file: outputs/core_macro.gds"
puts "LEF file: outputs/core_macro.lef"
puts "=========================================="

# Exit Innovus
exit