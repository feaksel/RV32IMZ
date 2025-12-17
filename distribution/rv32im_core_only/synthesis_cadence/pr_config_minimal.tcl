# ============================================================================
# PLACE & ROUTE CONFIGURATION: MINIMAL PDK
# ============================================================================

puts "📦 Using MINIMAL PDK P&R configuration"

# Skip CTS entirely (no clock buffers available)
puts "Skipping CTS (minimal PDK - clock routed as regular net)"

# Use simple MMMC
set init_mmmc_file mmmc_simple.tcl

# Conservative floorplan for academic demo
set conservative_floorplan true