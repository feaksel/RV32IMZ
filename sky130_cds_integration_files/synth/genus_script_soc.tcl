#===============================================================================
# Genus Synthesis Script for rv32imz_soc_macro
# Top-level SOC integration
# Integrates: rv32im_integrated + peripheral_subsystem + memory
#===============================================================================

set DESIGN "rv32imz_soc_macro"

# Paths
set LIB_PATH "../sky130_osu_sc_t18"
set HDL_PATH "hdl/soc_integrated"
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

# Level 1 integrated macros
set l1_macros {rv32im_integrated peripheral_subsystem}

foreach macro $l1_macros {
    set netlist_file "${MACRO_DIR}/${macro}/${macro}_macro_netlist.v"
    if {[file exists $netlist_file]} {
        read_hdl -v2001 $netlist_file
        puts "    ✓ ${macro}_macro netlist loaded"
    } else {
        puts "ERROR: ${macro}_macro netlist not found!"
        puts "Build ${macro}_macro first using integration flow"
        exit 1
    }
}

# Memory macro (leaf)
set netlist_file "${MACRO_DIR}/memory_macro/memory_macro_netlist.v"
if {[file exists $netlist_file]} {
    read_hdl -v2001 $netlist_file
    puts "    ✓ memory_macro netlist loaded"
} else {
    puts "ERROR: memory_macro netlist not found!"
    puts "Build memory_macro first using standard sky130_cds flow"
    exit 1
}

#===============================================================================
# Read Top-Level SOC RTL
#===============================================================================

puts "==> Reading top-level SOC RTL..."
read_hdl -v2001 {
    rv32imz_soc_macro.v
}

#===============================================================================
# Elaborate
#===============================================================================

puts "==> Elaborating design..."
elaborate $DESIGN

check_design -unresolved

#===============================================================================
# Mark ALL Macros as Black Boxes
#===============================================================================

puts "==> Setting macros as black boxes..."

set all_macros {rv32im_integrated_macro peripheral_subsystem_macro memory_macro}

foreach macro $all_macros {
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

# Read constraints from sub-macros (optional)
catch {read_sdc "${MACRO_DIR}/rv32im_integrated/rv32im_integrated_macro.sdc"}
catch {read_sdc "${MACRO_DIR}/peripheral_subsystem/peripheral_subsystem_macro.sdc"}
catch {read_sdc "${MACRO_DIR}/memory_macro/memory_macro.sdc"}

# Read top-level constraints
if {[file exists "constraints/soc_integrated.sdc"]} {
    read_sdc "constraints/soc_integrated.sdc"
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
# Synthesis (Only Top-Level Glue Logic)
#===============================================================================

puts "==> Running synthesis (top-level glue logic only)..."
puts "    Note: All macros are black boxes"

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

exec mkdir -p reports/soc_integrated

report_timing > reports/soc_integrated/timing.rpt
report_area > reports/soc_integrated/area.rpt
report_qor > reports/soc_integrated/qor.rpt
report_power > reports/soc_integrated/power.rpt
report_hierarchy > reports/soc_integrated/hierarchy.rpt

#===============================================================================
# Write Outputs
#===============================================================================

puts "==> Writing outputs..."

exec mkdir -p outputs/soc_integrated

write_hdl > outputs/soc_integrated/${DESIGN}.vh
write_sdc > outputs/soc_integrated/${DESIGN}.sdc
write_sdf > outputs/soc_integrated/${DESIGN}.sdf

puts ""
puts "========================================="
puts "SOC Integration Synthesis Complete!"
puts "========================================="
puts ""
puts "Complete design hierarchy:"
puts "  rv32imz_soc_macro (top)"
puts "    ├── u_rv32im_core (rv32im_integrated_macro)"
puts "    │   ├── u_core_macro (pre-built)"
puts "    │   └── u_mdu_macro (pre-built)"
puts "    ├── u_memory (memory_macro)"
puts "    └── u_peripherals (peripheral_subsystem_macro)"
puts "        ├── u_communication (pre-built)"
puts "        ├── u_protection (pre-built)"
puts "        ├── u_adc_subsystem (pre-built)"
puts "        └── u_pwm_accelerator (pre-built)"
puts ""
puts "Next step:"
puts "  cd ../pnr"
puts "  make -f Makefile.soc all"
puts ""

exit
