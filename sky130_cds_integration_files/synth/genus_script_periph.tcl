#===============================================================================
# Genus Synthesis Script for peripheral_subsystem_macro
# Integrates: communication + protection + adc_subsystem + pwm_accelerator
#===============================================================================

set DESIGN "peripheral_subsystem_macro"

# Paths
set LIB_PATH "../sky130_osu_sc_t18"
set HDL_PATH "hdl/peripheral_subsystem"
set MACRO_DIR "../pnr/outputs"

#===============================================================================
# Library Setup
#===============================================================================

set_db init_lib_search_path "$LIB_PATH/lib $LIB_PATH/lef"
set_db init_hdl_search_path $HDL_PATH

puts "==> Loading libraries..."
read_libs "$LIB_PATH/lib/sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"

puts "==> Reading LEF files..."
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T_tech.lef"
read_physical -lef "$LIB_PATH/lef/sky130_osu_sc_18T.lef"

#===============================================================================
# Read Pre-Built Macro Netlists
#===============================================================================

puts "==> Reading pre-built macro netlists..."

# List of peripheral macros
set peripheral_macros {communication_macro protection_macro adc_subsystem_macro pwm_accelerator_macro}

foreach macro $peripheral_macros {
    set netlist_file "${MACRO_DIR}/${macro}/${macro}_netlist.v"
    if {[file exists $netlist_file]} {
        read_hdl -v2001 $netlist_file
        puts "    ✓ ${macro} netlist loaded"
    } else {
        puts "ERROR: ${macro} netlist not found!"
        puts "Build ${macro} first using standard sky130_cds flow"
        exit 1
    }
}

#===============================================================================
# Read Top-Level Integration RTL
#===============================================================================

puts "==> Reading integration RTL..."
read_hdl -v2001 {
    peripheral_subsystem_macro.v
}

#===============================================================================
# Elaborate
#===============================================================================

puts "==> Elaborating design..."
elaborate $DESIGN

check_design -unresolved

#===============================================================================
# Mark Macros as Black Boxes
#===============================================================================

puts "==> Setting macros as black boxes..."

foreach macro $peripheral_macros {
    if {[llength [get_db designs $macro]] > 0} {
        set_db [get_db designs $macro] .preserve true
        set_dont_touch [get_db designs $macro]
        puts "    ✓ ${macro} marked as black box"
    }
}

#===============================================================================
# Read Constraints
#===============================================================================

puts "==> Applying constraints..."

# Read macro SDC files (optional)
foreach macro $peripheral_macros {
    catch {read_sdc "${MACRO_DIR}/${macro}/${macro}.sdc"}
}

# Read top-level constraints
if {[file exists "constraints/peripheral_subsystem.sdc"]} {
    read_sdc "constraints/peripheral_subsystem.sdc"
} else {
    # Default constraints
    puts "WARNING: No SDC file found, using default constraints"
    create_clock -period 10.0 [get_ports clk]
    set_clock_uncertainty 0.5 [get_clocks clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    remove_input_delay [get_ports clk]
    set_output_delay 2.0 -clock clk [all_outputs]
}

#===============================================================================
# Synthesis
#===============================================================================

puts "==> Running synthesis (glue logic only)..."

set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

syn_generic
syn_map
syn_opt

#===============================================================================
# Reports
#===============================================================================

puts "==> Generating reports..."

exec mkdir -p reports/peripheral_subsystem

report_timing > reports/peripheral_subsystem/timing.rpt
report_area > reports/peripheral_subsystem/area.rpt
report_qor > reports/peripheral_subsystem/qor.rpt
report_power > reports/peripheral_subsystem/power.rpt
report_hierarchy > reports/peripheral_subsystem/hierarchy.rpt

#===============================================================================
# Write Outputs
#===============================================================================

puts "==> Writing outputs..."

exec mkdir -p outputs/peripheral_subsystem

write_hdl > outputs/peripheral_subsystem/${DESIGN}.vh
write_sdc > outputs/peripheral_subsystem/${DESIGN}.sdc
write_sdf > outputs/peripheral_subsystem/${DESIGN}.sdf

puts ""
puts "========================================="
puts "Peripheral Subsystem Integration Complete!"
puts "========================================="
puts ""
puts "Design hierarchy:"
puts "  peripheral_subsystem_macro (top)"
puts "    ├── u_communication (pre-built black box)"
puts "    ├── u_protection (pre-built black box)"
puts "    ├── u_adc_subsystem (pre-built black box)"
puts "    └── u_pwm_accelerator (pre-built black box)"
puts ""
puts "Next step:"
puts "  cd ../pnr"
puts "  make -f Makefile.periph all"
puts ""

exit
