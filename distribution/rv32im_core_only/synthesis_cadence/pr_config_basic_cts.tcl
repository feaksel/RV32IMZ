# ============================================================================
# PLACE & ROUTE CONFIGURATION: BASIC CTS PDK
# ============================================================================

puts "⚡ Using BASIC CTS PDK P&R configuration"

# Try basic CTS (with available clock buffers)
puts "Attempting basic CTS with available clock buffers..."

# Use main MMMC with fallback
set init_mmmc_file mmmc.tcl
set enable_basic_cts true

# Moderate floorplan for CTS
set conservative_floorplan false