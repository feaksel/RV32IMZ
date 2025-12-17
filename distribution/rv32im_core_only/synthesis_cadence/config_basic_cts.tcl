# ============================================================================
# SYNTHESIS CONFIGURATION: BASIC CTS PDK
# Enhanced academic synthesis with basic clock tree support
# ============================================================================

puts "⚡ Using BASIC CTS PDK configuration"
puts "   - Minimal + clock buffers"
puts "   - Basic CTS capability"

# METHOD 1: Single library (enhanced with CTS cells)
read_libs $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Set synthesis for balance of speed and quality
set_db syn_generic_effort medium
set_db syn_map_effort medium  
set_db syn_opt_effort medium

# Enable basic clock optimization
set_db optimize_constant_propagation true
set_db optimize_registers true