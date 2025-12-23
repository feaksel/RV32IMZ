#===============================================================================
# Init Script for peripheral_subsystem_macro
# Places communication + protection + adc + pwm macros
#===============================================================================

source setup_periph.tcl

#===============================================================================
# Create Floorplan
#===============================================================================

puts "==> Creating floorplan..."

# Get macro bounding boxes
set comm_bbox [get_db [get_db insts u_communication] .bbox]
set prot_bbox [get_db [get_db insts u_protection] .bbox]
set adc_bbox [get_db [get_db insts u_adc_subsystem] .bbox]
set pwm_bbox [get_db [get_db insts u_pwm_accelerator] .bbox]

puts "Communication macro bbox: $comm_bbox"
puts "Protection macro bbox: $prot_bbox"
puts "ADC subsystem macro bbox: $adc_bbox"
puts "PWM accelerator macro bbox: $pwm_bbox"

# Create floorplan (adjust size based on your macros)
# Size: 500µm x 400µm with 20µm margins
floorPlan -site unithd -s 500.0 400.0 20.0 20.0 20.0 20.0

puts "Floorplan created: 500µm x 400µm with 20µm margins"

#===============================================================================
# Place Pre-Built Macros
#===============================================================================

puts "==> Placing pre-built macros..."

# Arrange macros in a 2x2 grid for good connectivity
# Adjust coordinates based on actual macro sizes

# Bottom row
placeInstance u_communication 50.0 50.0 -fixed
placeInstance u_protection 270.0 50.0 -fixed

# Top row
placeInstance u_adc_subsystem 50.0 220.0 -fixed
placeInstance u_pwm_accelerator 270.0 220.0 -fixed

puts "    ✓ u_communication placed at (50.0, 50.0) - FIXED"
puts "    ✓ u_protection placed at (270.0, 50.0) - FIXED"
puts "    ✓ u_adc_subsystem placed at (50.0, 220.0) - FIXED"
puts "    ✓ u_pwm_accelerator placed at (270.0, 220.0) - FIXED"

# Verify no overlap
verifyGeometry -noRoutingBlkg

#===============================================================================
# Pin Placement
#===============================================================================

puts "==> Placing top-level pins..."

# Clock and reset on top
editPin -pin clk -edge TOP -layer met3 -spreadType center
editPin -pin rst_n -edge TOP -layer met3 -spreadType center -start {30.0 0.0}

# Processor bus on left edge
editPin -pin addr* -edge LEFT -layer met2 -spreadType spread
editPin -pin data_in* -edge LEFT -layer met2 -spreadType spread
editPin -pin data_out* -edge LEFT -layer met2 -spreadType spread
editPin -pin write_en -edge LEFT -layer met2 -spreadType end
editPin -pin read_en -edge LEFT -layer met2 -spreadType end

# GPIO on right edge
editPin -pin gpio_in* -edge RIGHT -layer met2 -spreadType start
editPin -pin gpio_out* -edge RIGHT -layer met2 -spreadType start

# UART on bottom edge
editPin -pin uart_rx -edge BOTTOM -layer met2 -spreadType start
editPin -pin uart_tx -edge BOTTOM -layer met2 -spreadType start

# SPI on bottom edge
editPin -pin spi_sck -edge BOTTOM -layer met2 -spreadType center
editPin -pin spi_mosi -edge BOTTOM -layer met2 -spreadType center
editPin -pin spi_miso -edge BOTTOM -layer met2 -spreadType center
editPin -pin spi_ss -edge BOTTOM -layer met2 -spreadType center

# ADC on top edge
editPin -pin adc_data* -edge TOP -layer met2 -spreadType end
editPin -pin adc_sample -edge TOP -layer met2 -spreadType end

# PWM on right edge
editPin -pin pwm_out* -edge RIGHT -layer met2 -spreadType end

puts "Top-level pins placed"

#===============================================================================
# Power Planning
#===============================================================================

puts "==> Creating power distribution network..."

globalNetConnect VDD -type pgpin -pin vdd -inst *
globalNetConnect VSS -type pgpin -pin gnd -inst *

# Power rings
addRing -nets {VDD VSS} \
        -type core_rings \
        -follow io \
        -layer {top met1 bottom met1 left met2 right met2} \
        -width 3.5 \
        -spacing 1.5 \
        -offset 2.5

# Power stripes (more sets due to larger area)
addStripe -nets {VDD VSS} \
          -layer met2 \
          -direction vertical \
          -width 2.0 \
          -spacing 10.0 \
          -number_of_sets 30

addStripe -nets {VDD VSS} \
          -layer met3 \
          -direction horizontal \
          -width 2.0 \
          -spacing 10.0 \
          -number_of_sets 24

# Connect power
sroute -connect {blockPin padPin padRing corePin floatingStripe} \
       -layerChangeRange {met1 met4} \
       -blockPinTarget nearestTarget \
       -allowJogging 1 \
       -crossoverViaLayerRange {met1 met4}

puts "Power planning complete"

#===============================================================================
# Save Database
#===============================================================================

exec mkdir -p DBS/peripheral_subsystem
saveDesign DBS/peripheral_subsystem/init.enc

puts ""
puts "========================================="
puts "Init Complete for Peripheral Subsystem"
puts "========================================="
puts ""
puts "Floorplan: 500µm x 400µm"
puts ""
puts "Macros placed (FIXED):"
puts "  u_communication:    (50.0, 50.0)"
puts "  u_protection:       (270.0, 50.0)"
puts "  u_adc_subsystem:    (50.0, 220.0)"
puts "  u_pwm_accelerator:  (270.0, 220.0)"
puts ""
puts "Next steps:"
puts "  make place  - Place glue logic"
puts "  make cts    - Clock tree synthesis"
puts "  make route  - Route design"
puts ""
