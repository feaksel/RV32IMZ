# ============================================================================
# SYNTHESIS CONFIGURATION: ENHANCED PDK
# Full academic synthesis with comprehensive cell library
# ============================================================================

puts "🚀 Using ENHANCED PDK configuration"
puts "   - ~80 cells, full CTS support"
puts "   - Better optimization, slower synthesis"

# METHOD 2: Two-step loading with enhanced libraries
read_libs $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Try to load other corners for better optimization
if {[catch {
    read_libs $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_n40C_1v60.lib -add
    read_libs $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_100C_1v95.lib -add
    puts "✓ Multi-corner libraries loaded"
} err]} {
    puts "Warning: Single corner only: $err"
}

# Set synthesis for quality
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# Enable advanced optimizations
set_db optimize_constant_propagation true
set_db optimize_registers true
set_db optimize_sequential_area true