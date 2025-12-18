#===============================================================================
# Cadence Innovus Place & Route Script
# For: Custom RISC-V Core (RV32IM)
# Target: School technology library
#===============================================================================

# Paths relative to synthesis_cadence/ directory
set TECH_LIB_PATH "../pdk/sky130A/libs.ref"
set DESIGN_PATH "outputs"
set SRAM_LIB_PATH "$TECH_LIB_PATH/sky130_sram_macros"

#===============================================================================
# Initialize
#===============================================================================

puts "Initializing Innovus..."

# Set paths - Load tech LEF (layers) first, then cell LEF (cells)
set init_lef_file "$TECH_LIB_PATH/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef $TECH_LIB_PATH/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
set init_verilog "$DESIGN_PATH/core_netlist.v"
set init_design_netlist "$DESIGN_PATH/core_netlist.v"
set init_top_cell custom_riscv_core

# Power/ground nets
set init_pwr_net VDD
set init_gnd_net VSS

# Technology file (improved MMMC handling based on research)
puts "==> Setting up MMMC configuration..."

# CRITICAL: Never load libraries after MMMC! 
# Libraries must be defined within MMMC configuration files
proc setup_innovus_mmmc {} {
    global TECH_LIB_PATH
    
    # Try enhanced MMMC first
    if {[file exists "mmmc.tcl"]} {
        if {[catch {
            puts "==> Attempting enhanced MMMC setup..."
            set init_mmmc_file mmmc.tcl
        } err]} {
            puts "WARNING:  Enhanced MMMC failed: $err"
            return "mmmc_simple.tcl"
        }
        return "mmmc.tcl"
    } else {
        puts "==> Using simple MMMC fallback..."
        return "mmmc_simple.tcl"
    }
}

set init_mmmc_file [setup_innovus_mmmc]
puts "Using MMMC file: $init_mmmc_file"

# Read design (with error handling)
puts "Reading design with MMMC file: $init_mmmc_file"
if {[catch {init_design} err]} {
    puts "Error with main MMMC: $err"
    puts "Trying simple MMMC..."
    set init_mmmc_file mmmc_simple.tcl
    init_design
}

#===============================================================================
# Floorplan
#===============================================================================

puts "Creating floorplan..."

# Create floorplan (smaller for core only)
# Utilization: 0.7 = 70% (leave 30% for routing)
# Aspect ratio: 1.0 = square chip
# Core to IO spacing: 5 microns (smaller core)
floorPlan -site unithd -r 0.7 1.0 5 5 5 5

# Or specify absolute size for core (much smaller than SoC)
# floorPlan -site unithd -s 100 100 5 5 5 5  # 100x100 microns

# View floorplan
# gui_show

#===============================================================================
# Power Planning
#===============================================================================

puts "Adding power rings and stripes..."

# Add power rings around core
addRing -nets {VDD VSS} \
        -width 2 \
        -spacing 1 \
        -layer {top metal5 bottom metal5 left metal6 right metal6}

# Add power stripes
addStripe -nets {VDD VSS} \
          -layer metal4 \
          -direction vertical \
          -width 1 \
          -spacing 1 \
          -number_of_sets 4

addStripe -nets {VDD VSS} \
          -layer metal3 \
          -direction horizontal \
          -width 1 \
          -spacing 1 \
          -number_of_sets 4

# Special route (connect power/ground)
sroute -connect { blockPin padPin padRing corePin floatingStripe } \
       -layerChangeRange { metal1 metal6 } \
       -blockPinTarget { nearestTarget } \
       -padPinPortConnect { allPort oneGeom } \
       -padPinTarget { nearestTarget } \
       -corePinTarget { firstAfterRowEnd } \
       -floatingStripeTarget { blockring padring ring stripe ringpin blockpin followpin } \
       -allowJogging 1 \
       -crossoverViaLayerRange { metal1 metal6 } \
       -nets { VDD VSS } \
       -allowLayerChange 1 \
       -blockPin useLef \
       -targetViaLayerRange { metal1 metal6 }

#===============================================================================
# Placement
#===============================================================================

puts "Placing standard cells..."

# Set placement mode
setPlaceMode -fp false

# Place design
placeDesign

# Add filler cells (to fill gaps between cells)
# Update cell names based on your library
addFiller -cell {FILL1 FILL2 FILL4 FILL8} -prefix FILLER

# Optimize placement
refinePlace

