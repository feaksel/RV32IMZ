#===============================================================================
# Setup Script for rv32im_integrated_macro P&R
# Fixed for Innovus Initialization Flow
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

# Note: Using global variables (set) instead of set_db for init stage
set init_lib_search_path "${LIB_PATH}/${LIB_VARIANT}/lib"

# Define Base LEFs (Tech LEF must be first)
set base_lefs "${LIB_PATH}/sky130_osu_sc_18T.tlef ${LIB_PATH}/${LIB_VARIANT}/lef/sky130_osu_sc_${LIB_VARIANT}.lef"
set macro_lefs ""

puts "==> Library search path set"
puts "    Libs: ${LIB_PATH}/${LIB_VARIANT}/lib"

#===============================================================================
# Load Macro LEF Files
#===============================================================================

puts "==> Checking for macro LEF files..."

# Check core_macro LEF
if {[file exists "../pnr/outputs/core_macro/core_macro.lef"]} {
    append macro_lefs " ../pnr/outputs/core_macro/core_macro.lef"
    puts "    ✓ core_macro.lef found"
} else {
    puts "    WARNING: core_macro.lef not found"
}

# Check mdu_macro LEF
if {[file exists "../pnr/outputs/mdu_macro/mdu_macro.lef"]} {
    append macro_lefs " ../pnr/outputs/mdu_macro/mdu_macro.lef"
    puts "    ✓ mdu_macro.lef found"
} else {
    puts "    WARNING: mdu_macro.lef not found"
}

# Final LEF list
set init_lef_file [list $base_lefs $macro_lefs]

#===============================================================================
# Set Netlist and Timing Files
#===============================================================================

puts "==> Setting up design files..."

set NETLIST_FILE "../synth/outputs/rv32im_integrated/${DESIGN}.vh"
set SDC_FILE "../synth/outputs/rv32im_integrated/${DESIGN}.sdc"

if {[file exists $NETLIST_FILE]} {
    set init_verilog "$NETLIST_FILE"
    puts "    ✓ Netlist identified: ${DESIGN}.vh"
} else {
    puts "    ERROR: Netlist not found: $NETLIST_FILE"
    exit 1
}

set init_top_cell "$DESIGN"

# Define Power and Ground Nets (Required for Sky130)
set init_pwr_net "vccd1"
set init_gnd_net "vssd1"

#===============================================================================
# Initialize Design
#===============================================================================

puts "==> Initializing design database..."

# Using init_design to load the variables defined above
if {[file exists $SDC_FILE]} {
    puts "    ✓ SDC found: $SDC_FILE"
    init_design -setup $SDC_FILE -hold $SDC_FILE
} else {
    puts "    WARNING: No SDC found, initializing without timing constraints"
    init_design
}

puts "    ✓ Design initialized successfully: $DESIGN"

#===============================================================================
# Verify Design Hierarchy
#===============================================================================

puts "==> Verifying macro instances..."

set core_found 0
set mdu_found 0

# get_db is safe to use AFTER init_design
set all_insts [get_db insts]
foreach inst $all_insts {
    set inst_name [get_db $inst .name]
    if {$inst_name == "u_core_macro"} { set core_found 1 }
    if {$inst_name == "u_mdu_macro"}  { set mdu_found 1 }
}

if {$core_found} { puts "    ✓ u_core_macro: PLACED" } else { puts "    ! u_core_macro: MISSING" }
if {$mdu_found}  { puts "    ✓ u_mdu_macro: PLACED" }  else { puts "    ! u_mdu_macro: MISSING" }

puts ""
puts "Setup complete - ready for floorplanning"
puts ""
