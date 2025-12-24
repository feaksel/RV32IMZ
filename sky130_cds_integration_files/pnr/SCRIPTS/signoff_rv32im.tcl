#===============================================================================
# Signoff Script for rv32im_integrated_macro
# Generates LEF, netlist, and GDS with merged macros
#===============================================================================

# Restore post-route design
restoreDesign DBS/rv32im_integrated/route.enc rv32im_integrated_macro

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
# Generate Reports
#===============================================================================

puts "==> Generating reports..."

exec mkdir -p RPT/rv32im_integrated

report_timing -check_type setup -max_paths 20 > RPT/rv32im_integrated/setup.rpt
report_timing -check_type hold -max_paths 20 > RPT/rv32im_integrated/hold.rpt
report_area > RPT/rv32im_integrated/area.rpt
report_power > RPT/rv32im_integrated/power.rpt
summaryReport -noHtml -outFile RPT/rv32im_integrated/summary.rpt

# Check for timing violations
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

exec mkdir -p outputs/rv32im_integrated

# 1. LEF Abstract (for next-level integration)
# OVERLAP layer is now in modified tech LEF (loaded by setup script)
write_lef_abstract -5.7 outputs/rv32im_integrated/rv32im_integrated_macro.lef
puts "    ✓ LEF: outputs/rv32im_integrated/rv32im_integrated_macro.lef"

# 2. Gate-level Netlist (for next-level synthesis)
saveNetlist outputs/rv32im_integrated/rv32im_integrated_macro_netlist.v -excludeLeafCell
puts "    ✓ Netlist: outputs/rv32im_integrated/rv32im_integrated_macro_netlist.v"

# 3. Timing Constraints (for next-level P&R)
write_sdc outputs/rv32im_integrated/rv32im_integrated_macro.sdc
puts "    ✓ SDC: outputs/rv32im_integrated/rv32im_integrated_macro.sdc"

# 4. DEF File (optional - for debugging)
defOut outputs/rv32im_integrated/rv32im_integrated_macro.def
puts "    ✓ DEF: outputs/rv32im_integrated/rv32im_integrated_macro.def"

#===============================================================================
# Generate GDSII with MERGED Macro Layouts
#===============================================================================

puts "==> Generating GDSII with merged macro layouts..."

set MACRO_PATH "outputs"

# Find macro GDS files
set core_gds "${MACRO_PATH}/core_macro/core_macro.gds"
set mdu_gds "${MACRO_PATH}/mdu_macro/mdu_macro.gds"

# Build merge list
set merge_list {}
if {[file exists $core_gds]} {
    lappend merge_list $core_gds
    puts "    ✓ Will merge core_macro.gds"
} else {
    puts "    WARNING: core_macro.gds not found at $core_gds"
}

if {[file exists $mdu_gds]} {
    lappend merge_list $mdu_gds
    puts "    ✓ Will merge mdu_macro.gds"
} else {
    puts "    WARNING: mdu_macro.gds not found at $mdu_gds"
}

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

# Stream out with merged GDS
if {[llength $merge_list] > 0} {
    if {$gds_map != ""} {
        streamOut outputs/rv32im_integrated/rv32im_integrated_macro.gds \
            -mapFile $gds_map \
            -merge $merge_list \
            -stripes 1 \
            -units 1000 \
            -mode ALL
    } else {
        streamOut outputs/rv32im_integrated/rv32im_integrated_macro.gds \
            -merge $merge_list \
            -stripes 1 \
            -units 1000 \
            -mode ALL
    }
    puts "    ✓ GDSII: outputs/rv32im_integrated/rv32im_integrated_macro.gds (with merged macros)"
} else {
    puts "    ERROR: No macro GDS files found to merge!"
}

#===============================================================================
# (Optional) Generate Liberty Timing Model
#===============================================================================

# Uncomment to generate .lib file for more accurate next-level integration
# puts "==> Generating Liberty timing model..."
# write_timing_model \
#     -format lib \
#     -library_name rv32im_integrated_lib \
#     -typ_opcond \
#     -views {setup_func hold_func} \
#     outputs/rv32im_integrated/rv32im_integrated_macro.lib
# puts "    ✓ LIB: outputs/rv32im_integrated/rv32im_integrated_macro.lib"

#===============================================================================
# Save Final Database
#===============================================================================

saveDesign DBS/rv32im_integrated/signoff.enc

puts ""
puts "========================================="
puts "RV32IM Integration Signoff Complete!"
puts "========================================="
puts ""
puts "Integration files generated:"
puts "  outputs/rv32im_integrated/rv32im_integrated_macro.lef"
puts "  outputs/rv32im_integrated/rv32im_integrated_macro_netlist.v"
puts "  outputs/rv32im_integrated/rv32im_integrated_macro.sdc"
puts "  outputs/rv32im_integrated/rv32im_integrated_macro.gds"
puts ""
puts "GDS includes merged layouts:"
if {[file exists $core_gds]} {
    puts "  ✓ core_macro.gds"
}
if {[file exists $mdu_gds]} {
    puts "  ✓ mdu_macro.gds"
}
puts ""
puts "Ready for next-level SOC integration!"
puts ""