# Check placement
checkPlace

#===============================================================================
# Pre-CTS Optimization
#===============================================================================

puts "Pre-CTS optimization..."

# Set optimization mode (disable AAF-SI since we don't have OCV timing)
setOptMode -fixCap true -fixTran true -fixFanoutLoad true -aafAAFOpt false

# Optimize
optDesign -preCTS

#===============================================================================
# Clock Tree Synthesis (PDK-Aware)
#===============================================================================

puts "==> Clock Tree Synthesis Phase..."

# Detect PDK capabilities by checking for clock buffer cells
proc check_cts_capability {} {
    set clock_cells [get_lib_cells -quiet "*clkbuf*"]
    if {[llength $clock_cells] > 0} {
        puts "SUCCESS: Clock buffer cells detected: [llength $clock_cells] cells"
        return 1
    } else {
        puts "WARNING:  No clock buffer cells found - minimal PDK detected"
        return 0
    }
}

set cts_capable [check_cts_capability]

if {$cts_capable} {
    puts "==> Running Clock Tree Synthesis..."
    
    # Create clock tree specification
    if {[catch {
        create_ccopt_clock_tree_spec -file ccopt.spec
        puts "SUCCESS: Clock tree specification created"
        
        # Run CTS
        ccopt_design
        puts "SUCCESS: Clock tree synthesis completed"
        
        # Report clock tree quality
        report_ccopt_clock_trees -file reports/clock_tree.rpt
        puts "SUCCESS: Clock tree report generated"
        
    } err]} {
        puts "WARNING:  CTS failed, falling back to simple clock routing: $err"
        puts "   Clock will be routed as regular net"
    }
    
} else {
    puts "==> Minimal PDK: Skipping CTS, using simple clock routing..."
    puts "   Clock will be routed as regular net (acceptable for academic demo)"
    puts "   Note: This may result in clock skew, but design will complete"
}

#===============================================================================
# Post-CTS Optimization (PDK-Aware)
#===============================================================================

if {$cts_capable && ![catch {get_ccopt_clock_trees}]} {
    puts "==> Running post-CTS optimization..."
    optDesign -postCTS
    puts "SUCCESS: Post-CTS optimization completed"
} else {
    puts "==> Skipping post-CTS optimization (no CTS performed)"
}
# optDesign -postCTS -hold

#===============================================================================
# Routing
#===============================================================================

puts "Routing design..."

# Set routing mode
setNanoRouteMode -quiet -drouteFixAntenna true
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true

# Global routing
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override

# Route design
routeDesign

#===============================================================================
# Post-Route Optimization
#===============================================================================

puts "Post-route optimization..."

# Optimize timing
optDesign -postRoute

# Fix hold violations
optDesign -postRoute -hold

# Final optimization
optDesign -postRoute -incr

#===============================================================================
# Filler Cells (if not done earlier)
#===============================================================================

# Add/update filler if needed
# deleteFiller -prefix FILLER
# addFiller -cell {FILL1 FILL2 FILL4 FILL8} -prefix FILLER

#===============================================================================
# Verification (with error handling)
#===============================================================================

puts "Verifying design (with crash protection)..."

# Create reports directory
exec mkdir -p reports

# Verify connectivity (with error handling)
if {[catch {verify_connectivity -report reports/connectivity.rpt} err]} {
    puts "WARNING: Connectivity verification failed: $err"
    puts "Continuing anyway for academic demo..."
}

# Verify geometry (with error handling) 
if {[catch {verify_geometry -report reports/geometry.rpt} err]} {
    puts "WARNING: Geometry verification failed: $err"
    puts "Continuing anyway for academic demo..."
}

# Check DRC (with error handling)
if {[catch {verify_drc -report reports/drc.rpt -limit 1000} err]} {
    puts "WARNING: DRC verification failed: $err"
    puts "Continuing anyway for academic demo..."
}

#===============================================================================
# Reports
#===============================================================================

puts "Generating reports..."

# Timing reports
report_timing -nworst 10 > reports/post_route_timing.rpt
report_timing -nworst 10 -path_type full > reports/post_route_timing_full.rpt

# Setup timing
report_timing -late > reports/setup_timing.rpt

# Hold timing
report_timing -early > reports/hold_timing.rpt

# Area report
report_area > reports/post_route_area.rpt

# Power report
report_power > reports/post_route_power.rpt

