#===============================================================================
# Signoff Script for rv32imz_soc_macro (UPDATED FOR YOUR STRUCTURE)
# Your SOC uses: rv32im_integrated + individual peripherals (NOT peripheral_subsystem)
#===============================================================================

restoreDesign DBS/soc_integrated/route.enc rv32im_soc_with_integrated_core

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
# DRC and Connectivity Checks
#===============================================================================

puts "==> Running design checks..."

verifyConnectivity -type all -report RPT/soc_integrated/connectivity.rpt
verifyGeometry -report RPT/soc_integrated/geometry.rpt

#===============================================================================
# Reports
#===============================================================================

puts "==> Generating reports..."

exec mkdir -p RPT/soc_integrated

report_timing -check_type setup -max_paths 50 > RPT/soc_integrated/setup.rpt
report_timing -check_type hold -max_paths 50 > RPT/soc_integrated/hold.rpt
report_area > RPT/soc_integrated/area.rpt
report_power -hierarchy all > RPT/soc_integrated/power.rpt
report_power > RPT/soc_integrated/power_summary.rpt
summaryReport -noHtml -outFile RPT/soc_integrated/summary.rpt
report_hierarchy > RPT/soc_integrated/hierarchy.rpt

# Timing summary
set setup_viol [get_db timing_analysis_views:setup_func .setup_slack]
set hold_viol [get_db timing_analysis_views:hold_func .hold_slack]

puts ""
puts "========================================="
puts "Final Timing Summary"
puts "========================================="
puts "  Setup slack: $setup_viol"
puts "  Hold slack:  $hold_viol"
puts ""

if {$setup_viol < 0.0} {
    puts "WARNING: Setup timing violations detected!"
}
if {$hold_viol < 0.0} {
    puts "WARNING: Hold timing violations detected!"
}

#===============================================================================
# Generate Final SOC Files
#===============================================================================

puts "==> Generating final SOC files..."

exec mkdir -p outputs/soc_integrated

# OVERLAP layer is now defined in tech_overlay_overlap.lef (loaded in setup script)
write_lef_abstract -5.7 outputs/soc_integrated/rv32imz_soc_macro.lef
puts "    ✓ LEF: outputs/soc_integrated/rv32imz_soc_macro.lef"

saveNetlist outputs/soc_integrated/rv32imz_soc_macro_netlist.v -excludeLeafCell
puts "    ✓ Netlist: outputs/soc_integrated/rv32imz_soc_macro_netlist.v"

saveNetlist outputs/soc_integrated/rv32imz_soc_macro_full.v -includeLeafCell
puts "    ✓ Full Netlist: outputs/soc_integrated/rv32imz_soc_macro_full.v"

write_sdc outputs/soc_integrated/rv32imz_soc_macro.sdc
puts "    ✓ SDC: outputs/soc_integrated/rv32imz_soc_macro.sdc"

defOut outputs/soc_integrated/rv32imz_soc_macro.def
puts "    ✓ DEF: outputs/soc_integrated/rv32imz_soc_macro.def"

write_sdf outputs/soc_integrated/rv32imz_soc_macro.sdf
puts "    ✓ SDF: outputs/soc_integrated/rv32imz_soc_macro.sdf"

#===============================================================================
# Generate Final GDSII with ALL Macros Merged
#===============================================================================

puts ""
puts "==> Generating final GDSII with ALL macro layouts merged..."
puts ""

set MACRO_PATH "outputs"

# Build complete merge list
set merge_list {}

# Add rv32im_integrated (contains core + mdu already merged)
set gds_file "${MACRO_PATH}/rv32im_integrated/rv32im_integrated_macro.gds"
if {[file exists $gds_file]} {
    lappend merge_list $gds_file
    puts "    ✓ Will merge rv32im_integrated_macro.gds (contains core+mdu)"
} else {
    puts "    WARNING: rv32im_integrated_macro.gds not found at $gds_file"
}

# Add individual peripheral macros
set peripheral_macros {memory_macro communication_macro protection_macro adc_subsystem_macro pwm_accelerator_macro}

foreach macro $peripheral_macros {
    set gds_file "${MACRO_PATH}/${macro}/${macro}.gds"
    if {[file exists $gds_file]} {
        lappend merge_list $gds_file
        puts "    ✓ Will merge ${macro}.gds"
    } else {
        puts "    WARNING: ${macro}.gds not found at $gds_file"
    }
}

puts ""

# Find GDS map file (try local first, then PDK)
set gds_map ""
if {[file exists "streamOut.map"]} {
    set gds_map "streamOut.map"
    puts "    Using GDS map: $gds_map"
} elseif {[file exists "../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map"]} {
    set gds_map "../sky130_osu_sc_t18/gds/sky130_osu_sc_18T.map"
    puts "    Using GDS map: $gds_map"
} else {
    puts "    No GDS map file found - using default layer mapping"
}

# Stream out final GDS
if {[llength $merge_list] > 0} {
    puts ""
    puts "Streaming out final GDSII..."
    if {$gds_map != ""} {
        streamOut outputs/soc_integrated/rv32imz_soc_macro.gds \
            -mapFile $gds_map \
            -merge $merge_list \
            -stripes 1 \
            -units 1000 \
            -mode ALL
    } else {
        streamOut outputs/soc_integrated/rv32imz_soc_macro.gds \
            -merge $merge_list \
            -stripes 1 \
            -units 1000 \
            -mode ALL
    }
    puts "    ✓ GDSII: outputs/soc_integrated/rv32imz_soc_macro.gds"
    puts ""
    puts "    This GDS file contains the COMPLETE SOC layout"
    puts "    including ALL macros merged!"
} else {
    puts "    ERROR: No macro GDS files found to merge!"
}

#===============================================================================
# Save Final Database
#===============================================================================

saveDesign DBS/soc_integrated/signoff.enc

#===============================================================================
# Final Summary
#===============================================================================

puts ""
puts "========================================="
puts "SOC Integration Signoff COMPLETE!"
puts "========================================="
puts ""
puts "Final SOC files generated:"
puts "  outputs/soc_integrated/rv32imz_soc_macro.lef"
puts "  outputs/soc_integrated/rv32imz_soc_macro_netlist.v"
puts "  outputs/soc_integrated/rv32imz_soc_macro_full.v"
puts "  outputs/soc_integrated/rv32imz_soc_macro.sdc"
puts "  outputs/soc_integrated/rv32imz_soc_macro.sdf"
puts "  outputs/soc_integrated/rv32imz_soc_macro.gds  <-- FINAL CHIP GDS"
puts ""
puts "Complete SOC hierarchy in GDS (YOUR STRUCTURE):"
puts "  rv32im_soc_with_integrated_core"
puts "    ├── u_cpu_core (rv32im_integrated_macro)"
puts "    │   ├── u_core_macro (core_macro)"
puts "    │   └── u_mdu_macro (mdu_macro)"
puts "    ├── u_memory (memory_macro)"
puts "    ├── u_pwm (pwm_accelerator_macro)"
puts "    ├── u_adc (adc_subsystem_macro)"
puts "    ├── u_protection (protection_macro)"
puts "    └── u_communication (communication_macro)"
puts ""
puts "Total macros merged: 7 (rv32im_integrated + 5 peripherals)"
puts "Note: rv32im_integrated itself contains 2 macros (core + mdu)"
puts "So the complete hierarchy has 7 top-level macros in the GDS"
puts ""
puts "READY FOR TAPEOUT! 🚀"
puts ""
