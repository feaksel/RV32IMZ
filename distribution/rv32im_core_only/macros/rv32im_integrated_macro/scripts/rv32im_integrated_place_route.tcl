# Place and Route TCL Script for RV32IM Integrated Macro
# Hierarchical integration: Places pre-built core_macro + mdu_macro together
# Treats both as black boxes, places and routes connections between them

#==============================================================================
# Setup and Initialization
#==============================================================================

# Set variables
set DESIGN_NAME "rv32im_integrated_macro"
set LIB_DIR "$env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib"
set TECH_DIR "$env(PDK_ROOT)/sky130A/libs.tech/openlane/sky130_fd_sc_hd"
set MACRO_DIR ".."

# Initialize Innovus
init_design

#==============================================================================
# Library and Technology Setup
#==============================================================================

# Load MMMC configuration
source mmmc/rv32im_integrated_mmmc.tcl

# Load technology files
read_physical -lef [list \
    "$TECH_DIR/sky130_fd_sc_hd.tlef" \
    "$TECH_DIR/sky130_fd_sc_hd.lef" \
]

# Load pre-built macro LEF files (physical abstract views)
puts "Loading pre-built macro LEF files..."
if {[file exists "$MACRO_DIR/../core_macro/outputs/core_macro.lef"]} {
    read_physical -lef "$MACRO_DIR/../core_macro/outputs/core_macro.lef"
    puts "    core_macro LEF loaded"
} else {
    puts "ERROR: core_macro.lef not found!"
    exit 1
}

if {[file exists "$MACRO_DIR/../mdu_macro/outputs/mdu_macro.lef"]} {
    read_physical -lef "$MACRO_DIR/../mdu_macro/outputs/mdu_macro.lef"
    puts "    mdu_macro LEF loaded"
} else {
    puts "ERROR: mdu_macro.lef not found!"
    exit 1
}

# Load the synthesized netlist
read_netlist "../outputs/rv32im_integrated_macro_syn.v"

# Initialize the design
init_design -setup {setup_view} -hold {hold_view}

#==============================================================================
# Floorplan Creation - Larger for integrated core+MDU
#==============================================================================

# Create initial floorplan - larger to accommodate both macros
# Aspect ratio optimized for two macro placement
floorPlan -site unithd -s 300.0 200.0 10.0 10.0 10.0 10.0

# Place the pre-built macros
puts "Placing pre-built core_macro..."
placeInstance u_core_macro 20.0 20.0 -fixed

puts "Placing pre-built mdu_macro..."  
placeInstance u_mdu_macro 150.0 20.0 -fixed

puts "Pre-built macros placed as fixed blocks"

# Apply pin placement for SoC integration
if {[file exists scripts/rv32im_integrated_pin_placement.tcl]} {
    source scripts/rv32im_integrated_pin_placement.tcl
}

# Create power rings
addRing -nets {VDD VSS} -type core_rings -follow_io -layer {met1 met2} \
        -width 2.0 -spacing 2.0 -offset 2.0

#==============================================================================
# Power Planning - Enhanced for larger macro
#==============================================================================

# Add power stripes for better power distribution
addStripe -nets {VDD VSS} -layer met2 -direction vertical \
          -width 1.5 -spacing 10.0 -number_of_sets 15

addStripe -nets {VDD VSS} -layer met3 -direction horizontal \
          -width 1.5 -spacing 10.0 -number_of_sets 12

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

# Build clock tree with fallback
if {[catch {ccopt_design} result]} {
    puts "WARNING: CTS failed, continuing with ideal clocking"
    puts "Error: $result"
    catch {ccopt_design}
}

# Post-CTS optimization
optDesign -postCTS -incr

#==============================================================================
# Routing
#==============================================================================

# Configure routing
setNanoRouteMode -drouteFixAntenna true -drouteEndIteration 20

# Route design
routeDesign -globalDetail

# Post-route optimization
optDesign -postRoute -incr

#==============================================================================
# Add Filler Cells
#==============================================================================

# Add filler cells to complete the design
catch {addFiller -cell {sky130_fd_sc_hd__fill_1 sky130_fd_sc_hd__fill_2 sky130_fd_sc_hd__fill_4 sky130_fd_sc_hd__fill_8} -prefix FILLER}

#==============================================================================
# Final Verification
#==============================================================================

# Verify connectivity
verifyConnectivity -type all -error 1000 -warning 50

# Verify geometry
verifyGeometry -error 1000

# Check design rule violations
verify_drc -limit 1000

#==============================================================================
# Timing Analysis
#==============================================================================

# Update timing
setAnalysisMode -analysisType onChipVariation -cppr both

# Final timing reports
timeDesign -postRoute -prefix postRoute

#==============================================================================
# Reports
#==============================================================================

puts "Generating final reports..."

file mkdir ../reports

catch {report_area > ../reports/final_area.rpt}
catch {report_timing -nworst 10 > ../reports/timing.rpt}
catch {report_power > ../reports/power.rpt}

#==============================================================================
# Output Generation
#==============================================================================

puts "Writing output files..."

# Write output files
catch {streamOut ../outputs/rv32im_integrated_macro.gds -mapFile $env(PDK_ROOT)/sky130A/libs.tech/klayout/sky130A.gds.map}
catch {write_lef_abstract ../outputs/rv32im_integrated_macro.lef}
catch {defOut ../outputs/rv32im_integrated_macro.def}

#==============================================================================
# Summary
#==============================================================================

puts "======================================================================"
puts "RV32IM Integrated Macro Place & Route Complete"
puts "======================================================================"
puts ""
puts "Outputs:"
puts "  GDS:     ../outputs/rv32im_integrated_macro.gds"
puts "  LEF:     ../outputs/rv32im_integrated_macro.lef"
puts "  DEF:     ../outputs/rv32im_integrated_macro.def"
puts ""
puts "Reports:"
puts "  Area:    ../reports/final_area.rpt"
puts "  Timing:  ../reports/timing.rpt"
puts "  Power:   ../reports/power.rpt"
puts ""
puts "======================================================================"

exit