# Summary
summaryReport -outfile reports/summary.rpt

# Clock tree report
report_ccopt_clock_trees -file reports/clock_tree.rpt

#===============================================================================
# Extract Parasitics
#===============================================================================

puts "Extracting parasitics..."

# Extract RC
extractRC

# Write SDF for post-layout simulation
write_sdf outputs/post_route.sdf

#===============================================================================
# Save Design
#===============================================================================

puts "Saving design..."

# Save design database
saveDesign final_design.enc

#===============================================================================
# Generate Outputs (Bulletproof GDS Generation)
#===============================================================================

puts "Generating output files..."

# Create outputs directory
exec mkdir -p outputs

# Save design database first
saveDesign outputs/final_design.enc

# Generate GDSII stream file with error handling
puts "Generating GDSII file..."
if {[catch {
    # Try with complete GDS map file path
    if {[file exists $TECH_LIB_PATH/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.map]} {
        streamOut outputs/core_final.gds \
                  -mapFile $TECH_LIB_PATH/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.map \
                  -stripes 1 \
                  -units 1000 \
                  -mode ALL
    } else {
        # Fallback: generate without map file if missing
        puts "Warning: GDS map file not found, generating without it"
        streamOut outputs/core_final.gds \
                  -stripes 1 \
                  -units 1000 \
                  -mode ALL
    }
} err]} {
    puts "Error generating GDS with streamOut: $err"
    puts "Trying alternative GDS generation method..."
    
    # Alternative method: save as DEF and generate basic GDS
    if {[catch {
        defOut -floorplan -netlist -routing outputs/core_final.def
        puts "DEF file generated successfully"
        
        # Try basic GDS generation
        streamOut outputs/core_final.gds -units 1000 -mode ALL
        puts "Basic GDS file generated successfully"
    } err2]} {
        puts "ERROR: Both GDS generation methods failed:"
        puts "Method 1 error: $err"
        puts "Method 2 error: $err2"
        puts "Check PDK installation and try manual GDS export"
    }
}

# Generate other output files
puts "Generating netlist and other outputs..."

# Post-route netlist
if {[catch {saveNetlist outputs/core_post_route_netlist.v} err]} {
    puts "Warning: Netlist generation failed: $err"
}

# DEF file (always try to generate)
if {[catch {defOut -floorplan -netlist -routing outputs/core_final.def} err]} {
    puts "Warning: DEF generation failed: $err"
}

# SDF timing file
if {[catch {write_sdf outputs/post_route.sdf} err]} {
    puts "Warning: SDF generation failed: $err"
}

# Check what files were actually created
puts "\nFiles generated:"
exec ls -la outputs/

#===============================================================================
# Screenshots for Report
#===============================================================================

puts "Taking screenshots..."

# Show full chip
fit
# Take screenshot: File -> Save Image -> PNG

# Show zoomed view
zoomBox 50 50 150 150
# Take screenshot

# Show detail view
zoomBox 75 75 125 125
# Take screenshot

#===============================================================================
# Summary
#===============================================================================

puts "\n========================================="
puts "Place & Route Complete!"
puts "========================================="
puts ""
puts "Check reports:"
puts "  reports/drc.rpt              - DRC violations (should be 0)"
puts "  reports/connectivity.rpt     - Connectivity check"
puts "  reports/post_route_timing.rpt - Final timing"
puts "  reports/post_route_area.rpt  - Final area"
puts "  reports/post_route_power.rpt - Final power"
puts ""
puts "Output files:"
puts "  outputs/design.gds           - GDSII layout"
puts "  outputs/post_route_netlist.v - Final netlist"
puts "  outputs/design.def           - DEF file"
puts "  outputs/post_route.sdf       - Timing delays"
puts ""
puts "To view layout:"
puts "  1. In Innovus GUI: File -> Load Design"
puts "  2. In Virtuoso: Open outputs/design.gds"
puts ""
puts "For report, include:"
puts "  1. Floorplan screenshot"
puts "  2. Full chip layout"
puts "  3. Zoomed cell view"
puts "  4. Clock tree visualization"
puts "  5. Timing/area/power numbers"
puts ""
puts "If DRC violations exist:"
puts "  1. Check reports/drc.rpt for details"
puts "  2. May need to adjust floorplan or routing"
puts "  3. Consult with TA/professor"
puts ""
puts "========================================="

# Open GUI for viewing (if not already open)
# gui_show

    
