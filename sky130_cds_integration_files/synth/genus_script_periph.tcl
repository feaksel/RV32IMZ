#===============================================================================
# Genus Synthesis Script for peripheral_subsystem_macro
# Integrates: communication + protection + adc_subsystem + pwm_accelerator
#===============================================================================

set DESIGN "peripheral_subsystem_macro"

# Paths
set LIB_PATH "../sky130_osu_sc_t18"
set LIB_VARIANT "18T_ms"  # Options: 18T_hs, 18T_ls, 18T_ms
set HDL_PATH "hdl/peripheral_subsystem"
set MACRO_DIR "../pnr/outputs"

#===============================================================================
# Library Setup
#===============================================================================

set_db init_lib_search_path "$LIB_PATH/${LIB_VARIANT}/lib $LIB_PATH/${LIB_VARIANT}/lef $LIB_PATH"
set_db init_hdl_search_path $HDL_PATH

puts "==> Loading libraries..."
puts "    Using library variant: $LIB_VARIANT"

# Try to find timing library
set lib_loaded 0
foreach lib_variant {
    "sky130_osu_sc_${LIB_VARIANT}_TT_1P8_25C.ccs.lib"
    "sky130_osu_sc_${LIB_VARIANT}_TT_1P8_25C.lib"
} {
    if {[file exists "$LIB_PATH/${LIB_VARIANT}/lib/$lib_variant"]} {
        read_libs "$LIB_PATH/${LIB_VARIANT}/lib/$lib_variant"
        puts "    ✓ Loaded library: $lib_variant"
        set lib_loaded 1
        break
    }
}

if {!$lib_loaded} {
    puts "ERROR: No timing library found in $LIB_PATH/${LIB_VARIANT}/lib/"
    exit 1
}

# OPTIONAL: Load LEF files (only needed for physical synthesis)
set LOAD_LEFS 0  ;# Set to 1 if you need physical info, 0 for logical-only synthesis

if {$LOAD_LEFS} {
    puts "==> Reading LEF files..."

    # Tech LEF at root
    if {[file exists "$LIB_PATH/sky130_osu_sc_18T.tlef"]} {
        catch {read_physical -lef "$LIB_PATH/sky130_osu_sc_18T.tlef"}
        puts "    ⚠ Tech LEF loaded with warnings (this is OK)"
    } else {
        puts "WARNING: Tech LEF not found, continuing without physical data"
    }

    # Cell LEF in variant subdirectory
    if {[file exists "$LIB_PATH/${LIB_VARIANT}/lef/sky130_osu_sc_${LIB_VARIANT}.lef"]} {
        catch {read_physical -lef "$LIB_PATH/${LIB_VARIANT}/lef/sky130_osu_sc_${LIB_VARIANT}.lef"}
        puts "    ⚠ Cell LEF loaded with warnings (this is OK)"
    } else {
        puts "WARNING: Cell LEF not found, continuing without physical data"
    }
} else {
    puts "==> Skipping LEF files (logical synthesis only)"
    puts "    LEF files will be loaded in Innovus for P&R"
}

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
