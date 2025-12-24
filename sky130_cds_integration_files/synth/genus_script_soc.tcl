#===============================================================================
# Genus Synthesis Script for rv32imz_soc_macro (UPDATED FOR YOUR STRUCTURE)
# Your SOC directly instantiates: rv32im_integrated + individual peripherals
#===============================================================================

set DESIGN "rv32im_soc_with_integrated_core"  # Your actual module name!

# Paths
set LIB_PATH "../sky130_osu_sc_t18"
set LIB_VARIANT "18T_ms"  # Options: 18T_hs, 18T_ls, 18T_ms
set HDL_PATH "hdl/soc_integrated"
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

# LEVEL 1: RV32IM integrated macro (core + mdu already merged)
if {[file exists "${MACRO_DIR}/rv32im_integrated/rv32im_integrated_macro_netlist.v"]} {
    read_hdl -v2001 "${MACRO_DIR}/rv32im_integrated/rv32im_integrated_macro_netlist.v"
    puts "    ✓ rv32im_integrated_macro netlist loaded"
} else {
    puts "ERROR: rv32im_integrated_macro netlist not found!"
    exit 1
}

# LEVEL 0: Individual peripheral macros (your SOC uses them directly)
set peripheral_macros {memory_macro communication_macro protection_macro adc_subsystem_macro pwm_accelerator_macro}

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
# Read Top-Level SOC RTL
#===============================================================================

puts "==> Reading top-level SOC RTL..."
read_hdl -v2001 {
    rv32im_soc_complete.v
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

# Set rv32im_integrated as black box
if {[llength [get_db designs rv32im_integrated_macro]] > 0} {
    set_db [get_db designs rv32im_integrated_macro] .preserve true
    set_dont_touch [get_db designs rv32im_integrated_macro]
    puts "    ✓ rv32im_integrated_macro marked as black box"
}

# Set individual peripherals as black boxes
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

# Read constraints from sub-macros (optional)
catch {read_sdc "${MACRO_DIR}/rv32im_integrated/rv32im_integrated_macro.sdc"}
foreach macro $peripheral_macros {
    catch {read_sdc "${MACRO_DIR}/${macro}/${macro}.sdc"}
}

# Read top-level constraints
if {[file exists "constraints/soc_integrated.sdc"]} {
    read_sdc "constraints/soc_integrated.sdc"
} else {
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
puts "  rv32im_soc_with_integrated_core (top)"
puts "    ├── u_cpu_core (rv32im_integrated_macro)"
puts "    │   ├── u_core_macro (pre-built)"
puts "    │   └── u_mdu_macro (pre-built)"
puts "    ├── u_memory (memory_macro)"
puts "    ├── u_pwm (pwm_accelerator_macro)"
puts "    ├── u_adc (adc_subsystem_macro)"
puts "    ├── u_protection (protection_macro)"
puts "    └── u_communication (communication_macro)"
puts ""
puts "Next step:"
puts "  cd ../pnr"
puts "  make -f Makefile.soc all"
puts ""

exit
