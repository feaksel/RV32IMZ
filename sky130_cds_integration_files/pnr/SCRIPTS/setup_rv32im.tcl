#===============================================================================
# Setup Script for rv32im_integrated_macro P&R
# Loads libraries, LEF files, and netlist from synthesis
#===============================================================================

set DESIGN "rv32im_integrated_macro"
set LIB_PATH "../sky130_osu_sc_t18"
set LIB_VARIANT "18T_ms"

puts "========================================="
puts "Setting up RV32IM Integration P&R"
puts "========================================="
puts ""

#===============================================================================
# Load Libraries
#===============================================================================

puts "==> Loading timing libraries..."

# Load timing library for standard cells
set lib_file "$LIB_PATH/${LIB_VARIANT}/lib/sky130_osu_sc_${LIB_VARIANT}_TT_1P8_25C.ccs.lib"
if {[file exists $lib_file]} {
    read_lib $lib_file
    puts "    ✓ Loaded: $lib_file"
} else {
    puts "ERROR: Timing library not found: $lib_file"
    exit 1
}

# TODO: Load macro timing models if available
# catch {read_lib ../pnr/outputs/core_macro/core_macro.lib}
# catch {read_lib ../pnr/outputs/mdu_macro/mdu_macro.lib}

#===============================================================================
# Load LEF Files
#===============================================================================

puts "==> Loading LEF files..."

# Load technology LEF (at root level)
set tech_lef "$LIB_PATH/sky130_osu_sc_18T.tlef"
if {[file exists $tech_lef]} {
    read_lef $tech_lef
    puts "    ✓ Tech LEF: sky130_osu_sc_18T.tlef"
} else {
    puts "ERROR: Tech LEF not found: $tech_lef"
    exit 1
}

# Load standard cell LEF
set cell_lef "$LIB_PATH/${LIB_VARIANT}/lef/sky130_osu_sc_${LIB_VARIANT}.lef"
if {[file exists $cell_lef]} {
    read_lef $cell_lef
    puts "    ✓ Cell LEF: sky130_osu_sc_${LIB_VARIANT}.lef"
} else {
    puts "ERROR: Cell LEF not found: $cell_lef"
    exit 1
}

# Load macro LEF files (from pre-built macros)
puts "==> Loading macro LEF files..."

set core_lef "../pnr/outputs/core_macro/core_macro.lef"
if {[file exists $core_lef]} {
    read_lef $core_lef
    puts "    ✓ core_macro LEF loaded"
} else {
    puts "WARNING: core_macro LEF not found: $core_lef"
    puts "You need to build core_macro first and generate LEF abstract"
}

set mdu_lef "../pnr/outputs/mdu_macro/mdu_macro.lef"
if {[file exists $mdu_lef]} {
    read_lef $mdu_lef
    puts "    ✓ mdu_macro LEF loaded"
} else {
    puts "WARNING: mdu_macro LEF not found: $mdu_lef"
    puts "You need to build mdu_macro first and generate LEF abstract"
}

#===============================================================================
# Load Netlist from Synthesis
#===============================================================================

puts "==> Loading netlist from synthesis..."

set netlist_file "../synth/outputs/rv32im_integrated/${DESIGN}.vh"
if {[file exists $netlist_file]} {
    read_hdl $netlist_file
    puts "    ✓ Netlist loaded: ${DESIGN}.vh"
} else {
    puts "ERROR: Netlist not found: $netlist_file"
    puts "Run synthesis first:"
    puts "  cd ../synth"
    puts "  genus -batch -files genus_script_rv32im.tcl"
    exit 1
}

#===============================================================================
# Elaborate Design
#===============================================================================

puts "==> Elaborating design..."

# Use quotes instead of braces to allow variable substitution
set sdc_file "../synth/outputs/rv32im_integrated/${DESIGN}.sdc"

if {[file exists $sdc_file]} {
    init_design -setup $sdc_file -hold $sdc_file
    puts "    ✓ Design elaborated: $DESIGN"
    puts "    ✓ Timing constraints loaded: $sdc_file"
} else {
    # No SDC file - elaborate without constraints
    puts "WARNING: SDC file not found: $sdc_file"
    puts "Continuing without timing constraints..."
    init_design
    puts "    ✓ Design elaborated: $DESIGN (no constraints)"
}

#===============================================================================
# Design Checks
#===============================================================================

puts "==> Checking design..."

# Check if macros are present (use catch to avoid errors)
set core_exists 0
set mdu_exists 0

catch {
    set core_list [get_db insts u_core_macro]
    if {[llength $core_list] > 0} {
        set core_exists 1
    }
}

catch {
    set mdu_list [get_db insts u_mdu_macro]
    if {[llength $mdu_list] > 0} {
        set mdu_exists 1
    }
}

if {$core_exists == 0} {
    puts "WARNING: u_core_macro instance not found in netlist!"
}

if {$mdu_exists == 0} {
    puts "WARNING: u_mdu_macro instance not found in netlist!"
}

if {$core_exists > 0 && $mdu_exists > 0} {
    puts "    ✓ Both macros found in design"
}

puts ""
puts "Setup complete - ready for floorplanning"
puts ""
