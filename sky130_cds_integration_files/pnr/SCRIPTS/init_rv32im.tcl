#===============================================================================
# Init Script for rv32im_integrated_macro
# Creates floorplan and places pre-built macros as fixed blocks
#===============================================================================

source setup_rv32im.tcl

#===============================================================================
# Create Floorplan
#===============================================================================

puts "==> Creating floorplan..."

# Create floorplan with enough space for both macros plus glue logic
# Size: 400µm x 350µm with 15µm margins
# Adjust these dimensions based on your actual macro sizes!
# NOTE: Macro bounding boxes can be queried after floorplan is created
floorPlan -site unithd -s 400.0 350.0 15.0 15.0 15.0 15.0

puts "Floorplan created: 400µm x 350µm with 15µm margins"

#===============================================================================
# Place Pre-Built Macros as Fixed Blocks
#===============================================================================

puts "==> Placing pre-built macros..."

# Place core_macro on the left side
# Coordinates are in microns (µm)
placeInstance u_core_macro 40.0 60.0 -fixed

# Place mdu_macro on the right side
# Adjust X coordinate based on core width + spacing (e.g., 150-200µm apart)
placeInstance u_mdu_macro 250.0 60.0 -fixed

puts "    ✓ u_core_macro placed at (40.0, 60.0) - FIXED"
puts "    ✓ u_mdu_macro placed at (250.0, 60.0) - FIXED"

# Verify no overlap between macros
verifyGeometry -noRoutingBlkg

# Create placement blockages around macros (optional - keeps glue logic away)
# createPlaceBlockage -box {35.0 55.0 145.0 165.0} -type soft
# createPlaceBlockage -box {245.0 55.0 355.0 165.0} -type soft

#===============================================================================
# Top-Level Pin Placement
#===============================================================================

puts "==> Placing top-level I/O pins..."

# Place clock and reset on top edge
editPin -pin clk -edge TOP -layer met3 -spreadType center
editPin -pin rst_n -edge TOP -layer met3 -spreadType center -start {20.0 0.0}

# Place input pins on left edge
editPin -pin instruction* -edge LEFT -layer met2 -spreadType spread
editPin -pin data_in* -edge LEFT -layer met2 -spreadType spread
editPin -pin interrupt -edge LEFT -layer met2 -spreadType start

# Place output pins on right edge
editPin -pin data_out* -edge RIGHT -layer met2 -spreadType spread
editPin -pin addr_out* -edge BOTTOM -layer met2 -spreadType spread
editPin -pin mem_write_enable -edge RIGHT -layer met2 -spreadType end
editPin -pin mem_read_enable -edge RIGHT -layer met2 -spreadType end

puts "Top-level pins placed"

#===============================================================================
# Power Planning
#===============================================================================

puts "==> Creating power distribution network..."

# Global net connections (connect all VDD/VSS pins)
globalNetConnect VDD -type pgpin -pin vdd -inst *
globalNetConnect VSS -type pgpin -pin gnd -inst *

# Power rings around core area
addRing -nets {VDD VSS} \
        -type core_rings \
        -follow io \
        -layer {top met1 bottom met1 left met2 right met2} \
        -width 3.0 \
        -spacing 1.5 \
        -offset 2.0

# Power stripes (vertical on met2)
addStripe -nets {VDD VSS} \
          -layer met2 \
          -direction vertical \
          -width 2.0 \
          -spacing 8.0 \
          -number_of_sets 25

# Power stripes (horizontal on met3)
addStripe -nets {VDD VSS} \
          -layer met3 \
          -direction horizontal \
          -width 2.0 \
          -spacing 8.0 \
          -number_of_sets 20

# Special route to connect all power structures
sroute -connect {blockPin padPin padRing corePin floatingStripe} \
       -layerChangeRange {met1 met4} \
       -blockPinTarget nearestTarget \
       -allowJogging 1 \
       -crossoverViaLayerRange {met1 met4}

puts "Power planning complete"

#===============================================================================
# Add Well Taps (for latch-up prevention)
#===============================================================================

# Add well taps with 30µm spacing (adjust for your PDK rules)
# setAddWellTapMode -cell sky130_osu_sc_18T_ms__tap -cellInterval 30.0
# addWellTap -cell sky130_osu_sc_18T_ms__tap -cellInterval 30.0 -prefix WELLTAP

#===============================================================================
# Save Database
#===============================================================================

exec mkdir -p DBS/rv32im_integrated
saveDesign DBS/rv32im_integrated/init.enc

puts ""
puts "========================================="
puts "Init Complete for RV32IM Integration"
puts "========================================="
puts ""
puts "Floorplan: 400µm x 350µm"
puts ""
puts "Macros placed (FIXED):"
puts "  u_core_macro: (40.0, 60.0)"
puts "  u_mdu_macro:  (250.0, 60.0)"
puts ""
puts "Power network created:"
puts "  - Core rings (met1/met2)"
puts "  - Power stripes (met2/met3)"
puts "  - All structures connected"
puts ""
puts "Next steps:"
puts "  make place  - Place standard cells (glue logic)"
puts "  make cts    - Clock tree synthesis"
puts "  make route  - Route design"
puts ""
