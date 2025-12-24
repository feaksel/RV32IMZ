#===============================================================================
# Innovus Setup for peripheral_subsystem_macro
# Reads pre-built peripheral macro LEF files
#===============================================================================

set DESIGN "peripheral_subsystem_macro"
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
    -sdc_files [list "../synth/outputs/peripheral_subsystem/${DESIGN}.sdc"]

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
# Read Pre-Built Peripheral Macro LEF Files
#===============================================================================

puts "==> Loading pre-built peripheral macro LEF files..."

set peripheral_macros {communication_macro protection_macro adc_subsystem_macro pwm_accelerator_macro}

foreach macro $peripheral_macros {
    set lef_file "${MACRO_DIR}/${macro}/${macro}.lef"
    if {[file exists $lef_file]} {
        read_physical -lef $lef_file
        puts "    ✓ ${macro} LEF loaded"
    } else {
        puts "ERROR: ${macro}.lef not found!"
        puts "Generate it in Innovus after building ${macro}"
        exit 1
    }
}

#===============================================================================
# Read Netlist and Initialize
#===============================================================================

puts "==> Reading integrated netlist..."

read_netlist "../synth/outputs/peripheral_subsystem/${DESIGN}.vh"

init_design -setup {setup_func} -hold {hold_func}

puts ""
puts "========================================="
puts "Setup Complete for Peripheral Subsystem"
puts "========================================="
puts ""
puts "Design contains:"
puts "  - communication_macro (from LEF)"
puts "  - protection_macro (from LEF)"
puts "  - adc_subsystem_macro (from LEF)"
puts "  - pwm_accelerator_macro (from LEF)"
puts "  - Glue logic (to be placed)"
puts ""
