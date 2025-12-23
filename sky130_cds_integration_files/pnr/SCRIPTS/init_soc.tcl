#===============================================================================
# Init Script for rv32imz_soc_macro
# Top-level SOC floorplan and macro placement
# Places: rv32im_integrated + peripheral_subsystem + memory
#===============================================================================

source setup_soc.tcl

#===============================================================================
# Create Floorplan
#===============================================================================

puts "==> Creating floorplan..."

# Get macro bounding boxes
set rv32im_bbox [get_db [get_db insts u_rv32im_core] .bbox]
set periph_bbox [get_db [get_db insts u_peripherals] .bbox]
set mem_bbox [get_db [get_db insts u_memory] .bbox]

puts "RV32IM integrated macro bbox: $rv32im_bbox"
puts "Peripheral subsystem macro bbox: $periph_bbox"
puts "Memory macro bbox: $mem_bbox"

# Create large floorplan for complete SOC
# Size: 800µm x 700µm with 25µm margins
# This should accommodate all three major subsystems
floorPlan -site unithd -s 800.0 700.0 25.0 25.0 25.0 25.0

puts "Floorplan created: 800µm x 700µm with 25µm margins"

#===============================================================================
# Place Pre-Built Macros in Optimal Arrangement
#===============================================================================

puts "==> Placing pre-built macros..."

# Optimal arrangement for SOC:
# - RV32IM core in the center (high connectivity)
# - Memory close to core (high bandwidth)
# - Peripherals on the side (lower bandwidth)

# Place RV32IM core in center-left
placeInstance u_rv32im_core 100.0 250.0 -fixed

# Place memory close to core (high bandwidth requirement)
placeInstance u_memory 100.0 80.0 -fixed

# Place peripheral subsystem on right side
placeInstance u_peripherals 450.0 150.0 -fixed

puts "    ✓ u_rv32im_core placed at (100.0, 250.0) - FIXED"
puts "    ✓ u_memory placed at (100.0, 80.0) - FIXED"
puts "    ✓ u_peripherals placed at (450.0, 150.0) - FIXED"

# Verify no overlap
verifyGeometry -noRoutingBlkg

#===============================================================================
# Pin Placement
#===============================================================================

puts "==> Placing top-level SOC pins..."

# Clock and reset on top edge (center)
editPin -pin clk -edge TOP -layer met4 -spreadType center
editPin -pin rst_n -edge TOP -layer met4 -spreadType center -start {50.0 0.0}

# External memory interface on left edge
editPin -pin ext_mem_data_in* -edge LEFT -layer met3 -spreadType start
editPin -pin ext_mem_data_out* -edge LEFT -layer met3 -spreadType start
editPin -pin ext_mem_addr* -edge LEFT -layer met3 -spreadType spread
editPin -pin ext_mem_write_en -edge LEFT -layer met3 -spreadType end
editPin -pin ext_mem_read_en -edge LEFT -layer met3 -spreadType end

# GPIO on right edge
editPin -pin gpio_in* -edge RIGHT -layer met3 -spreadType start
editPin -pin gpio_out* -edge RIGHT -layer met3 -spreadType start

# UART on bottom edge
editPin -pin uart_rx -edge BOTTOM -layer met3 -spreadType start
editPin -pin uart_tx -edge BOTTOM -layer met3 -spreadType start

# SPI on bottom edge
editPin -pin spi_sck -edge BOTTOM -layer met3 -spreadType center
editPin -pin spi_mosi -edge BOTTOM -layer met3 -spreadType center
editPin -pin spi_miso -edge BOTTOM -layer met3 -spreadType center
editPin -pin spi_ss -edge BOTTOM -layer met3 -spreadType center

# ADC on right edge
editPin -pin adc_data* -edge RIGHT -layer met3 -spreadType center
editPin -pin adc_sample -edge RIGHT -layer met3 -spreadType center

# PWM on right edge
editPin -pin pwm_out* -edge RIGHT -layer met3 -spreadType end

# Interrupt on top edge
editPin -pin external_interrupt -edge TOP -layer met3 -spreadType end

puts "Top-level SOC pins placed"

#===============================================================================
# Power Planning (Robust for Large SOC)
#===============================================================================

puts "==> Creating power distribution network..."

# Global net connections
globalNetConnect VDD -type pgpin -pin vdd -inst *
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin gnd -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *

# Robust power rings (wider for SOC)
addRing -nets {VDD VSS} \
        -type core_rings \
        -follow io \
        -layer {top met1 bottom met1 left met2 right met2} \
        -width 5.0 \
        -spacing 2.0 \
        -offset 3.0

# Dense power mesh for large SOC
# Vertical stripes on met2
addStripe -nets {VDD VSS} \
          -layer met2 \
          -direction vertical \
          -width 3.0 \
          -spacing 12.0 \
          -number_of_sets 40

# Horizontal stripes on met3
addStripe -nets {VDD VSS} \
          -layer met3 \
          -direction horizontal \
          -width 3.0 \
          -spacing 12.0 \
          -number_of_sets 35

# Additional stripes on met4 for redundancy
addStripe -nets {VDD VSS} \
          -layer met4 \
          -direction vertical \
          -width 2.5 \
          -spacing 15.0 \
          -number_of_sets 30

# Connect all power structures
sroute -connect {blockPin padPin padRing corePin floatingStripe} \
       -layerChangeRange {met1 met5} \
       -blockPinTarget nearestTarget \
       -allowJogging 1 \
       -crossoverViaLayerRange {met1 met5} \
       -allowLayerChange 1

puts "Power planning complete (robust mesh for SOC)"

#===============================================================================
# Create Routing Blockages (Optional - Keep Signals Away from Macro Edges)
#===============================================================================

# Soft blockages around macros to improve routability
# createRouteBlockage -box {95.0 75.0 450.0 430.0} -layer all -spacing 2.0
# createRouteBlockage -box {445.0 145.0 750.0 550.0} -layer all -spacing 2.0

#===============================================================================
# Save Database
#===============================================================================

exec mkdir -p DBS/soc_integrated
saveDesign DBS/soc_integrated/init.enc

puts ""
puts "========================================="
puts "Init Complete for SOC Integration"
puts "========================================="
puts ""
puts "Floorplan: 800µm x 700µm (Full SOC)"
puts ""
puts "Macros placed (FIXED):"
puts "  u_rv32im_core (RV32IM):         (100.0, 250.0)"
puts "  u_memory (Memory Subsystem):    (100.0, 80.0)"
puts "  u_peripherals (Peripherals):    (450.0, 150.0)"
puts ""
puts "Power network:"
puts "  - Core rings (5µm width)"
puts "  - Dense mesh (met2/met3/met4)"
puts "  - 40 vertical + 35 horizontal stripes"
puts ""
puts "Next steps:"
puts "  make place  - Place top-level glue logic"
puts "  make cts    - Clock tree synthesis"
puts "  make route  - Route complete SOC"
puts ""
