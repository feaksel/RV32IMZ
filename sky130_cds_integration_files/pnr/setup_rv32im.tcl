#===============================================================================
# Innovus Setup for rv32im_integrated_macro
# Reads pre-built core_macro + mdu_macro LEF files
#===============================================================================

set DESIGN "rv32im_integrated_macro"
set LIB_PATH "../sky130_osu_sc_t18"
set MACRO_DIR "outputs"  # Where macro LEF/GDS files are located

#===============================================================================
# MMMC Setup - Library Sets
#===============================================================================

# Create library set for standard cells only
# Macro timing comes from LEF or optional .lib files
create_library_set -name libs_tt \
    -timing [list "${LIB_PATH}/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"]

# If you have macro .lib files for better timing, add them:
# set macro_libs {}
# if {[file exists "${MACRO_DIR}/core_macro/core_macro.lib"]} {
#     lappend macro_libs "${MACRO_DIR}/core_macro/core_macro.lib"
# }
# if {[file exists "${MACRO_DIR}/mdu_macro/mdu_macro.lib"]} {
#     lappend macro_libs "${MACRO_DIR}/mdu_macro/mdu_macro.lib"
# }
# create_library_set -name libs_tt \
#     -timing [concat [list "${LIB_PATH}/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"] $macro_libs]

#===============================================================================
# RC Corner
#===============================================================================

create_rc_corner -name rc_typ \
    -temperature 25 \
    -pre_route_res 1.0 \
    -pre_route_cap 1.0 \
    -post_route_res 1.0 \
    -post_route_cap 1.0

# If you have QRC tech file for more accurate extraction:
# create_rc_corner -name rc_typ \
#     -temperature 25 \
#     -qrc_tech $env(PDK_ROOT)/sky130A/libs.tech/qrc/qrcTechFile

#===============================================================================
# Delay Corner
#===============================================================================

create_delay_corner -name corner_tt \
    -library_set libs_tt \
    -rc_corner rc_typ

#===============================================================================
# Constraint Mode
#===============================================================================

create_constraint_mode -name setup_func_mode \
    -sdc_files [list "../synth/outputs/rv32im_integrated/${DESIGN}.sdc"]

#===============================================================================
# Analysis Views
#===============================================================================

create_analysis_view -name setup_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

create_analysis_view -name hold_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

set_analysis_view -setup {setup_func} -hold {hold_func}

#===============================================================================
# Power/Ground Nets
#===============================================================================

set_power_net VDD
set_ground_net VSS

#===============================================================================
# Read Technology LEF
#===============================================================================

puts "==> Loading technology LEF files..."

# Use modified tech LEF with OVERLAP layer (if available), otherwise use original
set tech_lef_with_overlap "sky130_osu_sc_18T_tech_with_overlap.lef"
if {[file exists $tech_lef_with_overlap]} {
    read_physical -lef [list \
        $tech_lef_with_overlap \
        "${LIB_PATH}/lef/sky130_osu_sc_18T.lef" \
    ]
    puts "    ✓ Using tech LEF with OVERLAP layer"
} else {
    puts "WARNING: Modified tech LEF not found!"
    puts "Run: ./add_overlap_to_tech_lef.sh to create it"
    puts "Using original tech LEF (write_lef_abstract may fail)"
    read_physical -lef [list \
        "${LIB_PATH}/lef/sky130_osu_sc_18T_tech.lef" \
        "${LIB_PATH}/lef/sky130_osu_sc_18T.lef" \
    ]
}

#===============================================================================
# Read Pre-Built Macro LEF Files
#===============================================================================

puts "==> Loading pre-built macro LEF files..."

# Read core_macro LEF
if {[file exists "${MACRO_DIR}/core_macro/core_macro.lef"]} {
    read_physical -lef "${MACRO_DIR}/core_macro/core_macro.lef"
    puts "    ✓ core_macro LEF loaded"
} else {
    puts "ERROR: core_macro.lef not found!"
    puts "Generate it in Innovus after building core_macro:"
    puts "  write_lef_abstract -5.7 outputs/core_macro/core_macro.lef"
    exit 1
}

# Read mdu_macro LEF
if {[file exists "${MACRO_DIR}/mdu_macro/mdu_macro.lef"]} {
    read_physical -lef "${MACRO_DIR}/mdu_macro/mdu_macro.lef"
    puts "    ✓ mdu_macro LEF loaded"
} else {
    puts "ERROR: mdu_macro.lef not found!"
    puts "Generate it in Innovus after building mdu_macro:"
    puts "  write_lef_abstract -5.7 outputs/mdu_macro/mdu_macro.lef"
    exit 1
}

#===============================================================================
# Read Netlist and Initialize
#===============================================================================

puts "==> Reading integrated netlist..."

read_netlist "../synth/outputs/rv32im_integrated/${DESIGN}.vh"

init_design -setup {setup_func} -hold {hold_func}

puts ""
puts "========================================="
puts "Setup Complete for RV32IM Integration"
puts "========================================="
puts ""
puts "Design contains:"
puts "  - core_macro (from LEF abstract)"
puts "  - mdu_macro (from LEF abstract)"
puts "  - Glue logic (to be placed)"
puts ""
