#===============================================================================
# Expert Final Signoff Script for rv32im_integrated_macro
#===============================================================================

# 1. Fix Manufacturing Grid (Set variable BEFORE restoring design)
set init_design_manufacturing_grid 0.005

# 2. Restore Design
restoreDesign DBS/rv32im_integrated/route.enc.dat/ rv32im_integrated_macro

#===============================================================================
# Extract Parasitics & Timing
#===============================================================================
puts "==> Extracting parasitics..."
extractRC

puts "==> Running final timing analysis..."
timeDesign -postRoute -si

#===============================================================================
# Generate Reports & Directories
#===============================================================================
puts "==> Generating reports..."
exec mkdir -p RPT/rv32im_integrated
exec mkdir -p outputs/rv32im_integrated

report_timing -check_type setup -max_paths 20 > RPT/rv32im_integrated/setup.rpt
report_area > RPT/rv32im_integrated/area.rpt
report_power > RPT/rv32im_integrated/power.rpt

#===============================================================================
# Generate Integration Files
#===============================================================================
puts "==> Generating integration files..."

# LEF Abstract (Critical for SOC-level placement)
write_lef_abstract -5.7 outputs/rv32im_integrated/rv32im_integrated_macro.lef

# Netlist (Exclude internal leaf cells for cleaner SOC hierarchy)
saveNetlist outputs/rv32im_integrated/rv32im_integrated_macro_netlist.v -excludeLeafCell

# SDC Constraints
write_sdc outputs/rv32im_integrated/rv32im_integrated_macro.sdc

#===============================================================================
# Generate GDSII with Local streamOut.map
#===============================================================================
puts "==> Generating GDSII..."

set MACRO_PATH "outputs"
set merge_list [list \
    "${MACRO_PATH}/core_macro/core_macro.gds" \
    "${MACRO_PATH}/mdu_macro/mdu_macro.gds" \
]

# Using local streamOut.map and explicit units to solve Grid errors
streamOut outputs/rv32im_integrated/rv32im_integrated_macro.gds \
    -mapFile "streamOut.map" \
    -merge $merge_list \
    -units 1000 \
    -mode ALL

#===============================================================================
# Save Final Database and Exit
#===============================================================================
saveDesign DBS/rv32im_integrated/signoff.enc
puts "RV32IM Signoff Complete! GDS and LEF are ready for SOC Integration."
exit
