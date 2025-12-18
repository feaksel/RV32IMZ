#===============================================================================
# Cadence Innovus Place and Route Script - Communication Macro
# Based on proven working place_route.tcl
# For: Communication Macro (UART, SPI, I2C)
#===============================================================================

# Paths (relative to macro directory)
set TECH_PATH "../../../../pdk/sky130A"
set NETLIST_PATH "outputs/communication_macro_netlist.v"
set SDC_PATH "outputs/communication_macro_constraints.sdc"

#===============================================================================
# Setup MMMC - Same as Working Script
#===============================================================================

# MMMC setup script path
set MMMC_SCRIPT "../mmmc/communication_macro_mmmc.tcl"

# Create MMMC script if it doesn't exist
if {![file exists $MMMC_SCRIPT]} {
    puts "Creating MMMC script..."
    exec mkdir -p [file dirname $MMMC_SCRIPT]
    
    set mmmc_file [open $MMMC_SCRIPT w]
    puts $mmmc_file "# MMMC Script for Communication Macro"
    puts $mmmc_file "\n# Create library set"
    puts $mmmc_file "create_library_set -name tt_lib_set -timing {$TECH_PATH/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib}"
    puts $mmmc_file "\n# Create constraint mode"
    puts $mmmc_file "create_constraint_mode -name func_mode -sdc_files {$SDC_PATH}"
    puts $mmmc_file "\n# Create RC corner"
    puts $mmmc_file "create_rc_corner -name tt_rc -cap_table {$TECH_PATH/libs.tech/openlane/sky130_fd_sc_hd/sky130_fd_sc_hd.captable}"
    puts $mmmc_file "\n# Create delay corner"
    puts $mmmc_file "create_delay_corner -name tt_delay -library_set tt_lib_set -rc_corner tt_rc"
    puts $mmmc_file "\n# Create analysis view"
    puts $mmmc_file "create_analysis_view -name tt_view -constraint_mode func_mode -delay_corner tt_delay"
    puts $mmmc_file "\n# Set analysis view"
    puts $mmmc_file "set_analysis_view -setup tt_view -hold tt_view"
    close $mmmc_file
}

#===============================================================================
# Design Import - Same as Working Script
#===============================================================================

puts "Setting up design import..."

# Set library and LEF paths
set init_lef_file {
    /home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
    /home/furka/RV32IMZ/pdk/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
}

# Set verilog file
set init_verilog $NETLIST_PATH

# Set MMMC file
set init_mmmc_file $MMMC_SCRIPT

# Set design name
set init_design_name communication_macro

# Set additional variables for robust import
set init_import_mode {-treat_unresolved_modules_as_black_box}

# Import design
puts "Importing design..."
init_design

#===============================================================================
# Floorplan - Same as Working Script
#===============================================================================

puts "Creating floorplan..."

# Get die area
set bbox [get_db design .bbox]
if {$bbox == ""} {
    # If no bbox, create one based on cell area
    floorPlan -r 1.0 0.7 5.0 5.0 5.0 5.0
} else {
    # Use existing bbox
    puts "Using existing die area from design"
}

# Add core rings if area is sufficient
catch {
    addRing -nets {VDD VSS} -type core_rings -follow core -layer {met4 met5} -width 1.8 -spacing 0.5 -offset 1.8
}

# Add power stripes
catch {
    addStripe -nets {VDD VSS} -layer met1 -direction vertical -width 0.48 -spacing 5.44 -set_to_set_distance 20.0
}

#===============================================================================
# Placement - Same as Working Script
#===============================================================================

puts "Running placement..."

# Global placement
place_design

# Check placement
check_place

#===============================================================================
# Clock Tree Synthesis - Same as Working Script
#===============================================================================

puts "Running clock tree synthesis..."

# Try to run CTS, with fallback
if {[catch {ccopt_design} result]} {
    puts "CTS failed, trying alternate approach: $result"
    # Fallback: try with simpler settings
    if {[catch {create_clock_tree_spec -out_dir clock_tree} result2]} {
        puts "Clock tree creation failed: $result2"
        # Continue without CTS for simple designs
    } else {
        catch {ccopt_design}
    }
}

#===============================================================================
# Routing - Same as Working Script  
#===============================================================================

puts "Running routing..."

# Global and detailed routing
if {[catch {routeDesign -globalDetail} result]} {
    puts "Global+Detail routing failed: $result"
    puts "Trying step-by-step routing..."
    
    # Try global routing first
    if {[catch {globalRoute} result2]} {
        puts "Global routing failed: $result2"
    }
    
    # Then detailed routing
    if {[catch {detailRoute} result3]} {
        puts "Detail routing failed: $result3"
    }
}

#===============================================================================
# Design Rule Check - Same as Working Script
#===============================================================================

puts "Running design checks..."

# Basic connectivity check
catch {verifyConnectivity}

#===============================================================================
# Reports and Output - Same as Working Script
#===============================================================================

puts "Generating reports and outputs..."

# Create directories
exec mkdir -p reports outputs

# Generate reports
catch {report_area > reports/area.rpt}
catch {report_timing -nworst 10 > reports/timing.rpt}
catch {report_power > reports/power.rpt}

# Write output files
catch {streamOut outputs/communication_macro.gds -mapFile /home/furka/RV32IMZ/pdk/sky130A/libs.tech/klayout/sky130A.gds.map}
catch {write_lef_abstract outputs/communication_macro.lef}
catch {defOut outputs/communication_macro.def}

#===============================================================================
# Summary - Same as Working Script
#===============================================================================

puts "\n======================================="
puts "Communication Macro P&R Complete!"
puts "======================================="
puts ""
puts "Output files (if successful):"
puts "  outputs/communication_macro.gds - Layout"
puts "  outputs/communication_macro.lef - Abstract view"
puts "  outputs/communication_macro.def - DEF file"
puts ""
puts "Reports:"
puts "  reports/area.rpt    - Area analysis"
puts "  reports/timing.rpt  - Timing analysis"
puts "  reports/power.rpt   - Power analysis"
puts "======================================="