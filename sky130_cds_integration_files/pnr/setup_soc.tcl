#===============================================================================
# Innovus Setup for rv32imz_soc_macro
# Top-level SOC integration
# Reads: rv32im_integrated + peripheral_subsystem + memory LEF files
#===============================================================================

set DESIGN "rv32imz_soc_macro"
set LIB_PATH "../sky130_osu_sc_t18"
set MACRO_DIR "outputs"

#===============================================================================
# MMMC Setup
#===============================================================================

create_library_set -name libs_tt \
    -timing [list "${LIB_PATH}/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"]

create_rc_corner -name rc_typ \
    -temperature 25 \
    -pre_route_res 1.0 \
    -pre_route_cap 1.0 \
    -post_route_res 1.0 \
    -post_route_cap 1.0

create_delay_corner -name corner_tt \
    -library_set libs_tt \
    -rc_corner rc_typ

create_constraint_mode -name setup_func_mode \
    -sdc_files [list "../synth/outputs/soc_integrated/${DESIGN}.sdc"]

create_analysis_view -name setup_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

create_analysis_view -name hold_func \
    -constraint_mode setup_func_mode \
    -delay_corner corner_tt

set_analysis_view -setup {setup_func} -hold {hold_func}

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
# Read All Pre-Built Macro LEF Files
#===============================================================================

puts "==> Loading pre-built macro LEF files..."

# Level 1 integrated macros
set l1_macros {rv32im_integrated peripheral_subsystem}

foreach macro $l1_macros {
    set lef_file "${MACRO_DIR}/${macro}/${macro}_macro.lef"
    if {[file exists $lef_file]} {
        read_physical -lef $lef_file
        puts "    ✓ ${macro}_macro LEF loaded"
    } else {
        puts "ERROR: ${macro}_macro.lef not found!"
        puts "Build ${macro}_macro first using integration flow"
        exit 1
    }
}

# Memory macro (leaf)
set lef_file "${MACRO_DIR}/memory_macro/memory_macro.lef"
if {[file exists $lef_file]} {
    read_physical -lef $lef_file
    puts "    ✓ memory_macro LEF loaded"
} else {
    puts "ERROR: memory_macro.lef not found!"
    puts "Build memory_macro first using standard sky130_cds flow"
    exit 1
}

#===============================================================================
# Read Netlist and Initialize
#===============================================================================

puts "==> Reading top-level SOC netlist..."

read_netlist "../synth/outputs/soc_integrated/${DESIGN}.vh"

init_design -setup {setup_func} -hold {hold_func}

puts ""
puts "========================================="
puts "Setup Complete for SOC Integration"
puts "========================================="
puts ""
puts "Design contains:"
puts "  - rv32im_integrated_macro (from LEF)"
puts "  - peripheral_subsystem_macro (from LEF)"
puts "  - memory_macro (from LEF)"
puts "  - Top-level glue logic (to be placed)"
puts ""
