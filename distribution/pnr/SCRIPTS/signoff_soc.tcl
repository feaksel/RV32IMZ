#===============================================================================
# SOC SIGNOFF SCRIPT (FINAL TAPE-OUT)
#===============================================================================
set DESIGN "rv32im_soc_with_integrated_core"
set MACRO_PATH "outputs"

# 1. RESTORE FINAL ROUTED DATABASE
restoreDesign DBS/soc_integrated/route.enc.dat $DESIGN

# 2. EXTRACT PARASITICS (RC)
puts "==> Extracting Parasitics..."
setExtractRCMode -engine postRoute
extractRC

# 3. FINAL TIMING ANALYSIS
puts "==> Running Final Timing Signoff..."
# Set Setup Mode
setAnalysisMode -checkType setup
timeDesign -postRoute -si
report_timing -check_type setup -max_paths 50 > RPT/soc_integrated/setup.rpt

# Set Hold Mode
setAnalysisMode -checkType hold
timeDesign -postRoute -hold -si
report_timing -check_type hold -max_paths 50 > RPT/soc_integrated/hold.rpt

# General Reports
report_area > RPT/soc_integrated/area.rpt
report_power > RPT/soc_integrated/power.rpt

# 4. PHYSICAL VERIFICATION
puts "==> Running DRC and Connectivity Checks..."
verifyConnectivity -type all -report RPT/soc_integrated/connectivity.rpt
verifyGeometry -report RPT/soc_integrated/geometry.rpt

# 5. EXPORT STANDARD FILES
exec mkdir -p outputs/soc_integrated
puts "==> Exporting Design Files..."

# LEF (Abstract for integration)
write_lef_abstract outputs/soc_integrated/${DESIGN}.lef

# Netlists
saveNetlist outputs/soc_integrated/${DESIGN}_netlist.v -excludeLeafCell
saveNetlist outputs/soc_integrated/${DESIGN}_full.v -includeLeafCell

# Constraints & Delays
write_sdc outputs/soc_integrated/${DESIGN}.sdc
write_sdf outputs/soc_integrated/${DESIGN}.sdf

# FIX: Use 'defOut' instead of 'write_def'
defOut -floorplan -netlist -routing outputs/soc_integrated/${DESIGN}.def

#===============================================================================
# 6. GDSII MERGE & STREAM OUT
#===============================================================================
puts "==> MERGING MACROS AND GENERATING GDSII..."

# Define the absolute map path
set GDS_MAP_FILE "/home/Student3/Documents/Masaustu/FurkanEmir/sky130_cds/pnr/streamOut.map"

set merge_list {}

# A. Add the CPU Core
set cpu_gds "${MACRO_PATH}/rv32im_integrated/rv32im_integrated_macro.gds"
if {[file exists $cpu_gds]} {
    lappend merge_list $cpu_gds
    puts "  Merging CPU: $cpu_gds"
} else {
    puts "  WARNING: CPU GDS not found at $cpu_gds"
}

# B. Add Peripherals
set periphs {memory_macro communication_macro protection_macro adc_subsystem_macro pwm_accelerator_macro}
foreach macro $periphs {
    set gds "${MACRO_PATH}/${macro}/${macro}.gds"
    if {[file exists $gds]} {
        lappend merge_list $gds
        puts "  Merging Peripheral: $macro"
    } else {
        puts "  WARNING: GDS missing for $macro"
    }
}

# C. Stream Out Final Chip
if {[llength $merge_list] > 0} {
    streamOut outputs/soc_integrated/${DESIGN}.gds \
        -mapFile $GDS_MAP_FILE \
        -libName DesignLib \
        -structureName $DESIGN \
        -merge $merge_list \
        -units 1000 \
        -mode ALL
    puts "SUCCESS: Final Merged GDS created at outputs/soc_integrated/${DESIGN}.gds"
} else {
    puts "ERROR: No macro GDS files found! GDS will contain black boxes."
    streamOut outputs/soc_integrated/${DESIGN}.gds \
        -mapFile $GDS_MAP_FILE \
        -libName DesignLib \
        -structureName $DESIGN \
        -units 1000 \
        -mode ALL
}

# 7. SAVE SIGNOFF DB
saveDesign DBS/soc_integrated/signoff.enc
puts "Signoff Complete."
exit
