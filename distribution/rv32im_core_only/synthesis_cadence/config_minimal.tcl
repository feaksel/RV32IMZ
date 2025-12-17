# ============================================================================
# SYNTHESIS CONFIGURATION: MINIMAL PDK
# Fast academic synthesis with basic cells only
# ============================================================================

puts "📦 Using MINIMAL PDK configuration"
puts "   - ~20 basic cells, no CTS"
puts "   - Fast synthesis, good for demos"

# METHOD 1: Single library (most reliable for minimal PDK)
read_libs $TECH_LIB_PATH/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Set synthesis for speed
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium