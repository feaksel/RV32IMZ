# Pin Placement for SoC Integration
# Assigns physical locations to top-level chip I/O ports

puts "INFO: Applying pin placement for rv32im_soc_complete..."

#==============================================================================
# Clock and Reset - TOP edge (central location)
#==============================================================================

editPin -pin clk -edge TOP -layer met3 -spreadType center -start {100.0 0.0}
editPin -pin rst_n -edge TOP -layer met3 -spreadType center -start {110.0 0.0}

#==============================================================================
# External Memory Interface - LEFT edge (if exposed)
#==============================================================================

# External bus signals if needed
# editPin -pin ext_addr[*] -edge LEFT -layer met2 -spreadType spread
# editPin -pin ext_data[*] -edge LEFT -layer met2 -spreadType spread

#==============================================================================
# Communication Interfaces - BOTTOM edge
#==============================================================================

# UART pins
editPin -pin uart_tx -edge BOTTOM -layer met3 -spreadType center -start {50.0 0.0}
editPin -pin uart_rx -edge BOTTOM -layer met3 -spreadType center -start {55.0 0.0}

# SPI pins
editPin -pin spi_sclk -edge BOTTOM -layer met3 -spreadType center -start {70.0 0.0}
editPin -pin spi_mosi -edge BOTTOM -layer met3 -spreadType center -start {75.0 0.0}
editPin -pin spi_miso -edge BOTTOM -layer met3 -spreadType center -start {80.0 0.0}
editPin -pin spi_ss -edge BOTTOM -layer met3 -spreadType center -start {85.0 0.0}

# GPIO pins
editPin -pin gpio[*] -edge BOTTOM -layer met2 -spreadType spread -start {100.0 0.0}

#==============================================================================
# PWM Outputs - RIGHT edge
#==============================================================================

editPin -pin pwm_out[*] -edge RIGHT -layer met3 -spreadType spread -start {30.0 0.0}

#==============================================================================
# ADC Interface - TOP edge (near power)
#==============================================================================

editPin -pin adc_in[*] -edge TOP -layer met2 -spreadType spread -start {150.0 0.0}
editPin -pin adc_clk -edge TOP -layer met3 -spreadType center -start {200.0 0.0}

#==============================================================================
# Protection/Monitor Signals - LEFT edge
#==============================================================================

editPin -pin temp_sense -edge LEFT -layer met3 -spreadType center -start {30.0 0.0}
editPin -pin overheat_alert -edge LEFT -layer met3 -spreadType center -start {35.0 0.0}
editPin -pin wdt_reset -edge LEFT -layer met3 -spreadType center -start {40.0 0.0}

#==============================================================================
# Interrupt Lines - RIGHT edge (if exposed)
#==============================================================================

editPin -pin irq[*] -edge RIGHT -layer met3 -spreadType spread -start {60.0 0.0}

#==============================================================================
# Power and Ground - Ring structure (handled by P&R)
#==============================================================================

puts "INFO: Pin placement for rv32im_soc_complete complete"
puts "INFO: Power/ground will be handled by ring and stripe creation in P&R"
