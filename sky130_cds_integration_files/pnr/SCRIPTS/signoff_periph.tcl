#===============================================================================
# Signoff Script for peripheral_subsystem_macro
# Generates LEF, netlist, and GDS with merged peripheral macros
#===============================================================================

restoreDesign DBS/peripheral_subsystem/route.enc peripheral_subsystem_macro

#===============================================================================
# Extract Parasitics
#===============================================================================

puts "==> Extracting parasitics..."

setExtractMode -engine postRoute
extractRC

#===============================================================================
# Final Timing Analysis
#===============================================================================

puts "==> Running final timing analysis..."

timeDesign -postRoute -si

#===============================================================================
# Reports
#===============================================================================

puts "==> Generating reports..."

exec mkdir -p RPT/peripheral_subsystem

report_timing -check_type setup -max_paths 20 > RPT/peripheral_subsystem/setup.rpt
report_timing -check_type hold -max_paths 20 > RPT/peripheral_subsystem/hold.rpt
report_area > RPT/peripheral_subsystem/area.rpt
report_power > RPT/peripheral_subsystem/power.rpt
summaryReport -noHtml -outFile RPT/peripheral_subsystem/summary.rpt

# Timing summary
set setup_viol [get_db timing_analysis_views:setup_func .setup_slack]
set hold_viol [get_db timing_analysis_views:hold_func .hold_slack]

puts ""
puts "Timing Summary:"
puts "  Setup slack: $setup_viol"
puts "  Hold slack:  $hold_viol"
puts ""

#===============================================================================
# Generate Integration Files
#===============================================================================

puts "==> Generating integration files..."

exec mkdir -p outputs/peripheral_subsystem

# Use LEF 5.6 to avoid OVERLAP layer requirement (LEF 5.7 needs OVERLAP in tech LEF)
if {[catch {
    write_lef_abstract -5.6 outputs/peripheral_subsystem/peripheral_subsystem_macro.lef
    puts "    ✓ LEF: outputs/peripheral_subsystem/peripheral_subsystem_macro.lef (LEF 5.6 format)"
} err]} {
    # Fallback: LEF 5.7 without obstructions if 5.6 fails
    write_lef_abstract -5.7 -noOBS outputs/peripheral_subsystem/peripheral_subsystem_macro.lef
    puts "    ✓ LEF: outputs/peripheral_subsystem/peripheral_subsystem_macro.lef (LEF 5.7, no OBS)"
    puts "    WARNING: Using -noOBS due to: $err"
}

saveNetlist outputs/peripheral_subsystem/peripheral_subsystem_macro_netlist.v -excludeLeafCell
puts "    ✓ Netlist: outputs/peripheral_subsystem/peripheral_subsystem_macro_netlist.v"

write_sdc outputs/peripheral_subsystem/peripheral_subsystem_macro.sdc
puts "    ✓ SDC: outputs/peripheral_subsystem/peripheral_subsystem_macro.sdc"

defOut outputs/peripheral_subsystem/peripheral_subsystem_macro.def
puts "    ✓ DEF: outputs/peripheral_subsystem/peripheral_subsystem_macro.def"

#===============================================================================
# Generate GDSII with Merged Peripheral Macros
#===============================================================================

puts "==> Generating GDSII with merged peripheral macro layouts..."

set MACRO_PATH "outputs"

# List of peripheral macros to merge
set peripheral_macros {communication_macro protection_macro adc_subsystem_macro pwm_accelerator_macro}

# Build merge list
set merge_list {}
foreach macro $peripheral_macros {
    set gds_file "${MACRO_PATH}/${macro}/${macro}.gds"
    if {[file exists $gds_file]} {
        lappend merge_list $gds_file
        puts "    ✓ Will merge ${macro}.gds"
    } else {
        puts "    WARNING: ${macro}.gds not found at $gds_file"
    }
}

# Find GDS map file
set gds_map ""
if {[file exists "../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map"]} {
    set gds_map "../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map"
} elseif {[file exists "streamOut.map"]} {
    set gds_map "streamOut.map"
}

# Stream out
if {[llength $merge_list] > 0} {
    if {$gds_map != ""} {
        streamOut outputs/peripheral_subsystem/peripheral_subsystem_macro.gds \
            -mapFile $gds_map \
            -merge $merge_list \
            -stripes 1 \
            -units 1000 \
            -mode ALL
    } else {
        streamOut outputs/peripheral_subsystem/peripheral_subsystem_macro.gds \
            -merge $merge_list \
            -stripes 1 \
            -units 1000 \
            -mode ALL
    }
    puts "    ✓ GDSII: outputs/peripheral_subsystem/peripheral_subsystem_macro.gds"
} else {
    puts "    ERROR: No peripheral macro GDS files found!"
}

#===============================================================================
# Save Database
#===============================================================================

saveDesign DBS/peripheral_subsystem/signoff.enc

puts ""
puts "========================================="
puts "Peripheral Subsystem Signoff Complete!"
puts "========================================="
puts ""
puts "Integration files generated:"
puts "  outputs/peripheral_subsystem/peripheral_subsystem_macro.lef"
puts "  outputs/peripheral_subsystem/peripheral_subsystem_macro_netlist.v"
puts "  outputs/peripheral_subsystem/peripheral_subsystem_macro.sdc"
puts "  outputs/peripheral_subsystem/peripheral_subsystem_macro.gds"
puts ""
puts "GDS includes merged layouts:"
foreach macro $peripheral_macros {
    set gds_file "${MACRO_PATH}/${macro}/${macro}.gds"
    if {[file exists $gds_file]} {
        puts "  ✓ ${macro}.gds"
    }
}
puts ""
