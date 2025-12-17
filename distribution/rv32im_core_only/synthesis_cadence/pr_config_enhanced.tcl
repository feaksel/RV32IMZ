# ============================================================================
# PLACE & ROUTE CONFIGURATION: ENHANCED PDK  
# ============================================================================

puts "🚀 Using ENHANCED PDK P&R configuration"

# Full CTS with comprehensive clock buffers
puts "Running full CTS with enhanced clock buffer library..."

# Use main MMMC with multi-corner
set init_mmmc_file mmmc.tcl
set enable_full_cts true

# Optimized floorplan for full CTS
set conservative_floorplan false
set enable_advanced_optimization true