#============================================================
# Final Robust Init Script
#============================================================
source SCRIPTS/setup_rv32im.tcl

puts "==> Initializing Design..."

# 1. Initialize with explicit MMMC views
# This forces the timing engine to start immediately, preventing mode errors.
init_design -setup {default_view} -hold {default_view}

# 2. Basic Setup
floorPlan -site 18T -s 1250.0 750.0 30.0 30.0 30.0 30.0

placeInstance u_core_macro 40.0 40.0 -fixed
placeInstance u_mdu_macro 780.0 40.0 -fixed

# 3. Power Connections (Sky130)
globalNetConnect vccd1 -type pgpin -pin vdd -inst *
globalNetConnect vssd1 -type pgpin -pin gnd -inst *

addRing -nets {vccd1 vssd1} -type core_rings -follow io \
        -layer {top met1 bottom met1 left met2 right met2} \
        -width 5.0 -spacing 2.0 -offset 3.0

sroute -connect {blockPin padPin padRing corePin floatingStripe} \
       -layerChangeRange {met1 met5} -blockPinTarget nearestTarget

# 4. Save and Verify
exec mkdir -p DBS/rv32im_integrated
saveDesign DBS/rv32im_integrated/init.enc

puts "==> Initialization Complete."
