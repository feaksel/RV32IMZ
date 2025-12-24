#===============================================================================
# Genus Synthesis Script for rv32im_integrated_macro
# Integrates pre-built core_macro + mdu_macro
#===============================================================================

set DESIGN "rv32im_integrated_macro"

# Paths
set LIB_PATH "../sky130_osu_sc_t18"
set HDL_PATH "hdl/rv32im_integrated"
set MACRO_DIR "../pnr/outputs"  # Where pre-built macros are

#===============================================================================
# Library Setup
#===============================================================================

set_db init_lib_search_path "$LIB_PATH/lib $LIB_PATH/lef"
set_db init_hdl_search_path $HDL_PATH

puts "==> Loading libraries..."

# Try to find timing library (try multiple variants)
set lib_loaded 0
foreach lib_variant {
    "sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"
    "sky130_osu_sc_18T_TT_1P8_25C.ccs.lib"
    "sky130_osu_sc_18T_ms_TT_1P8_25C.lib"
} {
    if {[file exists "$LIB_PATH/lib/$lib_variant"]} {
        read_libs "$LIB_PATH/lib/$lib_variant"
        puts "    ✓ Loaded library: $lib_variant"
        set lib_loaded 1
        break
    }
}

if {!$lib_loaded} {
    puts "ERROR: No timing library found in $LIB_PATH/lib/"
    puts "Expected one of:"
    puts "  - sky130_osu_sc_18T_ms_TT_1P8_25C.ccs.lib"
    puts "  - sky130_osu_sc_18T_TT_1P8_25C.ccs.lib"
    exit 1
}

puts "==> Reading LEF files..."

# Load tech LEF (MUST come first - defines layers)
set tech_lef_loaded 0
foreach tech_lef_variant {
    "sky130_osu_sc_18T_tech.lef"
    "sky130_osu_sc_18T_ms_tech.lef"
} {
    if {[file exists "$LIB_PATH/lef/$tech_lef_variant"]} {
        read_physical -lef "$LIB_PATH/lef/$tech_lef_variant"
        puts "    ✓ Tech LEF loaded: $tech_lef_variant"
        set tech_lef_loaded 1
        break
    }
}

if {!$tech_lef_loaded} {
    puts "ERROR: No technology LEF found in $LIB_PATH/lef/"
    puts "Tech LEF defines layers and is REQUIRED"
    exit 1
}

# Load cell LEF (MUST come after tech LEF)
set cell_lef_loaded 0
foreach cell_lef_variant {
    "sky130_osu_sc_18T.lef"
    "sky130_osu_sc_18T_ms.lef"
} {
    if {[file exists "$LIB_PATH/lef/$cell_lef_variant"]} {
        read_physical -lef "$LIB_PATH/lef/$cell_lef_variant"
        puts "    ✓ Cell LEF loaded: $cell_lef_variant"
        set cell_lef_loaded 1
        break
    }
}

if {!$cell_lef_loaded} {
    puts "ERROR: No cell LEF found in $LIB_PATH/lef/"
    exit 1
}

#===============================================================================
# Read Pre-Built Macro Netlists (Black Boxes)
#===============================================================================

puts "==> Reading pre-built macro netlists..."

# Read core_macro netlist
if {[file exists "${MACRO_DIR}/core_macro/core_macro_netlist.v"]} {
    read_hdl -v2001 "${MACRO_DIR}/core_macro/core_macro_netlist.v"
    puts "    ✓ core_macro netlist loaded"
} else {
    puts "ERROR: core_macro netlist not found!"
    puts "Build core_macro first using standard sky130_cds flow:"
    puts "  cd pnr && make all DESIGN=core_macro"
    puts "  Then generate integration files in Innovus"
    exit 1
}

# Read mdu_macro netlist
if {[file exists "${MACRO_DIR}/mdu_macro/mdu_macro_netlist.v"]} {
    read_hdl -v2001 "${MACRO_DIR}/mdu_macro/mdu_macro_netlist.v"
    puts "    ✓ mdu_macro netlist loaded"
} else {
    puts "ERROR: mdu_macro netlist not found!"
    puts "Build mdu_macro first using standard sky130_cds flow:"
    puts "  cd pnr && make all DESIGN=mdu_macro"
    puts "  Then generate integration files in Innovus"
    exit 1
}

#===============================================================================
# Read Top-Level Integration RTL
#===============================================================================

puts "==> Reading integration RTL..."
read_hdl -v2001 {
    rv32im_integrated_macro.v
}

#===============================================================================
# Elaborate
#===============================================================================

puts "==> Elaborating design..."
elaborate $DESIGN

check_design -unresolved

#===============================================================================
# Mark Macros as Black Boxes (Don't Touch!)
#===============================================================================

puts "==> Setting macros as black boxes..."

# Preserve pre-built macros (don't re-synthesize them)
if {[llength [get_db designs core_macro]] > 0} {
    set_db [get_db designs core_macro] .preserve true
    set_dont_touch [get_db designs core_macro]
    puts "    ✓ core_macro marked as black box"
}

if {[llength [get_db designs mdu_macro]] > 0} {
    set_db [get_db designs mdu_macro] .preserve true
    set_dont_touch [get_db designs mdu_macro]
    puts "    ✓ mdu_macro marked as black box"
}

#===============================================================================
# Read Constraints
#===============================================================================

puts "==> Applying constraints..."

# Read macro SDC files (for better timing - optional)
catch {read_sdc "${MACRO_DIR}/core_macro/core_macro.sdc"}
catch {read_sdc "${MACRO_DIR}/mdu_macro/mdu_macro.sdc"}

# Read top-level constraints
if {[file exists "constraints/rv32im_integrated.sdc"]} {
    read_sdc "constraints/rv32im_integrated.sdc"
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
# Synthesis (Only Glue Logic!)
#===============================================================================

puts "==> Running synthesis (glue logic only)..."
puts "    Note: Macros are black boxes, only interconnect will be synthesized"

set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# Synthesize only the wires connecting the macros
syn_generic
syn_map
syn_opt

#===============================================================================
# Reports
#===============================================================================

puts "==> Generating reports..."

exec mkdir -p reports/rv32im_integrated

report_timing > reports/rv32im_integrated/timing.rpt
report_area > reports/rv32im_integrated/area.rpt
report_qor > reports/rv32im_integrated/qor.rpt
report_power > reports/rv32im_integrated/power.rpt
report_hierarchy > reports/rv32im_integrated/hierarchy.rpt

#===============================================================================
# Write Outputs
#===============================================================================

puts "==> Writing outputs..."

exec mkdir -p outputs/rv32im_integrated

write_hdl > outputs/rv32im_integrated/${DESIGN}.vh
write_sdc > outputs/rv32im_integrated/${DESIGN}.sdc
write_sdf > outputs/rv32im_integrated/${DESIGN}.sdf

puts ""
puts "========================================="
puts "RV32IM Integration Synthesis Complete!"
puts "========================================="
puts ""
puts "Design hierarchy:"
puts "  rv32im_integrated_macro (top)"
puts "    ├── u_core_macro (pre-built black box)"
puts "    └── u_mdu_macro (pre-built black box)"
puts ""
puts "Next step:"
puts "  cd ../pnr"
puts "  make -f Makefile.rv32im all"
puts ""

exit
