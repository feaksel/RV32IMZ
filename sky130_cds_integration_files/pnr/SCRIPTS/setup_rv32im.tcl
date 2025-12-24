#===============================================================================
# Setup Script for rv32im_integrated_macro P&R
# Loads libraries, LEF files, and netlist for Innovus
#===============================================================================

set DESIGN "rv32im_integrated_macro"
set LIB_PATH "../sky130_osu_sc_t18"
set LIB_VARIANT "18T_ms"

puts "========================================="
puts "Setting up RV32IM Integration P&R"
puts "========================================="
puts ""

#===============================================================================
# Set Library Search Paths
#===============================================================================

set_db init_lib_search_path "${LIB_PATH}/${LIB_VARIANT}/lib"
set_db init_lef_file "${LIB_PATH}/sky130_osu_sc_18T.tlef ${LIB_PATH}/${LIB_VARIANT}/lef/sky130_osu_sc_${LIB_VARIANT}.lef"

puts "==> Library search path set"
puts "    Libs: ${LIB_PATH}/${LIB_VARIANT}/lib"
puts "    LEFs: tech + cell"

#===============================================================================
# Load Macro LEF Files
#===============================================================================

puts "==> Loading macro LEF files..."

# Load core_macro LEF
if {[file exists "../pnr/outputs/core_macro/core_macro.lef"]} {
    set_db init_lef_file [concat [get_db init_lef_file] "../pnr/outputs/core_macro/core_macro.lef"]
    puts "    ✓ core_macro.lef"
} else {
    puts "    WARNING: core_macro.lef not found"
}

# Load mdu_macro LEF
if {[file exists "../pnr/outputs/mdu_macro/mdu_macro.lef"]} {
    set_db init_lef_file [concat [get_db init_lef_file] "../pnr/outputs/mdu_macro/mdu_macro.lef"]
    puts "    ✓ mdu_macro.lef"
} else {
    puts "    WARNING: mdu_macro.lef not found"
}

#===============================================================================
# Set Netlist and Timing Files
#===============================================================================

puts "==> Setting up design files..."

set NETLIST_FILE "../synth/outputs/rv32im_integrated/${DESIGN}.vh"
set SDC_FILE "../synth/outputs/rv32im_integrated/${DESIGN}.sdc"

if {[file exists $NETLIST_FILE]} {
    set_db init_verilog $NETLIST_FILE
    puts "    ✓ Netlist: ${DESIGN}.vh"
} else {
    puts "    ERROR: Netlist not found: $NETLIST_FILE"
    puts "    Run synthesis first!"
    exit 1
}

# Set up timing
if {[file exists $SDC_FILE]} {
    # Use simple constraint mode
    set_db init_top_cell $DESIGN
    puts "    ✓ Top cell: $DESIGN"
    puts "    ✓ SDC: ${DESIGN}.sdc"
} else {
    puts "    WARNING: SDC not found: $SDC_FILE"
    set_db init_top_cell $DESIGN
}

#===============================================================================
# Initialize Design
#===============================================================================

puts "==> Initializing design..."

# Init design - this reads everything and elaborates
if {[file exists $SDC_FILE]} {
    init_design -setup $SDC_FILE -hold $SDC_FILE
} else {
    init_design
}

puts "    ✓ Design initialized: $DESIGN"

#===============================================================================
# Verify Design
#===============================================================================

puts "==> Checking design..."

# Check if macros are present
set core_found 0
set mdu_found 0

set all_insts [get_db insts -if {.is_hierarchical}]
foreach inst $all_insts {
    set inst_name [get_db $inst .name]
    if {$inst_name == "u_core_macro"} {
        set core_found 1
        puts "    ✓ Found: u_core_macro"
    }
    if {$inst_name == "u_mdu_macro"} {
        set mdu_found 1
        puts "    ✓ Found: u_mdu_macro"
    }
}

if {!$core_found} {
    puts "    WARNING: u_core_macro not found in design"
}

if {!$mdu_found} {
    puts "    WARNING: u_mdu_macro not found in design"
}

puts ""
puts "Setup complete - ready for floorplanning"
puts ""
