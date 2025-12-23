#===============================================================================
# Cadence Genus Synthesis Script - RV32IM Integrated Macro
# Hierarchical integration: Combines pre-built core_macro + mdu_macro
# Treats both as black boxes and wires them together
#===============================================================================

# Paths (use PDK_ROOT environment variable set by build script)
set TECH_LIB_PATH "$env(PDK_ROOT)/sky130A/libs.ref"
set RTL_PATH "rtl"
set MACRO_PATH ".."

#===============================================================================
# Setup
#===============================================================================

# Set search paths
set_db init_lib_search_path $TECH_LIB_PATH
set_db init_hdl_search_path $RTL_PATH

puts "==> Loading technology libraries..."

# Environment and debug setup
set_db information_level 7
set_db hdl_max_loop_limit 10000

# Read single technology library (typical corner only)
set lib_path "$TECH_LIB_PATH/sky130_fd_sc_hd/lib"

puts "==> Loading single typical corner library..."
read_libs ${lib_path}/sky130_fd_sc_hd__tt_025C_1v80.lib
puts "==> Library loaded successfully"

#===============================================================================
# Read Pre-Built Macro Netlists (Black Box)
#===============================================================================

puts "==> Reading pre-built macro netlists..."

# Read core_macro synthesized netlist as black box
if {[file exists "$MACRO_PATH/core_macro/outputs/core_macro_syn.v"]} {
    read_hdl -v2001 "$MACRO_PATH/core_macro/outputs/core_macro_syn.v"
    puts "    core_macro netlist loaded"
    set_db [get_db designs core_macro] .dont_touch true
} else {
    puts "ERROR: core_macro_syn.v not found - you must build core_macro first!"
    exit 1
}

# Read mdu_macro synthesized netlist as black box  
if {[file exists "$MACRO_PATH/mdu_macro/outputs/mdu_macro_syn.v"]} {
    read_hdl -v2001 "$MACRO_PATH/mdu_macro/outputs/mdu_macro_syn.v"
    puts "    mdu_macro netlist loaded"
    set_db [get_db designs mdu_macro] .dont_touch true
} else {
    puts "ERROR: mdu_macro_syn.v not found - you must build mdu_macro first!"
    exit 1
}

#===============================================================================
# Read RTL - Only the wrapper file
#===============================================================================

puts "Reading wrapper RTL..."

# Only read the top-level wrapper that instantiates the two macros
read_hdl -v2001 "rtl/rv32im_integrated_macro.v"

#===============================================================================
# Elaborate Design
#===============================================================================

puts "Elaborating design..."
elaborate rv32im_integrated_macro

# Check design
check_design -unresolved

# Set dont_touch on the pre-built macros to prevent optimization
set_db [get_db insts u_core_macro] .preserve true
set_db [get_db insts u_mdu_macro] .preserve true

puts "==> Pre-built macros marked as black boxes (dont_touch)"

#===============================================================================
# Constraints
#===============================================================================

puts "Applying constraints..."

# Read timing constraints
if {[file exists "constraints/rv32im_integrated_macro.sdc"]} {
    read_sdc constraints/rv32im_integrated_macro.sdc
} else {
    # Create basic clock constraint - 100MHz target
    create_clock -period 10.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    set_output_delay 2.0 -clock clk [all_outputs]
}

#===============================================================================
# Synthesis Settings - High effort for best QoR
#===============================================================================

puts "Setting synthesis options..."

# Effort levels (high for best results)
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# Enable retiming for better performance
set_db retime true

# Enable area recovery
set_db syn_opt_area_mode true

#===============================================================================
# Run Synthesis - Only connecting logic, macros are black boxes
#===============================================================================

puts "==> Running synthesis (generic)..."
syn_generic

puts "==> Running synthesis (mapping)..."
syn_map

puts "==> Running synthesis (optimization)..."
# Light optimization since macros are already optimized
syn_opt

#===============================================================================
# Reports
#===============================================================================

puts "Generating reports..."

file mkdir reports
report_area > reports/area.rpt
report_gates > reports/gates.rpt
report_timing > reports/timing.rpt
report_power > reports/power.rpt
report_qor > reports/qor.rpt

#===============================================================================
# Write Output
#===============================================================================

puts "Writing netlist..."

# Create outputs directory if it doesn't exist
file mkdir outputs

# Write Verilog netlist
write_hdl > outputs/rv32im_integrated_macro_syn.v

# Write SDC
write_sdc > outputs/rv32im_integrated_macro.sdc

puts "==> Synthesis complete!"
puts "==> Netlist: outputs/rv32im_integrated_macro_syn.v"
puts ""
puts "Summary:"
puts "--------"
report_qor

exit
